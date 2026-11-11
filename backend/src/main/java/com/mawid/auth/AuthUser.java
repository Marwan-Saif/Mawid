package com.mawid.auth;

/** The signed-in caller, put in the SecurityContext by {@link TokenAuthFilter}. */
public record AuthUser(Long id, Role role, Long placeId) {

    public boolean isOwnerOf(Long place) {
        return role == Role.OWNER && placeId != null && placeId.equals(place);
    }
}
