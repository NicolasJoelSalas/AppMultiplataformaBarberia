import 'dart:async';
import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'appointment_alerts.dart';

/// Browser reminders run while the app page is open.
class WebAppointmentAlerts extends AppointmentAlerts {
  WebAppointmentAlerts(this._session, this._bookings, this._storage);

  final SesionActual _session;
  final AppointmentAlertRepository _bookings;
  final SharedPreferences _storage;
  Set<String>? _disabled;
  @override
  Set<String>? get disabledReminders => _disabled;
  String _keyPrefix(String uid) =>
      'reminders.disabled.${base64Url.encode(utf8.encode(uid))}.';

  Set<String> _readDisabled(String uid) {
    final prefix = _keyPrefix(uid);
    return {
      for (final key in _storage.getKeys())
        if (key.startsWith(prefix) && _storage.getBool(key) == true)
          key.substring(prefix.length),
    };
  }

  final _notices = <AppointmentNotice>[];
  final _delivered = <(String, DateTime)>{};
  StreamSubscription<void>? _changes;
  Timer? _timer;
  List<AppointmentAlertRecord>? _records;
  String? _uid;
  AccountRole? _role;
  Future<void>? _refreshing;
  bool _dirty = false;
  int _generation = 0;
  int _planVersion = 0;

  @override
  void start(AccountRole role, {required bool english}) {
    final uid = _session.usuarioId;
    if (uid == null || (_uid == uid && _role == role)) return;
    unawaited(stop());
    _uid = uid;
    _role = role;
    _disabled = role == AccountRole.client
        ? Set.unmodifiable(_readDisabled(uid))
        : null;
    notifyListeners();
    _changes = _bookings
        .watchAppointmentAlertChanges(role, uid)
        .listen((_) => refresh(), onError: (Object _) {});
    refresh();
  }

  @override
  void refresh() {
    if (_uid == null || _session.usuarioId != _uid) return;
    _dirty = true;
    _refreshing ??= _drain().whenComplete(() {
      _refreshing = null;
      if (_dirty) refresh();
    });
  }

  Future<void> _drain() async {
    while (_dirty && _uid != null && _session.usuarioId == _uid) {
      _dirty = false;
      final generation = _generation;
      final uid = _uid!;
      final role = _role!;
      try {
        final current = await _bookings
            .loadAppointmentAlertRecords(role, uid)
            .timeout(const Duration(seconds: 12));
        if (generation != _generation || _session.usuarioId != uid) continue;
        if (_records case final previous?) {
          final changes = appointmentChanges(
            previous,
            current,
            role,
            uid,
            DateTime.now(),
          );
          _notices.addAll(changes.values.map(AppointmentNotice.fromChange));
        }
        _records = current;
        _planReminders();
        if (_notices.isNotEmpty) notifyListeners();
      } catch (_) {
        // The next confirmed update or page resume retries the server.
      }
    }
  }

  @override
  Future<void> setReminderEnabled(String appointmentId, bool enabled) async {
    final uid = _uid;
    final previous = _disabled;
    if (uid == null || previous == null || _session.usuarioId != uid) {
      throw StateError('No active client session');
    }
    final generation = _generation;
    final key = '${_keyPrefix(uid)}$appointmentId';
    final saved = await (enabled
        ? _storage.remove(key)
        : _storage.setBool(key, true));
    if (!saved) {
      throw StateError('Could not save reminder preference');
    }
    if (generation != _generation || _session.usuarioId != uid) return;
    _disabled = Set.unmodifiable(_readDisabled(uid));
    _planReminders();
    notifyListeners();
  }

  void _planReminders() {
    final version = ++_planVersion;
    _timer?.cancel();
    if (_role != AccountRole.client || _records == null) return;
    final now = DateTime.now();
    final next = upcomingAppointmentReminders(_records!, now)
      ..removeWhere(
        (reminder) => _disabled?.contains(reminder.appointmentId) == true,
      )
      ..sort((a, b) => a.at.compareTo(b.at));
    if (next.isEmpty) return;

    final uid = _uid!;
    _timer = Timer(next.first.at.difference(now), () async {
      try {
        await _storage.reload();
      } on Exception {
        // Use the last loaded browser preferences if storage is unavailable.
      }
      if (version != _planVersion || _session.usuarioId != uid || _uid != uid) {
        return;
      }
      _disabled = Set.unmodifiable(_readDisabled(uid));
      final currentTime = DateTime.now();
      for (final reminder in next) {
        if (reminder.at.isAfter(currentTime)) break;
        if (_disabled?.contains(reminder.appointmentId) != true &&
            reminder.start.isAfter(currentTime) &&
            _delivered.add((reminder.appointmentId, reminder.at))) {
          _notices.add(AppointmentNotice.reminder);
        }
      }
      _planReminders();
      notifyListeners();
    });
  }

  @override
  List<AppointmentNotice> takeNotices() {
    final pending = _notices.toList();
    _notices.clear();
    return pending;
  }

  @override
  Future<void> stop() async {
    _generation++;
    _planVersion++;
    final changes = _changes;
    _changes = null;
    _timer?.cancel();
    _uid = null;
    _role = null;
    _disabled = null;
    _records = null;
    _dirty = false;
    _delivered.clear();
    _notices.clear();
    await changes?.cancel();
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}
