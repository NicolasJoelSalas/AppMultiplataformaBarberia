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

  List<BookingSlot> availableSlots(int duration, DateTime now) {
    if (duration < ServiceDetails.minDuration ||
        duration > ServiceDetails.maxDuration) {
      throw BookingFailure.serviceChanged;
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
}

class BookingRequest {
  const BookingRequest({
    required this.id,
    required this.barberId,
    required this.serviceId,
    required this.zoneId,
    required this.slot,
    required this.clientName,
  });
  final String id;
  final String barberId;
  final String serviceId;
  final String zoneId;
  final BookingSlot slot;
  final String clientName;
}

enum AppointmentStatus {
  pending,
  canceled,
  completed,
  other;

  static AppointmentStatus fromStored(Object? value) =>
      switch (value.toString().toLowerCase()) {
        'true' || 'confirmado' || 'pendiente' => pending,
        'false' || 'cancelado' || 'cancelada' => canceled,
        'realizado' || 'completado' => completed,
        _ => other,
      };
}

class Appointment {
  const Appointment({
    required this.id,
    required this.serviceName,
    required this.participantName,
    required this.zoneId,
    required this.start,
    required this.end,
    required this.status,
  });
  final String id;
  final String serviceName;
  final String participantName;
  final String? zoneId;
  final DateTime? start;
  final DateTime? end;
  final AppointmentStatus status;
}

abstract interface class BookingRepository {
  Future<List<BookingBarber>> loadBarbers();
  Future<List<BookingService>> loadServices(String barberId);
  Future<BookingWeek> loadWeek(String barberId, String serviceId, int offset);
  String newRequestId();
  Future<void> confirm(BookingRequest request);
  Stream<List<Appointment>> watchAppointments(AccountRole role);
}

class ConfirmBooking {
  const ConfirmBooking(this.repository);
  final BookingRepository repository;

  Future<void> call(BookingRequest request) async {
    final name = request.clientName.trim();
    if (name.isEmpty || name.length > UpdateProfileNameUseCase.maxLength) {
      throw BookingFailure.fields;
    }
    await repository.confirm(
      BookingRequest(
        id: request.id,
        barberId: request.barberId,
        serviceId: request.serviceId,
        zoneId: request.zoneId,
        slot: request.slot,
        clientName: name,
      ),
    );
  }
}
