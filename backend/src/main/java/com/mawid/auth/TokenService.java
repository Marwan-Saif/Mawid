package com.mawid.auth;

import java.nio.charset.StandardCharsets;
import java.security.InvalidKeyException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Optional;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

/**
 * Small stateless bearer token: {@code base64url(userId.expiryEpoch).base64url(hmacSha256)}.
 *
 * <p>Kept dependency-free on purpose: it is easy to read in an interview and easy to swap
 * for a JWT library later without touching controllers.
 */
public class TokenService {

    private static final String ALGORITHM = "HmacSHA256";
    private static final Base64.Encoder ENCODER = Base64.getUrlEncoder().withoutPadding();
    private static final Base64.Decoder DECODER = Base64.getUrlDecoder();

    private final byte[] secret;
    private final Duration ttl;
    private final Clock clock;

    public TokenService(String secret, Duration ttl, Clock clock) {
        if (secret == null || secret.length() < 32) {
            throw new IllegalArgumentException("mawid.auth.token-secret must be at least 32 characters");
        }
        this.secret = secret.getBytes(StandardCharsets.UTF_8);
        this.ttl = ttl;
        this.clock = clock;
    }

    public String issue(long userId) {
        long expiry = Instant.now(clock).plus(ttl).getEpochSecond();
        String payload = ENCODER.encodeToString((userId + "." + expiry).getBytes(StandardCharsets.UTF_8));
        return payload + "." + sign(payload);
    }

    /** The user id inside a valid, unexpired token. */
    public Optional<Long> verify(String token) {
        if (token == null) {
            return Optional.empty();
        }
        int dot = token.lastIndexOf('.');
        if (dot <= 0) {
            return Optional.empty();
        }
        String payload = token.substring(0, dot);
        String signature = token.substring(dot + 1);
        if (!MessageDigest.isEqual(sign(payload).getBytes(StandardCharsets.UTF_8),
                signature.getBytes(StandardCharsets.UTF_8))) {
            return Optional.empty();
        }
        try {
            String[] parts = new String(DECODER.decode(payload), StandardCharsets.UTF_8).split("\\.");
            if (parts.length != 2) {
                return Optional.empty();
            }
            long userId = Long.parseLong(parts[0]);
            long expiry = Long.parseLong(parts[1]);
            if (Instant.now(clock).getEpochSecond() >= expiry) {
                return Optional.empty();
            }
            return Optional.of(userId);
        } catch (IllegalArgumentException e) {
            return Optional.empty();
        }
    }

    private String sign(String payload) {
        try {
            Mac mac = Mac.getInstance(ALGORITHM);
            mac.init(new SecretKeySpec(secret, ALGORITHM));
            return ENCODER.encodeToString(mac.doFinal(payload.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException | InvalidKeyException e) {
            throw new IllegalStateException("HMAC not available", e);
        }
    }
}
