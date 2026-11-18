-- Physical exercise assignments belong only to physiotherapy sessions.
begin;
create or replace function public.validate_activity_exercise() returns trigger
language plpgsql security definer set search_path = '' as $$
declare session_specialty text;
begin
 select specialty into session_specialty from public.care_sessions where id = new.session_id;
 if (new.exercise_code is not null or new.target_reps is not null or new.target_sets is not null)
    and session_specialty is distinct from 'physio' then
   raise exception 'Los ejercicios físicos y repeticiones solo se asignan en fisioterapia';
 end if;
 if new.exercise_code is not null and not exists (
   select 1 from public.exercise_catalog e where e.code = new.exercise_code
   and e.specialty = 'physio' and e.active
   and (e.created_by is null or e.created_by = new.created_by)) then
   raise exception 'Ejercicio de fisioterapia no disponible';
 end if;
 return new;
end;
$$;
drop trigger care_activities_exercise on public.care_activities;
create trigger care_activities_exercise before insert or update on public.care_activities
 for each row execute function public.validate_activity_exercise();
commit;
