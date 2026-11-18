"use client";

// Professional workspace for one care session. Same layout for the four specialties,
// themed through `data-specialty` (see globals.css). Exercise assignment adapted from
// PhysioBuddy NewAssignmentForm and fisio-app rehab plan panel (MIT).
import { useEffect, useState, type ReactNode } from "react";
import { ErrorText, Evidence, MetricsCard } from "./care";
import { Button } from "./ui/button";
import {
  addReview,
  assignActivity,
  assignExercise,
  cancelActivity,
  formatDate,
} from "@/lib/data";
import type {
  CareActivity,
  CareRecord,
  CareReview,
  CareSession,
  CatalogExercise,
  Specialty,
} from "@/lib/data";
import {
  clinicalNotes,
  clinicalSections,
  saveClinicalNote,
  uploadClinicalPhoto,
  type ClinicalNote,
} from "@/lib/clinical";
import Link from "next/link";
import { appointmentsBetween, dayKey, formatDay, formatTime, getSettings, sourceText, statusText } from "@/lib/agenda";
import type { Appointment } from "@/lib/agenda";
import { specialtyUI } from "@/lib/specialty-ui";

type Tile = [key: string, glyph: string, title: string, subtitle: string, color: string];

// Mismo acento por especialidad que la app del paciente: [semana actual, semanas anteriores].
const barColors: Record<Specialty, [string, string]> = {
  physio: ["#0F766E", "#9ED9CF"],
  skin: ["#BE3A5A", "#F2BCC9"],
  eyes: ["#2457D6", "#B9CBF5"],
  mind: ["#6D4AB8", "#D3C6EF"],
};

const looks: Record<
  Specialty,
  { eyebrow: string; title: string; text: string; tiles: Tile[]; planHeader: string; patientData: string }
> = {
  skin: {
    eyebrow: "Dermatología · Espacio clínico",
    title: "El cuidado de su piel, en cada etapa.",
    text: "Un expediente, una rutina y una historia de evolución para cada paciente.",
    tiles: [
      ["profile", "▤", "Información general", "Datos y antecedentes", "peach"],
      ["plan", "✚", "Tratamiento", "Rutina e indicaciones", "mint"],
      ["progress", "◎", "Seguimiento fotográfico", "Comparar la evolución", "lilac"],
      ["history", "▦", "Sesiones", "Registros y revisiones", "blue"],
    ],
    planHeader: "Tratamiento actual",
    patientData: "Lo que reporta el paciente",
  },
  physio: {
    eyebrow: "Fisioterapia · Espacio clínico",
    title: "Cada movimiento, medido y acompañado.",
    text: "Ejercicios asignados, grabaciones del paciente y la evolución del dolor en un solo lugar.",
    tiles: [
      ["profile", "▤", "Información general", "Datos de rehabilitación", "peach"],
      ["plan", "⟲", "Plan de ejercicios", "Series y repeticiones", "mint"],
      ["progress", "↗", "Progreso", "Dolor y grabaciones", "lilac"],
      ["history", "▦", "Sesiones", "Registros y revisiones", "blue"],
    ],
    planHeader: "Plan de rehabilitación",
    patientData: "Datos reportados en la app",
  },
  eyes: {
    eyebrow: "Oftalmología · Espacio clínico",
    title: "Su visión, revisión tras revisión.",
    text: "Indicaciones oculares, síntomas por ojo y evolución entre consultas.",
    tiles: [
      ["profile", "▤", "Información general", "Datos oculares", "peach"],
      ["plan", "◍", "Tratamiento", "Gotas e indicaciones", "mint"],
      ["progress", "◉", "Registro visual", "Síntomas por ojo", "lilac"],
      ["history", "▦", "Sesiones", "Registros y revisiones", "blue"],
    ],
    planHeader: "Tratamiento actual",
    patientData: "Datos reportados en la app",
  },
  mind: {
    eyebrow: "Psicología · Espacio clínico",
    title: "Un espacio seguro entre sesiones.",
    text: "Diario emocional, tareas terapéuticas y notas de sesión visibles solo para usted.",
    tiles: [
      ["profile", "▤", "Información general", "Expediente psicológico", "peach"],
      ["plan", "✎", "Tareas terapéuticas", "Actividades entre sesiones", "mint"],
      ["progress", "♡", "Diario emocional", "Emociones y escalas", "lilac"],
      ["history", "▦", "Sesiones", "Registros y revisiones", "blue"],
    ],
    planHeader: "Plan terapéutico",
    patientData: "Lo que comparte el paciente",
  },
};

const moodLabels: Record<string, string> = {
  calm: "Con calma",
  joy: "Con alegría",
  sadness: "Con tristeza",
  worry: "Con preocupación",
  tired: "Con cansancio",
};

export function RecordDetails({ record }: { record: CareRecord }) {
  const entries = Object.entries({
    ...record.details,
    ...(record.mood ? { "Estado emocional": moodLabels[record.mood] ?? record.mood } : {}),
    ...(record.body_zone ? { "Región anatómica": record.body_zone } : {}),
  }).filter(([, v]) => v !== null && v !== "");
  if (entries.length === 0) return null;
  return (
    <dl className="ws-details">
      {entries.map(([k, v]) => (
        <div key={k}>
          <dt>{k}</dt>
          <dd>{String(v)}</dd>
        </div>
      ))}
    </dl>
  );
}

