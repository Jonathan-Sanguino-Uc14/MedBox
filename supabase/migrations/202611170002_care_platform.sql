-- Med Box care platform (P0). Apply after 202611170001_mobile_foundation.sql.
-- Follows docs/MED_BOX_PLAN_MAESTRO.md sections 3 and 6:
--   deny by default; patient by own identity; specialist by active session and
--   provisioned specialty; administrators get no automatic clinical access;
--   public reads only on published catalog rows; access-changing writes go
--   through SECURITY DEFINER functions that also write access_audit.
begin;

-- ---------------------------------------------------------------------------
-- 1. Catalogs, organizations, profiles, specialists
-- ---------------------------------------------------------------------------
create table public.specialties (
  code text primary key check (code in ('physio','skin','eyes','mind')),
  label text not null
);
insert into public.specialties values
  ('physio','Fisioterapia'), ('skin','Dermatología'), ('eyes','Oftalmología'), ('mind','Psicología');

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(name) between 1 and 160),
  created_at timestamptz not null default now()
);
insert into public.organizations(id, name)
  values ('00000000-0000-4000-8000-000000000001', 'Med Box Demo (ficticia)');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '' check (length(full_name) <= 120),
  role text not null default 'patient' check (role in ('patient','specialist')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.memberships (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('specialist','org_admin')),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (organization_id, user_id, role)
);

