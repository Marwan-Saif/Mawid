package com.mawid.desk;

import static com.mawid.audit.AuditActions.BOOKING;
import static com.mawid.audit.AuditActions.CALLED;
import static com.mawid.audit.AuditActions.CHECKED_IN;
import static com.mawid.audit.AuditActions.NO_SHOW;
import static com.mawid.audit.AuditActions.PRESENCE_CHANGED;
import static com.mawid.audit.AuditActions.STAFF;
import static com.mawid.audit.AuditActions.VISIT_FINISHED;
import static com.mawid.audit.AuditActions.WALK_IN_ADDED;

import com.mawid.audit.AuditService;
import com.mawid.auth.AppUser;
import com.mawid.auth.AuthUser;
import com.mawid.auth.PhoneNumbers;
import com.mawid.auth.Role;
import com.mawid.auth.UserRepository;
import com.mawid.booking.Booking;
import com.mawid.booking.BookingDtos.BookingDto;
import com.mawid.booking.BookingRepository;
import com.mawid.booking.BookingService;
import com.mawid.booking.BookingService.Actor;
import com.mawid.booking.BookingService.NewBooking;
import com.mawid.booking.BookingSource;
import com.mawid.booking.BookingStatus;
import com.mawid.booking.BookingViews;
import com.mawid.common.ApiException;
import com.mawid.desk.DeskDtos.Board;
import com.mawid.desk.DeskDtos.Counts;
import com.mawid.desk.DeskDtos.Display;
import com.mawid.desk.DeskDtos.DisplayCall;
import com.mawid.desk.DeskDtos.DisplayEntry;
import com.mawid.desk.DeskDtos.DisplayStaff;
import com.mawid.desk.DeskDtos.PlaceInfo;
import com.mawid.desk.DeskDtos.QueueEntry;
import com.mawid.desk.DeskDtos.SelfCheckIn;
import com.mawid.desk.DeskDtos.StaffBoard;
import com.mawid.desk.DeskDtos.WalkInRequest;
import com.mawid.invoice.Invoice;
import com.mawid.invoice.InvoiceRepository;
import com.mawid.invoice.InvoiceStatus;
import com.mawid.place.OfferedServiceRepository;
import com.mawid.place.Place;
import com.mawid.place.PlaceDtos.ServiceDto;
import com.mawid.place.PlaceRepository;
import com.mawid.place.Staff;
import com.mawid.place.StaffPresence;
import com.mawid.place.StaffRepository;
import com.mawid.scheduling.QueueEstimator;
import com.mawid.scheduling.QueueEstimator.Estimate;
import com.mawid.scheduling.QueueEstimator.State;
import com.mawid.scheduling.QueueEstimator.Visit;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * The visit after the booking: arrive (QR or by hand) → wait → called to the room → done → invoice.
 *
 * <p>Every step is idempotent (checking in twice, or replaying a step from the app's offline
 * queue, returns the booking as it is) and writes an audit line in the same transaction.
 */
@Service
public class DeskService {

    /** Self check-in opens an hour before the booked time and stays open 30 minutes after it. */
    public static final Duration SELF_CHECK_IN_EARLY = Duration.ofMinutes(60);
    public static final Duration SELF_CHECK_IN_LATE = Duration.ofMinutes(30);

    private final BookingRepository bookingRepo;
    private final BookingService bookings;
    private final BookingViews views;
    private final PlaceRepository places;
    private final StaffRepository staff;
    private final OfferedServiceRepository services;
    private final UserRepository users;
    private final InvoiceRepository invoices;
    private final AuditService audit;
    private final Clock clock;

    public DeskService(BookingRepository bookingRepo, BookingService bookings, BookingViews views,
                       PlaceRepository places, StaffRepository staff, OfferedServiceRepository services,
                       UserRepository users, InvoiceRepository invoices, AuditService audit, Clock clock) {
        this.bookingRepo = bookingRepo;
        this.bookings = bookings;
        this.views = views;
        this.places = places;
        this.staff = staff;
        this.services = services;
        this.users = users;
        this.invoices = invoices;
        this.audit = audit;
        this.clock = clock;
    }

