"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import type { ReactNode } from "react";
import { useSpecialist } from "@/lib/use-specialist";
import { patientNames, sessions } from "@/lib/data";
import type { CareSession } from "@/lib/data";
import {
  DEFAULT_SETTINGS,
  addDays,
  addException,
  addRule,
  appointmentsBetween,
  availableSlots,
  bookAppointment,
  cancelAppointment,
  closeAppointment,
  confirmAppointment,
  dayKey,
  deleteException,
  deleteRule,
  formatDay,
  formatTime,
  getExceptions,
  getRules,
  getSettings,
  isoWeekday,
  localToDate,
  saveSettings,
  sourceText,
  statusText,
  weekdayLabels,
  zoned,
} from "@/lib/agenda";
import type {
  Appointment,
  AvailabilityException,
  AvailabilityRule,
  Modality,
  SchedulingSettings,
  Slot,
} from "@/lib/agenda";

const HOUR_PX = 64;

const look: Record<string, { bg: string; fg: string }> = {
  specialist: { bg: "#E8F6F3", fg: "#0B5E57" },
  assistant: { bg: "#E3EBFF", fg: "#1A3FA3" },
  patient: { bg: "#E3EBFF", fg: "#1A3FA3" },
  video: { bg: "#F1F4F8", fg: "#334155" },
  requested: { bg: "#FFF6E5", fg: "#8A5300" },
};

function mondayOf(key: string) {
  return addDays(key, 1 - isoWeekday(key));
}

const btn =
  "inline-flex min-h-[44px] items-center justify-center gap-2 rounded-xl px-4 text-sm font-semibold transition disabled:opacity-50";
const btnPrimary = `${btn} bg-[#2457D6] text-white hover:bg-[#1A3FA3]`;
const btnGhost = `${btn} border border-[#D5DCE7] bg-white text-[#0F172A] hover:bg-[#F5F7FA]`;
const field =
  "min-h-[44px] w-full min-w-0 max-w-full rounded-xl border border-[#D5DCE7] bg-white px-3 text-sm text-[#0F172A] focus:outline-none focus:ring-2 focus:ring-[#2457D6]";
const card = "min-w-0 rounded-2xl border border-[#E5E9F0] bg-white p-5";

