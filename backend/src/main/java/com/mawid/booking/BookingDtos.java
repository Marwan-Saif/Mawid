package com.mawid.booking;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;

public final class BookingDtos {

    private BookingDtos() {
    }

    public record BookingDto(Long id, Long placeId, String placeSlug, String placeNameAr, String placeNameEn,
                             String placeTimezone, Long serviceId, String serviceNameAr, String serviceNameEn,
                             Long staffId, String staffName, Long customerId, String customerName,
                             String customerPhone, Instant startAt, Instant endAt, int durationMin,
                             BigDecimal price, String currency, BookingStatus status, BookingSource source,
                             String note, Instant createdAt, boolean canChange) {
    }

    /** staffId null means "any available". */
    public record CreateBookingRequest(@NotNull Long placeId, @NotNull Long serviceId, Long staffId,
                                       @NotNull Instant startAt, @Size(max = 500) String note) {
    }

    public record RescheduleRequest(@NotNull Instant startAt, Long staffId) {
    }

    public record StatusUpdate(@NotNull BookingStatus status) {
    }

    /** Walk-in or phone booking typed by the owner. */
    public record ManualBookingRequest(@NotNull Long serviceId, Long staffId, @NotNull Instant startAt,
                                       @NotBlank String customerName, @NotBlank String customerPhone,
                                       @Size(max = 500) String note) {
    }

    /** Booking from the public web page: no account, just name and phone. */
    public record GuestBookingRequest(@NotNull Long serviceId, Long staffId, @NotNull Instant startAt,
                                      @NotBlank @Size(max = 80) String name, @NotBlank String phone) {
    }

    public record GuestBookingResponse(BookingDto booking, String whatsappLink) {
    }

    public record ServiceUpsert(@NotBlank String nameAr, @NotBlank String nameEn,
                                @NotNull Integer durationMin, @NotNull BigDecimal price, Boolean active) {
    }
}
