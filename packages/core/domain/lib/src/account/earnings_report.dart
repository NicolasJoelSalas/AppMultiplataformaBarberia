import '../agenda/agenda.dart';
import '../appointments/booking.dart';

enum EarningsPeriod { week, month }

class EarningsReport {
  const EarningsReport({
    required this.from,
    required this.through,
    required this.completed,
    required this.totalCents,
    required this.missingAmount,
  });

  static const zoneId = 'America/Argentina/Buenos_Aires';

  final DateTime from;
  final DateTime through;
  final List<Appointment> completed;
  final int totalCents;
  final int missingAmount;
}

class CalculateEarningsReport {
  const CalculateEarningsReport();

  EarningsReport call(
    Iterable<Appointment> appointments, {
    required DateTime now,
    required EarningsPeriod period,
    int offset = 0,
  }) {
    final calendar = AgendaCalendar(EarningsReport.zoneId);
    final today = calendar.dateOf(now);
    final from = switch (period) {
      EarningsPeriod.week =>
        calendar.mondayFor(now, 0).add(Duration(days: offset * 7)),
      EarningsPeriod.month => DateTime.utc(today.year, today.month + offset),
    };
    final until = switch (period) {
      EarningsPeriod.week => from.add(const Duration(days: 7)),
      EarningsPeriod.month => DateTime.utc(from.year, from.month + 1),
    };
    final firstInstant = calendar.startOfDay(from);
    final lastInstant = calendar.startOfDay(until);
    final completed = <Appointment>[];
    var total = 0;
    var missing = 0;
    for (final appointment in appointments) {
      final start = appointment.start;
      if (appointment.status != AppointmentStatus.completed ||
          start == null ||
          start.isBefore(firstInstant) ||
          !start.isBefore(lastInstant)) {
        continue;
      }
      completed.add(appointment);
      final amount = appointment.chargedPriceCents;
      if (amount == null || amount < 0) {
        missing++;
      } else {
        total += amount;
      }
    }
    completed.sort((a, b) => b.start!.compareTo(a.start!));
    return EarningsReport(
      from: from,
      through: until.subtract(const Duration(days: 1)),
      completed: List.unmodifiable(completed),
      totalCents: total,
      missingAmount: missing,
    );
  }
}
