package com.mawid.place;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "reviews")
public class Review {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private Long placeId;

    @Column(nullable = false)
    private String authorName;

    private int rating;

    @Column(length = 1000)
    private String text;

    private Instant createdAt;

    protected Review() {
    }

    public Review(Long placeId, String authorName, int rating, String text, Instant createdAt) {
        this.placeId = placeId;
        this.authorName = authorName;
        this.rating = rating;
        this.text = text;
        this.createdAt = createdAt;
    }

    public Long getId() { return id; }
    public Long getPlaceId() { return placeId; }
    public String getAuthorName() { return authorName; }
    public int getRating() { return rating; }
    public String getText() { return text; }
    public Instant getCreatedAt() { return createdAt; }
}