export default function AgendaPage() {
  const { specialty } = useSpecialist();
  const [settings, setSettings] = useState<SchedulingSettings>(DEFAULT_SETTINGS);
  const tz = settings.timezone;
  const [weekStart, setWeekStart] = useState(() => mondayOf(dayKey(new Date(), DEFAULT_SETTINGS.timezone)));
  const [view, setView] = useState<"week" | "day">("week");
  const [dayFocus, setDayFocus] = useState(() => dayKey(new Date(), DEFAULT_SETTINGS.timezone));
  const [appts, setAppts] = useState<Appointment[]>([]);
  const [rules, setRules] = useState<AvailabilityRule[]>([]);
  const [exceptions, setExceptions] = useState<AvailabilityException[]>([]);
  const [patients, setPatients] = useState<CareSession[]>([]);
  const [names, setNames] = useState<Record<string, string>>({});
  const [selected, setSelected] = useState<Appointment | null>(null);
  const [newOpen, setNewOpen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const today = dayKey(new Date(), tz);
  const days = useMemo(() => {
    if (view === "day") return [dayFocus];
    const n = rules.some((r) => r.weekday === 7) ? 7 : 6;
    return Array.from({ length: n }, (_, i) => addDays(weekStart, i));
  }, [view, dayFocus, weekStart, rules]);

  const [startHour, endHour] = useMemo(() => {
    let lo = 8;
    let hi = 19;
    for (const r of rules) {
      lo = Math.min(lo, Number(r.start_time.slice(0, 2)));
      hi = Math.max(hi, Math.ceil(Number(r.end_time.slice(0, 2)) + Number(r.end_time.slice(3, 5)) / 60));
    }
    for (const a of appts) {
      const s = zoned(a.start, tz);
      const e = zoned(a.end, tz);
      lo = Math.min(lo, s.h);
      hi = Math.max(hi, e.h + (e.min > 0 ? 1 : 0));
    }
    return [lo, Math.min(24, hi)];
  }, [rules, appts, tz]);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const s = await getSettings();
      setSettings(s);
      const from = localToDate(days[0], "00:00", s.timezone);
      const to = localToDate(addDays(days[days.length - 1], 1), "00:00", s.timezone);
      const [a, r, x, ss] = await Promise.all([appointmentsBetween(from, to), getRules(), getExceptions(), sessions()]);
      const active = ss.filter((v) => v.active && v.specialty === specialty);
      setAppts(a.filter((v) => v.status !== "cancelled"));
      setRules(r);
      setExceptions(x);
      setPatients(active);
      setNames(await patientNames([...new Set([...a.map((v) => v.patient_id), ...active.map((v) => v.patient_id)])]));
      setError(null);
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setLoading(false);
    }
  }, [days, specialty]);

  useEffect(() => {
    void load();
  }, [load]);

  const move = (n: number) => {
    if (view === "day") setDayFocus(addDays(dayFocus, n));
    else setWeekStart(addDays(weekStart, 7 * n));
  };
  const goToday = () => {
    setDayFocus(today);
    setWeekStart(mondayOf(today));
  };

  const rangeTitle =
    view === "day"
      ? formatDay(dayFocus, { weekday: "long", day: "numeric", month: "long" })
      : `${formatDay(days[0], { day: "numeric", month: "short" })} – ${formatDay(days[days.length - 1], {
          day: "numeric",
          month: "short",
        })}`;

  const hours = Array.from({ length: endHour - startHour }, (_, i) => startHour + i);
  const gridH = hours.length * HOUR_PX;

  const act = async (fn: () => Promise<unknown>) => {
    try {
      await fn();
      setSelected(null);
      await load();
    } catch (e) {
      setError((e as Error).message);
    }
  };

  return (
    <div className="mx-auto flex max-w-[1440px] flex-col gap-5 text-[#0F172A]">
      <header className="flex flex-wrap items-center justify-between gap-4">
        <div className="flex flex-wrap items-center gap-3">
          <h1 className="font-heading text-[28px] font-extrabold tracking-tight">Agenda</h1>
          <span className="text-[15px] font-medium capitalize text-[#5B6475]">{rangeTitle}</span>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <div className="flex rounded-xl border border-[#E5E9F0] bg-white p-1" role="group" aria-label="Vista">
            {(["day", "week"] as const).map((v) => (
              <button
                key={v}
                type="button"
                aria-pressed={view === v}
                onClick={() => setView(v)}
                className={`min-h-[36px] rounded-lg px-3 text-[13px] font-semibold ${
                  view === v ? "bg-[#EEF3FF] text-[#1A3FA3]" : "text-[#5B6475]"
                }`}
              >
                {v === "day" ? "Día" : "Semana"}
              </button>
            ))}
          </div>
          <button type="button" className={btnGhost} onClick={() => move(-1)} aria-label="Anterior">
            ‹
          </button>
          <button type="button" className={btnGhost} onClick={goToday}>
            Hoy
          </button>
          <button type="button" className={btnGhost} onClick={() => move(1)} aria-label="Siguiente">
            ›
          </button>
          <button type="button" className={btnPrimary} onClick={() => setNewOpen(true)} disabled={!patients.length}>
            Nueva cita
          </button>
        </div>
      </header>

      {error && (
        <p role="alert" className="rounded-xl bg-[#FDF0F0] px-4 py-3 text-sm text-[#A12A2A]">
          {error}
        </p>
      )}

      <div className="flex flex-wrap items-start gap-6">
        <section aria-label="Calendario" className="min-w-0 flex-[999_1_640px] overflow-x-auto rounded-2xl border border-[#E5E9F0] bg-white">
          <div style={{ minWidth: view === "day" ? 360 : 760 }}>
            <div className="grid border-b border-[#E5E9F0]" style={{ gridTemplateColumns: `64px repeat(${days.length}, minmax(0,1fr))` }}>
              <span />
              {days.map((d) => (
                <button
                  key={d}
                  type="button"
                  onClick={() => {
                    setDayFocus(d);
                    setView("day");
                  }}
                  className="flex flex-col items-center gap-0.5 px-2 py-3"
                  aria-label={`Ver ${formatDay(d, { weekday: "long", day: "numeric", month: "long" })}`}
                >
                  <span className="text-xs font-semibold uppercase text-[#5B6475]">{formatDay(d, { weekday: "short" })}</span>
                  <span
                    className={`font-heading flex h-9 w-9 items-center justify-center rounded-full text-xl font-extrabold ${
                      d === today ? "bg-[#2457D6] text-white" : ""
                    }`}
                  >
                    {Number(d.slice(8, 10))}
                  </span>
                </button>
              ))}
            </div>
            <div className="grid" style={{ gridTemplateColumns: `64px repeat(${days.length}, minmax(0,1fr))` }}>
              <div>
                {hours.map((h) => (
                  <div key={h} className="box-border pr-2 pt-1 text-right text-[11px] text-[#5B6475]" style={{ height: HOUR_PX }}>
                    {String(h).padStart(2, "0")}:00
                  </div>
                ))}
              </div>
              {days.map((d) => {
                const wd = isoWeekday(d);
                const open = rules.filter((r) => r.weekday === wd);
                const dayStart = localToDate(d, "00:00", tz);
                const dayEnd = localToDate(addDays(d, 1), "00:00", tz);
                const blocks = exceptions.filter((x) => x.start < dayEnd && x.end > dayStart);
                const items = appts.filter((a) => dayKey(a.start, tz) === d);
                const toY = (hh: number, mm: number) => (hh - startHour + mm / 60) * HOUR_PX;
                return (
                  <div
                    key={d}
                    className="relative border-l border-[#EEF1F5]"
                    style={{
                      height: gridH,
                      backgroundColor: "#F8F9FB",
                      backgroundImage: "linear-gradient(#EEF1F5 1px, transparent 1px)",
                      backgroundSize: `100% ${HOUR_PX}px`,
                    }}
                  >
                    {open.map((r) => {
                      const top = toY(Number(r.start_time.slice(0, 2)), Number(r.start_time.slice(3, 5)));
                      const bottom = toY(Number(r.end_time.slice(0, 2)), Number(r.end_time.slice(3, 5)));
                      return (
                        <div
                          key={r.id}
                          aria-hidden="true"
                          className="absolute inset-x-0"
                          style={{
                            top,
                            height: bottom - top,
                            backgroundColor: d === today ? "#FAFCFF" : "#FFFFFF",
                            backgroundImage: "linear-gradient(#EEF1F5 1px, transparent 1px)",
                            backgroundSize: `100% ${HOUR_PX}px`,
                            backgroundPosition: `0 ${-top}px`,
                          }}
                        />
                      );
                    })}
                    {blocks.map((x) => {
                      const s = x.start < dayStart ? { h: startHour, min: 0 } : zoned(x.start, tz);
                      const e = x.end > dayEnd ? { h: endHour, min: 0 } : zoned(x.end, tz);
                      const top = Math.max(0, toY(s.h, s.min));
                      const bottom = Math.min(gridH, toY(e.h, e.min));
                      if (bottom <= top) return null;
                      return (
                        <div
                          key={x.id}
                          className="absolute inset-x-1 rounded-lg border border-dashed border-[#C9D1DD] bg-[repeating-linear-gradient(45deg,#F1F4F8,#F1F4F8_6px,#E9EDF2_6px,#E9EDF2_12px)] p-2 text-[11px] font-semibold text-[#475569]"
                          style={{ top, height: bottom - top }}
                        >
                          Bloqueado{x.reason ? ` · ${x.reason}` : ""}
                        </div>
                      );
                    })}
                    {items.map((a) => {
                      const s = zoned(a.start, tz);
                      const e = zoned(a.end, tz);
                      const top = toY(s.h, s.min) + 2;
                      const h = Math.max(28, toY(e.h, e.min) - toY(s.h, s.min) - 4);
                      const k =
                        a.status === "requested" ? "requested" : a.modality === "video" ? "video" : a.source;
                      const c = look[k];
                      const done = a.status === "completed" || a.status === "no_show";
                      return (
                        <button
                          key={a.id}
                          type="button"
                          onClick={() => setSelected(a)}
                          className="absolute inset-x-1.5 flex flex-col gap-0.5 overflow-hidden rounded-[10px] px-2.5 py-2 text-left focus:outline-none focus:ring-2 focus:ring-[#2457D6]"
                          style={{ top, height: h, background: c.bg, opacity: done ? 0.6 : 1 }}
                        >
                          <span className="text-xs font-bold" style={{ color: c.fg }}>
                            {formatTime(a.start, tz)}
                            {a.status === "requested" ? " · por confirmar" : ""}
                          </span>
                          <span className="truncate text-[13px] font-semibold">{names[a.patient_id] || "Paciente"}</span>
                          <span className="truncate text-[11px] text-[#475569]">
                            {a.modality === "video" ? "Videollamada" : sourceText[a.source]}
                          </span>
                        </button>
                      );
                    })}
                  </div>
                );
              })}
            </div>
          </div>
          {loading && <p className="px-5 py-3 text-sm text-[#5B6475]">Cargando…</p>}
        </section>

        <aside className="flex min-w-0 flex-[1_1_320px] flex-col gap-5">
          <Availability
            settings={settings}
            rules={rules}
            exceptions={exceptions}
            onChange={load}
          />
          <section aria-labelledby="leg" className={card}>
            <h2 id="leg" className="font-heading mb-3 text-[17px] font-bold">
              Origen de la cita
            </h2>
            <ul className="flex flex-col gap-2 text-[13px]">
              <li className="flex items-center gap-2.5"><span className="h-3.5 w-3.5 rounded bg-[#E8F6F3]" />Agendada por ti</li>
              <li className="flex items-center gap-2.5"><span className="h-3.5 w-3.5 rounded bg-[#E3EBFF]" />Agendada por el paciente o el asistente</li>
              <li className="flex items-center gap-2.5"><span className="h-3.5 w-3.5 rounded bg-[#F1F4F8]" />Videollamada</li>
              <li className="flex items-center gap-2.5"><span className="h-3.5 w-3.5 rounded bg-[#FFF6E5]" />Por confirmar</li>
            </ul>
          </section>
        </aside>
      </div>

      {selected && (
        <Dialog title="Cita" onClose={() => setSelected(null)}>
          <p className="font-heading text-lg font-extrabold">{names[selected.patient_id] || "Paciente"}</p>
          <p className="text-sm text-[#334155]">
            {formatDay(dayKey(selected.start, tz), { weekday: "long", day: "numeric", month: "long" })} ·{" "}
            {formatTime(selected.start, tz)}–{formatTime(selected.end, tz)}
          </p>
          <p className="text-sm text-[#5B6475]">
            {selected.session_title} · {selected.modality === "video" ? "Videollamada" : "Presencial"} ·{" "}
            {sourceText[selected.source]} · {statusText[selected.status]}
          </p>
          {selected.notes && <p className="rounded-xl bg-[#F5F7FA] p-3 text-sm">{selected.notes}</p>}
          <div className="mt-2 flex flex-wrap gap-2">
            <a href={`/paciente?id=${selected.session_id}`} className={btnGhost}>
              Abrir expediente
            </a>
            {selected.status === "requested" && (
              <button type="button" className={btnPrimary} onClick={() => act(() => confirmAppointment(selected.id))}>
                Confirmar
              </button>
            )}
            {selected.status === "confirmed" && selected.start <= new Date() && (
              <>
                <button type="button" className={btnPrimary} onClick={() => act(() => closeAppointment(selected.id, "completed"))}>
                  Marcar atendida
                </button>
                <button type="button" className={btnGhost} onClick={() => act(() => closeAppointment(selected.id, "no_show"))}>
                  No asistió
                </button>
              </>
            )}
            {(selected.status === "confirmed" || selected.status === "requested") && (
              <button
                type="button"
                className={`${btn} border border-[#F3C9C9] bg-white text-[#A12A2A] hover:bg-[#FDF0F0]`}
                onClick={() => {
                  if (window.confirm("¿Cancelar esta cita? El paciente la verá cancelada en su app.")) {
                    void act(() => cancelAppointment(selected.id));
                  }
                }}
              >
                Cancelar cita
              </button>
            )}
          </div>
        </Dialog>
      )}

      {newOpen && (
        <NewAppointment
          tz={tz}
          patients={patients}
          names={names}
          today={today}
          rules={rules}
          onClose={() => setNewOpen(false)}
          onDone={async () => {
            setNewOpen(false);
            await load();
          }}
        />
      )}
    </div>
  );
}

