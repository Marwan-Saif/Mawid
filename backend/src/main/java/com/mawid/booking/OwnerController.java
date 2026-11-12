package com.mawid.booking;

import com.mawid.auth.AppUser;
import com.mawid.auth.AuthUser;
import com.mawid.auth.PhoneNumbers;
import com.mawid.auth.Role;
import com.mawid.auth.UserRepository;
import com.mawid.booking.BookingDtos.BookingDto;
import com.mawid.booking.BookingDtos.ManualBookingRequest;
import com.mawid.booking.BookingDtos.ServiceUpsert;
import com.mawid.booking.BookingDtos.StatusUpdate;
import com.mawid.booking.BookingService.Actor;
import com.mawid.booking.BookingService.NewBooking;
import com.mawid.common.ApiException;
import com.mawid.place.OfferedService;
import com.mawid.place.OfferedServiceRepository;
import com.mawid.place.PlaceDtos.PlaceDetails;
import com.mawid.place.PlaceDtos.ServiceDto;
import com.mawid.place.PlaceQueries;
import com.mawid.place.Staff;
import com.mawid.place.StaffRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Everything the owner dashboard needs. The place is always the signed-in owner's own place. */
@Tag(name = "Owner")
@RestController
@RequestMapping("/api/v1/owner")
public class OwnerController {

    private final BookingService bookings;
    private final BookingViews views;
    private final PlaceQueries places;
    private final OfferedServiceRepository services;
    private final StaffRepository staff;
    private final UserRepository users;
    private final Clock clock;

    public OwnerController(BookingService bookings, BookingViews views, PlaceQueries places,
                           OfferedServiceRepository services, StaffRepository staff, UserRepository users,
                           Clock clock) {
        this.bookings = bookings;
        this.views = views;
        this.places = places;
        this.services = services;
        this.staff = staff;
        this.users = users;
        this.clock = clock;
    }

    @GetMapping("/place")
    public PlaceDetails myPlace(@AuthenticationPrincipal AuthUser me) {
        return places.details(places.byId(placeOf(me)), true);
    }

    @Operation(summary = "The day's schedule in the place's timezone (default: today)")
    @GetMapping("/bookings")
    public List<BookingDto> day(@AuthenticationPrincipal AuthUser me,
                                @RequestParam(required = false)
                                @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        Long placeId = placeOf(me);
        LocalDate day = date != null ? date : LocalDate.now(places.byId(placeId).zone());
        return views.list(bookings.forPlaceOnDay(placeId, day));
    }

    @PatchMapping("/bookings/{id}/status")
    public BookingDto status(@AuthenticationPrincipal AuthUser me, @PathVariable Long id,
                             @Valid @RequestBody StatusUpdate body) {
        return views.of(bookings.updateStatus(id, body.status(), me));
    }

    @Operation(summary = "Add a walk-in or phone booking; uses the same locks, so it can't clash")
    @PostMapping("/bookings")
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public BookingDto manual(@AuthenticationPrincipal AuthUser me, @Valid @RequestBody ManualBookingRequest body) {
        Long placeId = placeOf(me);
        String phone = PhoneNumbers.normalize(body.customerPhone());
        AppUser customer = users.findByPhone(phone).orElseGet(() -> users.save(
                new AppUser(phone, body.customerName().trim(), Role.CUSTOMER, null, Instant.now(clock))));
        Booking b = bookings.create(new NewBooking(placeId, body.serviceId(), body.staffId(), customer.getId(),
                body.startAt(), body.note(), BookingSource.MANUAL, BookingStatus.CONFIRMED), Actor.OWNER);
        return views.of(b);
    }

    @GetMapping("/services")
    public List<ServiceDto> services(@AuthenticationPrincipal AuthUser me) {
        return services.findByPlaceIdOrderByIdAsc(placeOf(me)).stream().map(ServiceDto::of).toList();
    }

    @Operation(summary = "Add a service; every team member is assigned to it so it is bookable right away")
    @PostMapping("/services")
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public ServiceDto addService(@AuthenticationPrincipal AuthUser me, @Valid @RequestBody ServiceUpsert body) {
        Long placeId = placeOf(me);
        validate(body);
        OfferedService s = services.save(new OfferedService(placeId, body.nameAr().trim(), body.nameEn().trim(),
                body.durationMin(), body.price()));
        for (Staff member : staff.findByPlaceIdOrderByIdAsc(placeId)) {
            member.addService(s.getId());
        }
        return ServiceDto.of(s);
    }

    @PutMapping("/services/{id}")
    @Transactional
    public ServiceDto updateService(@AuthenticationPrincipal AuthUser me, @PathVariable Long id,
                                    @Valid @RequestBody ServiceUpsert body) {
        Long placeId = placeOf(me);
        validate(body);
        OfferedService s = services.findById(id)
                .filter(x -> x.getPlaceId().equals(placeId))
                .orElseThrow(() -> ApiException.notFound("Service"));
        s.update(body.nameAr().trim(), body.nameEn().trim(), body.durationMin(), body.price(),
                body.active() == null || body.active());
        return ServiceDto.of(s);
    }

    private static void validate(ServiceUpsert body) {
        if (body.durationMin() < 15 || body.durationMin() > 480 || body.durationMin() % 15 != 0) {
            throw ApiException.badRequest("INVALID_DURATION", "Duration must be 15 to 480 minutes, in steps of 15");
        }
        if (body.price().signum() < 0) {
            throw ApiException.badRequest("INVALID_PRICE", "Price can't be negative");
        }
    }

    private static Long placeOf(AuthUser me) {
        if (me.placeId() == null) {
            throw ApiException.forbidden("This owner account has no place yet");
        }
        return me.placeId();
    }
}
