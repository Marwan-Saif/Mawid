package com.mawid.place;

import com.mawid.scheduling.SlotCalculator.WorkingHours;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.Table;
import java.time.DayOfWeek;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.EnumSet;
import java.util.HashSet;
import java.util.Set;

/** A clinic, salon or spa. Working hours are local to {@link #timezone}. */
@Entity
@Table(name = "places")
public class Place {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** Used in the public booking link: /b/{slug}. */
    @Column(nullable = false, unique = true)
    private String slug;

    @Column(nullable = false)
    private String nameAr;

    @Column(nullable = false)
    private String nameEn;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Category category;

    private String areaAr;
    private String areaEn;
    private double rating;
    private int reviewsCount;
    private double distanceKm;

    @Column(nullable = false)
    private String timezone;

    @Column(nullable = false)
    private String currency;

    /** WhatsApp number in international format, used for click-to-chat links. */
    private String phone;

    @Column(nullable = false)
    private LocalTime openTime;

    @Column(nullable = false)
    private LocalTime closeTime;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "place_closed_days", joinColumns = @JoinColumn(name = "place_id"))
    @Enumerated(EnumType.STRING)
    @Column(name = "day_of_week")
    private Set<DayOfWeek> closedDays = new HashSet<>();

    protected Place() {
    }

    public Place(String slug, String nameAr, String nameEn, Category category, String areaAr, String areaEn,
                 String timezone, String currency, String phone, LocalTime openTime, LocalTime closeTime,
                 Set<DayOfWeek> closedDays) {
        this.slug = slug;
        this.nameAr = nameAr;
        this.nameEn = nameEn;
        this.category = category;
        this.areaAr = areaAr;
        this.areaEn = areaEn;
        this.timezone = timezone;
        this.currency = currency;
        this.phone = phone;
        this.openTime = openTime;
        this.closeTime = closeTime;
        this.closedDays = new HashSet<>(closedDays);
    }

    public ZoneId zone() {
        return ZoneId.of(timezone);
    }

    public WorkingHours workingHours() {
        Set<DayOfWeek> closed = closedDays.isEmpty() ? EnumSet.noneOf(DayOfWeek.class) : EnumSet.copyOf(closedDays);
        return new WorkingHours(openTime, closeTime, closed);
    }

    public Place withStats(double rating, int reviewsCount, double distanceKm) {
        this.rating = rating;
        this.reviewsCount = reviewsCount;
        this.distanceKm = distanceKm;
        return this;
    }

    public Long getId() { return id; }
    public String getSlug() { return slug; }
    public String getNameAr() { return nameAr; }
    public String getNameEn() { return nameEn; }
    public Category getCategory() { return category; }
    public String getAreaAr() { return areaAr; }
    public String getAreaEn() { return areaEn; }
    public double getRating() { return rating; }
    public int getReviewsCount() { return reviewsCount; }
    public double getDistanceKm() { return distanceKm; }
    public String getTimezone() { return timezone; }
    public String getCurrency() { return currency; }
    public String getPhone() { return phone; }
    public LocalTime getOpenTime() { return openTime; }
    public LocalTime getCloseTime() { return closeTime; }
    public Set<DayOfWeek> getClosedDays() { return closedDays; }
}
