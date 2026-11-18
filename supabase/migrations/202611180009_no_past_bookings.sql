-- Med Box 0009: ninguna cita puede reservarse en una fecha u hora pasada (paciente, asistente ni especialista).
-- Misma función que 0008 salvo el chequeo de fecha. Conserva firma, permisos y auditoría.

create or replace function public.book_appointment(p_session_id uuid, p_start timestamptz,
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
  -- Nadie reserva en el pasado (antes el especialista podía hasta un día atrás).
  if p_start <= now() then
    return jsonb_build_object('ok', false, 'error', 'Ese horario ya pasó. Elige otro.');
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
