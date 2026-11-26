package com.mawid.desk;

import com.mawid.auth.AuthUser;
import com.mawid.booking.BookingDtos.BookingDto;
import com.mawid.common.ApiException;
import com.mawid.desk.DeskDtos.Board;
import com.mawid.desk.DeskDtos.CheckInRequest;
import com.mawid.desk.DeskDtos.PresenceUpdate;
import com.mawid.desk.DeskDtos.StaffBoard;
import com.mawid.desk.DeskDtos.WalkInRequest;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import java.time.LocalDate;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/** Front desk: owner or reception of the signed-in user's place. */
@Tag(name = "Front desk")
@RestController
@RequestMapping("/api/v1/desk")
public class DeskController {

    private final DeskService desk;

    public DeskController(DeskService desk) {
        this.desk = desk;
    }

    @Operation(summary = "Today's queue: every visit with its expected start and delay, each doctor's status, counts")
    @GetMapping("/board")
    public Board board(@AuthenticationPrincipal AuthUser me,
                       @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date) {
        return desk.board(placeOf(me), date);
    }

    @Operation(summary = "Check in from a scanned QR (the code or a /c/{code} link). Scanning twice is harmless.")
    @PostMapping("/check-in")
    public BookingDto checkInByCode(@AuthenticationPrincipal AuthUser me, @Valid @RequestBody CheckInRequest body) {
        return desk.checkInByCode(placeOf(me), body.code(), me);
    }

    @PostMapping("/bookings/{id}/check-in")
    public BookingDto checkIn(@AuthenticationPrincipal AuthUser me, @PathVariable Long id) {
        return desk.checkIn(placeOf(me), id, me);
    }

    @Operation(summary = "Walk-in: book the first free time today with whoever is free, and check them in")
    @PostMapping("/walk-ins")
    @ResponseStatus(HttpStatus.CREATED)
    public BookingDto walkIn(@AuthenticationPrincipal AuthUser me, @Valid @RequestBody WalkInRequest body) {
        return desk.walkIn(placeOf(me), body, me);
    }

    @Operation(summary = "Call to the room (the waiting screen announces it). Calling again repeats the announcement.")
    @PostMapping("/bookings/{id}/call")
    public BookingDto call(@AuthenticationPrincipal AuthUser me, @PathVariable Long id) {
        return desk.call(placeOf(me), id, me);
    }

    @PostMapping("/bookings/{id}/finish")
    public BookingDto finish(@AuthenticationPrincipal AuthUser me, @PathVariable Long id) {
        return desk.finish(placeOf(me), id, me);
    }

    @PostMapping("/bookings/{id}/no-show")
    public BookingDto noShow(@AuthenticationPrincipal AuthUser me, @PathVariable Long id) {
        return desk.noShow(placeOf(me), id, me);
    }

    @Operation(summary = "Available / busy / on a break / away, shown on the waiting screen")
    @PatchMapping("/staff/{id}/presence")
    public StaffBoard presence(@AuthenticationPrincipal AuthUser me, @PathVariable Long id,
                               @Valid @RequestBody PresenceUpdate body) {
        return desk.presence(placeOf(me), id, body.presence(), me);
    }

    private static Long placeOf(AuthUser me) {
        if (me.placeId() == null) {
            throw ApiException.forbidden("This account has no place yet");
        }
        return me.placeId();
    }
}
