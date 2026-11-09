import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

Appointment _turn(
  String id,
  DateTime? start,
  int? cents, {
  AppointmentStatus status = AppointmentStatus.completed,
}) => Appointment(
  id: id,
  serviceName: 'Corte',
  participantName: 'Cliente',
  zoneId: 'UTC',
  start: start,
  end: null,
  status: status,
  chargedPriceCents: cents,
);

void main() {
  const calculate = CalculateEarningsReport();

  test(
    'weekly earnings use Buenos Aires boundaries and sum recorded cents only',
    () {
      final result = calculate(
        [
          _turn('first', DateTime.utc(2026, 11, 2, 3), 1250050),
          _turn('last', DateTime.utc(2026, 11, 9, 2, 59), 29),
          _turn('zero', DateTime.utc(2026, 11, 4), 0),
          _turn('missing', DateTime.utc(2026, 11, 5), null),
          _turn('negative', DateTime.utc(2026, 11, 6), -1),
          _turn(
            'pending',
            DateTime.utc(2026, 11, 7),
            9000,
            status: AppointmentStatus.pending,
          ),
          _turn(
            'canceled',
            DateTime.utc(2026, 11, 8),
            9000,
            status: AppointmentStatus.canceled,
          ),
          _turn('before', DateTime.utc(2026, 11, 2, 2, 59), 9000),
          _turn('after', DateTime.utc(2026, 11, 9, 3), 9000),
          _turn('no-date', null, 9000),
        ],
        now: DateTime.utc(2026, 11, 9, 1),
        period: EarningsPeriod.week,
      );
      expect(result.from, DateTime.utc(2026, 11, 2));
      expect(result.through, DateTime.utc(2026, 11, 8));
      expect(result.totalCents, 1250079);
      expect(result.missingAmount, 2);
      expect(result.completed.map((item) => item.id), [
        'last',
        'negative',
        'missing',
        'zero',
        'first',
      ]);
    },
  );

  test(
    'the previous monthly period crosses years and ends at local midnight',
    () {
      final result = calculate(
        [
          _turn('december', DateTime.utc(2027, 1, 1, 2, 59), 5),
          _turn('january', DateTime.utc(2027, 1, 1, 3), 10),
        ],
        now: DateTime.utc(2027, 1, 15),
        period: EarningsPeriod.month,
        offset: -1,
      );
      expect(result.from, DateTime.utc(2026, 12));
      expect(result.through, DateTime.utc(2026, 12, 31));
      expect(result.totalCents, 5);
      expect(result.completed.single.id, 'december');
    },
  );
}
