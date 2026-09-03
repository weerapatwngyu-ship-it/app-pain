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
-- Supabase grants this itself; the stub must too, or auth.uid() in a query
-- (not just inside a SECURITY DEFINER policy) fails with "permission denied".
grant usage on schema auth to authenticated;
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

-- EXPLOIT 15 used to assert that a doctor could not open a thread first.
-- That rule was deliberately reversed: a doctor now starts conversations too,
-- so they can follow up on a symptom log or an alert without waiting to be
-- messaged. The block was removed rather than left failing, because a test
-- that contradicts the intended behaviour is worse than no test. What still
-- holds is covered by POSITIVE 13 (the doctor opens it, the patient reads it)
-- and EXPLOIT 27 (they cannot open one under another doctor's name).

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

\echo ''
\echo '=== POSITIVE 10: an approved doctor READS every patient''s records ==='
-- Deliberately broader than can_access_patient(): a small clinic wants all
-- approved doctors to see the whole caseload. Read only — see EXPLOIT 17.
begin;
  select id as pid from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  insert into public.prescriptions (id, patient_id, medication_name, dosage, frequency, start_date)
  values ('aaaaaaaa-0000-0000-0000-000000000009', :'pid','Metformin','500mg','วันละ 2 ครั้ง', current_date);
  insert into public.symptom_logs (patient_id, pain_score, category)
  values (:'pid', 6, 'head');
  update public.profiles set role='provider' where id='22222222-2222-2222-2222-222222222222';

  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  \echo '  -- sees both patients, not just own (expect 2):'
  select count(*) as patients_visible from public.patients;
  \echo '  -- sees the other patient''s prescription (expect 1):'
  select count(*) as prescriptions_visible from public.prescriptions;
  \echo '  -- sees the other patient''s symptom log (expect 1):'
  select count(*) as symptoms_visible from public.symptom_logs;
rollback;

\echo ''
\echo '=== EXPLOIT 17: that doctor tries to WRITE for an unassigned patient (must FAIL) ==='
-- Widening reads must not widen writes: prescribing for someone else's
-- patient stays blocked by can_manage_patient_care().
begin;
  select id as pid from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  update public.profiles set role='provider' where id='22222222-2222-2222-2222-222222222222';
  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  insert into public.prescriptions (patient_id, medication_name, dosage, frequency, start_date)
  values (:'pid','Fentanyl','100mg','hourly', current_date);
rollback;

\echo ''
\echo '=== EXPLOIT 18: an ordinary patient still sees only themselves (must be 1) ==='
-- The widened read is scoped to provider/admin; a patient must not inherit it.
begin;
  select id as pid from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  insert into public.prescriptions (patient_id, medication_name, dosage, frequency, start_date)
  values (:'pid','Metformin','500mg','วันละ 2 ครั้ง', current_date);
  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  \echo '  -- expect 1 (own patient row only):'
  select count(*) as patients_visible from public.patients;
  \echo '  -- expect 0 (someone else''s prescription):'
  select count(*) as prescriptions_visible from public.prescriptions;
rollback;

\echo ''
\echo '=== POSITIVE 11: admin approves a doctor end to end (listing + role) ==='
-- The whole point of approval: without profiles_update_admin the role update
-- silently matched no rows and the doctor never reached their inbox.
begin;
  update public.profiles set role='admin' where id='11111111-1111-1111-1111-111111111111';
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  \echo '  -- admin publishes the listing (expect INSERT 0 1):'
  insert into public.doctors (id, user_id, name, specialty)
  values ('eeeeeeee-0000-0000-0000-00000000000a',
          '22222222-2222-2222-2222-222222222222','นพ.ทดสอบ','อายุรกรรม');
  \echo '  -- admin grants the role (expect UPDATE 1):'
  update public.profiles set role='provider'
   where id='22222222-2222-2222-2222-222222222222';
  reset role;
  \echo '  -- role actually stuck (expect provider):'
  select role as doctor_role from public.profiles
   where id='22222222-2222-2222-2222-222222222222';

  \echo '  -- and that account now resolves to its listing (expect 1):'
  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  select count(*) as my_listing from public.doctors where user_id = auth.uid();
rollback;

\echo ''
\echo '=== EXPLOIT 19: a non-admin changes someone else''s role (must affect 0 rows) ==='
begin;
  update public.profiles set role='provider' where id='22222222-2222-2222-2222-222222222222';
  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  \echo '  -- a provider promoting another account (expect UPDATE 0):'
  update public.profiles set role='admin'
   where id='11111111-1111-1111-1111-111111111111';
  \echo '  -- and promoting themselves (expect ERROR: role pin in profiles_update_own):'
  update public.profiles set role='admin'
   where id='22222222-2222-2222-2222-222222222222';
rollback;

\echo ''
\echo '=== POSITIVE 12: two opted-in patients open a thread and both read it ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  select id as pb from public.patients
   where owner_user_id='22222222-2222-2222-2222-222222222222' \gset
  update public.patients set peer_chat_enabled = true where id in (:'pa', :'pb');

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  select public.open_peer_conversation(:'pb') as cid \gset
  insert into public.peer_messages (conversation_id, sender_id, body)
  values (:'cid','11111111-1111-1111-1111-111111111111','สวัสดีครับ เป็นยังไงบ้าง');

  \echo '  -- opening it again continues the same thread (expect 1 row total):'
  select public.open_peer_conversation(:'pb') as reopened \gset
  select count(*) as threads from public.peer_conversations;

  \echo '  -- the other side sees the thread and the message (expect 1 and 1):'
  select public.as_user('22222222-2222-2222-2222-222222222222');
  select count(*) as their_threads from public.peer_threads();
  select count(*) as their_msgs from public.peer_messages where conversation_id = :'cid';

  \echo '  -- and the thread names the counterpart, not themselves:'
  select other_name from public.peer_threads();

  \echo '  -- last_message_at is bumped by the trigger, not by the client.'
  \echo '  -- Timestamped explicitly: now() is frozen for the whole'
  \echo '  -- transaction, so a default-timestamped row cannot show movement.'
  select public.as_user('11111111-1111-1111-1111-111111111111');
  insert into public.peer_messages (conversation_id, sender_id, body, created_at)
  values (:'cid','11111111-1111-1111-1111-111111111111','ตอบกลับ', now() + interval '5 min');
  reset role;
  \echo '  -- expect t:'
  select (last_message_at = now() + interval '5 min') as touched
    from public.peer_conversations where id = :'cid';

  \echo '  -- and the client still cannot write it directly (expect UPDATE 0):'
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  update public.peer_conversations set last_message_at = now() + interval '99 days'
   where id = :'cid';
rollback;

\echo ''
\echo '=== EXPLOIT 20: an uninvolved patient reads a peer thread (must return 0) ==='
begin;
  insert into auth.users (id, email)
  values ('99999999-9999-9999-9999-999999999999','nosy@test.com');
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  select id as pb from public.patients
   where owner_user_id='22222222-2222-2222-2222-222222222222' \gset
  update public.patients set peer_chat_enabled = true where id in (:'pa', :'pb');

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  select public.open_peer_conversation(:'pb') as cid \gset
  insert into public.peer_messages (conversation_id, sender_id, body)
  values (:'cid','11111111-1111-1111-1111-111111111111','เรื่องส่วนตัว');

  \echo '  -- a third patient (expect 0 threads, 0 messages):'
  select public.as_user('99999999-9999-9999-9999-999999999999');
  select count(*) as threads from public.peer_conversations;
  select count(*) as msgs from public.peer_messages;
rollback;

\echo ''
\echo '=== EXPLOIT 21: a doctor reads their patient''s private peer thread (must return 0) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  select id as pb from public.patients
   where owner_user_id='22222222-2222-2222-2222-222222222222' \gset
  update public.patients set peer_chat_enabled = true where id in (:'pa', :'pb');
  -- A fully privileged clinician: provider role AND a linked doctor listing,
  -- i.e. someone who can read the whole caseload.
  insert into auth.users (id, email)
  values ('88888888-8888-8888-8888-888888888888','doc@test.com');
  update public.profiles set role='provider'
   where id='88888888-8888-8888-8888-888888888888';
  insert into public.doctors (id, user_id, name, specialty)
  values ('eeeeeeee-0000-0000-0000-000000000009',
          '88888888-8888-8888-8888-888888888888','หมอ C','อายุรกรรม');

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  select public.open_peer_conversation(:'pb') as cid \gset
  insert into public.peer_messages (conversation_id, sender_id, body)
  values (:'cid','11111111-1111-1111-1111-111111111111','ไม่อยากให้หมอเห็น');

  \echo '  -- can_view_all_patients() is true for them (expect t):'
  select public.as_user('88888888-8888-8888-8888-888888888888');
  select public.can_view_all_patients() as sees_caseload;
  \echo '  -- yet the peer thread stays private (expect 0 threads, 0 messages):'
  select count(*) as threads from public.peer_conversations;
  select count(*) as msgs from public.peer_messages;
rollback;

\echo ''
\echo '=== EXPLOIT 22: messaging someone who never opted in (must ERROR) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  select id as pb from public.patients
   where owner_user_id='22222222-2222-2222-2222-222222222222' \gset
  -- Only the caller opts in; the target never did.
  update public.patients set peer_chat_enabled = true where id = :'pa';

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  \echo '  -- expect ERROR: both participants must enable peer chat';
  select public.open_peer_conversation(:'pb');
rollback;

\echo ''
\echo '=== EXPLOIT 23: bypassing the RPC by inserting a thread directly (must FAIL) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  select id as pb from public.patients
   where owner_user_id='22222222-2222-2222-2222-222222222222' \gset
  update public.patients set peer_chat_enabled = true where id = :'pa';

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  \echo '  -- no INSERT policy on peer_conversations, so this cannot pass:'
  insert into public.peer_conversations (patient_low, patient_high)
  values (least(:'pa'::uuid, :'pb'::uuid), greatest(:'pa'::uuid, :'pb'::uuid));
rollback;

\echo ''
\echo '=== EXPLOIT 24: the directory is closed to a patient who has not opted in ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  select id as pb from public.patients
   where owner_user_id='22222222-2222-2222-2222-222222222222' \gset
  update public.patients set peer_chat_enabled = true where id = :'pb';

  set local role authenticated;
  \echo '  -- lurker has not opted in, so sees nobody (expect 0):'
  select public.as_user('11111111-1111-1111-1111-111111111111');
  select count(*) as listed from public.peer_directory();

  \echo '  -- after opting in they see the other opted-in patient (expect 1):'
  reset role;
  update public.patients set peer_chat_enabled = true where id = :'pa';
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  select count(*) as listed from public.peer_directory();

  \echo '  -- and never themselves:'
  select count(*) as self_listed from public.peer_directory()
   where patient_id = :'pa';
rollback;

\echo ''
\echo '=== EXPLOIT 25: posting into a peer thread under the other person''s name (must FAIL) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  select id as pb from public.patients
   where owner_user_id='22222222-2222-2222-2222-222222222222' \gset
  update public.patients set peer_chat_enabled = true where id in (:'pa', :'pb');

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  select public.open_peer_conversation(:'pb') as cid \gset
  \echo '  -- sender_id is pinned to auth.uid():'
  insert into public.peer_messages (conversation_id, sender_id, body)
  values (:'cid','22222222-2222-2222-2222-222222222222','ฉันบอกเองว่าหยุดยาได้');
rollback;

\echo ''
\echo '=== EXPLOIT 26: editing or deleting a sent peer message (must affect 0 rows) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  select id as pb from public.patients
   where owner_user_id='22222222-2222-2222-2222-222222222222' \gset
  update public.patients set peer_chat_enabled = true where id in (:'pa', :'pb');

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  select public.open_peer_conversation(:'pb') as cid \gset
  insert into public.peer_messages (conversation_id, sender_id, body)
  values (:'cid','11111111-1111-1111-1111-111111111111','ข้อความเดิม');
  \echo '  -- expect UPDATE 0 then DELETE 0:'
  update public.peer_messages set body='ข้อความที่ถูกแก้' where conversation_id = :'cid';
  delete from public.peer_messages where conversation_id = :'cid';
rollback;

\echo ''
\echo '=== POSITIVE 13: a doctor opens a thread with a patient and both can read it ==='
begin;
  select id as pid from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  insert into auth.users (id, email)
  values ('77777777-7777-7777-7777-777777777777','doc-init@test.com');
  insert into public.doctors (id, user_id, name, specialty)
  values ('eeeeeeee-0000-0000-0000-00000000000a',
          '77777777-7777-7777-7777-777777777777','หมอ D','อายุรกรรม');

  set local role authenticated;
  select public.as_user('77777777-7777-7777-7777-777777777777');
  \echo '  -- doctor starts the conversation (expect INSERT 0 1):'
  insert into public.conversations (id, patient_id, doctor_id)
  values ('ffffffff-0000-0000-0000-00000000000a', :'pid',
          'eeeeeeee-0000-0000-0000-00000000000a');
  insert into public.messages (conversation_id, sender_id, body)
  values ('ffffffff-0000-0000-0000-00000000000a',
          '77777777-7777-7777-7777-777777777777','ผลตรวจออกแล้ว สะดวกคุยไหมครับ');

  \echo '  -- the patient sees it without having started it (expect 1 and 1):'
  select public.as_user('11111111-1111-1111-1111-111111111111');
  select count(*) as threads from public.conversations
   where id='ffffffff-0000-0000-0000-00000000000a';
  select count(*) as msgs from public.messages
   where conversation_id='ffffffff-0000-0000-0000-00000000000a';
rollback;

\echo ''
\echo '=== EXPLOIT 27: a doctor opens a thread under another doctor''s name (must FAIL) ==='
begin;
  select id as pid from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  insert into auth.users (id, email)
  values ('77777777-7777-7777-7777-777777777777','doc-init@test.com');
  insert into public.doctors (id, user_id, name, specialty) values
    ('eeeeeeee-0000-0000-0000-00000000000a',
     '77777777-7777-7777-7777-777777777777','หมอ D','อายุรกรรม'),
    ('eeeeeeee-0000-0000-0000-00000000000b', null,'หมอ E','ผิวหนัง');

  set local role authenticated;
  select public.as_user('77777777-7777-7777-7777-777777777777');
  \echo '  -- naming a listing that is not theirs:'
  insert into public.conversations (patient_id, doctor_id)
  values (:'pid','eeeeeeee-0000-0000-0000-00000000000b');
rollback;

\echo ''
\echo '=== EXPLOIT 28: a patient opens a thread as if they were a doctor (must FAIL) ==='
begin;
  select id as other from public.patients
   where owner_user_id='22222222-2222-2222-2222-222222222222' \gset
  insert into public.doctors (id, user_id, name, specialty)
  values ('eeeeeeee-0000-0000-0000-00000000000c', null,'หมอ F','หัวใจ');

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  \echo '  -- a thread on someone else''s patient record, no listing of their own:'
  insert into public.conversations (patient_id, doctor_id)
  values (:'other','eeeeeeee-0000-0000-0000-00000000000c');
rollback;

\echo ''
\echo '=== POSITIVE 14: a doctor reads the question queue and answers one ==='
begin;
  select id as pid from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  insert into auth.users (id, email)
  values ('66666666-6666-6666-6666-666666666666','answerer@test.com');
  insert into public.doctors (id, user_id, name, specialty)
  values ('eeeeeeee-0000-0000-0000-00000000000d',
          '66666666-6666-6666-6666-666666666666','หมอ G','อายุรกรรม');

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  insert into public.health_questions (id, patient_id, asked_by, topic_key, question)
  values ('cccccccc-0000-0000-0000-000000000001', :'pid',
          '11111111-1111-1111-1111-111111111111','diabetes','กินยาก่อนหรือหลังอาหารครับ');

  \echo '  -- the doctor sees it even with no link to this patient (expect 1):'
  select public.as_user('66666666-6666-6666-6666-666666666666');
  select count(*) as in_queue from public.health_questions where status='pending';

  \echo '  -- and answers it (expect UPDATE 1):'
  update public.health_questions
     set answer='หลังอาหารครับ', status='answered'
   where id='cccccccc-0000-0000-0000-000000000001';

  \echo '  -- the trigger signed it with their own listing, and stamped a time:'
  reset role;
  select answered_by = 'eeeeeeee-0000-0000-0000-00000000000d' as signed_correctly,
         answered_at is not null as stamped,
         question = 'กินยาก่อนหรือหลังอาหารครับ' as question_intact
    from public.health_questions where id='cccccccc-0000-0000-0000-000000000001';

  \echo '  -- and the patient can read the answer (expect 1):'
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  select count(*) as answered_visible from public.health_questions
   where id='cccccccc-0000-0000-0000-000000000001' and status='answered';
rollback;

\echo ''
\echo '=== EXPLOIT 29: a doctor rewrites the question or signs it as someone else ==='
begin;
  select id as pid from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  insert into auth.users (id, email)
  values ('66666666-6666-6666-6666-666666666666','answerer@test.com');
  insert into public.doctors (id, user_id, name, specialty) values
    ('eeeeeeee-0000-0000-0000-00000000000d',
     '66666666-6666-6666-6666-666666666666','หมอ G','อายุรกรรม'),
    ('eeeeeeee-0000-0000-0000-00000000000e', null,'หมอ H','ผิวหนัง');
  insert into public.health_questions (id, patient_id, asked_by, topic_key, question)
  values ('cccccccc-0000-0000-0000-000000000002', :'pid',
          '11111111-1111-1111-1111-111111111111','diabetes','คำถามเดิม');

  set local role authenticated;
  select public.as_user('66666666-6666-6666-6666-666666666666');
  update public.health_questions
     set question='คำถามที่ถูกแก้',
         answer='ตอบแล้ว',
         answered_by='eeeeeeee-0000-0000-0000-00000000000e'
   where id='cccccccc-0000-0000-0000-000000000002';

  reset role;
  \echo '  -- expect the original question, and their own id not หมอ H''s:'
  select question,
         answered_by = 'eeeeeeee-0000-0000-0000-00000000000d' as signed_as_self
    from public.health_questions where id='cccccccc-0000-0000-0000-000000000002';
rollback;

\echo ''
\echo '=== EXPLOIT 30: an ordinary patient reads the whole question queue (must be 1) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  select id as pb from public.patients
   where owner_user_id='22222222-2222-2222-2222-222222222222' \gset
  insert into public.health_questions (patient_id, asked_by, topic_key, question) values
    (:'pa','11111111-1111-1111-1111-111111111111','diabetes','ของ A'),
    (:'pb','22222222-2222-2222-2222-222222222222','kidney','ของ B');

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  \echo '  -- only their own (expect 1):'
  select count(*) as visible from public.health_questions;
  \echo '  -- and answering their own is refused by the trigger (answer stays null):'
  update public.health_questions set answer='ฉันตอบเอง', status='answered'
   where patient_id = :'pa';
  reset role;
  select count(*) as self_answered from public.health_questions
   where patient_id = :'pa' and answer is not null;
rollback;

\echo ''
\echo '=== EXPLOIT 31: patient B rewrites patient A''s profile name and phone (must not) ==='
begin;
  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  update public.profiles
     set first_name='ถูก', last_name='แก้', phone='0999999999',
         profile_completed_at=now()
   where id='11111111-1111-1111-1111-111111111111';

  reset role;
  \echo '  -- expect all null: nothing of A''s was written:'
  select first_name, last_name, phone, profile_completed_at
    from public.profiles where id='11111111-1111-1111-1111-111111111111';
rollback;

\echo ''
\echo '=== EXPLOIT 32: the profile form is not a way to become an admin (role must stay patient) ==='
begin;
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  -- The real form sends exactly these columns; role is smuggled in alongside
  -- them, which is what a hand-rolled PostgREST call could do just as easily.
  update public.profiles
     set first_name='สมชาย', last_name='ใจดี', phone='0812345678',
         profile_completed_at=now(), role='admin'
   where id='11111111-1111-1111-1111-111111111111';

  reset role;
  \echo '  -- expect role=patient, and the name fields unwritten too (the whole';
  \echo '  -- statement is refused, not just the role part):';
  select role, first_name, last_name from public.profiles
   where id='11111111-1111-1111-1111-111111111111';
rollback;

\echo ''
\echo '=== EXPLOIT 33: a patient completes their own profile (must succeed) ==='
begin;
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  update public.profiles
     set first_name='สมหญิง', last_name='รักดี', name='สมหญิง รักดี',
         phone='0812345678', profile_completed_at=now()
   where id='11111111-1111-1111-1111-111111111111';

  select id as pid from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  update public.patients
     set birth_date='1990-05-20', gender='female', name='สมหญิง รักดี'
   where id = :'pid';

  reset role;
  \echo '  -- expect the values above, proving the form is not blocked by RLS:'
  select p.first_name, p.last_name, p.phone,
         p.profile_completed_at is not null as completed
    from public.profiles p where p.id='11111111-1111-1111-1111-111111111111';
  select birth_date, gender from public.patients where id = :'pid';
rollback;

\echo ''
\echo '=== EXPLOIT 34: gender outside the three offered options is refused ==='
begin;
  select id as pid from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  \echo '  -- expect a check-constraint violation, not a stored row:'
  savepoint before_bad_gender;
  update public.patients set gender='อื่นๆ' where id = :'pid';
  rollback to savepoint before_bad_gender;
  reset role;
rollback;

\echo ''
\echo '=== EXPLOIT 35: patient B edits patient A''s allergy list (must not) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  update public.patients
     set drug_allergies = array['เพนิซิลลิน'], blood_type='O+'
   where id = :'pa';

  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  -- Clearing someone's allergy list is the dangerous direction: a prescriber
  -- reading the record would then see nothing rather than a wrong entry.
  update public.patients
     set drug_allergies = '{}', blood_type='A+'
   where id = :'pa';

  reset role;
  \echo '  -- expect the allergy still there and blood type unchanged:'
  select drug_allergies, blood_type from public.patients where id = :'pa';
rollback;

\echo ''
\echo '=== EXPLOIT 36: a patient records their own health details (must succeed) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  update public.patients
     set primary_condition='เบาหวาน',
         drug_allergies = array['เพนิซิลลิน','แอสไพริน'],
         blood_type='B+', weight_kg=65.5, height_cm=170
   where id = :'pa';
  reset role;
  \echo '  -- expect the values above:'
  select primary_condition, drug_allergies, blood_type, weight_kg, height_cm
    from public.patients where id = :'pa';
rollback;

\echo ''
\echo '=== EXPLOIT 37: out-of-range measurements and a bogus blood type are refused ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');

  \echo '  -- 700 kg (a slipped decimal point) must be refused:'
  savepoint s1;
  update public.patients set weight_kg=700 where id = :'pa';
  rollback to savepoint s1;

  \echo '  -- 900 cm must be refused:'
  savepoint s2;
  update public.patients set height_cm=900 where id = :'pa';
  rollback to savepoint s2;

  \echo '  -- a blood type that is not one of the eight must be refused:'
  savepoint s3;
  update public.patients set blood_type='C+' where id = :'pa';
  rollback to savepoint s3;

  reset role;
