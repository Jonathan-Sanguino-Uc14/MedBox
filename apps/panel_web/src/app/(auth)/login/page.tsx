"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import type { FormEvent } from "react";
import { AuthCard, Field } from "@/components/auth-card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { friendly } from "@/lib/data";
import { supabase } from "@/lib/supabase";
import { leaveAccount } from "@/lib/session";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await leaveAccount();
      const { error } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
      if (error) throw new Error(friendly(error.message));
      router.replace("/panel");
    } catch (err) {
      setError((err as Error).message);
    } finally { setBusy(false); }
  }

  async function useAnotherEmail() {
    setBusy(true);
    setError(null);
    try {
      await leaveAccount();
      setEmail("");
      setPassword("");
      document.getElementById("login-email")?.focus();
    } catch (err) { setError((err as Error).message); }
    finally { setBusy(false); }
  }

  return (
    <AuthCard
      title="Iniciar sesión"
      subtitle="Gestiona pacientes, indicaciones y seguimiento de tu especialidad."
    >
      <form onSubmit={handleSubmit} className="grid gap-4">
        <Field label="Correo electrónico">
          <Input
            id="login-email"
            name="email"
            type="email"
            required
            autoComplete="username"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
          />
        </Field>
        <Field label="Contraseña">
          <Input
            type="password"
            required
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
        </Field>
        {error && <p role="alert" className="text-sm text-red-700">{error}</p>}
        <Button type="submit" disabled={busy}>
          {busy ? "Entrando…" : "Entrar"}
        </Button>
        <Button type="button" variant="outline" disabled={busy} onClick={useAnotherEmail}>Usar otro correo</Button>
      </form>
      <p className="mt-6 text-sm text-[#66746e]">
        ¿Eres profesional de la salud y no tienes cuenta?{" "}
        <Link href="/registro" className="font-semibold text-[#123a52] underline">
          Regístrate
        </Link>
      </p>
    </AuthCard>
  );
}