    // ================================================================ board

    @Transactional(readOnly = true)
    public Board board(Long placeId, LocalDate requested) {
        Place place = place(placeId);
        Instant now = Instant.now(clock);
        LocalDate today = today(place);
        LocalDate day = requested == null ? today : requested;

        List<Booking> list = bookingsOn(place, day);
        List<Staff> team = staff.findByPlaceIdOrderByIdAsc(placeId);
        Map<Long, Estimate> eta = day.equals(today) ? QueueEstimator.estimate(visits(list), now) : Map.of();
        Map<Long, Invoice> billed = invoicesFor(list);

        List<Booking> shown = list.stream().filter(b -> b.getStatus() != BookingStatus.CANCELLED).toList();
        Map<Long, BookingDto> dtos = views.list(shown).stream()
                .collect(Collectors.toMap(BookingDto::id, Function.identity()));
        List<QueueEntry> queue = new ArrayList<>();
        for (Booking b : shown) {
            Estimate e = eta.get(b.getId());
            Invoice inv = billed.get(b.getId());
            queue.add(new QueueEntry(dtos.get(b.getId()),
                    e == null ? b.getStartAt() : e.expectedStart(),
                    e == null ? 0 : e.delayMin(),
                    e == null ? 0 : e.ahead(),
                    e != null && e.late(),
                    inv == null ? null : inv.getId(),
                    inv == null ? null : inv.getNumber(),
                    inv == null ? null : inv.getStatus().name()));
        }

        List<StaffBoard> staffRows = team.stream().map(s -> new StaffBoard(s.getId(), s.getName(), s.getTitleAr(),
                s.getTitleEn(), s.getRoom(), s.getPresence(), s.getPresenceSince(),
                shown.stream().filter(b -> b.getStaffId().equals(s.getId())
                        && b.getStatus() == BookingStatus.IN_PROGRESS).map(Booking::getId).findFirst().orElse(null),
                (int) shown.stream().filter(b -> b.getStaffId().equals(s.getId())
                        && b.getStatus() == BookingStatus.ARRIVED).count())).toList();

        Counts counts = new Counts(
                count(shown, BookingStatus.PENDING) + count(shown, BookingStatus.CONFIRMED),
                count(shown, BookingStatus.ARRIVED),
                count(shown, BookingStatus.IN_PROGRESS),
                count(shown, BookingStatus.COMPLETED),
                count(shown, BookingStatus.NO_SHOW));
        List<ServiceDto> serviceRows = services.findByPlaceIdOrderByIdAsc(placeId).stream()
                .filter(s -> s.isActive()).map(ServiceDto::of).toList();
        return new Board(day.toString(), PlaceInfo.of(place), staffRows, queue, serviceRows, counts, now);
    }

    // ================================================================ arrive

    /** Reception scanned the customer's QR (or typed the code). */
    @Transactional
    public BookingDto checkInByCode(Long placeId, String scanned, AuthUser me) {
        String code = extractCode(scanned);
        Booking b = bookingRepo.findByCheckInCode(code)
                .filter(x -> x.getPlaceId().equals(placeId))
                .orElseThrow(() -> ApiException.notFound("Booking"));
        return views.of(checkIn(b, me, "QR"));
    }

    @Transactional
    public BookingDto checkIn(Long placeId, Long bookingId, AuthUser me) {
        return views.of(checkIn(own(placeId, bookingId), me, "DESK"));
    }

