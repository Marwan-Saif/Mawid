package com.mawid.booking;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;

public interface BookingRepository extends JpaRepository<Booking, Long> {

    List<Booking> findByPlaceIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
            Long placeId, Instant from, Instant to);

    List<Booking> findByStaffIdInAndStatusInAndStartAtGreaterThanEqualAndStartAtLessThan(
            Collection<Long> staffIds, Collection<BookingStatus> statuses, Instant from, Instant to);

    List<Booking> findByCustomerIdOrderByStartAtDesc(Long customerId);

    List<Booking> findByStatusInAndRemindedAtIsNullAndStartAtGreaterThanEqualAndStartAtLessThan(
            Collection<BookingStatus> statuses, Instant from, Instant to);
}
