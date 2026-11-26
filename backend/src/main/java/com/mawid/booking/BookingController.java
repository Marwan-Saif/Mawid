package com.mawid.booking;

import com.mawid.audit.AuditActions;
import com.mawid.audit.AuditService;
import com.mawid.auth.AuthUser;
import com.mawid.booking.BookingDtos.BookingDto;
import com.mawid.booking.BookingDtos.CreateBookingRequest;
import com.mawid.booking.BookingDtos.RescheduleRequest;
import com.mawid.booking.BookingService.Actor;
import com.mawid.booking.BookingService.NewBooking;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.util.List;
import java.util.Map;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Bookings")
@RestController
@RequestMapping("/api/v1/bookings")
public class BookingController {

    private final BookingService service;
    private final BookingViews views;
    private final AuditService audit;

    public BookingController(BookingService service, BookingViews views, AuditService audit) {
        this.service = service;
        this.views = views;
        this.audit = audit;
    }

    @Operation(summary = "Book a slot. staffId null = any available team member. 409 SLOT_TAKEN if someone was faster.")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public BookingDto create(@AuthenticationPrincipal AuthUser me, @Valid @RequestBody CreateBookingRequest body) {
        Booking b = service.create(new NewBooking(body.placeId(), body.serviceId(), body.staffId(), me.id(),
                body.startAt(), body.note(), BookingSource.APP, BookingStatus.CONFIRMED), Actor.CUSTOMER);
        return views.of(b);
    }

    @GetMapping("/me")
    public List<BookingDto> mine(@AuthenticationPrincipal AuthUser me) {
        return views.list(service.forCustomer(me.id()));
    }

    @Operation(summary = "Cancel; frees the time immediately. Customers: up to 3 hours before.")
    @PostMapping("/{id}/cancel")
    @Transactional
    public BookingDto cancel(@AuthenticationPrincipal AuthUser me, @PathVariable Long id) {
        Booking b = service.cancel(id, me);
        audit.record(b.getPlaceId(), me, AuditActions.BOOKING_CANCELLED, AuditActions.BOOKING, b.getId(),
                "#" + b.getId(), Map.of("startAt", b.getStartAt().toString()));
        return views.of(b);
    }

    @Operation(summary = "Move to another time (and optionally another team member).")
    @PostMapping("/{id}/reschedule")
    @Transactional
    public BookingDto reschedule(@AuthenticationPrincipal AuthUser me, @PathVariable Long id,
                                 @Valid @RequestBody RescheduleRequest body) {
        String before = service.startOf(id).toString();
        Booking b = service.reschedule(id, body.startAt(), body.staffId(), me);
        audit.record(b.getPlaceId(), me, AuditActions.BOOKING_MOVED, AuditActions.BOOKING, b.getId(),
                "#" + b.getId(), Map.of("from", before, "to", b.getStartAt().toString()));
        return views.of(b);
    }
}
