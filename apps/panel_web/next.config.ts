import type { NextConfig } from "next";
import { PHASE_DEVELOPMENT_SERVER } from "next/constants";

// Static export: the panel is a client app; all authorization is enforced by
// Supabase RLS and SECURITY DEFINER functions, never by this frontend.
const nextConfig = (phase: string): NextConfig => ({
  reactStrictMode: true,
  // Keep production builds from overwriting chunks used by the dev server.
  distDir: phase === PHASE_DEVELOPMENT_SERVER ? ".next-dev" : ".next",
  output: "export",
  images: { unoptimized: true },
});

export default nextConfig;