rollback;

\echo ''
\echo '=== CONTROL 38: a doctor can read a patient''s allergies (must return them) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  update public.patients set drug_allergies = array['เพนิซิลลิน'] where id = :'pa';
  insert into auth.users (id, email)
    values ('77777777-7777-7777-7777-777777777777','doc@test.com');
  update public.profiles set role='provider'
   where id='77777777-7777-7777-7777-777777777777';

  set local role authenticated;
  select public.as_user('77777777-7777-7777-7777-777777777777');
  \echo '  -- expect the allergy: a prescriber who cannot see it is the point';
  \echo '  -- of storing it at all:';
  select drug_allergies from public.patients where id = :'pa';
  reset role;
rollback;

\echo ''
\echo '=== CONTROL 39: a patient adds their own medication and times (must succeed) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');

  insert into public.prescriptions
    (patient_id, medication_name, dosage, frequency, start_date, source)
  values (:'pa','พาราเซตามอล','500 mg','วันละ 3 ครั้ง', current_date, 'self');

  select id as rx from public.prescriptions
   where patient_id = :'pa' and medication_name='พาราเซตามอล' \gset
  insert into public.dose_schedules (prescription_id, scheduled_time)
  values (:'rx','08:00'), (:'rx','20:00');

  \echo '  -- expect 1 prescription and 2 times:'
  select count(*) as times from public.dose_schedules where prescription_id = :'rx';
  reset role;
  \echo '  -- and created_by stamped to the patient, not left to the client:'
  select source, created_by = '11111111-1111-1111-1111-111111111111' as stamped
    from public.prescriptions where id = :'rx';
