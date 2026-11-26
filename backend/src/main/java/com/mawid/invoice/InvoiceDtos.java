package com.mawid.invoice;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

public final class InvoiceDtos {

    private InvoiceDtos() {
    }

    public record LineDto(String description, int qty, BigDecimal unitPrice, BigDecimal amount, Long serviceId) {
        static LineDto of(InvoiceLine l) {
            return new LineDto(l.getDescription(), l.getQty(), l.getUnitPrice(), l.amount(), l.getServiceId());
        }
    }

    public record InvoiceDto(Long id, long number, Long placeId, Long bookingId, String customerName,
                             String customerPhone, String staffName, List<LineDto> lines, BigDecimal subtotal,
                             BigDecimal discount, BigDecimal total, String currency, InvoiceStatus status,
                             PaymentMethod paymentMethod, Instant createdAt, Instant updatedAt, Instant paidAt,
                             String createdByName, String voidReason, long version, String publicToken,
                             String clientRef, String printUrl) {
    }

    public record LineInput(@NotBlank @Size(max = 120) String description,
                            @NotNull @Min(1) @Max(99) Integer qty,
                            @NotNull BigDecimal unitPrice,
                            Long serviceId) {
    }

    /**
     * New invoice. With {@code bookingId} the customer and doctor come from the booking.
     * {@code clientRef} makes it safe to send twice (offline replay): the second call returns the first invoice.
     */
    public record CreateInvoiceRequest(Long bookingId,
                                       @Size(max = 80) String customerName,
                                       String customerPhone,
                                       @NotEmpty @Size(max = 30) List<@Valid LineInput> lines,
                                       BigDecimal discount,
                                       PaymentMethod paidWith,
                                       @Size(max = 64) String clientRef) {
    }

    /** {@code version} is the one the editor loaded; a newer one on the server means someone else saved first. */
    public record UpdateInvoiceRequest(@NotEmpty @Size(max = 30) List<@Valid LineInput> lines,
                                       BigDecimal discount,
                                       @NotNull Long version) {
    }

    public record PayRequest(@NotNull PaymentMethod method) {
    }

    public record VoidRequest(@NotBlank @Size(max = 200) String reason) {
    }
}
