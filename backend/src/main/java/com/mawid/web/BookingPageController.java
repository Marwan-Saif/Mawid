package com.mawid.web;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

/** Short, shareable link: https://your-domain/b/lamsa-salon serves the static booking page. */
@Controller
public class BookingPageController {

    @GetMapping({"/b/{slug}", "/b/{slug}/"})
    public String page(@PathVariable String slug) {
        return "forward:/book/index.html";
    }
}
