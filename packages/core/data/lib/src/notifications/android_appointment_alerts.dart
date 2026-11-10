import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/timezone.dart' as tz;

/// A single SQLite transaction serializes the foreground and background jobs.
class AndroidAppointmentAlerts {
  AndroidAppointmentAlerts(this._bookings, this._noticeText);

  final ({String title, String body, String channel}) Function(
    AppointmentNotice notice,
    bool english,
    DateTime? start,
  )
  _noticeText;

  final AppointmentAlertRepository _bookings;
  final _notifications = FlutterLocalNotificationsPlugin();
  Future<Database>? _opening;
  static const _session = 'alert_session';

  Future<Database> _database() => _opening ??= openDatabase(
    'appointment_alerts.db',
    version: 1,
    onCreate: (db, _) => db.execute('''
      CREATE TABLE $_session (
        id INTEGER PRIMARY KEY,
        uid TEXT NOT NULL,
        role TEXT NOT NULL,
        english INTEGER NOT NULL,
        baseline TEXT,
        next_id INTEGER NOT NULL DEFAULT 1
      )
    '''),
  );

  AndroidFlutterLocalNotificationsPlugin get _android => _notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()!;

  Future<void> initialize(void Function(String uid) onTap) async {
    void handle(NotificationResponse response) {
      final payload = _decodePayload(response.payload);
      final uid = payload?.firstOrNull;
      if (uid is String) onTap(uid);
    }

    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_appointment_notice'),
      ),
      onDidReceiveNotificationResponse: handle,
    );
    final launch = await _notifications.getNotificationAppLaunchDetails();
    final response = launch?.notificationResponse;
    if (launch?.didNotificationLaunchApp == true && response != null) {
      handle(response);
    }
  }

  Future<bool> requestPermissions({required bool exact}) async {
    if (!await notificationsEnabled()) {
      await _android.requestNotificationsPermission();
      if (!await notificationsEnabled()) return false;
    }
    if (exact && !await _exactAllowed()) {
      return await _android.requestExactAlarmsPermission() == true;
    }
    return true;
  }

  Future<bool> notificationsEnabled() async =>
      await _android.areNotificationsEnabled() == true;

  Future<bool> _exactAllowed() async =>
      await _android.canScheduleExactNotifications() == true;

  Future<void> activate(
    String uid,
    AccountRole role, {
    required bool english,
  }) async {
    await (await _database()).transaction((tx) async {
      final state = await _active(tx);
      if (state?['uid'] == uid && state?['role'] == role.name) {
        await tx.update(_session, {'english': english ? 1 : 0});
      } else {
        await _notifications.cancelAll();
        await tx.delete(_session);
        await tx.insert(_session, {
          'id': 1,
          'uid': uid,
          'role': role.name,
          'english': english ? 1 : 0,
        });
      }
    });
  }

  Future<void> deactivate() async {
    await (await _database()).transaction((tx) async {
      await tx.delete(_session);
      try {
        await _notifications.cancelAll();
      } catch (_) {
        // Keep the session closed even if Android cannot clear notifications.
      }
    });
  }

  Future<Map<String, Object?>?> _active(Transaction tx) async =>
      (await tx.query(_session, limit: 1)).firstOrNull;

  Future<void> sync(String uid) async {
    await (await _database()).transaction((tx) async {
      final state = await _active(tx);
      if (state == null || state['uid'] != uid) return;
      final role = AccountRole.values.byName(state['role'] as String);
      final english = state['english'] == 1;
      final now = DateTime.now();
      final current =
          (await _bookings
                  .loadAppointmentAlertRecords(role, uid)
                  .timeout(const Duration(seconds: 12)))
              .where((item) => item.start?.isAfter(now) == true)
              .toList();
      var nextId = state['next_id'] as int;
      final pending = await _notifications.pendingNotificationRequests();
      for (final notification in pending) {
        if (notification.id >= nextId) nextId = notification.id + 1;
      }
      final allowed = await notificationsEnabled();
      final previous = state['baseline'] as String?;
      if (allowed && previous != null) {
        final changes = appointmentChanges(
          _decodeRecords(previous),
          current,
          role,
          uid,
          now,
        );
        for (final entry in changes.entries) {
          final text = _noticeText(
            AppointmentNotice.fromChange(entry.value),
            english,
            null,
          );
          await _notifications.show(
            id: nextId++,
            title: text.title,
            body: text.body,
            notificationDetails: _details(
              reminder: false,
              channel: text.channel,
            ),
            payload: jsonEncode([uid, entry.key]),
          );
        }
      }

      final exact = allowed && await _exactAllowed();
      final desired = <String, AppointmentReminder>{};
      if (allowed && role == AccountRole.client) {
        for (final reminder in upcomingAppointmentReminders(
          current,
          DateTime.now(),
          includeElapsed: true,
        )) {
          final payload = jsonEncode([
            uid,
            reminder.appointmentId,
            reminder.hours,
            reminder.at.millisecondsSinceEpoch,
            exact,
            english,
            reminder.start.toLocal().timeZoneOffset.inMinutes,
          ]);
          desired[payload] = reminder;
        }
      }

      for (final notification in pending) {
        final payload = notification.payload;
        if (payload != null && desired.remove(payload) != null) continue;
        await _notifications.cancel(id: notification.id);
      }
      for (final entry in desired.entries) {
        final reminder = entry.value;
        if (!reminder.at.isAfter(DateTime.now())) continue;
        final text = _noticeText(
          AppointmentNotice.reminder,
          english,
          reminder.start,
        );
        await _notifications.zonedSchedule(
          id: nextId++,
          title: text.title,
          body: text.body,
          scheduledDate: tz.TZDateTime.from(reminder.at, tz.UTC),
          notificationDetails: _details(reminder: true, channel: text.channel),
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          payload: entry.key,
        );
      }

      await tx.update(_session, {
        'baseline': _encodeRecords(current),
        'next_id': nextId,
      });
    });
  }

  NotificationDetails _details({
    required bool reminder,
    required String channel,
  }) => NotificationDetails(
    android: AndroidNotificationDetails(
      reminder ? 'appointment_reminders' : 'appointment_updates',
      channel,
      icon: 'ic_appointment_notice',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.private,
    ),
  );

  List<dynamic>? _decodePayload(String? payload) {
    if (payload == null) return null;
    try {
      final decoded = jsonDecode(payload);
      return decoded is List ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  String _encodeRecords(List<AppointmentAlertRecord> records) => jsonEncode([
    for (final item in records)
      {
        'id': item.id,
        'client': item.clientId,
        'barber': item.barberId,
        'service': item.serviceId,
        'start': item.start?.millisecondsSinceEpoch,
        'end': item.end?.millisecondsSinceEpoch,
        'status': item.status.name,
        'reference': item.referenceUrl,
      },
  ]);

  List<AppointmentAlertRecord> _decodeRecords(String value) => [
    for (final row in jsonDecode(value) as List)
      AppointmentAlertRecord(
        id: row['id'] as String,
        clientId: row['client'] as String,
        barberId: row['barber'] as String,
        serviceId: row['service'] as String,
        start: _instant(row['start'] as int?),
        end: _instant(row['end'] as int?),
        status: AppointmentStatus.values.byName(row['status'] as String),
        canceledBy: null,
        referenceUrl: row['reference'] as String?,
      ),
  ];

  DateTime? _instant(int? millis) => millis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
}
