-- Med Box RLS smoke test. Run in the Supabase SQL editor AFTER both migrations.
-- Everything runs inside one transaction and is rolled back: no data remains.
-- Success = final row 'RLS OK'. Any failure raises an exception naming the check.
begin;

-- Synthetic users (two patients, two physio specialists).
insert into auth.users(id, instance_id, aud, role, email, email_confirmed_at) values
  ('10000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'p1@test.medbox', now()),
  ('10000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'p2@test.medbox', now()),
  ('20000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 's1@test.medbox', now()),
  ('20000000-0000-4000-8000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 's2@test.medbox', now());
select public.provision_specialist('s1@test.medbox', 'Esp. Ficticia Uno', array['physio']);
select public.provision_specialist('s2@test.medbox', 'Esp. Ficticia Dos', array['physio']);


-- 1. Patient cannot self-promote; role column is not writable.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$ begin
  begin
    update public.profiles set role = 'specialist';
    raise exception 'FAIL 1: patient changed role';
  exception when insufficient_privilege then null; end;
  if (select public.my_role()->>'role') <> 'patient' then raise exception 'FAIL 1b'; end if;
  if (public.create_care_invite('physio', 'x@test.medbox'))->>'ok' = 'true' then
    raise exception 'FAIL 1c: patient issued invite';
  end if;
end $$;

-- 2. Specialist S1 issues invite for P1.
select set_config('request.jwt.claims', '{"sub":"20000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select set_config('t.code', public.create_care_invite('physio', 'p1@test.medbox')->>'code', true);
do $$ begin
  if current_setting('t.code', true) is null or length(current_setting('t.code')) <> 12 then raise exception 'FAIL 2'; end if;
  if (select count(*) from public.care_invites) <> 1 then raise exception 'FAIL 2b: invite not visible to owner'; end if;
end $$;
do $$ begin
  begin
    perform code_hash from public.care_invites;
    raise exception 'FAIL 2c: code_hash readable';
  exception when insufficient_privilege then null; end;
end $$;

-- 3. Another patient cannot use P1's code.
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$ begin
  if (public.request_care_link(current_setting('t.code')))->>'ok' = 'true' then raise exception 'FAIL 3'; end if;
end $$;

-- 4. P1 requests; no session yet.
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$ begin
  if (public.request_care_link(lower(current_setting('t.code'))))->>'ok' <> 'true' then raise exception 'FAIL 4'; end if;
  if (select count(*) from public.care_sessions) <> 0 then raise exception 'FAIL 4b: self-approved'; end if;
  if (select count(*) from public.my_link_requests() where status = 'pending') <> 1 then raise exception 'FAIL 4c'; end if;
end $$;

-- 5. S2 (same specialty, other professional) cannot see or approve.
select set_config('request.jwt.claims', '{"sub":"20000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$ declare rid uuid; begin
  if (select count(*) from public.specialist_link_requests()) <> 0 then raise exception 'FAIL 5'; end if;
  if (select count(*) from public.care_link_requests) <> 0 then raise exception 'FAIL 5b'; end if;
end $$;
reset role;
select set_config('t.req', (select id::text from public.care_link_requests limit 1), true);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"20000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$ begin
  if (public.approve_care_link(current_setting('t.req')::uuid, 'X'))->>'ok' = 'true' then raise exception 'FAIL 5c'; end if;
end $$;

-- 6. S1 approves; invite becomes single-use.
select set_config('request.jwt.claims', '{"sub":"20000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select set_config('t.session', public.approve_care_link(current_setting('t.req')::uuid, 'Rodilla', 'Ejercicios suaves')->>'session_id', true);
do $$ begin
  if current_setting('t.session', true) is null then raise exception 'FAIL 6'; end if;
  if not (select revoked from public.care_invites limit 1) then raise exception 'FAIL 6b'; end if;
  insert into public.care_activities(session_id, created_by, title)
    values (current_setting('t.session')::uuid, '20000000-0000-4000-8000-000000000001', 'Sentadilla asistida');
end $$;

-- 7. P1 sees session and activity; writes structured record; wrong-specialty field rejected.
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$ begin
  if (select count(*) from public.care_sessions) <> 1 then raise exception 'FAIL 7'; end if;
  if (select count(*) from public.care_activities) <> 1 then raise exception 'FAIL 7b'; end if;
  insert into public.care_records(session_id, patient_id, completed, pain, note)
    values (current_setting('t.session')::uuid, '10000000-0000-4000-8000-000000000001', true, 4, 'Ficticio');
  begin
    insert into public.care_records(session_id, patient_id, mood)
      values (current_setting('t.session')::uuid, '10000000-0000-4000-8000-000000000001', 'calm');
    raise exception 'FAIL 7c: mood accepted in physio';
  exception when raise_exception then
    if sqlerrm like 'FAIL%' then raise; end if;
  end;
  begin
    insert into public.care_reviews(session_id, record_id, specialist_id, body)
      select session_id, id, '10000000-0000-4000-8000-000000000001', 'auto' from public.care_records limit 1;
    raise exception 'FAIL 7d: patient wrote review';
  exception when insufficient_privilege then null; end;
end $$;

-- 8. P2 sees nothing and cannot write into P1's session.
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$ begin
  if (select count(*) from public.care_sessions) + (select count(*) from public.care_records)
     + (select count(*) from public.care_activities) <> 0 then raise exception 'FAIL 8'; end if;
  begin
    insert into public.care_records(session_id, patient_id, note)
      values (current_setting('t.session')::uuid, '10000000-0000-4000-8000-000000000002', 'intruso');
    raise exception 'FAIL 8b';
  exception when insufficient_privilege or foreign_key_violation then null; end;
end $$;

-- 9. S1 reviews; S2 cannot read or review.
select set_config('request.jwt.claims', '{"sub":"20000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$ begin
  if (select count(*) from public.care_records) <> 1 then raise exception 'FAIL 9'; end if;
  insert into public.care_reviews(session_id, record_id, specialist_id, body)
    select session_id, id, '20000000-0000-4000-8000-000000000001', 'Buen avance' from public.care_records;
end $$;
reset role;
select set_config('t.record', (select id::text from public.care_records limit 1), true);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"20000000-0000-4000-8000-000000000002","role":"authenticated"}', true);
do $$ begin
  if (select count(*) from public.care_records) + (select count(*) from public.care_reviews) <> 0 then raise exception 'FAIL 9b'; end if;
  begin
    insert into public.care_reviews(session_id, record_id, specialist_id, body)
      values (current_setting('t.session')::uuid, current_setting('t.record')::uuid, '20000000-0000-4000-8000-000000000002', 'x');
    raise exception 'FAIL 9c';
  exception when insufficient_privilege then null; end;
end $$;

-- 10. Closing the session removes specialist access; patient keeps history.
select set_config('request.jwt.claims', '{"sub":"20000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$ begin
  if (public.close_care_session(current_setting('t.session')::uuid))->>'ok' <> 'true' then raise exception 'FAIL 10'; end if;
  if (select count(*) from public.care_records) <> 0 then raise exception 'FAIL 10b'; end if;
end $$;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$ begin
  if (select count(*) from public.care_records) <> 1 or (select count(*) from public.care_reviews) <> 1 then
    raise exception 'FAIL 10c';
  end if;
end $$;

-- 11. Anonymous: no clinical access; published prevention catalog readable.
reset role;
set local role anon;
do $$ begin
  begin
    perform 1 from public.care_sessions;
    raise exception 'FAIL 11';
  exception when insufficient_privilege then null; end;
  if (select count(*) from public.prevention_rules) < 1 then raise exception 'FAIL 11b'; end if;
end $$;

reset role;
rollback;
select 'RLS OK' as result;
