import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

class BookingViewModel extends ChangeNotifier {
  BookingViewModel(this._repository) : _confirm = ConfirmBooking(_repository);

  final BookingRepository _repository;
  final ConfirmBooking _confirm;
  List<BookingBarber> barbers = const [];
  List<BookingService> services = const [];
  BookingBarber? barber;
  BookingService? service;
  BookingWeek? week;
  BookingSlot? slot;
  BookingFailure? failure;
  int offset = 0;
  bool loading = false;
  bool confirming = false;
  bool _disposed = false;
  String? _requestId;

  bool get busy => loading || confirming;

  Future<void> retry() {
    final selected = barber;
    if (selected == null) {
      return _load(() async {
        barbers = await _repository.loadBarbers();
      });
    }
    if (service == null || failure == BookingFailure.serviceChanged) {
      return selectBarber(selected);
    }
    return _loadWeek();
  }

  Future<void> selectBarber(BookingBarber value) => _load(() async {
    barber = value;
    service = null;
    services = const [];
    _clearWeek();
    services = await _repository.loadServices(value.id);
  });

  Future<void> selectService(BookingService value) {
    if (busy) return Future.value();
    service = value;
    return _loadWeek();
  }

  Future<void> selectWeek(int value) {
    if (busy || offset == value) return Future.value();
    offset = value;
    return _loadWeek();
  }

  Future<void> _loadWeek() => _load(() async {
    _clearWeek();
    week = await _repository.loadWeek(barber!.id, service!.id, offset);
  });

  void _clearWeek() {
    week = null;
    slot = null;
    _requestId = null;
  }

  void selectSlot(BookingSlot value) {
    if (busy || slot == value) return;
    slot = value;
    _requestId = null;
    failure = null;
    _notify();
  }

  Future<bool> confirm(String name) async {
    final selected = slot;
    if (selected == null || busy || _disposed) return false;
    confirming = true;
    failure = null;
    _notify();
    try {
      await _confirm(
        BookingRequest(
          id: _requestId ??= _repository.newRequestId(),
          barberId: barber!.id,
          serviceId: service!.id,
          zoneId: week!.zoneId,
          slot: selected,
          clientName: name,
        ),
      );
      return true;
    } on BookingFailure catch (error) {
      failure = error;
      if (error == BookingFailure.unavailable ||
          error == BookingFailure.unpublished ||
          error == BookingFailure.serviceChanged) {
        _clearWeek();
      }
      return false;
    } catch (_) {
      failure = BookingFailure.operation;
      return false;
    } finally {
      confirming = false;
      _notify();
    }
  }

  Future<void> _load(Future<void> Function() action) async {
    if (busy || _disposed) return;
    loading = true;
    failure = null;
    _notify();
    try {
      await action();
    } on BookingFailure catch (error) {
      failure = error;
    } catch (_) {
      failure = BookingFailure.operation;
    } finally {
      loading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
