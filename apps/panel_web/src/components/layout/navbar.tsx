"use client";

// Adapted from fisio-app (MIT, (c) 2026 Matias Riffo) components/layout/navbar.tsx.

import Link from "next/link";
import { BrandLogo } from "@/components/brand-logo";
import { useRouter } from "next/navigation";
import { specialtyLabels, Specialty } from "@/lib/data";
import { supabase } from "@/lib/supabase";
import { useSpecialist } from "@/lib/use-specialist";

type NavbarProps = {
  onMenuToggle: () => void;
};

export function Navbar({ onMenuToggle }: NavbarProps) {
  const router = useRouter();
  const { role, specialty, setSpecialty } = useSpecialist();

  async function handleLogout() {
    await supabase.auth.signOut();
    router.push("/login");
  }

  return (
    <header className="sticky top-0 z-10 border-b border-[#d9e1dc] bg-white/90 px-4 py-3 backdrop-blur md:px-8">
      <div className="flex items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <button
            type="button"
            aria-label="Abrir menú"
            onClick={onMenuToggle}
            className="rounded-md p-1.5 text-[#123a52] transition hover:bg-[#f0f5f2] nav:hidden"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="22"
              height="22"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              strokeWidth={2}
            >
              <line x1="3" y1="6" x2="21" y2="6" />
              <line x1="3" y1="12" x2="21" y2="12" />
              <line x1="3" y1="18" x2="21" y2="18" />
            </svg>
          </button>
          <Link href="/panel" className="font-semibold text-[#123a52] nav:hidden">
            <BrandLogo className="w-24 sm:w-32" />
          </Link>
        </div>

        <label className="text-sm font-medium">Especialidad
          {role && role.specialties.length > 1 ? <select className="ml-2 rounded border p-2" value={specialty} onChange={e=>setSpecialty(e.target.value as Specialty)}>{role.specialties.map(s=><option key={s} value={s}>{specialtyLabels[s]}</option>)}</select> : <span className="ml-2">{specialtyLabels[specialty]}</span>}
        </label>
        <div className="hidden text-sm text-[#66746e] nav:block">
          {role?.display_name ?? "Seguimiento entre consultas"}
          {role && !role.verified && (
            <span className="ml-2 rounded bg-amber-100 px-2 py-0.5 text-xs text-amber-800">
              Cuenta no verificada
            </span>
          )}
        </div>

        <button
          type="button"
          onClick={handleLogout}
          className="rounded-md border border-[#d9e1dc] px-3 py-2 text-sm font-medium text-[#123a52] transition hover:border-[#123a52] hover:text-[#123a52]"
        >
          Cerrar sesión
        </button>
      </div>
    </header>
  );
}
