# MedTrack

Mobile app for medication dispensing reminders and patient symptom tracking.
This package contains the Flutter `lib/` source tree implementing the
architecture described in the project's design document, built with a
feature-first Clean Architecture layout (`presentation` / `domain` / `data`
per feature).

## Getting started

This repo ships the Dart source only — the native `android/` and `ios/`
platform folders are generated locally (they're gitignored since they're
machine/toolchain-specific):

```bash
cd medtrack
flutter create . --platforms=android,ios   # generates android/ and ios/
flutter pub get
flutter run
```

Requires Flutter 3.19+ / Dart 3.3+.

## Demo / mock mode

No backend is deployed yet, so `Env.useMockBackend` (`lib/app/di/env.dart`)
defaults to `true`: login accepts any email/password and every feature
screen is backed by in-memory sample data (see the `Mock*Repository`
classes under each feature's `data/repositories/`), so the app is fully
explorable via the bottom-nav shown after login. Once a real API is
deployed, run with:

```bash
flutter run --dart-define=USE_MOCK_BACKEND=false --dart-define=API_BASE_URL=https://your-api.example.com
```

## Structure

```
lib/
├── app/            # entry point, routing, DI wiring
├── core/           # cross-cutting: network client, local db, notifications
├── features/
│   ├── auth/               # login, session, account linking
│   ├── medication/         # prescriptions, dose schedule, dose log
│   ├── symptom_tracking/   # symptom & vital sign logging, trends
│   ├── alerts/             # missed-dose / abnormal-symptom alerts
│   └── dashboard/          # caregiver / provider overview
└── shared/         # theme, reusable widgets, utils
```

Each feature under `features/` follows the same three layers:

- **domain** — entities and use cases, no Flutter/IO dependencies
- **data** — repository implementations, local/remote data sources, DTOs
- **presentation** — screens, widgets, Riverpod providers

## State management & backend

- State: [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod)
- DI: [`get_it`](https://pub.dev/packages/get_it)
- Routing: [`go_router`](https://pub.dev/packages/go_router)
- HTTP: [`dio`](https://pub.dev/packages/dio) against the backend API
  described in the architecture doc (`/v1/...` REST endpoints)
- Local persistence: `sqflite` (offline-first dose/symptom logs) +
  `flutter_secure_storage` (tokens)
- Notifications: `flutter_local_notifications` for on-device dose reminders
  (works offline), backed by FCM/APNs for server-triggered alerts

## Tests

```bash
flutter test
```
