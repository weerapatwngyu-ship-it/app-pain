-- MedTrack schema for Supabase.
--
-- Run this once in the Supabase dashboard: SQL Editor > New query > paste >
-- Run. It is written to be re-runnable, so running it twice is harmless.
--
-- The app talks to Postgres directly, with no server of its own in between.
-- That makes Row Level Security the ONLY thing standing between one
-- patient's medical records and every other signed-in user, so every table
-- below enables RLS and every policy is written against auth.uid().

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

-- App-side profile for a Supabase auth user. Supabase owns identity
-- (auth.users); this owns role and display fields.
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  name text not null default 'ผู้ใช้ใหม่',
  role text not null default 'patient'
    check (role in ('patient', 'caregiver', 'provider', 'admin')),
  phone text,
  avatar_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.patients (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  birth_date date not null,
  gender text,
  primary_condition text,
  created_at timestamptz not null default now()
);
create index if not exists patients_owner_idx on public.patients (owner_user_id);

-- Given and family name kept apart rather than parsed back out of `name`.
-- Splitting a display name on whitespace guesses wrong on any name with more
-- than two parts, and the form asks for the two separately — storing only the
-- joined string would mean re-opening that form with the fields wrong.
-- `name` stays as the single display value everything else already reads.
alter table public.profiles add column if not exists first_name text;
alter table public.profiles add column if not exists last_name text;

-- Stamped when the user finishes the after-sign-up form. A null here is what
-- sends them to that form, rather than inferring it from placeholder values:
-- the sign-up trigger has to put *something* in patients.birth_date to satisfy
-- NOT NULL, and a real user could genuinely have been born on whatever date
-- was chosen as the placeholder.
alter table public.profiles add column if not exists profile_completed_at timestamptz;

-- The form offers exactly these three, so the column should hold exactly
-- these three. patients_update is necessarily broad enough to let a client
-- send any string here, and without the constraint a typo — or a client
-- built against an older spelling — becomes a row that no screen renders.
-- Existing values outside the set are cleared first so this is re-runnable
-- on a database that already has data in it.
update public.patients
   set gender = null
 where gender is not null
   and gender not in ('female', 'male', 'unspecified');
alter table public.patients drop constraint if exists patients_gender_check;
alter table public.patients add constraint patients_gender_check
  check (gender is null or gender in ('female', 'male', 'unspecified'));

-- Health details the patient enters about themselves.
--
-- Drug allergies are a list rather than one free-text field, because this is
-- the one entry here that exists to be checked against something: "penicillin"
-- sitting in a sentence alongside two other drugs cannot be compared to a
-- prescription, and an allergy that cannot be checked is a note rather than a
-- safeguard. The rest are single values and stay single values —
-- primary_condition already exists above and is what staff see in the
-- caseload list, so it is reused rather than duplicated by a second
-- conditions column.
alter table public.patients
  add column if not exists drug_allergies text[] not null default '{}';
alter table public.patients add column if not exists blood_type text;
alter table public.patients add column if not exists weight_kg numeric(5,2);
alter table public.patients add column if not exists height_cm numeric(5,2);

