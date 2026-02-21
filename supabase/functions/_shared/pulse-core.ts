import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";
import {
  PULSE_CONFIG,
  SCRIPT_SLOTS,
  TOPIC_TEMPLATES,
  normalizeElementKey,
  randomFrom,
} from "./pulse-config.ts";

export type DispatchResult = {
  user_id: string;
  dispatched: boolean;
  reason?: string;
  content?: string;
};

type CompanionRow = {
  id: string;
  user_id: string;
  persona_settings?: { element?: string };
  element_balance?: Record<string, unknown>;
};

type PulseStateRow = {
  user_id: string;
  daily_count: number;
  last_day_utc: string;
  last_sent_at: string | null;
  timezone: string | null;
};

function minutesOfDayUTC(now: Date): number {
  return now.getUTCHours() * 60 + now.getUTCMinutes();
}

function parseHHmm(value: string): number {
  const [h = "0", m = "0"] = value.split(":");
  return Number(h) * 60 + Number(m);
}

function minutesOfDayByTimezone(now: Date, timezone: string): number | null {
  try {
    const parts = new Intl.DateTimeFormat("en-GB", {
      timeZone: timezone,
      hour12: false,
      hour: "2-digit",
      minute: "2-digit",
    }).formatToParts(now);

    const hour = Number(parts.find((p) => p.type === "hour")?.value ?? "0");
    const minute = Number(parts.find((p) => p.type === "minute")?.value ?? "0");
    return hour * 60 + minute;
  } catch {
    return null;
  }
}

function isQuietHours(now: Date, timezone: string): boolean {
  const localMinutes = minutesOfDayByTimezone(now, timezone);
  const current = localMinutes ?? minutesOfDayUTC(now);
  const start = parseHHmm(PULSE_CONFIG.global.quietHours.start);
  const end = parseHHmm(PULSE_CONFIG.global.quietHours.end);
  if (start === end) return false;
  if (start < end) return current >= start && current < end;
  return current >= start || current < end;
}

function pickScriptSlot(recentText: string): { theme: string; hook: string } {
  const normalized = recentText.toLowerCase();
  const hit = SCRIPT_SLOTS.find((slot) =>
    slot.recallKeys.some((k) => normalized.includes(k.toLowerCase()))
  );
  return {
    theme: (hit ?? randomFrom(SCRIPT_SLOTS)).theme,
    hook: (hit ?? randomFrom(SCRIPT_SLOTS)).hook,
  };
}

function fallbackPulse(intent: string, hook: string): string {
  switch (intent) {
    case "提醒":
      return `${hook}。先喝口水，给我回个“在”。`;
    case "鼓励":
      return `${hook}。你已经扛了很多，今天也一样能过。`;
    case "轻调侃":
      return `${hook}。别装失踪，我知道你在。`;
    case "延续话题":
      return `${hook}。要不要把那段接着说完？`;
    default:
      return `${hook}。你不用立刻好起来，我先陪你缓一会儿。`;
  }
}

