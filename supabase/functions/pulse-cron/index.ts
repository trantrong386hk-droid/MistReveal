import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";
import { dispatchPulseForUser } from "../_shared/pulse-core.ts";

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const cronSecret = Deno.env.get("PULSE_CRON_SECRET");

  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: "missing_supabase_env" }, 500);
  }

  if (cronSecret) {
    const header = req.headers.get("x-cron-secret") ?? "";
    if (header != cronSecret) {
      return json({ error: "forbidden" }, 403);
    }
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: companions, error } = await supabase
    .from("ai_companions")
    .select("user_id")
    .order("updated_at", { ascending: false })
    .limit(300);

  if (error) {
    console.error("[pulse-cron] load companions failed", error);
    return json({ error: "load_companions_failed" }, 500);
  }

  const userIds = Array.from(new Set((companions ?? []).map((r) => r.user_id).filter(Boolean)));
  const results: Array<{ user_id: string; dispatched: boolean; reason?: string }> = [];

  for (const userId of userIds) {
    const result = await dispatchPulseForUser({
      userId,
      source: "cron_hourly",
      dryRun: false,
    });
    results.push({ user_id: userId, dispatched: result.dispatched, reason: result.reason });
  }

  return json({ scanned: userIds.length, dispatched: results.filter((r) => r.dispatched).length, results });
});
