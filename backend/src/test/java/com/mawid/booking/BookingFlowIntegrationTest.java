package com.mawid.booking;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.mawid.booking.BookingService.Actor;
import com.mawid.booking.BookingService.NewBooking;
import com.mawid.place.OfferedService;
import com.mawid.place.OfferedServiceRepository;
import com.mawid.place.Place;
import com.mawid.place.PlaceRepository;
import com.mawid.place.Staff;
import com.mawid.place.StaffRepository;
import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

/** End to end through HTTP, against the seeded demo data and the in-memory database. */
@SpringBootTest(properties = {"mawid.seed.enabled=true", "mawid.reminders.enabled=false"})
@AutoConfigureMockMvc
class BookingFlowIntegrationTest {

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired PlaceRepository places;
    @Autowired OfferedServiceRepository services;
    @Autowired StaffRepository staff;
    @Autowired BookingService bookingService;
    @Autowired SlotLockRepository locks;

    Place lamsa;
    OfferedService haircut;
    Staff noura;
    Staff reem;
    LocalDate day;

    @BeforeEach
    void setUp() {
        lamsa = places.findBySlug("lamsa-salon").orElseThrow();
        haircut = services.findByPlaceIdOrderByIdAsc(lamsa.getId()).stream()
                .filter(s -> s.getNameEn().startsWith("Haircut")).findFirst().orElseThrow();
        List<Staff> team = staff.findByPlaceIdOrderByIdAsc(lamsa.getId());
        noura = team.stream().filter(s -> s.getName().equals("نورا")).findFirst().orElseThrow();
        reem = team.stream().filter(s -> s.getName().equals("ريم")).findFirst().orElseThrow();
        // A future weekday when both stylists work (Reem is off on Sundays).
        day = LocalDate.now(lamsa.zone()).plusDays(10);
        while (day.getDayOfWeek() == DayOfWeek.SUNDAY) {
            day = day.plusDays(1);
        }
    }

    private Instant at(int hour, int minute) {
        return day.atTime(hour, minute).atZone(lamsa.zone()).toInstant();
    }

    private String demoToken(String role) throws Exception {
        String body = mvc.perform(post("/api/v1/auth/demo").contentType(MediaType.APPLICATION_JSON)
                        .content("{\"role\":\"" + role + "\"}"))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(body).get("token").asText();
    }

