-- Expediente profesional por sesión. Notas privadas, históricas y sin sobreescritura.
begin;
create table public.clinical_notes (
 id uuid primary key default gen_random_uuid(),
 session_id uuid not null references public.care_sessions(id),
 author_id uuid not null references auth.users(id),
 section text not null check (section in ('profile','lesion','consultation','assessment','photo')),
 fields jsonb not null check (jsonb_typeof(fields) = 'object' and octet_length(fields::text) <= 40000),
 created_at timestamptz not null default now()
);
create index clinical_notes_session_idx on public.clinical_notes(session_id, created_at desc);
alter table public.clinical_notes enable row level security;
revoke all on public.clinical_notes from anon, authenticated;
grant select on public.clinical_notes to authenticated;
grant insert (session_id,author_id,section,fields) on public.clinical_notes to authenticated;
create policy clinical_notes_read on public.clinical_notes for select to authenticated using (
 exists (select 1 from public.care_sessions s where s.id = session_id
 and s.specialist_id = (select auth.uid()) and s.active and s.specialty in ('skin','mind'))
);
create policy clinical_notes_insert on public.clinical_notes for insert to authenticated with check (
 author_id = (select auth.uid()) and exists (select 1 from public.care_sessions s where s.id = session_id
 and s.specialist_id = (select auth.uid()) and s.active
 and (s.specialty = 'skin' and section in ('profile','lesion','consultation','photo')
 or s.specialty = 'mind' and section in ('profile','assessment','consultation')))
);
-- Specialists may attach original images only with a recorded patient image consent.
create policy clinical_image_insert on storage.objects for insert to authenticated with check (
 bucket_id = 'care-evidence' and lower(storage.extension(name)) in ('jpg','jpeg','png')
 and exists (select 1 from public.care_sessions s
 where s.id::text = (storage.foldername(name))[1]
 and s.patient_id::text = (storage.foldername(name))[2]
 and s.specialist_id = (select auth.uid()) and s.active and s.specialty = 'skin'
 and public.has_consent(s.patient_id, 'images'))
);
commit;
