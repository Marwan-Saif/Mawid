import 'package:flutter_test/flutter_test.dart';
import 'package:mawid/features/booking/domain/services/slot_calculator.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../helpers/test_setup.dart';

void main() {
  setUpAll(initTestEnvironment);

  const calc = SlotCalculator();
  const tenToNoon = WorkingHours(openMinutes: 600, closeMinutes: 720, closedDays: {DateTime.friday});
  final longAgo = DateTime.utc(2026, 1, 1);

  // Thursday 5 Nov 2026 in Dubai.
  DateTime dubai(int h, int m) => tz.TZDateTime(tz.getLocation('Asia/Dubai'), 2026, 11, 5, h, m).toUtc();

  List<String> times(List slots) => slots.map((s) {
        final local = tz.TZDateTime.from(s.startAt as DateTime, tz.getLocation('Asia/Dubai'));
        return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      }).toList();

  List run({
    int duration = 45,
    List<StaffSchedule>? staff,
    DateTime? now,
    int day = 5,
    String timezone = 'Asia/Dubai',
  }) =>
      calc.slotsFor(
        year: 2026,
        month: 11,
        day: day,
        timezone: timezone,
        hours: tenToNoon,
        durationMinutes: duration,
        staff: staff ?? const [StaffSchedule(staffId: '1', daysOff: {}, busy: [])],
        nowUtc: now ?? longAgo,
      );

  test('offers every 15 minutes while the service still fits before closing', () {
    expect(times(run()), ['10:00', '10:15', '10:30', '10:45', '11:00', '11:15']);
  });

  test('a slot is booked when it overlaps an existing booking', () {
    final slots = run(staff: [
      StaffSchedule(staffId: '1', daysOff: const {}, busy: [BusyInterval(dubai(10, 30), dubai(11, 15))]),
    ]);
    expect(times(slots.where((s) => s.available).toList()), ['11:15']);
  });

  test('"anyone available" falls back to the other staff member', () {
    final slots = run(staff: [
      StaffSchedule(staffId: '1', daysOff: const {}, busy: [BusyInterval(dubai(10, 0), dubai(12, 0))]),
      const StaffSchedule(staffId: '2', daysOff: {}, busy: []),
    ]);
    expect(slots.every((s) => s.freeStaffIds.length == 1 && s.freeStaffIds.first == '2'), isTrue);
  });

  test('staff on their day off are never offered', () {
    final slots = run(staff: const [StaffSchedule(staffId: '1', daysOff: {DateTime.thursday}, busy: [])]);
    expect(slots.any((s) => s.available), isFalse);
  });

  test('closed days have no slots', () {
    expect(run(day: 6), isEmpty); // Friday
  });

  test('past times are shown but not bookable', () {
    final slots = run(duration: 30, now: dubai(10, 40));
    expect(times(slots.where((s) => s.available).toList()).first, '10:45');
  });

  test('working hours are local to the place (Dubai vs Cairo)', () {
    final first = run(duration: 30).first.startAt;
    expect(first, DateTime.utc(2026, 11, 5, 6)); // 10:00 Dubai = 06:00 UTC
    final cairo = run(duration: 30, timezone: 'Africa/Cairo').first.startAt;
    expect(cairo.isAfter(first), isTrue);
  });

  test('lock units cover the whole service, rounded up', () {
    expect(SlotCalculator.lockUnits(dubai(10, 0), 45), hasLength(3));
    expect(SlotCalculator.lockUnits(dubai(10, 0), 50), hasLength(4));
  });

  test('customers can change up to 3 hours before', () {
    expect(SlotCalculator.customerCanChange(dubai(15, 0), dubai(12, 0)), isTrue);
    expect(SlotCalculator.customerCanChange(dubai(15, 0), dubai(12, 1)), isFalse);
  });

  test('fitsWorkingHours rejects services that run past closing', () {
    expect(SlotCalculator.fitsWorkingHours(dubai(11, 15), 45, 'Asia/Dubai', tenToNoon), isTrue);
    expect(SlotCalculator.fitsWorkingHours(dubai(11, 30), 45, 'Asia/Dubai', tenToNoon), isFalse);
  });
}
