package com.mawid.desk;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.mawid.auth.AppUser;
import com.mawid.auth.Role;
import com.mawid.auth.UserRepository;
import com.mawid.booking.Booking;
import com.mawid.booking.BookingService;
import com.mawid.booking.BookingService.Actor;
import com.mawid.booking.BookingService.NewBooking;
import com.mawid.booking.BookingSource;
import com.mawid.booking.BookingStatus;
import com.mawid.place.OfferedService;
import com.mawid.place.OfferedServiceRepository;
import com.mawid.place.Place;
import com.mawid.place.PlaceRepository;
import com.mawid.place.Staff;
import com.mawid.place.StaffRepository;
import com.mawid.scheduling.SlotCalculator;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

/**
 * The visit end to end at Al Nakheel Clinic: QR check-in → call → finish → invoice → edit → audit,
 * plus the public waiting screen and the customer's own check-in page.
 *
 * <p>The whole context runs on a fixed clock (11:07 in Amman), so the "today" these tests need
 * exists whatever time the build runs, even close to midnight.
 */
// Own in-memory database: the other integration test's context seeds the shared one on the real
// clock, and this class needs its demo day seeded on the fixed clock below.
@SpringBootTest(properties = {"mawid.seed.enabled=true", "mawid.reminders.enabled=false",
        "spring.datasource.url=jdbc:h2:mem:desk;MODE=PostgreSQL;DB_CLOSE_DELAY=-1;DATABASE_TO_LOWER=TRUE"})
@AutoConfigureMockMvc
class DeskFlowIntegrationTest {

    @TestConfiguration
    static class FixedClock {
        @Bean
        @Primary
        Clock fixedClock() {
            Instant at = LocalDateTime.of(2026, 11, 26, 11, 7).atZone(ZoneId.of("Asia/Amman")).toInstant();
            return Clock.fixed(at, ZoneOffset.UTC);
        }
    }

    @Autowired Clock clock;

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired PlaceRepository places;
    @Autowired OfferedServiceRepository services;
    @Autowired StaffRepository staff;
    @Autowired UserRepository users;
    @Autowired BookingService bookings;

    Place nakheel;
    OfferedService consult;
    OfferedService followUp;
    OfferedService pressure;
    Staff lina;
    Instant t0;

    @BeforeEach
    void setUp() {
        nakheel = places.findBySlug("nakheel-clinic").orElseThrow();
        List<OfferedService> list = services.findByPlaceIdOrderByIdAsc(nakheel.getId());
        consult = list.stream().filter(s -> s.getNameEn().equals("Consultation")).findFirst().orElseThrow();
        followUp = list.stream().filter(s -> s.getNameEn().equals("Follow-up")).findFirst().orElseThrow();
        pressure = list.stream().filter(s -> s.getNameEn().startsWith("Blood pressure")).findFirst().orElseThrow();
        lina = staff.findByPlaceIdOrderByIdAsc(nakheel.getId()).stream()
                .filter(s -> s.getName().contains("لينا")).findFirst().orElseThrow();
        t0 = SlotCalculator.alignDown(clock.instant());
    }

