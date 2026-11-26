package com.mawid.invoice;

public enum InvoiceStatus {
    /** Issued, not paid yet. */
    ISSUED,
    PAID,
    /** Cancelled with a reason. Kept, never deleted, so numbers have no gaps. */
    VOID
}
