package com.mawid.booking;

import com.mawid.auth.AuthUser;
import com.mawid.common.ApiException;
import com.mawid.place.OfferedService;
import com.mawid.place.OfferedServiceRepository;
import com.mawid.place.Place;
import com.mawid.place.PlaceDtos.Availability;
import com.mawid.place.PlaceDtos.SlotDto;
import com.mawid.place.PlaceRepository;
import com.mawid.place.Staff;
import com.mawid.place.StaffRepository;
import com.mawid.scheduling.SlotCalculator;
import com.mawid.scheduling.SlotCalculator.Interval;
import com.mawid.scheduling.SlotCalculator.Slot;
import com.mawid.scheduling.SlotCalculator.StaffSchedule;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * The booking rules in one place.
 *
 * <p>Double booking is prevented in two layers: a read check (is any lock unit taken?) that gives
 * a clean answer in the normal case, and the unique index on {@code slot_locks} that settles real
 * races at the database. Cancelling deletes the booking's locks in the same transaction, so the
 * time is free again immediately.
 */
@Service
public class BookingService {

    private static final DateTimeFormatter HH_MM = DateTimeFormatter.ofPattern("HH:mm");

    /** Who is acting decides which rules apply. */
    public enum Actor { CUSTOMER, OWNER, SYSTEM }

    public record NewBooking(Long placeId, Long serviceId, Long staffId, Long customerId, Instant startAt,
                             String note, BookingSource source, BookingStatus status) {
    }

    private final BookingRepository bookings;
    private final SlotLockRepository locks;
    private final PlaceRepository places;
    private final OfferedServiceRepository services;
    private final StaffRepository staff;
    private final Clock clock;

    public BookingService(BookingRepository bookings, SlotLockRepository locks, PlaceRepository places,
                          OfferedServiceRepository services, StaffRepository staff, Clock clock) {
        this.bookings = bookings;
        this.locks = locks;
        this.places = places;
        this.services = services;
        this.staff = staff;
        this.clock = clock;
    }

    // ---------------------------------------------------------------- availability

    @Transactional(readOnly = true)
    public Availability availability(Long placeId, Long serviceId, LocalDate date, Long staffId) {
        Place place = place(placeId);
        OfferedService service = serviceOf(place, serviceId);
        List<Staff> candidates = candidates(place, service, staffId);
        ZoneId zone = place.zone();
        List<Slot> slots = SlotCalculator.slotsFor(date, zone, place.workingHours(), service.getDurationMin(),
                schedules(candidates, date, zone, null), Instant.now(clock));
        List<SlotDto> dtos = slots.stream()
                .map(s -> new SlotDto(s.startAt(), s.localTime().format(HH_MM), s.available(), s.freeStaffIds()))
                .toList();
        return new Availability(date.toString(), place.getTimezone(), service.getDurationMin(), dtos);
    }

    // ---------------------------------------------------------------- create

    @Transactional
    public Booking create(NewBooking req, Actor actor) {
        Place place = place(req.placeId());
        OfferedService service = serviceOf(place, req.serviceId());
        if (actor != Actor.SYSTEM && !service.isActive()) {
            throw ApiException.badRequest("SERVICE_INACTIVE", "This service is not bookable right now");
        }
        Instant start = req.startAt();
        validateTime(place, service.getDurationMin(), start, actor);

        List<Staff> candidates = candidates(place, service, req.staffId());
        Staff chosen = firstFree(candidates, place, start, service.getDurationMin());

        Booking booking = bookings.save(new Booking(place.getId(), service.getId(), chosen.getId(), req.customerId(),
                start, service.getDurationMin(), service.getPrice(), place.getCurrency(),
                req.status() == null ? BookingStatus.CONFIRMED : req.status(), req.source(), req.note(),
                Instant.now(clock)));
        writeLocks(booking);
        return booking;
    }

    // ---------------------------------------------------------------- change

