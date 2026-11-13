package com.mawid.seed;

import static java.time.DayOfWeek.FRIDAY;
import static java.time.DayOfWeek.SUNDAY;

import com.mawid.auth.AppUser;
import com.mawid.auth.AuthController;
import com.mawid.auth.Role;
import com.mawid.auth.UserRepository;
import com.mawid.booking.Booking;
import com.mawid.booking.BookingService;
import com.mawid.booking.BookingService.Actor;
import com.mawid.booking.BookingService.NewBooking;
import com.mawid.booking.BookingSource;
import com.mawid.booking.BookingStatus;
import com.mawid.common.ApiException;
import com.mawid.place.Category;
import com.mawid.place.OfferedService;
import com.mawid.place.OfferedServiceRepository;
import com.mawid.place.Place;
import com.mawid.place.PlaceRepository;
import com.mawid.place.Review;
import com.mawid.place.ReviewRepository;
import com.mawid.place.Staff;
import com.mawid.place.StaffRepository;
import com.mawid.scheduling.SlotCalculator;
import java.math.BigDecimal;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Demo data so the app, the booking page and Swagger have something real to show on first run:
 * two salons/spas in Dubai and two clinics in Cairo, staff, services, reviews, a demo customer
 * and a demo owner, and a realistic "today" for the owner dashboard.
 */
