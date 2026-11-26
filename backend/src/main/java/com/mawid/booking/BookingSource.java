package com.mawid.booking;

/**
 * Where the booking came from: the app, the public web link, typed in by the owner (phone call),
 * or a walk-in added at reception and queued straight away.
 */
public enum BookingSource {
    APP, WEB, MANUAL, WALK_IN
}
