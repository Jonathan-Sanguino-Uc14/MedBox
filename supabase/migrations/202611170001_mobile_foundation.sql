-- Med Box mobile foundation. Apply once through an authenticated Supabase SQL editor.
-- This migration does not create public clinical access or grant users specialist roles.
begin;
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create table public.care_sessions (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references auth.users(id),
  specialist_id uuid not null references auth.users(id),
  specialty text not null check (specialty in ('physio','skin','eyes','mind')),
  title text not null check (length(title) between 1 and 160),
  professional_name text not null,
  instructions text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create index care_sessions_patient_idx on public.care_sessions(patient_id);
create index care_sessions_specialist_idx on public.care_sessions(specialist_id);
create table public.care_records (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.care_sessions(id),
  patient_id uuid not null references auth.users(id),
  details jsonb not null check (jsonb_typeof(details) = 'object' and octet_length(details::text) <= 12000),
  created_at timestamptz not null default now()
);
create index care_records_session_idx on public.care_records(session_id, created_at);
create table public.care_invites (
  id uuid primary key default gen_random_uuid(),
  code_hash text not null unique,
  specialist_id uuid not null references auth.users(id),
  specialty text not null check (specialty in ('physio','skin','eyes','mind')),
  recipient_email text not null,
  expires_at timestamptz not null default now() + interval '48 hours',
  revoked boolean not null default false,
  created_at timestamptz not null default now()
);
create table public.care_link_requests (
  id uuid primary key default gen_random_uuid(),
  invite_id uuid not null references public.care_invites(id),
  patient_id uuid not null references auth.users(id),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  unique(invite_id, patient_id)
);
create table public.care_link_attempts (
  patient_id uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
create index care_link_attempts_patient_idx on public.care_link_attempts(patient_id, created_at);

alter table public.care_sessions enable row level security;
alter table public.care_records enable row level security;
alter table public.care_invites enable row level security;
alter table public.care_link_requests enable row level security;
alter table public.care_link_attempts enable row level security;
revoke all on public.care_sessions, public.care_records, public.care_invites, public.care_link_requests, public.care_link_attempts from anon, authenticated;
grant select on public.care_sessions, public.care_records, public.care_link_requests to authenticated;
grant insert on public.care_records to authenticated;
create policy session_participants_read on public.care_sessions for select to authenticated
  using (patient_id = (select auth.uid()) or (specialist_id = (select auth.uid()) and active));
create policy record_participants_read on public.care_records for select to authenticated
  using (exists (select 1 from public.care_sessions s where s.id = session_id
    and (s.patient_id = (select auth.uid()) or (s.specialist_id = (select auth.uid()) and s.active))));
create policy patient_insert_own_record on public.care_records for insert to authenticated
  with check (patient_id = (select auth.uid()) and exists (
    select 1 from public.care_sessions s where s.id = session_id and s.patient_id = (select auth.uid()) and s.active));
create policy patient_requests_read on public.care_link_requests for select to authenticated
  using (patient_id = (select auth.uid()));

-- Return error objects rather than raise after recording an attempt, so failed attempts persist.
create function public.request_care_link(invitation_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  invitation public.care_invites;
  actor_email text;
begin
  if actor is null then return jsonb_build_object('ok', false, 'error', 'Inicia sesión para continuar.'); end if;
  perform pg_advisory_xact_lock(hashtextextended(actor::text, 0));
  if (select count(*) from public.care_link_attempts where patient_id = actor and created_at > now() - interval '15 minutes') >= 10 then
    return jsonb_build_object('ok', false, 'error', 'Demasiados intentos. Espera 15 minutos.');
  end if;
  insert into public.care_link_attempts(patient_id) values(actor);
  if invitation_code is null or length(invitation_code) not between 8 and 64 then
    return jsonb_build_object('ok', false, 'error', 'El código no está disponible para esta cuenta.');
  end if;
  select lower(email) into actor_email from auth.users where id = actor and email_confirmed_at is not null;
  select * into invitation from public.care_invites
    where code_hash = encode(extensions.digest(upper(trim(invitation_code)), 'sha256'), 'hex')
      and lower(recipient_email) = actor_email and not revoked and expires_at > now()
    for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'El código no está disponible para esta cuenta.'); end if;
  insert into public.care_link_requests(invite_id, patient_id) values(invitation.id, actor)
    on conflict (invite_id, patient_id) do nothing;
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.request_care_link(text) from public, anon;
grant execute on function public.request_care_link(text) to authenticated;
commit;
-- Approval and provisioning are administrative operations in this first mobile slice.
-- No client can create sessions, issue invites, approve itself, or change clinical records.
-- Private photo storage and professional portal are intentionally not part of this migration.