rollback;

\echo ''
\echo '=== EXPLOIT 40: a patient edits a prescription a doctor wrote (must not) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  insert into public.prescriptions
    (patient_id, medication_name, dosage, frequency, start_date, source)
  values (:'pa','วาร์ฟาริน','5 mg','วันละครั้ง', current_date, 'clinician');
  select id as rx from public.prescriptions
   where patient_id = :'pa' and medication_name='วาร์ฟาริน' \gset

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  \echo '  -- changing the dose of a doctor''s order must not take:'
  update public.prescriptions set dosage='50 mg' where id = :'rx';
  \echo '  -- nor deleting it:'
  delete from public.prescriptions where id = :'rx';
  reset role;
  \echo '  -- expect the original 5 mg, still present:'
  select medication_name, dosage, source from public.prescriptions where id = :'rx';
rollback;

\echo ''
\echo '=== EXPLOIT 41: a patient relabels their own entry as clinician-written (must not) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  insert into public.prescriptions
    (patient_id, medication_name, dosage, frequency, start_date, source)
  values (:'pa','ยาของฉัน','1 เม็ด','วันละครั้ง', current_date, 'self');
  select id as rx from public.prescriptions
   where patient_id = :'pa' and medication_name='ยาของฉัน' \gset

  update public.prescriptions set source='clinician' where id = :'rx';
  reset role;
  \echo '  -- expect source still self: the trigger pins it after creation:'
  select source from public.prescriptions where id = :'rx';