    /** Someone walked in without a booking: book the next free time with whoever is free, and queue them. */
    @Transactional
    public BookingDto walkIn(Long placeId, WalkInRequest req, AuthUser me) {
        Instant now = Instant.now(clock);
        String phone = PhoneNumbers.normalize(req.customerPhone());
        AppUser customer = users.findByPhone(phone).orElseGet(() -> users.save(
                new AppUser(phone, req.customerName().trim(), Role.CUSTOMER, null, now)));
        Instant start = bookings.firstFreeStart(placeId, req.serviceId(), req.staffId(), now, Duration.ofHours(6))
                .orElseThrow(() -> ApiException.conflict("NO_FREE_TIME", "Nobody is free for this service today"));
        Booking b = bookings.create(new NewBooking(placeId, req.serviceId(), req.staffId(), customer.getId(), start,
                req.note(), BookingSource.WALK_IN, BookingStatus.CONFIRMED), Actor.DESK);
        audit.record(placeId, me, WALK_IN_ADDED, BOOKING, b.getId(), customer.getName(),
                Map.of("serviceId", req.serviceId(), "startAt", start.toString()));
        return views.of(checkIn(b, me, "WALK_IN"));
    }

    // ================================================================ the room

    @Transactional
    public BookingDto call(Long placeId, Long bookingId, AuthUser me) {
        Booking b = own(placeId, bookingId);
        boolean repeat = b.getStatus() == BookingStatus.IN_PROGRESS;
        if (!repeat) {
            if (b.getStatus() == BookingStatus.CONFIRMED || b.getStatus() == BookingStatus.PENDING) {
                throw ApiException.conflict("NOT_CHECKED_IN", "Check this person in first");
            }
            if (b.getStatus() != BookingStatus.ARRIVED) {
                throw ApiException.conflict("NOT_CALLABLE", "This visit can't be called now");
            }
            Place place = place(placeId);
            boolean busy = bookingsOn(place, today(place)).stream()
                    .anyMatch(x -> x.getStaffId().equals(b.getStaffId()) && x.getStatus() == BookingStatus.IN_PROGRESS
                            && !x.getId().equals(b.getId()));
            if (busy) {
                throw ApiException.conflict("STAFF_BUSY", "Still with another patient; finish that visit first");
            }
        }
        Staff s = staffMember(b.getStaffId());
        Instant now = Instant.now(clock);
        b.call(s.getRoom(), now);
        s.setPresence(StaffPresence.BUSY, now);
        Map<String, Object> d = new LinkedHashMap<>();
        d.put("ticket", b.getTicketNo());
        d.put("room", s.getRoom());
        d.put("staff", s.getName());
        d.put("repeat", repeat);
        audit.record(placeId, me, CALLED, BOOKING, b.getId(), customerName(b), d);
        return views.of(b);
    }

    @Transactional
    public BookingDto finish(Long placeId, Long bookingId, AuthUser me) {
        Booking b = own(placeId, bookingId);
        if (b.getStatus() == BookingStatus.COMPLETED) {
            return views.of(b);
        }
        if (b.getStatus() != BookingStatus.IN_PROGRESS && b.getStatus() != BookingStatus.ARRIVED) {
            throw ApiException.conflict("NOT_IN_ROOM", "This visit hasn't started");
        }
        Instant now = Instant.now(clock);
        b.finish(now);
        Staff s = staffMember(b.getStaffId());
        Place place = place(placeId);
        boolean stillBusy = bookingsOn(place, today(place)).stream()
                .anyMatch(x -> x.getStaffId().equals(s.getId()) && x.getStatus() == BookingStatus.IN_PROGRESS
                        && !x.getId().equals(b.getId()));
        if (!stillBusy && s.getPresence() == StaffPresence.BUSY) {
            s.setPresence(StaffPresence.AVAILABLE, now);
        }
        Map<String, Object> d = new LinkedHashMap<>();
        d.put("ticket", b.getTicketNo());
        d.put("staff", s.getName());
        if (b.getStartedAt() != null) {
            d.put("minutes", Duration.between(b.getStartedAt(), now).toMinutes());
        }
        audit.record(placeId, me, VISIT_FINISHED, BOOKING, b.getId(), customerName(b), d);
        return views.of(b);
    }

