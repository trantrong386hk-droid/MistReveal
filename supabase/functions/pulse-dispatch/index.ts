import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";
import { dispatchPulseForUser } from "../_shared/pulse-core.ts";

type DispatchBody = {
  user_id?: string;
  source?: string;
  dry_run?: boolean;
  timezone?: string;
};

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

  let body: DispatchBody = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }

  const source = body.source ?? "manual";
  const dryRun = body.dry_run ?? false;
  const authHeader = req.headers.get("Authorization") ?? "";
  const bearer = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : "";
  const cronHeader = req.headers.get("x-cron-secret") ?? "";

  let userId = body.user_id;

  if (!userId) {
    if (!bearer) {
      return json({ error: "missing_auth" }, 401);
    }
    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error } = await supabase.auth.getUser(bearer);
    if (error || !data.user) {
      return json({ error: "invalid_user" }, 401);
    }
    userId = data.user.id;
  } else if (cronSecret) {
    if (cronHeader !== cronSecret && bearer !== serviceRoleKey) {
      return json({ error: "forbidden" }, 403);
    }
  }

  try {
    const result = await dispatchPulseForUser({
      userId,
      source,
      dryRun,
      timezone: body.timezone,
    });

    return json({
      dispatched: result.dispatched,
      reason: result.reason,
      content: result.content,
      user_id: result.user_id,
    });
  } catch (error) {
    console.error("[pulse-dispatch]", error);
    return json({ error: "dispatch_failed" }, 500);
  }
});
