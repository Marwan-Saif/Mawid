package com.mawid.booking;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.Instant;

/**
 * One row per staff member per 15-minute unit that is taken.
 *
 * <p>The unique constraint is the whole double-booking guarantee: if two customers try to take
 * the same unit for the same staff member at the same moment, the database accepts one insert
 * and rejects the other, whatever the application threads were doing. It works the same on
 * H2 and PostgreSQL, with no locking hints.
 */
@Entity
@Table(name = "slot_locks", uniqueConstraints =
        @UniqueConstraint(name = "uk_slot_lock_staff_unit", columnNames = {"staff_id", "unit_start"}))
public class SlotLock {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "staff_id", nullable = false)
    private Long staffId;

    @Column(name = "unit_start", nullable = false)
    private Instant unitStart;

    @Column(nullable = false)
    private Long bookingId;

    protected SlotLock() {
    }

    public SlotLock(Long staffId, Instant unitStart, Long bookingId) {
        this.staffId = staffId;
        this.unitStart = unitStart;
        this.bookingId = bookingId;
    }

    public Long getId() { return id; }
    public Long getStaffId() { return staffId; }
    public Instant getUnitStart() { return unitStart; }
    public Long getBookingId() { return bookingId; }
}
