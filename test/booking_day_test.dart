import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final midnight = DateTime.utc(2026, 11, 9, 3);
  DateTime at(int hour, [int minute = 0]) =>
      midnight.add(Duration(hours: hour, minutes: minute));
  final agenda = AgendaAvailability(
    midnight,
    at(24),
    '0' * 540 + '1' * 180 + '0' * 60 + '1' * 300 + '0' * 360,
  );

  test('fits the whole service within published and free minutes', () {
    final day = BookingDay(agenda, agenda.emptyOccupation);
    final slots = day.availableSlots(75, at(9));
    expect(slots.map((slot) => slot.start), [
      at(10, 15),
      at(13),
      at(14, 15),
      at(15, 30),
      at(16, 45),
    ]);
    expect(slots.last.end, at(18));
    expect(
      () => day.reserve(BookingSlot(at(11, 30), at(12, 10))),
      throwsA(BookingFailure.unavailable),
    );
  });

  test('a new service duration cannot reuse any already occupied minutes', () {
    final first = BookingDay(agenda, agenda.emptyOccupation);
    final occupied = first.reserve(BookingSlot(at(9), at(10, 15)));
    final updated = BookingDay(agenda, occupied);
    expect(occupied.substring(540, 615), '1' * 75);
    expect(updated.availableSlots(40, at(8)).first.start, at(10, 15));
    expect(
      () => updated.reserve(BookingSlot(at(10), at(10, 40))),
      throwsA(BookingFailure.unavailable),
    );
  });
}
