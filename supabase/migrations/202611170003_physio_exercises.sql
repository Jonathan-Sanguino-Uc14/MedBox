-- Med Box physiotherapy: professional self-registration, exercise catalog,
-- camera-assisted exercise results and private exercise videos.
-- Patterns adapted from MIT-licensed references (docs/REFERENCIAS_DESCARGADAS.md):
--   PhysioBuddy (Exercise / AssignedExercise.target_reps / DoctorProfile fields),
--   fisio-app (clinician registration, Exercise.bodyRegion/defaultReps/precautions).
begin;

-- ---------------------------------------------------------------------------
-- 1. Operator switches (single row). Self-registration can be turned off.
-- ---------------------------------------------------------------------------
create table public.app_settings (
  id boolean primary key default true check (id),
  allow_specialist_self_registration boolean not null default true
);
insert into public.app_settings default values;
alter table public.app_settings enable row level security;
revoke all on public.app_settings from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Professional profile fields. Self-registered accounts are NOT verified.
-- ---------------------------------------------------------------------------
alter table public.specialists
  add column license_number text check (length(license_number) <= 40),
  add column qualification text check (length(qualification) <= 160),
  add column phone text check (length(phone) <= 30),
  add column clinic_name text check (length(clinic_name) <= 160),
  add column experience_years smallint check (experience_years between 0 and 70),
  add column verified boolean not null default false;
update public.specialists set verified = true;  -- operator-provisioned before this migration

create function public.register_as_specialist(
  p_display_name text, p_specialty text, p_license_number text,
  p_qualification text default null, p_phone text default null,
  p_clinic_name text default null, p_experience_years int default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid();
begin
  if actor is null then return jsonb_build_object('ok', false, 'error', 'Inicia sesión para continuar.'); end if;
  if not (select allow_specialist_self_registration from public.app_settings) then
    return jsonb_build_object('ok', false, 'error', 'El registro de profesionales está cerrado. Contacta al administrador.');
  end if;
  if p_specialty not in ('physio','skin','eyes','mind') then
    return jsonb_build_object('ok', false, 'error', 'Especialidad no válida.');
  end if;
  if p_display_name is null or length(trim(p_display_name)) not between 3 and 120 then
    return jsonb_build_object('ok', false, 'error', 'Escribe tu nombre profesional.');
  end if;
  if p_license_number is null or trim(p_license_number) !~ '^[A-Za-z0-9-]{4,40}$' then
    return jsonb_build_object('ok', false, 'error', 'Cédula profesional no válida.');
  end if;
  if exists (select 1 from public.care_sessions where patient_id = actor and active) then
    return jsonb_build_object('ok', false, 'error', 'Esta cuenta tiene sesiones como paciente. Usa otra cuenta para tu perfil profesional.');
  end if;
  insert into public.specialists(user_id, organization_id, display_name, license_number, qualification,
                                 phone, clinic_name, experience_years, verified)
  values (actor, '00000000-0000-4000-8000-000000000001', trim(p_display_name), upper(trim(p_license_number)),
          nullif(trim(p_qualification), ''), nullif(trim(p_phone), ''), nullif(trim(p_clinic_name), ''),
          p_experience_years, false)
  on conflict (user_id) do update set display_name = excluded.display_name,
    license_number = excluded.license_number, qualification = excluded.qualification,
    phone = excluded.phone, clinic_name = excluded.clinic_name,
    experience_years = excluded.experience_years;
  insert into public.specialist_specialties(user_id, specialty) values (actor, p_specialty)
    on conflict do nothing;
  insert into public.memberships(organization_id, user_id, role)
    values ('00000000-0000-4000-8000-000000000001', actor, 'specialist') on conflict do nothing;
  update public.profiles set role = 'specialist', full_name = trim(p_display_name) where id = actor;
  perform public.audit('specialist.self_register', 'specialist', actor);
  return jsonb_build_object('ok', true, 'verified', false);
end;
$$;
revoke all on function public.register_as_specialist(text, text, text, text, text, text, int) from public, anon;
grant execute on function public.register_as_specialist(text, text, text, text, text, text, int) to authenticated;

-- my_role now also reports verification.
create or replace function public.my_role() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'role', coalesce((select role from public.profiles where id = (select auth.uid())), 'patient'),
    'display_name', (select display_name from public.specialists where user_id = (select auth.uid()) and active),
    'verified', coalesce((select verified from public.specialists where user_id = (select auth.uid())), false),
    'specialties', coalesce((select jsonb_agg(ss.specialty order by ss.specialty)
      from public.specialist_specialties ss join public.specialists s on s.user_id = ss.user_id
      where ss.user_id = (select auth.uid()) and s.active), '[]'::jsonb));
$$;

