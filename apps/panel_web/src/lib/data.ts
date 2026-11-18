import { supabase } from "./supabase";

export type Specialty = "physio" | "skin" | "eyes" | "mind";

export const specialtyLabels: Record<Specialty, string> = {
  physio: "Fisioterapia",
  skin: "Dermatología",
  eyes: "Oftalmología",
  mind: "Psicología",
};

export const statusLabels: Record<string, string> = {
  pending: "Pendiente",
  approved: "Aprobada",
  rejected: "Rechazada",
};

export type AccountRole = {
  role: "patient" | "specialist";
  display_name: string | null;
  verified: boolean;
  specialties: Specialty[];
};

export type LinkRequest = {
  id: string;
  specialty: Specialty;
  recipient_email: string;
  status: string;
  created_at: string;
};

export type CareSession = {
  id: string;
  patient_id: string;
  specialty: Specialty;
  title: string;
  instructions: string;
  active: boolean;
  created_at: string;
};

export type CatalogExercise = {
  code: string;
  name: string;
  description: string;
  body_region: string;
  camera_view: "front" | "side";
  default_reps: number;
  precautions: string;
  created_by: string | null;
  detector: string | null;
  demo_video_path: string | null;
  demo_video_url: string | null;
};

export const detectorOptions: Array<{ value: string; label: string }> = [
  { value: "", label: "Sin conteo automático (solo video)" },
  { value: "squat", label: "Patrón de sentadilla (rodilla y cadera)" },
  { value: "knee_lift", label: "Patrón de elevación de rodilla" },
  { value: "quadriceps_stretch", label: "Patrón de flexión de rodilla hacia atrás" },
  { value: "bicep_curl", label: "Patrón de flexión de codo" },
  { value: "shoulder_raise", label: "Patrón de elevación de brazos" },
];

export type CareActivity = {
  id: string;
  title: string;
  instructions: string;
  due_on: string | null;
  exercise_code: string | null;
  target_reps: number | null;
  target_sets: number | null;
  cancelled: boolean;
  created_at: string;
};

export type ExerciseMetrics = {
  exercise: string;
  target_reps: number;
  complete_reps: number;
  incomplete_reps: number;
  fast_reps: number;
  avg_peak_angle_deg: number | null;
  avg_rep_seconds: number | null;
  tracked_ratio: number;
  duration_seconds: number;
  pattern_ok: boolean;
};

export type CareRecord = {
  mood?: string | null;
  body_zone?: string | null;
  id: string;
  session_id: string;
  activity_id: string | null;
  created_at: string;
  completed: boolean | null;
  pain: number | null;
  pain_after: number | null;
  note: string | null;
  evidence_path: string | null;
  exercise_metrics: ExerciseMetrics | null;
  details: Record<string, unknown>;
};

export type CareReview = {
  id: string;
  record_id: string;
  body: string;
  created_at: string;
};

type RpcResult = { ok: boolean; error?: string; [k: string]: unknown };

function check(result: unknown, fallback: string): RpcResult {
  const r = result as RpcResult | null;
  if (r && r.ok) return r;
  throw new Error(r?.error ?? fallback);
}

function fail(error: { message: string } | null) {
  if (error) throw new Error(friendly(error.message));
}

export function friendly(message: string) {
  if (/row-level security|permission denied/i.test(message)) {
    return "No tienes permiso para esta acción.";
  }
  if (/Invalid login credentials/i.test(message)) {
    return "Correo o contraseña incorrectos, o la cuenta no está confirmada.";
  }
  if (/Email not confirmed/i.test(message)) {
    return "Confirma tu correo antes de iniciar sesión.";
  }
  return message;
}

export async function myRole(): Promise<AccountRole> {
  const { data, error } = await supabase.rpc("my_role");
  fail(error);
  return data as AccountRole;
}

export type ProfessionalProfile = {
  display_name: string;
  specialty: Specialty;
  license_number: string;
  qualification?: string;
  phone?: string;
  clinic_name?: string;
  experience_years?: number | null;
};

export async function registerAsSpecialist(p: ProfessionalProfile) {
  const { data, error } = await supabase.rpc("register_as_specialist", {
    p_display_name: p.display_name,
    p_specialty: p.specialty,
    p_license_number: p.license_number,
    p_qualification: p.qualification || null,
    p_phone: p.phone || null,
    p_clinic_name: p.clinic_name || null,
    p_experience_years: p.experience_years ?? null,
  });
  fail(error);
  check(data, "No se pudo completar el registro profesional.");
}

