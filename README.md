# app-pain — MedTrack

MedTrack แอปจ่ายยาและติดตามอาการผู้ป่วย — เชื่อมการกินยาตรงเวลาเข้ากับบันทึกอาการ
เพื่อให้ผู้ป่วย ผู้ดูแล และบุคลากรทางการแพทย์เห็นแนวโน้มเดียวกันแบบเรียลไทม์

ดูสถาปัตยกรรมและการออกแบบระบบฉบับเต็มได้ที่ [`docs/architecture.md`](docs/architecture.md)

## โครงสร้างโปรเจกต์

| ไดเรกทอรี | รายละเอียด |
|---|---|
| [`backend/`](backend/README.md) | NestJS + TypeORM + PostgreSQL API (Phase 1 MVP) |
| [`mobile/`](mobile/README.md) | Flutter mobile client (Phase 1 MVP) |
| `docs/` | เอกสารออกแบบสถาปัตยกรรมระบบ |

## เริ่มต้นใช้งาน

```bash
# Backend
cd backend
cp .env.example .env
npm install
npm run start:dev

# Mobile (ในอีก terminal)
cd mobile
flutter pub get
flutter run --dart-define=MEDTRACK_API_BASE_URL=http://localhost:3000/v1
```

## สถานะการพัฒนา

กำลังพัฒนา **Phase 1 (MVP)** ตาม roadmap ในเอกสารสถาปัตยกรรม §11: บัญชีผู้ใช้, ใบสั่งยา,
ตารางเตือนยา, บันทึกการกินยา (dose log), และบันทึกอาการพื้นฐาน (pain score) — ยังไม่รวมผู้ดูแล
หรือบุคลากรทางการแพทย์ (Phase 2–3)
