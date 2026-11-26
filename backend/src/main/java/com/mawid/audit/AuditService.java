package com.mawid.audit;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.mawid.auth.AppUser;
import com.mawid.auth.AuthUser;
import com.mawid.auth.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Writes the audit log. Joins the caller's transaction on purpose: if the change rolls back,
 * its log line goes with it, so the log never claims something that didn't happen.
 */
@Service
public class AuditService {

    public static final String PATIENT = "PATIENT";
    public static final String SYSTEM = "SYSTEM";

    public record AuditDto(Long id, Instant at, Long actorId, String actorName, String actorRole, String action,
                           String entityType, Long entityId, String entityLabel, JsonNode details) {
    }

    private final AuditRepository repository;
    private final UserRepository users;
    private final ObjectMapper json;
    private final Clock clock;

    public AuditService(AuditRepository repository, UserRepository users, ObjectMapper json, Clock clock) {
        this.repository = repository;
        this.users = users;
        this.json = json;
        this.clock = clock;
    }

    /** {@code actor} null means the customer themself (self check-in) when there is no account. */
    @Transactional(propagation = Propagation.REQUIRED)
    public void record(Long placeId, AuthUser actor, String action, String entityType, Long entityId,
                       String entityLabel, Map<String, ?> details) {
        Long actorId = actor == null ? null : actor.id();
        String role = actor == null ? PATIENT : actor.role().name();
        String name = actor == null ? null
                : users.findById(actor.id()).map(AppUser::getName).orElse(null);
        if (name == null || name.isBlank()) {
            name = role;
        }
        repository.save(new AuditEntry(placeId, Instant.now(clock), actorId, name, role, action, entityType,
                entityId, entityLabel, write(details)));
    }

    @Transactional(readOnly = true)
    public List<AuditDto> recent(Long placeId, String entityType, Long entityId, int limit) {
        PageRequest page = PageRequest.of(0, Math.max(1, Math.min(limit, 500)));
        List<AuditEntry> rows = entityType != null && entityId != null
                ? repository.findByPlaceIdAndEntityTypeAndEntityIdOrderByAtDescIdDesc(placeId, entityType, entityId, page)
                : repository.findByPlaceIdOrderByAtDescIdDesc(placeId, page);
        return rows.stream().map(this::dto).toList();
    }

    private AuditDto dto(AuditEntry e) {
        return new AuditDto(e.getId(), e.getAt(), e.getActorId(), e.getActorName(), e.getActorRole(), e.getAction(),
                e.getEntityType(), e.getEntityId(), e.getEntityLabel(), read(e.getDetails()));
    }

    private String write(Map<String, ?> details) {
        if (details == null || details.isEmpty()) {
            return null;
        }
        try {
            return json.writeValueAsString(details);
        } catch (JsonProcessingException e) {
            return null;
        }
    }

    private JsonNode read(String text) {
        if (text == null) {
            return json.createObjectNode();
        }
        try {
            return json.readTree(text);
        } catch (JsonProcessingException e) {
            return json.createObjectNode();
        }
    }
}
