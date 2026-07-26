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

```bash
flutter pub get
flutter run --dart-define=MEDTRACK_API_BASE_URL=http://localhost:3000/v1
```

Point `MEDTRACK_API_BASE_URL` at a running instance of `../backend`.

## Note on this scaffold

This code was written without a Flutter SDK available in the environment that generated
it, so it has **not** been run through `flutter pub get`, `flutter analyze`, or
`flutter test`. Review it — and run those commands — before relying on it.
