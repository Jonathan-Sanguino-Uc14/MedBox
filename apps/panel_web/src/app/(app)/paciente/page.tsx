"use client";

// Patient detail: loads the session and hands it to the specialty workspace.
import { useSpecialist } from "@/lib/use-specialist";
import { useRouter, useSearchParams } from "next/navigation";
import { Suspense, useCallback, useEffect, useState } from "react";
import { ErrorText } from "@/components/care";
import { SpecialtyWorkspace } from "@/components/specialty-workspace";
import {
  activities as loadActivities,
  catalog as loadCatalog,
  closeSession,
  formatDate,
  patientNames,
  records as loadRecords,
  reviews as loadReviews,
  session as loadSession,
  specialtyLabels,
} from "@/lib/data";
import type { CareActivity, CareRecord, CareReview, CareSession, CatalogExercise } from "@/lib/data";
import Link from "next/link";

function initials(name: string) {
  if (!name) return "P";
  const p = name.trim().split(/\s+/);
  if (p.length === 1) return p[0][0].toUpperCase();
  return (p[0][0] + p[p.length - 1][0]).toUpperCase();
}

const specialtyColors: Record<string, { bg: string; text: string }> = {
  physio: { bg: "#E8F6F3", text: "#0F766E" },
  skin: { bg: "#FBE7EC", text: "#BE3A5A" },
  eyes: { bg: "#EFF5FF", text: "#2457D6" },
  mind: { bg: "#F0EEFF", text: "#6B4FBB" },
};

function PatientDetail() {
  const { specialty } = useSpecialist();
  const id = useSearchParams().get("id") ?? "";
  const router = useRouter();
  const [s, setS] = useState<CareSession | null>(null);
  const [name, setName] = useState("");
  const [acts, setActs] = useState<CareActivity[]>([]);
  const [recs, setRecs] = useState<CareRecord[]>([]);
  const [revs, setRevs] = useState<CareReview[]>([]);
  const [cat, setCat] = useState<CatalogExercise[]>([]);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!id) return;
    try {
      const sess = await loadSession(id);
      if (!sess || !sess.active) {
        setError("Sesión no disponible o cerrada.");
        return;
      }
      setS(sess);
      const [n, a, r, v, c] = await Promise.all([
        patientNames([sess.patient_id]),
        loadActivities(id),
        loadRecords(id),
        loadReviews([id]),
        sess.specialty === "physio" ? loadCatalog() : Promise.resolve([]),
      ]);
      setName(n[sess.patient_id] ?? "");
      setActs(a);
      setRecs(r);
      setRevs(v);
      setCat(c);
    } catch (e) {
      setError((e as Error).message);
    }
  }, [id]);

  useEffect(() => {
    load();
  }, [load]);

  if (!s) {
    return (
      <div className="p-6">
        {error
          ? <ErrorText error={error} />
          : <p className="text-sm text-[#5B6475]">Cargando expediente…</p>}
      </div>
    );
  }

  if (s.specialty !== specialty) {
    return (
      <div className="mx-auto max-w-2xl p-6">
        <div className="rounded-xl border border-[#E5E9F0] bg-white p-6 text-center">
          <p className="font-semibold text-[#0F172A]">
            Esta sesión pertenece a {specialtyLabels[s.specialty]}
          </p>
          <p className="mt-1 text-sm text-[#5B6475]">
            Cambia a esa especialidad desde el menú superior para consultar su expediente.
          </p>
        </div>
      </div>
    );
  }

  const spColors = specialtyColors[s.specialty] ?? specialtyColors.physio;

  return (
    <div className="mx-auto max-w-5xl space-y-5 p-6">
      {/* Patient header card */}
      <div className="rounded-xl border border-[#E5E9F0] bg-white p-5">
        <div className="flex flex-wrap items-start gap-4">
          {/* Avatar */}
          <div
            className="flex h-16 w-16 flex-shrink-0 items-center justify-center rounded-2xl text-xl font-bold"
            style={{ background: spColors.bg, color: spColors.text }}
          >
            {initials(name)}
          </div>

          {/* Name + chips */}
          <div className="flex-1">
            <div className="flex flex-wrap items-center gap-2">
              <h1
                className="text-xl font-semibold text-[#0F172A]"
                style={{ fontFamily: "var(--font-manrope,'Manrope',system-ui)" }}
              >
                {name || "Paciente sin nombre registrado"}
              </h1>
              <span
                className="rounded-full px-2.5 py-0.5 text-xs font-semibold"
                style={{ background: spColors.bg, color: spColors.text }}
              >
                {specialtyLabels[s.specialty]}
              </span>
              {s.active && (
                <span className="rounded-full bg-[#E8F6F3] px-2.5 py-0.5 text-xs font-semibold text-[#0F766E]">
                  Sesión activa
                </span>
              )}
            </div>
            <p className="mt-1 text-sm text-[#5B6475]">
              {s.title} · desde {formatDate(s.created_at)}
            </p>
          </div>

          {/* Action buttons */}
          <div className="flex flex-shrink-0 items-center gap-2">
            <Link
              href="/pacientes"
              className="rounded-lg border border-[#E5E9F0] bg-white px-3 py-2 text-sm font-medium text-[#5B6475] transition hover:bg-[#F5F7FA]"
            >
              ← Volver
            </Link>
          </div>
        </div>
      </div>

      <ErrorText error={error} />

      <SpecialtyWorkspace
        key={s.id}
        session={s}
        patientName={name}
        records={recs}
        activities={acts}
        reviews={revs}
        catalog={cat}
        onChanged={load}
        onClose={async () => {
          try {
            await closeSession(s.id);
            router.replace("/pacientes");
          } catch (e) {
            setError((e as Error).message);
          }
        }}
      />
    </div>
  );
}

export default function PatientPage() {
  return (
    <Suspense>
      <PatientDetail />
    </Suspense>
  );
}