    @Transactional
    public BookingDto noShow(Long placeId, Long bookingId, AuthUser me) {
        Booking b = own(placeId, bookingId);
        if (b.getStatus() == BookingStatus.NO_SHOW) {
            return views.of(b);
        }
        if (b.getStatus() != BookingStatus.CONFIRMED && b.getStatus() != BookingStatus.PENDING
                && b.getStatus() != BookingStatus.ARRIVED) {
            throw ApiException.conflict("NOT_CHANGEABLE", "This visit can't be marked as a no-show");
        }
        Booking updated = bookings.updateStatus(b.getId(), BookingStatus.NO_SHOW, me);
        audit.record(placeId, me, NO_SHOW, BOOKING, b.getId(), customerName(b),
                Map.of("startAt", b.getStartAt().toString()));
        return views.of(updated);
    }

    @Transactional
    public StaffBoard presence(Long placeId, Long staffId, StaffPresence presence, AuthUser me) {
        Staff s = staffMember(staffId);
        if (!s.getPlaceId().equals(placeId)) {
            throw ApiException.notFound("Staff");
        }
        StaffPresence before = s.getPresence();
        s.setPresence(presence, Instant.now(clock));
        if (before != presence) {
            audit.record(placeId, me, PRESENCE_CHANGED, STAFF, s.getId(), s.getName(),
                    Map.of("from", before.name(), "to", presence.name()));
        }
        return new StaffBoard(s.getId(), s.getName(), s.getTitleAr(), s.getTitleEn(), s.getRoom(), s.getPresence(),
                s.getPresenceSince(), null, 0);
    }

    // ================================================================ waiting-room screen

    @Transactional(readOnly = true)
    public Display display(String slug) {
        Place place = places.findBySlug(slug).orElseThrow(() -> ApiException.notFound("Place"));
        Instant now = Instant.now(clock);
        List<Booking> list = bookingsOn(place, today(place));
        Map<Long, Estimate> eta = QueueEstimator.estimate(visits(list), now);
        List<Staff> team = staff.findByPlaceIdOrderByIdAsc(place.getId());
        Map<Long, Staff> staffById = team.stream().collect(Collectors.toMap(Staff::getId, Function.identity()));
        Map<Long, String> names = screenNames(list);

        List<DisplayStaff> staffRows = team.stream().map(s -> {
            Booking serving = list.stream().filter(b -> b.getStaffId().equals(s.getId())
                    && b.getStatus() == BookingStatus.IN_PROGRESS).findFirst().orElse(null);
            return new DisplayStaff(s.getId(), s.getName(), s.getTitleAr(), s.getTitleEn(), s.getRoom(),
                    s.getPresence(), serving == null ? null : serving.getTicketNo(),
                    serving == null ? null : names.get(serving.getId()));
        }).toList();

        List<DisplayEntry> waiting = list.stream()
                .filter(b -> b.getStatus() == BookingStatus.ARRIVED)
                .sorted(Comparator.comparing((Booking b) -> eta.containsKey(b.getId())
                        ? eta.get(b.getId()).expectedStart() : b.getStartAt()).thenComparing(Booking::getId))
                .map(b -> {
                    Estimate e = eta.get(b.getId());
                    Staff s = staffById.get(b.getStaffId());
                    int etaMin = e == null ? 0 : (int) Math.max(0, Duration.between(now, e.expectedStart()).toMinutes());
                    return new DisplayEntry(b.getTicketNo() == null ? 0 : b.getTicketNo(), names.get(b.getId()),
                            b.getStaffId(), s == null ? null : s.getName(), s == null ? null : s.getRoom(),
                            etaMin, e == null ? 0 : e.delayMin());
                })
                .toList();

        DisplayCall last = list.stream()
                .filter(b -> b.getCalledAt() != null && b.getCalledAt().isAfter(now.minus(Duration.ofHours(2))))
                .max(Comparator.comparing(Booking::getCalledAt))
                .map(b -> {
                    Staff s = staffById.get(b.getStaffId());
                    return new DisplayCall(b.getId() + "-" + b.getCallCount(), b.getTicketNo(), names.get(b.getId()),
                            b.getRoom(), s == null ? null : s.getName(), b.getCalledAt());
                })
                .orElse(null);
        int served = count(list, BookingStatus.COMPLETED);
        return new Display(PlaceInfo.of(place), staffRows, waiting, last, served, now);
    }