/** Completes the professional profile saved at sign-up (email confirmation flow). */
export async function completePendingProfile(): Promise<boolean> {
  const { data } = await supabase.auth.getUser();
  const meta = data.user?.user_metadata as
    | { account_type?: string; professional?: ProfessionalProfile }
    | undefined;
  if (meta?.account_type !== "specialist" || !meta.professional) return false;
  await registerAsSpecialist(meta.professional);
  return true;
}

export async function specialistRequests(): Promise<LinkRequest[]> {
  const { data, error } = await supabase.rpc("specialist_link_requests");
  fail(error);
  return (data ?? []) as LinkRequest[];
}

export async function createInvite(specialty: Specialty, email: string) {
  const { data, error } = await supabase.rpc("create_care_invite", {
    p_specialty: specialty,
    p_recipient_email: email.trim(),
  });
  fail(error);
  return check(data, "No se pudo crear la invitación.") as RpcResult & {
    code: string;
    expires_at: string;
  };
}

export async function approve(requestId: string, title: string, instructions: string) {
  const { data, error } = await supabase.rpc("approve_care_link", {
    p_request_id: requestId,
    p_title: title.trim(),
    p_instructions: instructions.trim(),
  });
  fail(error);
  return check(data, "No se pudo aprobar.") as RpcResult & { session_id: string };
}

export async function reject(requestId: string) {
  const { data, error } = await supabase.rpc("reject_care_link", {
    p_request_id: requestId,
  });
  fail(error);
  check(data, "No se pudo rechazar.");
}

export async function closeSession(sessionId: string) {
  const { data, error } = await supabase.rpc("close_care_session", {
    p_session_id: sessionId,
  });
  fail(error);
  check(data, "No se pudo cerrar la sesión.");
}

export async function sessions(): Promise<CareSession[]> {
  const { data, error } = await supabase
    .from("care_sessions")
    .select("id, patient_id, specialty, title, instructions, active, created_at")
    .order("created_at", { ascending: false });
  fail(error);
  return (data ?? []) as CareSession[];
}

export async function session(id: string): Promise<CareSession | null> {
  const { data, error } = await supabase
    .from("care_sessions")
    .select("id, patient_id, specialty, title, instructions, active, created_at")
    .eq("id", id)
    .maybeSingle();
  fail(error);
  return data as CareSession | null;
}

export async function patientNames(ids: string[]): Promise<Record<string, string>> {
  if (ids.length === 0) return {};
  const { data, error } = await supabase
    .from("profiles")
    .select("id, full_name")
    .in("id", ids);
  fail(error);
  return Object.fromEntries(
    (data ?? []).map((p: { id: string; full_name: string }) => [p.id, p.full_name]),
  );
}

export async function catalog(): Promise<CatalogExercise[]> {
  const { data, error } = await supabase
    .from("exercise_catalog")
    .select(
      "code, name, description, body_region, camera_view, default_reps, precautions, created_by, detector, demo_video_path, demo_video_url",
    )
    .eq("active", true)
    .eq("specialty", "physio")
    .order("created_by", { ascending: false, nullsFirst: false })
    .order("name");
  fail(error);
  return (data ?? []) as CatalogExercise[];
}

export type NewExercise = {
  name: string;
  description: string;
  body_region: string;
  camera_view: "front" | "side";
  default_reps: number;
  precautions: string;
  detector: string;
  demo_video_url: string;
};

function randomCode() {
  const bytes = crypto.getRandomValues(new Uint8Array(8));
  return "c_" + Array.from(bytes, (b) => (b % 36).toString(36)).join("");
}

