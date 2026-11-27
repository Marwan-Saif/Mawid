# Mawid · موعد

**Bilingual (Arabic RTL + English) booking and front-desk system for clinics and salons.**
From the booking to the invoice: QR check-in, a live waiting-room screen that calls people in out loud, each doctor's status, invoices printed on A4 or a receipt, a log of who changed what, and a desk that keeps working when the internet drops.
Flutter app with Clean Architecture and BLoC, a Spring Boot API that makes double booking impossible, and a no-install booking link for customers who live on WhatsApp and Instagram.

[![App](https://github.com/Marwan-Saif/Mawid/actions/workflows/app.yml/badge.svg)](https://github.com/Marwan-Saif/Mawid/actions/workflows/app.yml)
[![Backend](https://github.com/Marwan-Saif/Mawid/actions/workflows/backend.yml/badge.svg)](https://github.com/Marwan-Saif/Mawid/actions/workflows/backend.yml)

**Try it:** [web demo](https://marwan-saif.github.io/Mawid/) (tap *Try as customer*, *Try as owner* or *Try as clinic reception*, no sign-up) · demo APK from the latest [App workflow run](https://github.com/Marwan-Saif/Mawid/actions/workflows/app.yml)

---

## The problem

Clinics and salons in Egypt and the Gulf still book by phone and WhatsApp. Two receptionists give the same 5 pm slot to two people, nobody remembers to remind the customer, and the owner has no single view of the day.

## What Mawid does

| For customers | For the owner |
| --- | --- |
| Find a clinic or salon, see services with duration and price | Today's schedule at a glance, with counts |
| Pick a day, a free time and a person (or "anyone available") | Change status: started, done, no-show, cancelled |
| Confirmation, reminder an hour before | Add walk-in and phone bookings that use the same rules |
| Cancel or move up to 3 hours before | Add and edit services, hide them, change prices |
| Arabic (RTL) and English, switch any time | A booking link for the Instagram bio: customers book with name + phone, no app |
| A QR on every booking for check-in, and their place in the queue | The front desk: queue, waiting screen, invoices, audit log |

## The front desk: one visit, start to finish

Follow Abu Sami at Al Nakheel Clinic (the seeded demo, alive at whatever time you open it):

```
 booked ──► arrives ──────────► waits ─────────────► called in ──────► done ──────► invoice
            QR at reception     screen: "no. 4,       voice: "رقم ٤،     doctor      #1042: 20 + 5 = 25
            or "I'm here" link  ~10 min, 10 late"     أبو سامي، غرفة ١"   free again  A4 / receipt + QR
```

| Piece | How it works |
| --- | --- |
| **QR check-in** | Every booking has a 10-character code shown as a QR in the customer's app. Reception scans it (or types it); the customer can also open `/c/{code}` (in the reminder message) and tap *I'm here* from an hour before. Scanning twice is harmless. |
| **Waiting-room screen** | `/w/{slug}` on any TV browser (or the app's own screen on a tablet): who's being called, each doctor's status, the queue with expected wait and delay. Names are shortened for a public screen ("يوسف ن."). New calls flash and are spoken twice after a chime. |
| **Queue times** | `QueueEstimator` (same code in Java and Dart, same tests): whoever is in the room finishes at start + duration, people go in by booked time, never early; someone booked but 15+ minutes late doesn't hold up the people behind them. |
| **Doctor / stylist status** | Available, with a patient, on a break, away. Calling someone in makes the doctor busy; finishing frees them. A second call while busy is refused (`STAFF_BUSY`). |
| **Invoices** | Numbered per place with no gaps (row lock on the place), lines from the service list or free text, discount, cash/card/transfer, void with a reason. Prints as A4 or an 80 mm receipt from `/i/{token}`, with a QR back to the live invoice so a printout can be verified. |
| **Audit log** | Every desk change writes who/what/when in the same transaction: *"Sara (reception) edited invoice #1042 at 11:12: total 20 → 25, + blood pressure check"*. Edits use the invoice version, so two desks can't overwrite each other (`STALE_INVOICE`). |
| **Works offline** | The desk keeps the last board on the device. Check-in, call, finish, no-show, status changes, new invoices and payments go to an on-device outbox and show right away; they're sent in order when the network is back. Each is idempotent on the server (an invoice carries a `clientRef`), and anything the server refuses later is reported, not lost. The demo has a *Try offline* switch. |
| **Roles** | Owner (everything), reception (the desk only, no prices or services setup), customer. |

## The interesting part: no double booking, even under load

Every 15-minute unit of a staff member's time is a row in `slot_locks` with a **unique index on (staff_id, unit_start)**. A 45-minute haircut holds 3 units. Booking writes the booking and its units in one transaction:

```
customer A ─┐                       ┌─ INSERT (noura, 17:00) ✓
            ├─ same staff, 17:00 ──►│
customer B ─┘                       └─ INSERT (noura, 17:00) ✗ unique violation → 409 SLOT_TAKEN
```

- **"Anyone available"** tries each staff member who does the service and takes the first whose units are all free.
- **Cancelling** deletes the booking's units in the same transaction, so the time is free immediately.
- **Moving** a booking releases its own units first, so moving by 15 minutes onto itself works.
- The read check gives a clean answer in the normal case; the database index settles real races. It works the same on H2 and PostgreSQL, with no locking hints.

`BookingFlowIntegrationTest.onlyOneOfManySimultaneousRequestsWins` fires 8 requests for the same slot at the same moment and asserts exactly one wins.

## Architecture

```
app/  Flutter
  presentation  ── BLoC / Cubit, pages, widgets            (knows only domain + core)
  domain        ── entities, use cases, repository contracts, SlotCalculator (pure Dart)
  data          ── models (JSON ⇄ entity), data sources, repository implementations
                    ├─ ApiDataSource   → Spring Boot API
                    └─ FakeDataSource  → in-memory FakeBackend (same JSON, same rules)

backend/  Spring Boot 3 · Java 21
  scheduling    ── SlotCalculator (pure Java, same rules as the Dart one)
  booking       ── BookingService (rules + locks), controllers for customer, owner, public page
  auth          ── phone OTP, HMAC bearer tokens, Spring Security roles
  reminder      ── scheduled job one hour before, pluggable Notifier (log → WhatsApp/SMS)
```

Switching the app from the offline demo to the real API is one flag:

```bash
flutter run                                                        # offline demo
flutter run --dart-define=BACKEND=api --dart-define=API_URL=http://10.0.2.2:8080
```

Only `injection_container.dart` changes which data source is registered. Screens, BLoCs and use cases are identical. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the layers, patterns and decisions.

## Tech

**App:** Flutter, flutter_bloc, get_it, go_router, dartz (`Either<Failure, T>`), equatable, http, shared_preferences, intl + timezone, google_fonts, url_launcher. Tests: flutter_test, bloc_test, mocktail. No code generation step.

**API:** Spring Boot 3.5, Spring Web, Data JPA, Validation, Security, Actuator, springdoc-openapi (Swagger UI at `/docs`), H2 for dev, PostgreSQL via Docker Compose. Tests: JUnit 5, MockMvc, AssertJ.

## Run it

### App (no server needed)

```bash
cd app
flutter create . --org com.mawid --platforms=android,ios,web   # once, generates platform folders
flutter pub get
flutter run
```

Demo logins: **Try as customer** / **Try as owner**, or any phone number with code `123456`.

### API

```bash
cd backend
mvn spring-boot:run                 # H2 in memory, demo data seeded
# or
docker compose up --build           # with PostgreSQL
```

- Swagger UI: http://localhost:8080/docs
- Public booking page: http://localhost:8080/b/lamsa-salon
- Demo OTP: `123456`, demo accounts `+971500000001` (customer), `+971500000002` (owner)

### Tests

```bash
cd backend && mvn verify
cd app && flutter test && bash tool/check_layers.sh
```

## Selling it to a business (white-label)

Each client gets the same code with their own `Brand` (name, colors, WhatsApp) in `app/lib/config/brand.dart`, their services and staff in the API, and their booking link `/b/<their-slug>`. Production settings:

| Variable | Purpose |
| --- | --- |
| `MAWID_TOKEN_SECRET` | long random secret for login tokens |
| `MAWID_DEMO_CODE` | set to empty to turn off demo logins |
| `MAWID_SEED` | `false` to skip demo data |
| `DATABASE_URL`, `DATABASE_USER`, `DATABASE_PASSWORD` | PostgreSQL |

Replace `LoggingSmsSender` and `LoggingNotifier` with an SMS provider or the WhatsApp Business API to send real codes and reminders.

**Data:** Mawid stores a customer's name, phone and bookings only. It has no field for medical notes on purpose; clinics that need records should keep them in their own system.

## Roadmap

- WhatsApp Business API reminders and confirmations
- Deposits to cut no-shows
- Live updates over SSE/WebSocket instead of polling (the screen polls every 3 s, the desk every 10 s)
- Direct printing to thermal printers (ESC/POS) from the desk
- Push notifications (FCM) for new bookings on the API backend

---

Built by [Marwan Saif](https://www.linkedin.com/in/marwan-saif-361a17243) · Flutter & backend developer
