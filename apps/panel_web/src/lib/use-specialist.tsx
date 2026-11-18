"use client";

import { useRouter } from "next/navigation";
import { createContext, useContext, useEffect, useState } from "react";
import type { ReactNode } from "react";
import { completePendingProfile, myRole } from "./data";
import type { AccountRole, Specialty } from "./data";
import { supabase } from "./supabase";
import { validatedUser, leaveAccount } from "./session";

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
    let revision = 0;
    let currentUserId: string | null = null;
    async function load() {
      const request = ++revision;
      try {
        const user = await validatedUser();
        if (!alive || request !== revision) return;
        if (!user) { setState({ role: null, error: null }); router.replace("/login"); return; }
        if (currentUserId === user.id) return;
        let role = await myRole();
        if (role.role !== "specialist" && (await completePendingProfile())) role = await myRole();
        if (!alive || request !== revision) return;
        if (role.role !== "specialist") { router.replace("/registro?completar=1"); return; }
        currentUserId = user.id;
        setCurrentSpecialty(role.specialties[0] ?? "physio");
        setState({ role, error: null });
      } catch (e) {
        if (alive && request === revision) { currentUserId = null; setState({ role: null, error: (e as Error).message }); }
      }
    }
    void load();
    const { data: sub } = supabase.auth.onAuthStateChange((event, session) => {
      if (event === "SIGNED_OUT") {
        ++revision;
        currentUserId = null;
        setState({ role: null, error: null });
        router.replace("/login");
      } else if (event === "SIGNED_IN" && currentUserId && session?.user.id !== currentUserId) {
        ++revision;
        setState({ role: null, error: null });
        // Defer Auth calls until the auth callback has returned.
        setTimeout(() => { if (alive) void load(); }, 0);
      }
    });
    const revalidate = () => { if (document.visibilityState === "visible") void load(); };
    document.addEventListener("visibilitychange", revalidate);
    return () => {
      alive = false;
      ++revision;
      document.removeEventListener("visibilitychange", revalidate);
      sub.subscription.unsubscribe();
    };
  }, [router]);

  if (state.error) {
    return <div className="grid gap-4 p-8"><p role="alert" className="text-red-700">No se pudo cargar tu cuenta: {state.error}</p><button onClick={() => window.location.reload()}>Reintentar</button><button onClick={async () => { try { await leaveAccount(); router.replace("/login"); } catch (e) { setState({role: null, error: (e as Error).message}); } }}>Usar otro correo</button></div>;
  }
  if (!state.role) {
    return <p className="p-8 text-[#66746e]">Cargando…</p>;
  }
  return <Ctx.Provider value={{...state, specialty, setSpecialty: (s) => { if(state.role?.specialties.includes(s)) { setCurrentSpecialty(s); router.push("/panel"); } } }}>{children}</Ctx.Provider>;
}

export function useSpecialist() {
  return useContext(Ctx);
}