/** Creates a specialist-owned exercise; optional demo video goes to private storage. */
export async function createExercise(
  input: NewExercise,
  video: File | null,
  onStep?: (step: string) => void,
) {
  const { data: user } = await supabase.auth.getUser();
  const uid = user.user?.id;
  if (!uid) throw new Error("Inicia sesión de nuevo.");
  let demoPath: string | null = null;
  if (video) {
    if (video.size > 50 * 1024 * 1024) throw new Error("El video supera 50 MB.");
    const ext = video.name.split(".").pop()?.toLowerCase() || "mp4";
    demoPath = `${uid}/${crypto.randomUUID()}.${ext}`;
    onStep?.("Subiendo video de demostración…");
    const { error } = await supabase.storage
      .from("exercise-demos")
      .upload(demoPath, video, { contentType: video.type || "video/mp4" });
    fail(error);
  }
  onStep?.("Guardando ejercicio…");
  const { error } = await supabase.from("exercise_catalog").insert({
    code: randomCode(),
    specialty: "physio",
    name: input.name.trim(),
    description: input.description.trim(),
    body_region: input.body_region.trim() || "General",
    camera_view: input.camera_view,
    default_reps: input.default_reps,
    precautions: input.precautions.trim(),
    created_by: uid,
    detector: input.detector || null,
    demo_video_path: demoPath,
    demo_video_url: input.demo_video_url.trim() || null,
  });
  fail(error);
}

export async function archiveExercise(code: string) {
  const { error } = await supabase
    .from("exercise_catalog")
    .update({ active: false })
    .eq("code", code);
  fail(error);
}

export async function demoUrl(path: string): Promise<string> {
  const { data, error } = await supabase.storage
    .from("exercise-demos")
    .createSignedUrl(path, 300);
  fail(error);
  return data!.signedUrl;
}

export async function activities(sessionId: string): Promise<CareActivity[]> {
  const { data, error } = await supabase
    .from("care_activities")
    .select(
      "id, title, instructions, due_on, exercise_code, target_reps, target_sets, cancelled, created_at",
    )
    .eq("session_id", sessionId)
    .order("created_at", { ascending: false });
  fail(error);
  return (data ?? []) as CareActivity[];
}

export async function assignExercise(input: {
  sessionId: string;
  exercise: CatalogExercise;
  reps: number;
  sets: number;
  notes: string;
  dueOn: string | null;
}) {
  const { data: user } = await supabase.auth.getUser();
  const target = await session(input.sessionId);
  if (!target?.active || target.specialty !== "physio") throw new Error("Los ejercicios físicos solo corresponden a sesiones de fisioterapia.");
  const view =
    input.exercise.camera_view === "front"
      ? "Coloca el teléfono de frente, a unos 2 metros."
      : "Coloca el teléfono de lado, a unos 2 metros.";
  const { error } = await supabase.from("care_activities").insert({
    session_id: input.sessionId,
    created_by: user.user?.id,
    title: input.exercise.name,
    instructions: [
      input.exercise.description,
      view,
      input.exercise.precautions ? `Precaución: ${input.exercise.precautions}` : "",
      input.notes.trim(),
    ]
      .filter(Boolean)
      .join("\n"),
    exercise_code: input.exercise.code,
    target_reps: input.reps,
    target_sets: input.sets,
    due_on: input.dueOn || null,
  });
  fail(error);
}

export async function assignActivity(sessionId: string, title: string, instructions: string) {
  const { data: user } = await supabase.auth.getUser();
  const { error } = await supabase.from("care_activities").insert({
    session_id: sessionId,
    created_by: user.user?.id,
    title: title.trim(),
    instructions: instructions.trim(),
  });
  fail(error);
}

export async function cancelActivity(id: string) {
  const { error } = await supabase
    .from("care_activities")
    .update({ cancelled: true })
    .eq("id", id);
  fail(error);
}

export async function records(sessionId: string): Promise<CareRecord[]> {
  const { data, error } = await supabase
    .from("care_records")
    .select(
      "id, session_id, activity_id, created_at, completed, pain, pain_after, note, evidence_path, exercise_metrics, details, mood, body_zone",
    )
    .eq("session_id", sessionId)
    .order("created_at", { ascending: false });
  fail(error);
  return (data ?? []) as CareRecord[];
}

export async function recentRecords(sessionIds: string[]): Promise<CareRecord[]> {
  if (sessionIds.length === 0) return [];
  const { data, error } = await supabase
    .from("care_records")
    .select(
      "id, session_id, activity_id, created_at, completed, pain, pain_after, note, evidence_path, exercise_metrics, details, mood, body_zone",
    )
    .in("session_id", sessionIds)
    .order("created_at", { ascending: false })
    .limit(50);
  fail(error);
  return (data ?? []) as CareRecord[];
}