-- patients_update has to be broad enough to let the owner write these, which
-- means the client picks the values — so the bounds live here, where a client
-- cannot skip them. The ranges are wide on purpose: they are there to catch a
-- misread unit or a slipped decimal point (70 kg entered as 700), not to
-- judge whether a body is plausible.
alter table public.patients drop constraint if exists patients_blood_type_check;
alter table public.patients add constraint patients_blood_type_check
  check (blood_type is null or blood_type in
    ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'));

alter table public.patients drop constraint if exists patients_weight_check;
alter table public.patients add constraint patients_weight_check
  check (weight_kg is null or (weight_kg > 0 and weight_kg <= 500));

alter table public.patients drop constraint if exists patients_height_check;
alter table public.patients add constraint patients_height_check
  check (height_cm is null or (height_cm > 0 and height_cm <= 300));


-- Grants a caregiver access to someone else's patient record.
create table if not exists public.patient_links (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'caregiver' check (role in ('caregiver', 'provider')),
  status text not null default 'pending' check (status in ('pending', 'active', 'revoked')),
  created_at timestamptz not null default now(),
  unique (patient_id, user_id)
);
create index if not exists patient_links_user_idx on public.patient_links (user_id, status);

create table if not exists public.prescriptions (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients (id) on delete cascade,
  medication_name text not null,
  dosage text not null,
  frequency text not null,
  start_date date not null,
  end_date date,
  created_at timestamptz not null default now()
);
create index if not exists prescriptions_patient_idx on public.prescriptions (patient_id);

-- Who entered a medication.
--
-- Until now only clinical staff could write prescriptions, and no screen ever
-- did — so the table stayed empty and every patient's schedule was blank
-- forever. Patients can now add their own, which raises the question the
-- policies below answer: a patient must not be able to quietly edit an order a
-- doctor wrote. Marking the origin is what makes those two cases separable.
--
-- The default is 'clinician' so rows that already exist keep the meaning they
-- were written with.
alter table public.prescriptions
  add column if not exists source text not null default 'clinician';
alter table public.prescriptions drop constraint if exists prescriptions_source_check;
alter table public.prescriptions add constraint prescriptions_source_check
  check (source in ('self', 'clinician'));

alter table public.prescriptions
  add column if not exists created_by uuid references auth.users (id);

create table if not exists public.dose_schedules (
  id uuid primary key default gen_random_uuid(),
  prescription_id uuid not null references public.prescriptions (id) on delete cascade,
  scheduled_time time not null,
  is_prn boolean not null default false
);
create index if not exists dose_schedules_prescription_idx
  on public.dose_schedules (prescription_id);

create table if not exists public.dose_logs (
  id uuid primary key default gen_random_uuid(),
  schedule_id uuid not null references public.dose_schedules (id) on delete cascade,
  scheduled_at timestamptz not null,
  actioned_at timestamptz default now(),
  status text not null check (status in ('taken', 'skipped', 'missed'))
);
create index if not exists dose_logs_schedule_idx on public.dose_logs (schedule_id);

create table if not exists public.symptom_logs (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients (id) on delete cascade,
  recorded_at timestamptz not null default now(),
  pain_score int check (pain_score between 0 and 10),
  category text check (
    category in ('head', 'stomach', 'skin', 'respiratory', 'joint', 'other')
  ),
  custom_fields jsonb
);
create index if not exists symptom_logs_patient_idx
  on public.symptom_logs (patient_id, recorded_at desc);

create table if not exists public.alerts (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients (id) on delete cascade,
  severity text not null check (severity in ('normal', 'watch', 'critical')),
  status text not null default 'open' check (status in ('open', 'acknowledged')),
  message text,
  created_at timestamptz not null default now()
);
create index if not exists alerts_patient_idx on public.alerts (patient_id, created_at desc);

-- Shared directory, not per-patient data.
--
-- user_id links the listing to a real account so the doctor can sign in and
-- answer. It stays nullable: a directory entry may exist before (or without)
-- an account, and deleting the account leaves the listing rather than
-- cascading away a doctor patients have already been messaging.
create table if not exists public.doctors (
  id uuid primary key default gen_random_uuid(),
  user_id uuid unique references auth.users (id) on delete set null,
  name text not null,
  specialty text not null,
  bio text,
  photo_url text,
  created_at timestamptz not null default now()
);

-- Existing installs predate user_id; adding it here keeps schema.sql the one
-- file to run, rather than needing a separate migration.
alter table public.doctors
  add column if not exists user_id uuid unique references auth.users (id) on delete set null;

-- A patient's question about a health topic, plus the reply once staff answer
-- it. Deliberately not a chat: the doctors table above is a directory, not
-- accounts — no doctor can sign in yet — so this records the question durably
-- and shows the patient it is waiting, rather than implying someone is on the
-- other end in real time.
create table if not exists public.health_questions (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients (id) on delete cascade,
  asked_by uuid not null references auth.users (id) on delete cascade,
  -- Matches HealthTopic.key in the app. Free text on purpose: adding a topic
  -- to the catalog should not need a migration.
  topic_key text not null,
  question text not null,
  status text not null default 'pending'
    check (status in ('pending', 'answered', 'closed')),
  answer text,
  answered_by uuid references public.doctors (id) on delete set null,
  answered_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists health_questions_patient_idx
  on public.health_questions (patient_id, created_at desc);

-- One ongoing thread between a patient and a doctor. Distinct from
-- health_questions, which is a one-shot question about a topic that any staff
-- member may answer — this is addressed to a specific doctor and stays open.
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references public.patients (id) on delete cascade,
  doctor_id uuid not null references public.doctors (id) on delete cascade,
  created_at timestamptz not null default now(),
  -- Denormalised so the thread list can sort without touching messages.
  last_message_at timestamptz not null default now(),
  -- One thread per pair: reopening a chat should continue it, not fork it.
  unique (patient_id, doctor_id)
);
create index if not exists conversations_patient_idx
  on public.conversations (patient_id, last_message_at desc);
create index if not exists conversations_doctor_idx
  on public.conversations (doctor_id, last_message_at desc);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null references auth.users (id) on delete cascade,
  body text not null check (length(trim(body)) > 0),
  created_at timestamptz not null default now()
);
create index if not exists messages_conversation_idx
  on public.messages (conversation_id, created_at);

