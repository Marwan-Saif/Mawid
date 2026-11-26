package com.mawid.audit;

import com.mawid.audit.AuditService.AuditDto;
import com.mawid.auth.AuthUser;
import com.mawid.common.ApiException;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Front desk")
@RestController
@RequestMapping("/api/v1/desk/audit")
public class AuditController {

    private final AuditService audit;

    public AuditController(AuditService audit) {
        this.audit = audit;
    }

    @Operation(summary = "Who changed what, newest first; filter by entityType + entityId for one invoice or booking")
    @GetMapping
    public List<AuditDto> recent(@AuthenticationPrincipal AuthUser me,
                                 @RequestParam(required = false) String entityType,
                                 @RequestParam(required = false) Long entityId,
                                 @RequestParam(defaultValue = "100") int limit) {
        if (me.placeId() == null) {
            throw ApiException.forbidden("This account has no place yet");
        }
        return audit.recent(me.placeId(), entityType, entityId, limit);
    }
}
