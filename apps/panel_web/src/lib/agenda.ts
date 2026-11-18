import { supabase } from "./supabase";
import { friendly } from "./data";
import type { Specialty } from "./data";

// Agenda (migración 0008). Misma fuente que la app del paciente y el asistente de citas.

export type AppointmentStatus = "requested" | "confirmed" | "cancelled" | "completed" | "no_show";
export type AppointmentSource = "specialist" | "patient" | "assistant";
export type Modality = "in_person" | "video";

export type Appointment = {
  id: string;
  session_id: string;
  patient_id: string;
  specialist_id: string;
  start: Date;
  end: Date;
  status: AppointmentStatus;
  modality: Modality;
  source: AppointmentSource;
  notes: string;
  session_title: string;
  specialty: Specialty | null;
};

export type SchedulingSettings = {
  slot_minutes: number;
  buffer_minutes: number;
  timezone: string;
  auto_confirm: boolean;
  min_notice_minutes: number;
};

export type AvailabilityRule = { id: string; weekday: number; start_time: string; end_time: string };
export type AvailabilityException = { id: string; start: Date; end: Date; reason: string };
export type Slot = { start: Date; end: Date };

export const DEFAULT_SETTINGS: SchedulingSettings = {
  slot_minutes: 45,
  buffer_minutes: 15,
  timezone: "America/Cancun",
  auto_confirm: true,
  min_notice_minutes: 60,
};

export const weekdayLabels = ["", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"];

export const statusText: Record<AppointmentStatus, string> = {
  requested: "Por confirmar",
  confirmed: "Confirmada",
  cancelled: "Cancelada",
  completed: "Atendida",
  no_show: "No asistió",
};

export const sourceText: Record<AppointmentSource, string> = {
  specialist: "Agendada por ti",
  patient: "Agendada por el paciente",
  assistant: "Agendada por el asistente",
};

/** Convierte un tstzrange de PostgREST ('["2026-11-19 15:00:00+00","…")') en fechas. */
export function parseRange(range: string): { start: Date; end: Date } {
  const inner = range.trim().replace(/^[[(]/, "").replace(/[\])]$/, "");
  const [a, b] = inner.split(",").map((s) => s.trim().replace(/^"|"$/g, ""));
  const fix = (s: string) => new Date(s.replace(" ", "T").replace(/([+-]\d{2})$/, "$1:00"));
  return { start: fix(a), end: fix(b) };
}

function rangeLiteral(start: Date, end: Date) {
  return `[${start.toISOString()},${end.toISOString()})`;
}

async function uid(): Promise<string> {
  const { data } = await supabase.auth.getUser();
  if (!data.user) throw new Error("Tu sesión expiró. Vuelve a entrar.");
  return data.user.id;
}

type AppointmentRow = {
  id: string;
  session_id: string;
  patient_id: string;
  specialist_id: string;
  period: string;
  status: AppointmentStatus;
  modality: Modality;
  source: AppointmentSource;
  notes: string;
  care_sessions: { title: string; specialty: Specialty } | { title: string; specialty: Specialty }[] | null;
};

/** Citas del especialista que se cruzan con [from, to). */
export async function appointmentsBetween(from: Date, to: Date): Promise<Appointment[]> {
  const me = await uid();
  const { data, error } = await supabase
    .from("appointments")
    .select("id, session_id, patient_id, specialist_id, period, status, modality, source, notes, care_sessions(title, specialty)")
    .eq("specialist_id", me)
    .overlaps("period", rangeLiteral(from, to))
    .order("period", { ascending: true });
  if (error) throw new Error(friendly(error.message));
  return ((data ?? []) as unknown as AppointmentRow[]).map((r) => {
    const s = Array.isArray(r.care_sessions) ? r.care_sessions[0] : r.care_sessions;
    return {
      id: r.id,
      session_id: r.session_id,
      patient_id: r.patient_id,
      specialist_id: r.specialist_id,
      ...parseRange(r.period),
      status: r.status,
      modality: r.modality,
      source: r.source,
      notes: r.notes,
      session_title: s?.title ?? "",
      specialty: s?.specialty ?? null,
    };
  });
}

/** Próxima cita viva de una sesión (expediente). */
export async function nextAppointmentForSession(sessionId: string): Promise<Appointment | null> {
  const now = new Date();
  const later = new Date(now.getTime() + 1000 * 60 * 60 * 24 * 120);
  const list = await appointmentsBetween(now, later);
  return list.find((a) => a.session_id === sessionId && (a.status === "confirmed" || a.status === "requested")) ?? null;
}

export async function getSettings(): Promise<SchedulingSettings> {
  const me = await uid();
  const { data, error } = await supabase
    .from("scheduling_settings")
    .select("slot_minutes, buffer_minutes, timezone, auto_confirm, min_notice_minutes")
    .eq("specialist_id", me)
    .maybeSingle();
  if (error) throw new Error(friendly(error.message));
  return (data as SchedulingSettings | null) ?? DEFAULT_SETTINGS;
}

export async function saveSettings(s: SchedulingSettings) {
  const me = await uid();
  const { error } = await supabase.from("scheduling_settings").upsert({ specialist_id: me, ...s });
  if (error) throw new Error(friendly(error.message));
}

export async function getRules(): Promise<AvailabilityRule[]> {
  const me = await uid();
  const { data, error } = await supabase
    .from("availability_rules")
    .select("id, weekday, start_time, end_time")
    .eq("specialist_id", me)
    .order("weekday")
    .order("start_time");
  if (error) throw new Error(friendly(error.message));
  return (data ?? []).map((r) => ({ ...r, start_time: r.start_time.slice(0, 5), end_time: r.end_time.slice(0, 5) }));
}

export async function addRule(weekday: number, start: string, end: string) {
  const me = await uid();
  if (start >= end) throw new Error("La hora de inicio debe ser antes que la de fin.");
  const { error } = await supabase
    .from("availability_rules")
    .insert({ specialist_id: me, weekday, start_time: start, end_time: end });
  if (error) throw new Error(friendly(error.message));
}

export async function deleteRule(id: string) {
  const { error } = await supabase.from("availability_rules").delete().eq("id", id);
  if (error) throw new Error(friendly(error.message));
}

export async function getExceptions(): Promise<AvailabilityException[]> {
  const me = await uid();
  const { data, error } = await supabase
    .from("availability_exceptions")
    .select("id, period, reason")
    .eq("specialist_id", me)
    .overlaps("period", rangeLiteral(new Date(), new Date(Date.now() + 1000 * 60 * 60 * 24 * 365)));
  if (error) throw new Error(friendly(error.message));
  return (data ?? []).map((r) => ({ id: r.id, reason: r.reason, ...parseRange(r.period) }));
}

export async function addException(start: Date, end: Date, reason: string) {
  const me = await uid();
  if (!(start < end)) throw new Error("El bloqueo debe terminar después de empezar.");
  const { error } = await supabase
    .from("availability_exceptions")
    .insert({ specialist_id: me, period: rangeLiteral(start, end), reason: reason.slice(0, 200) });
  if (error) throw new Error(friendly(error.message));
}

export async function deleteException(id: string) {
  const { error } = await supabase.from("availability_exceptions").delete().eq("id", id);
  if (error) throw new Error(friendly(error.message));
}

/** Huecos libres de una sesión (el mismo cálculo que ve el paciente). */
export async function availableSlots(sessionId: string, fromDay: string, days = 1): Promise<Slot[]> {
  const { data, error } = await supabase.rpc("get_available_slots", {
    p_session_id: sessionId,
    p_from: fromDay,
    p_days: days,
  });
  if (error) throw new Error(friendly(error.message));
  return ((data ?? []) as Array<{ slot_start: string; slot_end: string }>).map((s) => ({
    start: new Date(s.slot_start),
    end: new Date(s.slot_end),
  }));
}

type RpcResult = { ok: boolean; error?: string; appointment_id?: string };

async function rpc(name: string, args: Record<string, unknown>): Promise<RpcResult> {
  const { data, error } = await supabase.rpc(name, args);
  if (error) throw new Error(friendly(error.message));
  const res = data as RpcResult;
  if (!res?.ok) throw new Error(res?.error ?? "No se pudo completar.");
  return res;
}

export function bookAppointment(sessionId: string, start: Date, modality: Modality, notes = "") {
  return rpc("book_appointment", {
    p_session_id: sessionId,
    p_start: start.toISOString(),
    p_modality: modality,
    p_notes: notes,
  });
}

export function cancelAppointment(id: string) {
  return rpc("cancel_appointment", { p_appointment_id: id });
}

export function confirmAppointment(id: string) {
  return rpc("confirm_appointment", { p_appointment_id: id });
}

export function closeAppointment(id: string, status: "completed" | "no_show") {
  return rpc("close_appointment", { p_appointment_id: id, p_status: status });
}

// ---------------------------------------------------------------------------
// Fechas en la zona horaria del consultorio
// ---------------------------------------------------------------------------

/** Partes de fecha/hora de `d` vistas en la zona `tz`. */
export function zoned(d: Date, tz: string) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: tz,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(d);
  const get = (t: string) => Number(parts.find((p) => p.type === t)?.value);
  return { y: get("year"), m: get("month"), d: get("day"), h: get("hour"), min: get("minute") };
}

