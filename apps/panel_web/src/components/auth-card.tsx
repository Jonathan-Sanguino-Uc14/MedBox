import type { ReactNode } from "react";
import { BrandLogo } from "@/components/brand-logo";

// Layout inspired by fisio-app (MIT) app/(auth) pages.
export function AuthCard({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle: string;
  children: ReactNode;
}) {
  return (
    <main className="flex min-h-screen items-center justify-center px-4 py-10">
      <div className="w-full max-w-lg rounded-xl border border-[#d9e1dc] bg-white p-8 shadow-sm">
        <BrandLogo className="mb-5 w-64 max-w-full" />
        <p className="text-sm font-semibold uppercase tracking-[0.18em] text-[#76b8b1]">
          Panel profesional
        </p>
        <h1 className="mt-3 text-2xl font-semibold text-[#123a52]">{title}</h1>
        <p className="mt-2 text-sm text-[#66746e]">{subtitle}</p>
        <div className="mt-6">{children}</div>
      </div>
    </main>
  );
}

export function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label className="grid gap-1.5 text-sm font-medium text-[#123a52]">
      {label}
      {children}
    </label>
  );
}