    @Transactional
    public Booking cancel(Long bookingId, AuthUser by) {
        Booking b = booking(bookingId);
        Actor actor = authorize(b, by);
        if (!b.getStatus().holdsTime() || b.getStatus() == BookingStatus.COMPLETED) {
            throw ApiException.conflict("NOT_CANCELLABLE", "This booking can no longer be cancelled");
        }
        if (actor == Actor.CUSTOMER && !SlotCalculator.customerCanChange(b.getStartAt(), Instant.now(clock))) {
            throw ApiException.conflict("TOO_LATE_TO_CHANGE", "Bookings can be changed up to 3 hours before");
        }
        locks.deleteByBookingId(b.getId());
        b.setStatus(BookingStatus.CANCELLED);
        return b;
    }

    @Transactional
    public Booking reschedule(Long bookingId, Instant newStart, Long staffId, AuthUser by) {
        Booking b = booking(bookingId);
        Actor actor = authorize(b, by);
        if (!b.getStatus().holdsTime() || b.getStatus() == BookingStatus.COMPLETED) {
            throw ApiException.conflict("NOT_CHANGEABLE", "This booking can no longer be changed");
        }
        Instant now = Instant.now(clock);
        if (actor == Actor.CUSTOMER && !SlotCalculator.customerCanChange(b.getStartAt(), now)) {
            throw ApiException.conflict("TOO_LATE_TO_CHANGE", "Bookings can be changed up to 3 hours before");
        }
        Place place = place(b.getPlaceId());
        OfferedService service = serviceOf(place, b.getServiceId());
        validateTime(place, b.getDurationMin(), newStart, actor);

        // Free this booking's own units first so moving by 15 minutes onto itself works.
        locks.deleteByBookingId(b.getId());
        Staff chosen = firstFree(candidates(place, service, staffId), place, newStart, b.getDurationMin());
        b.moveTo(newStart, chosen.getId());
        bookings.flush();
        writeLocks(b);
        return b;
    }

    @Transactional
    public Booking updateStatus(Long bookingId, BookingStatus status, AuthUser owner) {
        Booking b = booking(bookingId);
        if (!owner.isOwnerOf(b.getPlaceId())) {
            throw ApiException.forbidden("Not your place");
        }
        if (b.getStatus() == status) {
            return b;
        }
        boolean held = b.getStatus().holdsTime();
        boolean holds = status.holdsTime();
        if (held && !holds) {
            locks.deleteByBookingId(b.getId());
        } else if (!held && holds) {
            // Re-opening a cancelled booking: only if the time is still free.
            Place place = place(b.getPlaceId());
            firstFree(List.of(staffMember(b.getStaffId())), place, b.getStartAt(), b.getDurationMin());
            b.setStatus(status);
            writeLocks(b);
            return b;
        }
        b.setStatus(status);
        return b;
    }

    // ---------------------------------------------------------------- queries

    @Transactional(readOnly = true)
    public List<Booking> forCustomer(Long customerId) {
        return bookings.findByCustomerIdOrderByStartAtDesc(customerId);
    }

    @Transactional(readOnly = true)
    public List<Booking> forPlaceOnDay(Long placeId, LocalDate date) {
        Place place = place(placeId);
        Instant from = date.atStartOfDay(place.zone()).toInstant();
        Instant to = date.plusDays(1).atStartOfDay(place.zone()).toInstant();
        return bookings.findByPlaceIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(placeId, from, to);
    }

    // ---------------------------------------------------------------- helpers

    private void validateTime(Place place, int durationMin, Instant start, Actor actor) {
        if (!SlotCalculator.isAligned(start)) {
            throw ApiException.badRequest("SLOT_NOT_ALIGNED", "Start time must be on a 15-minute boundary");
        }
        if (actor != Actor.SYSTEM && !start.isAfter(Instant.now(clock))) {
            throw ApiException.badRequest("SLOT_IN_PAST", "This time has already passed");
        }
        if (!SlotCalculator.fitsWorkingHours(start, durationMin, place.zone(), place.workingHours())) {
            throw ApiException.badRequest("OUTSIDE_WORKING_HOURS", "The place is closed at this time");
        }
    }