-- ---------------------------------------------------------------------------
-- Helpers
--
-- SECURITY DEFINER so they can read patients/patient_links while evaluating
-- a policy ON those same tables — a plain query there would re-enter RLS and
-- recurse. `search_path = ''` forces fully-qualified names so the definer
-- rights can't be redirected by a caller-controlled search path.
-- ---------------------------------------------------------------------------

create or replace function public.can_access_patient(target_patient_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.patients p
    where p.id = target_patient_id and p.owner_user_id = auth.uid()
  ) or exists (
    select 1 from public.patient_links l
    where l.patient_id = target_patient_id
      and l.user_id = auth.uid()
      and l.status = 'active'
  );
$$;

-- A dose log names a schedule, not a patient; walk back to the owner.
create or replace function public.patient_id_for_schedule(target_schedule_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.patient_id
  from public.dose_schedules s
  join public.prescriptions p on p.id = s.prescription_id
  where s.id = target_schedule_id;
$$;

create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('provider', 'admin')
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles where id = auth.uid() and role = 'admin'
  );
$$;

-- The doctor listing this account signs in as, or null for everyone else.
-- Being listed in `doctors` is what makes an account a doctor for messaging
-- purposes; profiles.role only decides which shell the app shows.
create or replace function public.current_doctor_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select id from public.doctors where user_id = auth.uid();
$$;

-- A thread is readable by the patient side (owner or active caregiver link)
-- and by the one doctor it is addressed to — nobody else, including other
-- doctors.
create or replace function public.can_access_conversation(target_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.conversations c
    where c.id = target_conversation_id
      and (
        public.can_access_patient(c.patient_id)
        or c.doctor_id = public.current_doctor_id()
      )
  );
$$;

-- The caller's stored role, read past RLS so an UPDATE policy on profiles can
-- compare the incoming row against it without recursing into itself.
create or replace function public.current_profile_role()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select role from public.profiles where id = auth.uid();
$$;

-- Same idea for ownership: lets patients_update pin owner_user_id to what is
-- already stored instead of whatever the client sent.
create or replace function public.patient_owner(target_patient_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select owner_user_id from public.patients where id = target_patient_id;
$$;

-- A dose schedule names a prescription, not a patient. Unlike
-- patient_id_for_schedule this resolves from the prescription_id column, so it
-- also works on INSERT, when the schedule row does not exist yet.
create or replace function public.patient_id_for_prescription(target_prescription_id uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select patient_id from public.prescriptions where id = target_prescription_id;
$$;

-- Who may prescribe for a given patient. is_staff() alone is not enough: it
-- says "this account is a provider somewhere", not "this account treats THIS
-- patient", which would let any provider rewrite every patient's medication.
-- Providers reach a patient only through an active provider link; admins are
-- deliberately global, and cannot be self-assigned (see profiles_update_own).
--
-- Note the deliberate asymmetry: an admin may write care records for any
-- patient, but patients_select still only exposes owned/linked rows, so an
-- admin cannot browse the patient list. Any future admin console therefore
-- needs its own read path (a service-role backend or an explicit policy)
-- rather than assuming this function's reach applies to reads too.
create or replace function public.can_manage_patient_care(target_patient_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  ) or exists (
    select 1
    from public.patient_links l
    join public.profiles pr on pr.id = l.user_id
    where l.patient_id = target_patient_id
      and l.user_id = auth.uid()
      and l.status = 'active'
      and l.role = 'provider'
      and pr.role in ('provider', 'admin')
  );
$$;

-- True when the caller owns the patient this prescription belongs to AND
-- entered it themselves. Both halves matter: ownership alone would let a
-- patient rewrite the times on an order a doctor placed.
create or replace function public.owns_self_entered_prescription(
  target_prescription_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.prescriptions pr
    join public.patients p on p.id = pr.patient_id
    where pr.id = target_prescription_id
      and pr.source = 'self'
      and p.owner_user_id = auth.uid()
  );
$$;

-- Read access to the whole caseload, for approved clinical staff.
--
-- This is deliberately broader than can_access_patient(): a doctor here sees
-- every patient's records, not only the ones who messaged them. That is a
-- product decision for a small clinic where all approved doctors are trusted
-- with the full caseload — it is not the safe default, and it means approving
-- a doctor hands over every patient's medical history. Approval stays
-- admin-only and manual for exactly this reason.
--
-- Read only. Writing still goes through can_manage_patient_care(), so a
-- doctor cannot change medication for a patient who isn't theirs.
create or replace function public.can_view_all_patients()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role in ('provider', 'admin')
  );
$$;

-- ---------------------------------------------------------------------------
-- New-user provisioning
--
-- Mirrors what the old backend did on first sign-in: give the account a
-- profile and, for patients, the patient record the rest of the app hangs
-- off. Runs as the definer because a brand-new user has no rows yet.
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  display_name text;
  new_patient_id uuid;
begin
  display_name := coalesce(
    nullif(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'name', ''),
    split_part(coalesce(new.email, ''), '@', 1),
    'ผู้ใช้ใหม่'
  );

  insert into public.profiles (id, email, name, avatar_url)
  values (
    new.id,
    new.email,
    display_name,
    nullif(new.raw_user_meta_data ->> 'avatar_url', '')
  )
  on conflict (id) do nothing;

  select id into new_patient_id from public.patients where owner_user_id = new.id;
  if new_patient_id is null then
    -- Birth date is collected later in the app; this placeholder keeps the
    -- NOT NULL column satisfiable at sign-up.
    insert into public.patients (owner_user_id, name, birth_date)
    values (new.id, display_name, '2000-01-01');
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.profiles       enable row level security;
alter table public.patients       enable row level security;
alter table public.patient_links  enable row level security;
alter table public.prescriptions  enable row level security;
alter table public.dose_schedules enable row level security;
alter table public.dose_logs      enable row level security;
alter table public.symptom_logs   enable row level security;
alter table public.alerts         enable row level security;
alter table public.doctors        enable row level security;
alter table public.health_questions enable row level security;
alter table public.conversations  enable row level security;
alter table public.messages       enable row level security;

-- profiles: your own row only.
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated using (id = auth.uid());

-- Restricting the ROW is not enough here: `role` lives on this table, so a
-- policy that only checked `id = auth.uid()` would let any patient run
--   update profiles set role = 'admin' where id = <self>
-- straight against PostgREST with their own anon key, and every is_staff()
-- gate below would then open for them. Pinning role to its stored value keeps
-- promotion a service-role/SQL-editor operation.
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid() and role = public.current_profile_role());

