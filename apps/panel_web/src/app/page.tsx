"use client";

import { useRouter } from "next/navigation";
import { useEffect } from "react";
import { validatedUser } from "@/lib/session";

export default function Home() {
  const router = useRouter();
  useEffect(() => {
    validatedUser().then((user) => {
      router.replace(user ? "/panel" : "/login");
    }).catch(() => router.replace("/login"));
  }, [router]);
  return <p className="p-8 text-[#66746e]">Cargando…</p>;
}
