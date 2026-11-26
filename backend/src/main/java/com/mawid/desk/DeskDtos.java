package com.mawid.desk;

import com.mawid.booking.BookingDtos.BookingDto;
import com.mawid.booking.BookingStatus;
import com.mawid.place.Category;
import com.mawid.place.Place;
import com.mawid.place.PlaceDtos.ServiceDto;
import com.mawid.place.StaffPresence;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;

public final class DeskDtos {

    private DeskDtos() {
    }

    public record PlaceInfo(Long id, String slug, String nameAr, String nameEn, Category category, String timezone,
                            String currency) {
        static PlaceInfo of(Place p) {
            return new PlaceInfo(p.getId(), p.getSlug(), p.getNameAr(), p.getNameEn(), p.getCategory(),
                    p.getTimezone(), p.getCurrency());
        }
    }

    public record StaffBoard(Long id, String name, String titleAr, String titleEn, String room,
                             StaffPresence presence, Instant presenceSince, Long currentBookingId, int waiting) {
    }

    /** A booking plus where it stands in the queue right now. */
    public record QueueEntry(BookingDto booking, Instant expectedStartAt, int delayMin, int ahead, boolean late,
                             Long invoiceId, Long invoiceNumber, String invoiceStatus) {
    }

    public record Counts(int booked, int waiting, int inRoom, int done, int noShow) {
    }

    /** Everything the front desk screen shows, in one call. */
    public record Board(String date, PlaceInfo place, List<StaffBoard> staff, List<QueueEntry> queue,
                        List<ServiceDto> services, Counts counts, Instant serverTime) {
    }

    /** Scanned QR text: either the raw code or a link ending in /c/{code}. */
    public record CheckInRequest(@NotBlank @Size(max = 300) String code) {
    }

    public record WalkInRequest(@NotNull Long serviceId, Long staffId,
                                @NotBlank @Size(max = 80) String customerName,
                                @NotBlank String customerPhone,
                                @Size(max = 500) String note) {
    }

    public record PresenceUpdate(@NotNull StaffPresence presence) {
    }

    // ------------------------------------------------------------ waiting-room screen (public)

    public record DisplayStaff(Long id, String name, String titleAr, String titleEn, String room,
                               StaffPresence presence, Integer nowServingTicket, String nowServingName) {
    }

    public record DisplayEntry(int ticketNo, String name, Long staffId, String staffName, String room, int etaMin,
                               int delayMin) {
    }

    /** {@code seq} changes on every call (and every repeat), so the screen knows when to speak. */
    public record DisplayCall(String seq, Integer ticketNo, String name, String room, String staffName, Instant at) {
    }

    public record Display(PlaceInfo place, List<DisplayStaff> staff, List<DisplayEntry> waiting,
                          DisplayCall lastCall, int servedToday, Instant serverTime) {
    }

    // ------------------------------------------------------------ the customer's own check-in page (public)

    public record SelfCheckIn(String placeSlug, String placeNameAr, String placeNameEn, String timezone,
                              BookingStatus status, Instant startAt, String serviceNameAr, String serviceNameEn,
                              String staffName, Integer ticketNo, Integer ahead, Integer etaMin, String room,
                              boolean canCheckIn, Instant opensAt) {
    }
}
