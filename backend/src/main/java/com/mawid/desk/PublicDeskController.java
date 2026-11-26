package com.mawid.desk;

import com.mawid.desk.DeskDtos.Display;
import com.mawid.desk.DeskDtos.SelfCheckIn;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RestController;

/** No sign-in: the waiting-room TV and the customer's own phone. Names are shortened ("مريم ع."). */
@Tag(name = "Waiting room")
@RestController
public class PublicDeskController {

    private final DeskService desk;

    public PublicDeskController(DeskService desk) {
        this.desk = desk;
    }

    @Operation(summary = "What the waiting-room screen shows; poll every few seconds")
    @GetMapping("/api/v1/public/places/{slug}/display")
    public Display display(@PathVariable String slug) {
        return desk.display(slug);
    }

    @Operation(summary = "The customer's check-in page: status, ticket and wait")
    @GetMapping("/api/v1/public/check-in/{code}")
    public SelfCheckIn status(@PathVariable String code) {
        return desk.selfStatus(code);
    }

    @Operation(summary = "\"I'm here\": self check-in from an hour before the booking to 30 minutes after")
    @PostMapping("/api/v1/public/check-in/{code}")
    public SelfCheckIn checkIn(@PathVariable String code) {
        return desk.selfCheckIn(code);
    }
}
