package com.mawid.booking;

import com.mawid.auth.AppUser;
import com.mawid.auth.PhoneNumbers;
import com.mawid.auth.Role;
import com.mawid.auth.UserRepository;
import com.mawid.booking.BookingDtos.BookingDto;
import com.mawid.booking.BookingDtos.GuestBookingRequest;
import com.mawid.booking.BookingDtos.GuestBookingResponse;
import com.mawid.booking.BookingService.Actor;
import com.mawid.booking.BookingService.NewBooking;
import com.mawid.place.Place;
import com.mawid.place.PlaceDtos.Availability;
import com.mawid.place.PlaceDtos.PlaceDetails;
import com.mawid.place.PlaceQueries;
import com.mawid.reminder.WhatsAppLinks;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * Powers the no-install booking link (/b/{slug}) a salon puts in its Instagram bio or WhatsApp status.
 * Customers book with name + phone only.
 */
@Tag(name = "Public booking page")
@RestController
@RequestMapping("/api/v1/public/places/{slug}")
public class PublicBookingController {

    private final PlaceQueries places;
    private final BookingService bookings;
    private final BookingViews views;
    private final UserRepository users;
    private final WhatsAppLinks whatsapp;
    private final Clock clock;

    public PublicBookingController(PlaceQueries places, BookingService bookings, BookingViews views,
                                   UserRepository users, WhatsAppLinks whatsapp, Clock clock) {
        this.places = places;
        this.bookings = bookings;
        this.views = views;
        this.users = users;
        this.whatsapp = whatsapp;
        this.clock = clock;
    }

    @GetMapping
    public PlaceDetails place(@PathVariable String slug) {
        return places.details(places.bySlug(slug));
    }

    @GetMapping("/availability")
    public Availability availability(@PathVariable String slug, @RequestParam Long serviceId,
                                     @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
                                     @RequestParam(required = false) Long staffId) {
        return bookings.availability(places.bySlug(slug).getId(), serviceId, date, staffId);
    }

    @Operation(summary = "Book as a guest; returns a WhatsApp link to message the place")
    @PostMapping("/bookings")
    @ResponseStatus(HttpStatus.CREATED)
    @Transactional
    public GuestBookingResponse book(@PathVariable String slug, @Valid @RequestBody GuestBookingRequest body) {
        Place place = places.bySlug(slug);
        String phone = PhoneNumbers.normalize(body.phone());
        AppUser customer = users.findByPhone(phone).orElseGet(() -> users.save(
                new AppUser(phone, body.name().trim(), Role.CUSTOMER, null, Instant.now(clock))));
        Booking b = bookings.create(new NewBooking(place.getId(), body.serviceId(), body.staffId(), customer.getId(),
                body.startAt(), null, BookingSource.WEB, BookingStatus.CONFIRMED), Actor.CUSTOMER);
        BookingDto dto = views.of(b);
        return new GuestBookingResponse(dto, whatsapp.messagePlace(place, dto));
    }
}
