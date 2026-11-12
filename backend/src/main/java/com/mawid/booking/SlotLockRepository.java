package com.mawid.booking;

import java.time.Instant;
import java.util.Collection;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface SlotLockRepository extends JpaRepository<SlotLock, Long> {

    boolean existsByStaffIdAndUnitStartIn(Long staffId, Collection<Instant> unitStarts);

    long countByBookingId(Long bookingId);

    /** Bulk delete runs immediately, before any new locks are inserted in the same transaction. */
    @Modifying(flushAutomatically = true, clearAutomatically = false)
    @Query("delete from SlotLock l where l.bookingId = :bookingId")
    int deleteByBookingId(@Param("bookingId") Long bookingId);
}