    private String otpToken(String phone) throws Exception {
        mvc.perform(post("/api/v1/auth/otp/request").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(Map.of("phone", phone)))).andExpect(status().isOk());
        String body = mvc.perform(post("/api/v1/auth/otp/verify").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("phone", phone, "code", "123456", "name", "Test"))))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(body).get("token").asText();
    }

    private ResultActions book(String token, Long staffId, Instant start) throws Exception {
        Map<String, Object> body = new java.util.HashMap<>();
        body.put("placeId", lamsa.getId());
        body.put("serviceId", haircut.getId());
        body.put("staffId", staffId);
        body.put("startAt", start.toString());
        return mvc.perform(post("/api/v1/bookings").header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON).content(json.writeValueAsString(body)));
    }

    @Test
    void sameStaffSameTimeIsRejectedButAnyAvailablePicksSomeoneElse() throws Exception {
        String ahmed = demoToken("CUSTOMER");
        String other = otpToken("+971509990001");

        book(ahmed, noura.getId(), at(11, 0)).andExpect(status().isCreated())
                .andExpect(jsonPath("$.staffId").value(noura.getId()))
                .andExpect(jsonPath("$.status").value("CONFIRMED"));

        // 11:15 overlaps Noura's 11:00-11:45 haircut.
        book(other, noura.getId(), at(11, 15)).andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("SLOT_TAKEN"));

        // "Any available" at the same time goes to Reem.
        book(other, null, at(11, 15)).andExpect(status().isCreated())
                .andExpect(jsonPath("$.staffId").value(reem.getId()));
    }

    @Test
    void availabilityReflectsBookingsAndCancellingFreesTheTime() throws Exception {
        String ahmed = demoToken("CUSTOMER");
        String created = book(ahmed, noura.getId(), at(14, 0)).andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        long bookingId = json.readTree(created).get("id").asLong();
        assertThat(locks.countByBookingId(bookingId)).isEqualTo(3);

        assertThat(slotAvailable(noura.getId(), "14:00")).isFalse();

        mvc.perform(post("/api/v1/bookings/" + bookingId + "/cancel").header("Authorization", "Bearer " + ahmed))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELLED"));
        assertThat(locks.countByBookingId(bookingId)).isZero();
        assertThat(slotAvailable(noura.getId(), "14:00")).isTrue();
    }

    @Test
    void rescheduleMovesTheLocks() throws Exception {
        String ahmed = demoToken("CUSTOMER");
        String created = book(ahmed, noura.getId(), at(16, 0)).andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        long id = json.readTree(created).get("id").asLong();

        // Moving by 15 minutes overlaps its own old units; that must be allowed.
        mvc.perform(post("/api/v1/bookings/" + id + "/reschedule").header("Authorization", "Bearer " + ahmed)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"startAt\":\"" + at(16, 15) + "\",\"staffId\":" + noura.getId() + "}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.startAt").value(at(16, 15).toString()));
        assertThat(slotAvailable(noura.getId(), "16:00")).isFalse(); // 16:00-16:45 overlaps 16:15
        assertThat(slotAvailable(noura.getId(), "17:00")).isTrue();
    }

    @Test
    void onlyOneOfManySimultaneousRequestsWins() throws Exception {
        Instant start = at(19, 0);
        int threads = 8;
        ExecutorService pool = Executors.newFixedThreadPool(threads);
        CountDownLatch go = new CountDownLatch(1);
        List<Future<Boolean>> results = new ArrayList<>();
        for (int i = 0; i < threads; i++) {
            long customer = i + 1;
            Callable<Boolean> attempt = () -> {
                go.await();
                try {
                    bookingService.create(new NewBooking(lamsa.getId(), haircut.getId(), noura.getId(), customer,
                            start, null, BookingSource.APP, BookingStatus.CONFIRMED), Actor.CUSTOMER);
                    return true;
                } catch (RuntimeException e) {
                    return false;
                }
            };
            results.add(pool.submit(attempt));
        }
        go.countDown();
        int wins = 0;
        for (Future<Boolean> f : results) {
            if (f.get()) {
                wins++;
            }
        }
        pool.shutdown();
        assertThat(wins).isEqualTo(1);
    }

    @Test
    void ownerSeesTheDayAndCustomersCannotUseOwnerEndpoints() throws Exception {
        String ahmed = demoToken("CUSTOMER");
        String owner = demoToken("OWNER");
        book(ahmed, reem.getId(), at(12, 0)).andExpect(status().isCreated());

        String list = mvc.perform(get("/api/v1/owner/bookings").param("date", day.toString())
                        .header("Authorization", "Bearer " + owner))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        assertThat(json.readTree(list).findValuesAsText("startAt")).contains(at(12, 0).toString());

        mvc.perform(get("/api/v1/owner/bookings").header("Authorization", "Bearer " + ahmed))
                .andExpect(status().isForbidden());
        mvc.perform(post("/api/v1/bookings").contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void ownerCanAddAWalkInThatRespectsTheSameLocks() throws Exception {
        String owner = demoToken("OWNER");
        String walkIn = json.writeValueAsString(Map.of("serviceId", haircut.getId(), "staffId", noura.getId(),
                "startAt", at(20, 0).toString(), "customerName", "Walk-in", "customerPhone", "+971509990002"));
        mvc.perform(post("/api/v1/owner/bookings").header("Authorization", "Bearer " + owner)
                        .contentType(MediaType.APPLICATION_JSON).content(walkIn))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.source").value("MANUAL"));
        mvc.perform(post("/api/v1/owner/bookings").header("Authorization", "Bearer " + owner)
                        .contentType(MediaType.APPLICATION_JSON).content(walkIn))
                .andExpect(status().isConflict());
    }

    @Test
    void guestCanBookFromThePublicPageAndGetsAWhatsAppLink() throws Exception {
        String body = json.writeValueAsString(Map.of("serviceId", haircut.getId(), "startAt", at(21, 0).toString(),
                "name", "Guest", "phone", "+971 50 999 0003"));
        mvc.perform(post("/api/v1/public/places/lamsa-salon/bookings")
                        .contentType(MediaType.APPLICATION_JSON).content(body))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.booking.source").value("WEB"))
                .andExpect(jsonPath("$.whatsappLink").value(org.hamcrest.Matchers.startsWith("https://wa.me/971")));
    }

    @Test
    void rejectsTimesOutsideWorkingHoursAndUnalignedTimes() throws Exception {
        String ahmed = demoToken("CUSTOMER");
        book(ahmed, null, at(23, 0)).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("OUTSIDE_WORKING_HOURS"));
        book(ahmed, null, at(11, 10)).andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("SLOT_NOT_ALIGNED"));
    }

    private boolean slotAvailable(Long staffId, String localTime) throws Exception {
        String body = mvc.perform(get("/api/v1/places/" + lamsa.getId() + "/availability")
                        .param("serviceId", haircut.getId().toString())
                        .param("date", day.toString())
                        .param("staffId", staffId.toString()))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        for (JsonNode slot : json.readTree(body).get("slots")) {
            if (slot.get("localTime").asText().equals(localTime)) {
                return slot.get("available").asBoolean();
            }
        }
        throw new AssertionError("No slot " + localTime);
    }
}
