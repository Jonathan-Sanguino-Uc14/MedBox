import { createClient } from "@supabase/supabase-js";

// Publishable key only (same as the mobile app). Privileged keys never live here.
const url =
  process.env.NEXT_PUBLIC_SUPABASE_URL ?? "https://vdfqadtohwlolwuwgeki.supabase.co";
const key =
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ??
  "sb_publishable_qAuNWUI3XXNN4nJp6GBIww_fF4G7vHg";

export const supabase = createClient(url, key, {
  auth: { persistSession: true, autoRefreshToken: true },
});
