import { createClient } from "@supabase/supabase-js";

// Service-role client for privileged server-side actions (e.g. account deletion).
// Requires SUPABASE_SERVICE_ROLE_KEY (server-only secret). Returns null if missing.
export function createAdminClient() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !serviceKey) {
    return null;
  }

  return createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
}
