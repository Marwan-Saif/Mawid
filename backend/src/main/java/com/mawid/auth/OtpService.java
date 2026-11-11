package com.mawid.auth;

import com.mawid.common.ApiException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/**
 * Phone OTP: 6 digits, valid 5 minutes, 5 attempts. Kept in memory; a single-instance
 * deployment is enough for one business. Move to Redis when running several instances.
 */
@Service
public class OtpService {

    private static final Duration VALIDITY = Duration.ofMinutes(5);
    private static final int MAX_ATTEMPTS = 5;

    private record Pending(String code, Instant expiresAt, int attempts) {
    }

    private final Map<String, Pending> pending = new ConcurrentHashMap<>();
    private final SecureRandom random = new SecureRandom();
    private final SmsSender sms;
    private final AuthProperties props;
    private final Clock clock;

    public OtpService(SmsSender sms, AuthProperties props, Clock clock) {
        this.sms = sms;
        this.props = props;
        this.clock = clock;
    }

    public void request(String phone) {
        String code = String.format("%06d", random.nextInt(1_000_000));
        pending.put(phone, new Pending(code, Instant.now(clock).plus(VALIDITY), 0));
        sms.send(phone, "Mawid code: " + code + " | كود موعد: " + code);
    }

    public void verify(String phone, String code) {
        if (props.demoEnabled() && props.demoCode().equals(code)) {
            pending.remove(phone);
            return;
        }
        Pending p = pending.get(phone);
        if (p == null || Instant.now(clock).isAfter(p.expiresAt())) {
            pending.remove(phone);
            throw new ApiException(HttpStatus.UNAUTHORIZED, "OTP_EXPIRED", "Code expired, request a new one");
        }
        if (p.attempts() >= MAX_ATTEMPTS) {
            pending.remove(phone);
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "OTP_LOCKED", "Too many attempts");
        }
        if (!p.code().equals(code)) {
            pending.put(phone, new Pending(p.code(), p.expiresAt(), p.attempts() + 1));
            throw new ApiException(HttpStatus.UNAUTHORIZED, "OTP_INVALID", "Wrong code");
        }
        pending.remove(phone);
    }
}
