package com.mawid.invoice;

import static com.mawid.audit.AuditActions.INVOICE;
import static com.mawid.audit.AuditActions.INVOICE_CREATED;
import static com.mawid.audit.AuditActions.INVOICE_EDITED;
import static com.mawid.audit.AuditActions.INVOICE_PAID;
import static com.mawid.audit.AuditActions.INVOICE_VOIDED;

import com.mawid.audit.AuditService;
import com.mawid.auth.AppUser;
import com.mawid.auth.AuthUser;
import com.mawid.auth.PhoneNumbers;
import com.mawid.auth.UserRepository;
import com.mawid.booking.Booking;
import com.mawid.booking.BookingRepository;
import com.mawid.common.ApiException;
import com.mawid.invoice.InvoiceDtos.CreateInvoiceRequest;
import com.mawid.invoice.InvoiceDtos.InvoiceDto;
import com.mawid.invoice.InvoiceDtos.LineDto;
import com.mawid.invoice.InvoiceDtos.LineInput;
import com.mawid.invoice.InvoiceDtos.UpdateInvoiceRequest;
import com.mawid.place.Place;
import com.mawid.place.PlaceRepository;
import com.mawid.place.StaffRepository;
import java.math.BigDecimal;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Invoices: create (idempotent by clientRef), edit with a version check, pay, void. Each step is audited. */
@Service
public class InvoiceService {

    private static final SecureRandom RANDOM = new SecureRandom();
    private static final char[] TOKEN_ALPHABET =
            "abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789".toCharArray();

    private final InvoiceRepository invoices;
    private final PlaceRepository places;
    private final BookingRepository bookings;
    private final StaffRepository staff;
    private final UserRepository users;
    private final AuditService audit;
    private final Clock clock;

    public InvoiceService(InvoiceRepository invoices, PlaceRepository places, BookingRepository bookings,
                          StaffRepository staff, UserRepository users, AuditService audit, Clock clock) {
        this.invoices = invoices;
        this.places = places;
        this.bookings = bookings;
        this.staff = staff;
        this.users = users;
        this.audit = audit;
        this.clock = clock;
    }

    @Transactional
    public Invoice create(Long placeId, CreateInvoiceRequest req, AuthUser me) {
        if (req.clientRef() != null && !req.clientRef().isBlank()) {
            var existing = invoices.findByPlaceIdAndClientRef(placeId, req.clientRef());
            if (existing.isPresent()) {
                return existing.get();
            }
        }
        List<InvoiceLine> lines = lines(req.lines());
        BigDecimal discount = discount(req.discount(), lines);

        Long bookingId = null;
        Long customerId = null;
        String customerName = req.customerName();
        String customerPhone = req.customerPhone() == null || req.customerPhone().isBlank() ? null
                : PhoneNumbers.normalize(req.customerPhone());
        String staffName = null;
        if (req.bookingId() != null) {
            Booking b = bookings.findById(req.bookingId())
                    .filter(x -> x.getPlaceId().equals(placeId))
                    .orElseThrow(() -> ApiException.notFound("Booking"));
            boolean billed = !invoices.findByBookingIdInAndStatusNot(List.of(b.getId()), InvoiceStatus.VOID).isEmpty();
            if (billed) {
                throw ApiException.conflict("ALREADY_INVOICED", "This visit already has an invoice");
            }
            bookingId = b.getId();
            customerId = b.getCustomerId();
            AppUser c = users.findById(b.getCustomerId()).orElse(null);
            if (c != null) {
                customerName = c.getName();
                customerPhone = c.getPhone();
            }
            staffName = staff.findById(b.getStaffId()).map(s -> s.getName()).orElse(null);
        }
        if (customerName == null || customerName.isBlank()) {
            throw ApiException.badRequest("CUSTOMER_REQUIRED", "Who is this invoice for?");
        }

        Place place = places.lockById(placeId).orElseThrow(() -> ApiException.notFound("Place"));
        Instant now = Instant.now(clock);
        Invoice inv = new Invoice(placeId, place.takeInvoiceNo(), bookingId, customerId, customerName.trim(),
                customerPhone, staffName, place.getCurrency(), now, me == null ? null : me.id(),
                blankToNull(req.clientRef()), token());
        inv.setLines(lines, discount);
        if (req.paidWith() != null) {
            inv.pay(req.paidWith(), now);
        }
        inv = invoices.saveAndFlush(inv);
        Map<String, Object> d = new LinkedHashMap<>();
        d.put("number", inv.getNumber());
        d.put("total", inv.getTotal());
        d.put("currency", inv.getCurrency());
        if (inv.getStatus() == InvoiceStatus.PAID) {
            d.put("paidWith", inv.getPaymentMethod().name());
        }
        audit.record(placeId, me, INVOICE_CREATED, INVOICE, inv.getId(), "#" + inv.getNumber(), d);
        return inv;
    }

