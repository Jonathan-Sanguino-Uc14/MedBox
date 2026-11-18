-- Med Box agenda smoke test (after migrations 0001-0008). Rolled back; leaves no data.
-- Success = final row 'AGENDA OK'.
begin;
insert into auth.users(id, instance_id, aud, role, email, email_confirmed_at) values
  ('10000000-0000-4000-8000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pa@test.medbox', now()),
  ('10000000-0000-4000-8000-0000000000a2', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'pb@test.medbox', now()),
  ('20000000-0000-4000-8000-0000000000a1', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'fa@test.medbox', now());
set local role authenticated;

-- Especialista se registra, invita; paciente A se vincula; especialista aprueba.
select set_config('request.jwt.claims', '{"sub":"20000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true);
do $$ begin
  if (public.register_as_specialist('Lic. Agenda', 'physio', 'ag-001'))->>'ok' <> 'true' then raise exception 'FAIL A1'; end if;
end $$;
select set_config('t.code', public.create_care_invite('physio', 'pa@test.medbox')->>'code', true);
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true);
do $$ begin
  if (public.request_care_link(current_setting('t.code')))->>'ok' <> 'true' then raise exception 'FAIL A2'; end if;
end $$;
reset role;
select set_config('t.req', (select id::text from public.care_link_requests where patient_id = '10000000-0000-4000-8000-0000000000a1' limit 1), true);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"20000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true);
select set_config('t.session', public.approve_care_link(current_setting('t.req')::uuid, 'Rodilla')->>'session_id', true);

-- Especialista define horario: todos los días 09:00-14:00, 45 min + 15 de margen.
do $$ begin
  insert into public.scheduling_settings(specialist_id) values ('20000000-0000-4000-8000-0000000000a1');
  insert into public.availability_rules(specialist_id, weekday, start_time, end_time)
    select '20000000-0000-4000-8000-0000000000a1', w, '09:00', '14:00' from generate_series(1, 7) w;
end $$;

-- Paciente A: ve 5 huecos mañana, reserva uno, no puede duplicar ni inventar horario.
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true);
do $$ declare
  sid uuid := current_setting('t.session')::uuid;
  d date := (now() at time zone 'America/Cancun')::date + 1;
  first_slot timestamptz; r jsonb; n int;
begin
  select count(*), min(slot_start) into n, first_slot from public.get_available_slots(sid, d, 1);
  if n <> 5 then raise exception 'FAIL B1: % huecos', n; end if;
  r := public.book_appointment(sid, first_slot, 'in_person', 'assistant');
  if r->>'ok' <> 'true' or r->>'status' <> 'confirmed' then raise exception 'FAIL B2: %', r; end if;
  if (select source from public.appointments where id = (r->>'appointment_id')::uuid) <> 'assistant' then raise exception 'FAIL B3'; end if;
  if (select count(*) from public.get_available_slots(sid, d, 1)) <> 4 then raise exception 'FAIL B4'; end if;
  if (public.book_appointment(sid, first_slot))->>'ok' = 'true' then raise exception 'FAIL B5: doble reserva'; end if;
  if (public.book_appointment(sid, first_slot + interval '30 minutes'))->>'ok' = 'true' then raise exception 'FAIL B6: horario inventado'; end if;
  begin
    insert into public.appointments(session_id, specialist_id, patient_id, period, source, created_by)
      values (sid, '20000000-0000-4000-8000-0000000000a1', '10000000-0000-4000-8000-0000000000a1',
              tstzrange(first_slot + interval '2 hours', first_slot + interval '3 hours'), 'patient', '10000000-0000-4000-8000-0000000000a1');
    raise exception 'FAIL B7: insert directo';
  exception when insufficient_privilege then null; end;
  -- Reagendar a las 12:00 locales.
  r := public.reschedule_appointment((select id from public.appointments where status = 'confirmed' limit 1),
                                     ((d + time '12:00') at time zone 'America/Cancun'), 'assistant');
  if r->>'ok' <> 'true' then raise exception 'FAIL B8: %', r; end if;
  if (select count(*) from public.appointments where status = 'confirmed') <> 1
     or (select count(*) from public.appointments where status = 'cancelled') <> 1 then raise exception 'FAIL B9'; end if;
  -- Reagendar a un hueco inválido no cambia nada.
  r := public.reschedule_appointment((r->>'appointment_id')::uuid, ((d + time '12:20') at time zone 'America/Cancun'));
  if r->>'ok' = 'true' or (select count(*) from public.appointments where status = 'confirmed') <> 1 then raise exception 'FAIL B10'; end if;
end $$;

-- Paciente B (sin vínculo): no ve citas ni huecos ni puede reservar.
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-0000000000a2","role":"authenticated"}', true);
do $$ begin
  if (select count(*) from public.appointments) <> 0 then raise exception 'FAIL C1'; end if;
  if (select count(*) from public.get_available_slots(current_setting('t.session')::uuid, null, 7)) <> 0 then raise exception 'FAIL C2'; end if;
  if (public.book_appointment(current_setting('t.session')::uuid, now() + interval '1 day'))->>'ok' = 'true' then raise exception 'FAIL C3'; end if;
  if (select count(*) from public.availability_rules) <> 0 then raise exception 'FAIL C4'; end if;
end $$;

-- Especialista ve la cita y la cancela; queda auditado.
select set_config('request.jwt.claims', '{"sub":"20000000-0000-4000-8000-0000000000a1","role":"authenticated"}', true);
do $$ begin
  if (select count(*) from public.appointments where status = 'confirmed') <> 1 then raise exception 'FAIL D1'; end if;
  if (public.cancel_appointment((select id from public.appointments where status = 'confirmed')))->>'ok' <> 'true' then raise exception 'FAIL D2'; end if;
end $$;
reset role;
do $$ begin
  if (select count(*) from public.access_audit where action like 'appointment.%' and ok) < 4 then raise exception 'FAIL E1'; end if;
end $$;
select 'AGENDA OK';
rollback;
