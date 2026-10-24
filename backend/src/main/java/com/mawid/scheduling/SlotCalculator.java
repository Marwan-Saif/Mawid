package com.mawid.scheduling;

import java.time.DayOfWeek;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * Pure scheduling math, no Spring and no database.
 *
 * <p>The day is cut into 15-minute units. A slot is a possible start time inside working hours
 * where the whole service fits before closing. A slot is available when at least one staff
 * member who does the service is working that day and has no booking overlapping
 * {@code [start, start + duration)}.
 *
 * <p>All instants are UTC; the place's {@link ZoneId} turns local working hours into instants,
 * so a customer in Cairo booking a salon in Dubai sees the salon's hours.
 */
public final class SlotCalculator {

    public static final int UNIT_MINUTES = 15;
    /** Customers can cancel or reschedule until this long before the appointment. */
    public static final Duration CHANGE_CUTOFF = Duration.ofHours(3);

    private SlotCalculator() {
    }

    public record Interval(Instant start, Instant end) {
        public boolean overlaps(Instant otherStart, Instant otherEnd) {
            return start.isBefore(otherEnd) && otherStart.isBefore(end);
        }
    }

    /** One staff member who can do the requested service, with their busy time that day. */
    public record StaffSchedule(long staffId, Set<DayOfWeek> daysOff, List<Interval> busy) {
        boolean isFree(LocalDate date, Instant start, Instant end) {
            if (daysOff.contains(date.getDayOfWeek())) {
                return false;
            }
            for (Interval b : busy) {
                if (b.overlaps(start, end)) {
                    return false;
                }
            }
            return true;
        }
    }

    public record WorkingHours(LocalTime open, LocalTime close, Set<DayOfWeek> closedDays) {
        public boolean isOpenOn(LocalDate date) {
            return !closedDays.contains(date.getDayOfWeek()) && open.isBefore(close);
        }
    }

    public record Slot(Instant startAt, LocalTime localTime, List<Long> freeStaffIds) {
        public boolean available() {
            return !freeStaffIds.isEmpty();
        }
    }

    /**
     * Every 15-minute start time for {@code date} in the place's zone, with the staff free for it.
     * Slots that start at or before {@code now} are returned as unavailable so the grid stays stable.
     */
    public static List<Slot> slotsFor(LocalDate date,
                                      ZoneId zone,
                                      WorkingHours hours,
                                      int durationMinutes,
                                      List<StaffSchedule> staff,
                                      Instant now) {
        List<Slot> result = new ArrayList<>();
        if (durationMinutes <= 0 || !hours.isOpenOn(date)) {
            return result;
        }
        LocalDateTime cursor = date.atTime(hours.open());
        LocalDateTime lastStart = date.atTime(hours.close()).minusMinutes(durationMinutes);
        while (!cursor.isAfter(lastStart)) {
            Instant start = cursor.atZone(zone).toInstant();
            Instant end = start.plus(Duration.ofMinutes(durationMinutes));
            List<Long> free = new ArrayList<>();
            if (start.isAfter(now)) {
                for (StaffSchedule s : staff) {
                    if (s.isFree(date, start, end)) {
                        free.add(s.staffId());
                    }
                }
            }
            result.add(new Slot(start, cursor.toLocalTime(), List.copyOf(free)));
            cursor = cursor.plusMinutes(UNIT_MINUTES);
        }
        return result;
    }

    /** The 15-minute lock units a booking occupies: a 45-minute service holds 3 units. */
    public static List<Instant> lockUnits(Instant start, int durationMinutes) {
        int units = (int) Math.ceil(durationMinutes / (double) UNIT_MINUTES);
        Instant aligned = alignDown(start);
        List<Instant> result = new ArrayList<>(units);
        for (int i = 0; i < units; i++) {
            result.add(aligned.plus(Duration.ofMinutes((long) UNIT_MINUTES * i)));
        }
        return result;
    }

    public static Instant alignDown(Instant t) {
        long unitSeconds = UNIT_MINUTES * 60L;
        long epoch = t.getEpochSecond();
        return Instant.ofEpochSecond(epoch - Math.floorMod(epoch, unitSeconds));
    }

    /** True when the time is a 15-minute boundary (slots are only offered on those). */
    public static boolean isAligned(Instant t) {
        return t.getNano() == 0 && Math.floorMod(t.getEpochSecond(), UNIT_MINUTES * 60L) == 0;
    }

    /** Whether a customer may still cancel or move the appointment. */
    public static boolean customerCanChange(Instant startAt, Instant now) {
        return !Duration.between(now, startAt).minus(CHANGE_CUTOFF).isNegative();
    }

    /** Whether a single start time fits inside working hours for the given duration. */
    public static boolean fitsWorkingHours(Instant start, int durationMinutes, ZoneId zone, WorkingHours hours) {
        LocalDateTime local = LocalDateTime.ofInstant(start, zone);
        LocalDate date = local.toLocalDate();
        if (!hours.isOpenOn(date)) {
            return false;
        }
        LocalDateTime open = date.atTime(hours.open());
        LocalDateTime close = date.atTime(hours.close());
        return !local.isBefore(open) && !local.plusMinutes(durationMinutes).isAfter(close);
    }
}
