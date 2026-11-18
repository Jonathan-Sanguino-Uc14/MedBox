-- Professional record for physiotherapy and ophthalmology too (profile + session notes).
-- Same rules as 0005: only the specialist of the active session reads or appends.
begin;
drop policy clinical_notes_read on public.clinical_notes;
drop policy clinical_notes_insert on public.clinical_notes;
create policy clinical_notes_read on public.clinical_notes for select to authenticated using (
 exists (select 1 from public.care_sessions s where s.id = session_id
 and s.specialist_id = (select auth.uid()) and s.active)
);
create policy clinical_notes_insert on public.clinical_notes for insert to authenticated with check (
 author_id = (select auth.uid()) and exists (select 1 from public.care_sessions s where s.id = session_id
 and s.specialist_id = (select auth.uid()) and s.active
 and (s.specialty = 'skin' and section in ('profile','lesion','consultation','photo')
 or s.specialty = 'mind' and section in ('profile','assessment','consultation')
 or s.specialty in ('physio','eyes') and section in ('profile','consultation')))
);
commit;
