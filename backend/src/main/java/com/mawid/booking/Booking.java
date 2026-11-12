package com.mawid.booking;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import jakarta.persistence.Version;
import java.math.BigDecimal;
import java.time.Duration;
import java.time.Instant;

@Entity
@Table(name = "bookings", indexes = {
        @Index(name = "ix_bookings_place_start", columnList = "place_id,start_at"),
        @Index(name = "ix_bookings_customer_start", columnList = "customer_id,start_at"),
        @Index(name = "ix_bookings_staff_start", columnList = "staff_id,start_at")
})
public class Booking {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "place_id", nullable = false)
    private Long placeId;

    @Column(nullable = false)
    private Long serviceId;

    /** Always a real staff member; "any available" is resolved when booking. */
    @Column(name = "staff_id", nullable = false)
    private Long staffId;

    @Column(name = "customer_id", nullable = false)
    private Long customerId;

    /** UTC. Shown in the place's timezone. */
    @Column(name = "start_at", nullable = false)
    private Instant startAt;

    @Column(nullable = false)
    private int durationMin;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal price;

    @Column(nullable = false)
    private String currency;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private BookingStatus status;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private BookingSource source;

    @Column(length = 500)
    private String note;

    @Column(nullable = false)
    private Instant createdAt;

    private Instant remindedAt;

    @Version
    private long version;

    protected Booking() {
    }

    public Booking(Long placeId, Long serviceId, Long staffId, Long customerId, Instant startAt, int durationMin,
                   BigDecimal price, String currency, BookingStatus status, BookingSource source, String note,
                   Instant createdAt) {
        this.placeId = placeId;
        this.serviceId = serviceId;
        this.staffId = staffId;
        this.customerId = customerId;
        this.startAt = startAt;
        this.durationMin = durationMin;
        this.price = price;
        this.currency = currency;
        this.status = status;
        this.source = source;
        this.note = note;
        this.createdAt = createdAt;
    }

    public Instant endAt() {
        return startAt.plus(Duration.ofMinutes(durationMin));
    }

    public void moveTo(Instant newStart, Long newStaffId) {
        this.startAt = newStart;
        this.staffId = newStaffId;
        this.remindedAt = null;
    }

    public void setStatus(BookingStatus status) {
        this.status = status;
    }

    public void markReminded(Instant at) {
        this.remindedAt = at;
    }

    public Long getId() { return id; }
    public Long getPlaceId() { return placeId; }
    public Long getServiceId() { return serviceId; }
    public Long getStaffId() { return staffId; }
    public Long getCustomerId() { return customerId; }
    public Instant getStartAt() { return startAt; }
    public int getDurationMin() { return durationMin; }
    public BigDecimal getPrice() { return price; }
    public String getCurrency() { return currency; }
    public BookingStatus getStatus() { return status; }
    public BookingSource getSource() { return source; }
    public String getNote() { return note; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getRemindedAt() { return remindedAt; }
}