rollback;

\echo ''
\echo '=== EXPLOIT 42: a patient inserts medication onto someone else''s record (must not) ==='
begin;
  select id as pb from public.patients
   where owner_user_id='22222222-2222-2222-2222-222222222222' \gset
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  \echo '  -- expect an RLS refusal, not a row on B''s chart:'
  savepoint s1;
  insert into public.prescriptions
    (patient_id, medication_name, dosage, frequency, start_date, source)
  values (:'pb','ยาที่ยัดใส่คนอื่น','1 เม็ด','วันละครั้ง', current_date, 'self');
  rollback to savepoint s1;
  reset role;
rollback;

\echo ''
\echo '=== EXPLOIT 43: a patient sets times on a doctor''s prescription (must not) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  insert into public.prescriptions
    (patient_id, medication_name, dosage, frequency, start_date, source)
  values (:'pa','วาร์ฟาริน','5 mg','วันละครั้ง', current_date, 'clinician');
  select id as rx from public.prescriptions
   where patient_id = :'pa' and medication_name='วาร์ฟาริน' \gset

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  \echo '  -- expect an RLS refusal:'
  savepoint s1;
  insert into public.dose_schedules (prescription_id, scheduled_time)
  values (:'rx','03:00');
  rollback to savepoint s1;
  reset role;