    @Transactional
    public Invoice update(Long placeId, Long id, UpdateInvoiceRequest req, AuthUser me) {
        Invoice inv = own(placeId, id);
        if (inv.getStatus() == InvoiceStatus.VOID) {
            throw ApiException.conflict("INVOICE_VOID", "A voided invoice can't be edited");
        }
        if (req.version() != inv.getVersion()) {
            throw ApiException.conflict("STALE_INVOICE", "Someone else changed this invoice. Reload it and try again.");
        }
        List<InvoiceLine> lines = lines(req.lines());
        BigDecimal discount = discount(req.discount(), lines);

        List<String> before = inv.getLines().stream().map(InvoiceService::describe).toList();
        List<String> after = lines.stream().map(InvoiceService::describe).toList();
        BigDecimal totalBefore = inv.getTotal();
        BigDecimal discountBefore = inv.getDiscount();

        inv.setLines(lines, discount);
        inv.touched(Instant.now(clock));
        inv = invoices.saveAndFlush(inv);

        Map<String, Object> d = new LinkedHashMap<>();
        d.put("number", inv.getNumber());
        d.put("totalFrom", totalBefore);
        d.put("totalTo", inv.getTotal());
        d.put("currency", inv.getCurrency());
        List<String> added = new ArrayList<>(after);
        before.forEach(added::remove);
        List<String> removed = new ArrayList<>(before);
        after.forEach(removed::remove);
        if (!added.isEmpty()) {
            d.put("added", added);
        }
        if (!removed.isEmpty()) {
            d.put("removed", removed);
        }
        if (discountBefore.compareTo(inv.getDiscount()) != 0) {
            d.put("discountFrom", discountBefore);
            d.put("discountTo", inv.getDiscount());
        }
        audit.record(placeId, me, INVOICE_EDITED, INVOICE, inv.getId(), "#" + inv.getNumber(), d);
        return inv;
    }

    @Transactional
    public Invoice pay(Long placeId, Long id, PaymentMethod method, AuthUser me) {
        Invoice inv = own(placeId, id);
        if (inv.getStatus() == InvoiceStatus.VOID) {
            throw ApiException.conflict("INVOICE_VOID", "A voided invoice can't be paid");
        }
        if (inv.getStatus() == InvoiceStatus.PAID) {
            return inv; // replay from an offline queue, or a double tap
        }
        inv.pay(method, Instant.now(clock));
        inv = invoices.saveAndFlush(inv);
        audit.record(placeId, me, INVOICE_PAID, INVOICE, inv.getId(), "#" + inv.getNumber(),
                Map.of("number", inv.getNumber(), "total", inv.getTotal(), "currency", inv.getCurrency(),
                        "paidWith", method.name()));
        return inv;
    }

