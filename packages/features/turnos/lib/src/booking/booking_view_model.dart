import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';

class BookingViewModel extends ChangeNotifier {
  BookingViewModel(this._repository, this._photos, this._original)
    : _confirm = ConfirmBooking(_repository);

  final BookingRepository _repository;
  final BookingPhotoRepository _photos;
  final Appointment? _original;
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
  Uint8List? photoBytes;
  String? _uploadedPhoto;
  bool _changeReference = false;

  String? get existingPhoto =>
      _changeReference ? null : _original?.referenceUrl;

  bool get busy => loading || confirming;

  Future<void> initialize() async {
    await retry();
    final original = _original;
    if (_disposed || original == null) return;
    final matchingBarber = barbers
        .where((item) => item.id == original.barberId)
        .firstOrNull;
    if (matchingBarber == null) return;
    await selectBarber(matchingBarber);
    if (_disposed) return;
    final matchingService = services
        .where((item) => item.id == original.serviceId)
        .firstOrNull;
    if (matchingService == null) return;
    if (original.start case final start?) {
      const fallback = 'America/Argentina/Buenos_Aires';
      final AgendaCalendar calendar;
      try {
        calendar = AgendaCalendar(original.zoneId ?? fallback);
      } on AgendaProblem {
        await selectService(matchingService);
        return;
      }
      offset =
          calendar.dateOf(start).isBefore(calendar.mondayFor(DateTime.now(), 1))
          ? 0
          : 1;
    }
    await selectService(matchingService);
    if (_disposed) return;
    final sameSlot = week?.slots
        .where(
          (item) =>
              item.start.microsecondsSinceEpoch ==
                  original.start?.microsecondsSinceEpoch &&
              item.end.microsecondsSinceEpoch ==
                  original.end?.microsecondsSinceEpoch,
        )
        .firstOrNull;
    if (sameSlot != null) selectSlot(sameSlot);
  }

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
    week = await _repository.loadWeek(
      barber!.id,
      service!.id,
      offset,
      editingId: _original?.id,
    );
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

  void setPhoto(Uint8List? bytes) {
    if (confirming || _disposed) return;
    photoBytes = bytes;
    _uploadedPhoto = null;
    _changeReference = true;
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
      final normalizedName = ConfirmBooking.normalizeName(name);
      final bytes = photoBytes;
      if (bytes != null) _uploadedPhoto ??= await _photos.upload(bytes);
      await _confirm(
        BookingRequest(
          id: _original?.id ?? (_requestId ??= _repository.newRequestId()),
          barberId: barber!.id,
          serviceId: service!.id,
          zoneId: week!.zoneId,
          slot: selected,
          clientName: normalizedName,
          referenceUrl: _uploadedPhoto,
          changeReference: _original == null || _changeReference,
        ),
        original: _original,
      );
      return true;
    } on BookingFailure catch (error) {
      failure = error;
      if (error == BookingFailure.unavailable ||
          error == BookingFailure.unpublished ||
          error == BookingFailure.serviceChanged ||
          error == BookingFailure.changed ||
          error == BookingFailure.notEditable) {
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
