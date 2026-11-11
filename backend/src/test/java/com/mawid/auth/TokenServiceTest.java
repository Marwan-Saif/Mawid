package com.mawid.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;

class TokenServiceTest {

    private static final String SECRET = "test-secret-that-is-long-enough-0123456789";
    private static final Instant NOW = Instant.parse("2026-11-01T10:00:00Z");

    private TokenService at(Instant when) {
        return new TokenService(SECRET, Duration.ofDays(1), Clock.fixed(when, ZoneOffset.UTC));
    }

    @Test
    void roundTrip() {
        String token = at(NOW).issue(42L);
        assertThat(at(NOW).verify(token)).contains(42L);
    }

    @Test
    void rejectsTamperedTokens() {
        String token = at(NOW).issue(42L);
        String forged = token.replaceFirst("^[^.]+", java.util.Base64.getUrlEncoder().withoutPadding()
                .encodeToString("1.9999999999".getBytes()));
        assertThat(at(NOW).verify(forged)).isEmpty();
        assertThat(at(NOW).verify("garbage")).isEmpty();
        assertThat(at(NOW).verify(null)).isEmpty();
    }

    @Test
    void rejectsExpiredTokens() {
        String token = at(NOW).issue(42L);
        assertThat(at(NOW.plus(Duration.ofDays(1)).plusSeconds(1)).verify(token)).isEmpty();
    }

    @Test
    void refusesShortSecrets() {
        assertThatThrownBy(() -> new TokenService("short", Duration.ofDays(1), Clock.systemUTC()))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void normalizesPhones() {
        assertThat(PhoneNumbers.normalize("00971 50 123 4567")).isEqualTo("+971501234567");
        assertThat(PhoneNumbers.normalize("+20 100 000 0002")).isEqualTo("+201000000002");
    }
}
