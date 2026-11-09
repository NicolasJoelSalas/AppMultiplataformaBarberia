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
