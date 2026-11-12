package com.mawid.booking;

import java.util.EnumSet;
import java.util.Set;

public enum BookingStatus {
    PENDING, CONFIRMED, IN_PROGRESS, COMPLETED, CANCELLED, NO_SHOW;

    /** Statuses that hold the staff member's time. */
    public static final Set<BookingStatus> HOLDS_TIME = EnumSet.of(PENDING, CONFIRMED, IN_PROGRESS, COMPLETED);

    public boolean holdsTime() {
        return HOLDS_TIME.contains(this);
    }
}
