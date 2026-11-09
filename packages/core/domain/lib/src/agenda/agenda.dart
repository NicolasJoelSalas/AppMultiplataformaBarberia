import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

enum AgendaFailure {
  permission,
  network,
  zone,
  weekChanged,
  changed,
  emptyDay,
  time,
  duration,
  overlap,
  zoneBookings,
  availability,
  operation,
}

class AgendaProblem implements Exception {
  const AgendaProblem(this.reason, {this.day});
  final AgendaFailure reason;
  final int? day;
}

class AgendaSpan {
  const AgendaSpan(this.start, this.end);

  final String start;
  final String end;

  static final _clockTime = RegExp(r'^([01][0-9]|2[0-3]):([0-5][0-9])$');

  static int? minutes(String value) {
    final match = _clockTime.firstMatch(value);
    if (match == null) return null;
    return int.parse(match[1]!) * 60 + int.parse(match[2]!);
  }
}

class AgendaDay {
  const AgendaDay({this.open = false, this.spans = const []});

  final bool open;
  final List<AgendaSpan> spans;
}

class AgendaWeek {
  AgendaWeek({
    required this.monday,
    required this.zoneId,
    required List<AgendaDay> days,
  }) : days = List.unmodifiable(days);

  /// A calendar date represented in UTC for date arithmetic, not an instant.
  final DateTime monday;
  final String zoneId;
  final List<AgendaDay> days;

  String get id => monday.toIso8601String().split('T').first;

  DateTime dateAt(int index) => monday.add(Duration(days: index));

  AgendaWeek withDay(int index, AgendaDay day) => AgendaWeek(
    monday: monday,
    zoneId: zoneId,
    days: [...days]..[index] = day,
  );

  bool sameSchedule(AgendaWeek other) =>
      days.length == other.days.length &&
      days.indexed.every((entry) {
        final (index, day) = entry;
        final previous = other.days[index];
        return day.open == previous.open &&
            day.spans.length == previous.spans.length &&
            day.spans.indexed.every((entry) {
              final (index, span) = entry;
              final before = previous.spans[index];
              return span.start == before.start && span.end == before.end;
            });
      });
}

final _locations = _loadLocations();

Map<String, tz.Location> _loadLocations() {
  tzdata.initializeTimeZones();
  return tz.timeZoneDatabase.locations;
}

class AgendaCalendar {
  factory AgendaCalendar(String zoneId) {
    final location = _locations[zoneId];
    if (location == null) throw const AgendaProblem(AgendaFailure.zone);
    return AgendaCalendar._(location);
  }

  const AgendaCalendar._(this._zone);

  final tz.Location _zone;

  DateTime dateOf(DateTime instant) {
    final local = tz.TZDateTime.from(instant, _zone);
    return DateTime.utc(local.year, local.month, local.day);
  }

  DateTime startOfDay(DateTime date) => _localTime(date, 0).native.toUtc();

  int minuteOfDay(DateTime instant) {
    final local = tz.TZDateTime.from(instant, _zone);
    return local.hour * 60 + local.minute;
  }

  DateTime mondayFor(DateTime instant, int offset) {
    if (offset < 0 || offset > 1) {
      throw const AgendaProblem(AgendaFailure.weekChanged);
    }
    final date = dateOf(instant);
    return date.add(
      Duration(days: 7 * offset - (date.weekday - DateTime.monday)),
    );
  }

  void requireCurrentWeek(DateTime monday, DateTime now) {
    if (monday != mondayFor(now, 0) && monday != mondayFor(now, 1)) {
      throw const AgendaProblem(AgendaFailure.weekChanged);
    }
  }

  List<AgendaAvailability> plan(AgendaWeek week) {
    if (week.days.length != 6) {
      throw const AgendaProblem(AgendaFailure.operation);
    }
    return [
      for (final (index, day) in week.days.indexed)
        _day(week.dateAt(index), day, index),
    ];
  }

