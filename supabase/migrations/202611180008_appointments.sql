-- Med Box 0008: agenda del especialista y citas (panel web, app del paciente y asistente de citas).
-- Una sola fuente de verdad: el panel, la app y la Edge Function chat-agent leen/escriben aquí.
-- Las citas solo se crean o cambian por funciones SECURITY DEFINER que auditan en access_audit.

create extension if not exists btree_gist with schema extensions;

-- ---------------------------------------------------------------------------
-- 1. Configuración y horario disponible del especialista
-- ---------------------------------------------------------------------------
create table public.scheduling_settings (
  specialist_id uuid primary key references public.specialists(user_id) on delete cascade,
  slot_minutes int not null default 45 check (slot_minutes between 10 and 240),
  buffer_minutes int not null default 15 check (buffer_minutes between 0 and 120),
  timezone text not null default 'America/Cancun' check (length(timezone) between 3 and 64),
  auto_confirm boolean not null default true,
  min_notice_minutes int not null default 60 check (min_notice_minutes between 0 and 10080),
  updated_at timestamptz not null default now()
);
create trigger scheduling_settings_touch before update on public.scheduling_settings
  for each row execute function public.touch_updated_at();

create table public.availability_rules (
  id uuid primary key default gen_random_uuid(),
  specialist_id uuid not null references public.specialists(user_id) on delete cascade,
  weekday smallint not null check (weekday between 1 and 7),   -- ISO: 1 = lunes … 7 = domingo
  start_time time not null,
  end_time time not null,
  created_at timestamptz not null default now(),
  check (start_time < end_time)
);
create index availability_rules_specialist_idx on public.availability_rules(specialist_id, weekday);

create table public.availability_exceptions (
  id uuid primary key default gen_random_uuid(),
  specialist_id uuid not null references public.specialists(user_id) on delete cascade,
  period tstzrange not null check (not isempty(period)),
  reason text not null default '' check (length(reason) <= 200),
  created_at timestamptz not null default now()
);
create index availability_exceptions_specialist_idx on public.availability_exceptions using gist (specialist_id, period);

-- ---------------------------------------------------------------------------
-- 2. Citas
-- ---------------------------------------------------------------------------
create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.care_sessions(id),
  specialist_id uuid not null references auth.users(id),
  patient_id uuid not null references auth.users(id),
  period tstzrange not null check (not isempty(period) and lower(period) < upper(period)),
  status text not null default 'confirmed' check (status in ('requested','confirmed','cancelled','completed','no_show')),
  modality text not null default 'in_person' check (modality in ('in_person','video')),
  source text not null check (source in ('specialist','patient','assistant')),
  notes text not null default '' check (length(notes) <= 1000),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(),
  cancelled_at timestamptz,
  cancelled_by uuid references auth.users(id),
  rescheduled_from uuid references public.appointments(id),
  -- Nunca dos citas vivas del mismo especialista que se crucen.
  constraint appointments_no_overlap exclude using gist (specialist_id with =, period with &&)
    where (status in ('requested','confirmed'))
);
create index appointments_patient_idx on public.appointments(patient_id, lower(period));
create index appointments_specialist_idx on public.appointments(specialist_id, lower(period));
create index appointments_session_idx on public.appointments(session_id);

-- ---------------------------------------------------------------------------
-- 3. RLS: deny by default
-- ---------------------------------------------------------------------------
alter table public.scheduling_settings enable row level security;
alter table public.availability_rules enable row level security;
alter table public.availability_exceptions enable row level security;
alter table public.appointments enable row level security;

create policy scheduling_settings_own on public.scheduling_settings for all to authenticated
  using (specialist_id = (select auth.uid())) with check (specialist_id = (select auth.uid()));
create policy availability_rules_own on public.availability_rules for all to authenticated
  using (specialist_id = (select auth.uid())) with check (specialist_id = (select auth.uid()));
create policy availability_exceptions_own on public.availability_exceptions for all to authenticated
  using (specialist_id = (select auth.uid())) with check (specialist_id = (select auth.uid()));

-- Lectura: el paciente ve sus citas; el especialista, las suyas. Escritura solo vía funciones.
create policy appointments_read on public.appointments for select to authenticated
  using (patient_id = (select auth.uid()) or specialist_id = (select auth.uid()));

revoke all on public.appointments from anon;
revoke insert, update, delete on public.appointments from authenticated;
grant select on public.appointments to authenticated;
grant select, insert, update, delete on public.scheduling_settings, public.availability_rules,
  public.availability_exceptions to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Funciones