-- patients: owned or actively linked.
drop policy if exists patients_select on public.patients;
create policy patients_select on public.patients
  for select to authenticated
  using (public.can_access_patient(id) or public.can_view_all_patients());

drop policy if exists patients_insert_own on public.patients;
create policy patients_insert_own on public.patients
  for insert to authenticated with check (owner_user_id = auth.uid());

-- can_access_patient() is satisfied by an active caregiver link as well as by
-- ownership, so checking it alone on both sides would let a linked caregiver
-- run `set owner_user_id = <self>`: the check would re-evaluate against the
-- new row, pass because they are now the owner, and strand the real owner —
-- who has no patient_links row — with no access at all. Ownership therefore
-- has to stay pinned to its stored value.
drop policy if exists patients_update on public.patients;
create policy patients_update on public.patients
  for update to authenticated
  using (public.can_access_patient(id))
  with check (
    public.can_access_patient(id)
    and owner_user_id = public.patient_owner(id)
  );

-- patient_links: the caregiver named on it, or the patient's owner.
drop policy if exists patient_links_select on public.patient_links;
create policy patient_links_select on public.patient_links
  for select to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.patients p
      where p.id = patient_id and p.owner_user_id = auth.uid()
    )
  );

-- Only the record's owner hands out access to it.
drop policy if exists patient_links_write_owner on public.patient_links;
create policy patient_links_write_owner on public.patient_links
  for all to authenticated
  using (
    exists (
      select 1 from public.patients p
      where p.id = patient_id and p.owner_user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.patients p
      where p.id = patient_id and p.owner_user_id = auth.uid()
    )
  );

-- prescriptions: readable by anyone with patient access; only staff prescribe.
drop policy if exists prescriptions_select on public.prescriptions;
create policy prescriptions_select on public.prescriptions
  for select to authenticated
  using (public.can_access_patient(patient_id) or public.can_view_all_patients());

drop policy if exists prescriptions_write_staff on public.prescriptions;
create policy prescriptions_write_staff on public.prescriptions
  for all to authenticated
  using (public.can_manage_patient_care(patient_id))
  with check (public.can_manage_patient_care(patient_id));

-- A patient keeps their own medication list.
--
-- Scoped to rows marked 'self' on BOTH sides, which is what stops a patient
-- editing an order a doctor wrote: `using` tests the row as it stands, so an
-- existing clinician row never matches and cannot be updated or deleted;
-- `with check` tests the row being written, so neither an insert nor an
-- update can pass itself off as clinician-entered. Losing either half would
-- let a patient rewrite a prescription and leave it still looking official.
drop policy if exists prescriptions_write_own_self on public.prescriptions;
create policy prescriptions_write_own_self on public.prescriptions
  for all to authenticated
  using (source = 'self' and public.patient_owner(patient_id) = auth.uid())
  with check (source = 'self' and public.patient_owner(patient_id) = auth.uid());

