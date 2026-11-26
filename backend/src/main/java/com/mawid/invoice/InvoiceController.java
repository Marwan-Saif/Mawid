package com.mawid.invoice;

import com.mawid.auth.AuthUser;
import com.mawid.common.ApiException;
import com.mawid.invoice.InvoiceDtos.CreateInvoiceRequest;
import com.mawid.invoice.InvoiceDtos.InvoiceDto;
import com.mawid.invoice.InvoiceDtos.PayRequest;
import com.mawid.invoice.InvoiceDtos.UpdateInvoiceRequest;
import com.mawid.invoice.InvoiceDtos.VoidRequest;
import com.mawid.place.PlaceRepository;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

@Tag(name = "Invoices")
@RestController
@RequestMapping("/api/v1/desk/invoices")
public class InvoiceController {

    private final InvoiceService invoices;
    private final PlaceRepository places;
    private final Clock clock;

    public InvoiceController(InvoiceService invoices, PlaceRepository places, Clock clock) {
        this.invoices = invoices;
        this.places = places;
        this.clock = clock;
    }

    @Operation(summary = "The day's invoices at the place, newest number first (default: today)")
    @GetMapping
    public List<InvoiceDto> day(@AuthenticationPrincipal AuthUser me,
                                @RequestParam(required = false)
                                @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        Long placeId = placeOf(me);
        LocalDate day = date != null ? date
                : Instant.now(clock).atZone(places.findById(placeId)
                        .orElseThrow(() -> ApiException.notFound("Place")).zone()).toLocalDate();
        String base = baseUrl();
        return invoices.forDay(placeId, day).stream().map(i -> invoices.dto(i, base)).toList();
    }

    @GetMapping("/{id}")
    public InvoiceDto one(@AuthenticationPrincipal AuthUser me, @PathVariable Long id) {
        return invoices.dto(invoices.get(placeOf(me), id), baseUrl());
    }

    @Operation(summary = "Issue an invoice; send the same clientRef again and you get the same invoice back")
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public InvoiceDto create(@AuthenticationPrincipal AuthUser me, @Valid @RequestBody CreateInvoiceRequest body) {
        return invoices.dto(invoices.create(placeOf(me), body, me), baseUrl());
    }

    @Operation(summary = "Change lines or discount. 409 STALE_INVOICE if someone saved a newer version first")
    @PutMapping("/{id}")
    public InvoiceDto update(@AuthenticationPrincipal AuthUser me, @PathVariable Long id,
                             @Valid @RequestBody UpdateInvoiceRequest body) {
        return invoices.dto(invoices.update(placeOf(me), id, body, me), baseUrl());
    }

    @PostMapping("/{id}/pay")
    public InvoiceDto pay(@AuthenticationPrincipal AuthUser me, @PathVariable Long id,
                          @Valid @RequestBody PayRequest body) {
        return invoices.dto(invoices.pay(placeOf(me), id, body.method(), me), baseUrl());
    }

    @PostMapping("/{id}/void")
    public InvoiceDto voidIt(@AuthenticationPrincipal AuthUser me, @PathVariable Long id,
                             @Valid @RequestBody VoidRequest body) {
        return invoices.dto(invoices.voidIt(placeOf(me), id, body.reason(), me), baseUrl());
    }

    static String baseUrl() {
        return ServletUriComponentsBuilder.fromCurrentContextPath().build().toUriString();
    }

    private static Long placeOf(AuthUser me) {
        if (me.placeId() == null) {
            throw ApiException.forbidden("This account has no place yet");
        }
        return me.placeId();
    }
}