create table public.specialists (
  user_id uuid primary key references auth.users(id) on delete cascade,
  organization_id uuid not null references public.organizations(id),
  display_name text not null check (length(display_name) between 1 and 120),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table public.specialist_specialties (
  user_id uuid not null references public.specialists(user_id) on delete cascade,
  specialty text not null references public.specialties(code),
  primary key (user_id, specialty)
);

create function public.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end;
$$;
create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles(id, full_name)
  values (new.id, left(coalesce(new.raw_user_meta_data->>'full_name', ''), 120))
  on conflict (id) do nothing;
  return new;
end;
$$;
revoke all on function public.handle_new_user() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();
insert into public.profiles(id) select id from auth.users on conflict (id) do nothing;

create function public.is_specialist_for(p_specialty text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.specialists s
    join public.specialist_specialties ss on ss.user_id = s.user_id
    where s.user_id = (select auth.uid()) and s.active and ss.specialty = p_specialty);
$$;
revoke all on function public.is_specialist_for(text) from public, anon;
grant execute on function public.is_specialist_for(text) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Extend foundation tables (sessions, invites, requests, records)
-- ---------------------------------------------------------------------------
alter table public.care_sessions
  add column organization_id uuid references public.organizations(id),
  add column closed_at timestamptz;
alter table public.care_sessions add constraint care_sessions_id_patient unique (id, patient_id);

alter table public.care_invites
  add column organization_id uuid references public.organizations(id);
create index care_invites_specialist_idx on public.care_invites(specialist_id, created_at desc);

alter table public.care_link_requests
  add column session_id uuid references public.care_sessions(id),
  add column decided_at timestamptz,
  add column decided_by uuid references auth.users(id);
create index care_link_requests_invite_idx on public.care_link_requests(invite_id);

-- Activity assignments: what the specialist asks the patient to do.
create table public.care_activities (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.care_sessions(id),
  created_by uuid not null references auth.users(id),
  title text not null check (length(title) between 1 and 160),
  instructions text not null default '' check (length(instructions) <= 4000),
  target jsonb not null default '{}' check (jsonb_typeof(target) = 'object' and octet_length(target::text) <= 2000),
  due_on date,
  cancelled boolean not null default false,
  created_at timestamptz not null default now()
);
create index care_activities_session_idx on public.care_activities(session_id, created_at);
alter table public.care_activities add constraint care_activities_id_session unique (id, session_id);

-- Records: one structured row per patient submission. Fields are validated per specialty.
alter table public.care_records
  add column activity_id uuid,
  add column idempotency_key uuid,
  add column completed boolean,
  add column pain smallint check (pain between 0 and 10),
  add column laterality text check (laterality in ('right','left','both','na')),
  add column mood text check (mood in ('calm','joy','sadness','worry','tired')),
  add column body_zone text check (length(body_zone) <= 100),
  add column note text check (length(note) <= 2000),
  add column evidence_path text check (length(evidence_path) <= 300),
  add column reported_on date not null default current_date;
alter table public.care_records alter column details set default '{}'::jsonb;
alter table public.care_records add constraint care_records_activity_fk
  foreign key (activity_id, session_id) references public.care_activities(id, session_id);
alter table public.care_records add constraint care_records_idempotency unique (patient_id, idempotency_key);
alter table public.care_records add constraint care_records_id_session unique (id, session_id);
alter table public.care_records add constraint care_records_session_patient_fk
  foreign key (session_id, patient_id) references public.care_sessions(id, patient_id);

create function public.validate_care_record() returns trigger
language plpgsql set search_path = '' as $$
declare sp text;
begin
  select specialty into sp from public.care_sessions where id = new.session_id;
  if new.pain is not null and sp <> 'physio' then raise exception 'pain solo aplica a fisioterapia'; end if;
  if new.laterality is not null and sp <> 'eyes' then raise exception 'laterality solo aplica a oftalmología'; end if;
  if new.mood is not null and sp <> 'mind' then raise exception 'mood solo aplica a psicología'; end if;
  if (new.body_zone is not null or new.evidence_path is not null) and sp <> 'skin' then
    raise exception 'zona/evidencia solo aplica a dermatología';
  end if;
  if new.evidence_path is not null
     and new.evidence_path not like new.session_id::text || '/' || new.patient_id::text || '/%' then
    raise exception 'ruta de evidencia no válida';
  end if;
  new.created_at := now();
  return new;
end;
$$;
create trigger care_records_validate before insert on public.care_records
  for each row execute function public.validate_care_record();

-- Clinical reviews: authored by the session specialist; append-only.
create table public.care_reviews (
  id uuid primary key default gen_random_uuid(),
  record_id uuid not null,
  session_id uuid not null references public.care_sessions(id),
  specialist_id uuid not null references auth.users(id),
  body text not null check (length(body) between 1 and 4000),
  shared_with_patient boolean not null default true,
  created_at timestamptz not null default now(),
  foreign key (record_id, session_id) references public.care_records(id, session_id)
);
create index care_reviews_session_idx on public.care_reviews(session_id, created_at);

-- ---------------------------------------------------------------------------
-- 3. Consents, data requests, audit
-- ---------------------------------------------------------------------------
create table public.consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  purpose text not null check (purpose in ('tracking','images','location','analytics')),
  granted boolean not null,
  version text not null default 'demo-1' check (length(version) <= 40),
  created_at timestamptz not null default now()
);
create index consents_user_purpose_idx on public.consents(user_id, purpose, created_at desc);

create function public.has_consent(p_user uuid, p_purpose text) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((select c.granted from public.consents c
    where c.user_id = p_user and c.purpose = p_purpose
    order by c.created_at desc limit 1), false);
$$;
revoke all on function public.has_consent(uuid, text) from public, anon, authenticated;

create table public.data_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('export','delete')),
  status text not null default 'pending' check (status in ('pending','in_progress','done','rejected')),
  created_at timestamptz not null default now()
);

-- No text, images or clinical content: actor, action, opaque resource id.
create table public.access_audit (
  id bigint generated always as identity primary key,
  actor uuid,
  action text not null,
  resource_type text not null,
  resource_id uuid,
  ok boolean not null default true,
  created_at timestamptz not null default now()
);
create index access_audit_actor_idx on public.access_audit(actor, created_at desc);