-- ---------------------------------------------------------------------------

-- Sesión activa a la que el usuario actual pertenece (paciente o especialista).
create function public.appt_session_for_caller(p_session_id uuid) returns public.care_sessions
language sql stable security definer set search_path = '' as $$
  select s.* from public.care_sessions s
  where s.id = p_session_id and s.active
    and (s.patient_id = (select auth.uid()) or s.specialist_id = (select auth.uid()));
$$;
revoke all on function public.appt_session_for_caller(uuid) from public, anon, authenticated;

-- Horarios libres de una sesión (lo que ven la app, el panel y el asistente).
create function public.get_available_slots(p_session_id uuid, p_from date default null, p_days int default 7)
returns table(slot_start timestamptz, slot_end timestamptz)
language plpgsql stable security definer set search_path = '' as $$
declare
  s public.care_sessions;
  cfg public.scheduling_settings;
  tz text;
  first_day date;
begin
  s := public.appt_session_for_caller(p_session_id);
  if s.id is null then return; end if;
  select * into cfg from public.scheduling_settings where specialist_id = s.specialist_id;
  if not found then
    cfg.slot_minutes := 45; cfg.buffer_minutes := 15; cfg.timezone := 'America/Cancun'; cfg.min_notice_minutes := 60;
  end if;
  tz := cfg.timezone;
  first_day := coalesce(p_from, (now() at time zone tz)::date);
  return query
  with days as (
    select (first_day + g)::date as d from generate_series(0, least(greatest(coalesce(p_days, 7), 1), 31) - 1) g
  ), candidates as (
    select ((d + r.start_time + make_interval(mins => n * (cfg.slot_minutes + cfg.buffer_minutes))) at time zone tz) as st,
           ((d + r.start_time + make_interval(mins => n * (cfg.slot_minutes + cfg.buffer_minutes) + cfg.slot_minutes)) at time zone tz) as en
    from days
    join public.availability_rules r on r.specialist_id = s.specialist_id and r.weekday = extract(isodow from d)
    cross join lateral generate_series(0, 200) n
    where d + r.start_time + make_interval(mins => n * (cfg.slot_minutes + cfg.buffer_minutes) + cfg.slot_minutes)
          <= d + r.end_time
  )
  select c.st, c.en from candidates c
  where c.st >= now() + make_interval(mins => cfg.min_notice_minutes)
    and not exists (
      select 1 from public.appointments a
      where a.specialist_id = s.specialist_id and a.status in ('requested','confirmed')
        and a.period && tstzrange(c.st - make_interval(mins => cfg.buffer_minutes), c.en + make_interval(mins => cfg.buffer_minutes))
    )
    and not exists (
      select 1 from public.availability_exceptions x
      where x.specialist_id = s.specialist_id and x.period && tstzrange(c.st, c.en)
    )
  order by c.st;
end;
$$;

-- Crear cita. Paciente (o el asistente con su sesión): solo en un horario libre.
-- Especialista: en cualquier hueco que no choque.
create function public.book_appointment(p_session_id uuid, p_start timestamptz,
  p_modality text default 'in_person', p_source text default null, p_notes text default '')
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  s public.care_sessions;
  cfg public.scheduling_settings;
  is_pro boolean;
  src text;
  dur int;
  new_id uuid;
  st text;
begin
  s := public.appt_session_for_caller(p_session_id);
  if s.id is null then
    perform public.audit('appointment.book', 'care_session', p_session_id, false);
    return jsonb_build_object('ok', false, 'error', 'Sesión no disponible.');
  end if;
  is_pro := s.specialist_id = actor;
  if p_modality not in ('in_person','video') or length(coalesce(p_notes, '')) > 1000 then
    return jsonb_build_object('ok', false, 'error', 'Datos de la cita no válidos.');
  end if;
  src := case when is_pro then 'specialist' when p_source = 'assistant' then 'assistant' else 'patient' end;
  select * into cfg from public.scheduling_settings where specialist_id = s.specialist_id;
  dur := coalesce(cfg.slot_minutes, 45);
  if not is_pro and not exists (select 1 from public.get_available_slots(p_session_id, (p_start at time zone coalesce(cfg.timezone, 'America/Cancun'))::date, 1) g
                                where g.slot_start = p_start) then
    return jsonb_build_object('ok', false, 'error', 'Ese horario ya no está disponible.');
  end if;
  if is_pro and p_start < now() - interval '1 day' then
    return jsonb_build_object('ok', false, 'error', 'La fecha ya pasó.');
  end if;
  st := case when is_pro or coalesce(cfg.auto_confirm, true) then 'confirmed' else 'requested' end;
  begin
    insert into public.appointments(session_id, specialist_id, patient_id, period, status, modality, source, notes, created_by)
    values (s.id, s.specialist_id, s.patient_id, tstzrange(p_start, p_start + make_interval(mins => dur)),
            st, p_modality, src, coalesce(p_notes, ''), actor)
    returning id into new_id;
  exception when exclusion_violation then
    return jsonb_build_object('ok', false, 'error', 'Ese horario ya no está disponible.');
  end;
  perform public.audit('appointment.book', 'appointment', new_id);
  return jsonb_build_object('ok', true, 'appointment_id', new_id, 'status', st,
    'start', p_start, 'end', p_start + make_interval(mins => dur), 'professional_name', s.professional_name);
