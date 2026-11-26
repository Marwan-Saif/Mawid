package com.mawid.auth;

/** The signed-in caller, put in the SecurityContext by {@link TokenAuthFilter}. */
public record AuthUser(Long id, Role role, Long placeId) {

    public boolean isOwnerOf(Long place) {
        return role == Role.OWNER && placeId != null && placeId.equals(place);
    }

    /** Owner or front desk of this place. */
    public boolean worksAt(Long place) {
        return (role == Role.OWNER || role == Role.RECEPTION) && placeId != null && placeId.equals(place);
    }
}
