package com.mawid.place;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalTime;
import java.util.List;

/** JSON shapes for places. Records keep the API contract in one readable file. */
public final class PlaceDtos {

    private PlaceDtos() {
    }

    public record PlaceSummary(Long id, String slug, String nameAr, String nameEn, Category category,
                               String areaAr, String areaEn, double rating, int reviewsCount, double distanceKm,
                               String timezone, String currency, String phone,
                               LocalTime openTime, LocalTime closeTime, List<String> closedDays) {
        public static PlaceSummary of(Place p) {
            return new PlaceSummary(p.getId(), p.getSlug(), p.getNameAr(), p.getNameEn(), p.getCategory(),
                    p.getAreaAr(), p.getAreaEn(), p.getRating(), p.getReviewsCount(), p.getDistanceKm(),
                    p.getTimezone(), p.getCurrency(), p.getPhone(), p.getOpenTime(), p.getCloseTime(),
                    p.getClosedDays().stream().map(Enum::name).sorted().toList());
        }
    }

    public record ServiceDto(Long id, Long placeId, String nameAr, String nameEn, int durationMin,
                             BigDecimal price, boolean active) {
        public static ServiceDto of(OfferedService s) {
            return new ServiceDto(s.getId(), s.getPlaceId(), s.getNameAr(), s.getNameEn(), s.getDurationMin(),
                    s.getPrice(), s.isActive());
        }
    }

    public record StaffDto(Long id, String name, String titleAr, String titleEn, List<Long> serviceIds,
                           List<String> daysOff) {
        public static StaffDto of(Staff s) {
            return new StaffDto(s.getId(), s.getName(), s.getTitleAr(), s.getTitleEn(),
                    s.getServiceIds().stream().sorted().toList(),
                    s.getDaysOff().stream().map(Enum::name).sorted().toList());
        }
    }

    public record ReviewDto(Long id, String authorName, int rating, String text, Instant createdAt) {
        public static ReviewDto of(Review r) {
            return new ReviewDto(r.getId(), r.getAuthorName(), r.getRating(), r.getText(), r.getCreatedAt());
        }
    }

    public record PlaceDetails(PlaceSummary place, List<ServiceDto> services, List<StaffDto> staff,
                               List<ReviewDto> reviews) {
    }

    public record SlotDto(Instant startAt, String localTime, boolean available, List<Long> freeStaffIds) {
    }

    public record Availability(String date, String timezone, int durationMin, List<SlotDto> slots) {
    }
}
