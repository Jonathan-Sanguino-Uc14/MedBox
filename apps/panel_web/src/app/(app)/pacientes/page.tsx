"use client";

import { useSpecialist } from "@/lib/use-specialist";
import Link from "next/link";
import { useEffect, useState } from "react";
import { ErrorText, PageHeader } from "@/components/care";
import { Card } from "@/components/ui/card";
import { formatDate, patientNames, sessions, specialtyLabels } from "@/lib/data";
import type { CareSession } from "@/lib/data";

export default function PatientsPage() {
  const {specialty} = useSpecialist();
  const [list, setList] = useState<CareSession[] | null>(null);
  const [names, setNames] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const s = (await sessions()).filter((x) => x.active && x.specialty === specialty);
        setList(s);
        setNames(await patientNames([...new Set(s.map((x) => x.patient_id))]));
      } catch (e) {
        setError((e as Error).message);
      }
    })();
  }, [specialty]);

  return (
    <>
      <PageHeader
        title="Pacientes"
        subtitle="Solo ves las sesiones privadas activas que tú aprobaste."
      />
      <ErrorText error={error} />
      {list === null && !error && <p className="text-sm text-[#66746e]">Cargando…</p>}
      {list?.length === 0 && (
        <Card>
          <p className="text-sm text-[#66746e]">
            Aún no tienes pacientes. Invita a uno y aprueba su solicitud.
          </p>
        </Card>
      )}
      <div className="grid gap-4 md:grid-cols-2">
        {list?.map((s) => (
          <Link key={s.id} href={`/paciente?id=${s.id}`}>
            <Card className="transition hover:border-[#123a52]">
              <p className="text-sm text-[#66746e]">{specialtyLabels[s.specialty]}</p>
              <p className="mt-1 text-lg font-semibold text-[#123a52]">
                {names[s.patient_id] || "Paciente sin nombre registrado"}
              </p>
              <p className="text-sm text-[#123a52]">{s.title}</p>
              <p className="mt-2 text-xs text-[#66746e]">Desde {formatDate(s.created_at)}</p>
            </Card>
          </Link>
        ))}
      </div>
    </>
  );
}