-- ---------------------------------------------------------------------------
-- 3. Exercise catalog (PhysioBuddy core library, translated; detector codes
--    match lib/exercise_analysis.dart).
-- ---------------------------------------------------------------------------
create table public.exercise_catalog (
  code text primary key check (code ~ '^[a-z_]{3,40}$'),
  specialty text not null default 'physio' references public.specialties(code),
  name text not null,
  description text not null,
  body_region text not null,
  camera_view text not null check (camera_view in ('front','side')),
  default_reps smallint not null check (default_reps between 1 and 100),
  precautions text not null default '',
  camera_supported boolean not null default true
);
insert into public.exercise_catalog values
  ('bicep_curl', 'physio', 'Flexión de codo (curl de bíceps)',
   'Codos pegados al cuerpo; dobla el codo llevando la mano hacia el hombro y regresa con el brazo extendido.',
   'Miembro superior', 'front', 10, 'Detente si aparece dolor intenso.', true),
  ('quadriceps_stretch', 'physio', 'Estiramiento de cuádriceps',
   'Apóyate en una pared o silla, toma tu tobillo y lleva el talón hacia el glúteo; regresa a la posición de pie.',
   'Miembro inferior', 'side', 10, 'Usa apoyo para mantener el equilibrio.', true),
  ('shoulder_raise', 'physio', 'Elevación de brazos por encima de la cabeza',
   'Con los brazos extendidos, elévalos por los lados hasta arriba de la cabeza y bájalos de forma controlada.',
   'Hombro', 'front', 10, 'No fuerces el rango si hay dolor.', true),
  ('squat', 'physio', 'Sentadilla',
   'Desde de pie, baja la cadera como si te sentaras y vuelve a subir. Espalda recta y rodillas alineadas.',
   'Miembro inferior', 'side', 10, 'Coloca una silla detrás como seguridad.', true),
  ('knee_lift', 'physio', 'Elevación de rodilla de pie',
   'De pie y erguido, eleva la rodilla hasta la altura de la cadera y regresa con la pierna extendida.',
   'Cadera', 'side', 10, 'Sujétate de un apoyo estable.', true);
alter table public.exercise_catalog enable row level security;
revoke all on public.exercise_catalog from anon, authenticated;
grant select on public.exercise_catalog to authenticated;
create policy exercise_catalog_read on public.exercise_catalog for select to authenticated using (true);

alter table public.care_activities
  add column exercise_code text references public.exercise_catalog(code),
  add column target_reps smallint check (target_reps between 1 and 100),
  add column target_sets smallint check (target_sets between 1 and 20);

-- ---------------------------------------------------------------------------
-- 4. Exercise results on records + video evidence for physio.
-- ---------------------------------------------------------------------------
alter table public.care_records
  add column exercise_metrics jsonb check (exercise_metrics is null or (
    jsonb_typeof(exercise_metrics) = 'object' and octet_length(exercise_metrics::text) <= 8000)),
  add column pain_after smallint check (pain_after between 0 and 10);

alter table public.consents drop constraint consents_purpose_check;
alter table public.consents add constraint consents_purpose_check
  check (purpose in ('tracking','images','video','location','analytics'));

create or replace function public.validate_care_record() returns trigger
language plpgsql set search_path = '' as $$
declare sp text;
begin
  select specialty into sp from public.care_sessions where id = new.session_id;
  if (new.pain is not null or new.pain_after is not null or new.exercise_metrics is not null) and sp <> 'physio' then
    raise exception 'dolor/métricas de ejercicio solo aplican a fisioterapia';
  end if;
  if new.laterality is not null and sp <> 'eyes' then raise exception 'laterality solo aplica a oftalmología'; end if;
  if new.mood is not null and sp <> 'mind' then raise exception 'mood solo aplica a psicología'; end if;
  if new.body_zone is not null and sp <> 'skin' then raise exception 'zona solo aplica a dermatología'; end if;
  if new.evidence_path is not null and sp not in ('skin','physio') then
    raise exception 'evidencia solo aplica a dermatología y fisioterapia';
  end if;
  if new.evidence_path is not null
     and new.evidence_path not like new.session_id::text || '/' || new.patient_id::text || '/%' then
    raise exception 'ruta de evidencia no válida';
  end if;
  new.created_at := now();
  return new;
end;
$$;

update storage.buckets
  set file_size_limit = 52428800,
      allowed_mime_types = array['image/jpeg','image/png','video/mp4','video/quicktime']
  where id = 'care-evidence';

create or replace function public.can_upload_evidence(p_name text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.care_sessions s
    where s.id::text = (storage.foldername(p_name))[1]
      and s.patient_id::text = (storage.foldername(p_name))[2]
      and s.patient_id = (select auth.uid()) and s.active
      and ((s.specialty = 'skin' and public.has_consent((select auth.uid()), 'images'))
        or (s.specialty = 'physio' and public.has_consent((select auth.uid()), 'video'))));
$$;

commit;
