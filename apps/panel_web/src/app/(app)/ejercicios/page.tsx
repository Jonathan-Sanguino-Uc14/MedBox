"use client";

import { useSpecialist } from "@/lib/use-specialist";
import { useCallback, useEffect, useState } from "react";
import type { FormEvent } from "react";
import { ErrorText, PageHeader, Spinner } from "@/components/care";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import {
  archiveExercise,
  catalog,
  createExercise,
  demoUrl,
  detectorOptions,
} from "@/lib/data";
import type { CatalogExercise, NewExercise } from "@/lib/data";

const empty: NewExercise = {
  name: "",
  description: "",
  body_region: "",
  camera_view: "side",
  default_reps: 10,
  precautions: "",
  detector: "",
  demo_video_url: "",
};

function DemoVideo({ ex }: { ex: CatalogExercise }) {
  const [url, setUrl] = useState<string | null>(null);
  if (!ex.demo_video_path && !ex.demo_video_url) return null;
  if (url) {
    return <video src={url} controls autoPlay className="mt-3 max-h-72 w-full rounded-lg bg-black" />;
  }
  return (
    <Button
      variant="outline"
      className="mt-3"
      onClick={async () =>
        setUrl(ex.demo_video_path ? await demoUrl(ex.demo_video_path) : ex.demo_video_url)
      }
    >
      Ver video de demostración
    </Button>
  );
}

export default function ExercisesPage() {
 const { specialty } = useSpecialist();
 if(specialty !== "physio") return <PageHeader title="Esta sección es de fisioterapia" subtitle="Usa el menú de tu especialidad para asignar las actividades correspondientes."/>;
 return <PhysicalExercises/>;
}

