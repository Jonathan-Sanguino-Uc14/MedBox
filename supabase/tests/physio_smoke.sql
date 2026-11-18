-- Med Box physio flow smoke test (after migrations 0001-0003). Rolled back; leaves no data.
-- Success = final row 'FISIO OK'.
begin;
insert into auth.users(id, instance_id, aud, role, email, email_confirmed_at) values
  ('10000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'p1@test.medbox', now()),
  ('20000000-0000-4000-8000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'f1@test.medbox', now());
set local role authenticated;

-- Physio self-registers (unverified) and cannot self-verify.
select set_config('request.jwt.claims', '{"sub":"20000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$ begin
  if (public.register_as_specialist('Lic. Ficticia', 'physio', 'abc-123'))->>'ok' <> 'true' then raise exception 'FAIL A1'; end if;
  if (public.my_role()->>'role') <> 'specialist' or (public.my_role()->>'verified')::boolean then raise exception 'FAIL A2'; end if;
  begin
    update public.specialists set verified = true;
    raise exception 'FAIL A3: self-verified';
  exception when insufficient_privilege then null; end;
end $$;
select set_config('t.code', public.create_care_invite('physio', 'p1@test.medbox')->>'code', true);

-- Patient requests link.
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$ begin
  if (public.request_care_link(current_setting('t.code')))->>'ok' <> 'true' then raise exception 'FAIL B1'; end if;
end $$;
reset role;
select set_config('t.req', (select id::text from public.care_link_requests limit 1), true);
set local role authenticated;

-- Physio approves and assigns a camera exercise.
select set_config('request.jwt.claims', '{"sub":"20000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
select set_config('t.session', public.approve_care_link(current_setting('t.req')::uuid, 'Rodilla')->>'session_id', true);
do $$ begin
  if (select count(*) from public.exercise_catalog) <> 5 then raise exception 'FAIL C1'; end if;
  insert into public.care_activities(session_id, created_by, title, exercise_code, target_reps, target_sets)
    values (current_setting('t.session')::uuid, '20000000-0000-4000-8000-000000000001', 'Sentadilla', 'squat', 10, 2);
end $$;

-- Patient: video upload needs consent; record with metrics.
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$ declare act uuid; p text; begin
  select id into act from public.care_activities;
  if act is null then raise exception 'FAIL D1'; end if;
  p := current_setting('t.session') || '/10000000-0000-4000-8000-000000000001/x.mp4';
  if public.can_upload_evidence(p) then raise exception 'FAIL D2: upload without consent'; end if;
  insert into public.consents(user_id, purpose, granted) values ('10000000-0000-4000-8000-000000000001', 'video', true);
  if not public.can_upload_evidence(p) then raise exception 'FAIL D3'; end if;
  insert into public.care_records(session_id, patient_id, activity_id, completed, exercise_metrics, pain_after, evidence_path)
    values (current_setting('t.session')::uuid, '10000000-0000-4000-8000-000000000001', act, true,
            '{"exercise":"squat","complete_reps":20,"target_reps":20,"pattern_ok":true}', 2, p);
end $$;

-- Physio reads metrics and may read the video.
select set_config('request.jwt.claims', '{"sub":"20000000-0000-4000-8000-000000000001","role":"authenticated"}', true);
do $$ begin
  if (select exercise_metrics->>'complete_reps' from public.care_records limit 1) <> '20' then raise exception 'FAIL E1'; end if;
  if not public.can_read_evidence((select evidence_path from public.care_records limit 1)) then raise exception 'FAIL E2'; end if;
end $$;
reset role;
rollback;
select 'FISIO OK' as result;
