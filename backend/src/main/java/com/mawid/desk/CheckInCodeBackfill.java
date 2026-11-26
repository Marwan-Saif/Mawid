package com.mawid.desk;

import com.mawid.booking.Booking;
import com.mawid.booking.BookingRepository;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/** Bookings saved before QR check-in existed get their code once, at startup. */
@Component
@Order(0)
public class CheckInCodeBackfill implements ApplicationRunner {

    private static final Logger log = LoggerFactory.getLogger(CheckInCodeBackfill.class);

    private final BookingRepository bookings;

    public CheckInCodeBackfill(BookingRepository bookings) {
        this.bookings = bookings;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        List<Booking> missing = bookings.findByCheckInCodeIsNull();
        missing.forEach(Booking::ensureCheckInCode);
        if (!missing.isEmpty()) {
            log.info("Gave {} older bookings a check-in code", missing.size());
        }
    }
}