function PhysicalExercises() {
  const [list, setList] = useState<CatalogExercise[]>([]);
  const [form, setForm] = useState<NewExercise>(empty);
  const [video, setVideo] = useState<File | null>(null);
  const [step, setStep] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [open, setOpen] = useState(false);

  const load = useCallback(() => {
    catalog().then(setList, (e) => setError((e as Error).message));
  }, []);
  useEffect(load, [load]);

  const set = <K extends keyof NewExercise>(k: K, v: NewExercise[K]) =>
    setForm((f) => ({ ...f, [k]: v }));

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setSaved(false);
    setStep("Preparando…");
    try {
      await createExercise(form, video, setStep);
      setForm(empty);
      setVideo(null);
      setSaved(true);
      setOpen(false);
      load();
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setStep(null);
    }
  }

  const mine = list.filter((x) => x.created_by);
  const base = list.filter((x) => !x.created_by);

  const card = (ex: CatalogExercise) => (
    <Card key={ex.code}>
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-sm text-[#66746e]">
            {ex.body_region} · Cámara {ex.camera_view === "front" ? "de frente" : "de lado"}
          </p>
          <h2 className="mt-1 text-lg font-semibold text-[#123a52]">{ex.name}</h2>
        </div>
        {ex.created_by && (
          <Button
            variant="ghost"
            onClick={async () => {
              if (window.confirm("¿Archivar este ejercicio? Ya no podrás asignarlo.")) {
                await archiveExercise(ex.code);
                load();
              }
            }}
          >
            Archivar
          </Button>
        )}
      </div>
      <p className="mt-2 whitespace-pre-line text-sm text-[#123a52]">{ex.description}</p>
      <p className="mt-2 text-sm text-[#66746e]">
        {ex.default_reps} repeticiones por defecto ·{" "}
        {ex.detector ? "conteo automático por cámara" : "solo video, sin conteo automático"}
        {ex.precautions && ` · ${ex.precautions}`}
      </p>
      <DemoVideo ex={ex} />
    </Card>
  );

  return (
    <>
      <PageHeader
        title="Ejercicios"
        subtitle="Crea tus propios ejercicios con un video de demostración. El paciente lo verá antes de grabarse."
      />
      <ErrorText error={error} />
      {saved && (
        <p className="mb-4 rounded-md bg-emerald-50 p-3 text-sm text-emerald-800">
          Ejercicio guardado. Ya puedes asignarlo desde la ficha de un paciente.
        </p>
      )}

      {!open ? (
        <Button className="mb-6" onClick={() => setOpen(true)}>
          + Nuevo ejercicio
        </Button>
      ) : (
        <Card className="relative mb-8 border-[#123a52]">
          {step && (
            <div className="absolute inset-0 z-10 flex flex-col items-center justify-center gap-3 rounded-lg bg-white/90">
              <Spinner />
              <p className="text-sm font-medium text-[#123a52]">{step}</p>
            </div>
          )}
          <h2 className="text-lg font-semibold text-[#123a52]">Nuevo ejercicio</h2>
          <form onSubmit={handleSubmit} className="mt-4 grid gap-4">
            <div className="grid gap-4 sm:grid-cols-2">
              <label className="grid gap-1.5 text-sm font-medium">
                Nombre
                <Input
                  required
                  minLength={3}
                  maxLength={120}
                  value={form.name}
                  onChange={(e) => set("name", e.target.value)}
                />
              </label>
              <label className="grid gap-1.5 text-sm font-medium">
                Región corporal
                <Input
                  maxLength={80}
                  placeholder="Rodilla, hombro, columna…"
                  value={form.body_region}
                  onChange={(e) => set("body_region", e.target.value)}
                />
              </label>
            </div>
            <label className="grid gap-1.5 text-sm font-medium">
              Instrucciones paso a paso
              <textarea
                required
                maxLength={2000}
                className="min-h-28 rounded-md border border-[#d9e1dc] p-3 text-sm"
                value={form.description}
                onChange={(e) => set("description", e.target.value)}
              />
            </label>
            <div className="grid gap-4 sm:grid-cols-3">
              <label className="grid gap-1.5 text-sm font-medium">
                Posición de la cámara
                <select
                  className="min-h-10 rounded-md border border-[#d9e1dc] bg-white px-3 text-sm"
                  value={form.camera_view}
                  onChange={(e) => set("camera_view", e.target.value as "front" | "side")}
                >
                  <option value="side">De lado</option>
                  <option value="front">De frente</option>
                </select>
              </label>
              <label className="grid gap-1.5 text-sm font-medium">
                Repeticiones por defecto
                <Input
                  type="number"
                  min={1}
                  max={100}
                  value={form.default_reps}
                  onChange={(e) => set("default_reps", Number(e.target.value))}
                />
              </label>
              <label className="grid gap-1.5 text-sm font-medium">
                Conteo automático
                <select
                  className="min-h-10 rounded-md border border-[#d9e1dc] bg-white px-3 text-sm"
                  value={form.detector}
                  onChange={(e) => set("detector", e.target.value)}
                >
                  {detectorOptions.map((o) => (
                    <option key={o.value} value={o.value}>
                      {o.label}
                    </option>
                  ))}
                </select>
              </label>
            </div>
            <label className="grid gap-1.5 text-sm font-medium">
              Precauciones (opcional)
              <Input
                maxLength={500}
                value={form.precautions}
                onChange={(e) => set("precautions", e.target.value)}
              />
            </label>
            <label className="grid gap-1.5 text-sm font-medium">
              Video de demostración (MP4 o WebM, máximo 50 MB)
              <input
                type="file"
                accept="video/mp4,video/webm,video/quicktime"
                className="text-sm"
                onChange={(e) => setVideo(e.target.files?.[0] ?? null)}
              />
            </label>
            {video && (
              <video
                src={URL.createObjectURL(video)}
                controls
                className="max-h-60 w-full rounded-lg bg-black"
              />
            )}
            <label className="grid gap-1.5 text-sm font-medium">
              O enlace directo a un video (https, opcional)
              <Input
                type="url"
                pattern="https://.*"
                placeholder="https://…/demostracion.mp4"
                value={form.demo_video_url}
                onChange={(e) => set("demo_video_url", e.target.value)}
              />
            </label>
            <div className="flex gap-2">
              <Button type="submit" disabled={!!step}>
                Guardar ejercicio
              </Button>
              <Button variant="ghost" onClick={() => setOpen(false)}>
                Cancelar
              </Button>
            </div>
          </form>
        </Card>
      )}

      {mine.length > 0 && (
        <>
          <h2 className="mb-3 text-lg font-semibold text-[#123a52]">Mis ejercicios</h2>
          <div className="mb-8 grid gap-4 md:grid-cols-2">{mine.map(card)}</div>
        </>
      )}
      <h2 className="mb-3 text-lg font-semibold text-[#123a52]">Ejercicios base</h2>
      <div className="grid gap-4 md:grid-cols-2">{base.map(card)}</div>
    </>
  );
}
