-- MedTrack RLS regression tests.
--
-- Every policy in schema.sql is the only thing separating one patient's
-- medical records from every other signed-in user, so the holes fixed here
-- get a test that actually attempts the exploit rather than a code comment.
--
-- These run against a plain local Postgres, NOT against your Supabase
-- project — they create and roll back data, and the stubs below stand in for
-- Supabase's auth/storage schemas. Do not run this in the Supabase SQL
-- Editor.
--
-- Usage (needs a local postgres 14+ and a non-root user):
--   initdb -D /tmp/medtrack-pg -U postgres -A trust
--   pg_ctl -D /tmp/medtrack-pg -o "-p 55432" start
--   psql -p 55432 -U postgres -f supabase/rls_test.sql          # stubs + tests
--   psql -p 55432 -U postgres -f supabase/schema.sql            # (run between)
--
-- Expected result: every EXPLOIT block errors or returns no rows, and every
-- POSITIVE/CONTROL block succeeds. An EXPLOIT block that succeeds is a
-- regression.

-- Minimal stand-ins for the Supabase-managed objects schema.sql builds on.
create role authenticated;
create role anon;
create role service_role;

create schema auth;
create table auth.users (
  id uuid primary key default gen_random_uuid(),
  email text,
  raw_user_meta_data jsonb default '{}'::jsonb
);
create or replace function auth.uid() returns uuid language sql stable as
$$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;

create schema storage;
create table storage.buckets (id text primary key, name text, public boolean);
create table storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text, name text, owner uuid
);
alter table storage.objects enable row level security;
create or replace function storage.foldername(name text) returns text[]
  language sql immutable as $$ select string_to_array(name, '/') $$;

-- Load supabase/schema.sql now, then continue with the blocks below.
\i schema.sql

grant usage on schema public to authenticated;
grant all on all tables in schema public to authenticated;
grant usage on schema storage to authenticated;
grant all on all tables in schema storage to authenticated;

-- Two ordinary patients, provisioned by the real handle_new_user trigger.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111','a@test.com'),
  ('22222222-2222-2222-2222-222222222222','b@test.com');

\echo '--- baseline: trigger provisioned both patients ---'
select email, (select count(*) from public.patients p where p.owner_user_id = u.id) as patients,
       (select role from public.profiles pr where pr.id = u.id) as role
from auth.users u order by email;

create or replace function public.as_user(uid text) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', uid, true);
  perform set_config('request.jwt.claims', json_build_object('role','authenticated','sub',uid)::text, true);
end $$;

\echo ''
\echo '=== EXPLOIT 1: patient self-promotes to admin (must FAIL) ==='
begin;
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  update public.profiles set role = 'admin' where id = '11111111-1111-1111-1111-111111111111';
rollback;

\echo ''
\echo '=== CONTROL 1: patient renames self (must SUCCEED, 1 row) ==='
begin;
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  update public.profiles set name = 'ชื่อใหม่' where id = '11111111-1111-1111-1111-111111111111';
rollback;

\echo ''
\echo '=== EXPLOIT 2: read another patient rows (must be 0) ==='
begin;
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  select count(*) as visible_patients_total from public.patients;
  select count(*) as visible_profiles_total from public.profiles;
rollback;

\echo ''
\echo '=== EXPLOIT 3: hijack ownership of a linked patient (must FAIL) ==='
begin;
  -- B is an active caregiver on A's patient record.
  insert into public.patient_links (patient_id, user_id, role, status)
  values ((select id from public.patients where owner_user_id='11111111-1111-1111-1111-111111111111'),
          '22222222-2222-2222-2222-222222222222','caregiver','active');
  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  update public.patients set owner_user_id = '22222222-2222-2222-2222-222222222222'
   where id = (select id from public.patients where owner_user_id='11111111-1111-1111-1111-111111111111');
rollback;

