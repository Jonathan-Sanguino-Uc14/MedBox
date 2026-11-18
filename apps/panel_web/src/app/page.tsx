"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { supabase } from "@/lib/supabase";

export default function Home() {
  const router = useRouter();
  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      router.replace(data.session ? "/panel" : "/login");
    });
  }, [router]);
  return <p className="p-8 text-[#66746e]">Cargando…</p>;
}
