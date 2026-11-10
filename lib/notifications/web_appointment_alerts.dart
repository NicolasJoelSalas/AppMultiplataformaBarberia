import 'dart:async';

import 'package:domain/domain.dart';

import 'appointment_alerts.dart';

/// Browser reminders run while the app page is open.
class WebAppointmentAlerts extends AppointmentAlerts {
  WebAppointmentAlerts(this._session, this._bookings);

  final SesionActual _session;
  final AppointmentAlertRepository _bookings;
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

  @override
  void start(AccountRole role, {required bool english}) {
    final uid = _session.usuarioId;
    if (uid == null || (_uid == uid && _role == role)) return;
    unawaited(stop());
    _uid = uid;
    _role = role;
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

  void _planReminders() {
    _timer?.cancel();
    if (_role != AccountRole.client || _records == null) return;
    final now = DateTime.now();
    final next = upcomingAppointmentReminders(_records!, now)
      ..sort((a, b) => a.at.compareTo(b.at));
    if (next.isEmpty) return;

    _timer = Timer(next.first.at.difference(now), () {
      if (_session.usuarioId != _uid) return;
      final currentTime = DateTime.now();
      for (final reminder in next) {
        if (reminder.at.isAfter(currentTime)) break;
        if (reminder.start.isAfter(currentTime) &&
            _delivered.add((reminder.appointmentId, reminder.at))) {
          _notices.add(AppointmentNotice.reminder);
        }
      }
      _planReminders();
      if (_notices.isNotEmpty) notifyListeners();
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
    final changes = _changes;
    _changes = null;
    _timer?.cancel();
    _uid = null;
    _role = null;
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
