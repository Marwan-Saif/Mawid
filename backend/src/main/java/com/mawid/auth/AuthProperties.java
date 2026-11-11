package com.mawid.auth;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * @param tokenSecret HMAC secret, at least 32 chars. Set MAWID_TOKEN_SECRET in production.
 * @param tokenTtl    how long a login lasts
 * @param demoCode    when set, this OTP always works and the demo login endpoint is open
 */
@ConfigurationProperties(prefix = "mawid.auth")
public record AuthProperties(String tokenSecret, Duration tokenTtl, String demoCode) {

    public AuthProperties {
        if (tokenTtl == null) {
            tokenTtl = Duration.ofDays(30);
        }
    }

    public boolean demoEnabled() {
        return demoCode != null && !demoCode.isBlank();
    }
}
