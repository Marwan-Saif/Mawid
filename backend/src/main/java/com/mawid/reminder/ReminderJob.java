package com.mawid.reminder;

import com.mawid.auth.AppUser;
import com.mawid.auth.UserRepository;
import com.mawid.booking.Booking;
import com.mawid.booking.BookingRepository;
import com.mawid.booking.BookingStatus;
import com.mawid.place.OfferedService;
import com.mawid.place.OfferedServiceRepository;
import com.mawid.place.Place;
import com.mawid.place.PlaceRepository;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.format.DateTimeFormatter;
import java.util.EnumSet;
import java.util.List;
import java.util.Locale;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Server-side reminder about one hour before the appointment. Runs every few minutes and marks
 * each booking as reminded, so restarts never send twice. Server reminders reach customers who
 * booked from the web link and never installed the app, which is what cuts no-shows.
 */
@Component
@ConditionalOnProperty(prefix = "mawid.reminders", name = "enabled", havingValue = "true", matchIfMissing = true)
public class ReminderJob {

    static final Duration LEAD = Duration.ofMinutes(60);
    private static final DateTimeFormatter TIME = DateTimeFormatter.ofPattern("h:mm a", Locale.forLanguageTag("ar-EG"));

    private final BookingRepository bookings;
    private final PlaceRepository places;
    private final OfferedServiceRepository services;
    private final UserRepository users;
    private final Notifier notifier;
    private final Clock clock;

    public ReminderJob(BookingRepository bookings, PlaceRepository places, OfferedServiceRepository services,
                       UserRepository users, Notifier notifier, Clock clock) {
        this.bookings = bookings;
        this.places = places;
        this.services = services;
        this.users = users;
        this.notifier = notifier;
        this.clock = clock;
    }

    @Scheduled(fixedDelayString = "${mawid.reminders.interval-ms:300000}", initialDelay = 30_000)
    public void run() {
        remindDue();
    }

    /** Sends every due reminder; returns how many bookings were handled. */
    @Transactional
    public int remindDue() {
        Instant now = Instant.now(clock);
        List<Booking> due = bookings.findByStatusInAndRemindedAtIsNullAndStartAtGreaterThanEqualAndStartAtLessThan(
                EnumSet.of(BookingStatus.PENDING, BookingStatus.CONFIRMED), now, now.plus(LEAD));
        for (Booking b : due) {
            AppUser customer = users.findById(b.getCustomerId()).orElse(null);
            Place place = places.findById(b.getPlaceId()).orElse(null);
            OfferedService service = services.findById(b.getServiceId()).orElse(null);
            if (customer != null && place != null && service != null) {
                String time = b.getStartAt().atZone(place.zone()).format(TIME);
                notifier.send(customer.getPhone(), "تذكير: موعدك " + service.getNameAr() + " في " + place.getNameAr()
                        + " الساعة " + time + " | Reminder: " + service.getNameEn() + " at " + place.getNameEn());
            }
            b.markReminded(now);
            bookings.save(b); // explicit: run() calls this without the transactional proxy
        }
        return due.size();
    }
}
