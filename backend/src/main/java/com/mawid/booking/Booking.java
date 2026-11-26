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
import java.security.SecureRandom;
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

    // ------------------------------------------------------------ front desk (all nullable: older rows)

    /**
     * Short secret shown as a QR on the customer's booking. Scanned at reception, or opened as
     * /c/{code} on the customer's phone to check in by themselves.
     */
    @Column(name = "check_in_code", unique = true, length = 16)
    private String checkInCode;

    /** Number on the waiting-room screen, given at check-in (1, 2, 3... per place per day). */
    @Column(name = "ticket_no")
    private Integer ticketNo;

    private Instant checkedInAt;

    /** Last time the patient was called to the room; the waiting screen announces each new value. */
    private Instant calledAt;

    private Integer callCount;

    /** Room or chair the patient was called to ("Room 2", "Chair 1"). */
    @Column(length = 40)
    private String room;

    private Instant startedAt;
    private Instant finishedAt;

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
        this.checkInCode = newCheckInCode();
    }

    private static final SecureRandom RANDOM = new SecureRandom();
    private static final char[] CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789".toCharArray();

    /** 10 characters from a 31-letter alphabet without look-alikes (0/O, 1/I/L): about 8e14 codes. */
    static String newCheckInCode() {
        char[] out = new char[10];
        for (int i = 0; i < out.length; i++) {
            out[i] = CODE_ALPHABET[RANDOM.nextInt(CODE_ALPHABET.length)];
        }
        return new String(out);
    }

    /** Rows created before the front-desk module have no code yet. */
    public String ensureCheckInCode() {
        if (checkInCode == null) {
            checkInCode = newCheckInCode();
        }
        return checkInCode;
    }

    public void checkIn(int ticket, Instant at) {
        this.status = BookingStatus.ARRIVED;
        this.ticketNo = ticket;
        this.checkedInAt = at;
    }

    /** Call to the room. Calling again (patient didn't hear) only repeats the announcement. */
    public void call(String room, Instant at) {
        if (status != BookingStatus.IN_PROGRESS) {
            this.status = BookingStatus.IN_PROGRESS;
            this.startedAt = at;
        }
        this.room = room;
        this.calledAt = at;
        this.callCount = (callCount == null ? 0 : callCount) + 1;
    }

    public void finish(Instant at) {
        this.status = BookingStatus.COMPLETED;
        this.finishedAt = at;
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
    public String getCheckInCode() { return checkInCode; }
    public Integer getTicketNo() { return ticketNo; }
    public Instant getCheckedInAt() { return checkedInAt; }
    public Instant getCalledAt() { return calledAt; }
    public int getCallCount() { return callCount == null ? 0 : callCount; }
    public String getRoom() { return room; }
    public Instant getStartedAt() { return startedAt; }
    public Instant getFinishedAt() { return finishedAt; }
}