    private String token(String role) throws Exception {
        String body = mvc.perform(post("/api/v1/auth/demo").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"role\":\"" + role + "\"}"))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString();
        return json.readTree(body).get("token").asText();
    }

    private void assumeToday(Instant start) {
        Assumptions.assumeTrue(start.atZone(nakheel.zone()).toLocalDate()
                        .equals(clock.instant().atZone(nakheel.zone()).toLocalDate()),
                "too close to midnight in Amman for a same-day visit");
    }

    private Booking visit(OfferedService s, Instant start, String phone) {
        assumeToday(start);
        AppUser c = users.findByPhone(phone).orElseGet(() -> users.save(
                new AppUser(phone, "مريض تجربة", Role.CUSTOMER, null, clock.instant())));
        return bookings.create(new NewBooking(nakheel.getId(), s.getId(), lina.getId(), c.getId(), start, null,
                BookingSource.APP, BookingStatus.CONFIRMED), Actor.SYSTEM);
    }

    private JsonNode body(org.springframework.test.web.servlet.ResultActions r) throws Exception {
        return json.readTree(r.andReturn().getResponse().getContentAsString());
    }

    @Test
    void receptionSeesTheLiveBoardButNotTheOwnerSetup() throws Exception {
        String desk = token("RECEPTION");
        JsonNode board = body(mvc.perform(get("/api/v1/desk/board").header("Authorization", "Bearer " + desk))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.place.slug").value("nakheel-clinic"))
                .andExpect(jsonPath("$.staff.length()").value(2)));
        assertThat(board.get("counts").get("inRoom").asInt()).isGreaterThanOrEqualTo(1);
        assertThat(board.get("counts").get("waiting").asInt()).isGreaterThanOrEqualTo(2);

        mvc.perform(get("/api/v1/owner/services").header("Authorization", "Bearer " + desk))
                .andExpect(status().isForbidden());
        mvc.perform(get("/api/v1/desk/board"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void qrCheckInCallFinishInvoiceEditAndAudit() throws Exception {
        String desk = token("RECEPTION");
        Booking b = visit(consult, t0.plus(Duration.ofMinutes(90)), "+962791110001");

        // Scan the QR (a link) → arrived with a ticket. Scanning again changes nothing.
        JsonNode in = body(mvc.perform(post("/api/v1/desk/check-in").header("Authorization", "Bearer " + desk)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("code", "https://clinic.example/c/" + b.getCheckInCode()))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ARRIVED")));
        int ticket = in.get("ticketNo").asInt();
        assertThat(ticket).isGreaterThan(0);
        mvc.perform(post("/api/v1/desk/check-in").header("Authorization", "Bearer " + desk)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("code", b.getCheckInCode()))))
                .andExpect(jsonPath("$.ticketNo").value(ticket));

        // Call → in the room; Dr Lina is now busy so the next one has to wait.
        mvc.perform(post("/api/v1/desk/bookings/" + b.getId() + "/call").header("Authorization", "Bearer " + desk))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("IN_PROGRESS"))
                .andExpect(jsonPath("$.room").value("غرفة ٢"));
        JsonNode display = body(mvc.perform(get("/api/v1/public/places/nakheel-clinic/display"))
                .andExpect(status().isOk()));
        assertThat(display.get("lastCall").get("ticketNo").asInt()).isEqualTo(ticket);
        JsonNode linaOnScreen = null;
        for (JsonNode s : display.get("staff")) {
            if (s.get("id").asLong() == lina.getId()) {
                linaOnScreen = s;
            }
        }
        assertThat(linaOnScreen).isNotNull();
        assertThat(linaOnScreen.get("presence").asText()).isEqualTo("BUSY");

        Booking next = visit(followUp, t0.plus(Duration.ofMinutes(135)), "+962791110002");
        mvc.perform(post("/api/v1/desk/bookings/" + next.getId() + "/check-in").header("Authorization", "Bearer " + desk))
                .andExpect(status().isOk());
        mvc.perform(post("/api/v1/desk/bookings/" + next.getId() + "/call").header("Authorization", "Bearer " + desk))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("STAFF_BUSY"));

        mvc.perform(post("/api/v1/desk/bookings/" + b.getId() + "/finish").header("Authorization", "Bearer " + desk))
                .andExpect(jsonPath("$.status").value("COMPLETED"));

        // Invoice: 20 consultation + 5 blood pressure = 25. Same clientRef twice = one invoice.
        Map<String, Object> create = Map.of("bookingId", b.getId(), "clientRef", "test-" + b.getId(), "lines", List.of(
                Map.of("description", "كشفية", "qty", 1, "unitPrice", 20, "serviceId", consult.getId()),
                Map.of("description", "قياس ضغط", "qty", 1, "unitPrice", 5, "serviceId", pressure.getId())));
        JsonNode inv = body(mvc.perform(post("/api/v1/desk/invoices").header("Authorization", "Bearer " + desk)
                        .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(create)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.total").value(25.0))
                .andExpect(jsonPath("$.status").value("ISSUED")));
        long invoiceId = inv.get("id").asLong();
        assertThat(inv.get("number").asLong()).isGreaterThan(1042);
        mvc.perform(post("/api/v1/desk/invoices").header("Authorization", "Bearer " + desk)
                        .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(create)))
                .andExpect(jsonPath("$.id").value(invoiceId));

        // A second invoice for the same visit (different clientRef) is refused.
        Map<String, Object> again = new java.util.HashMap<>(create);
        again.put("clientRef", "other-" + b.getId());
        mvc.perform(post("/api/v1/desk/invoices").header("Authorization", "Bearer " + desk)
                        .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(again)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("ALREADY_INVOICED"));

        // Edit with the version we loaded; then the same old version again is stale.
        long version = inv.get("version").asLong();
        Map<String, Object> edit = Map.of("version", version, "discount", 2, "lines", List.of(
                Map.of("description", "كشفية", "qty", 1, "unitPrice", 20),
                Map.of("description", "قياس ضغط", "qty", 1, "unitPrice", 5),
                Map.of("description", "فحص سكر", "qty", 1, "unitPrice", 7)));
        mvc.perform(put("/api/v1/desk/invoices/" + invoiceId).header("Authorization", "Bearer " + desk)
                        .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(edit)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.subtotal").value(32.0))
                .andExpect(jsonPath("$.total").value(30.0));
        mvc.perform(put("/api/v1/desk/invoices/" + invoiceId).header("Authorization", "Bearer " + desk)
                        .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(edit)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("STALE_INVOICE"));

        mvc.perform(post("/api/v1/desk/invoices/" + invoiceId + "/pay").header("Authorization", "Bearer " + desk)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"method\":\"CASH\"}"))
                .andExpect(jsonPath("$.status").value("PAID"));

        // Who did what: Sara at reception, newest first.
        JsonNode log = body(mvc.perform(get("/api/v1/desk/audit")
                        .param("entityType", "INVOICE").param("entityId", String.valueOf(invoiceId))
                        .header("Authorization", "Bearer " + desk))
                .andExpect(status().isOk()));
        assertThat(log.get(0).get("action").asText()).isEqualTo("INVOICE_PAID");
        assertThat(log.get(1).get("action").asText()).isEqualTo("INVOICE_EDITED");
        assertThat(log.get(1).get("actorName").asText()).isEqualTo("سارة");
        assertThat(log.get(1).get("actorRole").asText()).isEqualTo("RECEPTION");
        assertThat(log.get(1).get("details").get("totalTo").decimalValue()).isEqualByComparingTo("30");
        assertThat(log.get(1).get("details").get("added").get(0).asText()).startsWith("فحص سكر");

        // The printable page: public by its token, with a QR.
        String page = mvc.perform(get("/i/" + inv.get("publicToken").asText()).param("size", "receipt"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.TEXT_HTML))
                .andReturn().getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        assertThat(page).contains("#" + inv.get("number").asLong()).contains("<svg").contains("30.00");
    }

    @Test
    void waitingScreenIsPublicAndShortensNames() throws Exception {
        String screen = mvc.perform(get("/api/v1/public/places/nakheel-clinic/display"))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        assertThat(screen).doesNotContain("النجار").doesNotContain("الرواشدة").doesNotContain("+9627");
        assertThat(screen).contains("أبو سامي");
    }

    @Test
    void customerChecksInFromTheirPhoneOnlyAroundTheirTime() throws Exception {
        Booking soon = visit(followUp, t0.plus(Duration.ofMinutes(30)), "+962791110003");
        Booking later = visit(consult, t0.plus(Duration.ofMinutes(180)), "+962791110004");

        mvc.perform(get("/api/v1/public/check-in/" + later.getCheckInCode()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.canCheckIn").value(false));
        mvc.perform(post("/api/v1/public/check-in/" + later.getCheckInCode()))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("CHECKIN_WINDOW"));

        mvc.perform(post("/api/v1/public/check-in/" + soon.getCheckInCode()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("ARRIVED"))
                .andExpect(jsonPath("$.ticketNo").isNumber());
        mvc.perform(get("/api/v1/public/check-in/NOPE"))
                .andExpect(status().isNotFound());
    }

    @Test
    void walkInIsBookedIntoTheNextFreeTimeAndQueued() throws Exception {
        String desk = token("RECEPTION");
        Assumptions.assumeTrue(t0.plus(Duration.ofHours(6)).atZone(nakheel.zone()).toLocalDate()
                .equals(clock.instant().atZone(nakheel.zone()).toLocalDate()), "late in the day in Amman");
        mvc.perform(post("/api/v1/desk/walk-ins").header("Authorization", "Bearer " + desk)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("serviceId", pressure.getId(),
                                "customerName", "زائر بدون موعد", "customerPhone", "+962791110009"))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.status").value("ARRIVED"))
                .andExpect(jsonPath("$.source").value("WALK_IN"))
                .andExpect(jsonPath("$.ticketNo").isNumber());
    }

    @Test
    void staffPresenceIsAudited() throws Exception {
        String desk = token("RECEPTION");
        Staff khaled = staff.findByPlaceIdOrderByIdAsc(nakheel.getId()).stream()
                .filter(s -> s.getName().contains("خالد")).findFirst().orElseThrow();
        mvc.perform(patch("/api/v1/desk/staff/" + khaled.getId() + "/presence").header("Authorization", "Bearer " + desk)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"presence\":\"BREAK\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.presence").value("BREAK"));
        JsonNode log = body(mvc.perform(get("/api/v1/desk/audit").header("Authorization", "Bearer " + desk)));
        assertThat(log.get(0).get("action").asText()).isEqualTo("PRESENCE_CHANGED");
        mvc.perform(patch("/api/v1/desk/staff/" + khaled.getId() + "/presence").header("Authorization", "Bearer " + desk)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"presence\":\"BUSY\"}"))
                .andExpect(status().isOk());
    }
}