function HeroArt({ specialty }: { specialty: Specialty }) {
  const glyph: Record<Specialty, ReactNode> = {
    skin: (
      <>
        <circle cx="52" cy="52" r="12" fill="var(--ws-accent)" opacity=".35" />
        <circle cx="52" cy="52" r="5" fill="var(--ws-accent)" />
        {[[30, 40], [70, 38], [40, 72], [68, 66]].map(([x, y]) => (
          <circle key={`${x}${y}`} cx={x} cy={y} r="2.5" fill="var(--ws-accent)" opacity=".5" />
        ))}
      </>
    ),
    physio: (
      <g stroke="var(--ws-accent)" strokeWidth="5" strokeLinecap="round" fill="none">
        <circle cx="52" cy="30" r="6" fill="var(--ws-accent)" stroke="none" />
        <path d="M52 40 L52 60 M36 48 L68 46 M52 60 L42 76 M52 60 L64 74" />
      </g>
    ),
    eyes: (
      <>
        <path d="M24 52 Q52 24 80 52 Q52 80 24 52Z" fill="#fff" stroke="var(--ws-accent)" strokeWidth="4" />
        <circle cx="52" cy="52" r="11" fill="var(--ws-accent)" />
        <circle cx="56" cy="48" r="3" fill="#fff" />
      </>
    ),
    mind: (
      <path
        d="M52 76 C26 58 28 34 44 34 C48 34 51 37 52 40 C53 37 56 34 60 34 C76 34 78 58 52 76Z"
        fill="var(--ws-accent)"
        opacity=".85"
      />
    ),
  };
  return (
    <svg viewBox="0 0 120 120" className="ws-hero-art" role="img" aria-label="Ilustración de la especialidad">
      <defs>
        <radialGradient id={`lens-${specialty}`}>
          <stop offset="0" stopColor="#fff" />
          <stop offset="1" stopColor="var(--ws-soft)" />
        </radialGradient>
      </defs>
      <line x1="80" y1="80" x2="106" y2="106" stroke="#262449" strokeWidth="13" strokeLinecap="round" />
      <circle cx="52" cy="52" r="38" fill={`url(#lens-${specialty})`} stroke="#262449" strokeWidth="7" />
      {glyph[specialty]}
    </svg>
  );
}