rollback;

\echo ''
\echo '=== CONTROL 44: doctor_consult_count นับได้จริง ==='
begin;
  insert into public.doctors (name, specialty) values ('นพ.ทดสอบนับเคส','ทั่วไป');
  select id as d1 from public.doctors where name='นพ.ทดสอบนับเคส' \gset
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  select id as pb from public.patients
   where owner_user_id='22222222-2222-2222-2222-222222222222' \gset
  insert into public.conversations (patient_id, doctor_id) values (:'pa', :'d1')
    on conflict do nothing;
  insert into public.conversations (patient_id, doctor_id) values (:'pb', :'d1')
    on conflict do nothing;
  \echo '  -- expect 2:'
  select public.doctor_consult_count(:'d1'::uuid) as consults;
rollback;

\echo ''
\echo '=== EXPLOIT 45: ผู้ป่วยใช้ฟังก์ชันนับเพื่อดูแชทคนอื่น (ต้องไม่ได้) ==='
begin;
  insert into public.doctors (name, specialty) values ('นพ.ทดสอบนับเคส','ทั่วไป');
  select id as d1 from public.doctors where name='นพ.ทดสอบนับเคส' \gset
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  select id as pb from public.patients
   where owner_user_id='22222222-2222-2222-2222-222222222222' \gset
  insert into public.conversations (patient_id, doctor_id) values (:'pa', :'d1')
    on conflict do nothing;
  insert into public.conversations (patient_id, doctor_id) values (:'pb', :'d1')
    on conflict do nothing;

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  \echo '  -- นับได้ (ตัวเลขรวม ไม่ระบุตัวตน) expect 2:'
  select public.doctor_consult_count(:'d1'::uuid) as consults;
  \echo '  -- แต่ยังอ่านแชทได้แค่ของตัวเอง expect 1 row:'
  select count(*) as visible_threads from public.conversations;
  reset role;
rollback;

\echo ''
\echo '=== CONTROL 46: หมอสั่งยาได้หลังเริ่มสนทนากับผู้ป่วย ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset

  insert into auth.users (id, email)
    values ('33333333-3333-3333-3333-333333333333','rx-doc@test.com');
  update public.profiles set role='provider'
   where id='33333333-3333-3333-3333-333333333333';
  insert into public.doctors (user_id, name, specialty)
  values ('33333333-3333-3333-3333-333333333333','นพ.ทดสอบสั่งยา','ทั่วไป');
  select id as doc from public.doctors
   where user_id='33333333-3333-3333-3333-333333333333' \gset

  \echo '  -- ก่อนมีการสนทนา expect f:'
  set local role authenticated;
  select public.as_user('33333333-3333-3333-3333-333333333333');
  select public.can_manage_patient_care(:'pa'::uuid) as before_chat;
  reset role;

  insert into public.conversations (patient_id, doctor_id) values (:'pa', :'doc');

  \echo '  -- หลังเริ่มสนทนา expect t:'
  set local role authenticated;
  select public.as_user('33333333-3333-3333-3333-333333333333');
  select public.can_manage_patient_care(:'pa'::uuid) as after_chat;

  \echo '  -- และสั่งยาได้จริง expect INSERT 0 1:'
  insert into public.prescriptions
    (patient_id, medication_name, dosage, frequency, start_date, source)
  values (:'pa','ยาที่หมอสั่ง','500 mg','วันละ 3 ครั้ง', current_date, 'clinician');
  reset role;
  select medication_name, source from public.prescriptions
   where patient_id = :'pa' and medication_name='ยาที่หมอสั่ง';
rollback;

\echo ''
\echo '=== EXPLOIT 47: หมอที่ไม่เคยคุยกับผู้ป่วยรายนั้น สั่งยาให้ (ต้องไม่ได้) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  select id as pb from public.patients
   where owner_user_id='22222222-2222-2222-2222-222222222222' \gset

  insert into auth.users (id, email)
    values ('33333333-3333-3333-3333-333333333333','rx-doc@test.com');
  update public.profiles set role='provider'
   where id='33333333-3333-3333-3333-333333333333';
  insert into public.doctors (user_id, name, specialty)
  values ('33333333-3333-3333-3333-333333333333','นพ.ทดสอบสั่งยา','ทั่วไป');
  select id as doc from public.doctors
   where user_id='33333333-3333-3333-3333-333333333333' \gset

  -- คุยกับ A เท่านั้น ไม่เคยคุยกับ B
  insert into public.conversations (patient_id, doctor_id) values (:'pa', :'doc');

  set local role authenticated;
  select public.as_user('33333333-3333-3333-3333-333333333333');
  \echo '  -- ดูแล A ได้ expect t:'
  select public.can_manage_patient_care(:'pa'::uuid) as manages_a;
  \echo '  -- แต่ B ไม่ได้ expect f:'
  select public.can_manage_patient_care(:'pb'::uuid) as manages_b;
  \echo '  -- สั่งยาให้ B expect RLS refusal:'
  savepoint s1;
  insert into public.prescriptions
    (patient_id, medication_name, dosage, frequency, start_date, source)
  values (:'pb','ยาที่ไม่ควรสั่งได้','1 เม็ด','วันละครั้ง', current_date, 'clinician');
  rollback to savepoint s1;
  reset role;
rollback;

