"use client";

import Link from "next/link";
import { BrandLogo } from "@/components/brand-logo";
import { usePathname } from "next/navigation";
import { useSpecialist } from "@/lib/use-specialist";
import { specialtyNavigation } from "@/lib/specialty-ui";
import { specialtyLabels } from "@/lib/data";

type SidebarProps = {
  isOpen?: boolean;
  onClose?: () => void;
};

/** Nav icon SVGs keyed by route prefix */
function NavIcon({ href }: { href: string }) {
  const style = { width: 18, height: 18, flexShrink: 0 } as const;
  if (href === "/panel")
    return (
      <svg style={style} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <rect x="3" y="3" width="7" height="7" rx="1.5" /><rect x="14" y="3" width="7" height="7" rx="1.5" />
        <rect x="3" y="14" width="7" height="7" rx="1.5" /><rect x="14" y="14" width="7" height="7" rx="1.5" />
      </svg>
    );
  if (href === "/agenda")
    return (
      <svg style={style} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <rect x="3" y="4" width="18" height="18" rx="2" /><path d="M16 2v4M8 2v4M3 10h18" />
      </svg>
    );
  if (href === "/pacientes")
    return (
      <svg style={style} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <circle cx="9" cy="7" r="4" /><path d="M3 21v-2a4 4 0 0 1 4-4h4a4 4 0 0 1 4 4v2" />
        <path d="M19 11v6m-3-3h6" />
      </svg>
    );
  if (href === "/ejercicios" || href === "/actividades")
    return (
      <svg style={style} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M17 11H7a1 1 0 0 0-1 1v1a1 1 0 0 0 1 1h10a1 1 0 0 0 1-1v-1a1 1 0 0 0-1-1z" />
        <path d="M5 12H3M21 12h-2M5 12V9M19 12V9M5 9H3M19 9h2" />
      </svg>
    );
  if (href === "/invitar")
    return (
      <svg style={style} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" />
        <polyline points="22,6 12,13 2,6" />
      </svg>
    );
  if (href === "/consultorio")
    return (
      <svg style={style} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
      </svg>
    );
  if (href === "/recursos")
    return (
      <svg style={style} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" /><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
      </svg>
    );
  return (
    <svg style={style} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="10" />
    </svg>
  );
}

/** Initials from display_name */
function initials(name: string | null | undefined) {
  if (!name) return "?";
  const parts = name.trim().split(/\s+/);
  if (parts.length === 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
}

export function Sidebar({ isOpen = false, onClose }: SidebarProps) {
  const pathname = usePathname();
  const { role, specialty } = useSpecialist();
  const navigation = specialtyNavigation(specialty);

  // Separate main nav (all except Consultorio) and bottom nav (Consultorio)
  const mainNav = navigation.filter((n) => n.href !== "/consultorio");
  const bottomNav = navigation.find((n) => n.href === "/consultorio");

  return (
    <>
      {/* Mobile overlay */}
      {isOpen && (
        <div
          className="fixed inset-0 z-40 bg-black/30 nav:hidden"
          onClick={onClose}
          aria-hidden="true"
        />
      )}

      <aside
        className={[
          "fixed inset-y-0 left-0 z-50 flex w-[260px] flex-col border-r border-[#E5E9F0] bg-white transition-transform",
          "nav:relative nav:translate-x-0",
          isOpen ? "translate-x-0" : "-translate-x-full",
        ].join(" ")}
      >
        {/* Logo */}
        <div className="flex items-center gap-2.5 px-5 py-5 border-b border-[#E5E9F0]">
          <Link href="/panel" className="flex items-center gap-2.5" onClick={onClose}>
            <BrandLogo className="w-48 max-w-full" />
          </Link>
        </div>

        {/* Main nav */}
        <nav className="flex-1 overflow-y-auto px-3 py-4" aria-label="Navegación principal">
          <ul className="grid gap-0.5">
            {mainNav.map((item) => {
              const isActive = item.href === "/panel"
                ? pathname === "/panel"
                : pathname.startsWith(item.href);
              return (
                <li key={item.href}>
                  <Link
                    href={item.href}
                    onClick={onClose}
                    className={[
                      "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
                      isActive
                        ? "bg-[#EFF5FF] text-[#1A3FA3]"
                        : "text-[#5B6475] hover:bg-[#F5F7FA] hover:text-[#0F172A]",
                    ].join(" ")}
                    aria-current={isActive ? "page" : undefined}
                  >
                    <NavIcon href={item.href} />
                    {item.label}
                  </Link>
                </li>
              );
            })}
          </ul>
        </nav>

        {/* Bottom: Consultorio + specialist card */}
        <div className="border-t border-[#E5E9F0] px-3 py-3">
          {bottomNav && (
            <Link
              href={bottomNav.href}
              onClick={onClose}
              className={[
                "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors mb-2",
                pathname === "/consultorio"
                  ? "bg-[#EFF5FF] text-[#1A3FA3]"
                  : "text-[#5B6475] hover:bg-[#F5F7FA] hover:text-[#0F172A]",
              ].join(" ")}
            >
              <NavIcon href="/consultorio" />
              {bottomNav.label}
            </Link>
          )}

          {/* Specialist card */}
          <div className="flex items-center gap-3 rounded-lg bg-[#F5F7FA] px-3 py-2.5">
            <div
              className="flex h-9 w-9 flex-shrink-0 items-center justify-center rounded-full text-sm font-bold"
              style={{ background: "#CCEFEA", color: "#0F766E" }}
            >
              {initials(role?.display_name)}
            </div>
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-semibold text-[#0F172A]">
                {role?.display_name ?? "Especialista"}
              </p>
              <p className="truncate text-xs text-[#5B6475]">
                {specialtyLabels[specialty]}
              </p>
            </div>
          </div>
        </div>
      </aside>
    </>
  );
}
