"use client";

// Adapted from fisio-app (MIT, (c) 2026 Matias Riffo) components/layout/app-shell.tsx.

import { useState } from "react";
import type { ReactNode } from "react";
import { Navbar } from "./navbar";
import { Sidebar } from "./sidebar";
import { SpecialistProvider, useSpecialist } from "@/lib/use-specialist";

type AppShellProps = {
  children: ReactNode;
};

export function AppShell({ children }: AppShellProps) {
  const [sidebarOpen, setSidebarOpen] = useState(false);

  return (
    <SpecialistProvider>
    <div className="min-h-screen nav:flex">
      {sidebarOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/40 nav:hidden"
          onClick={() => setSidebarOpen(false)}
        />
      )}
      <Sidebar isOpen={sidebarOpen} onClose={() => setSidebarOpen(false)} />
      <div className="min-w-0 flex-1">
        <Navbar onMenuToggle={() => setSidebarOpen((prev) => !prev)} />
        <SpecialtyContent>{children}</SpecialtyContent>
      </div>
    </div>
    </SpecialistProvider>
  );
}

function SpecialtyContent({children}:{children:ReactNode}) { const {specialty}=useSpecialist(); return <main key={specialty} className="mx-auto w-full max-w-6xl px-4 py-8 md:px-8">{children}</main>; }