function Dialog({ title, onClose, children }: { title: string; onClose: () => void; children: ReactNode }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-[#0F172A]/40 p-4 sm:items-center" onClick={onClose}>
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        className="flex w-full max-w-md flex-col gap-2 rounded-2xl bg-white p-6 shadow-xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between">
          <h2 className="font-heading text-sm font-bold uppercase tracking-wide text-[#5B6475]">{title}</h2>
          <button type="button" onClick={onClose} aria-label="Cerrar" className="flex h-11 w-11 items-center justify-center rounded-xl text-xl text-[#5B6475] hover:bg-[#F5F7FA]">
            ×
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

function NewAppointment({
  tz,
  patients,
  names,
  today,
  rules,
  onClose,
  onDone,
}: {
  tz: string;
  patients: CareSession[];
  names: Record<string, string>;
  today: string;
  rules: AvailabilityRule[];
  onClose: () => void;
  onDone: () => Promise<void>;
}) {
  const [sessionId, setSessionId] = useState(patients[0]?.id ?? "");
  const openDays = new Set(rules.map((r) => r.weekday));
  const nextDays = Array.from({ length: 28 }, (_, i) => addDays(today, i));
  const [day, setDay] = useState(() => nextDays.find((d) => openDays.has(isoWeekday(d))) ?? today);
  const [slots, setSlots] = useState<Slot[] | null>(null);
  const [pick, setPick] = useState<Slot | null>(null);
  const [modality, setModality] = useState<Modality>("in_person");
  const [notes, setNotes] = useState("");
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    if (!sessionId) return;
    setSlots(null);
    setPick(null);
    availableSlots(sessionId, day, 1)
      .then((list) => setSlots(list.filter((s) => s.start > new Date())))
      .catch((e: Error) => setErr(e.message));
  }, [sessionId, day]);

  const submit = async () => {
    if (!pick) return;
    if (pick.start <= new Date()) {
      setErr("Ese horario ya pasó. Elige otro.");
      return;
    }
    setBusy(true);
    try {
      await bookAppointment(sessionId, pick.start, modality, notes);
      await onDone();
    } catch (e) {
      setErr((e as Error).message);
      setBusy(false);
    }
  };

  return (
    <Dialog title="Nueva cita" onClose={onClose}>
      <label className="flex flex-col gap-1 text-sm font-semibold">
        Paciente
        <select className={field} value={sessionId} onChange={(e) => setSessionId(e.target.value)}>
          {patients.map((p) => (
            <option key={p.id} value={p.id}>
              {(names[p.patient_id] || "Paciente") + " · " + p.title}
            </option>
          ))}
        </select>
      </label>
      <div className="flex min-w-0 flex-col gap-2">
        <span className="text-sm font-semibold">
          Día · <span className="font-normal capitalize text-[#334155]">{formatDay(day, { weekday: "long", day: "numeric", month: "long" })}</span>
        </span>
        <div className="flex gap-2 overflow-x-auto pb-1" role="group" aria-label="Elegir día">
          {nextDays.map((d) => {
            const on = d === day;
            const closed = !openDays.has(isoWeekday(d));
            return (
              <button
                key={d}
                type="button"
                aria-pressed={on}
                aria-label={`${formatDay(d, { weekday: "long", day: "numeric", month: "long" })}${closed ? ", sin horario" : ""}`}
                onClick={() => setDay(d)}
                className={`flex w-[58px] shrink-0 flex-col items-center rounded-xl py-2 transition ${
                  on
                    ? "bg-[#2457D6] text-white"
                    : closed
                      ? "bg-[#F5F7FA] text-[#94A0B4]"
                      : "bg-[#EEF3FF] text-[#1A3FA3] hover:bg-[#DCE6FF]"
                }`}
              >
                <span className="text-[11px] font-bold uppercase">{formatDay(d, { weekday: "short" }).replace(".", "")}</span>
                <span className="font-heading text-lg font-extrabold leading-tight">{Number(d.slice(8, 10))}</span>
                <span className="text-[11px] font-semibold">{formatDay(d, { month: "short" }).replace(".", "")}</span>
              </button>
            );
          })}
        </div>
      </div>
      <div className="flex flex-col gap-2">
        <span className="text-sm font-semibold">Horarios libres</span>
        {slots === null && !err && <span className="text-sm text-[#5B6475]">Buscando horarios…</span>}
        {slots?.length === 0 && (
          <span className="text-sm text-[#5B6475]">
            {openDays.has(isoWeekday(day))
              ? "Ya no quedan horarios libres ese día. Elige otro."
              : "No tienes horario ese día. Agrégalo en «Horario disponible» o elige un día en azul."}
          </span>
        )}
        <div className="flex flex-wrap gap-2">
          {slots?.map((s) => {
            const on = pick?.start.getTime() === s.start.getTime();
            return (
              <button
                key={s.start.toISOString()}
                type="button"
                aria-pressed={on}
                onClick={() => setPick(s)}
                className={`min-h-[40px] rounded-full border-[1.5px] px-3.5 text-sm font-semibold ${
                  on ? "border-[#2457D6] bg-[#2457D6] text-white" : "border-[#C9D5F2] bg-[#EEF3FF] text-[#1A3FA3]"
                }`}
              >
                {formatTime(s.start, tz)}
              </button>
            );
          })}
        </div>
      </div>
      <fieldset className="flex gap-4 text-sm">
        <legend className="mb-1 font-semibold">Modalidad</legend>
        {(["in_person", "video"] as const).map((m) => (
          <label key={m} className="flex min-h-[44px] items-center gap-2">
            <input type="radio" name="modality" checked={modality === m} onChange={() => setModality(m)} className="h-5 w-5 shrink-0 accent-[#2457D6]" />
            {m === "in_person" ? "Presencial" : "Videollamada"}
          </label>
        ))}
      </fieldset>
      <label className="flex flex-col gap-1 text-sm font-semibold">
        Nota (opcional)
        <textarea className={`${field} py-2`} rows={2} maxLength={1000} value={notes} onChange={(e) => setNotes(e.target.value)} />
      </label>
      {err && <p role="alert" className="text-sm text-[#A12A2A]">{err}</p>}
      <div className="mt-2 flex justify-end gap-2">
        <button type="button" className={btnGhost} onClick={onClose}>
          Cancelar
        </button>
        <button type="button" className={btnPrimary} disabled={!pick || busy} onClick={submit}>
          {busy ? "Guardando…" : "Agendar"}
        </button>
      </div>
    </Dialog>
  );
}