    // ================================================================ the customer's own phone

    @Transactional(readOnly = true)
    public SelfCheckIn selfStatus(String code) {
        Booking b = byCode(code);
        return selfView(b, Instant.now(clock));
    }

    /** The customer tapped "I'm here" on /c/{code} (from the QR or the WhatsApp reminder). */
    @Transactional
    public SelfCheckIn selfCheckIn(String code) {
        Booking b = byCode(code);
        Instant now = Instant.now(clock);
        Place place = place(b.getPlaceId());
        if (b.getStatus() == BookingStatus.CONFIRMED || b.getStatus() == BookingStatus.PENDING) {
            if (!inSelfWindow(b, place, now)) {
                throw ApiException.conflict("CHECKIN_WINDOW",
                        "Check-in opens an hour before your appointment, on the day");
            }
            checkIn(b, null, "SELF");
        } else if (b.getStatus() == BookingStatus.CANCELLED || b.getStatus() == BookingStatus.NO_SHOW) {
            throw ApiException.conflict("NOT_CHECKABLE", "This booking is no longer active. Please see reception.");
        }
        return selfView(b, now);
    }

    // ================================================================ helpers

    private Booking checkIn(Booking b, AuthUser me, String via) {
        switch (b.getStatus()) {
            case ARRIVED, IN_PROGRESS, COMPLETED -> {
                return b; // already here: scanning twice is fine
            }
            case CANCELLED -> throw ApiException.conflict("BOOKING_CANCELLED", "This booking was cancelled");
            default -> {
            }
        }
        Place place = places.lockById(b.getPlaceId()).orElseThrow(() -> ApiException.notFound("Place"));
        LocalDate today = today(place);
        if (!b.getStartAt().atZone(place.zone()).toLocalDate().equals(today)) {
            throw ApiException.conflict("NOT_TODAY", "This booking is for another day");
        }
        Booking target = b;
        if (b.getStatus() == BookingStatus.NO_SHOW) {
            // Came late after all: take the time back, only if it's still free.
            target = bookings.updateStatus(b.getId(), BookingStatus.ARRIVED, me);
        }
        Instant from = today.atStartOfDay(place.zone()).toInstant();
        Instant to = today.plusDays(1).atStartOfDay(place.zone()).toInstant();
        int ticket = bookingRepo.maxTicket(place.getId(), from, to) + 1;
        target.checkIn(ticket, Instant.now(clock));
        bookingRepo.flush();
        audit.record(place.getId(), me, CHECKED_IN, BOOKING, target.getId(), customerName(target),
                Map.of("ticket", ticket, "via", via));
        return target;
    }

    private SelfCheckIn selfView(Booking b, Instant now) {
        Place place = place(b.getPlaceId());
        BookingDto dto = views.of(b);
        Integer ahead = null;
        Integer etaMin = null;
        if (b.getStatus() == BookingStatus.ARRIVED) {
            Map<Long, Estimate> eta = QueueEstimator.estimate(visits(bookingsOn(place, today(place))), now);
            Estimate e = eta.get(b.getId());
            if (e != null) {
                ahead = e.ahead();
                etaMin = (int) Math.max(0, Duration.between(now, e.expectedStart()).toMinutes());
            }
        }
        boolean can = (b.getStatus() == BookingStatus.CONFIRMED || b.getStatus() == BookingStatus.PENDING)
                && inSelfWindow(b, place, now);
        return new SelfCheckIn(place.getSlug(), place.getNameAr(), place.getNameEn(), place.getTimezone(),
                b.getStatus(), b.getStartAt(), dto.serviceNameAr(), dto.serviceNameEn(), dto.staffName(),
                b.getTicketNo(), ahead, etaMin, b.getRoom(), can, b.getStartAt().minus(SELF_CHECK_IN_EARLY));
    }

