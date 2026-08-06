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
create table if not exists public.doctors (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  specialty text not null,
  bio text,
  photo_url text,
  created_at timestamptz not null default now()
);

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
  for select to authenticated using (public.can_access_patient(id));

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
  for select to authenticated using (public.can_access_patient(patient_id));

drop policy if exists prescriptions_write_staff on public.prescriptions;
create policy prescriptions_write_staff on public.prescriptions
  for all to authenticated
  using (public.can_manage_patient_care(patient_id))
  with check (public.can_manage_patient_care(patient_id));

drop policy if exists dose_schedules_select on public.dose_schedules;
create policy dose_schedules_select on public.dose_schedules
  for select to authenticated
  using (public.can_access_patient(public.patient_id_for_schedule(id)));

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

-- dose_logs: patients record their own doses, so read and write both go
-- through patient access rather than staff-only.
drop policy if exists dose_logs_select on public.dose_logs;
create policy dose_logs_select on public.dose_logs
  for select to authenticated
  using (public.can_access_patient(public.patient_id_for_schedule(schedule_id)));

drop policy if exists dose_logs_insert on public.dose_logs;
create policy dose_logs_insert on public.dose_logs
  for insert to authenticated
  with check (public.can_access_patient(public.patient_id_for_schedule(schedule_id)));

drop policy if exists symptom_logs_select on public.symptom_logs;
create policy symptom_logs_select on public.symptom_logs
  for select to authenticated using (public.can_access_patient(patient_id));

drop policy if exists symptom_logs_insert on public.symptom_logs;
create policy symptom_logs_insert on public.symptom_logs
  for insert to authenticated with check (public.can_access_patient(patient_id));

drop policy if exists alerts_select on public.alerts;
create policy alerts_select on public.alerts
  for select to authenticated using (public.can_access_patient(patient_id));

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

-- doctors: a shared directory — everyone reads, only staff edit.
drop policy if exists doctors_select on public.doctors;
create policy doctors_select on public.doctors
  for select to authenticated using (true);

drop policy if exists doctors_write_staff on public.doctors;
create policy doctors_write_staff on public.doctors
  for all to authenticated using (public.is_staff()) with check (public.is_staff());

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