\echo ''
\echo '=== EXPLOIT 48: ผู้ป่วยติดป้ายยาตัวเองว่าหมอสั่ง (ต้องไม่ได้) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  \echo '  -- expect RLS refusal:'
  savepoint s1;
  insert into public.prescriptions
    (patient_id, medication_name, dosage, frequency, start_date, source)
  values (:'pa','แอบอ้างว่าหมอสั่ง','1 เม็ด','วันละครั้ง', current_date, 'clinician');
  rollback to savepoint s1;
  reset role;
rollback;

\echo ''
\echo '=== CONTROL 49: หมออ่านประวัติผู้ป่วยได้ครบ (วันเกิด กรุ๊ปเลือด แพ้ยา แพ้อาหาร) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  update public.patients
     set birth_date = '1987-03-12',
         blood_type = 'O+',
         drug_allergies = array['เพนิซิลลิน'],
         food_allergies = array['กุ้ง','ถั่วลิสง'],
         primary_condition = 'เบาหวาน'
   where id = :'pa';

  insert into auth.users (id, email)
    values ('88888888-8888-8888-8888-888888888888','doc2@test.com');
  update public.profiles set role='provider'
   where id='88888888-8888-8888-8888-888888888888';

  set local role authenticated;
  select public.as_user('88888888-8888-8888-8888-888888888888');
  \echo '  -- expect ทุกช่องมีค่า: ประวัติที่หมออ่านไม่ได้ ก็ไม่ต่างจากไม่มี:'
  select birth_date, blood_type, primary_condition,
         drug_allergies, food_allergies
    from public.patients where id = :'pa';
  reset role;
rollback;

\echo ''
\echo '=== EXPLOIT 50: ผู้ใช้ทั่วไป (ไม่ใช่หมอ) อ่านประวัติคนอื่น (ต้องได้ 0 แถว) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  update public.patients set food_allergies = array['กุ้ง'] where id = :'pa';

  set local role authenticated;
  -- ผู้ป่วยอีกคนหนึ่ง ไม่ได้เป็น provider และไม่ได้ถูกมอบสิทธิ์ดูแล
  select public.as_user('22222222-2222-2222-2222-222222222222');
  \echo '  -- expect 0 rows:'
  select name, food_allergies from public.patients where id = :'pa';
  reset role;
rollback;

