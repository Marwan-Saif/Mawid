package com.mawid.audit;

/** The codes stored in audit_log.action and audit_log.entity_type. The apps translate them. */
public final class AuditActions {

    private AuditActions() {
    }

    // entity types
    public static final String BOOKING = "BOOKING";
    public static final String INVOICE = "INVOICE";
    public static final String STAFF = "STAFF";
    public static final String SERVICE = "SERVICE";

    // bookings and the visit
    public static final String BOOKING_CREATED = "BOOKING_CREATED";
    public static final String WALK_IN_ADDED = "WALK_IN_ADDED";
    public static final String BOOKING_STATUS = "BOOKING_STATUS";
    public static final String BOOKING_CANCELLED = "BOOKING_CANCELLED";
    public static final String BOOKING_MOVED = "BOOKING_MOVED";
    public static final String CHECKED_IN = "CHECKED_IN";
    public static final String CALLED = "CALLED";
    public static final String VISIT_FINISHED = "VISIT_FINISHED";
    public static final String NO_SHOW = "NO_SHOW";

    // people
    public static final String PRESENCE_CHANGED = "PRESENCE_CHANGED";

    // money
    public static final String INVOICE_CREATED = "INVOICE_CREATED";
    public static final String INVOICE_EDITED = "INVOICE_EDITED";
    public static final String INVOICE_PAID = "INVOICE_PAID";
    public static final String INVOICE_VOIDED = "INVOICE_VOIDED";

    // setup
    public static final String SERVICE_SAVED = "SERVICE_SAVED";
}