create function public.audit(p_action text, p_type text, p_id uuid, p_ok boolean default true) returns void
language sql security definer set search_path = '' as $$
  insert into public.access_audit(actor, action, resource_type, resource_id, ok)
  values ((select auth.uid()), p_action, p_type, p_id, p_ok);
$$;
revoke all on function public.audit(text, text, uuid, boolean) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Public prevention catalog (plan §7 and §9). No personal data.
-- ---------------------------------------------------------------------------
create table public.data_sources (
  id text primary key,
  name text not null,
  url text not null,
  license text not null default 'Pendiente de validar',
  consulted_on date not null
);
create table public.prevention_rules (
  code text primary key,
  title text not null,
  body text not null,
  source_id text not null references public.data_sources(id),
  scope text not null default 'Educación general',
  is_local_alert boolean not null default false,
  reviewed_on date not null,
  expires_on date not null,
  published boolean not null default false
);
insert into public.data_sources values
  ('who-dengue', 'OMS · Dengue y dengue grave',
   'https://www.who.int/es/news-room/fact-sheets/detail/dengue-and-severe-dengue',
   'Términos de uso OMS', date '2026-11-17');
insert into public.prevention_rules values
  ('R01', 'Menos criaderos, más prevención',
   'Reduce los recipientes con agua acumulada y protege tu hogar de los mosquitos. Consulta la fuente para conocer medidas de prevención.',
   'who-dengue', 'Educación general', false, date '2026-11-17', date '2027-02-15', true);

-- ---------------------------------------------------------------------------
-- 5. RLS, grants and policies
-- ---------------------------------------------------------------------------
alter table public.specialties enable row level security;
alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.memberships enable row level security;
alter table public.specialists enable row level security;
alter table public.specialist_specialties enable row level security;
alter table public.care_activities enable row level security;
alter table public.care_reviews enable row level security;
alter table public.consents enable row level security;
alter table public.data_requests enable row level security;
alter table public.access_audit enable row level security;
alter table public.data_sources enable row level security;
alter table public.prevention_rules enable row level security;

revoke all on public.specialties, public.organizations, public.profiles, public.memberships,
  public.specialists, public.specialist_specialties, public.care_activities, public.care_reviews,
  public.consents, public.data_requests, public.access_audit, public.data_sources,
  public.prevention_rules from anon, authenticated;

-- Catalogs
grant select on public.specialties, public.data_sources, public.prevention_rules to anon, authenticated;
create policy specialties_read on public.specialties for select to anon, authenticated using (true);
create policy sources_read on public.data_sources for select to anon, authenticated using (true);
create policy rules_published_read on public.prevention_rules for select to anon, authenticated
  using (published and expires_on >= current_date);

grant select on public.organizations to authenticated;
create policy organization_member_read on public.organizations for select to authenticated
  using (exists (select 1 from public.memberships m
    where m.organization_id = organizations.id and m.user_id = (select auth.uid()) and m.active));

-- Profiles: own row; specialist sees linked patient's name only while session active.
grant select on public.profiles to authenticated;
grant update (full_name) on public.profiles to authenticated;
create policy profile_self_read on public.profiles for select to authenticated
  using (id = (select auth.uid()));
create policy profile_linked_specialist_read on public.profiles for select to authenticated
  using (exists (select 1 from public.care_sessions s
    where s.patient_id = profiles.id and s.specialist_id = (select auth.uid()) and s.active));
create policy profile_self_update on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

grant select on public.memberships, public.specialists, public.specialist_specialties to authenticated;
create policy membership_self_read on public.memberships for select to authenticated
  using (user_id = (select auth.uid()));
create policy specialist_self_read on public.specialists for select to authenticated
  using (user_id = (select auth.uid()));
create policy specialty_self_read on public.specialist_specialties for select to authenticated
  using (user_id = (select auth.uid()));

-- Invites: issuing specialist sees metadata, never the code hash.
grant select (id, specialist_id, organization_id, specialty, recipient_email, expires_at, revoked, created_at)
  on public.care_invites to authenticated;