@Component
@ConditionalOnProperty(prefix = "mawid.seed", name = "enabled", havingValue = "true")
public class DemoDataSeeder implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(DemoDataSeeder.class);

    private final PlaceRepository places;
    private final OfferedServiceRepository services;
    private final StaffRepository staff;
    private final ReviewRepository reviews;
    private final UserRepository users;
    private final BookingService bookings;
    private final Clock clock;

    public DemoDataSeeder(PlaceRepository places, OfferedServiceRepository services, StaffRepository staff,
                          ReviewRepository reviews, UserRepository users, BookingService bookings,
                          Clock clock) {
        this.places = places;
        this.services = services;
        this.staff = staff;
        this.reviews = reviews;
        this.users = users;
        this.bookings = bookings;
        this.clock = clock;
    }

    @Override
    public void run(ApplicationArguments args) {
        if (places.count() > 0) {
            return;
        }
        // No outer transaction on purpose: each booking commits on its own, so one skipped
        // demo booking (e.g. a stylist's day off) can't roll the whole seed back.
        seed();
        log.info("Demo data seeded: {} places, {} users", places.count(), users.count());
    }

    private void seed() {
        Instant now = Instant.now(clock);

        // ------------------------------------------------------------ Lamsa Salon, Dubai
        Place lamsa = places.save(new Place("lamsa-salon", "صالون لمسة", "Lamsa Salon", Category.SALON,
                "القرهود، دبي", "Al Garhoud, Dubai", "Asia/Dubai", "AED", "+971500000010",
                LocalTime.of(10, 0), LocalTime.of(22, 0), Set.of()).withStats(4.8, 214, 1.2));
        OfferedService haircut = service(lamsa, "قص شعر وتصفيف", "Haircut & styling", 45, "120");
        OfferedService colour = service(lamsa, "صبغة كاملة", "Full colour", 90, "350");
        OfferedService protein = service(lamsa, "بروتين وعلاج", "Protein treatment", 120, "600");
        OfferedService nails = service(lamsa, "مانيكير وباديكير", "Manicure & pedicure", 60, "150");
        Set<Long> lamsaAll = Set.of(haircut.getId(), colour.getId(), protein.getId(), nails.getId());
        Staff noura = staff.save(new Staff(lamsa.getId(), "نورا", "خبيرة شعر", "Hair specialist", lamsaAll, Set.of()));
        Staff reem = staff.save(new Staff(lamsa.getId(), "ريم", "مصففة شعر", "Stylist",
                Set.of(haircut.getId(), nails.getId()), Set.of(SUNDAY)));
        review(lamsa, "سارة م.", 5, "خدمة ممتازة ونورا شاطرة جدًا في الصبغة.", 3);
        review(lamsa, "Hind A.", 5, "Booked in seconds, no calls needed. Lovely place.", 9);
        review(lamsa, "منى ع.", 4, "المكان نضيف والمواعيد مظبوطة.", 20);

        // ------------------------------------------------------------ Serenity Spa, Dubai
        Place spa = places.save(new Place("serenity-spa", "سيرينيتي سبا", "Serenity Spa", Category.SPA,
                "جميرا، دبي", "Jumeirah, Dubai", "Asia/Dubai", "AED", "+971500000020",
                LocalTime.of(10, 0), LocalTime.of(23, 0), Set.of()).withStats(4.7, 98, 3.4));
        OfferedService massage = service(spa, "مساج استرخاء", "Relaxing massage", 60, "300");
        OfferedService hammam = service(spa, "حمام مغربي", "Moroccan bath", 90, "400");
        Set<Long> spaAll = Set.of(massage.getId(), hammam.getId());
        staff.save(new Staff(spa.getId(), "ليلى", "معالجة", "Therapist", spaAll, Set.of()));
        staff.save(new Staff(spa.getId(), "هالة", "معالجة", "Therapist", spaAll, Set.of(FRIDAY)));
        review(spa, "Aisha K.", 5, "The Moroccan bath was perfect.", 5);

        // ------------------------------------------------------------ Smile Clinic, Cairo
        Place smile = places.save(new Place("smile-clinic", "عيادة سمايل", "Smile Clinic", Category.DENTAL,
                "مدينة نصر، القاهرة", "Nasr City, Cairo", "Africa/Cairo", "EGP", "+201000000010",
                LocalTime.of(12, 0), LocalTime.of(22, 0), Set.of(FRIDAY)).withStats(4.9, 167, 2.1));
        OfferedService checkup = service(smile, "كشف أسنان", "Dental check-up", 30, "300");
        OfferedService cleaning = service(smile, "تنظيف جير", "Scaling & cleaning", 45, "600");
        OfferedService filling = service(smile, "حشو تجميلي", "Cosmetic filling", 60, "900");
        Set<Long> smileAll = Set.of(checkup.getId(), cleaning.getId(), filling.getId());
        Staff drSara = staff.save(new Staff(smile.getId(), "د. سارة خالد", "طبيبة أسنان", "Dentist", smileAll, Set.of()));
        staff.save(new Staff(smile.getId(), "د. عمر حسن", "طبيب أسنان", "Dentist", smileAll, Set.of(SUNDAY)));
        review(smile, "محمد ف.", 5, "د. سارة محترمة جدًا والكشف كان سريع.", 2);
        review(smile, "Youssef T.", 5, "Got the 3-hour reminder and the booking was exactly on time.", 12);

        // ------------------------------------------------------------ Care Clinic, Cairo
        Place care = places.save(new Place("care-clinic", "عيادة كير", "Care Clinic", Category.CLINIC,
                "المعادي، القاهرة", "Maadi, Cairo", "Africa/Cairo", "EGP", "+201000000020",
                LocalTime.of(9, 0), LocalTime.of(17, 0), Set.of(FRIDAY)).withStats(4.6, 75, 4.8));
        OfferedService consult = service(care, "كشف باطنة", "Internal medicine consult", 30, "400");
        OfferedService followUp = service(care, "متابعة", "Follow-up visit", 15, "250");
        staff.save(new Staff(care.getId(), "د. أحمد منصور", "استشاري باطنة", "Consultant physician",
                Set.of(consult.getId(), followUp.getId()), Set.of()));

        // ------------------------------------------------------------ people
        AppUser ahmed = users.save(new AppUser(AuthController.DEMO_CUSTOMER_PHONE, "أحمد", Role.CUSTOMER, null, now));
        users.save(new AppUser(AuthController.DEMO_OWNER_PHONE, "مدام نهى", Role.OWNER, lamsa.getId(), now));
        users.save(new AppUser("+201000000002", "د. سارة خالد", Role.OWNER, smile.getId(), now));
        AppUser mariam = customer("+971500000101", "مريم ع.", now);
        AppUser hala = customer("+971500000102", "هالة م.", now);
        AppUser dina = customer("+971500000103", "دينا س.", now);
        AppUser lama = customer("+971500000104", "لمى ك.", now);
        AppUser salma = customer("+971500000105", "سلمى ر.", now);

        // ------------------------------------------------------------ a believable "today" at Lamsa
        LocalDate today = LocalDate.now(lamsa.zone());
        todayBooking(lamsa, colour, noura, mariam, today, LocalTime.of(10, 0), now);
        todayBooking(lamsa, haircut, reem, hala, today, LocalTime.of(11, 30), now);
        todayBooking(lamsa, protein, noura, dina, today, LocalTime.of(13, 0), now);
        todayBooking(lamsa, nails, noura, lama, today, LocalTime.of(16, 0), now);
        todayBooking(lamsa, haircut, reem, salma, today, LocalTime.of(18, 30), now);

        // ------------------------------------------------------------ Ahmed's own bookings
        Instant nextDental = firstOpenTimeAfter(smile, checkup.getDurationMin(), now.plus(Duration.ofHours(2)));
        tryBook(smile, checkup, drSara, ahmed, nextDental, BookingStatus.CONFIRMED, BookingSource.APP);
        Instant inThreeDays = today.plusDays(3).atTime(17, 0).atZone(lamsa.zone()).toInstant();
        tryBook(lamsa, haircut, null, ahmed, inThreeDays, BookingStatus.CONFIRMED, BookingSource.APP);
        Instant lastWeek = today.minusDays(7).atTime(17, 0).atZone(lamsa.zone()).toInstant();
        tryBook(lamsa, haircut, reem, ahmed, lastWeek, BookingStatus.COMPLETED, BookingSource.APP);
    }

    private OfferedService service(Place p, String ar, String en, int minutes, String price) {
        return services.save(new OfferedService(p.getId(), ar, en, minutes, new BigDecimal(price)));
    }

    private void review(Place p, String author, int rating, String text, int daysAgo) {
        reviews.save(new Review(p.getId(), author, rating, text, Instant.now(clock).minus(Duration.ofDays(daysAgo))));
    }

    private AppUser customer(String phone, String name, Instant now) {
        return users.save(new AppUser(phone, name, Role.CUSTOMER, null, now));
    }

    private void todayBooking(Place p, OfferedService s, Staff st, AppUser c, LocalDate day, LocalTime at,
                              Instant now) {
        Instant start = day.atTime(at).atZone(p.zone()).toInstant();
        Instant end = start.plus(Duration.ofMinutes(s.getDurationMin()));
        BookingStatus status = !end.isAfter(now) ? BookingStatus.COMPLETED
                : !start.isAfter(now) ? BookingStatus.IN_PROGRESS
                : BookingStatus.CONFIRMED;
        tryBook(p, s, st, c, start, status, BookingSource.APP);
    }

    private void tryBook(Place p, OfferedService s, Staff st, AppUser c, Instant start, BookingStatus status,
                         BookingSource source) {
        if (start == null) {
            return;
        }
        try {
            Booking b = bookings.create(new NewBooking(p.getId(), s.getId(), st == null ? null : st.getId(),
                    c.getId(), start, null, source, status), Actor.SYSTEM);
            log.debug("Seeded booking #{}", b.getId());
        } catch (ApiException e) {
            if (st != null) {
                tryBook(p, s, null, c, start, status, source); // that person is off today: anyone free
            } else {
                log.debug("Skipped demo booking at {}: {}", start, e.code());
            }
        }
    }

    /** First 15-minute start at or after {@code from} that fits the place's working hours (within a week). */
    private static Instant firstOpenTimeAfter(Place p, int durationMin, Instant from) {
        Instant t = SlotCalculator.alignDown(from).plus(Duration.ofMinutes(SlotCalculator.UNIT_MINUTES));
        Instant limit = from.plus(Duration.ofDays(7));
        while (t.isBefore(limit)) {
            if (SlotCalculator.fitsWorkingHours(t, durationMin, p.zone(), p.workingHours())) {
                return t;
            }
            t = t.plus(Duration.ofMinutes(SlotCalculator.UNIT_MINUTES));
        }
        return null;
    }
}
