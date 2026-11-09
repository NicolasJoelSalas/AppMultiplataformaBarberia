import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weeks and intervals use the barber calendar and preserve breaks', () {
    const zone = 'America/Argentina/Buenos_Aires';
    final calendar = AgendaCalendar(zone);
    // 01:00 UTC on Monday is still Sunday in Buenos Aires.
    final now = DateTime.utc(2026, 11, 9, 1);
    expect(calendar.mondayFor(now, 0), DateTime.utc(2026, 11, 2));
    final monday = calendar.mondayFor(now, 1);
    final week = AgendaWeek(
      monday: monday,
      zoneId: zone,
      days: const [
        AgendaDay(
          open: true,
          spans: [AgendaSpan('09:00', '12:00'), AgendaSpan('13:00', '18:00')],
        ),
        AgendaDay(),
        AgendaDay(),
        AgendaDay(),
        AgendaDay(),
        AgendaDay(),
      ],
    );
    final day = calendar.plan(week).first;
    final start = DateTime.utc(2026, 11, 9, 12);
    final end = DateTime.utc(2026, 11, 9, 13);
    expect(day.start, DateTime.utc(2026, 11, 9, 3));
    expect(day.includes(start, end), isTrue);
    expect(
      day.includes(
        DateTime.utc(2026, 11, 9, 14, 30),
        DateTime.utc(2026, 11, 9, 15, 30),
      ),
      isFalse,
    );
    final occupied = day.occupy(day.emptyOccupation, start, end);
    expect(day.release(occupied, start, end), day.emptyOccupation);

    expect(
      () => calendar.plan(
        week.withDay(
          0,
          const AgendaDay(
            open: true,
            spans: [AgendaSpan('09:00', '11:00'), AgendaSpan('10:30', '13:00')],
          ),
        ),
      ),
      throwsA(
        isA<AgendaProblem>().having(
          (p) => p.reason,
          'reason',
          AgendaFailure.overlap,
        ),
      ),
    );
  });

  test('a weekday with a forward clock change has only its real minutes', () {
    const zone = 'Asia/Jerusalem';
    final week = AgendaWeek(
      monday: DateTime.utc(2024, 3, 25),
      zoneId: zone,
      days: List.filled(6, const AgendaDay()),
    );
    final calendar = AgendaCalendar(zone);
    expect(calendar.plan(week)[4].attention.length, 23 * 60);
    expect(
      () => calendar.plan(
        week.withDay(
          4,
          const AgendaDay(open: true, spans: [AgendaSpan('02:15', '04:00')]),
        ),
      ),
      throwsA(
        isA<AgendaProblem>().having(
          (p) => p.reason,
          'reason',
          AgendaFailure.time,
        ),
      ),
    );
  });
}
