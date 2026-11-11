package com.mawid.auth;

import com.mawid.common.ApiException;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import java.time.Clock;
import java.time.Instant;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "Auth")
@RestController
@RequestMapping("/api/v1")
public class AuthController {

    /** Seeded demo accounts, see DemoDataSeeder. */
    public static final String DEMO_CUSTOMER_PHONE = "+971500000001";
    public static final String DEMO_OWNER_PHONE = "+971500000002";

    public record OtpRequest(@NotBlank String phone) {
    }

    public record OtpVerify(@NotBlank String phone, @NotBlank String code, String name) {
    }

    public record DemoLogin(@NotBlank @Pattern(regexp = "CUSTOMER|OWNER") String role) {
    }

    public record UserDto(Long id, String phone, String name, Role role, Long placeId, String lang) {
        static UserDto of(AppUser u) {
            return new UserDto(u.getId(), u.getPhone(), u.getName(), u.getRole(), u.getPlaceId(), u.getLang());
        }
    }

    public record Session(String token, UserDto user) {
    }

    public record ProfileUpdate(String name, @Pattern(regexp = "ar|en") String lang) {
    }

    private final OtpService otp;
    private final TokenService tokens;
    private final UserRepository users;
    private final AuthProperties props;
    private final Clock clock;

    public AuthController(OtpService otp, TokenService tokens, UserRepository users, AuthProperties props,
                          Clock clock) {
        this.otp = otp;
        this.tokens = tokens;
        this.users = users;
        this.props = props;
        this.clock = clock;
    }

    @Operation(summary = "Send a 6-digit code by SMS")
    @PostMapping("/auth/otp/request")
    public Map<String, Object> requestOtp(@Valid @RequestBody OtpRequest body) {
        otp.request(PhoneNumbers.normalize(body.phone()));
        return Map.of("sent", true, "demo", props.demoEnabled());
    }

    @Operation(summary = "Verify the code; creates the customer account on first login")
    @PostMapping("/auth/otp/verify")
    @Transactional
    public Session verify(@Valid @RequestBody OtpVerify body) {
        String phone = PhoneNumbers.normalize(body.phone());
        otp.verify(phone, body.code().trim());
        AppUser user = users.findByPhone(phone)
                .orElseGet(() -> users.save(new AppUser(phone, body.name(), Role.CUSTOMER, null, Instant.now(clock))));
        if (body.name() != null && !body.name().isBlank() && user.getName() == null) {
            user.rename(body.name().trim());
        }
        return new Session(tokens.issue(user.getId()), UserDto.of(user));
    }

    @Operation(summary = "Demo only: sign in as the seeded customer or owner without SMS")
    @PostMapping("/auth/demo")
    public Session demo(@Valid @RequestBody DemoLogin body) {
        if (!props.demoEnabled()) {
            throw ApiException.forbidden("Demo login is disabled");
        }
        String phone = "OWNER".equals(body.role()) ? DEMO_OWNER_PHONE : DEMO_CUSTOMER_PHONE;
        AppUser user = users.findByPhone(phone)
                .orElseThrow(() -> new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "NO_DEMO_DATA",
                        "Demo data not seeded"));
        return new Session(tokens.issue(user.getId()), UserDto.of(user));
    }

    @GetMapping("/me")
    public UserDto me(@AuthenticationPrincipal AuthUser auth) {
        return users.findById(auth.id()).map(UserDto::of).orElseThrow(() -> ApiException.notFound("User"));
    }

    @PatchMapping("/me")
    @Transactional
    public UserDto updateMe(@AuthenticationPrincipal AuthUser auth, @Valid @RequestBody ProfileUpdate body) {
        AppUser user = users.findById(auth.id()).orElseThrow(() -> ApiException.notFound("User"));
        if (body.name() != null && !body.name().isBlank()) {
            user.rename(body.name().trim());
        }
        if (body.lang() != null) {
            user.setLang(body.lang());
        }
        return UserDto.of(user);
    }
}
