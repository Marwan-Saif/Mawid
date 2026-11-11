package com.mawid.auth;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;

@Entity
@Table(name = "users")
public class AppUser {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** E.164, e.g. +971500000001. The login identity. */
    @Column(nullable = false, unique = true)
    private String phone;

    private String name;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Role role;

    /** Set for owners: the place they manage. */
    private Long placeId;

    private String lang = "ar";

    @Column(nullable = false)
    private Instant createdAt;

    protected AppUser() {
    }

    public AppUser(String phone, String name, Role role, Long placeId, Instant createdAt) {
        this.phone = phone;
        this.name = name;
        this.role = role;
        this.placeId = placeId;
        this.createdAt = createdAt;
    }

    public void rename(String name) {
        this.name = name;
    }

    public void setLang(String lang) {
        this.lang = lang;
    }

    public Long getId() { return id; }
    public String getPhone() { return phone; }
    public String getName() { return name; }
    public Role getRole() { return role; }
    public Long getPlaceId() { return placeId; }
    public String getLang() { return lang; }
    public Instant getCreatedAt() { return createdAt; }
}
