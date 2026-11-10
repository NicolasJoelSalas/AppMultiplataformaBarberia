import '../account/profile.dart';
import 'booking.dart';

abstract interface class AppointmentAlertRepository {
  Stream<void> watchAppointmentAlertChanges(AccountRole role, String uid);
  Future<List<AppointmentAlertRecord>> loadAppointmentAlertRecords(
    AccountRole role,
    String uid,
  );
}

class AppointmentAlertRecord {
  const AppointmentAlertRecord({
    required this.id,
    required this.clientId,
    required this.barberId,
    required this.serviceId,
    required this.start,
    required this.end,
    required this.status,
    required this.canceledBy,
    required this.referenceUrl,
  });

  final String id;
  final String clientId;
  final String barberId;
  final String serviceId;
  final DateTime? start;
  final DateTime? end;
  final AppointmentStatus status;
  final String? canceledBy;
  final String? referenceUrl;

  bool sameSchedule(AppointmentAlertRecord other) =>
      barberId == other.barberId &&
      serviceId == other.serviceId &&
      start?.millisecondsSinceEpoch == other.start?.millisecondsSinceEpoch &&
      end?.millisecondsSinceEpoch == other.end?.millisecondsSinceEpoch;

  bool sameBooking(AppointmentAlertRecord other) =>
      sameSchedule(other) &&
      clientId == other.clientId &&
      status == other.status &&
      referenceUrl == other.referenceUrl;
}

enum AppointmentChange { booked, updated, canceled }

enum AppointmentNotice {
  reminder,
  booked,
  updated,
  canceled;

  static AppointmentNotice fromChange(AppointmentChange change) =>
      switch (change) {
        AppointmentChange.booked => booked,
        AppointmentChange.updated => updated,
        AppointmentChange.canceled => canceled,
      };
}

Map<String, AppointmentChange> appointmentChanges(
  List<AppointmentAlertRecord> previous,
  List<AppointmentAlertRecord> current,
  AccountRole role,
  String uid,
  DateTime now,
) {
  final before = {for (final item in previous) item.id: item};
  final after = {for (final item in current) item.id: item};
  final changes = <String, AppointmentChange>{};
  for (final item in current) {
    final old = before[item.id];
    if (item.start?.isAfter(now) != true) continue;
    if (item.status == AppointmentStatus.canceled) {
      if (old?.status == AppointmentStatus.pending && item.canceledBy != uid) {
        changes[item.id] = AppointmentChange.canceled;
      }
    } else if (item.status == AppointmentStatus.pending) {
      if (old == null && role == AccountRole.barber) {
        changes[item.id] = AppointmentChange.booked;
      } else if (old != null &&
          (role == AccountRole.barber
              ? !item.sameBooking(old)
              : !item.sameSchedule(old))) {
        changes[item.id] = AppointmentChange.updated;
      }
    }
  }
  for (final old in previous) {
    if (!after.containsKey(old.id) &&
        old.status == AppointmentStatus.pending &&
        old.start?.isAfter(now) == true) {
      changes[old.id] = AppointmentChange.canceled;
    }
  }
  return changes;
}

class AppointmentReminder {
  const AppointmentReminder(
    this.appointmentId,
    this.start,
    this.at,
    this.hours,
  );
  final String appointmentId;
  final DateTime start;
  final DateTime at;
  final int hours;
}

List<AppointmentReminder> upcomingAppointmentReminders(
  List<AppointmentAlertRecord> appointments,
  DateTime now, {
  bool includeElapsed = false,
}) => [
  for (final item in appointments)
    if (item.status == AppointmentStatus.pending &&
        item.start?.isAfter(now) == true)
      for (final hours in const [24, 1])
        if (includeElapsed ||
            item.start!.subtract(Duration(hours: hours)).isAfter(now))
          AppointmentReminder(
            item.id,
            item.start!,
            item.start!.subtract(Duration(hours: hours)),
            hours,
          ),
];
