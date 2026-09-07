# KnightMarket Mobile App

Flutter mobile app for KnightMarket — buy and sell with fellow students near campus.

## Features

- **Explore** — Browse listings with search & filters (category, condition, price)
- **Map** — OpenStreetMap pins for browsing listings by area
- **Meetup Arranging** — Pick a public spot + time on the map to exchange an item and confirm payment in person, right from the chat thread
- **Saved** — Favorited listings synced with your account
- **Real-time Chat** — Socket.IO messaging with unread badge on tab
- **List an Item** — Create listings with photo upload (up to 3 photos)
- **Authentication** — Login, register, forgot password, .edu email verification (Verified Student badge)
- **Profile** — Manage your listings and account

## Running locally

```bash
# 1. Start the backend server
cd ../server && npm run dev   # runs on http://localhost:5000

# 2. Run the app
cd mobile
flutter run
```

The API base URL is set in `lib/services/api_service.dart` (`_baseUrl`). It defaults to
`http://localhost:5000/api`, which works for iOS Simulator and Flutter web/desktop. For an
Android emulator, change it to `http://10.0.2.2:5000/api`. For a physical device, use your
machine's local IP (`ipconfig getifaddr en0` on macOS) instead of `localhost`.

## Production

Point `_baseUrl` in `lib/services/api_service.dart` at your deployed API, then build:

```bash
flutter build ios --release
flutter build appbundle --release   # Google Play Store
```

## Project Structure

```
lib/
├── main.dart
├── config/
│   ├── app_router.dart      # go_router routes
│   └── app_theme.dart       # Black & gold brand theme
├── models/                  # User, Listing, Thread, Message
├── services/
│   └── api_service.dart     # Dio + JWT interceptor + secure token storage
├── providers/                # State (AuthProvider, ListingsProvider, ChatProvider)
└── screens/
    ├── main_shell.dart (widgets/) # Bottom tab bar
    ├── auth/                 # Login, Register, Forgot Password
    ├── explore/               # Listing browse + search
    ├── map/                   # Browse map + meetup location picker
    ├── listings/              # Detail, Create, Edit, My Listings
    ├── favorites/             # Saved listings
    ├── chat/                  # Messages + meetup arranging
    └── profile/               # User profile
```

## Backend Sync

The mobile app talks to the same Node/Express + MongoDB API in `../server`:
- Same MongoDB database
- Same JWT authentication
- Same Socket.IO for real-time chat and meetup updates
- Same Cloudinary images
