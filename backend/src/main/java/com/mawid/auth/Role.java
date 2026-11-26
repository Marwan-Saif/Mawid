package com.mawid.auth;

public enum Role {
    CUSTOMER, OWNER,
    /** Front desk of a place: queue, check-in, invoices. No access to services or prices setup. */
    RECEPTION
}