-- Stamps who wrote the row instead of trusting what the client sent. The
-- policy above already pins `source` for patients, but staff write through a
-- policy that does not, and created_by is otherwise whatever was posted.
create or replace function public.prescriptions_stamp_author()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.created_by := auth.uid();
  if tg_op = 'UPDATE' then
    -- Origin is set once, when the row is created. Allowing it to change
    -- would give back exactly what the policy above takes away.
    new.source := old.source;
  end if;
  return new;
end;
$$;

drop trigger if exists prescriptions_stamp_author on public.prescriptions;
create trigger prescriptions_stamp_author
  before insert or update on public.prescriptions
  for each row execute function public.prescriptions_stamp_author();

drop policy if exists dose_schedules_select on public.dose_schedules;
create policy dose_schedules_select on public.dose_schedules
  for select to authenticated
  using (
    public.can_access_patient(public.patient_id_for_schedule(id))
    or public.can_view_all_patients()
  );

-- Resolved from prescription_id rather than patient_id_for_schedule(id) so
-- the check also holds on INSERT, before the schedule row exists.
drop policy if exists dose_schedules_write_staff on public.dose_schedules;
create policy dose_schedules_write_staff on public.dose_schedules
  for all to authenticated
  using (
    public.can_manage_patient_care(public.patient_id_for_prescription(prescription_id))
  )
  with check (
    public.can_manage_patient_care(public.patient_id_for_prescription(prescription_id))
  );

-- The times on a patient's own medication.
--
-- Delegated to a helper rather than written inline because it has to read the
-- parent prescription, and a policy on dose_schedules querying prescriptions
-- would re-enter that table's own policies.
drop policy if exists dose_schedules_write_own_self on public.dose_schedules;
create policy dose_schedules_write_own_self on public.dose_schedules
  for all to authenticated
  using (public.owns_self_entered_prescription(prescription_id))
  with check (public.owns_self_entered_prescription(prescription_id));

-- dose_logs: patients record their own doses, so read and write both go
-- through patient access rather than staff-only.
drop policy if exists dose_logs_select on public.dose_logs;
create policy dose_logs_select on public.dose_logs
  for select to authenticated
  using (
    public.can_access_patient(public.patient_id_for_schedule(schedule_id))
    or public.can_view_all_patients()
  );

drop policy if exists dose_logs_insert on public.dose_logs;
create policy dose_logs_insert on public.dose_logs
  for insert to authenticated
  with check (public.can_access_patient(public.patient_id_for_schedule(schedule_id)));

drop policy if exists symptom_logs_select on public.symptom_logs;
create policy symptom_logs_select on public.symptom_logs
  for select to authenticated
  using (public.can_access_patient(patient_id) or public.can_view_all_patients());

drop policy if exists symptom_logs_insert on public.symptom_logs;
create policy symptom_logs_insert on public.symptom_logs
  for insert to authenticated with check (public.can_access_patient(patient_id));

drop policy if exists alerts_select on public.alerts;
create policy alerts_select on public.alerts
  for select to authenticated
  using (public.can_access_patient(patient_id) or public.can_view_all_patients());

-- Acknowledging is the only thing the app does here, but the policy alone
-- would also permit rewriting `severity` and `message` — i.e. a patient
-- editing the clinical content of their own alert. RLS has no column-level
-- grain, so the trigger below puts every other column back.
drop policy if exists alerts_update on public.alerts;
create policy alerts_update on public.alerts
  for update to authenticated
  using (public.can_access_patient(patient_id))
  with check (public.can_access_patient(patient_id));

create or replace function public.alerts_allow_status_change_only()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Only end-user sessions are constrained. Whatever raises alerts runs with
  -- the service role (no 'authenticated' JWT) and still writes freely. Read
  -- from the request claims directly rather than auth.role()/auth.jwt(), which
  -- are unset outside a PostgREST request and vary across Supabase versions.
  if coalesce(current_setting('request.jwt.claims', true)::jsonb ->> 'role', '')
     = 'authenticated' then
    new.id         := old.id;
    new.patient_id := old.patient_id;
    new.severity   := old.severity;
    new.message    := old.message;
    new.created_at := old.created_at;
  end if;
  return new;
end;
$$;

drop trigger if exists alerts_status_only on public.alerts;
create trigger alerts_status_only
  before update on public.alerts
  for each row execute function public.alerts_allow_status_change_only();

-- health_questions: the patient (or their caregiver) asks; only staff answer.
drop policy if exists health_questions_select on public.health_questions;
create policy health_questions_select on public.health_questions
  for select to authenticated using (public.can_access_patient(patient_id));

