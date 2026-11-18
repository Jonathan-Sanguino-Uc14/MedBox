"use client";
import { useState } from "react";
import Link from "next/link";
import { BrandLogo } from "@/components/brand-logo";
import { SpecialtyWorkspace } from "@/components/specialty-workspace";
import { Button } from "@/components/ui/button";
import { specialtyLabels } from "@/lib/data";
import type { CareActivity, CareRecord, CatalogExercise, Specialty } from "@/lib/data";

const day = (n: number) => new Date(Date.UTC(2026, 10, 17 - n, 17)).toISOString();

function record(id: string, n: number, extra: Partial<CareRecord>): CareRecord {
  return {
    id,
    session_id: "preview",
    activity_id: null,
    created_at: day(n),
    completed: null,
    pain: null,
    pain_after: null,
    note: null,
    evidence_path: null,
    exercise_metrics: null,
    details: {},
    ...extra,
  };
}

function activity(id: string, title: string, instructions: string, extra: Partial<CareActivity> = {}): CareActivity {
  return {
    id,
    title,
    instructions,
    due_on: null,
    exercise_code: null,
    target_reps: null,
    target_sets: null,
    cancelled: false,
    created_at: day(20),
    ...extra,
  };
}

const samples: Record<Specialty, { title: string; acts: CareActivity[]; recs: CareRecord[] }> = {
  skin: {
    title: "Dermatitis leve",
    acts: [
      activity("s1", "Crema tópica hidrocortisona 1%", "Aplicar 2 veces al día en la zona afectada durante 14 días."),
      activity("s2", "Protector solar FPS 50+", "Aplicar cada 3 horas en exposición al sol."),
    ],
    recs: [
      record("sr2", 1, { activity_id: "s1", completed: true, note: "La comezón bajó bastante.", details: { "Identificador de lesión": "L-01", Comezón: 2, "Etapa del tratamiento": "Seguimiento" } }),
      record("sr1", 9, { activity_id: "s1", completed: true, details: { "Identificador de lesión": "L-01", Comezón: 6, "Fototipo de piel": "III", "Tipo de piel": "Mixta" } }),
    ],
  },
  physio: {
    title: "Rehabilitación de rodilla",
    acts: [activity("p1", "Sentadilla asistida", "Baja despacio, con apoyo en una silla.", { exercise_code: "squat", target_reps: 10, target_sets: 3 })],
    recs: [1, 2, 3, 4, 5, 6].map((n) =>
      record(`pr${n}`, n, { activity_id: "p1", completed: true, pain: n + 1, pain_after: Math.max(1, n), body_zone: "Rodilla derecha" }),
    ),
  },
  eyes: {
    title: "Ojo seco",
    acts: [activity("e1", "Lágrimas artificiales", "1 gota en cada ojo 4 veces al día.")],
    recs: [
      record("er2", 2, { activity_id: "e1", completed: true, details: { Lateralidad: "Ambos" }, note: "Menos ardor por la tarde." }),
      record("er1", 6, { activity_id: "e1", completed: false, details: { Lateralidad: "Derecho" } }),
    ],
  },
  mind: {
    title: "Manejo de ansiedad",
    acts: [activity("m1", "Respiración guiada", "5 minutos antes de dormir.")],
    recs: [
      record("mr3", 1, { mood: "calm", completed: true, activity_id: "m1", details: { Ansiedad: 3, Estrés: 4, "Calidad del sueño": 7 } }),
      record("mr2", 4, { mood: "worry", details: { Ansiedad: 6, Estrés: 6, "Calidad del sueño": 5 } }),
      record("mr1", 7, { mood: "worry", details: { Ansiedad: 7, Estrés: 7, "Calidad del sueño": 4 } }),
    ],
  },
};

const instructions: Record<Specialty, string> = {
  skin: "Hidratación diaria y evitar irritantes.",
  physio: "Ejercicios 5 días por semana; detente si el dolor supera 6/10.",
  eyes: "Descansa la vista 20 segundos cada 20 minutos frente a pantallas.",
  mind: "Registra tu diario cada noche; lo revisamos en la próxima sesión.",
};

const catalog: CatalogExercise[] = [
  { code: "squat", name: "Sentadilla asistida", description: "Flexión de rodilla y cadera con apoyo.", body_region: "Rodilla", camera_view: "side", default_reps: 10, precautions: "Sin dolor agudo", created_by: null, detector: "squat", demo_video_path: null, demo_video_url: null },
];

export default function Preview() {
  const [specialty, setSpecialty] = useState<Specialty>("skin");
  const sample = samples[specialty];
  return (
    <main className="mx-auto max-w-6xl p-4 md:p-8">
      <header className="mb-6 flex flex-wrap items-center justify-between gap-4">
        <div>
          <BrandLogo className="mb-2 w-48" />
          <p className="font-semibold">Vista del profesional</p>
          <p className="text-sm text-slate-500">Vista previa con datos de ejemplo. Los cambios se pierden al salir.</p>
        </div>
        <Link href="/login" className="underline">
          Entrar al panel
        </Link>
      </header>
      <div className="mb-6 flex flex-wrap gap-3">
        {(Object.keys(specialtyLabels) as Specialty[]).map((s) => (
          <Button key={s} variant={s === specialty ? "primary" : "outline"} aria-pressed={specialty === s} onClick={() => setSpecialty(s)}>
            {specialtyLabels[s]}
          </Button>
        ))}
      </div>
      <SpecialtyWorkspace
        key={specialty}
        demo
        session={{ id: "preview", patient_id: "example", specialty, title: sample.title, instructions: instructions[specialty], active: true, created_at: day(20) }}
        patientName="María López García"
        records={sample.recs}
        activities={sample.acts}
        reviews={[]}
        catalog={catalog}
      />
    </main>
  );
}