create policy invite_owner_read on public.care_invites for select to authenticated
  using (specialist_id = (select auth.uid()));
create policy request_invite_owner_read on public.care_link_requests for select to authenticated
  using (exists (select 1 from public.care_invites i
    where i.id = invite_id and i.specialist_id = (select auth.uid())));

-- Activities: specialist of the active session writes; both participants read.
grant select, insert on public.care_activities to authenticated;
grant update (cancelled, due_on) on public.care_activities to authenticated;
create policy activity_participants_read on public.care_activities for select to authenticated
  using (exists (select 1 from public.care_sessions s where s.id = session_id
    and (s.patient_id = (select auth.uid()) or (s.specialist_id = (select auth.uid()) and s.active))));
create policy activity_specialist_insert on public.care_activities for insert to authenticated
  with check (created_by = (select auth.uid()) and exists (select 1 from public.care_sessions s
    where s.id = session_id and s.specialist_id = (select auth.uid()) and s.active));
create policy activity_specialist_update on public.care_activities for update to authenticated
  using (exists (select 1 from public.care_sessions s
    where s.id = session_id and s.specialist_id = (select auth.uid()) and s.active))
  with check (exists (select 1 from public.care_sessions s
    where s.id = session_id and s.specialist_id = (select auth.uid()) and s.active));

-- Reviews: patient reads shared ones; specialist reads/writes in active session.
grant select, insert on public.care_reviews to authenticated;
create policy review_patient_read on public.care_reviews for select to authenticated
  using (shared_with_patient and exists (select 1 from public.care_sessions s
    where s.id = session_id and s.patient_id = (select auth.uid())));
create policy review_specialist_read on public.care_reviews for select to authenticated
  using (exists (select 1 from public.care_sessions s
    where s.id = session_id and s.specialist_id = (select auth.uid()) and s.active));
create policy review_specialist_insert on public.care_reviews for insert to authenticated
  with check (specialist_id = (select auth.uid()) and exists (
    select 1 from public.care_sessions s where s.id = session_id
      and s.specialist_id = (select auth.uid()) and s.active));

-- Consents and data requests: own rows, append-only from the client.
grant select, insert on public.consents, public.data_requests to authenticated;
create policy consent_self_read on public.consents for select to authenticated
  using (user_id = (select auth.uid()));
create policy consent_self_insert on public.consents for insert to authenticated
  with check (user_id = (select auth.uid()));
create policy data_request_self_read on public.data_requests for select to authenticated
  using (user_id = (select auth.uid()));
create policy data_request_self_insert on public.data_requests for insert to authenticated
  with check (user_id = (select auth.uid()) and status = 'pending');

-- access_audit: no client grants at all (operator reads from SQL editor).

-- ---------------------------------------------------------------------------
-- 6. Workflow functions
-- ---------------------------------------------------------------------------
create function public.my_role() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'role', coalesce((select role from public.profiles where id = (select auth.uid())), 'patient'),
    'display_name', (select display_name from public.specialists where user_id = (select auth.uid()) and active),
    'specialties', coalesce((select jsonb_agg(ss.specialty order by ss.specialty)
      from public.specialist_specialties ss join public.specialists s on s.user_id = ss.user_id
      where ss.user_id = (select auth.uid()) and s.active), '[]'::jsonb));
$$;

