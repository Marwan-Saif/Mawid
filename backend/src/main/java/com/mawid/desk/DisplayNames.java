package com.mawid.desk;

import java.util.Set;

/**
 * What a public screen may show and say: "مريم ع." instead of "مريم عبد الله", "يوسف ن." for
 * "يوسف النجار", but kunyas stay
 * whole ("أبو سامي") because that is how people are called in the room anyway.
 */
public final class DisplayNames {

    private static final Set<String> KUNYA = Set.of("أبو", "ابو", "أم", "ام", "abu", "umm", "um");

    private DisplayNames() {
    }

    public static String forScreen(String fullName) {
        if (fullName == null || fullName.isBlank()) {
            return null;
        }
        String[] parts = fullName.trim().split("\\s+");
        if (parts.length == 1) {
            return parts[0];
        }
        if (KUNYA.contains(parts[0].toLowerCase()) && parts.length >= 2) {
            return parts[0] + " " + parts[1];
        }
        String second = parts[1];
        if (second.endsWith(".")) {
            return parts[0] + " " + second;
        }
        if (second.startsWith("ال") && second.length() > 2) {
            second = second.substring(2); // "النجار" → "ن." like people would write it
        }
        return parts[0] + " " + second.codePoints().limit(1)
                .collect(StringBuilder::new, StringBuilder::appendCodePoint, StringBuilder::append) + ".";
    }
}
