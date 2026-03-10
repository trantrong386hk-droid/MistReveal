import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ============================================================
// minimax-proxy — MiniMax LLM 代理（灵犀对话专用）
// 格式与 OpenAI chat/completions 兼容，直接透明转发。
// API key 仅存在于 Deno 环境变量，客户端永不可见。
// ============================================================

const MINIMAX_API_URL = "https://api.minimaxi.com/v1/text/chatcompletion_v2";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  // JWT 验证
  const jwt = req.headers.get("Authorization")?.replace("Bearer ", "");
  if (!jwt) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401, headers: { "Content-Type": "application/json" },
    });
  }
  const supabaseAdmin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );
  const { data: { user }, error: authErr } = await supabaseAdmin.auth.getUser(jwt);
  if (!user || authErr) {
    console.error("[minimax-proxy] JWT validation failed:", authErr);
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401, headers: { "Content-Type": "application/json" },
    });
  }

  const apiKey = Deno.env.get("MINIMAX_API_KEY");
  if (!apiKey) {
    console.error("[minimax-proxy] MINIMAX_API_KEY is not set");
    return new Response(JSON.stringify({ error: "API key not configured" }), {
      status: 500, headers: { "Content-Type": "application/json" },
    });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400, headers: { "Content-Type": "application/json" },
    });
  }

  console.log(`[minimax-proxy] user=${user.id} model=${body["model"]} msgs=${(body["messages"] as unknown[])?.length ?? 0}`);

  const upstream = await fetch(MINIMAX_API_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  console.log(`[minimax-proxy] upstream status: ${upstream.status}`);

  if (upstream.status !== 200) {
    const errorText = await upstream.text();
    console.error(`[minimax-proxy] upstream error ${upstream.status}:`, errorText);
    const clientStatus = upstream.status === 401 || upstream.status === 403 ? 502 : upstream.status;
    return new Response(
      JSON.stringify({ error: "upstream_error", upstream_status: upstream.status, detail: errorText }),
      { status: clientStatus, headers: { "Content-Type": "application/json" } }
    );
  }

  const responseText = await upstream.text();
  return new Response(responseText, {
    status: 200,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
});
