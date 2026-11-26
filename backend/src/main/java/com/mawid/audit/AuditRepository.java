package com.mawid.audit;

import java.util.List;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AuditRepository extends JpaRepository<AuditEntry, Long> {

    List<AuditEntry> findByPlaceIdOrderByAtDescIdDesc(Long placeId, Pageable page);

    List<AuditEntry> findByPlaceIdAndEntityTypeAndEntityIdOrderByAtDescIdDesc(Long placeId, String entityType,
                                                                             Long entityId, Pageable page);
}