-- asked_by is pinned to the caller so a question cannot be attributed to
-- someone else, and the reply columns are pinned to empty so a patient cannot
-- post a question that already carries its own "doctor's answer".
drop policy if exists health_questions_insert on public.health_questions;
create policy health_questions_insert on public.health_questions
  for insert to authenticated
  with check (
    public.can_access_patient(patient_id)
    and asked_by = auth.uid()
    and status = 'pending'
    and answer is null
    and answered_by is null
    and answered_at is null
  );

-- No UPDATE policy for patients at all: once asked, a question is theirs to
-- read but not to rewrite, which keeps the answered record trustworthy.
drop policy if exists health_questions_answer_staff on public.health_questions;
create policy health_questions_answer_staff on public.health_questions
  for update to authenticated
  using (public.can_manage_patient_care(patient_id))
  with check (public.can_manage_patient_care(patient_id));

-- The two policies above between them left the feature dead: a patient could
-- post a question, but can_access_patient() hid it from every doctor, and
-- can_manage_patient_care() needs an active provider patient_links row, which
-- nothing in this app ever creates. Questions went in and no one could read or
-- answer them.
--
-- A doctor is anyone holding a listing, which only an admin can grant, so the
-- queue is visible to approved doctors and to nobody else.
drop policy if exists health_questions_select_doctor on public.health_questions;
create policy health_questions_select_doctor on public.health_questions
  for select to authenticated
  using (public.current_doctor_id() is not null);

drop policy if exists health_questions_answer_doctor on public.health_questions;
create policy health_questions_answer_doctor on public.health_questions
  for update to authenticated
  using (public.current_doctor_id() is not null)
  with check (public.current_doctor_id() is not null);

-- The UPDATE policy above is broad by necessity — a doctor answers questions
-- for patients they have no link to. This narrows what that update may touch:
-- everything the patient wrote stays as written, and the answer is signed by
-- whoever actually typed it rather than by whatever the client sent.
create or replace function public.health_questions_answer_only()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(current_setting('request.jwt.claims', true)::jsonb ->> 'role', '')
       = 'authenticated' then
    new.id         := old.id;
    new.patient_id := old.patient_id;
    new.asked_by   := old.asked_by;
    new.topic_key  := old.topic_key;
    new.question   := old.question;
    new.created_at := old.created_at;

    if new.answer is distinct from old.answer then
      new.answered_by := public.current_doctor_id();
      new.answered_at := now();
    else
      new.answered_by := old.answered_by;
      new.answered_at := old.answered_at;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists health_questions_answer_guard on public.health_questions;
create trigger health_questions_answer_guard
  before update on public.health_questions
  for each row execute function public.health_questions_answer_only();

-- doctors: a shared directory — everyone reads, only an admin adds or removes
-- a listing. Patients used to be able to create these (the app showed them an
-- "add doctor" button), which meant anyone could publish themselves to every
-- patient as a doctor; in an app that carries medical advice that is the more
-- dangerous hole, not a UI wart. is_staff() is not enough either: one provider
-- should not be able to edit another's listing.
drop policy if exists doctors_select on public.doctors;
create policy doctors_select on public.doctors
  for select to authenticated using (true);

drop policy if exists doctors_write_staff on public.doctors;
drop policy if exists doctors_write_admin on public.doctors;
create policy doctors_write_admin on public.doctors
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- A doctor maintains their own listing (name, specialty, bio, photo). The
-- check pins user_id to the caller, so they cannot hand the listing — and the
-- conversations attached to it — to another account.
drop policy if exists doctors_update_self on public.doctors;
create policy doctors_update_self on public.doctors
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- conversations: the patient side or the addressed doctor.
drop policy if exists conversations_select on public.conversations;
create policy conversations_select on public.conversations
  for select to authenticated
  using (
    public.can_access_patient(patient_id)
    or doctor_id = public.current_doctor_id()
  );

drop policy if exists conversations_insert_patient on public.conversations;
create policy conversations_insert_patient on public.conversations
  for insert to authenticated
  with check (public.can_access_patient(patient_id));

-- A doctor may also open the thread, so they can follow up on a symptom log
-- or an alert without waiting to be messaged first. doctor_id is pinned to
-- the caller's own listing: they can start a conversation as themselves, never
-- one that appears to come from another doctor.
drop policy if exists conversations_insert_doctor on public.conversations;
create policy conversations_insert_doctor on public.conversations
  for insert to authenticated
  with check (doctor_id = public.current_doctor_id());

-- Both sides may touch last_message_at when they post.
drop policy if exists conversations_update on public.conversations;
create policy conversations_update on public.conversations
  for update to authenticated
  using (
    public.can_access_patient(patient_id)
    or doctor_id = public.current_doctor_id()
  )
  with check (
    public.can_access_patient(patient_id)
    or doctor_id = public.current_doctor_id()
  );

