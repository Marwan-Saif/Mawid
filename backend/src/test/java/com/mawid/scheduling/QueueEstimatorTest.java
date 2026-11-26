package com.mawid.scheduling;

import static org.assertj.core.api.Assertions.assertThat;

import com.mawid.scheduling.QueueEstimator.Estimate;
import com.mawid.scheduling.QueueEstimator.State;
import com.mawid.scheduling.QueueEstimator.Visit;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class QueueEstimatorTest {

    private static final Instant NOON = Instant.parse("2026-11-26T10:00:00Z");

    private static Instant at(int minutesFromNoon) {
        return NOON.plusSeconds(minutesFromNoon * 60L);
    }

    @Test
    void overrunInTheRoomPushesEveryoneBehind() {
        // In since 11:50 for a 30-minute visit → out at 12:20. Abu Sami booked 12:00 goes in at 12:20.
        Map<Long, Estimate> e = QueueEstimator.estimate(List.of(
                new Visit(1, 7, at(-30), 30, State.IN_ROOM, at(-10)),
                new Visit(2, 7, at(0), 30, State.ARRIVED, null),
                new Visit(3, 7, at(30), 30, State.BOOKED, null)), NOON);

        assertThat(e.get(2L).expectedStart()).isEqualTo(at(20));
        assertThat(e.get(2L).delayMin()).isEqualTo(20);
        assertThat(e.get(2L).ahead()).isEqualTo(1);
        assertThat(e.get(3L).expectedStart()).isEqualTo(at(50));
        assertThat(e.get(3L).delayMin()).isEqualTo(20);
        assertThat(e.get(3L).ahead()).isEqualTo(2);
    }

    @Test
    void nobodyGoesInBeforeTheirBookedTime() {
        Map<Long, Estimate> e = QueueEstimator.estimate(List.of(
                new Visit(1, 7, at(45), 15, State.ARRIVED, null)), NOON);

        assertThat(e.get(1L).expectedStart()).isEqualTo(at(45));
        assertThat(e.get(1L).delayMin()).isZero();
        assertThat(e.get(1L).ahead()).isZero();
    }

    @Test
    void aVisitThatShouldHaveEndedGetsAFewMoreMinutes() {
        Map<Long, Estimate> e = QueueEstimator.estimate(List.of(
                new Visit(1, 7, at(-60), 30, State.IN_ROOM, at(-50)),
                new Visit(2, 7, at(-15), 15, State.ARRIVED, null)), NOON);

        assertThat(e.get(2L).expectedStart()).isEqualTo(NOON.plus(QueueEstimator.OVERRUN_PADDING));
    }

    @Test
    void aLateNoShowDoesNotHoldUpThePeopleBehindThem() {
        Map<Long, Estimate> e = QueueEstimator.estimate(List.of(
                new Visit(1, 7, at(-20), 30, State.BOOKED, null),
                new Visit(2, 7, at(0), 30, State.ARRIVED, null)), NOON);

        assertThat(e.get(1L).late()).isTrue();
        assertThat(e.get(2L).expectedStart()).isEqualTo(NOON);
        assertThat(e.get(2L).ahead()).isZero();
    }

    @Test
    void eachDoctorHasTheirOwnQueue() {
        Map<Long, Estimate> e = QueueEstimator.estimate(List.of(
                new Visit(1, 7, at(-10), 30, State.IN_ROOM, at(-10)),
                new Visit(2, 7, at(0), 30, State.ARRIVED, null),
                new Visit(3, 8, at(0), 30, State.ARRIVED, null)), NOON);

        assertThat(e.get(2L).delayMin()).isEqualTo(20);
        assertThat(e.get(3L).delayMin()).isZero();
    }
}
