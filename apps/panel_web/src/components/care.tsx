"use client";

import { useState } from "react";
import { Button } from "@/components/ui/button";
import { evidenceUrl, exerciseNames } from "@/lib/data";
import type { ExerciseMetrics } from "@/lib/data";

export function PageHeader({ title, subtitle }: { title: string; subtitle?: string }) {
  return (
    <div className="mb-6">
      <h1 className="text-2xl font-semibold text-[#123a52]">{title}</h1>
      {subtitle && <p className="mt-1 text-sm text-[#66746e]">{subtitle}</p>}
    </div>
  );
}

export function Spinner() {
  return (
    <span
      role="status"
      aria-label="Cargando"
      className="inline-block h-10 w-10 animate-spin rounded-full border-4 border-[#76b8b1]/30 border-t-[#123a52]"
    />
  );
}

export function ErrorText({ error }: { error: string | null }) {
  return error ? <p className="text-sm text-red-700">{error}</p> : null;
}

/** Camera-estimated exercise summary sent by the patient app. */
export function MetricsCard({ m }: { m: ExerciseMetrics }) {
  const rows: Array<[string, string]> = [
    ["Ejercicio", exerciseNames[m.exercise] ?? m.exercise],
    ["Repeticiones completas", `${m.complete_reps} de ${m.target_reps}`],
    ["Incompletas", String(m.incomplete_reps ?? 0)],
    ["Muy rápidas", String(m.fast_reps ?? 0)],
    ["Ángulo promedio alcanzado", m.avg_peak_angle_deg == null ? "—" : `${m.avg_peak_angle_deg}°`],
    ["Tiempo por repetición", m.avg_rep_seconds == null ? "—" : `${m.avg_rep_seconds} s`],
    ["Cuerpo detectado", `${m.tracked_ratio}% del video`],
    ["Duración", `${m.duration_seconds} s`],
  ];
  return (
    <div
      className={
        "mt-3 rounded-lg border p-4 " +
        (m.pattern_ok ? "border-emerald-200 bg-emerald-50" : "border-amber-200 bg-amber-50")
      }
    >
      <p className="text-sm font-semibold text-[#123a52]">
        {m.pattern_ok ? "Patrón adecuado (estimación)" : "Patrón a revisar"}
      </p>
      <dl className="mt-2 grid grid-cols-1 gap-x-6 gap-y-1 text-sm sm:grid-cols-2">
        {rows.map(([k, v]) => (
          <div key={k} className="flex justify-between gap-4 border-b border-black/5 py-1">
            <dt className="text-[#66746e]">{k}</dt>
            <dd className="font-medium text-[#123a52]">{v}</dd>
          </div>
        ))}
      </dl>
      <p className="mt-2 text-xs text-[#66746e]">
        Estimación automática por cámara en el teléfono del paciente. Confirma con el video.
      </p>
    </div>
  );
}

/** Private image or video, loaded on demand through a 60 s signed URL. */
export function Evidence({ path }: { path: string }) {
  const [url, setUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const isVideo = /\.(mp4|mov)$/i.test(path);

  async function load() {
    try {
      setUrl(await evidenceUrl(path));
    } catch {
      setError("Archivo no disponible.");
    }
  }

  if (error) return <p className="mt-2 text-sm text-red-700">{error}</p>;
  if (!url) {
    return (
      <Button variant="outline" className="mt-3" onClick={load}>
        {isVideo ? "Ver video del ejercicio" : "Ver foto"}
      </Button>
    );
  }
  return isVideo ? (
    <video src={url} controls autoPlay className="mt-3 max-h-[480px] w-full rounded-lg bg-black" />
  ) : (
    // eslint-disable-next-line @next/next/no-img-element
    <img src={url} alt="Foto del registro" className="mt-3 max-h-80 rounded-lg" />
  );
}
