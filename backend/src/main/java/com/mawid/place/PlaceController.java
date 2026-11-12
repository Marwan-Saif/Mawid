package com.mawid.place;

import com.mawid.booking.BookingService;
import com.mawid.common.ApiException;
import com.mawid.place.PlaceDtos.Availability;
import com.mawid.place.PlaceDtos.PlaceDetails;
import com.mawid.place.PlaceDtos.PlaceSummary;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.time.LocalDate;
import java.util.List;
import java.util.Locale;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Places")
@RestController
@RequestMapping("/api/v1/places")
public class PlaceController {

    private final PlaceQueries queries;
    private final BookingService bookings;

    public PlaceController(PlaceQueries queries, BookingService bookings) {
        this.queries = queries;
        this.bookings = bookings;
    }

    @GetMapping
    public List<PlaceSummary> list(@RequestParam(required = false) Category category,
                                   @RequestParam(required = false) String q) {
        String needle = q == null ? null : q.trim().toLowerCase(Locale.ROOT);
        return queries.all().stream()
                .filter(p -> category == null || p.getCategory() == category)
                .filter(p -> needle == null || needle.isEmpty() || queries.matches(p, needle))
                .map(PlaceSummary::of)
                .toList();
    }

    @GetMapping("/{id}")
    public PlaceDetails details(@PathVariable Long id) {
        return queries.details(queries.byId(id));
    }

    @GetMapping("/{id}/availability")
    public Availability availability(@PathVariable Long id,
                                     @RequestParam Long serviceId,
                                     @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date,
                                     @RequestParam(required = false) Long staffId) {
        if (date.isAfter(LocalDate.now().plusDays(90))) {
            throw ApiException.badRequest("TOO_FAR", "Bookings open up to 90 days ahead");
        }
        return bookings.availability(id, serviceId, date, staffId);
    }
}