    @Transactional
    public Invoice voidIt(Long placeId, Long id, String reason, AuthUser me) {
        Invoice inv = own(placeId, id);
        if (inv.getStatus() == InvoiceStatus.VOID) {
            return inv;
        }
        inv.voidIt(reason.trim(), Instant.now(clock));
        inv = invoices.saveAndFlush(inv);
        audit.record(placeId, me, INVOICE_VOIDED, INVOICE, inv.getId(), "#" + inv.getNumber(),
                Map.of("number", inv.getNumber(), "total", inv.getTotal(), "currency", inv.getCurrency(),
                        "reason", inv.getVoidReason()));
        return inv;
    }

    @Transactional(readOnly = true)
    public List<Invoice> forDay(Long placeId, LocalDate day) {
        Place place = places.findById(placeId).orElseThrow(() -> ApiException.notFound("Place"));
        Instant from = day.atStartOfDay(place.zone()).toInstant();
        Instant to = day.plusDays(1).atStartOfDay(place.zone()).toInstant();
        return invoices.findByPlaceIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThanOrderByNumberDesc(placeId, from, to);
    }

    @Transactional(readOnly = true)
    public Invoice get(Long placeId, Long id) {
        return own(placeId, id);
    }

    public InvoiceDto dto(Invoice inv, String baseUrl) {
        String createdBy = inv.getCreatedById() == null ? null
                : users.findById(inv.getCreatedById()).map(AppUser::getName).orElse(null);
        return new InvoiceDto(inv.getId(), inv.getNumber(), inv.getPlaceId(), inv.getBookingId(),
                inv.getCustomerName(), inv.getCustomerPhone(), inv.getStaffName(),
                inv.getLines().stream().map(LineDto::of).toList(), inv.getSubtotal(), inv.getDiscount(),
                inv.getTotal(), inv.getCurrency(), inv.getStatus(), inv.getPaymentMethod(), inv.getCreatedAt(),
                inv.getUpdatedAt(), inv.getPaidAt(), createdBy, inv.getVoidReason(), inv.getVersion(),
                inv.getPublicToken(), inv.getClientRef(),
                baseUrl == null ? null : baseUrl + "/i/" + inv.getPublicToken());
    }

    // ---------------------------------------------------------------- helpers

    private Invoice own(Long placeId, Long id) {
        return invoices.findById(id)
                .filter(i -> Objects.equals(i.getPlaceId(), placeId))
                .orElseThrow(() -> ApiException.notFound("Invoice"));
    }

    private static List<InvoiceLine> lines(List<LineInput> input) {
        List<InvoiceLine> out = new ArrayList<>();
        for (LineInput l : input) {
            if (l.unitPrice().signum() < 0) {
                throw ApiException.badRequest("INVALID_PRICE", "Price can't be negative");
            }
            out.add(new InvoiceLine(l.description().trim(), l.qty(), l.unitPrice(), l.serviceId()));
        }
        return out;
    }

    private static BigDecimal discount(BigDecimal discount, List<InvoiceLine> lines) {
        if (discount == null || discount.signum() == 0) {
            return BigDecimal.ZERO;
        }
        BigDecimal subtotal = lines.stream().map(InvoiceLine::amount).reduce(BigDecimal.ZERO, BigDecimal::add);
        if (discount.signum() < 0 || discount.compareTo(subtotal) > 0) {
            throw ApiException.badRequest("INVALID_DISCOUNT", "Discount must be between 0 and the subtotal");
        }
        return discount;
    }

    /** "قياس ضغط × 1 @ 5.00" — how a line reads in the audit log. */
    private static String describe(InvoiceLine l) {
        return l.getDescription() + " × " + l.getQty() + " @ " + l.getUnitPrice().stripTrailingZeros().toPlainString();
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }

    private static String token() {
        char[] out = new char[24];
        for (int i = 0; i < out.length; i++) {
            out[i] = TOKEN_ALPHABET[RANDOM.nextInt(TOKEN_ALPHABET.length)];
        }
        return new String(out);
    }
}
