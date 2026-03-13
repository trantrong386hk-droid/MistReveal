"use client";

import { useEffect, useState } from "react";
import { useRouter, useParams } from "next/navigation";
import StarField from "@/components/StarField";
import ChatInterface from "@/components/ChatInterface";
import { supabase, ensureAnonymousSession } from "@/lib/supabase";
import type { AICompanion, GeneratedPortrait } from "@/lib/types";

export default function ChatPage() {
  const router = useRouter();
  const params = useParams();
  const companionId = params.companionId as string;

  const [companion, setCompanion] = useState<AICompanion | null>(null);
  const [portraitUrl, setPortraitUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!companionId) {
      router.replace("/");
      return;
    }

    const load = async () => {
      try {
        await ensureAnonymousSession();

        const { data: { session } } = await supabase.auth.getSession();
        if (!session) {
          setError("请先完成灵魂分析");
          setLoading(false);
          return;
        }

        // Load companion
        const { data: companionData, error: companionErr } = await supabase
          .from("ai_companions")
          .select(
            "id,user_id,persona_settings,visual_prompt,intimacy_level,element_balance,soul_analysis_record_id,portrait_id,analyzed_message_count,created_at,updated_at"
          )
          .eq("id", companionId)
          .eq("user_id", session.user.id)
          .single();

        if (companionErr || !companionData) {
          console.error("[chat] companion not found:", companionErr);
          setError("未找到伴侣数据，请重新测算");
          setLoading(false);
          return;
        }

        setCompanion(companionData as AICompanion);

        // Load portrait image
        if (companionData.portrait_id) {
          const { data: portrait } = await supabase
            .from("generated_portraits")
            .select("image_url")
            .eq("id", companionData.portrait_id)
            .single();

          if (portrait?.image_url) {
            setPortraitUrl(portrait.image_url);
          }
        } else if (companionData.visual_prompt) {
          // visual_prompt might store the image URL directly in web version
          setPortraitUrl(companionData.visual_prompt);
        }

        // Also check sessionStorage for image
        const sessionImageUrl = sessionStorage.getItem("mistreveal_image_url");
        if (sessionImageUrl && !portraitUrl) {
          setPortraitUrl(sessionImageUrl);
        }
      } catch (err) {
        console.error("[chat] load error:", err);
        setError("加载失败，请稍后重试");
      } finally {
        setLoading(false);
      }
    };

    load();
  }, [companionId, router]);

  if (loading) {
    return (
      <div className="min-h-screen bg-mist-bg flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <div className="w-12 h-12 rounded-full border border-purple-500/30 flex items-center justify-center text-2xl animate-spin-slow">
            ✦
          </div>
          <div className="text-white/40 text-sm animate-pulse">唤醒灵犀中…</div>
        </div>
      </div>
    );
  }

  if (error || !companion) {
    return (
      <div className="min-h-screen bg-mist-bg flex items-center justify-center px-6">
        <div className="text-center space-y-4">
          <div className="text-4xl opacity-30">◈</div>
          <div className="text-white/60 text-sm">{error || "伴侣数据不存在"}</div>
          <button
            onClick={() => router.push("/analyze")}
            className="px-6 py-3 rounded-xl bg-red-500/20 border border-red-500/40 text-red-300 text-sm hover:bg-red-500/30 transition-all"
          >
            重新测算
          </button>
        </div>
      </div>
    );
  }

  return (
    <main className="min-h-screen bg-mist-bg relative flex flex-col">
      <StarField starCount={80} />

      <div className="relative z-10 flex flex-col h-screen">
        <ChatInterface
          companion={companion}
          portraitUrl={portraitUrl || undefined}
          onBack={() => router.back()}
        />
      </div>
    </main>
  );
}