end;
$$;

-- Cancelar (paciente o especialista de la cita).
create function public.cancel_appointment(p_appointment_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  update public.appointments set status = 'cancelled', cancelled_at = now(), cancelled_by = auth.uid()
    where id = p_appointment_id and status in ('requested','confirmed')
      and (patient_id = auth.uid() or specialist_id = auth.uid());
  if not found then
    perform public.audit('appointment.cancel', 'appointment', p_appointment_id, false);
    return jsonb_build_object('ok', false, 'error', 'Cita no disponible.');
  end if;
  perform public.audit('appointment.cancel', 'appointment', p_appointment_id);
  return jsonb_build_object('ok', true);
end;
$$;

-- Reagendar: cancela la anterior y crea la nueva en una sola operación (o nada).
create function public.reschedule_appointment(p_appointment_id uuid, p_new_start timestamptz,
  p_source text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  old public.appointments;
  res jsonb;
begin
  select * into old from public.appointments
    where id = p_appointment_id and status in ('requested','confirmed')
      and (patient_id = auth.uid() or specialist_id = auth.uid())
    for update;
  if not found then return jsonb_build_object('ok', false, 'error', 'Cita no disponible.'); end if;
  begin
    update public.appointments set status = 'cancelled', cancelled_at = now(), cancelled_by = auth.uid()
      where id = old.id;
    res := public.book_appointment(old.session_id, p_new_start, old.modality, p_source, old.notes);
    if (res->>'ok')::boolean is not true then
      raise exception 'medbox_reschedule_failed';
    end if;
    update public.appointments set rescheduled_from = old.id where id = (res->>'appointment_id')::uuid;
  exception when raise_exception then
    return coalesce(res, jsonb_build_object('ok', false, 'error', 'No se pudo reagendar.'));
  end;
  perform public.audit('appointment.reschedule', 'appointment', old.id);
  return res || jsonb_build_object('previous_appointment_id', old.id);
end;
$$;

-- El especialista confirma una solicitud (cuando no tiene confirmación automática).
create function public.confirm_appointment(p_appointment_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  update public.appointments set status = 'confirmed'
    where id = p_appointment_id and status = 'requested' and specialist_id = auth.uid();
  if not found then return jsonb_build_object('ok', false, 'error', 'Cita no disponible.'); end if;
  perform public.audit('appointment.confirm', 'appointment', p_appointment_id);
  return jsonb_build_object('ok', true);
end;
$$;

-- Marcar atendida / no asistió (solo especialista, citas ya iniciadas).
create function public.close_appointment(p_appointment_id uuid, p_status text) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  if p_status not in ('completed','no_show') then
    return jsonb_build_object('ok', false, 'error', 'Estado no válido.');
  end if;
  update public.appointments set status = p_status
    where id = p_appointment_id and status = 'confirmed' and specialist_id = auth.uid()
      and lower(period) <= now();
  if not found then return jsonb_build_object('ok', false, 'error', 'Cita no disponible.'); end if;
  perform public.audit('appointment.' || p_status, 'appointment', p_appointment_id);
  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.get_available_slots(uuid, date, int),
  public.book_appointment(uuid, timestamptz, text, text, text),
  public.cancel_appointment(uuid), public.reschedule_appointment(uuid, timestamptz, text),
  public.confirm_appointment(uuid), public.close_appointment(uuid, text) from public, anon;
grant execute on function public.get_available_slots(uuid, date, int),
  public.book_appointment(uuid, timestamptz, text, text, text),
  public.cancel_appointment(uuid), public.reschedule_appointment(uuid, timestamptz, text),
  public.confirm_appointment(uuid), public.close_appointment(uuid, text) to authenticated;
