package com.mawid.invoice;

import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.OrderColumn;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import jakarta.persistence.Version;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

/**
 * A bill for a visit (or a counter sale). Numbered per place without gaps: voiding keeps the row.
 * Every change is optimistic-locked by {@link #version}, so two desks editing the same invoice
 * can't silently overwrite each other.
 */
@Entity
@Table(name = "invoices",
        uniqueConstraints = {
                @UniqueConstraint(name = "uq_invoice_number", columnNames = {"place_id", "invoice_no"}),
                @UniqueConstraint(name = "uq_invoice_client_ref", columnNames = {"place_id", "client_ref"}),
                @UniqueConstraint(name = "uq_invoice_token", columnNames = {"public_token"})
        },
        indexes = {
                @Index(name = "ix_invoice_place_created", columnList = "place_id,created_at"),
                @Index(name = "ix_invoice_booking", columnList = "booking_id")
        })
public class Invoice {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "place_id", nullable = false)
    private Long placeId;

    @Column(name = "invoice_no", nullable = false)
    private long number;

    @Column(name = "booking_id")
    private Long bookingId;

    private Long customerId;

    @Column(nullable = false, length = 80)
    private String customerName;

    @Column(length = 20)
    private String customerPhone;

    /** Doctor or stylist, copied so the printout doesn't change if the team does. */
    @Column(length = 80)
    private String staffName;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "invoice_lines", joinColumns = @JoinColumn(name = "invoice_id"))
    @OrderColumn(name = "line_no")
    private List<InvoiceLine> lines = new ArrayList<>();

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal subtotal;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal discount;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal total;

    @Column(nullable = false, length = 3)
    private String currency;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 10)
    private InvoiceStatus status;

    @Enumerated(EnumType.STRING)
    @Column(length = 10)
    private PaymentMethod paymentMethod;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    private Long createdById;

    private Instant updatedAt;
    private Instant paidAt;

    @Column(length = 200)
    private String voidReason;

    /** Id the app made up when it created the invoice, maybe offline. Replays return the same invoice. */
    @Column(name = "client_ref", length = 64)
    private String clientRef;

    /** Unguessable id for the printable page and the QR on it: /i/{publicToken}. */
    @Column(name = "public_token", nullable = false, length = 32)
    private String publicToken;

    @Version
    private long version;

    protected Invoice() {
    }

    public Invoice(Long placeId, long number, Long bookingId, Long customerId, String customerName,
                   String customerPhone, String staffName, String currency, Instant createdAt, Long createdById,
                   String clientRef, String publicToken) {
        this.placeId = placeId;
        this.number = number;
        this.bookingId = bookingId;
        this.customerId = customerId;
        this.customerName = customerName;
        this.customerPhone = customerPhone;
        this.staffName = staffName;
        this.currency = currency;
        this.createdAt = createdAt;
        this.createdById = createdById;
        this.clientRef = clientRef;
        this.publicToken = publicToken;
        this.status = InvoiceStatus.ISSUED;
        this.subtotal = BigDecimal.ZERO;
        this.discount = BigDecimal.ZERO;
        this.total = BigDecimal.ZERO;
    }

    public void setLines(List<InvoiceLine> newLines, BigDecimal newDiscount) {
        lines.clear();
        lines.addAll(newLines);
        subtotal = newLines.stream().map(InvoiceLine::amount).reduce(BigDecimal.ZERO, BigDecimal::add)
                .setScale(2, RoundingMode.HALF_UP);
        discount = (newDiscount == null ? BigDecimal.ZERO : newDiscount).setScale(2, RoundingMode.HALF_UP);
        total = subtotal.subtract(discount).max(BigDecimal.ZERO);
    }

    public void touched(Instant at) {
        this.updatedAt = at;
    }

    public void pay(PaymentMethod method, Instant at) {
        this.status = InvoiceStatus.PAID;
        this.paymentMethod = method;
        this.paidAt = at;
    }

    public void voidIt(String reason, Instant at) {
        this.status = InvoiceStatus.VOID;
        this.voidReason = reason;
        this.updatedAt = at;
    }

    public Long getId() { return id; }
    public Long getPlaceId() { return placeId; }
    public long getNumber() { return number; }
    public Long getBookingId() { return bookingId; }
    public Long getCustomerId() { return customerId; }
    public String getCustomerName() { return customerName; }
    public String getCustomerPhone() { return customerPhone; }
    public String getStaffName() { return staffName; }
    public List<InvoiceLine> getLines() { return lines; }
    public BigDecimal getSubtotal() { return subtotal; }
    public BigDecimal getDiscount() { return discount; }
    public BigDecimal getTotal() { return total; }
    public String getCurrency() { return currency; }
    public InvoiceStatus getStatus() { return status; }
    public PaymentMethod getPaymentMethod() { return paymentMethod; }
    public Instant getCreatedAt() { return createdAt; }
    public Long getCreatedById() { return createdById; }
    public Instant getUpdatedAt() { return updatedAt; }
    public Instant getPaidAt() { return paidAt; }
    public String getVoidReason() { return voidReason; }
    public String getClientRef() { return clientRef; }
    public String getPublicToken() { return publicToken; }
    public long getVersion() { return version; }
}