create function public.my_link_requests() returns table(id uuid, specialty text, status text, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select r.id, i.specialty, r.status, r.created_at
  from public.care_link_requests r join public.care_invites i on i.id = r.invite_id
  where r.patient_id = (select auth.uid())
  order by r.created_at desc limit 50;
$$;

create function public.specialist_link_requests() returns table(
  id uuid, specialty text, recipient_email text, status text, created_at timestamptz)
language sql stable security definer set search_path = '' as $$
  select r.id, i.specialty, i.recipient_email, r.status, r.created_at
  from public.care_link_requests r join public.care_invites i on i.id = r.invite_id
  where i.specialist_id = (select auth.uid()) and public.is_specialist_for(i.specialty)
  order by (r.status = 'pending') desc, r.created_at desc limit 100;
$$;

create function public.create_care_invite(p_specialty text, p_recipient_email text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  raw bytea;
  code text := '';
  org uuid;
  invite public.care_invites;
begin
  if actor is null or not public.is_specialist_for(p_specialty) then
    return jsonb_build_object('ok', false, 'error', 'No tienes permiso para invitar en esta especialidad.');
  end if;
  if p_recipient_email is null or length(p_recipient_email) > 254
     or trim(p_recipient_email) !~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    return jsonb_build_object('ok', false, 'error', 'Correo del paciente no válido.');
  end if;
  if (select count(*) from public.care_invites
      where specialist_id = actor and created_at > now() - interval '1 hour') >= 30 then
    return jsonb_build_object('ok', false, 'error', 'Límite de invitaciones alcanzado. Intenta más tarde.');
  end if;
  raw := extensions.gen_random_bytes(12);
  for i in 0..11 loop
    code := code || substr(alphabet, (get_byte(raw, i) % 32) + 1, 1);
  end loop;
  select organization_id into org from public.specialists where user_id = actor;
  insert into public.care_invites(code_hash, specialist_id, organization_id, specialty, recipient_email)
  values (encode(extensions.digest(code, 'sha256'), 'hex'), actor, org, p_specialty, lower(trim(p_recipient_email)))
  returning * into invite;
  perform public.audit('invite.create', 'care_invite', invite.id);
  return jsonb_build_object('ok', true, 'invite_id', invite.id, 'code', code, 'expires_at', invite.expires_at);
end;
$$;

create function public.revoke_care_invite(p_invite_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  update public.care_invites set revoked = true
    where id = p_invite_id and specialist_id = auth.uid() and not revoked;
  if not found then return jsonb_build_object('ok', false, 'error', 'Invitación no disponible.'); end if;
  perform public.audit('invite.revoke', 'care_invite', p_invite_id);
  return jsonb_build_object('ok', true);
end;
$$;

create function public.approve_care_link(p_request_id uuid, p_title text, p_instructions text default '') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  req public.care_link_requests;
  invite public.care_invites;
  pro public.specialists;
  new_session uuid;
begin
  select * into req from public.care_link_requests where id = p_request_id for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'Solicitud no disponible.'); end if;
  select * into invite from public.care_invites where id = req.invite_id for update;
  if invite.specialist_id is distinct from actor or not public.is_specialist_for(invite.specialty) then
    perform public.audit('link.approve', 'care_link_request', p_request_id, false);
    return jsonb_build_object('ok', false, 'error', 'Solicitud no disponible.');
  end if;
  if req.status <> 'pending' or invite.revoked then
    return jsonb_build_object('ok', false, 'error', 'La solicitud ya fue resuelta o la invitación está revocada.');
  end if;
  if p_title is null or length(trim(p_title)) not between 1 and 160 or length(coalesce(p_instructions, '')) > 4000 then
    return jsonb_build_object('ok', false, 'error', 'Título o indicaciones no válidos.');
  end if;
  select * into pro from public.specialists where user_id = actor;
  insert into public.care_sessions(patient_id, specialist_id, organization_id, specialty, title, professional_name, instructions)
  values (req.patient_id, actor, pro.organization_id, invite.specialty, trim(p_title), pro.display_name, coalesce(p_instructions, ''))
  returning id into new_session;
  update public.care_link_requests
    set status = 'approved', session_id = new_session, decided_at = now(), decided_by = actor
    where id = req.id;
  update public.care_invites set revoked = true where id = invite.id;  -- single use
  perform public.audit('link.approve', 'care_session', new_session);
  return jsonb_build_object('ok', true, 'session_id', new_session);
end;
$$;

create function public.reject_care_link(p_request_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  update public.care_link_requests r set status = 'rejected', decided_at = now(), decided_by = auth.uid()
    from public.care_invites i
    where r.id = p_request_id and i.id = r.invite_id and i.specialist_id = auth.uid() and r.status = 'pending';
  if not found then return jsonb_build_object('ok', false, 'error', 'Solicitud no disponible.'); end if;
  perform public.audit('link.reject', 'care_link_request', p_request_id);
  return jsonb_build_object('ok', true);
end;
$$;

create function public.close_care_session(p_session_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  update public.care_sessions set active = false, closed_at = now()
    where id = p_session_id and specialist_id = auth.uid() and active;
  if not found then return jsonb_build_object('ok', false, 'error', 'Sesión no disponible.'); end if;
  perform public.audit('session.close', 'care_session', p_session_id);
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.my_role(), public.my_link_requests(), public.specialist_link_requests(),
  public.create_care_invite(text, text), public.revoke_care_invite(uuid),
  public.approve_care_link(uuid, text, text), public.reject_care_link(uuid),
  public.close_care_session(uuid) from public, anon;
grant execute on function public.my_role(), public.my_link_requests(), public.specialist_link_requests(),
  public.create_care_invite(text, text), public.revoke_care_invite(uuid),
  public.approve_care_link(uuid, text, text), public.reject_care_link(uuid),
  public.close_care_session(uuid) to authenticated;

-- Operator only (SQL editor, postgres role). Clients cannot call it.
create function public.provision_specialist(p_email text, p_display_name text, p_specialties text[],
  p_organization uuid default '00000000-0000-4000-8000-000000000001') returns uuid
language plpgsql security definer set search_path = '' as $$
declare target uuid;
begin
  select id into target from auth.users where lower(email) = lower(trim(p_email));
  if target is null then raise exception 'No existe usuario con ese correo'; end if;
  insert into public.specialists(user_id, organization_id, display_name) values (target, p_organization, p_display_name)
    on conflict (user_id) do update set display_name = excluded.display_name,
      organization_id = excluded.organization_id, active = true;
  delete from public.specialist_specialties where user_id = target;
  insert into public.specialist_specialties(user_id, specialty) select target, unnest(p_specialties);
  insert into public.memberships(organization_id, user_id, role) values (p_organization, target, 'specialist')
    on conflict do nothing;
  update public.profiles set role = 'specialist' where id = target;
  return target;
end;
$$;
revoke all on function public.provision_specialist(text, text, text[], uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 7. Private evidence storage. Path: <session_id>/<patient_id>/<uuid>.<ext>
-- ---------------------------------------------------------------------------
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('care-evidence', 'care-evidence', false, 10485760, array['image/jpeg','image/png'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create function public.can_upload_evidence(p_name text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.care_sessions s
    where s.id::text = (storage.foldername(p_name))[1]
      and s.patient_id::text = (storage.foldername(p_name))[2]
      and s.patient_id = (select auth.uid()) and s.active and s.specialty = 'skin')
    and public.has_consent((select auth.uid()), 'images');
$$;
create function public.can_read_evidence(p_name text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.care_sessions s
    where s.id::text = (storage.foldername(p_name))[1]
      and s.patient_id::text = (storage.foldername(p_name))[2]
      and (s.patient_id = (select auth.uid()) or (s.specialist_id = (select auth.uid()) and s.active)));
$$;
revoke all on function public.can_upload_evidence(text), public.can_read_evidence(text) from public, anon;
grant execute on function public.can_upload_evidence(text), public.can_read_evidence(text) to authenticated;

create policy care_evidence_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'care-evidence' and public.can_upload_evidence(name));
create policy care_evidence_read on storage.objects for select to authenticated
  using (bucket_id = 'care-evidence' and public.can_read_evidence(name));

commit;
