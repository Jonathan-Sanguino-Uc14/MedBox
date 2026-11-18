"use client";

import { useState } from "react";
import type { FormEvent } from "react";
import { ErrorText, PageHeader } from "@/components/care";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { createInvite, formatDate, specialtyLabels } from "@/lib/data";
import { useSpecialist } from "@/lib/use-specialist";

export default function InvitePage() {
  const { specialty } = useSpecialist();
  const [email, setEmail] = useState("");
  const [result, setResult] = useState<{ code: string; email: string; expires: string } | null>(
    null,
  );
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    setResult(null);
    setCopied(false);
    try {
      const r = await createInvite(specialty, email);
      setResult({ code: r.code, email: email.trim().toLowerCase(), expires: r.expires_at });
      setEmail("");
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }

  const message = result
    ? `Hola. Tu especialista en ${specialtyLabels[specialty].toLowerCase()} te invitó a Med Box para tu seguimiento. ` +
      `Descarga la app, crea tu cuenta con ${result.email} y en «Vincular con un código» escribe: ${result.code}. ` +
      `El código vence el ${formatDate(result.expires)}.`
    : "";

  return (
    <>
      <PageHeader
        title="Invitar paciente"
        subtitle="El código es de un solo uso, vence en 48 horas y solo funciona con el correo indicado."
      />
      <Card className="max-w-xl">
        <form onSubmit={handleSubmit} className="grid gap-4">
          <label className="grid gap-1.5 text-sm font-medium text-[#123a52]">
            Especialidad
            <p>{specialtyLabels[specialty]}</p>
          </label>
          <label className="grid gap-1.5 text-sm font-medium text-[#123a52]">
            Correo del paciente
            <Input
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </label>
          <ErrorText error={error} />
          <Button type="submit" disabled={busy}>
            {busy ? "Creando…" : "Crear código"}
          </Button>
        </form>
      </Card>

      {result && (
        <Card className="mt-6 max-w-xl border-[#123a52]">
          <p className="text-sm text-[#66746e]">
            Código para {result.email}. No se volverá a mostrar.
          </p>
          <p className="mt-3 select-all font-mono text-3xl font-semibold tracking-widest text-[#123a52]">
            {result.code}
          </p>
          <div className="mt-4 flex flex-wrap gap-2">
            <Button
              variant="outline"
              onClick={async () => {
                await navigator.clipboard.writeText(message);
                setCopied(true);
              }}
            >
              {copied ? "Mensaje copiado" : "Copiar mensaje"}
            </Button>
            <a
              className="inline-flex min-h-10 items-center rounded-md bg-[#25d366] px-4 text-sm font-semibold text-white"
              href={`https://wa.me/?text=${encodeURIComponent(message)}`}
              target="_blank"
              rel="noreferrer"
            >
              Enviar por WhatsApp
            </a>
            <a
              className="inline-flex min-h-10 items-center rounded-md border border-[#123a52] px-4 text-sm font-semibold text-[#123a52]"
              href={`mailto:${result.email}?subject=${encodeURIComponent("Tu invitación a Med Box")}&body=${encodeURIComponent(message)}`}
            >
              Enviar por correo
            </a>
          </div>
          <p className="mt-4 text-xs text-[#66746e]">
            Cuando el paciente ingrese el código aparecerá en «Inicio» para que lo apruebes.
          </p>
        </Card>
      )}
    </>
  );
}
