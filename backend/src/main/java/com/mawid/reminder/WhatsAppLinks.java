package com.mawid.reminder;

import com.mawid.booking.BookingDtos.BookingDto;
import com.mawid.place.Place;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Locale;
import org.springframework.stereotype.Component;

/** wa.me click-to-chat links: free, no API key, and how customers in the region already talk to salons. */
@Component
public class WhatsAppLinks {

    private static final DateTimeFormatter WHEN =
            DateTimeFormatter.ofPattern("EEEE d MMMM, h:mm a", Locale.forLanguageTag("ar-EG"));

    public String messagePlace(Place place, BookingDto booking) {
        if (place.getPhone() == null || place.getPhone().isBlank()) {
            return null;
        }
        String when = booking.startAt().atZone(ZoneId.of(place.getTimezone())).format(WHEN);
        String text = "مرحبًا " + place.getNameAr() + "، حجزت " + booking.serviceNameAr() + " يوم " + when
                + " (رقم الحجز #" + booking.id() + ").";
        return link(place.getPhone(), text);
    }

    public static String link(String phone, String text) {
        String digits = phone.replaceAll("[^0-9]", "");
        return "https://wa.me/" + digits + "?text=" + URLEncoder.encode(text, StandardCharsets.UTF_8).replace("+", "%20");
    }
}
