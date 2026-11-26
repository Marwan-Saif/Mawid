package com.mawid.place;

/** What the waiting room and the front desk see next to each doctor or stylist. */
public enum StaffPresence {
    /** Free: the next patient can be called in. */
    AVAILABLE,
    /** With a patient. Set when reception calls someone in, cleared when the visit is finished. */
    BUSY,
    BREAK,
    /** Not in today or stepped out. */
    AWAY
}
