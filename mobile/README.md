# MedTrack Mobile (Phase 1 MVP)

Flutter client implementing the clean-architecture layout described in
[`../docs/architecture.md`](../docs/architecture.md) §5: `presentation` → `domain` → `data`
per feature, plus shared `core/` (network, local storage, notifications) and `shared/`
(theme, widgets).

## Structure

```
lib/
├── app/                # MaterialApp root + screen wiring
├── core/
│   ├── network/         # ApiClient (REST + JWT)
│   ├── storage/          # SQLite local store + offline sync queue
│   └── notification/     # Local notification wrapper
├── features/
│   ├── auth/
│   ├── medication/       # today's dose schedule + dose logging
│   ├── symptom_tracking/ # pain score logging
│   ├── alerts/            # open alerts + acknowledge
│   └── dashboard/         # caregiver/provider view (Phase 2 stub)
└── shared/
    ├── theme/
    └── widgets/
```

## Running

Start `../backend` first (`npm run start:dev`, listens on `http://localhost:3000/v1`), then:

```bash
flutter pub get
flutter run
```

`lib/main.dart` picks a sensible default API host per platform — `10.0.2.2` on the
Android emulator (its alias for the host machine's `localhost`; plain `localhost`
from inside the emulator means the emulator itself, not your machine), `localhost`
everywhere else (iOS simulator, desktop). Override it explicitly when neither
applies, e.g. a physical device on the same network as the backend:

```bash
flutter run --dart-define=MEDTRACK_API_BASE_URL=http://<your-machine-lan-ip>:3000/v1
```

For Android, an emulator or device must be connected (`flutter devices`) before `flutter run`.

## Verified

`flutter pub get`, `flutter analyze`, and `flutter test` all pass. `android/app/build.gradle.kts`
enables core library desugaring, which `flutter_local_notifications` requires — without it,
`flutter run` fails at the `checkDebugAarMetadata` Gradle task.
