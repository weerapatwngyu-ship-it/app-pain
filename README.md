# app-pain — MedTrack

MedTrack แอปจ่ายยาและติดตามอาการผู้ป่วย — เชื่อมการกินยาตรงเวลาเข้ากับบันทึกอาการ
เพื่อให้ผู้ป่วย ผู้ดูแล และบุคลากรทางการแพทย์เห็นแนวโน้มเดียวกันแบบเรียลไทม์

ดูสถาปัตยกรรมและการออกแบบระบบฉบับเต็มได้ที่ [`docs/architecture.md`](docs/architecture.md)

## โครงสร้างโปรเจกต์

| ไดเรกทอรี | รายละเอียด |
|---|---|
| [`mobile/`](mobile/README.md) | Flutter mobile client |
| `supabase/` | สคีมาฐานข้อมูลและกฎความปลอดภัย (RLS) — รันใน Supabase SQL Editor |
| `docs/` | เอกสารออกแบบสถาปัตยกรรมระบบ |

## เริ่มต้นใช้งาน

แอปคุยกับ Supabase โดยตรง ไม่มีเซิร์ฟเวอร์ของเราเองคั่นกลาง — ไม่ต้องเปิด backend
ค้างไว้ และไม่ต้องอยู่ WiFi วงเดียวกัน

1. สร้างโปรเจกต์ที่ [supabase.com](https://supabase.com)
2. เปิด SQL Editor แล้วรัน [`supabase/schema.sql`](supabase/schema.sql) หนึ่งครั้ง
   (สร้างตาราง + กฎความปลอดภัย + ที่เก็บรูป)
3. Authentication → Providers → เปิด **Google** แล้วใส่ OAuth client ID/secret
   จาก Google Cloud Console
4. Authentication → URL Configuration → Redirect URLs เพิ่ม
   `com.example.medtrack://login-callback`
5. รันแอป:

```bash
cd mobile
flutter pub get
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```

`SUPABASE_ANON_KEY` เป็น key สาธารณะ ใส่ในแอปได้ปลอดภัย — สิทธิ์การเข้าถึงข้อมูล
ถูกกำหนดด้วยกฎ RLS ในฐานข้อมูล ไม่ใช่ด้วยการซ่อน key

## สถานะการพัฒนา

กำลังพัฒนา **Phase 1 (MVP)** ตาม roadmap ในเอกสารสถาปัตยกรรม §11: บัญชีผู้ใช้, ใบสั่งยา,
ตารางเตือนยา, บันทึกการกินยา (dose log), และบันทึกอาการพื้นฐาน (pain score) — ยังไม่รวมผู้ดูแล
หรือบุคลากรทางการแพทย์ (Phase 2–3)
