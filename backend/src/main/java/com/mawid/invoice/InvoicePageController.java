package com.mawid.invoice;

import com.mawid.common.ApiException;
import com.mawid.place.Place;
import com.mawid.place.PlaceRepository;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

/**
 * /i/{token}: the printable invoice. Public on purpose (the token is 24 random characters, like an
 * unlisted link) so it opens from the QR on paper, from WhatsApp, or from the desk's print button.
 */
@Controller
public class InvoicePageController {

    private final InvoiceRepository invoices;
    private final PlaceRepository places;

    public InvoicePageController(InvoiceRepository invoices, PlaceRepository places) {
        this.invoices = invoices;
        this.places = places;
    }

    @GetMapping({"/i/{token}", "/i/{token}/"})
    public ResponseEntity<String> page(@PathVariable String token,
                                       @RequestParam(defaultValue = "a4") String size,
                                       @RequestParam(defaultValue = "ar") String lang,
                                       @RequestParam(defaultValue = "0") String print) {
        Invoice inv = invoices.findByPublicToken(token).orElseThrow(() -> ApiException.notFound("Invoice"));
        Place place = places.findById(inv.getPlaceId()).orElseThrow(() -> ApiException.notFound("Place"));
        String url = ServletUriComponentsBuilder.fromCurrentContextPath().path("/i/" + token).build().toUriString();
        String html = InvoiceHtml.render(inv, place, !"en".equalsIgnoreCase(lang),
                "receipt".equalsIgnoreCase(size) ? InvoiceHtml.Size.RECEIPT : InvoiceHtml.Size.A4,
                "1".equals(print), url);
        return ResponseEntity.ok()
                .contentType(new MediaType("text", "html", java.nio.charset.StandardCharsets.UTF_8))
                .cacheControl(CacheControl.noStore())
                .header("Referrer-Policy", "no-referrer")
                .body(html);
    }
}