function Panel({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <section className={`ws-panel ${className}`}>{children}</section>;
}

function Empty({ children }: { children: ReactNode }) {
  return <p className="ws-empty">{children}</p>;
}

export function SpecialtyWorkspace({
  session,
  patientName,
  records,
  activities,
  reviews,
  catalog = [],
  demo = false,
  initialTab,
  onChanged,
  onClose,
}: {
  session: CareSession;
  patientName: string;
  records: CareRecord[];
  activities: CareActivity[];
  reviews: CareReview[];
  catalog?: CatalogExercise[];
  demo?: boolean;
  initialTab?: string;
  onChanged?: () => Promise<void>;
  onClose?: () => void;
}) {
  const sp = session.specialty;
  const look = looks[sp];
  const ui = specialtyUI[sp];
  const sections = clinicalSections[sp] ?? {};
  const clinical = Object.keys(sections).length > 0;
  const [tab, setTab] = useState(initialTab ?? "resumen");
  const [acts, setActs] = useState(activities);
  const [recs, setRecs] = useState(records);
  const [revs, setRevs] = useState(reviews);
  const [entries, setEntries] = useState<ClinicalNote[]>([]);
  const [loaded, setLoaded] = useState(!clinical);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState("");
  const [draft, setDraft] = useState<Record<string, string>>({});
  const [reviewDrafts, setReviewDrafts] = useState<Record<string, string>>({});
  // Plan form
  const [code, setCode] = useState("");
  const [reps, setReps] = useState(10);
  const [sets, setSets] = useState(1);
  const [dueOn, setDueOn] = useState("");
  const [title, setTitle] = useState("");
  const [notes, setNotes] = useState("");
  // Photos
  const [lesion, setLesion] = useState("");
  const [before, setBefore] = useState("");
  const [after, setAfter] = useState("");
  const [photoFile, setPhotoFile] = useState<File | null>(null);
  const [photoFields, setPhotoFields] = useState<Record<string, string>>({});
  const [appts, setAppts] = useState<Appointment[]>([]);
  const [apptTz, setApptTz] = useState("America/Cancun");
  useEffect(() => {
    if (demo) return;
    let alive = true;
    (async () => {
      try {
        const cfg = await getSettings();
        const day = 1000 * 60 * 60 * 24;
        const list = await appointmentsBetween(new Date(Date.now() - 365 * day), new Date(Date.now() + 365 * day));
        if (alive) {
          setApptTz(cfg.timezone);
          setAppts(list.filter((a) => a.session_id === session.id && a.status !== "cancelled"));
        }
      } catch {
        /* la agenda es opcional en el expediente */
      }
    })();
    return () => {
      alive = false;
    };
  }, [session.id, demo]);

  useEffect(() => setActs(activities), [activities]);
  useEffect(() => setRecs(records), [records]);
  useEffect(() => setRevs(reviews), [reviews]);
  useEffect(() => {
    if (!clinical || demo) {
      setLoaded(true);
      return;
    }
    let alive = true;
    clinicalNotes(session.id)
      .then((v) => {
        if (alive) {
          setEntries(v);
          setLoaded(true);
        }
      })
      .catch((e) => alive && setError((e as Error).message));
    return () => {
      alive = false;
    };
  }, [session.id, clinical, demo]);

  async function run(real: () => Promise<unknown>, fake: () => void, done = "") {
    setBusy(true);
    setError(null);
    setMessage("");
    try {
      if (demo) fake();
      else {
        await real();
        await onChanged?.();
      }
      if (done) setMessage(done);
      return true;
    } catch (e) {
      setError((e as Error).message);
      return false;
    } finally {
      setBusy(false);
    }
  }

  const tabTitle: Record<string, string> = {
    resumen: "Resumen",
    plan: "Plan",
    progreso: "Progreso",
    notas: "Notas clínicas",
    citas: "Citas",
    info: "Información general",
  };
  function navigate(key: string) {
    if (Object.values(draft).some(Boolean) && !window.confirm("¿Descartar el borrador sin guardar?")) return;
    setTab(key);
    setDraft({});
    setMessage("");
    setError(null);
  }

  const active = acts.filter((a) => !a.cancelled);
  const pending = active.filter((a) => !recs.some((r) => r.activity_id === a.id && r.completed));
  const latest: Record<string, unknown> = {};
  for (const r of [...recs].reverse()) {
    Object.assign(latest, r.details);
    if (r.body_zone) latest["Región anatómica"] = r.body_zone;
    if (r.pain != null) latest["Dolor reportado"] = `${r.pain}/10`;
    if (r.pain_after != null) latest["Dolor después del ejercicio"] = `${r.pain_after}/10`;
    if (r.mood) latest["Estado emocional"] = moodLabels[r.mood] ?? r.mood;
  }
  const actTitle = (id: string | null) => acts.find((a) => a.id === id)?.title;
  const selected = catalog.find((c) => c.code === code);
  const lastNote = entries[0];

  // ---------- Clinical notes ----------

  async function saveNote(section: string) {
    const fields = Object.fromEntries(Object.entries(draft).filter(([, v]) => v.trim()));
    const ok = await run(
      async () => {
        await saveClinicalNote(session.id, section, fields);
        setEntries(await clinicalNotes(session.id));
      },
      () =>
        setEntries((prev) => [
          { id: crypto.randomUUID(), section, fields, created_at: new Date().toISOString() },
          ...prev,
        ]),
      demo ? "Nota de ejemplo guardada solo durante esta vista previa." : "Nota guardada en el expediente profesional.",
    );
    if (ok) setDraft({});
  }

  function noteForm(section: string) {
    const spec = sections[section];
    if (!spec) return null;
    return (
      <Panel>
        <p className="ws-eyebrow">Expediente profesional</p>
        <h3 className="ws-h3">{spec.title}</h3>
        <p className="ws-muted mb-4">
          Cada guardado añade una nota fechada al historial. Completa solo los datos pertinentes.
        </p>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            void saveNote(section);
          }}
        >
          <fieldset disabled={busy || !loaded} className="grid gap-4 md:grid-cols-2">
            {spec.fields.map((f) => {
              const [label, ...options] = f.split("|");
              return (
                <label key={label} className="ws-label">
                  {label}
                  {options.length ? (
                    <select value={draft[label] ?? ""} onChange={(e) => setDraft({ ...draft, [label]: e.target.value })}>
                      <option value="">Sin registrar</option>
                      {options.map((o) => (
                        <option key={o}>{o}</option>
                      ))}
                    </select>
                  ) : (
                    <textarea
                      maxLength={1000}
                      value={draft[label] ?? ""}
                      onChange={(e) => setDraft({ ...draft, [label]: e.target.value })}
                    />
                  )}
                </label>
              );
            })}
          </fieldset>
          <button type="submit" className="ws-primary mt-5" disabled={busy || !loaded || !Object.values(draft).some((v) => v.trim())}>
            {busy ? "Guardando…" : "Guardar nota clínica"}
          </button>
        </form>
      </Panel>
    );
  }

  function noteList(list: ClinicalNote[]) {
    if (list.length === 0) return <Empty>{loaded ? "Aún no hay notas clínicas." : "Cargando expediente…"}</Empty>;
    return (
      <ol className="ws-timeline">
        {list.map((n) => (
          <li key={n.id}>
            <p className="font-semibold">
              {sections[n.section]?.title ?? (n.section === "photo" ? "Fotografía de consulta" : n.section)}
            </p>
            <time className="ws-muted text-xs">{formatDate(n.created_at)}</time>
            <dl className="ws-details">
              {Object.entries(n.fields)
                .filter(([k, v]) => v && k !== "Archivo")
                .map(([k, v]) => (
                  <div key={k}>
                    <dt>{k}</dt>
                    <dd>{v}</dd>
                  </div>
                ))}
            </dl>
          </li>
        ))}
      </ol>
    );
  }

  // ---------- Tabs ----------

  function resumen() {
    // 6-week compliance bars
    const now = Date.now();
    const compData = Array.from({ length: 6 }, (_, i) => {
      const wStart = now - (5 - i) * 7 * 24 * 60 * 60 * 1000;
      const wEnd = wStart + 7 * 24 * 60 * 60 * 1000;
      const done = recs.filter((r) => {
        const t = new Date(r.created_at).getTime();
        return r.completed && t >= wStart && t < wEnd;
      }).length;
      const total = Math.max(1, active.length);
      const pct = Math.min(100, Math.round((100 * done) / total));
      const h = Math.max(4, Math.round(pct * 1.4));
      const label = new Date(wStart).toLocaleDateString("es-MX", { day: "numeric", month: "short" });
      return { label, pct, h, isLatest: i === 5 };
    });

    // Pain line chart (physio)
    const painPts = [...recs]
      .reverse()
      .map((r) => r.pain_after ?? r.pain)
      .filter((v): v is number => v !== null)
      .slice(-12);
    const W = 380, H = 160, PX = 20, PY = 16;
    const painSvg = painPts.length >= 2 ? (
      <svg viewBox={`0 0 ${W} ${H}`} className="mt-3 w-full" aria-label="Tendencia de dolor">
        {/* Y axis grid lines */}
        {[0, 5, 10].map((v) => {
          const y = H - PY - (v / 10) * (H - 2 * PY);
          return (
            <g key={v}>
              <line x1={PX} y1={y} x2={W - PX} y2={y} stroke="#E5E9F0" strokeWidth="1" />
              <text x={PX - 4} y={y + 4} textAnchor="end" fontSize="10" fill="#5B6475">{v}</text>
            </g>
          );
        })}
        <polyline
          points={painPts.map((v, i) => {
            const x = PX + (i / (painPts.length - 1)) * (W - 2 * PX);
            const y = H - PY - (v / 10) * (H - 2 * PY);
            return `${x},${y}`;
          }).join(" ")}
          fill="none"
          stroke="#0F766E"
          strokeWidth="2.5"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        {painPts.map((v, i) => {
          const x = PX + (i / (painPts.length - 1)) * (W - 2 * PX);
          const y = H - PY - (v / 10) * (H - 2 * PY);
          const c = v >= 7 ? "#A12A2A" : v >= 4 ? "#8A5300" : "#0F766E";
          return <circle key={i} cx={x} cy={y} r="4" fill={c} />;
        })}
      </svg>
    ) : null;

    return (
      <>
        <div className="grid gap-3 sm:grid-cols-3">
          {[
            ["Registros recibidos", String(recs.length)],
            [sp === "physio" ? "Ejercicios pendientes" : "Indicaciones pendientes", String(pending.length)],
            clinical
              ? ["Última nota clínica", lastNote ? formatDate(lastNote.created_at) : loaded ? "Sin notas" : "Cargando…"]
              : ["Último registro", recs[0] ? formatDate(recs[0].created_at) : "Sin registros"],
          ].map(([k, v]) => (
            <Panel key={k} className="ws-stat">
              <p className="ws-muted">{k}</p>
              <p className="ws-stat-value">{v}</p>
            </Panel>
          ))}
        </div>

        <div className="grid gap-5 lg:grid-cols-2">
          <Panel>
            <h3 className="ws-h3">Cumplimiento semanal (6 semanas)</h3>
            <div className="ws-compliance-bars mt-4">
              {compData.map(({ label, pct, h, isLatest }, i) => (
                <div key={i} className="ws-compliance-bar">
                  <span className="text-xs text-[#5B6475]">{pct}%</span>
                  <div
                    aria-hidden="true"
                    style={{
                      height: `${h}px`,
                      width: "100%",
                      maxWidth: "40px",
                      background: isLatest ? barColors[sp][0] : barColors[sp][1],
                      borderRadius: "6px 6px 0 0",
                    }}
                  />
                  <span className="text-[10px] text-[#5B6475]">{label}</span>
                </div>
              ))}
            </div>
          </Panel>

          {sp === "physio" && (
            <Panel>
              <h3 className="ws-h3">Dolor reportado (0-10)</h3>
              {painSvg ?? <p className="ws-muted mt-2 text-sm">Sin datos de dolor aún.</p>}
            </Panel>
          )}
        </div>

        <Panel>
          <h3 className="ws-h3">Último reporte del paciente</h3>
          {recs[0] ? (
            <>
              <p className="ws-muted mt-1">
                {formatDate(recs[0].created_at)}
                {actTitle(recs[0].activity_id) && ` · ${actTitle(recs[0].activity_id)}`}
              </p>
              <RecordDetails record={recs[0]} />
              {recs[0].note && <p className="mt-2 italic">"{recs[0].note}"</p>}
            </>
          ) : (
            <Empty>Todavía no hay registros. Aparecerán cuando el paciente los comparta desde su celular.</Empty>
          )}
        </Panel>
      </>
    );
  }

  function profile() {
    const profileNotes = entries.filter((n) => n.section === "profile");
    const data = Object.entries(latest).filter(([, v]) => v !== null && v !== "");
    return (
      <>
        <Panel className="ws-person">
          <span className="ws-avatar">{(patientName || "P").trim()[0]?.toUpperCase()}</span>
          <div className="min-w-0 flex-1">
            <h3 className="ws-h3">{patientName || "Paciente sin nombre registrado"}</h3>
            <p className="ws-muted">
              {session.title} · desde {formatDate(session.created_at)}
            </p>
          </div>
          <span className="ws-status">{session.active ? "Seguimiento activo" : "Sesión cerrada"}</span>
        </Panel>
        <div className="grid gap-5 lg:grid-cols-2">
          <Panel>
            <h3 className="ws-h3">Indicaciones generales</h3>
            <p className="mt-2 whitespace-pre-line">{session.instructions || "Sin indicaciones generales registradas."}</p>
          </Panel>
          <Panel>
            <h3 className="ws-h3">{look.patientData}</h3>
            {data.length ? (
              <dl className="ws-details">
                {data.map(([k, v]) => (
                  <div key={k}>
                    <dt>{k}</dt>
                    <dd>{String(v)}</dd>
                  </div>
                ))}
              </dl>
            ) : (
              <Empty>El paciente aún no ha compartido datos.</Empty>
            )}
          </Panel>
        </div>
        {clinical && (
          <>
            {noteForm("profile")}
            <Panel>
              <h3 className="ws-h3 mb-3">Expedientes guardados</h3>
              {noteList(profileNotes)}
            </Panel>
          </>
        )}
      </>
    );
  }

  function plan() {
    return (
      <div className="grid gap-5 lg:grid-cols-[1.15fr_1fr]">
        <div>
          <Panel className="ws-banner">
            <span className="ws-icon">{look.tiles[1][1]}</span>
            <div>
              <h3 className="font-semibold">{look.planHeader}</h3>
              <p className="ws-muted">
                {active.length} {active.length === 1 ? "indicación activa" : "indicaciones activas"}
              </p>
            </div>
            <span className="ws-status">{session.active ? "En seguimiento" : "Cerrado"}</span>
          </Panel>
          <h3 className="ws-h3 my-4">{ui.plan}</h3>
          {acts.length === 0 && <Empty>Todavía no hay indicaciones. Añade el plan personalizado del paciente.</Empty>}
          <div className="space-y-3">
            {acts.map((a) => {
              const done = recs.filter((r) => r.activity_id === a.id && r.completed).length;
              return (
                <Panel key={a.id} className="ws-row">
                  <span className="ws-icon mint">{a.exercise_code ? "⟲" : "✧"}</span>
                  <div className="min-w-0 flex-1">
                    <h4 className={a.cancelled ? "ws-muted line-through" : "font-semibold"}>{a.title}</h4>
                    {a.target_reps && (
                      <p className="ws-accent-text text-sm font-semibold">
                        {a.target_sets ?? 1} × {a.target_reps} repeticiones
                      </p>
                    )}
                    {a.instructions && <p className="ws-muted mt-1 whitespace-pre-line">{a.instructions}</p>}
                    <p className="ws-ok mt-2 text-xs">
                      {a.cancelled
                        ? "Retirado"
                        : `${done} ${done === 1 ? "registro" : "registros"} de cumplimiento${a.due_on ? ` · hasta ${a.due_on}` : ""}`}
                    </p>
                  </div>
                  {!a.cancelled && (
                    <Button
                      variant="ghost"
                      disabled={busy}
                      onClick={() =>
                        void run(
                          () => cancelActivity(a.id),
                          () => setActs((p) => p.map((x) => (x.id === a.id ? { ...x, cancelled: true } : x))),
                        )
                      }
                    >
                      Retirar
                    </Button>
                  )}
                </Panel>
              );
            })}
          </div>
        </div>
        <Panel>
          <p className="ws-eyebrow">Plan personalizado</p>
          <h3 className="ws-h3 mb-4 mt-1">{ui.assign}</h3>
          {sp === "physio" ? physioForm() : activityForm()}
          <p className="ws-muted mt-4 text-xs">
            {demo ? "Vista previa: los cambios solo existen en memoria." : "Aparece de inmediato en la app del paciente."}
          </p>
        </Panel>
      </div>
    );
  }

  function physioForm() {
    return (
      <form
        className="grid gap-4"
        onSubmit={async (e) => {
          e.preventDefault();
          if (!selected) return;
          const ok = await run(
            () => assignExercise({ sessionId: session.id, exercise: selected, reps, sets, notes, dueOn: dueOn || null }),
            () =>
              setActs((p) => [
                {
                  id: crypto.randomUUID(),
                  title: selected.name,
                  instructions: notes,
                  due_on: dueOn || null,
                  exercise_code: selected.code,
                  target_reps: reps,
                  target_sets: sets,
                  cancelled: false,
                  created_at: new Date().toISOString(),
                },
                ...p,
              ]),
          );
          if (ok) {
            setCode("");
            setNotes("");
            setDueOn("");
          }
        }}
      >
        <label className="ws-label">
          Ejercicio
          <select
            value={code}
            onChange={(e) => {
              setCode(e.target.value);
              const ex = catalog.find((c) => c.code === e.target.value);
              if (ex) setReps(ex.default_reps);
            }}
          >
            <option value="">Selecciona un ejercicio</option>
            {catalog.map((c) => (
              <option key={c.code} value={c.code}>
                {c.name}
                {c.created_by ? " · propio" : ""}
              </option>
            ))}
          </select>
        </label>
        {selected && (
          <p className="ws-hint">
            {selected.description}
            <br />
            <span className="ws-muted">
              Cámara {selected.camera_view === "front" ? "de frente" : "de lado"}
              {selected.precautions && ` · ${selected.precautions}`}
              {selected.detector ? " · conteo automático" : " · solo video"}
              {(selected.demo_video_path || selected.demo_video_url) && " · con video demostración"}
            </span>
          </p>
        )}
        <div className="grid grid-cols-2 gap-3">
          <label className="ws-label">
            Repeticiones
            <input type="number" min={1} max={30} value={reps} onChange={(e) => setReps(Number(e.target.value))} />
          </label>
          <label className="ws-label">
            Series
            <input type="number" min={1} max={5} value={sets} onChange={(e) => setSets(Number(e.target.value))} />
          </label>
        </div>
        <label className="ws-label">
          Fecha límite (opcional)
          <input type="date" value={dueOn} onChange={(e) => setDueOn(e.target.value)} />
        </label>
        <label className="ws-label">
          Indicaciones adicionales
          <textarea maxLength={1000} value={notes} onChange={(e) => setNotes(e.target.value)} />
        </label>
        <button type="submit" className="ws-primary" disabled={busy || !selected || reps < 1 || reps > 30 || sets < 1 || sets > 5}>
          {busy ? "Asignando…" : "Asignar al paciente"}
        </button>
      </form>
    );
  }

  function activityForm() {
    return (
      <form
        className="grid gap-4"
        onSubmit={async (e) => {
          e.preventDefault();
          const ok = await run(
            () => assignActivity(session.id, title, notes),
            () =>
              setActs((p) => [
                {
                  id: crypto.randomUUID(),
                  title,
                  instructions: notes,
                  due_on: null,
                  exercise_code: null,
                  target_reps: null,
                  target_sets: null,
                  cancelled: false,
                  created_at: new Date().toISOString(),
                },
                ...p,
              ]),
          );
          if (ok) {
            setTitle("");
            setNotes("");
          }
        }}
      >
        <label className="ws-label">
          Tipo de indicación
          <select value={ui.templates.includes(title) ? title : ""} onChange={(e) => setTitle(e.target.value)}>
            <option value="">Selecciona o escribe una indicación</option>
            {ui.templates.map((t) => (
              <option key={t}>{t}</option>
            ))}
          </select>
        </label>
        <label className="ws-label">
          Título
          <input maxLength={160} placeholder="Nombre de la indicación" value={title} onChange={(e) => setTitle(e.target.value)} />
        </label>
        <label className="ws-label">
          Indicaciones, frecuencia y duración
          <textarea
            maxLength={4000}
            className="min-h-32"
            placeholder="Indicaciones específicas para este paciente"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
          />
        </label>
        <button type="submit" className="ws-primary" disabled={busy || !title.trim()}>
          {busy ? "Guardando…" : demo ? "Añadir indicación de ejemplo" : "Compartir indicación"}
        </button>
      </form>
    );
  }

  function photos() {
    const all: CareRecord[] = [
      ...recs,
      ...entries
        .filter((n) => n.section === "photo")
        .map((n) => ({
          id: n.id,
          session_id: session.id,
          activity_id: null,
          created_at: n.created_at,
          completed: null,
          pain: null,
          pain_after: null,
          note: n.fields["Observaciones"] ?? null,
          evidence_path: n.fields["Archivo"],
          exercise_metrics: null,
          details: Object.fromEntries(Object.entries(n.fields).filter(([k]) => k !== "Archivo")),
        })),
    ]
      .filter((r) => r.evidence_path && !/\.(mp4|mov)$/i.test(r.evidence_path))
      .sort((a, b) => b.created_at.localeCompare(a.created_at));
    const ids = Array.from(new Set(all.map((r) => String(r.details?.["Identificador de lesión"] ?? "")).filter(Boolean)));
    const list = all.filter((r) => !lesion || r.details?.["Identificador de lesión"] === lesion);
    return (
      <>
        <Panel>
          <h3 className="ws-h3">Comparación de evolución</h3>
          <p className="ws-muted my-2">
            Compara fotografías de la misma lesión. Revisa iluminación, distancia y orientación antes de valorar cambios.
          </p>
          <label className="ws-label">
            Lesión
            <select
              value={lesion}
              onChange={(e) => {
                setLesion(e.target.value);
                setBefore("");
                setAfter("");
              }}
            >
              <option value="">Todas las fotografías</option>
              {ids.map((id) => (
                <option key={id}>{id}</option>
              ))}
            </select>
          </label>
          {list.length < 2 && <Empty>Se necesitan al menos dos fotografías para comparar.</Empty>}
          <div className="mt-4 grid gap-4 md:grid-cols-2">
            {(
              [
                [before, setBefore, "Fotografía anterior", after],
                [after, setAfter, "Fotografía actual", before],
              ] as const
            ).map(([value, setter, label, other]) => {
              const r = list.find((p) => p.id === value);
              return (
                <div key={label} className="ws-photo-slot">
                  <label className="ws-label">
                    {label}
                    <select value={value} onChange={(e) => setter(e.target.value)}>
                      <option value="">Seleccionar fotografía</option>
                      {list.map((p) => (
                        <option key={p.id} value={p.id} disabled={p.id === other}>
                          {formatDate(p.created_at)} · {String(p.details?.["Identificador de lesión"] ?? "Sin identificador")}
                        </option>
                      ))}
                    </select>
                  </label>
                  {r?.evidence_path && (
                    <>
                      <Evidence key={r.id} path={r.evidence_path} />
                      <RecordDetails record={r} />
                    </>
                  )}
                </div>
              );
            })}
          </div>
        </Panel>
        <Panel>
          <details>
            <summary className="cursor-pointer font-semibold">Adjuntar fotografía de consulta</summary>
            <p className="ws-muted my-3">
              JPEG o PNG, hasta 10 MB. Requiere el consentimiento de imágenes registrado por el paciente.
            </p>
            {demo ? (
              <Empty>La carga de fotografías está disponible en una sesión real con consentimiento.</Empty>
            ) : (
              <form
                onSubmit={async (e) => {
                  e.preventDefault();
                  if (!photoFile) return;
                  const ok = await run(
                    async () => {
                      await uploadClinicalPhoto(session.id, session.patient_id, photoFile, photoFields);
                      setEntries(await clinicalNotes(session.id));
                    },
                    () => undefined,
                    "Fotografía guardada con su información clínica.",
                  );
                  if (ok) {
                    setPhotoFile(null);
                    setPhotoFields({});
                  }
                }}
              >
                <fieldset disabled={busy || !loaded} className="grid gap-3 sm:grid-cols-2">
                  {["Identificador de lesión", "Región anatómica", "Fecha y hora de toma", "Etapa del tratamiento", "Observaciones"].map((label) => (
                    <label key={label} className="ws-label">
                      {label}
                      <input
                        required={label !== "Observaciones"}
                        type={label === "Fecha y hora de toma" ? "datetime-local" : "text"}
                        maxLength={500}
                        value={photoFields[label] ?? ""}
                        onChange={(e) => setPhotoFields({ ...photoFields, [label]: e.target.value })}
                      />
                    </label>
                  ))}
                  <label className="ws-label">
                    Fotografía
                    <input key={entries.length} type="file" accept="image/jpeg,image/png" required onChange={(e) => setPhotoFile(e.target.files?.[0] ?? null)} />
                  </label>
                </fieldset>
                <button type="submit" className="ws-primary mt-3" disabled={busy || !loaded || !photoFile}>
                  Guardar fotografía
                </button>
              </form>
            )}
          </details>
        </Panel>
      </>
    );
  }

  function bars(values: Array<[string, number]>, max: number, label: string) {
    return (
      <div className="ws-bars" role="img" aria-label={label}>
        {values.map(([k, v], i) => (
          <div key={`${k}${i}`} className="ws-bar">
            <span className="ws-muted text-xs">{v}</span>
            <i style={{ height: `${8 + (v / max) * 110}px` }} data-level={v >= 7 ? "high" : v >= 4 ? "mid" : "low"} />
            <span className="ws-muted text-[10px]">{k}</span>
          </div>
        ))}
      </div>
    );
  }

  function progress() {
    if (sp === "skin") return photos();
    const chrono = [...recs].reverse();
    const answered = recs.filter((r) => r.completed != null);
    const adherence = answered.length ? Math.round((100 * answered.filter((r) => r.completed).length) / answered.length) : null;
    const short = (iso: string) => new Date(iso).toLocaleDateString("es-MX", { day: "numeric", month: "short" });
    const stats: Array<[string, string]> = [
      ["Registros", String(recs.length)],
      ["Cumplimiento", adherence == null ? "-" : `${adherence}%`],
    ];
    let chart: ReactNode = null;
    if (sp === "physio") {
      const pains = chrono
        .map((r) => [short(r.created_at), r.pain_after ?? r.pain] as const)
        .filter((p): p is readonly [string, number] => p[1] != null)
        .slice(-12)
        .map(([d, v]) => [d, v] as [string, number]);
      const avg = pains.length ? (pains.reduce((s, [, v]) => s + v, 0) / pains.length).toFixed(1) : "-";
      stats.push(["Dolor promedio", avg === "-" ? avg : `${avg}/10`]);
      chart = pains.length ? (
        <Panel>
          <h3 className="ws-h3">Dolor reportado (0-10)</h3>
          <p className="ws-muted">Después del ejercicio cuando existe; si no, antes. Del más antiguo al más reciente.</p>
          {bars(pains, 10, "Evolución del dolor")}
        </Panel>
      ) : null;
    }
    if (sp === "mind") {
      const counts: Record<string, number> = {};
      for (const r of recs) {
        const m = r.mood ? moodLabels[r.mood] ?? r.mood : (r.details["Estado emocional reportado"] as string | undefined);
        if (m) counts[m] = (counts[m] ?? 0) + 1;
      }
      const scales = ["Ansiedad", "Estrés", "Calidad del sueño"].map((k) => {
        const vals = recs.map((r) => Number(r.details[k])).filter((v) => !Number.isNaN(v) && r0(v));
        return [k, vals.length ? vals.reduce((a, b) => a + b, 0) / vals.length : null] as const;
      });
      const total = Object.values(counts).reduce((a, b) => a + b, 0);
      chart = (
        <div className="grid gap-5 lg:grid-cols-2">
          <Panel>
            <h3 className="ws-h3">Emociones registradas</h3>
            {total === 0 && <Empty>Sin emociones registradas todavía.</Empty>}
            {Object.entries(counts)
              .sort((a, b) => b[1] - a[1])
              .map(([k, v]) => (
                <div key={k} className="ws-meter">
                  <span>{k}</span>
                  <i>
                    <b style={{ width: `${(100 * v) / total}%` }} />
                  </i>
                  <span className="ws-muted">{v}</span>
                </div>
              ))}
          </Panel>
          <Panel>
            <h3 className="ws-h3">Escalas del diario (promedio 0-10)</h3>
            {scales.map(([k, v]) => (
              <div key={k} className="ws-meter">
                <span>{k}</span>
                <i>
                  <b style={{ width: `${v == null ? 0 : v * 10}%` }} />
                </i>
                <span className="ws-muted">{v == null ? "-" : v.toFixed(1)}</span>
              </div>
            ))}
          </Panel>
        </div>
      );
    }
    if (sp === "eyes") {
      const eyes: Record<string, number> = {};
      for (const r of recs) {
        const side = r.details["Lateralidad"] as string | undefined;
        if (side) eyes[side] = (eyes[side] ?? 0) + 1;
      }
      chart = (
        <Panel>
          <h3 className="ws-h3">Registros por ojo</h3>
          {Object.keys(eyes).length === 0 ? (
            <Empty>El paciente aún no indica el ojo en sus registros.</Empty>
          ) : (
            <div className="ws-eyes">
              {Object.entries(eyes).map(([k, v]) => (
                <div key={k}>
                  <strong>{v}</strong>
                  <span>{k}</span>
                </div>
              ))}
            </div>
          )}
        </Panel>
      );
    }
    const media = recs.filter((r) => r.exercise_metrics || r.evidence_path);
    return (
      <>
        <div className="grid gap-3 sm:grid-cols-[repeat(auto-fit,minmax(180px,1fr))]">
          {stats.map(([k, v]) => (
            <Panel key={k} className="ws-stat">
              <p className="ws-muted">{k}</p>
              <p className="ws-stat-value">{v}</p>
            </Panel>
          ))}
        </div>
        {recs.length === 0 ? <Panel><Empty>El paciente aún no envía registros.</Empty></Panel> : chart}
        {media.length > 0 && (
          <Panel>
            <h3 className="ws-h3">{sp === "physio" ? "Grabaciones y métricas" : "Fotografías compartidas"}</h3>
            <div className="mt-3 space-y-5">
              {media.map((r) => (
                <div key={r.id} className="ws-media">
                  <p className="font-semibold">
                    {actTitle(r.activity_id) ?? "Registro"} <span className="ws-muted font-normal">· {formatDate(r.created_at)}</span>
                  </p>
                  {r.exercise_metrics && <MetricsCard m={r.exercise_metrics} />}
                  {r.evidence_path && <Evidence path={r.evidence_path} />}
                </div>
              ))}
            </div>
          </Panel>
        )}
      </>
    );
  }

  function history() {
    return (
      <div className={clinical ? "grid gap-5 xl:grid-cols-[1.3fr_1fr]" : ""}>
        <Panel>
          <h3 className="ws-h3">{ui.records}</h3>
          {recs.length === 0 && <Empty>El paciente aún no envía registros.</Empty>}
          <ol className="ws-timeline">
            {recs.map((r) => {
              const mine = revs.filter((v) => v.record_id === r.id);
              return (
                <li key={r.id}>
                  <div className="flex flex-wrap items-baseline justify-between gap-2">
                    <p className="font-semibold">{actTitle(r.activity_id) ?? "Registro"}</p>
                    <time className="ws-muted text-xs">{formatDate(r.created_at)}</time>
                  </div>
                  <p className="mt-1 text-sm">
                    {r.completed != null && `Completado: ${r.completed ? "sí" : "no"} · `}
                    {r.pain != null && `Dolor: ${r.pain}/10 · `}
                    {r.pain_after != null && `Dolor después: ${r.pain_after}/10`}
                  </p>
                  {r.note && <p className="mt-1 text-sm italic">"{r.note}"</p>}
                  <RecordDetails record={r} />
                  {sp === "physio" && r.exercise_metrics && <MetricsCard m={r.exercise_metrics} />}
                  {r.evidence_path && <Evidence path={r.evidence_path} />}
                  {mine.map((v) => (
                    <p key={v.id} className="ws-review">
                      Tu revisión ({formatDate(v.created_at)}): {v.body}
                    </p>
                  ))}
                  <form
                    className="mt-3 flex gap-2"
                    onSubmit={async (e) => {
                      e.preventDefault();
                      const body = reviewDrafts[r.id] ?? "";
                      const ok = await run(
                        () => addReview(session.id, r.id, body),
                        () => setRevs((p) => [...p, { id: crypto.randomUUID(), record_id: r.id, body, created_at: new Date().toISOString() }]),
                      );
                      if (ok) setReviewDrafts((d) => ({ ...d, [r.id]: "" }));
                    }}
                  >
                    <input
                      className="ws-input flex-1"
                      placeholder="Comentario para el paciente"
                      maxLength={4000}
                      value={reviewDrafts[r.id] ?? ""}
                      onChange={(e) => setReviewDrafts((d) => ({ ...d, [r.id]: e.target.value }))}
                    />
                    <button type="submit" className="ws-primary" disabled={busy || !(reviewDrafts[r.id] ?? "").trim()}>
                      Enviar revisión
                    </button>
                  </form>
                </li>
              );
            })}
          </ol>
        </Panel>
        {clinical && (
          <Panel>
            <h3 className="ws-h3 mb-3">Historial clínico</h3>
            {noteList(entries)}
          </Panel>
        )}
      </div>
    );
  }

  function notas() {
    return (
      <div className={clinical ? "grid gap-5 xl:grid-cols-[1.3fr_1fr]" : ""}>
        <Panel>
          <h3 className="ws-h3">{ui.records}</h3>
          {recs.length === 0 && <Empty>El paciente aún no envía registros.</Empty>}
          <ol className="ws-timeline">
            {recs.map((r) => {
              const mine = revs.filter((v) => v.record_id === r.id);
              return (
                <li key={r.id}>
                  <div className="flex flex-wrap items-baseline justify-between gap-2">
                    <p className="font-semibold">{actTitle(r.activity_id) ?? "Registro"}</p>
                    <time className="ws-muted text-xs">{formatDate(r.created_at)}</time>
                  </div>
                  <p className="mt-1 text-sm">
                    {r.completed != null && `Completado: ${r.completed ? "sí" : "no"} · `}
                    {r.pain != null && `Dolor: ${r.pain}/10 · `}
                    {r.pain_after != null && `Dolor después: ${r.pain_after}/10`}
                  </p>
                  {r.note && <p className="mt-1 text-sm italic">"{r.note}"</p>}
                  <RecordDetails record={r} />
                  {sp === "physio" && r.exercise_metrics && <MetricsCard m={r.exercise_metrics} />}
                  {r.evidence_path && <Evidence path={r.evidence_path} />}
                  {mine.map((v) => (
                    <p key={v.id} className="ws-review">
                      Tu revisión ({formatDate(v.created_at)}): {v.body}
                    </p>
                  ))}
                  <form
                    className="mt-3 flex gap-2"
                    onSubmit={async (e) => {
                      e.preventDefault();
                      const body = reviewDrafts[r.id] ?? "";
                      const ok = await run(
                        () => addReview(session.id, r.id, body),
                        () => setRevs((p) => [...p, { id: crypto.randomUUID(), record_id: r.id, body, created_at: new Date().toISOString() }]),
                      );
                      if (ok) setReviewDrafts((d) => ({ ...d, [r.id]: "" }));
                    }}
                  >
                    <input
                      className="ws-input flex-1"
                      placeholder="Comentario para el paciente"
                      maxLength={4000}
                      value={reviewDrafts[r.id] ?? ""}
                      onChange={(e) => setReviewDrafts((d) => ({ ...d, [r.id]: e.target.value }))}
                    />
                    <button type="submit" className="ws-primary" disabled={busy || !(reviewDrafts[r.id] ?? "").trim()}>
                      Enviar revisión
                    </button>
                  </form>
                </li>
              );
            })}
          </ol>
        </Panel>
        {clinical && (
          <div className="space-y-5">
            {Object.keys(sections)
              .filter((k) => k !== "profile")
              .map((k) => <div key={k}>{noteForm(k)}</div>)}
            <Panel>
              <h3 className="ws-h3 mb-3">Historial clínico</h3>
              {noteList(entries.filter((n) => n.section !== "profile"))}
            </Panel>
          </div>
        )}
      </div>
    );
  }

  function citas() {
    if (demo) {
      return (
        <Panel>
          <p className="py-6 text-sm text-[#5B6475]">Las citas de la sesión aparecen aquí con una cuenta profesional.</p>
        </Panel>
      );
    }
    const now = new Date();
    const upcoming = appts.filter((a) => a.end >= now && (a.status === "confirmed" || a.status === "requested"));
    const past = appts.filter((a) => !upcoming.includes(a)).reverse();
    const row = (a: Appointment) => (
      <li key={a.id} className="flex flex-wrap items-center justify-between gap-2 border-t border-[#EEF1F5] py-3 text-sm">
        <span className="font-semibold capitalize text-[#0F172A]">
          {formatDay(dayKey(a.start, apptTz), { weekday: "long", day: "numeric", month: "long" })} · {formatTime(a.start, apptTz)}
        </span>
        <span className="text-[#5B6475]">
          {a.modality === "video" ? "Videollamada" : "Presencial"} · {sourceText[a.source]} · {statusText[a.status]}
        </span>
      </li>
    );
    return (
      <Panel>
        <div className="flex flex-wrap items-center justify-between gap-3">
          <h3 className="ws-h3">Próximas citas</h3>
          <Link href="/agenda" className="text-sm font-semibold text-[#2457D6] hover:text-[#1A3FA3]">
            Abrir agenda
          </Link>
        </div>
        {upcoming.length === 0 ? (
          <p className="py-4 text-sm text-[#5B6475]">Sin citas próximas. El paciente puede agendar desde su app.</p>
        ) : (
          <ul className="mt-2">{upcoming.map(row)}</ul>
        )}
        {past.length > 0 && (
          <>
            <h3 className="ws-h3 mt-6">Historial</h3>
            <ul className="mt-2">{past.map(row)}</ul>
          </>
        )}
      </Panel>
    );
  }

  const tabs = ["resumen", "plan", "progreso", "notas", "citas", "info"];

  return (
    <section className="ws" data-specialty={sp}>
      <nav className="ws-tabs" aria-label="Secciones del expediente">
        {tabs.map((key) => (
          <button key={key} aria-pressed={tab === key} disabled={busy} onClick={() => navigate(key)}>
            {tabTitle[key]}
          </button>
        ))}
      </nav>
      <ErrorText error={error} />
      {message && (
        <p role="status" className="ws-ok">
          {message}
        </p>
      )}
      {tab === "resumen" && resumen()}
      {tab === "info" && profile()}
      {tab === "plan" && plan()}
      {tab === "progreso" && progress()}
      {tab === "notas" && notas()}
      {tab === "citas" && citas()}
      {onClose && (
        <div className="flex justify-end pt-2">
          <Button
            variant="danger"
            disabled={busy}
            onClick={() => {
              if (window.confirm("¿Cerrar la sesión? Dejarás de ver este paciente; él conserva su historial.")) onClose();
            }}
          >
            Cerrar sesión de seguimiento
          </Button>
        </div>
      )}
    </section>
  );
}

function r0(v: number) {
  return v >= 0 && v <= 10;
}