\echo ''
\echo '=== EXPLOIT 4: promoted-then-prescribe for unrelated patient (must be 0 rows) ==='
begin;
  -- Simulate the worst case: B really IS a provider, but has no link to A.
  update public.profiles set role='provider' where id='22222222-2222-2222-2222-222222222222';
  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  insert into public.prescriptions (patient_id, medication_name, dosage, frequency, start_date)
  values ((select id from public.patients where owner_user_id='11111111-1111-1111-1111-111111111111'),
          'Fentanyl','100mg','hourly', current_date);
rollback;

\echo ''
\echo '=== EXPLOIT 5: patient edits alert severity/message (status only must apply) ==='
begin;
  insert into public.alerts (patient_id, severity, message)
  values ((select id from public.patients where owner_user_id='11111111-1111-1111-1111-111111111111'),
          'critical','ค่าความปวดสูงผิดปกติ');
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  update public.alerts set status='acknowledged', severity='normal', message='hacked';
  reset role;
  select status, severity, message from public.alerts;
rollback;

\echo '=== POSITIVE 1: patient updates own patient record (name/birth/gender) ==='
begin;
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  update public.patients set name='สมชาย', birth_date='1990-05-02', gender='male'
   where owner_user_id='11111111-1111-1111-1111-111111111111';
rollback;

\echo ''
\echo '=== POSITIVE 2: patient logs a dose + a symptom on own record ==='
begin;
  -- staff-created prescription/schedule, seeded as owner (service-role equivalent)
  insert into public.prescriptions (id, patient_id, medication_name, dosage, frequency, start_date)
  values ('aaaaaaaa-0000-0000-0000-000000000001',
          (select id from public.patients where owner_user_id='11111111-1111-1111-1111-111111111111'),
          'Paracetamol','500mg','วันละ 3 ครั้ง', current_date);
  insert into public.dose_schedules (id, prescription_id, scheduled_time)
  values ('bbbbbbbb-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001','08:00');

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  select count(*) as prescriptions_visible from public.prescriptions;
  select count(*) as schedules_visible from public.dose_schedules;
  insert into public.dose_logs (schedule_id, scheduled_at, status)
  values ('bbbbbbbb-0000-0000-0000-000000000001', now(), 'taken');
  insert into public.symptom_logs (patient_id, pain_score, category)
  values ((select id from public.patients where owner_user_id='11111111-1111-1111-1111-111111111111'), 7, 'head');
rollback;

\echo ''
\echo '=== POSITIVE 3: properly LINKED provider CAN prescribe for that patient ==='
begin;
  update public.profiles set role='provider' where id='22222222-2222-2222-2222-222222222222';
  insert into public.patient_links (patient_id, user_id, role, status)
  values ((select id from public.patients where owner_user_id='11111111-1111-1111-1111-111111111111'),
          '22222222-2222-2222-2222-222222222222','provider','active');
  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  insert into public.prescriptions (id, patient_id, medication_name, dosage, frequency, start_date)
  values ('cccccccc-0000-0000-0000-000000000001',
          (select id from public.patients where owner_user_id='11111111-1111-1111-1111-111111111111'),
          'Ibuprofen','200mg','วันละ 2 ครั้ง', current_date);
  insert into public.dose_schedules (prescription_id, scheduled_time)
  values ('cccccccc-0000-0000-0000-000000000001','09:00');
rollback;

