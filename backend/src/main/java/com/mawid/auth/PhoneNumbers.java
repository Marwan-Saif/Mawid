package com.mawid.auth;

import com.mawid.common.ApiException;

public final class PhoneNumbers {

    private PhoneNumbers() {
    }

    /** Keeps digits and a leading +; rejects anything that is not a plausible international number. */
    public static String normalize(String raw) {
        if (raw == null) {
            throw ApiException.badRequest("INVALID_PHONE", "Phone is required");
        }
        String digits = raw.replaceAll("[^0-9+]", "");
        if (digits.startsWith("00")) {
            digits = "+" + digits.substring(2);
        }
        if (!digits.startsWith("+")) {
            digits = "+" + digits;
        }
        if (!digits.matches("\\+[1-9][0-9]{7,14}")) {
            throw ApiException.badRequest("INVALID_PHONE", "Phone must be in international format, e.g. +971501234567");
        }
        return digits;
    }
}
