package com.mawid.scheduling;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Estimates when each waiting person will actually go in, per doctor or stylist.
 *
 * <p>Pure: no Spring, no database, so the same rules are unit-tested here and copied 1:1 into the
 * app's offline demo backend. The model is the one a receptionist uses in their head:
 * <ul>
 *   <li>Whoever is in the room now finishes at {@code startedAt + duration}; if that time has
 *       passed, assume a few more minutes ({@link #OVERRUN_PADDING}).</li>
 *   <li>Then people go in by their booked time, never before it.</li>
 *   <li>Someone who booked but hasn't arrived, and is more than {@link #NO_SHOW_GRACE} late, is
 *       flagged {@code late} and doesn't hold up the people behind them.</li>
 * </ul>
 */
public final class QueueEstimator {

    public static final Duration NO_SHOW_GRACE = Duration.ofMinutes(15);
    public static final Duration OVERRUN_PADDING = Duration.ofMinutes(5);

    private QueueEstimator() {
    }

    public enum State { BOOKED, ARRIVED, IN_ROOM }

    public record Visit(long id, long staffId, Instant scheduledStart, int durationMin, State state,
                        Instant startedAt) {
    }

    /**
     * @param expectedStart when they go in (for IN_ROOM: when they went in)
     * @param delayMin      minutes after their booked time (0 = on time)
     * @param ahead         people before them with the same staff member, including whoever is in the room
     * @param late          booked, not here, and past the grace period
     */
    public record Estimate(long id, Instant expectedStart, int delayMin, int ahead, boolean late) {
    }

    public static Map<Long, Estimate> estimate(List<Visit> visits, Instant now) {
        Map<Long, Estimate> result = new HashMap<>();
        Map<Long, List<Visit>> byStaff = visits.stream().collect(Collectors.groupingBy(Visit::staffId));
        for (List<Visit> list : byStaff.values()) {
            List<Visit> sorted = new ArrayList<>(list);
            sorted.sort(Comparator.comparing(Visit::scheduledStart).thenComparingLong(Visit::id));

            Instant cursor = now;
            int ahead = 0;
            for (Visit v : sorted) {
                if (v.state() != State.IN_ROOM) {
                    continue;
                }
                Instant began = v.startedAt() != null ? v.startedAt() : v.scheduledStart();
                Instant end = began.plus(Duration.ofMinutes(v.durationMin()));
                if (!end.isAfter(now)) {
                    end = now.plus(OVERRUN_PADDING);
                }
                if (end.isAfter(cursor)) {
                    cursor = end;
                }
                result.put(v.id(), new Estimate(v.id(), began, minutesBetween(v.scheduledStart(), began), 0, false));
                ahead++;
            }
            for (Visit v : sorted) {
                if (v.state() == State.IN_ROOM) {
                    continue;
                }
                boolean late = v.state() == State.BOOKED && v.scheduledStart().plus(NO_SHOW_GRACE).isBefore(now);
                Instant expected = cursor.isAfter(v.scheduledStart()) ? cursor : v.scheduledStart();
                result.put(v.id(), new Estimate(v.id(), expected, minutesBetween(v.scheduledStart(), expected),
                        ahead, late));
                if (!late) {
                    cursor = expected.plus(Duration.ofMinutes(v.durationMin()));
                    ahead++;
                }
            }
        }
        return result;
    }

    private static int minutesBetween(Instant scheduled, Instant actual) {
        long m = Duration.between(scheduled, actual).toMinutes();
        return (int) Math.max(0, m);
    }
}
