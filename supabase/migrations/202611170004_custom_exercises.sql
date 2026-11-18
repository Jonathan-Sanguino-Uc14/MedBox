-- Med Box: specialists create their own exercises with a demonstration video.
-- Patients see an exercise only when it is assigned in one of their sessions.
begin;

-- ---------------------------------------------------------------------------
-- 1. Catalog: built-in rows (created_by null) + specialist-owned rows.
-- ---------------------------------------------------------------------------
alter table public.exercise_catalog drop constraint exercise_catalog_code_check;
alter table public.exercise_catalog add constraint exercise_catalog_code_check
  check (code ~ '^[a-z0-9_]{3,40}$');
alter table public.exercise_catalog
  add column created_by uuid references auth.users(id) on delete cascade,
  add column detector text check (detector in ('bicep_curl','quadriceps_stretch','shoulder_raise','squat','knee_lift')),
  add column demo_video_path text check (length(demo_video_path) <= 300),
  add column demo_video_url text check (demo_video_url ~ '^https://' and length(demo_video_url) <= 500),
  add column active boolean not null default true,
  add column created_at timestamptz not null default now();
update public.exercise_catalog set detector = code where created_by is null;
alter table public.exercise_catalog add constraint exercise_catalog_text_limits
  check (length(name) between 3 and 120 and length(description) between 1 and 2000
         and length(body_region) <= 80 and length(precautions) <= 500);

create function public.validate_exercise() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.camera_supported := new.detector is not null;
  if new.demo_video_path is not null and new.created_by is not null
     and new.demo_video_path not like new.created_by::text || '/%' then
    raise exception 'ruta de video no válida';
  end if;
  return new;
end;
$$;
create trigger exercise_catalog_validate before insert or update on public.exercise_catalog
  for each row execute function public.validate_exercise();

drop policy exercise_catalog_read on public.exercise_catalog;
create policy exercise_catalog_read on public.exercise_catalog for select to authenticated
  using (
    (created_by is null and active)
    or created_by = (select auth.uid())
    or exists (
      select 1 from public.care_activities a
      join public.care_sessions s on s.id = a.session_id
      where a.exercise_code = exercise_catalog.code and s.patient_id = (select auth.uid()))
  );

grant insert (code, specialty, name, description, body_region, camera_view, default_reps,
              precautions, created_by, detector, demo_video_path, demo_video_url)
  on public.exercise_catalog to authenticated;
grant update (name, description, body_region, camera_view, default_reps, precautions,
              detector, demo_video_path, demo_video_url, active)
  on public.exercise_catalog to authenticated;
create policy exercise_owner_insert on public.exercise_catalog for insert to authenticated
  with check (created_by = (select auth.uid()) and public.is_specialist_for(specialty));
create policy exercise_owner_update on public.exercise_catalog for update to authenticated
  using (created_by = (select auth.uid())) with check (created_by = (select auth.uid()));

-- An activity may only use a built-in exercise or one owned by the assigning specialist.
create or replace function public.validate_activity_exercise() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.exercise_code is not null and not exists (
    select 1 from public.exercise_catalog e
    where e.code = new.exercise_code and e.active
      and (e.created_by is null or e.created_by = new.created_by)) then
    raise exception 'ejercicio no disponible';
  end if;
  return new;
end;
$$;
create trigger care_activities_exercise before insert or update of exercise_code on public.care_activities
  for each row execute function public.validate_activity_exercise();

-- ---------------------------------------------------------------------------
-- 2. Demonstration videos. Path: <specialist_id>/<uuid>.<ext>
-- ---------------------------------------------------------------------------
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('exercise-demos', 'exercise-demos', false, 52428800, array['video/mp4','video/webm','video/quicktime'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create function public.can_read_demo(p_name text) returns boolean
language sql stable security definer set search_path = '' as $$
  select (storage.foldername(p_name))[1] = (select auth.uid())::text
    or exists (
      select 1 from public.exercise_catalog e
      join public.care_activities a on a.exercise_code = e.code
      join public.care_sessions s on s.id = a.session_id
      where e.demo_video_path = p_name and s.patient_id = (select auth.uid()));
$$;
revoke all on function public.can_read_demo(text) from public, anon;
grant execute on function public.can_read_demo(text) to authenticated;

create policy exercise_demo_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'exercise-demos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (select 1 from public.specialists where user_id = (select auth.uid()) and active));
create policy exercise_demo_read on storage.objects for select to authenticated
  using (bucket_id = 'exercise-demos' and public.can_read_demo(name));

-- ---------------------------------------------------------------------------
-- 3. Neutral organization name (no "demo"/"ficticia" wording in the UI).
-- ---------------------------------------------------------------------------
update public.organizations set name = 'Med Box'
  where id = '00000000-0000-4000-8000-000000000001';

commit;