\echo ''
\echo '=== CONTROL 51: หมอเห็นว่าผู้ป่วยกินยาหรือยัง (ต้องเห็น dose_logs) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset

  insert into public.prescriptions
    (patient_id, medication_name, dosage, frequency, start_date, source)
  values (:'pa','ยาความดัน','1 เม็ด','วันละครั้ง', current_date, 'self')
  returning id as rx \gset
  insert into public.dose_schedules (prescription_id, scheduled_time)
  values (:'rx','08:00') returning id as sch \gset
  insert into public.dose_logs (schedule_id, scheduled_at, actioned_at, status)
  values (:'sch', now(), now(), 'taken');

  insert into auth.users (id, email)
    values ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa','doc3@test.com');
  update public.profiles set role='provider'
   where id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  set local role authenticated;
  select public.as_user('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
  \echo '  -- expect 1 row taken: การติดตามการกินยาคือเหตุผลที่บันทึกมันไว้:'
  select status from public.dose_logs where schedule_id = :'sch';
  reset role;
rollback;

\echo ''
\echo '=== EXPLOIT 52: ผู้ป่วยคนอื่นอ่านบันทึกการกินยาของคนนี้ (ต้องได้ 0 แถว) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset

  insert into public.prescriptions
    (patient_id, medication_name, dosage, frequency, start_date, source)
  values (:'pa','ยาความดัน','1 เม็ด','วันละครั้ง', current_date, 'self')
  returning id as rx \gset
  insert into public.dose_schedules (prescription_id, scheduled_time)
  values (:'rx','08:00') returning id as sch \gset
  insert into public.dose_logs (schedule_id, scheduled_at, actioned_at, status)
  values (:'sch', now(), now(), 'taken');

  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  \echo '  -- expect 0 rows:'
  select status from public.dose_logs where schedule_id = :'sch';
  reset role;
rollback;

\echo ''
\echo '=== CONTROL 53: ผู้ป่วยเพิกถอนสิทธิ์หมอได้เอง (ต้องได้) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset

  insert into auth.users (id, email)
    values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','revoke-doc@test.com');
  update public.profiles set role='provider'
   where id='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  insert into public.doctors (user_id, name, specialty)
  values ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb','นพ.ทดสอบเพิกถอน','ทั่วไป')
  returning id as doc \gset
  insert into public.conversations (patient_id, doctor_id) values (:'pa', :'doc');

  set local role authenticated;
  select public.as_user('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
  \echo '  -- หมอดูแลได้ก่อนเพิกถอน expect t:'
  select public.can_manage_patient_care(:'pa'::uuid) as before_revoke;
  reset role;

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  \echo '  -- ผู้ป่วยเห็นว่าใครมีสิทธิ์ expect 1 row:'
  select role, status from public.patient_links where patient_id = :'pa';
  \echo '  -- และเพิกถอนได้ expect UPDATE 1:'
  update public.patient_links set status = 'revoked' where patient_id = :'pa';
  reset role;

  set local role authenticated;
  select public.as_user('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');
  \echo '  -- หลังเพิกถอน ดูแลไม่ได้ expect f:'
  select public.can_manage_patient_care(:'pa'::uuid) as after_revoke;
  \echo '  -- และสั่งยาไม่ได้ expect RLS refusal:'
  savepoint s1;
  insert into public.prescriptions
    (patient_id, medication_name, dosage, frequency, start_date, source)
  values (:'pa','ยาหลังถูกเพิกถอน','1 เม็ด','วันละครั้ง', current_date, 'clinician');
  rollback to savepoint s1;
  reset role;
rollback;

\echo ''
\echo '=== EXPLOIT 54: ผู้ป่วยอีกคนแก้สิทธิ์ในประวัติคนอื่น (ต้องไม่ได้) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  insert into public.patient_links (patient_id, user_id, role, status)
  values (:'pa','22222222-2222-2222-2222-222222222222','provider','revoked');

  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  \echo '  -- แก้สถานะของตัวเองในประวัติคนอื่นไม่ได้ expect UPDATE 0:'
  update public.patient_links set status = 'active'
   where patient_id = :'pa' and user_id = '22222222-2222-2222-2222-222222222222';
  \echo '  -- และเพิ่มสิทธิ์ใหม่ให้ตัวเองไม่ได้ expect RLS refusal:'
  savepoint s1;
  insert into public.patient_links (patient_id, user_id, role, status)
  values (:'pa','99999999-9999-9999-9999-999999999999','provider','active');
  rollback to savepoint s1;
  reset role;
rollback;

\echo ''
\echo '=== CONTROL 55: หมอที่ดูแลอยู่ หยุดยาและลบยาที่สั่งไว้ได้ ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset

  insert into auth.users (id, email)
    values ('cccccccc-cccc-cccc-cccc-cccccccccccc','stop-doc@test.com');
  update public.profiles set role='provider'
   where id='cccccccc-cccc-cccc-cccc-cccccccccccc';
  insert into public.doctors (user_id, name, specialty)
  values ('cccccccc-cccc-cccc-cccc-cccccccccccc','นพ.ทดสอบหยุดยา','ทั่วไป')
  returning id as doc \gset
  insert into public.conversations (patient_id, doctor_id) values (:'pa', :'doc');

  set local role authenticated;
  select public.as_user('cccccccc-cccc-cccc-cccc-cccccccccccc');
  insert into public.prescriptions
    (patient_id, medication_name, dosage, frequency, start_date, source)
  values (:'pa','ยาที่จะหยุด','1 เม็ด','วันละครั้ง', current_date, 'clinician')
  returning id as rx \gset

  \echo '  -- หยุดยา (ใส่ end_date) expect UPDATE 1:'
  update public.prescriptions set end_date = current_date where id = :'rx';
  \echo '  -- ลบยาที่สั่งผิด expect DELETE 1:'
  delete from public.prescriptions where id = :'rx';
  reset role;
rollback;

\echo ''
\echo '=== EXPLOIT 56: ผู้ป่วยหยุด/ลบยาที่หมอสั่ง (ต้องไม่ได้) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  insert into public.prescriptions
    (patient_id, medication_name, dosage, frequency, start_date, source)
  values (:'pa','ยาที่หมอสั่ง','1 เม็ด','วันละครั้ง', current_date, 'clinician')
  returning id as rx \gset

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  \echo '  -- ผู้ป่วยหยุดยาของหมอเองไม่ได้ expect UPDATE 0:'
  update public.prescriptions set end_date = current_date where id = :'rx';
  \echo '  -- และลบไม่ได้ expect DELETE 0:'
  delete from public.prescriptions where id = :'rx';
  reset role;
rollback;

\echo ''
\echo '=== CONTROL 57: จุดแดง — ข้อความใหม่ทำให้ฝั่งที่ไม่ได้ส่งเห็นว่ายังไม่อ่าน ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset

  insert into auth.users (id, email)
    values ('dddddddd-dddd-dddd-dddd-dddddddddddd','unread-doc@test.com');
  update public.profiles set role='provider'
   where id='dddddddd-dddd-dddd-dddd-dddddddddddd';
  insert into public.doctors (user_id, name, specialty)
  values ('dddddddd-dddd-dddd-dddd-dddddddddddd','นพ.ทดสอบจุดแดง','ทั่วไป')
  returning id as doc \gset
  insert into public.conversations (patient_id, doctor_id) values (:'pa', :'doc')
  returning id as conv \gset

  set local role authenticated;
  select public.as_user('dddddddd-dddd-dddd-dddd-dddddddddddd');
  -- created_at ระบุเอง เพราะ now() ในทรานแซกชันเดียวไม่เดิน เวลาจะเท่ากันเป๊ะ
  -- แล้วเงื่อนไข > กลายเป็นเท็จทั้งที่ควรเป็นจริง
  insert into public.messages (conversation_id, sender_id, body, created_at)
  values (:'conv','dddddddd-dddd-dddd-dddd-dddddddddddd','สวัสดีครับ',
          now() - interval '10 minutes');
  reset role;

  \echo '  -- หมอส่ง: ฝั่งหมออ่านแล้ว (t) ฝั่งผู้ป่วยยังไม่อ่าน (t = unread):'
  select doctor_read_at = last_message_at as doctor_caught_up,
         patient_read_at is null as patient_unread
    from public.conversations where id = :'conv';

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  \echo '  -- ผู้ป่วยเปิดอ่าน expect UPDATE 1:'
  update public.conversations set patient_read_at = now() - interval '5 minutes'
   where id = :'conv';
  reset role;

  \echo '  -- อ่านแล้วทั้งคู่ expect f (ไม่มีอะไรค้าง):'
  select last_message_at > patient_read_at as patient_unread
    from public.conversations where id = :'conv';

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  insert into public.messages (conversation_id, sender_id, body, created_at)
  values (:'conv','11111111-1111-1111-1111-111111111111','ขอบคุณครับ', now());
  reset role;

  \echo '  -- ผู้ป่วยตอบกลับ: คราวนี้ฝั่งหมอค้าง expect t:'
  select last_message_at > doctor_read_at as doctor_unread,
         last_message_at > patient_read_at as patient_unread
    from public.conversations where id = :'conv';
rollback;

\echo ''
\echo '=== EXPLOIT 58: คนนอกไปเคลียร์จุดแดงของห้องที่ไม่เกี่ยวกับตัวเอง (ต้องไม่ได้) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  insert into auth.users (id, email)
    values ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee','other-doc@test.com');
  update public.profiles set role='provider'
   where id='eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
  insert into public.doctors (user_id, name, specialty)
  values ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee','นพ.ไม่เกี่ยว','ทั่วไป')
  returning id as doc \gset
  insert into public.conversations (patient_id, doctor_id) values (:'pa', :'doc')
  returning id as conv \gset

  set local role authenticated;
  -- ผู้ป่วยอีกคน ไม่ได้อยู่ในห้องนี้เลย
  select public.as_user('22222222-2222-2222-2222-222222222222');
  \echo '  -- เคลียร์จุดแดงห้องคนอื่นไม่ได้ expect UPDATE 0:'
  update public.conversations set patient_read_at = now() where id = :'conv';
  reset role;
rollback;

\echo ''
\echo '=== CONTROL 59: หมอเห็นบันทึกอาการรวมทั้งข้อความที่ผู้ป่วยพิมพ์ ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  insert into public.symptom_logs
    (patient_id, pain_score, category, custom_fields)
  values (:'pa', 3, 'head', '{"note":"ปวดหลังอาหารเที่ยง"}'::jsonb);
  reset role;

  insert into auth.users (id, email)
    values ('ffffffff-ffff-ffff-ffff-ffffffffffff','symptom-doc@test.com');
  update public.profiles set role='provider'
   where id='ffffffff-ffff-ffff-ffff-ffffffffffff';

  set local role authenticated;
  select public.as_user('ffffffff-ffff-ffff-ffff-ffffffffffff');
  \echo '  -- expect หมวด คะแนน และข้อความครบ: บันทึกที่หมออ่านไม่ได้ก็ไม่มีประโยชน์:'
  select category, pain_score, custom_fields->>'note' as note
    from public.symptom_logs where patient_id = :'pa';
  reset role;
rollback;

\echo ''
\echo '=== EXPLOIT 60: ผู้ป่วยอีกคนอ่านบันทึกอาการของคนนี้ (ต้องได้ 0 แถว) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  insert into public.symptom_logs
    (patient_id, pain_score, category, custom_fields)
  values (:'pa', 8, 'stomach', '{"note":"ความลับ"}'::jsonb);
  reset role;

  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  \echo '  -- expect 0 rows:'
  select category, custom_fields->>'note' as note
    from public.symptom_logs where patient_id = :'pa';
  reset role;
rollback;

\echo ''
\echo '=== CONTROL 61: หมอหยุดยาพร้อมระบุว่าหายแล้ว ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset

  insert into auth.users (id, email)
    values ('eeeeeeee-1111-2222-3333-eeeeeeeeeeee','stopdoc@test.com');
  update public.profiles set role='provider'
   where id='eeeeeeee-1111-2222-3333-eeeeeeeeeeee';
  insert into public.doctors (user_id, name, specialty)
    values ('eeeeeeee-1111-2222-3333-eeeeeeeeeeee','หมอหยุดยา','อายุรกรรม');

  -- The doctor gains care of this patient by opening a conversation, which is
  -- what link_doctor_on_conversation() is for.
  insert into public.conversations (patient_id, doctor_id)
    select :'pa', id from public.doctors
     where user_id='eeeeeeee-1111-2222-3333-eeeeeeeeeeee';

  set local role authenticated;
  select public.as_user('eeeeeeee-1111-2222-3333-eeeeeeeeeeee');
  insert into public.prescriptions
    (patient_id, medication_name, dosage, frequency, start_date, source)
  values (:'pa','ยาแก้อักเสบ','1 เม็ด','วันละ 3 ครั้ง', current_date, 'clinician')
  returning id as rx \gset

  update public.prescriptions
     set end_date = current_date - 1, stop_reason = 'recovered'
   where id = :'rx';
  \echo '  -- expect stop_reason = recovered:'
  select medication_name, stop_reason, end_date < current_date as ended
    from public.prescriptions where id = :'rx';
  reset role;
rollback;

\echo ''
\echo '=== EXPLOIT 62: ค่า stop_reason นอกเหนือจากที่กำหนด (ต้อง error) ==='
begin;
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  insert into public.prescriptions
    (patient_id, medication_name, dosage, frequency, start_date, source,
     stop_reason)
  values (:'pa','ยาทดสอบ','1 เม็ด','วันละ 1 ครั้ง', current_date, 'self',
          'cured-by-magic');
  reset role;
rollback;

\echo ''
\echo '=== CONTROL 63: ผู้ป่วยได้รหัสครอบครัวของตัวเอง ==='
begin;
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  \echo '  -- expect รหัส 8 หลัก และเรียกซ้ำได้รหัสเดิม:'
  select length(public.my_family_code()) as len,
         public.my_family_code() = public.my_family_code() as stable_code;
  reset role;
rollback;

\echo ''
\echo '=== EXPLOIT 64: เข้าร่วมด้วยรหัสแล้วอ่านข้อมูลทันที (ต้องได้ 0 แถว ก่อนอนุมัติ) ==='
begin;
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  select public.my_family_code() as fcode \gset
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  insert into public.symptom_logs (patient_id, pain_score, category)
    values (:'pa', 7, 'head');
  reset role;

  -- คนนอกกรอกรหัส: ได้แค่ pending ยังไม่ควรเห็นอะไร
  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  \echo '  -- expect pending:'
  select public.request_family_access(:'fcode') as result;
  \echo '  -- expect 0 rows (ยังไม่อนุมัติ):'
  select category, pain_score from public.symptom_logs where patient_id = :'pa';
  reset role;
rollback;

\echo ''
\echo '=== CONTROL 65: อนุมัติแล้วครอบครัวเห็นข้อมูลได้ ==='
begin;
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  select public.my_family_code() as fcode \gset
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  insert into public.symptom_logs (patient_id, pain_score, category)
    values (:'pa', 7, 'head');
  reset role;

  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  select public.request_family_access(:'fcode');
  reset role;

  -- เจ้าของกดอนุมัติ
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  \echo '  -- expect t (อนุมัติสำเร็จ):'
  select public.set_family_member_status(
    '22222222-2222-2222-2222-222222222222', 'active') as approved;
  reset role;

  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  \echo '  -- expect เห็นอาการ และเห็นชื่อผู้ป่วยในรายการที่ดูแล:'
  select category, pain_score from public.symptom_logs where patient_id = :'pa';
  select count(*) as caring_for from public.my_family_patients();
  reset role;
rollback;

\echo ''
\echo '=== EXPLOIT 66: คนนอกกดอนุมัติตัวเองเข้าครอบครัวคนอื่น (ต้องได้ f) ==='
begin;
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  select public.my_family_code() as fcode \gset
  reset role;

  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  select public.request_family_access(:'fcode');
  \echo '  -- expect f: อนุมัติตัวเองไม่ได้ ต้องเป็นเจ้าของข้อมูลเท่านั้น';
  select public.set_family_member_status(
    '22222222-2222-2222-2222-222222222222', 'active') as self_approved;
  reset role;
rollback;

\echo ''
\echo '=== EXPLOIT 67: ถอนสิทธิ์แล้วยังอ่านได้อยู่ไหม (ต้องได้ 0 แถว) ==='
begin;
  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  select public.my_family_code() as fcode \gset
  select id as pa from public.patients
   where owner_user_id='11111111-1111-1111-1111-111111111111' \gset
  insert into public.symptom_logs (patient_id, pain_score, category)
    values (:'pa', 5, 'stomach');
  reset role;

  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  select public.request_family_access(:'fcode');
  reset role;

  set local role authenticated;
  select public.as_user('11111111-1111-1111-1111-111111111111');
  select public.set_family_member_status(
    '22222222-2222-2222-2222-222222222222', 'active');
  select public.set_family_member_status(
    '22222222-2222-2222-2222-222222222222', 'revoked');
  reset role;

  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  \echo '  -- expect 0 rows:'
  select category from public.symptom_logs where patient_id = :'pa';
  reset role;
rollback;

\echo ''
\echo '=== EXPLOIT 68: กรอกรหัสมั่วเพื่อหาบัญชีคนอื่น (ต้องได้ not_found) ==='
begin;
  set local role authenticated;
  select public.as_user('22222222-2222-2222-2222-222222222222');
  \echo '  -- expect not_found:'
  select public.request_family_access('ZZZZZZZZ') as result;
  reset role;
rollback;
