package com.mawid.place;

import com.mawid.common.ApiException;
import com.mawid.place.PlaceDtos.PlaceDetails;
import com.mawid.place.PlaceDtos.PlaceSummary;
import com.mawid.place.PlaceDtos.ReviewDto;
import com.mawid.place.PlaceDtos.ServiceDto;
import com.mawid.place.PlaceDtos.StaffDto;
import java.util.List;
import java.util.Locale;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class PlaceQueries {

    private final PlaceRepository places;
    private final OfferedServiceRepository services;
    private final StaffRepository staff;
    private final ReviewRepository reviews;

    public PlaceQueries(PlaceRepository places, OfferedServiceRepository services, StaffRepository staff,
                        ReviewRepository reviews) {
        this.places = places;
        this.services = services;
        this.staff = staff;
        this.reviews = reviews;
    }

    public List<Place> all() {
        return places.findAllByOrderByDistanceKmAsc();
    }

    public Place byId(Long id) {
        return places.findById(id).orElseThrow(() -> ApiException.notFound("Place"));
    }

    public Place bySlug(String slug) {
        return places.findBySlug(slug).orElseThrow(() -> ApiException.notFound("Place"));
    }

    /** Search by place name or by the name of any active service, in both languages. */
    public boolean matches(Place p, String needle) {
        if (contains(p.getNameAr(), needle) || contains(p.getNameEn(), needle)
                || contains(p.getAreaAr(), needle) || contains(p.getAreaEn(), needle)) {
            return true;
        }
        return services.findByPlaceIdAndActiveTrueOrderByIdAsc(p.getId()).stream()
                .anyMatch(s -> contains(s.getNameAr(), needle) || contains(s.getNameEn(), needle));
    }

    public PlaceDetails details(Place p) {
        return details(p, false);
    }

    public PlaceDetails details(Place p, boolean includeInactive) {
        List<OfferedService> list = includeInactive
                ? services.findByPlaceIdOrderByIdAsc(p.getId())
                : services.findByPlaceIdAndActiveTrueOrderByIdAsc(p.getId());
        return new PlaceDetails(PlaceSummary.of(p),
                list.stream().map(ServiceDto::of).toList(),
                staff.findByPlaceIdOrderByIdAsc(p.getId()).stream().map(StaffDto::of).toList(),
                reviews.findByPlaceIdOrderByCreatedAtDesc(p.getId()).stream().map(ReviewDto::of).toList());
    }

    private static boolean contains(String haystack, String needle) {
        return haystack != null && haystack.toLowerCase(Locale.ROOT).contains(needle);
    }
}
