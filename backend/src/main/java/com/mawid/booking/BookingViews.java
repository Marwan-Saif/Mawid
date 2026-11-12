package com.mawid.booking;

import com.mawid.auth.AppUser;
import com.mawid.auth.UserRepository;
import com.mawid.booking.BookingDtos.BookingDto;
import com.mawid.place.OfferedService;
import com.mawid.place.OfferedServiceRepository;
import com.mawid.place.Place;
import com.mawid.place.PlaceRepository;
import com.mawid.place.Staff;
import com.mawid.place.StaffRepository;
import com.mawid.scheduling.SlotCalculator;
import java.time.Clock;
import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import org.springframework.stereotype.Component;

/** Turns bookings into the denormalized JSON the apps show, loading each related row once. */
@Component
public class BookingViews {

    private final PlaceRepository places;
    private final OfferedServiceRepository services;
    private final StaffRepository staff;
    private final UserRepository users;
    private final Clock clock;

    public BookingViews(PlaceRepository places, OfferedServiceRepository services, StaffRepository staff,
                        UserRepository users, Clock clock) {
        this.places = places;
        this.services = services;
        this.staff = staff;
        this.users = users;
        this.clock = clock;
    }

    public BookingDto of(Booking b) {
        return list(List.of(b)).get(0);
    }

    public List<BookingDto> list(List<Booking> bookings) {
        Map<Long, Place> placeById = new HashMap<>();
        Map<Long, OfferedService> serviceById = new HashMap<>();
        Map<Long, Staff> staffById = new HashMap<>();
        Map<Long, AppUser> userById = new HashMap<>();
        Instant now = Instant.now(clock);
        return bookings.stream().map(b -> {
            Place p = cached(placeById, b.getPlaceId(), id -> places.findById(id).orElse(null));
            OfferedService s = cached(serviceById, b.getServiceId(), id -> services.findById(id).orElse(null));
            Staff st = cached(staffById, b.getStaffId(), id -> staff.findById(id).orElse(null));
            AppUser c = cached(userById, b.getCustomerId(), id -> users.findById(id).orElse(null));
            boolean canChange = b.getStatus().holdsTime() && b.getStatus() != BookingStatus.COMPLETED
                    && SlotCalculator.customerCanChange(b.getStartAt(), now);
            return new BookingDto(b.getId(), b.getPlaceId(),
                    p == null ? null : p.getSlug(),
                    p == null ? null : p.getNameAr(),
                    p == null ? null : p.getNameEn(),
                    p == null ? "UTC" : p.getTimezone(),
                    b.getServiceId(),
                    s == null ? null : s.getNameAr(),
                    s == null ? null : s.getNameEn(),
                    b.getStaffId(),
                    st == null ? null : st.getName(),
                    b.getCustomerId(),
                    c == null ? null : c.getName(),
                    c == null ? null : c.getPhone(),
                    b.getStartAt(), b.endAt(), b.getDurationMin(), b.getPrice(), b.getCurrency(),
                    b.getStatus(), b.getSource(), b.getNote(), b.getCreatedAt(), canChange);
        }).toList();
    }

    private static <T> T cached(Map<Long, T> cache, Long id, Function<Long, T> loader) {
        if (id == null) {
            return null;
        }
        if (!cache.containsKey(id)) {
            cache.put(id, loader.apply(id));
        }
        return cache.get(id);
    }
}