export async function reviews(sessionIds: string[]): Promise<CareReview[]> {
  if (sessionIds.length === 0) return [];
  const { data, error } = await supabase
    .from("care_reviews")
    .select("id, record_id, body, created_at")
    .in("session_id", sessionIds)
    .order("created_at");
  fail(error);
  return (data ?? []) as CareReview[];
}

export async function addReview(sessionId: string, recordId: string, body: string) {
  const { data: user } = await supabase.auth.getUser();
  const { error } = await supabase.from("care_reviews").insert({
    session_id: sessionId,
    record_id: recordId,
    specialist_id: user.user?.id,
    body: body.trim(),
  });
  fail(error);
}

/** 60-second signed URL for a private image or video. */
export async function evidenceUrl(path: string): Promise<string> {
  const { data, error } = await supabase.storage
    .from("care-evidence")
    .createSignedUrl(path, 60);
  fail(error);
  return data!.signedUrl;
}

export const exerciseNames: Record<string, string> = {
  bicep_curl: "Flexión de codo",
  quadriceps_stretch: "Estiramiento de cuádriceps",
  shoulder_raise: "Elevación de brazos",
  squat: "Sentadilla",
  knee_lift: "Elevación de rodilla",
};

export function formatDate(iso: string) {
  return new Date(iso).toLocaleString("es-MX", {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

export type PendingRecordInfo = {
  recordId: string;
  sessionId: string;
  patientName: string;
  activityTitle: string;
  pain: number | null;
  createdAt: string;
  metrics: ExerciseMetrics | null;
};

/**
 * Unreviewed care_records for the given active sessions,
 * enriched with patient name and activity title.
 */
export async function pendingRecordsWithInfo(
  activeSessions: CareSession[],
): Promise<PendingRecordInfo[]> {
  if (activeSessions.length === 0) return [];
  const ids = activeSessions.map((s) => s.id);
  const patientIds = [...new Set(activeSessions.map((s) => s.patient_id))];

  const [recs, revs, names] = await Promise.all([
    recentRecords(ids),
    reviews(ids),
    patientNames(patientIds),
  ]);

  const reviewed = new Set(revs.map((v) => v.record_id));
  const pending = recs.filter((r) => !reviewed.has(r.id));
  if (pending.length === 0) return [];

  // Fetch activity titles for pending records in one query
  const activityIds = [
    ...new Set(
      pending.map((r) => r.activity_id).filter(Boolean) as string[],
    ),
  ];
  let activityTitles: Record<string, string> = {};
  if (activityIds.length > 0) {
    const { data: acts, error } = await supabase
      .from("care_activities")
      .select("id, title")
      .in("id", activityIds);
    fail(error);
    activityTitles = Object.fromEntries(
      (acts ?? []).map((a: { id: string; title: string }) => [a.id, a.title]),
    );
  }

  const sessionMap = Object.fromEntries(activeSessions.map((s) => [s.id, s]));

  return pending.map((r) => {
    const sess = sessionMap[r.session_id];
    return {
      recordId: r.id,
      sessionId: r.session_id,
      patientName: names[sess?.patient_id ?? ""] ?? "Paciente",
      activityTitle:
        (r.activity_id ? activityTitles[r.activity_id] : null) ??
        "Actividad libre",
      pain: r.pain_after ?? r.pain,
      createdAt: r.created_at,
      metrics: r.exercise_metrics,
    };
  });
}

/**
 * Compliance percentage (0–100) for the last 7 days:
 * completed care_records / assigned (non-cancelled) care_activities.
 */
export async function weeklyCompliance(sessionIds: string[]): Promise<number> {
  if (sessionIds.length === 0) return 0;
  const sevenDaysAgo = new Date(
    Date.now() - 7 * 24 * 60 * 60 * 1000,
  ).toISOString();

  const { data: acts, error: actsErr } = await supabase
    .from("care_activities")
    .select("id")
    .in("session_id", sessionIds)
    .eq("cancelled", false)
    .gte("created_at", sevenDaysAgo);
  fail(actsErr);

  const assigned = acts ?? [];
  if (assigned.length === 0) return 0;
  const actIds = assigned.map((a: { id: string }) => a.id);

  const { data: recs, error: recsErr } = await supabase
    .from("care_records")
    .select("id")
    .in("activity_id", actIds)
    .eq("completed", true)
    .gte("created_at", sevenDaysAgo);
  fail(recsErr);

  return Math.round(((recs ?? []).length / assigned.length) * 100);
}