/** Horas cada 30 min entre 06:00 y 22:00 para los selectores. */
const TIME_OPTIONS = Array.from({ length: 33 }, (_, i) => {
  const m = 6 * 60 + i * 30;
  return `${String(Math.floor(m / 60)).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`;
});
const DAY_LETTERS = ["", "L", "M", "M", "J", "V", "S", "D"];

function Notice({ kind, text }: { kind: "error" | "ok"; text: string }) {
  return (
    <p
      role={kind === "error" ? "alert" : "status"}
      className={`rounded-xl px-3 py-2 text-[13px] ${
        kind === "error" ? "bg-[#FDF0F0] text-[#A12A2A]" : "bg-[#E8F6F3] text-[#0B5E57]"
      }`}
    >
      {text}
    </p>
  );
}

function Availability({
  settings,
  rules,
  exceptions,
  onChange,
}: {
  settings: SchedulingSettings;
  rules: AvailabilityRule[];
  exceptions: AvailabilityException[];
  onChange: () => Promise<void>;
}) {
  const [draft, setDraft] = useState(settings);
  const [picked, setPicked] = useState<number[]>([1, 2, 3, 4, 5]);
  const [st, setSt] = useState("09:00");
  const [en, setEn] = useState("14:00");
  const [bFrom, setBFrom] = useState("");
  const [bTo, setBTo] = useState("");
  const [bReason, setBReason] = useState("");
  const [msg, setMsg] = useState<{ where: "rule" | "settings" | "block"; kind: "error" | "ok"; text: string } | null>(null);
  const [busy, setBusy] = useState(false);
  useEffect(() => setDraft(settings), [settings]);
  const tz = settings.timezone;

  const run = async (where: "rule" | "settings" | "block", fn: () => Promise<string | void>) => {
    setBusy(true);
    setMsg(null);
    try {
      const ok = await fn();
      await onChange();
      if (ok) setMsg({ where, kind: "ok", text: ok });
    } catch (e) {
      setMsg({ where, kind: "error", text: (e as Error).message });
    } finally {
      setBusy(false);
    }
  };

  const toggleDay = (d: number) =>
    setPicked((p) => (p.includes(d) ? p.filter((x) => x !== d) : [...p, d].sort((a, b) => a - b)));

  const addRules = () =>
    run("rule", async () => {
      if (picked.length === 0) throw new Error("Elige al menos un día.");
      if (st >= en) throw new Error("La hora de inicio debe ser antes que la de fin.");
      const clash = picked.filter((d) => rules.some((r) => r.weekday === d && r.start_time < en && st < r.end_time));
      if (clash.length) {
        throw new Error(
          `Ya tienes horario que se cruza el ${clash.map((d) => weekdayLabels[d].toLowerCase()).join(", ")}. Quítalo o elige otras horas.`,
        );
      }
      for (const d of picked) await addRule(d, st, en);
      return `Horario agregado: ${picked.map((d) => weekdayLabels[d]).join(", ")} de ${st} a ${en}.`;
    });

  const nowLocal = (() => {
    const z = zoned(new Date(), tz);
    return `${dayKey(new Date(), tz)}T${String(z.h).padStart(2, "0")}:${String(z.min).padStart(2, "0")}`;
  })();
  const toDate = (v: string) => localToDate(v.slice(0, 10), v.slice(11, 16), tz);
  const fieldMsg = (where: "rule" | "settings" | "block") =>
    msg && msg.where === where ? <Notice kind={msg.kind} text={msg.text} /> : null;

  return (
    <section aria-labelledby="disp" className={`${card} flex flex-col gap-4`}>
      <div>
        <h2 id="disp" className="font-heading text-[17px] font-bold">
          Horario disponible
        </h2>
        <p className="text-[13px] text-[#5B6475]">
          Tus pacientes y el asistente solo pueden reservar dentro de este horario.
        </p>
      </div>

      <ul className="flex flex-col" aria-label="Horario semanal">
        {[1, 2, 3, 4, 5, 6, 7].map((d) => {
          const list = rules.filter((r) => r.weekday === d);
          return (
            <li key={d} className="flex min-h-[44px] items-center gap-3 border-t border-[#EEF1F5] py-1.5 text-sm">
              <span className="w-[84px] shrink-0 font-semibold">{weekdayLabels[d]}</span>
              <div className="flex min-w-0 flex-1 flex-wrap gap-1.5">
                {list.length === 0 && <span className="text-[13px] text-[#94A0B4]">Sin horario</span>}
                {list.map((r) => (
                  <span
                    key={r.id}
                    className="inline-flex items-center gap-1 rounded-full bg-[#EEF3FF] py-1 pl-3 pr-1 text-[13px] font-semibold text-[#1A3FA3]"
                  >
                    {r.start_time}–{r.end_time}
                    <button
                      type="button"
                      aria-label={`Quitar ${weekdayLabels[r.weekday]} ${r.start_time}–${r.end_time}`}
                      className="flex h-7 w-7 items-center justify-center rounded-full text-base hover:bg-[#DCE6FF]"
                      disabled={busy}
                      onClick={() => run("rule", () => deleteRule(r.id))}
                    >
                      ×
                    </button>
                  </span>
                ))}
              </div>
            </li>
          );
        })}
      </ul>

      <form
        className="flex flex-col gap-3 rounded-xl border border-[#E5E9F0] p-4"
        onSubmit={(e) => {
          e.preventDefault();
          void addRules();
        }}
      >
        <h3 className="text-sm font-bold">Agregar horario</h3>
        <fieldset className="flex flex-col gap-2">
          <legend className="mb-1 text-xs font-semibold text-[#334155]">Días</legend>
          <div className="flex flex-wrap gap-1.5">
            {[1, 2, 3, 4, 5, 6, 7].map((d) => {
              const on = picked.includes(d);
              return (
                <button
                  key={d}
                  type="button"
                  aria-pressed={on}
                  aria-label={weekdayLabels[d]}
                  title={weekdayLabels[d]}
                  onClick={() => toggleDay(d)}
                  className={`h-11 w-11 rounded-full text-sm font-bold transition ${
                    on ? "bg-[#2457D6] text-white" : "border border-[#D5DCE7] bg-white text-[#334155] hover:bg-[#F5F7FA]"
                  }`}
                >
                  {DAY_LETTERS[d]}
                </button>
              );
            })}
          </div>
          <div className="flex flex-wrap gap-3 text-xs font-semibold">
            <button type="button" className="text-[#2457D6] hover:underline" onClick={() => setPicked([1, 2, 3, 4, 5])}>
              Lunes a viernes
            </button>
            <button type="button" className="text-[#2457D6] hover:underline" onClick={() => setPicked([1, 2, 3, 4, 5, 6])}>
              Lunes a sábado
            </button>
            <button type="button" className="text-[#5B6475] hover:underline" onClick={() => setPicked([])}>
              Ninguno
            </button>
          </div>
        </fieldset>
        <div className="grid min-w-0 grid-cols-2 gap-3">
          <label className="flex min-w-0 flex-col gap-1 text-xs font-semibold text-[#334155]">
            Desde
            <select
              className={field}
              value={st}
              onChange={(e) => {
                const v = e.target.value;
                setSt(v);
                if (en <= v) setEn(TIME_OPTIONS[Math.min(TIME_OPTIONS.indexOf(v) + 2, TIME_OPTIONS.length - 1)]);
              }}
            >
              {TIME_OPTIONS.slice(0, -1).map((t) => (
                <option key={t} value={t}>
                  {t}
                </option>
              ))}
            </select>
          </label>
          <label className="flex min-w-0 flex-col gap-1 text-xs font-semibold text-[#334155]">
            Hasta
            <select className={field} value={en} onChange={(e) => setEn(e.target.value)}>
              {TIME_OPTIONS.filter((t) => t > st).map((t) => (
                <option key={t} value={t}>
                  {t}
                </option>
              ))}
            </select>
          </label>
        </div>
        {fieldMsg("rule")}
        <button type="submit" className={`${btnPrimary} w-full`} disabled={busy || picked.length === 0 || st >= en}>
          {picked.length === 0
            ? "Elige al menos un día"
            : `Agregar ${st}–${en} a ${picked.length === 7 ? "toda la semana" : picked.length === 1 ? weekdayLabels[picked[0]].toLowerCase() : `${picked.length} días`}`}
        </button>
      </form>

      <div className="flex flex-col gap-3 rounded-xl bg-[#F5F7FA] p-4">
        <div className="grid grid-cols-2 gap-2">
          <label className="flex min-w-0 flex-col gap-1 text-xs font-semibold text-[#334155]">
            Duración de cita
            <select
              className={field}
              value={draft.slot_minutes}
              onChange={(e) => setDraft({ ...draft, slot_minutes: Number(e.target.value) })}
            >
              {[15, 20, 30, 40, 45, 50, 60, 75, 90, 120].map((m) => (
                <option key={m} value={m}>
                  {m} min
                </option>
              ))}
            </select>
          </label>
          <label className="flex min-w-0 flex-col gap-1 text-xs font-semibold text-[#334155]">
            Descanso entre citas
            <select
              className={field}
              value={draft.buffer_minutes}
              onChange={(e) => setDraft({ ...draft, buffer_minutes: Number(e.target.value) })}
            >
              {[0, 5, 10, 15, 20, 30, 45, 60].map((m) => (
                <option key={m} value={m}>
                  {m === 0 ? "Sin descanso" : `${m} min`}
                </option>
              ))}
            </select>
          </label>
        </div>
        <label className="flex min-h-[44px] items-center justify-between gap-3 text-[13px] font-semibold">
          Confirmar citas automáticamente
          <input
            type="checkbox"
            className="h-5 w-5 shrink-0 accent-[#2457D6]"
            checked={draft.auto_confirm}
            onChange={(e) => setDraft({ ...draft, auto_confirm: e.target.checked })}
          />
        </label>
        {fieldMsg("settings")}
        <button
          type="button"
          className={btnPrimary}
          disabled={busy}
          onClick={() =>
            run("settings", async () => {
              await saveSettings(draft);
              return "Ajustes guardados.";
            })
          }
        >
          Guardar ajustes
        </button>
        <span className="text-xs text-[#5B6475]">Zona horaria: {tz}</span>
      </div>

      <div className="flex flex-col gap-2">
        <h3 className="text-sm font-bold">Bloqueos (vacaciones, congresos)</h3>
        {exceptions.length === 0 && <p className="text-[13px] text-[#94A0B4]">Sin bloqueos próximos.</p>}
        {exceptions.map((x) => (
          <div key={x.id} className="flex items-center justify-between gap-2 text-[13px] text-[#334155]">
            <span className="capitalize">
              {formatDay(dayKey(x.start, tz), { weekday: "short", day: "numeric", month: "short" })} {formatTime(x.start, tz)} →{" "}
              {formatDay(dayKey(x.end, tz), { weekday: "short", day: "numeric", month: "short" })} {formatTime(x.end, tz)}
              {x.reason ? ` · ${x.reason}` : ""}
            </span>
            <button
              type="button"
              aria-label="Quitar bloqueo"
              className="flex h-11 w-11 items-center justify-center rounded-xl text-[#5B6475] hover:bg-[#FDF0F0] hover:text-[#A12A2A]"
              onClick={() => run("block", () => deleteException(x.id))}
            >
              ×
            </button>
          </div>
        ))}
        <form
          className="flex flex-col gap-2"
          onSubmit={(e) => {
            e.preventDefault();
            if (!bFrom || !bTo) return;
            void run("block", async () => {
              const from = toDate(bFrom);
              const to = toDate(bTo);
              if (to <= new Date()) throw new Error("El bloqueo ya pasó. Elige fechas futuras.");
              await addException(from, to, bReason);
              setBFrom("");
              setBTo("");
              setBReason("");
              return "Horario bloqueado.";
            });
          }}
        >
          <div className="grid min-w-0 grid-cols-1 gap-3">
            <label className="flex min-w-0 flex-col gap-1 text-xs font-semibold text-[#334155]">
              Desde
              <input
                type="datetime-local"
                className={field}
                value={bFrom}
                min={nowLocal}
                onChange={(e) => setBFrom(e.target.value)}
              />
            </label>
            <label className="flex min-w-0 flex-col gap-1 text-xs font-semibold text-[#334155]">
              Hasta
              <input
                type="datetime-local"
                className={field}
                value={bTo}
                min={bFrom || nowLocal}
                onChange={(e) => setBTo(e.target.value)}
              />
            </label>
          </div>
          <label className="flex min-w-0 flex-col gap-1 text-xs font-semibold text-[#334155]">
            Motivo (opcional)
            <input type="text" maxLength={200} className={field} value={bReason} onChange={(e) => setBReason(e.target.value)} />
          </label>
          {fieldMsg("block")}
          <button type="submit" className={btnGhost} disabled={!bFrom || !bTo || busy}>
            Bloquear horario
          </button>
        </form>
      </div>
    </section>
  );
}