    /** The first candidate whose lock units are all free; staff on a day off are skipped. */
    private Staff firstFree(List<Staff> candidates, Place place, Instant start, int durationMin) {
        LocalDate localDate = start.atZone(place.zone()).toLocalDate();
        List<Instant> units = SlotCalculator.lockUnits(start, durationMin);
        for (Staff s : candidates) {
            if (s.getDaysOff().contains(localDate.getDayOfWeek())) {
                continue;
            }
            if (!locks.existsByStaffIdAndUnitStartIn(s.getId(), units)) {
                return s;
            }
        }
        throw ApiException.conflict("SLOT_TAKEN", "This time is no longer available");
    }

    private void writeLocks(Booking b) {
        List<SlotLock> rows = SlotCalculator.lockUnits(b.getStartAt(), b.getDurationMin()).stream()
                .map(unit -> new SlotLock(b.getStaffId(), unit, b.getId()))
                .toList();
        // Flush now so a unique-index clash surfaces here as DataIntegrityViolationException (409).
        locks.saveAllAndFlush(rows);
    }

    private List<StaffSchedule> schedules(List<Staff> candidates, LocalDate date, ZoneId zone, Long ignoreBooking) {
        if (candidates.isEmpty()) {
            return List.of();
        }
        // Look a day back too: a long booking that started yesterday evening can spill into today.
        Instant from = date.minusDays(1).atStartOfDay(zone).toInstant();
        Instant to = date.plusDays(1).atStartOfDay(zone).toInstant();
        Set<Long> ids = candidates.stream().map(Staff::getId).collect(Collectors.toSet());
        Map<Long, List<Interval>> busy = bookings
                .findByStaffIdInAndStatusInAndStartAtGreaterThanEqualAndStartAtLessThan(
                        ids, BookingStatus.HOLDS_TIME, from, to)
                .stream()
                .filter(b -> ignoreBooking == null || !ignoreBooking.equals(b.getId()))
                .collect(Collectors.groupingBy(Booking::getStaffId,
                        Collectors.mapping(b -> new Interval(b.getStartAt(), b.endAt()), Collectors.toList())));
        List<StaffSchedule> result = new ArrayList<>();
        for (Staff s : candidates) {
            var daysOff = s.getDaysOff().isEmpty() ? EnumSet.noneOf(java.time.DayOfWeek.class)
                    : EnumSet.copyOf(s.getDaysOff());
            result.add(new StaffSchedule(s.getId(), daysOff, busy.getOrDefault(s.getId(), List.of())));
        }
        return result;
    }

    private List<Staff> candidates(Place place, OfferedService service, Long staffId) {
        List<Staff> all = staff.findByPlaceIdOrderByIdAsc(place.getId()).stream()
                .filter(s -> s.doesService(service.getId()))
                .toList();
        if (staffId == null) {
            if (all.isEmpty()) {
                throw ApiException.badRequest("NO_STAFF", "Nobody offers this service yet");
            }
            return all;
        }
        return all.stream()
                .filter(s -> s.getId().equals(staffId))
                .findFirst()
                .map(List::of)
                .orElseThrow(() -> ApiException.badRequest("STAFF_NOT_AVAILABLE",
                        "This team member does not offer this service"));
    }

    private Actor authorize(Booking b, AuthUser by) {
        if (by.isOwnerOf(b.getPlaceId())) {
            return Actor.OWNER;
        }
        if (b.getCustomerId().equals(by.id())) {
            return Actor.CUSTOMER;
        }
        throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Not your booking");
    }

    private Place place(Long id) {
        return places.findById(id).orElseThrow(() -> ApiException.notFound("Place"));
    }

    private OfferedService serviceOf(Place place, Long serviceId) {
        OfferedService s = services.findById(serviceId).orElseThrow(() -> ApiException.notFound("Service"));
        if (!s.getPlaceId().equals(place.getId())) {
            throw ApiException.notFound("Service");
        }
        return s;
    }

    private Staff staffMember(Long id) {
        return staff.findById(id).orElseThrow(() -> ApiException.notFound("Staff"));
    }

    private Booking booking(Long id) {
        return bookings.findById(id).orElseThrow(() -> ApiException.notFound("Booking"));
    }
}
