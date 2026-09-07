# KnightMarket

A mobile marketplace built for UCF students to buy and sell with each other near campus —
textbooks, dorm gear, electronics, tickets, and more. Verified with a `.edu` email, arranged
over real-time chat, and completed in person at a public meetup spot the two sides agree on
together.

Black-and-gold visual identity throughout, matching the Knights.

---

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Database Design](#database-design)
- [Real-Time Messaging](#real-time-messaging)
- [Security](#security)
- [API Overview](#api-overview)
- [How It Was Built](#how-it-was-built)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Next Steps to Complete](#next-steps-to-complete)
- [Roadmap](#roadmap)

---

## Features

- **Student-verified accounts** — registering with a `.edu` email automatically grants a
  "Verified Student" badge; every account still requires email confirmation before first login.
- **Listings** — title, description, price, category, condition, and up to 3 photos per item,
  hosted and auto-optimized via Cloudinary.
- **Browse & filter** — search by keyword, filter by category/condition/price range, newest-first
  feed with paid boosts able to float a listing to the top for a set window of time.
- **Map-based meetup arranging** — instead of listing a home address, sellers give a general
  public area (e.g. "Near the Student Union"). The exact meetup spot and time get proposed,
  confirmed, and tracked per-conversation directly on an interactive map inside the chat thread.
- **Real-time chat** — Socket.IO-backed messaging with unread badges, block/delete conversations,
  and an in-thread system for proposing a meetup, confirming it, and marking the exchange
  complete once payment has changed hands in person.
- **Ratings & trust** — once an exchange is marked complete, both sides can rate each other
  1–5 stars with optional written feedback. Aggregate scores show up on profiles and listings so
  buyers and sellers can gauge trustworthiness before ever messaging.
- **Admin dashboard** — platform-wide stats (users, listings, chat activity, 7-day activity),
  user moderation (block/unblock, delete — admin accounts are delete-protected), and a boost
  toggle for listings, all backed by real endpoints rather than static data.
- **Direct support channel** — a "Contact Admin" flow that opens a real chat thread with a
  platform admin, using the same messaging infrastructure as any other conversation.

## Tech Stack

**Mobile app**
| Layer | Choice |
|---|---|
| Framework | Flutter (Dart) |
| State management | Provider |
| Navigation | go_router |
| HTTP client | Dio |
| Realtime | socket_io_client |
| Secure storage | flutter_secure_storage (JWT) |
| Maps | flutter_map + latlong2 (OpenStreetMap tiles — no API key required) |
| Images | image_picker, cached_network_image |

**Backend**
| Layer | Choice |
|---|---|
| Runtime | Node.js + Express |
| Database | MongoDB (via Mongoose ODM) |
| Realtime | Socket.IO (WebSocket transport) |
| Auth | JWT (jsonwebtoken) + bcrypt password hashing |
| Validation | express-validator |
| Image storage | Cloudinary (via multer-storage-cloudinary) |
| Transactional email | Resend |
| Scheduled jobs | node-cron |
| Security middleware | helmet, express-rate-limit, cors |
| Logging | morgan |

**Infrastructure**
- MongoDB Atlas (managed cloud database)
- Cloudinary (image CDN + optimization)
- Resend (email delivery)
- Railway-ready backend (`railway.toml` included) for deployment

## Architecture

A two-part monorepo: a Flutter client and a Node/Express API, talking over a versioned REST
interface plus a persistent WebSocket connection for anything real-time.

```
┌─────────────────┐        HTTPS/REST         ┌──────────────────┐
│  Flutter mobile  │ ───────────────────────▶  │  Express API      │
│  (iOS/Android)   │ ◀───────────────────────  │                    │
│                  │                            │                    │
│                  │        WebSocket           │                    │
│                  │ ◀════════════════════════▶ │  Socket.IO server  │
└─────────────────┘                            └─────────┬────────┘
                                                            │
                                            ┌───────────────┼───────────────┐
                                            ▼               ▼               ▼
                                      MongoDB Atlas    Cloudinary        Resend
                                      (data)           (images)          (email)
```

The API is stateless aside from the live socket registry — every request carries its own JWT,
so any number of API instances could sit behind a load balancer without session affinity.

## Database Design

MongoDB, accessed through Mongoose schemas. Five core collections:

**`users`**
Account identity, credentials (bcrypt-hashed, cost factor 12), role (`user`/`admin`),
verification flags, favorited listings, and a denormalized `ratingAvg`/`ratingCount` pair that's
recomputed on every new rating rather than aggregated on read — keeps profile/listing fetches to
a single query instead of a join-and-average every time. A `lastActiveAt` timestamp is bumped on
login and on every authenticated request, powering the admin dashboard's activity view.

**`listings`**
Title, description, price, category, condition, images, a GeoJSON `Point` for map placement, a
lifecycle `status` (`active` → `pending` → `offMarket`), and an `expiresAt` (90 days out) that a
daily cron job enforces automatically. `boostedUntil` is schema-ready for the paid-boost feature —
while it's in the future, the listing sorts above everything else; a separate hourly cron clears
it back to `null` once the paid window lapses, so an expired boost can never keep out-ranking
fresh listings indefinitely.

**`threads`**
Exactly two participants, an optional listing reference (a "Contact Admin" thread has none), a
snapshot of the listing at conversation-start (title/price/image — survives the listing later
being edited or deleted), and an embedded `meetup` sub-document tracking the proposed location,
time, and confirmation state for that specific exchange.

**`messages`**
Belongs to a thread; tracks sender, body, and a `readBy` array used to compute per-thread and
global unread counts without a separate read-receipts collection.

**`ratings`**
One document per (thread, rater) pair — a unique compound index prevents a transaction from
being rated twice by the same side. Score (1–5) and optional written feedback.

**Indexing strategy**: a `2dsphere` index on `listings.coordinates` makes map-radius queries fast
at the database layer rather than filtering in application code; compound indexes on
`(status, createdAt)`, `(status, category)`, and `(participants, lastMessageAt)` match the app's
actual query shapes (the feed, category filters, and thread lists) rather than indexing every
field indiscriminately.

## Real-Time Messaging

Chat delivery uses **Socket.IO over a WebSocket transport** (long-polling fallback is explicitly
disabled client-side), not HTTP polling. That distinction is the whole reason it's fast:

- **Polling** means the client repeatedly asks "anything new?" on a timer — the *fastest* a
  message could ever arrive is one polling interval, and every idle check still costs a request.
- **A persistent WebSocket connection** means the server *pushes* a message down the open
  connection the instant it's written to the database — there's no interval to wait out and no
  wasted idle requests.

Each authenticated client joins a private room (`user:<their id>`) the moment it connects. When
someone sends a message, the API writes it to MongoDB and immediately emits `newMessage` to the
recipient's room — one write, one push, no broadcast to anyone who isn't a party to that
conversation. In practice that means delivery is bound almost entirely by network round-trip
time rather than server-side overhead: typically well under a second on a normal connection,
often near-instant on the same WiFi network. The same room-based push model drives unread-count
badges and live meetup-status updates (proposed/confirmed/completed), so those update instantly
too instead of waiting for the user to pull to refresh.

REST is still used for everything that isn't inherently "push" — fetching message history,
creating a listing, submitting a rating — since those are naturally request/response operations
where a persistent connection wouldn't add anything.

## Security

- Passwords hashed with bcrypt (cost factor 12), never stored or returned in plaintext
- JWTs signed server-side, 7-day expiry, required on every protected route
- Every write endpoint validated with express-validator before it touches a controller
- `helmet` for standard HTTP security headers; `cors` restricted to known origins (plus
  no-origin requests, which covers native mobile clients)
- Rate limiting: 100 requests/15 min globally per IP, 200/15 min on auth routes specifically
- Admin routes gated by both authentication *and* a role check; admin accounts cannot be
  deleted by anyone, including other admins
- Email verification required before first login — unverified accounts can register but not
  authenticate

## API Overview

| Group | Examples |
|---|---|
| `/api/auth` | register, login, verify email, forgot/reset password, resend verification |
| `/api/listings` | list/search/filter, create, update, status, favorite, map pins |
| `/api/threads` | list conversations, send message, propose/confirm/complete meetup, rate, contact admin |
| `/api/ratings` | fetch a user's received ratings |
| `/api/admin` | platform stats, user management, listing moderation & boost |

Every response follows one envelope shape — `{ success, message, data }` on success,
`{ success: false, message, errors? }` on failure — so the client never has to guess a
response's structure.

## How It Was Built

Roughly in this order, each stage building on the data model established before it:

1. **Data modeling** — sketched the five core entities (User, Listing, Thread, Message, Rating)
   and how they reference each other before writing any endpoint, so later features (ratings,
   meetups) could be added as extensions of existing relationships rather than bolted on.
2. **Backend foundation** — Express app skeleton, MongoDB connection handling, a consistent
   error-handling middleware chain, and the shared response envelope every route uses.
3. **Accounts & auth** — registration with automatic `.edu` verification, email confirmation
   flow, JWT issuing, and password reset — the prerequisite for everything else being
   user-scoped.
4. **Listings** — schema, the Cloudinary image pipeline, CRUD endpoints, and search/filter/sort
   query logic.
5. **Real-time chat** — Socket.IO wired into the existing Express HTTP server, thread/message
   schemas, and room-based delivery.
6. **Map & meetup coordination** — extended the thread model with an embedded meetup
   sub-document and built the propose → confirm → complete lifecycle on top of the existing chat
   system rather than as a separate feature.
7. **Trust & ratings** — added once "complete" was a real, reachable state in the meetup
   lifecycle, since a rating only makes sense after an exchange actually happened.
8. **Admin tooling** — a dashboard reading real aggregate queries against the same collections
   everything else writes to, plus moderation actions wired to the same user/listing schemas.
9. **Mobile client** — the Flutter app built screen by screen against the already-working API:
   explore/search, listing detail, create/edit, chat + meetup UI, profile, and the admin
   dashboard, tied together with the black-and-gold theme throughout.
10. **Hardening** — real-device testing surfaced and fixed a handful of concurrency/state bugs
    (list-widget identity across item removal, a stale WebSocket connection surviving an account
    switch, an unbounded boost expiry) before considering any feature "done."

## Project Structure

```
ucfmarketplace/
├── mobile/                  # Flutter app
│   └── lib/
│       ├── config/          # Theme, router
│       ├── models/          # Listing, Thread, Message, User, Rating-adjacent types
│       ├── providers/       # Auth, Listings, Chat state (Provider package)
│       ├── screens/         # One folder per feature area
│       ├── services/        # API client (Dio + JWT interceptor)
│       └── widgets/         # Shared components (listing card, star rating, ...)
└── server/                  # Node/Express API
    └── src/
        ├── config/          # DB connection, Cloudinary
        ├── controllers/     # Route handlers, grouped by resource
        ├── middleware/      # Auth, validation, error handling
        ├── models/          # Mongoose schemas
        ├── routes/          # Express routers
        └── utils/           # Email, geocoding, cron jobs, seed data
```

## Getting Started

**Backend**
```bash
cd server
npm install
cp .env.example .env   # fill in MongoDB/Cloudinary/Resend credentials
npm run dev
```

**Mobile app**
```bash
cd mobile
flutter pub get
flutter run
```

The API base URL is set in `mobile/lib/services/api_service.dart` — point it at your machine's
address on the network the device is using.

## Next Steps to Complete

Functionally working end-to-end today, but a few things stand between this and a public
release:

**Deployment**
- [ ] Deploy the backend (Railway config is already in place — `server/railway.toml`) so the
  app isn't dependent on a laptop staying on and reachable
- [ ] Point `SERVER_URL` and the mobile app's API base URL at that permanent deployed address
  instead of a local network IP, which changes across networks/reboots
- [ ] Move Cloudinary and Resend off free-tier defaults (current sender is the shared
  `onboarding@resend.dev` sandbox address, which limits who can actually receive email) — verify
  a real sending domain in Resend
- [ ] iOS build — only Android has been built and tested so far; the Flutter codebase itself is
  cross-platform, but iOS signing/App Store setup hasn't been done

**Product completeness**
- [ ] Real payment flow for boosted listings — the toggle exists and works, but it's
  admin-triggered today rather than a self-serve paid flow
- [ ] Public reviews screen — the ratings API already returns a user's full review history;
  there's just no dedicated screen surfacing it yet (today only the aggregate score/count shows)
- [ ] Push notifications for new messages when the app isn't open
- [ ] Automated test coverage — Jest is wired up on the backend but no test suite exists yet
  beyond the placeholder

**Operational**
- [ ] Replace the shared demo password (`Hero12345` across 5 seed accounts) and remove or
  reset the seed data before any real users are onboarded
- [ ] Set a real `ADMIN_EMAIL` / rotate the admin password before going live
- [ ] Decide on and push to a permanent git remote — this repo is currently pushing to a
  personal collaborator's GitHub, not a dedicated project remote

## Roadmap

- Paid boosts: the schema and toggle already exist (admin-controlled today); next step is a
  real payment flow so sellers can self-serve a boost rather than requesting one from an admin
- Push notifications for new messages when the app is backgrounded
- A public reviews view surfacing written feedback on a seller's profile (the API for it already
  exists; no dedicated screen yet)