    private boolean inSelfWindow(Booking b, Place place, Instant now) {
        boolean today = b.getStartAt().atZone(place.zone()).toLocalDate().equals(today(place));
        return today && !now.isBefore(b.getStartAt().minus(SELF_CHECK_IN_EARLY))
                && !now.isAfter(b.getStartAt().plus(SELF_CHECK_IN_LATE));
    }

    /** Accepts "K7Q2M9XW3A", "mawid:K7Q2..." or "https://host/c/K7Q2...". */
    static String extractCode(String scanned) {
        String s = scanned.trim();
        int slash = s.lastIndexOf("/c/");
        if (slash >= 0) {
            s = s.substring(slash + 3);
        }
        int colon = s.lastIndexOf(':');
        if (colon >= 0 && !s.startsWith("http")) {
            s = s.substring(colon + 1);
        }
        int cut = s.indexOf('?');
        if (cut >= 0) {
            s = s.substring(0, cut);
        }
        s = s.replace("/", "").trim().toUpperCase();
        if (s.isEmpty() || s.length() > 16) {
            throw ApiException.badRequest("INVALID_CODE", "That isn't a Mawid check-in code");
        }
        return s;
    }

    private static List<Visit> visits(List<Booking> list) {
        List<Visit> out = new ArrayList<>();
        for (Booking b : list) {
            State st = switch (b.getStatus()) {
                case PENDING, CONFIRMED -> State.BOOKED;
                case ARRIVED -> State.ARRIVED;
                case IN_PROGRESS -> State.IN_ROOM;
                default -> null;
            };
            if (st != null) {
                out.add(new Visit(b.getId(), b.getStaffId(), b.getStartAt(), b.getDurationMin(), st, b.getStartedAt()));
            }
        }
        return out;
    }

    private Map<Long, Invoice> invoicesFor(List<Booking> list) {
        if (list.isEmpty()) {
            return Map.of();
        }
        Map<Long, Invoice> out = new HashMap<>();
        for (Invoice i : invoices.findByBookingIdInAndStatusNot(list.stream().map(Booking::getId).toList(),
                InvoiceStatus.VOID)) {
            out.put(i.getBookingId(), i);
        }
        return out;
    }

    private Map<Long, String> screenNames(List<Booking> list) {
        Map<Long, String> byUser = new HashMap<>();
        Map<Long, String> out = new HashMap<>();
        for (Booking b : list) {
            String n = byUser.computeIfAbsent(b.getCustomerId(),
                    id -> users.findById(id).map(AppUser::getName).map(DisplayNames::forScreen).orElse(""));
            out.put(b.getId(), n);
        }
        return out;
    }

    private String customerName(Booking b) {
        return users.findById(b.getCustomerId()).map(AppUser::getName).orElse("#" + b.getId());
    }

    /** "Today" at the place, from the injected clock (tests pin it). */
    private LocalDate today(Place place) {
        return Instant.now(clock).atZone(place.zone()).toLocalDate();
    }

    private List<Booking> bookingsOn(Place place, LocalDate day) {
        Instant from = day.atStartOfDay(place.zone()).toInstant();
        Instant to = day.plusDays(1).atStartOfDay(place.zone()).toInstant();
        return bookingRepo.findByPlaceIdAndStartAtGreaterThanEqualAndStartAtLessThanOrderByStartAtAsc(
                place.getId(), from, to);
    }

    private static int count(List<Booking> list, BookingStatus status) {
        return (int) list.stream().filter(b -> b.getStatus() == status).count();
    }

    private Booking own(Long placeId, Long bookingId) {
        return bookingRepo.findById(bookingId)
                .filter(b -> Objects.equals(b.getPlaceId(), placeId))
                .orElseThrow(() -> ApiException.notFound("Booking"));
    }

    private Booking byCode(String code) {
        return bookingRepo.findByCheckInCode(extractCode(code)).orElseThrow(() -> ApiException.notFound("Booking"));
    }

    private Place place(Long id) {
        return places.findById(id).orElseThrow(() -> ApiException.notFound("Place"));
    }

    private Staff staffMember(Long id) {
        return staff.findById(id).orElseThrow(() -> ApiException.notFound("Staff"));
    }
}
