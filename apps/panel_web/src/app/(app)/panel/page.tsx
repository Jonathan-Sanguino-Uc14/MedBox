"use client";

import { specialtyUI } from "@/lib/specialty-ui";
import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { ErrorText } from "@/components/care";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  approve,
  formatDate,
  pendingRecordsWithInfo,
  recentRecords,
  reject,
  reviews,
  sessions,
  specialistRequests,
  specialtyLabels,
  statusLabels,
  weeklyCompliance,
} from "@/lib/data";
import type { CareRecord, CareSession, LinkRequest, PendingRecordInfo } from "@/lib/data";
import { useSpecialist } from "@/lib/use-specialist";
import { useRouter } from "next/navigation";
import { addDays, appointmentsBetween, dayKey, getSettings, localToDate } from "@/lib/agenda";

function PainBadge({ pain }: { pain: number | null }) {
  if (pain === null) return <span className="text-xs text-[#5B6475]">—</span>;
  if (pain >= 7) return <span className="pain-hi">{pain}/10</span>;
  if (pain >= 4) return <span className="pain-mid">{pain}/10</span>;
  return <span className="pain-lo">{pain}/10</span>;
}

function StatCard({
  label,
  value,
  sub,
  highlight,
}: {
  label: string;
  value: string | number;
  sub?: string;
  highlight?: boolean;
}) {
  return (
    <div className="rounded-xl border border-[#E5E9F0] bg-white p-5">
      <p className="text-sm text-[#5B6475]">{label}</p>
      <p
        className={[
          "mt-1 text-3xl font-semibold",
          highlight ? "text-[#A12A2A]" : "text-[#0F172A]",
        ].join(" ")}
      >
        {value}
      </p>
      {sub && <p className="mt-1 text-xs text-[#5B6475]">{sub}</p>}
    </div>
  );
}