-- messages: readable by whoever may see the thread; sender is pinned to the
-- caller so neither side can post words under the other's name. No UPDATE or
-- DELETE policy at all — a sent message is part of a medical exchange and
-- stays as sent.
drop policy if exists messages_select on public.messages;
create policy messages_select on public.messages
  for select to authenticated
  using (public.can_access_conversation(conversation_id));

drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages
  for insert to authenticated
  with check (
    public.can_access_conversation(conversation_id)
    and sender_id = auth.uid()
  );

-- profiles: an admin needs to see accounts to promote one to a doctor. This
-- is the only cross-user read in the schema, and it is limited to admins,
-- which cannot be self-assigned (see profiles_update_own).
drop policy if exists profiles_select_admin on public.profiles;
create policy profiles_select_admin on public.profiles
  for select to authenticated using (public.is_admin());

-- Approving a doctor has to set that account's role to 'provider', and
-- profiles_update_own only ever matches the caller's own row — without this
-- the approval updated nothing at all, silently: the doctor got a listing but
-- kept role 'patient', so the app sent them to the patient screens and their
-- inbox was unreachable.
--
-- Permissive policies are OR'd, so this bypasses the role pin in
-- profiles_update_own. That is the intent — granting roles is what an admin
-- is for — and it is why becoming an admin is not something the app can do
-- to itself: the first one is set in SQL, and only an existing admin can
-- make another.
drop policy if exists profiles_update_admin on public.profiles;
create policy profiles_update_admin on public.profiles
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- Storage: avatars and doctor photos
--
-- Public-read so Flutter's NetworkImage can load them without a token;
-- writes are restricted to the signed-in owner's own folder.
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

drop policy if exists avatars_read on storage.objects;
create policy avatars_read on storage.objects
  for select using (bucket_id = 'avatars');

drop policy if exists avatars_write_own on storage.objects;
create policy avatars_write_own on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists avatars_update_own on storage.objects;
create policy avatars_update_own on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- ---------------------------------------------------------------------------
-- Peer chat: patient <-> patient direct messages
--
-- Kept in its own pair of tables rather than widening conversations/messages.
-- That pair models a clinical exchange with a named doctor, and relaxing its
-- doctor_id to nullable would drop both the NOT NULL and the
-- unique (patient_id, doctor_id) that keep one thread per patient/doctor pair
-- honest. Two tables cost a little duplication and keep that guarantee.
--
-- Visibility here is deliberately narrower than everywhere else in the schema:
-- can_access_patient() is satisfied only by ownership or an active caregiver
-- link, so a doctor or admin reading the whole caseload still cannot open a
-- patient's private conversation with another patient.
-- ---------------------------------------------------------------------------

-- Opt-in. A patient is neither listed in the directory nor able to browse it
-- until they turn this on, so the default install exposes no patient to any
-- other patient.
alter table public.patients
  add column if not exists peer_chat_enabled boolean not null default false;

create table if not exists public.peer_conversations (
  id uuid primary key default gen_random_uuid(),
  -- Stored as an ordered pair so (a,b) and (b,a) cannot both exist and race
  -- into two threads for the same two people.
  patient_low uuid not null references public.patients (id) on delete cascade,
  patient_high uuid not null references public.patients (id) on delete cascade,
  created_at timestamptz not null default now(),
  last_message_at timestamptz not null default now(),
  constraint peer_conversations_ordered check (patient_low < patient_high),
  unique (patient_low, patient_high)
);
create index if not exists peer_conversations_low_idx
  on public.peer_conversations (patient_low, last_message_at desc);
create index if not exists peer_conversations_high_idx
  on public.peer_conversations (patient_high, last_message_at desc);

create table if not exists public.peer_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.peer_conversations (id) on delete cascade,
  sender_id uuid not null references auth.users (id) on delete cascade,
  body text not null check (length(trim(body)) > 0 and length(body) <= 2000),
  created_at timestamptz not null default now()
);
create index if not exists peer_messages_conversation_idx
  on public.peer_messages (conversation_id, created_at);

-- The patient record this account owns, or null for staff and admins — they
-- have no patient row, and so no peer chat.
create or replace function public.current_patient_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select id from public.patients where owner_user_id = auth.uid() limit 1;
$$;

create or replace function public.peer_chat_open(target_patient_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select peer_chat_enabled from public.patients where id = target_patient_id),
    false
  );
$$;

create or replace function public.can_access_peer_conversation(target_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.peer_conversations c
    where c.id = target_conversation_id
      and (
        public.can_access_patient(c.patient_low)
        or public.can_access_patient(c.patient_high)
      )
  );
$$;

