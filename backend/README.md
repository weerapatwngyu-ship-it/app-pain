# MedTrack Backend (Phase 1 MVP)

NestJS + TypeORM + PostgreSQL API implementing the core MedTrack domains: auth, patients,
prescriptions & dose schedules, dose logs, symptom logs, and alerts. See
[`../docs/architecture.md`](../docs/architecture.md) for the full system design.

## Requirements

- Node.js 20+
- PostgreSQL 14+

## Setup

```bash
cp .env.example .env
npm install
npm run start:dev
```

The API listens on `http://localhost:3000/v1`.

## Modules

| Module | Path prefix | Notes |
|---|---|---|
| `auth` | `/v1/auth` | Register/login, issues JWT access tokens |
| `patients` | `/v1/patients` | Patient profile, access-controlled by owner or active `patient-links` |
| `patient-links` | `/v1/patient-links` | Caregiver/provider ↔ patient linking with consent (pending/active/revoked) |
| `prescriptions` | `/v1/prescriptions`, `/v1/patients/:id/schedule/today` | Prescriptions + generated dose schedules |
| `dose-logs` | `/v1/dose-logs` | Records taken/skipped/snoozed/missed doses |
| `symptom-logs` | `/v1/symptom-logs`, `/v1/patients/:id/trends` | Symptom logs + combined dose/symptom trend series |
| `alerts` | `/v1/alerts`, `/v1/alert-rules` | Rule-based alert records and acknowledgement |

`TypeOrmModule` runs with `synchronize: true` for local development only — replace with
migrations before any shared or production environment.
