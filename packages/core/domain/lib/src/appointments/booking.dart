import 'dart:typed_data';

import '../account/profile.dart';
import '../agenda/agenda.dart';
import '../services/barber_service.dart';

enum BookingFailure implements Exception {
  permission,
  network,
  unpublished,
  unavailable,
  serviceChanged,
  fields,
  notEditable,
  notCompletable,
  invalidServicePrice,
  changed,
  photoUnavailable,
  photoUpload,
  operation,
}

class BookingBarber {
  const BookingBarber(this.id, this.name);
  final String id;
  final String name;
}

class BookingService {
  const BookingService(this.id, this.name, this.minutes, this.priceCents);
  final String id;
  final String name;
  final int minutes;
  final int? priceCents;
}

class BookingSlot {
  const BookingSlot(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

class BookingWeek {
  const BookingWeek(this.monday, this.zoneId, this.slots);
  final DateTime monday;
  final String zoneId;
  final List<BookingSlot> slots;
}

class BookingDay {
  BookingDay(this.availability, this.occupation) {
    final attention = availability.attention;
    final length = availability.end.difference(availability.start);
    if (attention.length < 1200 ||
        attention.length > 1560 ||
        length != Duration(minutes: attention.length) ||
        occupation.length != attention.length ||
        !_bits.hasMatch(occupation) ||
        !_bits.hasMatch(attention)) {
      throw BookingFailure.unpublished;
    }
  }

  static final _bits = RegExp(r'^[01]+$');
  final AgendaAvailability availability;
  final String occupation;

  List<BookingSlot> availableSlots(
    int duration,
    DateTime now, {
    DateTime? preferred,
  }) {
    if (duration < ServiceDetails.minDuration ||
        duration > ServiceDetails.maxDuration) {
      throw BookingFailure.serviceChanged;
    }
    if (preferred != null && preferred.isAfter(now)) {
      final slot = BookingSlot(
        preferred,
        preferred.add(Duration(minutes: duration)),
      );
      try {
        final other = BookingDay(availability, reserve(slot));
        return [slot, ...other.availableSlots(duration, now)]
          ..sort((a, b) => a.start.compareTo(b.start));
      } on BookingFailure catch (error) {
        if (error != BookingFailure.unavailable) rethrow;
      }
    }
    final slots = <BookingSlot>[];
    final attention = availability.attention;
    bool free(int index) => attention[index] == '1' && occupation[index] == '0';
    var minute = 0;
    while (minute < attention.length) {
      if (!free(minute)) {
        minute++;
        continue;
      }
      final first = minute;
      while (minute < attention.length && free(minute)) {
        minute++;
      }
      for (var start = first; start + duration <= minute; start += duration) {
        final from = availability.start.add(Duration(minutes: start));
        if (from.isAfter(now)) {
          slots.add(BookingSlot(from, from.add(Duration(minutes: duration))));
        }
      }
    }
    return slots;
  }

  String reserve(BookingSlot slot) {
    try {
      if (availability.includes(slot.start, slot.end)) {
        return availability.occupy(occupation, slot.start, slot.end);
      }
    } on AgendaProblem {
      throw BookingFailure.unavailable;
    }
    throw BookingFailure.unavailable;
  }

  BookingDay release(BookingSlot slot) {
    try {
      return BookingDay(
        availability,
        availability.release(occupation, slot.start, slot.end),
      );
    } on AgendaProblem {
      throw BookingFailure.unpublished;
    }
  }
}

class BookingRequest {
  const BookingRequest({
    required this.id,
    required this.barberId,
    required this.serviceId,
    required this.zoneId,
    required this.slot,
    required this.clientName,
    this.referenceUrl,
    this.changeReference = false,
  });
  final String id;
  final String barberId;
  final String serviceId;
  final String zoneId;
  final BookingSlot slot;
  final String clientName;
  final String? referenceUrl;
  final bool changeReference;
}

enum AppointmentStatus { pending, canceled, completed, other }

bool canChangeAppointment(
  AppointmentStatus status,
  DateTime? start,
  DateTime? end,
  DateTime now,
) =>
    status == AppointmentStatus.pending &&
    start?.isAfter(now) == true &&
    end != null;

bool canCompleteAppointment(
  AppointmentStatus status,
  DateTime? start,
  DateTime now,
) => status == AppointmentStatus.pending && start?.isAfter(now) == false;

bool canBookAt(AgendaCalendar calendar, DateTime start, DateTime now) {
  final date = calendar.dateOf(start);
  final current = calendar.mondayFor(now, 0);
  return start.isAfter(now) &&
      !date.isBefore(current) &&
      date.isBefore(current.add(const Duration(days: 14))) &&
      date.weekday != DateTime.sunday;
}

bool shouldCancelAfterAgendaChange(
  AgendaAvailability day,
  AppointmentStatus status,
  DateTime start,
  DateTime end,
  DateTime now,
) =>
    status == AppointmentStatus.pending &&
    start.isAfter(now) &&
    day.containsStart(start) &&
    !day.includes(start, end);

class Appointment {
  const Appointment({
    required this.id,
    required this.serviceName,
    required this.participantName,
    required this.zoneId,
    required this.start,
    required this.end,
    required this.status,
    this.barberId = '',
    this.serviceId = '',
    this.referenceUrl,
    this.chargedPriceCents,
    this.referenceAvailable = true,
  });
  final String id;
  final String serviceName;
  final String participantName;
  final String? zoneId;
  final DateTime? start;
  final DateTime? end;
  final AppointmentStatus status;
  final String barberId;
  final String serviceId;
  final String? referenceUrl;
  final int? chargedPriceCents;

  final bool referenceAvailable;
  String? get visibleReferenceUrl => referenceAvailable ? referenceUrl : null;

  bool canChangeAt(DateTime now) =>
      canChangeAppointment(status, start, end, now);

  bool canCompleteAt(DateTime now) =>
      canCompleteAppointment(status, start, now);
}

abstract interface class BookingRepository {
  Future<List<BookingBarber>> loadBarbers();
  Future<List<BookingService>> loadServices(String barberId);
  Future<BookingWeek> loadWeek(
    String barberId,
    String serviceId,
    int offset, {
    String? editingId,
  });
  String newRequestId();
  Future<void> confirm(BookingRequest request, {Appointment? original});
  Future<void> cancel(String id);
  Future<void> complete(String id);
  Stream<List<Appointment>> watchAppointments(AccountRole role);
}

class CompleteAppointment {
  const CompleteAppointment(this.repository);
  final BookingRepository repository;

  Future<void> call(Appointment appointment, DateTime now) async {
    if (appointment.id.isEmpty || !appointment.canCompleteAt(now)) {
      throw BookingFailure.notCompletable;
    }
    await repository.complete(appointment.id);
  }
}

abstract interface class BookingPhotoRepository {
  Future<String> upload(Uint8List image);
}

class ConfirmBooking {
  const ConfirmBooking(this.repository);
  final BookingRepository repository;

  static String normalizeName(String value) {
    final name = value.trim();
    if (name.isEmpty || name.length > UpdateProfileNameUseCase.maxLength) {
      throw BookingFailure.fields;
    }
    return name;
  }

  Future<void> call(BookingRequest request, {Appointment? original}) async {
    final name = normalizeName(request.clientName);
    await repository.confirm(
      BookingRequest(
        id: request.id,
        barberId: request.barberId,
        serviceId: request.serviceId,
        zoneId: request.zoneId,
        slot: request.slot,
        clientName: name,
        referenceUrl: request.referenceUrl,
        changeReference: request.changeReference,
      ),
      original: original,
    );
  }
}