\echo ''
\echo '=== POSITIVE 4: admin retains global prescribe access ==='
-- The patient id is captured BEFORE switching role: patients_select does not
-- give an admin global read (see can_manage_patient_care's note), so an
-- inline subquery here would resolve to NULL and fail on NOT NULL instead of
-- testing the policy.
begin;
  update public.profiles set role='admin' where id='22222222-2222-2222-2222-222222222222';
  select id as target_patient from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  \echo '  -- expect INSERT 0 1:'
  insert into public.prescriptions (patient_id, medication_name, dosage, frequency, start_date)
  values (:'target_patient','Amoxicillin','250mg','วันละ 3 ครั้ง', current_date);
  \echo '  -- expect 1 (own record only) — admin has no global patient read:'
  select count(*) as admin_visible_patients from public.patients;
rollback;

\echo ''
\echo '=== POSITIVE 5: avatar upload to own folder allowed, other folder denied ==='
begin;
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  insert into storage.objects (bucket_id, name)
    values ('avatars','11111111-1111-1111-1111-111111111111/me.jpg');
  \echo '  (next insert must FAIL)'
  insert into storage.objects (bucket_id, name)
    values ('avatars','22222222-2222-2222-2222-222222222222/steal.jpg');
rollback;

\echo ''
\echo '=== EXPLOIT 6: patient posts a question that already answers itself (must FAIL) ==='
-- A question carrying its own "doctor's answer" would show in the app as
-- though staff had replied, so the insert policy pins the reply columns empty.
begin;
  select id as pid from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  insert into public.health_questions (patient_id, asked_by, topic_key, question, status, answer)
  values (:'pid','11111111-1111-1111-1111-111111111111','diabetes','ปลอมคำตอบ','answered','กินยาให้เยอะขึ้น');
rollback;

\echo ''
\echo '=== EXPLOIT 7: patient attributes a question to another user (must FAIL) ==='
begin;
  select id as pid from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  insert into public.health_questions (patient_id, asked_by, topic_key, question)
  values (:'pid','22222222-2222-2222-2222-222222222222','diabetes','สวมรอยเป็นคนอื่น');
rollback;

\echo ''
\echo '=== EXPLOIT 8: patient rewrites an answered question (must affect 0 rows) ==='
-- There is no UPDATE policy for patients, so the update matches nothing
-- rather than erroring.
begin;
  select id as pid from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  insert into public.health_questions (id, patient_id, asked_by, topic_key, question, status, answer)
  values ('dddddddd-0000-0000-0000-000000000001', :'pid',
          '11111111-1111-1111-1111-111111111111','diabetes','น้ำตาลสูงทำยังไงดี',
          'answered','ปรับอาหารและพบแพทย์ตามนัด');
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  \echo '  -- expect UPDATE 0:'
  update public.health_questions set answer='แก้คำตอบหมอ', status='closed'
   where id='dddddddd-0000-0000-0000-000000000001';
  reset role;
  select answer from public.health_questions where id='dddddddd-0000-0000-0000-000000000001';
rollback;

\echo ''
\echo '=== EXPLOIT 9: read another patient''s questions (must be 0 rows) ==='
begin;
  select id as pid from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  insert into public.health_questions (patient_id, asked_by, topic_key, question)
  values (:'pid','11111111-1111-1111-1111-111111111111','allergy','ผื่นคันที่แขน');
  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  \echo '  -- expect 0:'
  select count(*) as other_patients_questions_visible from public.health_questions;
rollback;

\echo ''
\echo '=== POSITIVE 6: patient asks, reads back, and a linked provider answers ==='
begin;
  select id as pid from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  \echo '  -- ask (expect INSERT 0 1):'
  insert into public.health_questions (patient_id, asked_by, topic_key, question)
  values (:'pid','11111111-1111-1111-1111-111111111111','hypertension','ความดัน 150/95 อันตรายไหม');
  \echo '  -- read back (expect 1):'
  select count(*) as my_questions from public.health_questions;

  reset role;
  update public.profiles set role='provider' where id='22222222-2222-2222-2222-222222222222';
  insert into public.patient_links (patient_id, user_id, role, status)
  values (:'pid','22222222-2222-2222-2222-222222222222','provider','active');
  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  \echo '  -- linked provider answers (expect UPDATE 1):'
  update public.health_questions
     set answer='ควรวัดซ้ำและพบแพทย์', status='answered', answered_at=now()
   where patient_id=:'pid';
rollback;

-- ---------------------------------------------------------------------------
-- Doctor accounts and patient↔doctor chat
-- ---------------------------------------------------------------------------

\echo ''
\echo '=== EXPLOIT 10: patient publishes themselves as a doctor (must FAIL) ==='
-- The app used to show every patient an "add doctor" button. Anyone listing
-- themselves as a doctor is how unqualified advice reaches patients, so the
-- directory is admin-write only.
begin;
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  insert into public.doctors (name, specialty) values ('หมอปลอม','อายุรกรรม');
rollback;

\echo ''
\echo '=== EXPLOIT 11: a provider edits another doctor''s listing (must affect 0 rows) ==='
begin;
  insert into public.doctors (id, user_id, name, specialty)
  values ('eeeeeeee-0000-0000-0000-000000000001', null, 'หมอสมชาย','หัวใจ');
  update public.profiles set role='provider' where id='22222222-2222-2222-2222-222222222222';
  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  \echo '  -- expect UPDATE 0:'
  update public.doctors set name='ชื่อที่ถูกแก้' where id='eeeeeeee-0000-0000-0000-000000000001';
rollback;

\echo ''
\echo '=== POSITIVE 7: a doctor edits their OWN listing, but cannot reassign it ==='
begin;
  insert into public.doctors (id, user_id, name, specialty)
  values ('eeeeeeee-0000-0000-0000-000000000002','22222222-2222-2222-2222-222222222222',
          'หมอสมหญิง','ผิวหนัง');
  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  \echo '  -- own listing (expect UPDATE 1):'
  update public.doctors set bio='รับปรึกษาผื่นแพ้' where id='eeeeeeee-0000-0000-0000-000000000002';
  \echo '  -- hand listing to another account (expect ERROR):'
  update public.doctors set user_id='11111111-1111-1111-1111-111111111111'
   where id='eeeeeeee-0000-0000-0000-000000000002';
rollback;

\echo ''
\echo '=== POSITIVE 8: patient opens a chat and both sides post ==='
begin;
  select id as pid from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  insert into public.doctors (id, user_id, name, specialty)
  values ('eeeeeeee-0000-0000-0000-000000000003','22222222-2222-2222-2222-222222222222',
          'หมอสมหญิง','ผิวหนัง');

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  \echo '  -- patient opens thread (expect INSERT 0 1):'
  insert into public.conversations (id, patient_id, doctor_id)
  values ('ffffffff-0000-0000-0000-000000000001', :'pid', 'eeeeeeee-0000-0000-0000-000000000003');
  \echo '  -- patient posts (expect INSERT 0 1):'
  insert into public.messages (conversation_id, sender_id, body)
  values ('ffffffff-0000-0000-0000-000000000001','11111111-1111-1111-1111-111111111111','ผื่นคันมา 3 วันครับ');

  select public.as_user('22222222-2222-2222-2222-222222222222');
  \echo '  -- doctor sees the thread (expect 1):'
  select count(*) as doctor_visible_threads from public.conversations;
  \echo '  -- doctor replies (expect INSERT 0 1):'
  insert into public.messages (conversation_id, sender_id, body)
  values ('ffffffff-0000-0000-0000-000000000001','22222222-2222-2222-2222-222222222222','ลองถ่ายรูปผื่นมาให้ดูหน่อยครับ');
  \echo '  -- both messages visible to doctor (expect 2):'
  select count(*) as visible_messages from public.messages;
rollback;

\echo ''
\echo '=== EXPLOIT 12: an unrelated doctor reads someone else''s thread (must be 0) ==='
begin;
  select id as pid from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  -- Thread belongs to doctor A; doctor B is a different listing entirely.
  insert into public.doctors (id, user_id, name, specialty) values
    ('eeeeeeee-0000-0000-0000-000000000004', null, 'หมอ A','หัวใจ'),
    ('eeeeeeee-0000-0000-0000-000000000005','22222222-2222-2222-2222-222222222222','หมอ B','ผิวหนัง');
  insert into public.conversations (id, patient_id, doctor_id)
  values ('ffffffff-0000-0000-0000-000000000002', :'pid','eeeeeeee-0000-0000-0000-000000000004');
  insert into public.messages (conversation_id, sender_id, body)
  values ('ffffffff-0000-0000-0000-000000000002','11111111-1111-1111-1111-111111111111','ความลับทางการแพทย์');

  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  \echo '  -- expect 0 threads and 0 messages:'
  select count(*) as threads from public.conversations;
  select count(*) as msgs from public.messages;
rollback;

\echo ''
\echo '=== EXPLOIT 13: patient posts a message signed as the doctor (must FAIL) ==='
begin;
  select id as pid from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  insert into public.doctors (id, user_id, name, specialty)
  values ('eeeeeeee-0000-0000-0000-000000000006','22222222-2222-2222-2222-222222222222','หมอ B','ผิวหนัง');
  insert into public.conversations (id, patient_id, doctor_id)
  values ('ffffffff-0000-0000-0000-000000000003', :'pid','eeeeeeee-0000-0000-0000-000000000006');

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  insert into public.messages (conversation_id, sender_id, body)
  values ('ffffffff-0000-0000-0000-000000000003','22222222-2222-2222-2222-222222222222','คุณหายดีแล้ว หยุดยาได้');
rollback;

\echo ''
\echo '=== EXPLOIT 14: patient rewrites a doctor''s message (must affect 0 rows) ==='
begin;
  select id as pid from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  insert into public.doctors (id, user_id, name, specialty)
  values ('eeeeeeee-0000-0000-0000-000000000007','22222222-2222-2222-2222-222222222222','หมอ B','ผิวหนัง');
  insert into public.conversations (id, patient_id, doctor_id)
  values ('ffffffff-0000-0000-0000-000000000004', :'pid','eeeeeeee-0000-0000-0000-000000000007');
  insert into public.messages (id, conversation_id, sender_id, body)
  values ('11111111-aaaa-0000-0000-000000000001','ffffffff-0000-0000-0000-000000000004',
          '22222222-2222-2222-2222-222222222222','กินยาต่อตามเดิม');

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  \echo '  -- expect UPDATE 0 and DELETE 0:'
  update public.messages set body='หยุดยาได้' where id='11111111-aaaa-0000-0000-000000000001';
  delete from public.messages where id='11111111-aaaa-0000-0000-000000000001';
rollback;

\echo ''
\echo '=== EXPLOIT 15: doctor cold-opens a thread with a patient (must FAIL) ==='
begin;
  select id as pid from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  insert into public.doctors (id, user_id, name, specialty)
  values ('eeeeeeee-0000-0000-0000-000000000008','22222222-2222-2222-2222-222222222222','หมอ B','ผิวหนัง');
  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  insert into public.conversations (patient_id, doctor_id)
  values (:'pid','eeeeeeee-0000-0000-0000-000000000008');
rollback;

\echo ''
\echo '=== POSITIVE 9: admin manages the directory and sees accounts ==='
begin;
  update public.profiles set role='admin' where id='22222222-2222-2222-2222-222222222222';
  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  \echo '  -- admin adds a listing (expect INSERT 0 1):'
  insert into public.doctors (user_id, name, specialty)
  values ('11111111-1111-1111-1111-111111111111','หมอที่อนุมัติแล้ว','อายุรกรรม');
  \echo '  -- admin sees all accounts, needed to pick who to promote (expect 2):'
  select count(*) as visible_profiles from public.profiles;
rollback;

\echo ''
\echo '=== EXPLOIT 16: ordinary patient reads the account list (must be 1 = self) ==='
begin;
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  select count(*) as visible_profiles from public.profiles;
rollback;