  AgendaAvailability _day(DateTime date, AgendaDay day, int index) {
    final start = _localTime(date, 0);
    final end = _localTime(date.add(const Duration(days: 1)), 0);
    final length = end.difference(start).inMinutes;
    if (length < 1200 || length > 1560) {
      throw AgendaProblem(AgendaFailure.availability, day: index);
    }
    final mask = List.filled(length, '0');
    if (day.open) {
      if (day.spans.isEmpty) {
        throw AgendaProblem(AgendaFailure.emptyDay, day: index);
      }
      for (final span in day.spans) {
        final from = AgendaSpan.minutes(span.start);
        final to = AgendaSpan.minutes(span.end);
        if (from == null || to == null) {
          throw AgendaProblem(AgendaFailure.time, day: index);
        }
        if (to - from < 5) {
          throw AgendaProblem(AgendaFailure.duration, day: index);
        }
        final a = _localTime(date, from);
        final b = _localTime(date, to);
        if (a.hour * 60 + a.minute != from || b.hour * 60 + b.minute != to) {
          throw AgendaProblem(AgendaFailure.time, day: index);
        }
        final first = a.difference(start).inMinutes;
        final last = b.difference(start).inMinutes;
        if (first < 0 || last > length || last - first < 5) {
          throw AgendaProblem(AgendaFailure.duration, day: index);
        }
        if (mask.getRange(first, last).contains('1')) {
          throw AgendaProblem(AgendaFailure.overlap, day: index);
        }
        mask.fillRange(first, last, '1');
      }
    }
    return AgendaAvailability(
      start.native.toUtc(),
      end.native.toUtc(),
      mask.join(),
    );
  }

  tz.TZDateTime _localTime(DateTime date, int minute) {
    final local = tz.TZDateTime(
      _zone,
      date.year,
      date.month,
      date.day,
      minute ~/ 60,
      minute % 60,
    );
    // When clocks repeat an hour, use the earlier instant as java.time does.
    final previousOffset = tz.TZDateTime.from(
      local.subtract(const Duration(days: 1)),
      _zone,
    ).timeZoneOffset;
    final shift = previousOffset - local.timeZoneOffset;
    if (shift <= Duration.zero) return local;
    final earlier = local.subtract(shift);
    return earlier.year == date.year &&
            earlier.month == date.month &&
            earlier.day == date.day &&
            earlier.hour * 60 + earlier.minute == minute
        ? earlier
        : local;
  }
}

class AgendaAvailability {
  const AgendaAvailability(this.start, this.end, this.attention);

  final DateTime start;
  final DateTime end;
  final String attention;

  String get emptyOccupation => '0' * attention.length;

  bool containsStart(DateTime instant) =>
      !instant.isBefore(start) && instant.isBefore(end);

  bool includes(DateTime from, DateTime to) {
    final (first, last) = _indices(from, to);
    return !attention.substring(first, last).contains('0');
  }

  String occupy(String mask, DateTime from, DateTime to) =>
      _replace(mask, from, to, before: '0', after: '1');

  String release(String mask, DateTime from, DateTime to) =>
      _replace(mask, from, to, before: '1', after: '0');

  String _replace(
    String mask,
    DateTime from,
    DateTime to, {
    required String before,
    required String after,
  }) {
    final (first, last) = _indices(from, to);
    final count = last - first;
    if (mask.length != attention.length ||
        mask.substring(first, last) != before * count) {
      throw const AgendaProblem(AgendaFailure.availability);
    }
    return mask.replaceRange(first, last, after * count);
  }

  (int, int) _indices(DateTime from, DateTime to) {
    const minute = Duration.microsecondsPerMinute;
    final first = from.difference(start).inMicroseconds;
    final last = to.difference(start).inMicroseconds;
    if (first < 0 ||
        first >= last ||
        last > attention.length * minute ||
        first % minute != 0 ||
        last % minute != 0) {
      throw const AgendaProblem(AgendaFailure.availability);
    }
    return (first ~/ minute, last ~/ minute);
  }
}

abstract interface class AgendaRepository {
  Future<AgendaWeek> load(int offset);
  Future<void> save(AgendaWeek week);
  Future<void> publish(AgendaWeek week, List<AgendaAvailability> days);
}

class AgendaPublication {
  const AgendaPublication.published(this.spanCount) : problem = null;
  const AgendaPublication.pending(this.problem) : spanCount = null;

  final int? spanCount;
  final AgendaProblem? problem;
}

class SaveAndPublishAgenda {
  const SaveAndPublishAgenda(this.repository);

  final AgendaRepository repository;

  Future<AgendaPublication> call(AgendaWeek week) async {
    final days = AgendaCalendar(week.zoneId).plan(week);
    await repository.save(week);
    try {
      await repository.publish(week, days);
      final count = week.days.fold(
        0,
        (count, day) => count + (day.open ? day.spans.length : 0),
      );
      return AgendaPublication.published(count);
    } on AgendaProblem catch (problem) {
      return AgendaPublication.pending(problem);
    }
  }
}
