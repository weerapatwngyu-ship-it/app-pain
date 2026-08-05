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
3. เข้าสู่ระบบด้วยอีเมล/รหัสผ่านของ Supabase Auth เอง ไม่ต้องตั้งค่าอะไรเพิ่ม —
   Supabase เปิดวิธีนี้ไว้เป็นค่าเริ่มต้นอยู่แล้ว (ผู้ใช้ใหม่ต้องกดลิงก์ยืนยันในอีเมล
   ก่อนเข้าสู่ระบบครั้งแรกได้)
4. รันแอป — แนะนำให้ใช้ไฟล์ `dart_defines.json` แทนการพิมพ์/แปะคำสั่งยาวๆ บรรทัดเดียว
   (การแปะ URL/anon key ยาวๆ ลงเทอร์มินัลโดยตรง โดยเฉพาะจากมือถือหรือแอปเทอร์มินัลบางตัว
   มีโอกาสแทรกอักขระแปลกปลอมหรือขึ้นบรรทัดใหม่กลางคีย์ ทำให้เจอ error ประมาณ
   `FormatException: Invalid HTTP header field value`):

   ```bash
   cd mobile
   cp dart_defines.example.json dart_defines.json
   # แก้ dart_defines.json ใส่ SUPABASE_URL และ SUPABASE_ANON_KEY ของโปรเจกต์ตัวเอง
   flutter pub get
   flutter run --dart-define-from-file=dart_defines.json
   ```

   `dart_defines.json` ถูกใส่ไว้ใน `.gitignore` แล้ว จะไม่ถูก commit เข้า repo

   หรือจะใส่ `--dart-define` ตรงๆ ในคำสั่งเดียวก็ได้ (ใช้ได้ถ้ารันจากเทอร์มินัลบนเครื่อง
   คอมพิวเตอร์ปกติ ไม่ผ่านการแปะข้ามอุปกรณ์):

   ```bash
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
