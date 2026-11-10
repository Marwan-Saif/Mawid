package com.mawid.place;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;

/** Something a place sells by time: "Haircut & styling, 45 min, 120 AED". */
@Entity
@Table(name = "services")
public class OfferedService {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long placeId;

    @Column(nullable = false)
    private String nameAr;

    @Column(nullable = false)
    private String nameEn;

    @Column(nullable = false)
    private int durationMin;

    @Column(nullable = false, precision = 10, scale = 2)
    private BigDecimal price;

    private boolean active = true;

    protected OfferedService() {
    }

    public OfferedService(Long placeId, String nameAr, String nameEn, int durationMin, BigDecimal price) {
        this.placeId = placeId;
        update(nameAr, nameEn, durationMin, price, true);
    }

    public void update(String nameAr, String nameEn, int durationMin, BigDecimal price, boolean active) {
        this.nameAr = nameAr;
        this.nameEn = nameEn;
        this.durationMin = durationMin;
        this.price = price;
        this.active = active;
    }

    public Long getId() { return id; }
    public Long getPlaceId() { return placeId; }
    public String getNameAr() { return nameAr; }
    public String getNameEn() { return nameEn; }
    public int getDurationMin() { return durationMin; }
    public BigDecimal getPrice() { return price; }
    public boolean isActive() { return active; }
}
