package com.mawid.booking;

import java.time.Instant;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface BookingRepository extends JpaRepository<Booking, Long> {

    List<Booking> findByPlaceIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
            Long placeId, Instant from, Instant to);

    List<Booking> findByStaffIdInAndStatusInAndStartAtGreaterThanEqualAndStartAtLessThan(
            Collection<Long> staffIds, Collection<BookingStatus> statuses, Instant from, Instant to);

    List<Booking> findByCustomerIdOrderByStartAtDesc(Long customerId);

    Optional<Booking> findByCheckInCode(String checkInCode);

    List<Booking> findByCheckInCodeIsNull();

    @Query("select coalesce(max(b.ticketNo), 0) from Booking b"
            + " where b.placeId = :placeId and b.startAt >= :from and b.startAt < :to")
    int maxTicket(@Param("placeId") Long placeId, @Param("from") Instant from, @Param("to") Instant to);

    List<Booking> findByStatusInAndRemindedAtIsNullAndStartAtGreaterThanEqualAndStartAtLessThan(
            Collection<BookingStatus> statuses, Instant from, Instant to);
}
