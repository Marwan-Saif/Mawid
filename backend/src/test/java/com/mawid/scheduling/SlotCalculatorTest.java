package com.mawid.scheduling;

import static org.assertj.core.api.Assertions.assertThat;

import com.mawid.scheduling.SlotCalculator.Interval;
import com.mawid.scheduling.SlotCalculator.Slot;
import com.mawid.scheduling.SlotCalculator.StaffSchedule;
import com.mawid.scheduling.SlotCalculator.WorkingHours;
import java.time.DayOfWeek;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;

class SlotCalculatorTest {

    private static final ZoneId DUBAI = ZoneId.of("Asia/Dubai");
    private static final ZoneId CAIRO = ZoneId.of("Africa/Cairo");
    private static final LocalDate THURSDAY = LocalDate.of(2026, 11, 5);
    private static final WorkingHours TEN_TO_NOON =
            new WorkingHours(LocalTime.of(10, 0), LocalTime.of(12, 0), Set.of(DayOfWeek.FRIDAY));
    private static final Instant LONG_AGO = Instant.parse("2026-01-01T00:00:00Z");

    private static Instant dubai(int h, int m) {
        return THURSDAY.atTime(h, m).atZone(DUBAI).toInstant();
    }

    private static StaffSchedule busy(long id, Instant start, int minutes) {
        return new StaffSchedule(id, Set.of(), List.of(new Interval(start, start.plus(Duration.ofMinutes(minutes)))));
    }

    @Test
    void offersEveryQuarterWhereTheServiceFitsBeforeClosing() {
        List<Slot> slots = SlotCalculator.slotsFor(THURSDAY, DUBAI, TEN_TO_NOON, 45,
                List.of(new StaffSchedule(1, Set.of(), List.of())), LONG_AGO);

        assertThat(slots).extracting(s -> s.localTime().toString())
                .containsExactly("10:00", "10:15", "10:30", "10:45", "11:00", "11:15");
    }

    @Test
    void slotIsTakenWhenItOverlapsAnExistingBooking() {
        List<Slot> slots = SlotCalculator.slotsFor(THURSDAY, DUBAI, TEN_TO_NOON, 45,
                List.of(busy(1, dubai(10, 30), 45)), LONG_AGO);

        assertThat(slots).filteredOn(Slot::available).extracting(s -> s.localTime().toString())
                .containsExactly("11:15");
    }

    @Test
    void anyAvailableUsesTheOtherStaffMember() {
        List<Slot> slots = SlotCalculator.slotsFor(THURSDAY, DUBAI, TEN_TO_NOON, 45,
                List.of(busy(1, dubai(10, 0), 120), new StaffSchedule(2, Set.of(), List.of())), LONG_AGO);

        assertThat(slots).allMatch(s -> s.freeStaffIds().equals(List.of(2L)));
    }

    @Test
    void staffOnTheirDayOffAreNeverOffered() {
        StaffSchedule off = new StaffSchedule(1, Set.of(DayOfWeek.THURSDAY), List.of());
        assertThat(SlotCalculator.slotsFor(THURSDAY, DUBAI, TEN_TO_NOON, 45, List.of(off), LONG_AGO))
                .noneMatch(Slot::available);
    }

    @Test
    void closedDaysHaveNoSlots() {
        assertThat(SlotCalculator.slotsFor(THURSDAY.plusDays(1), DUBAI, TEN_TO_NOON, 45,
                List.of(new StaffSchedule(1, Set.of(), List.of())), LONG_AGO)).isEmpty();
    }

    @Test
    void pastSlotsAreShownButNotBookable() {
        Instant now = dubai(10, 40);
        List<Slot> slots = SlotCalculator.slotsFor(THURSDAY, DUBAI, TEN_TO_NOON, 30,
                List.of(new StaffSchedule(1, Set.of(), List.of())), now);

        assertThat(slots).filteredOn(Slot::available).first()
                .extracting(s -> s.localTime().toString()).isEqualTo("10:45");
    }

    @Test
    void workingHoursAreLocalToThePlace() {
        // 10:00 in Dubai is 06:00 UTC; the same wall-clock hour in Cairo is a different instant.
        Slot first = SlotCalculator.slotsFor(THURSDAY, DUBAI, TEN_TO_NOON, 30,
                List.of(new StaffSchedule(1, Set.of(), List.of())), LONG_AGO).get(0);
        Slot cairoFirst = SlotCalculator.slotsFor(THURSDAY, CAIRO, TEN_TO_NOON, 30,
                List.of(new StaffSchedule(1, Set.of(), List.of())), LONG_AGO).get(0);

        assertThat(first.startAt()).isEqualTo(Instant.parse("2026-11-05T06:00:00Z"));
        assertThat(cairoFirst.startAt()).isAfter(first.startAt());
    }

    @Test
    void lockUnitsCoverTheWholeServiceRoundedUp() {
        assertThat(SlotCalculator.lockUnits(dubai(10, 0), 45)).hasSize(3);
        assertThat(SlotCalculator.lockUnits(dubai(10, 0), 50)).hasSize(4);
        assertThat(SlotCalculator.lockUnits(dubai(10, 0), 15)).containsExactly(dubai(10, 0));
    }

    @Test
    void customersCanChangeUpToThreeHoursBefore() {
        Instant start = dubai(15, 0);
        assertThat(SlotCalculator.customerCanChange(start, dubai(12, 0))).isTrue();
        assertThat(SlotCalculator.customerCanChange(start, dubai(12, 1))).isFalse();
    }

    @Test
    void fitsWorkingHoursRejectsServicesThatRunPastClosing() {
        assertThat(SlotCalculator.fitsWorkingHours(dubai(11, 15), 45, DUBAI, TEN_TO_NOON)).isTrue();
        assertThat(SlotCalculator.fitsWorkingHours(dubai(11, 30), 45, DUBAI, TEN_TO_NOON)).isFalse();
        assertThat(SlotCalculator.fitsWorkingHours(dubai(9, 45), 30, DUBAI, TEN_TO_NOON)).isFalse();
    }
}
