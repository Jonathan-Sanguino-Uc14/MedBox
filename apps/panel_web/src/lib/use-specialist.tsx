"use client";

import { useRouter } from "next/navigation";
import { createContext, useContext, useEffect, useState } from "react";
import type { ReactNode } from "react";
import { completePendingProfile, myRole } from "./data";
import type { AccountRole, Specialty } from "./data";
import { supabase } from "./supabase";

type State = { role: AccountRole | null; error: string | null };
type ContextState = State & { specialty: Specialty; setSpecialty: (s: Specialty) => void };
const Ctx = createContext<ContextState>({ role: null, error: null, specialty: "physio", setSpecialty: () => {} });

/**
 * Client-side gate for the professional panel. It only routes the UI:
 * data access is enforced by Supabase RLS regardless of what renders here.
 */
export function SpecialistProvider({ children }: { children: ReactNode }) {
  const router = useRouter();
  const [specialty, setCurrentSpecialty] = useState<Specialty>("physio");
  const [state, setState] = useState<State>({ role: null, error: null });

  useEffect(() => {
    let alive = true;
    (async () => {
      const { data } = await supabase.auth.getSession();
      if (!data.session) {
        router.replace("/login");
        return;
      }
      try {
        let role = await myRole();
        if (role.role !== "specialist" && (await completePendingProfile())) {
          role = await myRole();
        }
        if (role.role !== "specialist") {
          router.replace("/registro?completar=1");
          return;
        }
        if (alive) { setCurrentSpecialty(role.specialties[0] ?? "physio"); setState({ role, error: null }); }
      } catch (e) {
        if (alive) setState({ role: null, error: (e as Error).message });
      }
    })();
    const { data: sub } = supabase.auth.onAuthStateChange((event) => {
      if (event === "SIGNED_OUT") router.replace("/login");
    });
    return () => {
      alive = false;
      sub.subscription.unsubscribe();
    };
  }, [router]);

  if (state.error) {
    return <p className="p-8 text-red-700">No se pudo cargar tu cuenta: {state.error}</p>;
  }
  if (!state.role) {
    return <p className="p-8 text-[#66746e]">Cargando…</p>;
  }
  return <Ctx.Provider value={{...state, specialty, setSpecialty: (s) => { if(state.role?.specialties.includes(s)) { setCurrentSpecialty(s); router.push("/panel"); } } }}>{children}</Ctx.Provider>;
}

export function useSpecialist() {
  return useContext(Ctx);
}
