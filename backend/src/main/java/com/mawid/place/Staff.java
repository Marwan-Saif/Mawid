package com.mawid.place;

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
import java.time.Instant;
import java.util.HashSet;
import java.util.Set;

/** A team member. "Any available" picks among the staff whose serviceIds contain the service. */
@Entity
@Table(name = "staff")
public class Staff {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long placeId;

    @Column(nullable = false)
    private String name;

    private String titleAr;
    private String titleEn;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "staff_services", joinColumns = @JoinColumn(name = "staff_id"))
    @Column(name = "service_id")
    private Set<Long> serviceIds = new HashSet<>();

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "staff_days_off", joinColumns = @JoinColumn(name = "staff_id"))
    @Enumerated(EnumType.STRING)
    @Column(name = "day_of_week")
    private Set<DayOfWeek> daysOff = new HashSet<>();

    /** Room or chair patients are called to: "غرفة ٢", "Chair 1". */
    @Column(length = 40)
    private String room;

    @Enumerated(EnumType.STRING)
    @Column(length = 16)
    private StaffPresence presence;

    private Instant presenceSince;

    protected Staff() {
    }

    public Staff(Long placeId, String name, String titleAr, String titleEn, Set<Long> serviceIds, Set<DayOfWeek> daysOff) {
        this.placeId = placeId;
        this.name = name;
        this.titleAr = titleAr;
        this.titleEn = titleEn;
        this.serviceIds = new HashSet<>(serviceIds);
        this.daysOff = new HashSet<>(daysOff);
    }

    public boolean doesService(Long serviceId) {
        return serviceIds.contains(serviceId);
    }

    public void addService(Long serviceId) {
        serviceIds.add(serviceId);
    }

    public Staff inRoom(String room) {
        this.room = room;
        return this;
    }

    public void setPresence(StaffPresence presence, Instant at) {
        if (this.presence != presence) {
            this.presence = presence;
            this.presenceSince = at;
        }
    }

    /** Defaults to "available" for rows created before presence existed. */
    public StaffPresence getPresence() { return presence == null ? StaffPresence.AVAILABLE : presence; }
    public Instant getPresenceSince() { return presenceSince; }
    public String getRoom() { return room; }

    public Long getId() { return id; }
    public Long getPlaceId() { return placeId; }
    public String getName() { return name; }
    public String getTitleAr() { return titleAr; }
    public String getTitleEn() { return titleEn; }
    public Set<Long> getServiceIds() { return serviceIds; }
    public Set<DayOfWeek> getDaysOff() { return daysOff; }
}
