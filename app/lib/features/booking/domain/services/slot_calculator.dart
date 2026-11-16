import 'package:timezone/timezone.dart' as tz;

import '../entities/time_slot.dart';

/// A busy period of one staff member (UTC).
class BusyInterval {
  const BusyInterval(this.start, this.end);

  final DateTime start;
  final DateTime end;

  bool overlaps(DateTime otherStart, DateTime otherEnd) => start.isBefore(otherEnd) && otherStart.isBefore(end);
}

class StaffSchedule {
  const StaffSchedule({required this.staffId, required this.daysOff, required this.busy});

  final String staffId;

  /// ISO weekdays (1 = Monday ... 7 = Sunday).
  final Set<int> daysOff;
  final List<BusyInterval> busy;
}

class WorkingHours {
  const WorkingHours({
    required this.openMinutes,
    required this.closeMinutes,
    required this.closedDays,
  });

  /// Minutes after local midnight.
  final int openMinutes;
  final int closeMinutes;
  final Set<int> closedDays;
}

/// Pure Dart scheduling math: the same rules as the Spring API's SlotCalculator, so the offline
/// demo and the real backend agree. No Flutter, no Firebase, no HTTP: tested on its own.
///
/// - The day is cut into 15-minute units.
/// - A slot is a start time where the whole service fits before closing.
/// - It is available if at least one staff member who does the service is working that day
///   and has nothing overlapping [start, start + duration).
/// - Working hours are local to the place's timezone; results are UTC.
class SlotCalculator {
  const SlotCalculator();

  static const int unitMinutes = 15;
  static const Duration changeCutoff = Duration(hours: 3);

  List<TimeSlot> slotsFor({
    required int year,
    required int month,
    required int day,
    required String timezone,
    required WorkingHours hours,
    required int durationMinutes,
    required List<StaffSchedule> staff,
    required DateTime nowUtc,
  }) {
    final location = tz.getLocation(timezone);
    final weekday = DateTime.utc(year, month, day).weekday;
    if (durationMinutes <= 0 || hours.closedDays.contains(weekday) || hours.openMinutes >= hours.closeMinutes) {
      return const [];
    }
    final slots = <TimeSlot>[];
    for (var m = hours.openMinutes; m + durationMinutes <= hours.closeMinutes; m += unitMinutes) {
      final local = tz.TZDateTime(location, year, month, day, m ~/ 60, m % 60);
      final start = local.toUtc();
      final end = start.add(Duration(minutes: durationMinutes));
      final free = <String>[];
      if (start.isAfter(nowUtc.toUtc())) {
        for (final s in staff) {
          if (s.daysOff.contains(weekday)) continue;
          if (s.busy.any((b) => b.overlaps(start, end))) continue;
          free.add(s.staffId);
        }
      }
      slots.add(TimeSlot(startAt: start, freeStaffIds: List.unmodifiable(free)));
    }
    return slots;
  }

  /// The 15-minute units a booking holds: a 45-minute service holds 3.
  static List<DateTime> lockUnits(DateTime startUtc, int durationMinutes) {
    final units = (durationMinutes / unitMinutes).ceil();
    final aligned = alignDown(startUtc);
    return List.generate(units, (i) => aligned.add(Duration(minutes: unitMinutes * i)));
  }

  static DateTime alignDown(DateTime t) {
    final ms = t.toUtc().millisecondsSinceEpoch;
    const unitMs = unitMinutes * 60 * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms - ms % unitMs, isUtc: true);
  }

  static bool customerCanChange(DateTime startUtc, DateTime nowUtc) =>
      startUtc.toUtc().difference(nowUtc.toUtc()) >= changeCutoff;

  /// Whether [startUtc] for [durationMinutes] fits inside the place's working hours.
  static bool fitsWorkingHours(DateTime startUtc, int durationMinutes, String timezone, WorkingHours hours) {
    final local = tz.TZDateTime.from(startUtc.toUtc(), tz.getLocation(timezone));
    if (hours.closedDays.contains(local.weekday)) return false;
    final startMin = local.hour * 60 + local.minute;
    return startMin >= hours.openMinutes && startMin + durationMinutes <= hours.closeMinutes;
  }
}