/** 'YYYY-MM-DD' del día local de `d` en `tz`. */
export function dayKey(d: Date, tz: string) {
  const z = zoned(d, tz);
  return `${z.y}-${String(z.m).padStart(2, "0")}-${String(z.d).padStart(2, "0")}`;
}

/** Suma días a una clave 'YYYY-MM-DD'. */
export function addDays(key: string, n: number) {
  const [y, m, d] = key.split("-").map(Number);
  const t = new Date(Date.UTC(y, m - 1, d + n));
  return t.toISOString().slice(0, 10);
}

/** Día ISO de la semana (1 = lunes … 7 = domingo) de una clave 'YYYY-MM-DD'. */
export function isoWeekday(key: string) {
  const [y, m, d] = key.split("-").map(Number);
  const w = new Date(Date.UTC(y, m - 1, d)).getUTCDay();
  return w === 0 ? 7 : w;
}

/** Instante UTC que corresponde a la hora local `hhmm` del día `key` en `tz`. */
export function localToDate(key: string, hhmm: string, tz: string) {
  const [y, m, d] = key.split("-").map(Number);
  const [h, mi] = hhmm.split(":").map(Number);
  const guess = new Date(Date.UTC(y, m - 1, d, h, mi));
  const z = zoned(guess, tz);
  const shown = Date.UTC(z.y, z.m - 1, z.d, z.h, z.min);
  return new Date(guess.getTime() - (shown - guess.getTime()));
}

export function formatTime(d: Date, tz: string) {
  return new Intl.DateTimeFormat("es-MX", { timeZone: tz, hour: "2-digit", minute: "2-digit", hourCycle: "h23" }).format(d);
}

export function formatDay(key: string, opts: Intl.DateTimeFormatOptions = { weekday: "short", day: "numeric" }) {
  const [y, m, d] = key.split("-").map(Number);
  return new Intl.DateTimeFormat("es-MX", { timeZone: "UTC", ...opts }).format(new Date(Date.UTC(y, m - 1, d, 12)));
}