export default function PanelPage() {
  const { role, specialty } = useSpecialist();
  const router = useRouter();
  const [requests, setRequests] = useState<LinkRequest[]>([]);
  const [active, setActive] = useState<CareSession[]>([]);
  const [pendingInfoList, setPendingInfoList] = useState<PendingRecordInfo[]>([]);
  const [compliance, setCompliance] = useState<number | null>(null);
  const [approving, setApproving] = useState<LinkRequest | null>(null);
  const [title, setTitle] = useState("");
  const [instructions, setInstructions] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [search, setSearch] = useState("");
  const [allRecs, setAllRecs] = useState<CareRecord[]>([]);
  const [todayAppts, setTodayAppts] = useState<{ total: number; bot: number } | null>(null);

  const load = useCallback(async () => {
    try {
      const [r, s] = await Promise.all([specialistRequests(), sessions()]);
      const act = s.filter((x) => x.active && x.specialty === specialty);
      setRequests(r.filter((x) => x.specialty === specialty));
      setActive(act);

      const ids = act.map((x) => x.id);
      const [info, pct, recs] = await Promise.all([
        pendingRecordsWithInfo(act),
        weeklyCompliance(ids),
        recentRecords(ids),
      ]);
      setPendingInfoList(info);
      setCompliance(pct);
      setAllRecs(recs);

      const cfg = await getSettings();
      const key = dayKey(new Date(), cfg.timezone);
      const appts = await appointmentsBetween(
        localToDate(key, "00:00", cfg.timezone),
        localToDate(addDays(key, 1), "00:00", cfg.timezone),
      );
      const live = appts.filter(
        (a) => a.specialty === specialty && a.status !== "cancelled" && a.status !== "no_show",
      );
      setTodayAppts({ total: live.length, bot: live.filter((a) => a.source === "assistant").length });
    } catch (e) {
      setError((e as Error).message);
    }
  }, [specialty]);

  useEffect(() => {
    load();
  }, [load]);

  async function run(action: () => Promise<unknown>) {
    setBusy(true);
    setError(null);
    try {
      await action();
      setApproving(null);
      await load();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  const open = requests.filter((r) => r.status === "pending");

  // "Necesitan atención": pain ≥7 + inactive ≥5 days + pending requests
  const fiveDaysAgo = Date.now() - 5 * 24 * 60 * 60 * 1000;
  const lastRecordBySession = new Map<string, number>();
  for (const r of allRecs) {
    const ts = new Date(r.created_at).getTime();
    const prev = lastRecordBySession.get(r.session_id) ?? 0;
    if (ts > prev) lastRecordBySession.set(r.session_id, ts);
  }
  const inactiveSessions = active.filter((s) => {
    const last = lastRecordBySession.get(s.id);
    return !last || last < fiveDaysAgo;
  });

  const highPainRecords = pendingInfoList.filter(
    (r) => r.pain !== null && r.pain >= 7,
  );

  const today = new Date().toLocaleDateString("es-MX", {
    weekday: "long",
    day: "numeric",
    month: "long",
  });

  const greeting =
    new Date().getHours() < 12
      ? "Buenos días"
      : new Date().getHours() < 19
        ? "Buenas tardes"
        : "Buenas noches";

  return (
    <div className="mx-auto max-w-5xl space-y-6 p-6">
      {/* Header */}
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <p className="text-sm text-[#5B6475] capitalize">{today}</p>
          <h1
            className="text-2xl font-semibold text-[#0F172A]"
            style={{ fontFamily: "var(--font-manrope,'Manrope',system-ui)" }}
          >
            {greeting}, {role?.display_name?.split(" ")[0] ?? "especialista"}
          </h1>
        </div>
        <div className="flex items-center gap-3">
          <input
            type="search"
            placeholder="Buscar paciente…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && search.trim()) {
                router.push(`/pacientes?q=${encodeURIComponent(search.trim())}`);
              }
            }}
            className="h-9 w-52 rounded-lg border border-[#E5E9F0] bg-white px-3 text-sm text-[#0F172A] placeholder:text-[#5B6475] focus:outline-2 focus:outline-[#2457D6]"
          />
          {/* Notification bell */}
          <button
            className="relative flex h-9 w-9 items-center justify-center rounded-lg border border-[#E5E9F0] bg-white text-[#5B6475] transition hover:bg-[#F5F7FA]"
            aria-label="Notificaciones"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
              <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" />
              <path d="M13.73 21a2 2 0 0 1-3.46 0" />
            </svg>
            {(open.length > 0 || highPainRecords.length > 0) && (
              <span className="absolute right-1.5 top-1.5 h-2 w-2 rounded-full bg-[#A12A2A]" />
            )}
          </button>
          <Link
            href="/invitar"
            className="inline-flex h-9 items-center gap-2 rounded-lg bg-[#2457D6] px-4 text-sm font-semibold text-white transition hover:bg-[#1A3FA3]"
          >
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" />
              <line x1="19" y1="8" x2="19" y2="14" /><line x1="22" y1="11" x2="16" y2="11" />
            </svg>
            Invitar paciente
          </Link>
        </div>
      </div>

      {role && !role.verified && (
        <p className="rounded-lg border border-[#FFF6E5] bg-[#FFF6E5] p-3 text-sm text-[#8A5300]">
          Cuenta profesional pendiente de verificación. Med Box aún no revisa tu cédula.
        </p>
      )}
      <ErrorText error={error} />

      {/* 4 stat cards */}
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard
          label="Citas hoy"
          value={todayAppts === null ? "—" : todayAppts.total}
          sub={
            todayAppts === null
              ? "Cargando…"
              : todayAppts.bot
                ? `${todayAppts.bot} agendada${todayAppts.bot === 1 ? "" : "s"} por el asistente`
                : "Ver agenda"
          }
        />
        <StatCard
          label="Por revisar"
          value={pendingInfoList.length}
          highlight={pendingInfoList.length > 0}
        />
        <StatCard
          label="Pacientes activos"
          value={active.length}
          sub={
            open.length > 0 ? `+ ${open.length} solicitud${open.length > 1 ? "es" : ""} pendiente${open.length > 1 ? "s" : ""}` : undefined
          }
        />
        <StatCard
          label="Cumplimiento semanal"
          value={compliance !== null ? `${compliance}%` : "—"}
          sub="Últimos 7 días"
        />
      </div>

      <div className="grid gap-6 xl:grid-cols-[1fr_320px]">
        {/* Por revisar */}
        <div className="rounded-xl border border-[#E5E9F0] bg-white">
          <div className="flex items-center justify-between border-b border-[#E5E9F0] px-5 py-4">
            <h2 className="text-base font-semibold text-[#0F172A]">Por revisar</h2>
            {pendingInfoList.length > 0 && (
              <span className="rounded-full bg-[#FDF0F0] px-2.5 py-0.5 text-xs font-semibold text-[#A12A2A]">
                {pendingInfoList.length}
              </span>
            )}
          </div>
          {pendingInfoList.length === 0 ? (
            <p className="px-5 py-4 text-sm text-[#5B6475]">
              Sin registros pendientes. Buen trabajo.
            </p>
          ) : (
            <ul className="divide-y divide-[#E5E9F0]">
              {pendingInfoList.slice(0, 10).map((r) => (
                <li
                  key={r.recordId}
                  className="flex items-center justify-between gap-4 px-5 py-3"
                >
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-medium text-[#0F172A]">
                      {r.patientName}
                    </p>
                    <p className="truncate text-xs text-[#5B6475]">
                      {r.activityTitle}
                      {r.metrics &&
                        ` · ${r.metrics.complete_reps}/${r.metrics.target_reps} rep.`}
                    </p>
                  </div>
                  <div className="flex flex-shrink-0 items-center gap-3">
                    <PainBadge pain={r.pain} />
                    <Link
                      href={`/paciente?id=${r.sessionId}`}
                      className="text-xs font-semibold text-[#2457D6] hover:underline"
                    >
                      Revisar
                    </Link>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>

        {/* Necesitan atención */}
        <div className="rounded-xl border border-[#E5E9F0] bg-white">
          <div className="border-b border-[#E5E9F0] px-5 py-4">
            <h2 className="text-base font-semibold text-[#0F172A]">Necesitan atención</h2>
          </div>
          <ul className="divide-y divide-[#E5E9F0]">
            {highPainRecords.length === 0 && inactiveSessions.length === 0 && open.length === 0 && (
              <li className="px-5 py-4 text-sm text-[#5B6475]">Sin alertas activas.</li>
            )}
            {highPainRecords.map((r) => (
              <li key={r.recordId} className="flex items-center gap-3 px-5 py-3">
                <span className="flex h-7 w-7 flex-shrink-0 items-center justify-center rounded-full bg-[#FDF0F0] text-xs font-bold text-[#A12A2A]">!</span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium text-[#0F172A]">{r.patientName}</p>
                  <p className="text-xs text-[#A12A2A]">Dolor {r.pain}/10</p>
                </div>
                <Link href={`/paciente?id=${r.sessionId}`} className="text-xs font-semibold text-[#2457D6] hover:underline">
                  Ver
                </Link>
              </li>
            ))}
            {inactiveSessions.map((s) => (
              <li key={s.id} className="flex items-center gap-3 px-5 py-3">
                <span className="flex h-7 w-7 flex-shrink-0 items-center justify-center rounded-full bg-[#FFF6E5] text-xs font-bold text-[#8A5300]">!</span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium text-[#0F172A]">{s.title}</p>
                  <p className="text-xs text-[#8A5300]">Sin actividad 5+ días</p>
                </div>
                <Link href={`/paciente?id=${s.id}`} className="text-xs font-semibold text-[#2457D6] hover:underline">
                  Ver
                </Link>
              </li>
            ))}
            {open.map((r) => (
              <li key={r.id} className="flex items-center gap-3 px-5 py-3">
                <span className="flex h-7 w-7 flex-shrink-0 items-center justify-center rounded-full bg-[#EFF5FF] text-xs font-bold text-[#1A3FA3]">+</span>
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-medium text-[#0F172A]">{r.recipient_email}</p>
                  <p className="text-xs text-[#5B6475]">Solicitud pendiente · {specialtyLabels[r.specialty]}</p>
                </div>
                <button
                  className="text-xs font-semibold text-[#2457D6] hover:underline"
                  onClick={() => {
                    setApproving(r);
                    setTitle(specialtyUI[r.specialty].session);
                    setInstructions("");
                  }}
                >
                  Aprobar
                </button>
              </li>
            ))}
          </ul>
        </div>
      </div>

      {/* Approve dialog */}
      {approving && (
        <div className="rounded-xl border border-[#2457D6] bg-white p-5">
          <h2 className="text-base font-semibold text-[#0F172A]">
            Crear sesión para {approving.recipient_email}
          </h2>
          <div className="mt-4 grid gap-3">
            <label className="grid gap-1 text-sm font-medium">
              Título de la sesión
              <Input value={title} maxLength={160} onChange={(e) => setTitle(e.target.value)} />
            </label>
            <label className="grid gap-1 text-sm font-medium">
              Indicaciones generales
              <textarea
                className="min-h-24 rounded-lg border border-[#E5E9F0] p-3 text-sm font-normal"
                maxLength={4000}
                value={instructions}
                onChange={(e) => setInstructions(e.target.value)}
              />
            </label>
            <div className="flex gap-2">
              <Button
                disabled={busy || !title.trim()}
                onClick={() =>
                  run(() => approve(approving.id, title, instructions))
                }
              >
                {busy ? "Creando…" : "Aprobar y crear sesión"}
              </Button>
              <Button variant="ghost" onClick={() => setApproving(null)}>
                Cancelar
              </Button>
            </div>
          </div>
        </div>
      )}

      {/* Solicitudes de vínculo (historial) */}
      {requests.length > 0 && (
        <div className="rounded-xl border border-[#E5E9F0] bg-white">
          <div className="border-b border-[#E5E9F0] px-5 py-4">
            <h2 className="text-base font-semibold text-[#0F172A]">Solicitudes de vínculo</h2>
          </div>
          <ul className="divide-y divide-[#E5E9F0]">
            {requests.map((r) => (
              <li
                key={r.id}
                className="flex flex-wrap items-center justify-between gap-3 px-5 py-3"
              >
                <div>
                  <p className="text-sm font-medium text-[#0F172A]">{r.recipient_email}</p>
                  <p className="text-xs text-[#5B6475]">
                    {specialtyLabels[r.specialty]} · {statusLabels[r.status] ?? r.status} ·{" "}
                    {formatDate(r.created_at)}
                  </p>
                </div>
                {r.status === "pending" && (
                  <div className="flex gap-2">
                    <Button
                      onClick={() => {
                        setApproving(r);
                        setTitle(specialtyUI[r.specialty].session);
                        setInstructions("");
                      }}
                    >
                      Aprobar
                    </Button>
                    <Button
                      variant="outline"
                      disabled={busy}
                      onClick={() => run(() => reject(r.id))}
                    >
                      Rechazar
                    </Button>
                  </div>
                )}
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
