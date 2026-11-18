"use client";

import { useEffect, useState } from "react";
import { useSpecialist } from "@/lib/use-specialist";
import { supabase } from "@/lib/supabase";
import { specialtyLabels } from "@/lib/data";

export default function ConsultorioPage() {
  const { role, specialty } = useSpecialist();
  const [email, setEmail] = useState<string | null>(null);

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => {
      if (data?.user?.email) setEmail(data.user.email);
    });
  }, []);

  if (!role) return null;

  const specialties = role.specialties ?? [specialty];

  return (
    <div className="mx-auto max-w-2xl space-y-5 p-6">
      <div>
        <h1
          className="text-2xl font-semibold text-[#0F172A]"
          style={{ fontFamily: "var(--font-manrope,'Manrope',system-ui)" }}
        >
          Mi consultorio
        </h1>
        <p className="mt-1 text-sm text-[#5B6475]">Información de tu cuenta profesional.</p>
      </div>

      <div className="rounded-xl border border-[#E5E9F0] bg-white divide-y divide-[#E5E9F0]">
        {/* Profile row */}
        <div className="flex items-center gap-4 p-5">
          <div
            className="flex h-14 w-14 flex-shrink-0 items-center justify-center rounded-2xl text-lg font-bold"
            style={{ background: "#CCEFEA", color: "#0F766E" }}
          >
            {role.display_name
              ? role.display_name
                  .trim()
                  .split(/\s+/)
                  .map((w) => w[0])
                  .slice(0, 2)
                  .join("")
                  .toUpperCase()
              : "?"}
          </div>
          <div>
            <p
              className="text-lg font-semibold text-[#0F172A]"
              style={{ fontFamily: "var(--font-manrope,'Manrope',system-ui)" }}
            >
              {role.display_name ?? "Sin nombre registrado"}
            </p>
            <div className="mt-1 flex flex-wrap gap-1.5">
              {specialties.map((s) => (
                <span
                  key={s}
                  className="rounded-full bg-[#EFF5FF] px-2.5 py-0.5 text-xs font-semibold text-[#1A3FA3]"
                >
                  {specialtyLabels[s]}
                </span>
              ))}
            </div>
          </div>
        </div>

        {/* Detail rows */}
        <dl className="divide-y divide-[#E5E9F0]">
          <Row label="Correo electrónico" value={email ?? "Cargando…"} />
          <Row
            label="Estado de verificación"
            value={
              role.verified ? (
                <span className="inline-flex items-center gap-1.5 text-sm font-semibold text-[#0F766E]">
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                    <path d="M20 6L9 17l-5-5" />
                  </svg>
                  Cuenta verificada
                </span>
              ) : (
                <span className="text-sm text-[#8A5300]">
                  Pendiente de verificación · Med Box aún no ha revisado tu cédula profesional
                </span>
              )
            }
          />
          <Row label="Tipo de cuenta" value="Especialista" />
        </dl>
      </div>

      {!role.verified && (
        <div className="rounded-xl border border-[#FFF6E5] bg-[#FFF6E5] p-4 text-sm text-[#8A5300]">
          <strong>¿Cómo verificar tu cuenta?</strong> El equipo de Med Box revisa tu cédula profesional manualmente. Puedes enviar un correo a soporte para agilizar el proceso.
        </div>
      )}
    </div>
  );
}

function Row({
  label,
  value,
}: {
  label: string;
  value: React.ReactNode;
}) {
  return (
    <div className="grid grid-cols-[200px_1fr] gap-4 px-5 py-3.5">
      <dt className="text-sm text-[#5B6475]">{label}</dt>
      <dd className="text-sm text-[#0F172A]">{value}</dd>
    </div>
  );
}
