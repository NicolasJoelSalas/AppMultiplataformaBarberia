import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

class AppointmentsViewModel extends ChangeNotifier {
  AppointmentsViewModel(this._repository, this.role)
    : _complete = CompleteAppointment(_repository);

  final BookingRepository _repository;
  final CompleteAppointment _complete;
  final AccountRole role;
  StreamSubscription<List<Appointment>>? _subscription;
  Timer? _startTimer;
  List<Appointment>? _appointments;
  BookingFailure? _error;
  String? _savingId;
  bool _disposed = false;

  List<Appointment>? get appointments => _appointments;
  BookingFailure? get error => _error;
  String? get savingId => _savingId;
  int get pendingCount =>
      _appointments
          ?.where((item) => item.status == AppointmentStatus.pending)
          .length ??
      0;

  (List<Appointment>, Map<AppointmentStatus, List<Appointment>>) groupedWeek(
    DateTime now,
    int offset,
    AppointmentStatus? statusFilter,
  ) {
    final weekly =
        [
          for (final item in _appointments ?? const <Appointment>[])
            if (_inWeek(item, now, offset)) item,
        ]..sort((a, b) {
          final byDistance = a.start!
              .difference(now)
              .inMicroseconds
              .abs()
              .compareTo(b.start!.difference(now).inMicroseconds.abs());
          if (byDistance != 0) return byDistance;
          final byTime = a.start!.compareTo(b.start!);
          return byTime == 0 ? a.id.compareTo(b.id) : byTime;
        });
    final groups = <AppointmentStatus, List<Appointment>>{};
    for (final item in weekly) {
      if (statusFilter == null || item.status == statusFilter) {
        groups.putIfAbsent(item.status, () => []).add(item);
      }
    }
    return (weekly, groups);
  }

  AgendaCalendar calendarFor(Appointment item) {
    const fallback = 'America/Argentina/Buenos_Aires';
    try {
      return AgendaCalendar(item.zoneId ?? fallback);
    } on AgendaProblem {
      return AgendaCalendar(fallback);
    }
  }

  bool _inWeek(Appointment item, DateTime now, int offset) {
    final start = item.start;
    if (start == null) return false;
    final calendar = calendarFor(item);
    final monday = calendar.mondayFor(now, offset);
    final date = calendar.dateOf(start);
    return !date.isBefore(monday) &&
        date.isBefore(monday.add(const Duration(days: 7)));
  }

  void start() {
    if (_subscription == null) retry();
  }

  void retry() {
    if (_disposed) return;
    unawaited(_subscription?.cancel());
    _error = null;
    _subscription = _repository
        .watchAppointments(role)
        .listen(
          (items) {
            _appointments = items;
            _error = null;
            _scheduleNextStart();
            notifyListeners();
          },
          onError: (Object error) {
            _error = error is BookingFailure ? error : BookingFailure.operation;
            if (_error == BookingFailure.permission) {
              _appointments = null;
              _startTimer?.cancel();
            }
            notifyListeners();
          },
        );
    notifyListeners();
  }

  void _scheduleNextStart() {
    _startTimer?.cancel();
    final now = DateTime.now();
    DateTime? next;
    for (final item in _appointments ?? const <Appointment>[]) {
      final start = item.start;
      if (item.status == AppointmentStatus.pending &&
          start != null &&
          start.isAfter(now) &&
          (next == null || start.isBefore(next))) {
        next = start;
      }
    }
    if (next != null) {
      _startTimer = Timer(next.difference(now), () {
        _scheduleNextStart();
        notifyListeners();
      });
    }
  }

  Future<void> cancel(Appointment item) =>
      _save(item.id, () => _repository.cancel(item.id));

  Future<void> complete(Appointment item) =>
      _save(item.id, () => _complete(item, DateTime.now()));

  Future<void> _save(String id, Future<void> Function() action) async {
    if (_savingId != null || _disposed) return;
    _savingId = id;
    notifyListeners();
    try {
      await action();
    } finally {
      _savingId = null;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _startTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
