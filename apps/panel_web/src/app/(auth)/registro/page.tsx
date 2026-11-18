"use client";

// Clinician sign-up adapted from fisio-app (MIT) auth schema (name, email,
// password) plus PhysioBuddy (MIT) DoctorProfile fields.
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Suspense, useEffect, useState } from "react";
import type { FormEvent } from "react";
import { AuthCard, Field } from "@/components/auth-card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { friendly, registerAsSpecialist, specialtyLabels } from "@/lib/data";
import type { ProfessionalProfile, Specialty } from "@/lib/data";
import { supabase } from "@/lib/supabase";
import { validatedUser, leaveAccount } from "@/lib/session";

function RegisterForm() {
  const router = useRouter();
  const [hasSession, setHasSession] = useState(false);
  const [checking, setChecking] = useState(true);
  const [sessionEmail, setSessionEmail] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [profile, setProfile] = useState<ProfessionalProfile>({
    display_name: "",
    specialty: "physio",
    license_number: "",
    qualification: "",
    phone: "",
    clinic_name: "",
    experience_years: null,
  });
  const [accepted, setAccepted] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);

  useEffect(() => {
    let alive = true;
    validatedUser().then((user) => {
      if (alive) { setHasSession(!!user); setSessionEmail(user?.email ?? ""); }
    }).catch((err) => { if (alive) setError(err.message); })
      .finally(() => { if (alive) setChecking(false); });
    return () => { alive = false; };
  }, []);

  const set = <K extends keyof ProfessionalProfile>(k: K, v: ProfessionalProfile[K]) =>
    setProfile((p) => ({ ...p, [k]: v }));

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (checking || busy) return;
    if (!accepted) {
      setError("Confirma la declaración para continuar.");
      return;
    }
    if (!/^[A-Za-z0-9-]{4,40}$/.test(profile.license_number.trim())) {
      setError("Cédula profesional: solo letras, números o guiones (4 a 40).");
      return;
    }
    setBusy(true);
    setError(null);
    try {
      if (hasSession) {
        const user = await validatedUser();
        if (!user || user.email !== sessionEmail) {
          setHasSession(false);
          throw new Error("La sesión cambió o la cuenta fue eliminada. Introduce tu correo y contraseña para registrarte.");
        }
      }
      if (!hasSession) {
        const { data, error } = await supabase.auth.signUp({
          email: email.trim(),
          password,
          options: {
            data: {
              account_type: "specialist",
              full_name: profile.display_name,
              professional: profile,
            },
          },
        });
        if (error) throw new Error(friendly(error.message));
        if (!data.session) {
          setInfo(
            "Te enviamos un correo de confirmación. Confírmalo e inicia sesión: tu perfil profesional se completará automáticamente.",
          );
          return;
        }
      }
      await registerAsSpecialist(profile);
      router.replace("/panel");
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }

  if (info) {
    return (
      <AuthCard title="Revisa tu correo" subtitle={info}>
        <Link href="/login" className="font-semibold text-[#123a52] underline">
          Ir a iniciar sesión
        </Link>
      </AuthCard>
    );
  }

  return (
    <AuthCard
      title={hasSession ? "Completa tu perfil profesional" : "Registro de profesional de la salud"}
      subtitle="Tu cuenta se mostrará como «no verificada» hasta que Med Box revise tu cédula."
    >
      {checking && <p role="status">Comprobando sesión…</p>}
      {hasSession && <div className="mb-4 grid gap-2 rounded-md bg-slate-50 p-3">
        <p className="break-all text-sm">Cuenta actual: {sessionEmail}</p>
        <Button type="button" variant="outline" disabled={busy} onClick={async () => {
          setBusy(true);
          try { await leaveAccount(); setHasSession(false); setSessionEmail(""); setEmail(""); setPassword(""); setError(null); }
          catch (err) { setError((err as Error).message); }
          finally { setBusy(false); }
        }}>Registrarme con otro correo</Button>
      </div>}
      <form onSubmit={handleSubmit} className="grid gap-4">
        {!hasSession && (
          <>
            <Field label="Correo electrónico">
              <Input
                type="email"
                required
                autoComplete="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </Field>
            <Field label="Contraseña (mínimo 8 caracteres)">
              <Input
                type="password"
                required
                minLength={8}
                autoComplete="new-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </Field>
          </>
        )}
        <Field label="Nombre profesional">
          <Input
            required
            minLength={3}
            maxLength={120}
            placeholder="Lic. Ana Pérez"
            value={profile.display_name}
            onChange={(e) => set("display_name", e.target.value)}
          />
        </Field>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Especialidad">
            <select
              className="min-h-10 rounded-md border border-[#d9e1dc] bg-white px-3 text-sm"
              value={profile.specialty}
              onChange={(e) => set("specialty", e.target.value as Specialty)}
            >
              {(Object.keys(specialtyLabels) as Specialty[]).map((s) => (
                <option key={s} value={s}>
                  {specialtyLabels[s]}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Cédula profesional">
            <Input
              required
              maxLength={40}
              value={profile.license_number}
              onChange={(e) => set("license_number", e.target.value.toUpperCase())}
            />
          </Field>
        </div>
        <Field label="Formación">
          <Input
            maxLength={160}
            value={profile.qualification}
            onChange={(e) => set("qualification", e.target.value)}
          />
        </Field>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Clínica o consultorio (opcional)">
            <Input
              maxLength={160}
              value={profile.clinic_name}
              onChange={(e) => set("clinic_name", e.target.value)}
            />
          </Field>
          <Field label="Teléfono (opcional)">
            <Input
              type="tel"
              maxLength={30}
              value={profile.phone}
              onChange={(e) => set("phone", e.target.value)}
            />
          </Field>
        </div>
        <Field label="Años de experiencia (opcional)">
          <Input
            type="number"
            min={0}
            max={70}
            value={profile.experience_years ?? ""}
            onChange={(e) =>
              set("experience_years", e.target.value === "" ? null : Number(e.target.value))
            }
          />
        </Field>
        <label className="flex items-start gap-2 text-sm text-[#123a52]">
          <input
            type="checkbox"
            className="mt-1"
            checked={accepted}
            onChange={(e) => setAccepted(e.target.checked)}
          />
          Declaro que los datos son correctos y entiendo que la cuenta aparece como no verificada.
        </label>
        {error && <p className="text-sm text-red-700">{error}</p>}
        <Button type="submit" disabled={busy || checking}>
          {busy ? "Guardando…" : hasSession ? "Guardar perfil" : "Crear cuenta"}
        </Button>
      </form>
      {!hasSession && (
        <p className="mt-6 text-sm text-[#66746e]">
          ¿Ya tienes cuenta?{" "}
          <Link href="/login" className="font-semibold text-[#123a52] underline">
            Inicia sesión
          </Link>
        </p>
      )}
    </AuthCard>
  );
}

export default function RegisterPage() {
  return (
    <Suspense>
      <RegisterForm />
    </Suspense>
  );
}
