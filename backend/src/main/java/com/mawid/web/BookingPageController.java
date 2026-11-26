package com.mawid.web;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

/**
 * Short, shareable links served by static pages:
 * <ul>
 *   <li>/b/{slug} the booking page (Instagram bio, WhatsApp status)</li>
 *   <li>/w/{slug} the waiting-room screen for the TV in the clinic, with voice calls</li>
 *   <li>/c/{code} the customer's own check-in page (the QR on their booking)</li>
 * </ul>
 */
@Controller
public class BookingPageController {

    @GetMapping({"/b/{slug}", "/b/{slug}/"})
    public String page(@PathVariable String slug) {
        return "forward:/book/index.html";
    }

    @GetMapping({"/w/{slug}", "/w/{slug}/"})
    public String waitingRoom(@PathVariable String slug) {
        return "forward:/display/index.html";
    }

    @GetMapping({"/c/{code}", "/c/{code}/"})
    public String checkIn(@PathVariable String code) {
        return "forward:/checkin/index.html";
    }
}