alter table public.peer_conversations enable row level security;
alter table public.peer_messages      enable row level security;

drop policy if exists peer_conversations_select on public.peer_conversations;
create policy peer_conversations_select on public.peer_conversations
  for select to authenticated
  using (
    public.can_access_patient(patient_low)
    or public.can_access_patient(patient_high)
  );

-- No INSERT, UPDATE or DELETE policy on purpose. Threads are created only
-- through open_peer_conversation(), which enforces the mutual opt-in, and
-- last_message_at is maintained by a trigger — so there is nothing a client
-- may write directly, and no policy for a direct write to satisfy. This also
-- closes the hijack an UPDATE policy would open: a participant could
-- otherwise repoint the other side of the pair at a third patient and keep
-- the thread's history.

drop policy if exists peer_messages_select on public.peer_messages;
create policy peer_messages_select on public.peer_messages
  for select to authenticated
  using (public.can_access_peer_conversation(conversation_id));

-- sender_id is pinned to the caller, so neither participant can post words
-- under the other's name. No UPDATE or DELETE policy: a sent message stays
-- as sent, matching the doctor threads.
drop policy if exists peer_messages_insert on public.peer_messages;
create policy peer_messages_insert on public.peer_messages
  for insert to authenticated
  with check (
    public.can_access_peer_conversation(conversation_id)
    and sender_id = auth.uid()
  );

-- Keeps the thread list sorted by activity without granting clients UPDATE on
-- the conversation row.
create or replace function public.peer_touch_conversation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.peer_conversations
     set last_message_at = new.created_at
   where id = new.conversation_id;
  return new;
end;
$$;

drop trigger if exists peer_messages_touch on public.peer_messages;
create trigger peer_messages_touch
  after insert on public.peer_messages
  for each row execute function public.peer_touch_conversation();

-- Directory of people who may be messaged. Both sides must have opted in:
-- turning peer chat on is what makes you visible AND what lets you look, so a
-- patient cannot lurk over the directory while staying unlisted themselves.
-- Returns names only — never a condition, a prescription or a symptom.
create or replace function public.peer_directory(search text default '')
returns table (patient_id uuid, display_name text)
language sql
stable
security definer
set search_path = ''
as $$
  select p.id, p.name
  from public.patients p
  where p.peer_chat_enabled
    and public.peer_chat_open(public.current_patient_id())
    and p.id is distinct from public.current_patient_id()
    and (
      coalesce(search, '') = ''
      or p.name ilike '%' || search || '%'
    )
  order by p.name
  limit 50;
$$;

-- The caller's threads with the counterpart's name resolved. Goes through a
-- definer so the list can name the other participant without opening
-- patients_select up to every patient row.
create or replace function public.peer_threads()
returns table (
  conversation_id uuid,
  other_patient_id uuid,
  other_name text,
  last_message_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with me as (select public.current_patient_id() as pid)
  select c.id,
         other.id,
         other.name,
         c.last_message_at
  from public.peer_conversations c
  cross join me
  join public.patients other
    on other.id = case when c.patient_low = me.pid
                       then c.patient_high
                       else c.patient_low
                  end
  where me.pid is not null
    and me.pid in (c.patient_low, c.patient_high)
  order by c.last_message_at desc;
$$;

-- Opens (or reuses) the thread between the caller and one other patient.
-- Definer because the tables carry no INSERT policy: this function is the
-- only way in, and it re-derives the caller's own patient id rather than
-- trusting one passed from the client.
create or replace function public.open_peer_conversation(target_patient_id uuid)
returns uuid
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  me uuid := public.current_patient_id();
  lo uuid;
  hi uuid;
  cid uuid;
begin
  if me is null or target_patient_id is null or me = target_patient_id then
    raise exception 'peer chat: invalid participants';
  end if;
  if not public.peer_chat_open(me) or not public.peer_chat_open(target_patient_id) then
    raise exception 'peer chat: both participants must enable peer chat';
  end if;

  lo := least(me, target_patient_id);
  hi := greatest(me, target_patient_id);

  insert into public.peer_conversations (patient_low, patient_high)
  values (lo, hi)
  on conflict (patient_low, patient_high) do nothing;

  select id into cid
  from public.peer_conversations
  where patient_low = lo and patient_high = hi;

  return cid;
end;
$$;

-- ---------------------------------------------------------------------------
-- Realtime
--
-- The chat screens subscribe to INSERTs over Supabase Realtime. Supabase
-- creates the supabase_realtime publication empty, so a table that is not
-- added to it never emits and a reply only shows up on a manual refresh.
-- Guarded so re-running this file is a no-op, and so the whole block skips on
-- a plain Postgres instance that has no such publication.
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    return;
  end if;
  foreach t in array array['messages', 'peer_messages'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
