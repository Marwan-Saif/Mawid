package com.mawid.audit;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import java.time.Instant;

/**
 * One line of "who changed what, when": "Sara (reception) edited invoice #1042 at 11:12: total 20 → 25".
 * Append-only: there is no update or delete endpoint for these rows.
 */
@Entity
@Table(name = "audit_log", indexes = {
        @Index(name = "ix_audit_place_at", columnList = "place_id,happened_at"),
        @Index(name = "ix_audit_entity", columnList = "entity_type,entity_id")
})
public class AuditEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "place_id", nullable = false)
    private Long placeId;

    @Column(name = "happened_at", nullable = false)
    private Instant at;

    /** Null when the customer acted without an account (self check-in) or the system did. */
    private Long actorId;

    @Column(nullable = false, length = 80)
    private String actorName;

    /** OWNER, RECEPTION, CUSTOMER, PATIENT (self check-in) or SYSTEM. */
    @Column(nullable = false, length = 16)
    private String actorRole;

    /** Stable code the apps translate, e.g. INVOICE_EDITED. */
    @Column(nullable = false, length = 32)
    private String action;

    @Column(name = "entity_type", nullable = false, length = 16)
    private String entityType;

    @Column(name = "entity_id")
    private Long entityId;

    /** What a person calls the thing: "#1042", "أبو سامي", "د. خالد". */
    @Column(length = 120)
    private String entityLabel;

    /** Small JSON object with the specifics (old and new values). */
    @Column(length = 4000)
    private String details;

    protected AuditEntry() {
    }

    public AuditEntry(Long placeId, Instant at, Long actorId, String actorName, String actorRole, String action,
                      String entityType, Long entityId, String entityLabel, String details) {
        this.placeId = placeId;
        this.at = at;
        this.actorId = actorId;
        this.actorName = actorName;
        this.actorRole = actorRole;
        this.action = action;
        this.entityType = entityType;
        this.entityId = entityId;
        this.entityLabel = entityLabel;
        this.details = details;
    }

    public Long getId() { return id; }
    public Long getPlaceId() { return placeId; }
    public Instant getAt() { return at; }
    public Long getActorId() { return actorId; }
    public String getActorName() { return actorName; }
    public String getActorRole() { return actorRole; }
    public String getAction() { return action; }
    public String getEntityType() { return entityType; }
    public Long getEntityId() { return entityId; }
    public String getEntityLabel() { return entityLabel; }
    public String getDetails() { return details; }
}