async function generateContentWithModel(args: {
  supabaseUrl: string;
  serviceRoleKey: string;
  intent: string;
  tone: string;
  topic: string;
  hook: string;
  recentContext: string;
}): Promise<string> {
  const model = Deno.env.get("PULSE_MODEL") ?? "qwen-plus";

  const systemPrompt =
    "你是亲密伴侣，输出严格 JSON：{\"content\": string}。content 必须口语化、有温度、40字以内。";
  const userPrompt = `intent=${args.intent}\ntone=${args.tone}\ntopic=${args.topic}\nhook=${args.hook}\nrecent_context=${args.recentContext}`;

  const response = await fetch(`${args.supabaseUrl}/functions/v1/aliyun-proxy`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${args.serviceRoleKey}`,
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userPrompt },
      ],
      response_format: { type: "json_object" },
      max_tokens: 180,
      temperature: 0.85,
    }),
  });

  if (!response.ok) {
    throw new Error(`aliyun-proxy failed: ${response.status}`);
  }

  const payload = await response.json();
  const raw = payload?.choices?.[0]?.message?.content;
  if (typeof raw !== "string") {
    throw new Error("aliyun-proxy response missing content");
  }

  const parsed = JSON.parse(raw);
  const content = String(parsed?.content ?? "").trim();
  if (!content) throw new Error("empty model content");
  return content;
}

async function sendPushIfPossible(args: {
  supabase: ReturnType<typeof createClient>;
  userId: string;
  content: string;
}): Promise<boolean> {
  const pushWebhook = Deno.env.get("PUSH_WEBHOOK_URL");
  if (!pushWebhook) return false;

  const { data: tokenRow } = await args.supabase
    .from("user_push_tokens")
    .select("token,platform")
    .eq("user_id", args.userId)
    .eq("active", true)
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (!tokenRow?.token) return false;

  const res = await fetch(pushWebhook, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      token: tokenRow.token,
      platform: tokenRow.platform,
      title: "灵犀来信",
      body: args.content,
      data: { type: "pulse_message" },
    }),
  });

  return res.ok;
}

export async function dispatchPulseForUser(params: {
  userId: string;
  source: string;
  dryRun: boolean;
  timezone?: string;
}): Promise<DispatchResult> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error("Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: companion } = await supabase
    .from("ai_companions")
    .select("id,user_id,persona_settings,element_balance")
    .eq("user_id", params.userId)
    .limit(1)
    .maybeSingle<CompanionRow>();

  if (!companion) {
    return { user_id: params.userId, dispatched: false, reason: "no_companion" };
  }

  const { data: lastUser } = await supabase
    .from("chat_history")
    .select("content,created_at")
    .eq("user_id", params.userId)
    .eq("role", "user")
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle<{ content: string; created_at: string }>();

  if (!lastUser?.created_at) {
    return { user_id: params.userId, dispatched: false, reason: "no_user_message" };
  }

  const now = new Date();

  const element = companion.persona_settings?.element ?? "木";
  const elementKey = normalizeElementKey(element);
  const rule = PULSE_CONFIG.elements[elementKey] ?? PULSE_CONFIG.elements.wood;

  const silenceHours = (now.getTime() - new Date(lastUser.created_at).getTime()) / 3_600_000;
  if (silenceHours < rule.silenceThresholdHours) {
    return { user_id: params.userId, dispatched: false, reason: "silence_not_reached" };
  }

  const today = now.toISOString().slice(0, 10);
  const { data: state } = await supabase
    .from("pulse_dispatch_state")
    .select("user_id,daily_count,last_day_utc,last_sent_at,timezone")
    .eq("user_id", params.userId)
    .maybeSingle<PulseStateRow>();

  const effectiveTimezone = (params.timezone ?? state?.timezone ?? "UTC").trim() || "UTC";

  if (isQuietHours(now, effectiveTimezone)) {
    return {
      user_id: params.userId,
      dispatched: false,
      reason: effectiveTimezone === "UTC" ? "quiet_hours_utc" : "quiet_hours_local",
    };
  }

  const dailyCount = state?.last_day_utc === today ? state.daily_count : 0;
  if (dailyCount >= PULSE_CONFIG.global.dailyBudget) {
    return { user_id: params.userId, dispatched: false, reason: "daily_budget_exceeded" };
  }

  if (state?.last_sent_at) {
    const minutesSinceLast = (now.getTime() - new Date(state.last_sent_at).getTime()) / 60_000;
    const cooldown = Math.max(PULSE_CONFIG.global.minIntervalMinutes, rule.cooldownMinutes);
    if (minutesSinceLast < cooldown) {
      return { user_id: params.userId, dispatched: false, reason: "cooldown_not_reached" };
    }
  }

  const slot = pickScriptSlot(lastUser.content ?? "");
  const intent = rule.intentPriority[0] ?? "安抚";
  const tones = TOPIC_TEMPLATES[intent]?.tones ?? ["温柔"];
  const tone = randomFrom(tones);

  let content = fallbackPulse(intent, slot.hook);
  try {
    content = await generateContentWithModel({
      supabaseUrl,
      serviceRoleKey,
      intent,
      tone,
      topic: slot.theme,
      hook: slot.hook,
      recentContext: lastUser.content ?? "",
    });
  } catch (error) {
    console.error("[pulse] model fallback", error);
  }

  if (params.dryRun) {
    return { user_id: params.userId, dispatched: true, reason: "dry_run", content };
  }

  const { error: insertChatError } = await supabase
    .from("chat_history")
    .insert({
      user_id: params.userId,
      companion_id: companion.id,
      role: "ai",
      content,
      tags: ["pulse_server"],
      sentiment: "proactive",
      element_context: companion.element_balance ?? null,
    });

  if (insertChatError) {
    console.error("[pulse] insert chat_history failed", insertChatError);
    return { user_id: params.userId, dispatched: false, reason: "insert_chat_failed" };
  }

  await supabase
    .from("pulse_dispatch_state")
    .upsert({
      user_id: params.userId,
      daily_count: dailyCount + 1,
      last_day_utc: today,
      last_sent_at: now.toISOString(),
      timezone: params.timezone ?? state?.timezone ?? null,
    }, { onConflict: "user_id" });

  const pushed = await sendPushIfPossible({ supabase, userId: params.userId, content });

  await supabase.from("pulse_dispatch_logs").insert({
    user_id: params.userId,
    companion_id: companion.id,
    source: params.source,
    intent,
    tone,
    topic: slot.theme,
    script_hook: slot.hook,
    dispatched: true,
    pushed,
      payload: {
        element,
        element_key: elementKey,
        timezone: effectiveTimezone,
        silence_hours: silenceHours,
        daily_count_before: dailyCount,
      },
  });

  return {
    user_id: params.userId,
    dispatched: true,
    content,
  };
}
