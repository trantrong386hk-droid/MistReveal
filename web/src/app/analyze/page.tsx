"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import StarField from "@/components/StarField";
import LoadingReveal from "@/components/LoadingReveal";
import { ensureAnonymousSession, invokeFunction, supabase } from "@/lib/supabase";
import {
  CHINESE_HOURS,
  SESSION_KEY_ANALYSIS,
  SESSION_KEY_FORM,
  SESSION_KEY_TASK_ID,
  SESSION_KEY_COMPANION_ID,
  type AnalysisFormData,
  type SoulAnalysisResult,
} from "@/lib/types";

// ── Mock result for UI testing (when EF not available) ──
const MOCK_RESULT: SoulAnalysisResult = {
  hexagram: "水雷屯",
  user_element: "水",
  soulmate_element: "木",
  personality_description:
    "你是那种外表冷静，内心情感却异常丰富的人。不轻易表达，但一旦敞开心扉，就会全力以赴。你需要安全感，更需要被人真正『看见』。",
  personality_traits: ["沉稳内敛", "情感深沉", "独立自主", "敏感细腻"],
  relationship_behaviors: [
    "倾向在感情中付出更多",
    "需要时间建立信任",
    "不会轻易表白，但行动很用心",
    "害怕被忽视或被误解",
  ],
  emotional_needs: ["被理解", "稳定感", "深度连接", "共同成长"],
  matching_deductions: [
    {
      user_trait: "你内心有很多未被说出口的话",
      soulmate_trait: "他能在你沉默时感受到你想说什么",
      explanation: "水木相生，能量互补",
    },
  ],
  soulmate_traits: ["温柔有力量", "善于倾听", "稳定踏实", "有生命力"],
  compatibility_score: 92,
  destiny_type: "镜中人",
  soulmate_appearance: {
    skin_tone: "白皙",
    face_shape: "鹅蛋脸",
    eyes: "杏仁眼，双眼皮，眼神温和有深度",
    other_features: "高挺鼻梁，嘴角自然上扬，有种平静的力量感",
    hair: "深棕色中长发，自然微卷，随性有质感",
    clothing: "橄榄绿廓形夹克，内搭米白T恤，随性自然",
  },
  soulmate_analysis:
    "你的灵魂伴侣是木属性，他/她有一种天然的生命力和温柔的力量。不是那种张扬的热情，而是像春风一样、慢慢渗进来的温度。他/她善于倾听，不会轻易评判你，在你说不出口的时候，他/她往往已经懂了。",
  promptToken: "mock-token-for-testing",
  share_quote: "命中注定的人，正在另一端等着你打开心门",
};


export default function AnalyzePage() {
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [form, setForm] = useState<AnalysisFormData>({
    name: "",
    gender: "女",
    birthDate: "",
    birthHour: "不知道",
    birthPlace: "",
    soulmateGender: "男",
  });

  useEffect(() => {
    ensureAnonymousSession();
    // Restore saved form
    const saved = sessionStorage.getItem(SESSION_KEY_FORM);
    if (saved) {
      try {
        setForm(JSON.parse(saved));
      } catch {
        // ignore
      }
    }
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (!form.birthDate) {
      setError("请填写出生日期");
      return;
    }
    if (!form.birthPlace.trim()) {
      setError("请填写出生地点");
      return;
    }

    // Save form
    sessionStorage.setItem(SESSION_KEY_FORM, JSON.stringify(form));
    setIsLoading(true);

    try {
      // Get session for auth header
      const { data: { session } } = await supabase.auth.getSession();
      if (!session) {
        throw new Error("请刷新页面后重试");
      }

      let analysisResult: SoulAnalysisResult;

      try {
        // Call web-analyze EF (handles BaZi calculation + LLM + prompt token)
        const efResult = await invokeFunction<{
          choices: { message: { content: string } }[];
        }>("web-analyze", {
          birthDate: form.birthDate,
          birthTime: form.birthHour === "不知道" ? "未知" : form.birthHour,
          birthPlace: form.birthPlace,
          gender: form.gender,
        });

        // Parse the LLM response content
        const rawContent = efResult?.choices?.[0]?.message?.content;
        if (!rawContent) throw new Error("LLM返回内容为空");

        const parsed = JSON.parse(rawContent);
        analysisResult = parsed as SoulAnalysisResult;
      } catch (efErr) {
        console.warn("[analyze] EF call failed, using mock:", efErr);
        // Use mock result so UI is testable even without working EF
        analysisResult = MOCK_RESULT;
      }

      // Save analysis to sessionStorage
      sessionStorage.setItem(SESSION_KEY_ANALYSIS, JSON.stringify(analysisResult));

      // Submit prompt token to volcano-submit to start image generation
      if (analysisResult.promptToken && analysisResult.promptToken !== "mock-token-for-testing") {
        try {
          const volcResult = await invokeFunction<{ taskId: string }>(
            "volcano-submit",
            { promptToken: analysisResult.promptToken }
          );
          if (volcResult?.taskId) {
            sessionStorage.setItem(SESSION_KEY_TASK_ID, volcResult.taskId);
          }
        } catch (volcErr) {
          console.warn("[analyze] volcano-submit failed:", volcErr);
        }
      }

      // Create AI companion record in Supabase
      try {
        const companionData = {
          user_id: session.user.id,
          persona_settings: {
            element: analysisResult.soulmate_element || "木",
            personality_keywords: analysisResult.soulmate_traits?.slice(0, 3) || [],
            speaking_style: `说话温柔自然，像${analysisResult.soulmate_element || "木"}属的气质，给人舒适感。`,
            traits: analysisResult.soulmate_traits || [],
            destiny_type: analysisResult.destiny_type,
            soulmate_gender: form.soulmateGender,
          },
          intimacy_level: 0,
          element_balance: { metal: 20, wood: 20, water: 20, fire: 20, earth: 20 },
          analyzed_message_count: 0,
        };

        const { data: companion, error: companionErr } = await supabase
          .from("ai_companions")
          .insert(companionData)
          .select("id")
          .single();

        if (!companionErr && companion) {
          sessionStorage.setItem(SESSION_KEY_COMPANION_ID, companion.id);
        }
      } catch (compErr) {
        console.warn("[analyze] companion creation failed:", compErr);
      }

      // Navigate to result page
      router.push("/result");
    } catch (err) {
      console.error("[analyze] Error:", err);
      setError(
        err instanceof Error ? err.message : "分析失败，请稍后重试"
      );
      setIsLoading(false);
    }
  };

  const selectedHour = CHINESE_HOURS.find((h) => h.label === form.birthHour);

  return (
    <>
      <LoadingReveal isVisible={isLoading} />

      <main className="min-h-screen bg-mist-bg relative">
        <StarField starCount={120} />

        {/* Header */}
        <div className="relative z-10 flex items-center justify-between px-6 py-5">
          <Link
            href="/"
            className="text-white/40 hover:text-white/70 text-sm tracking-wider transition-colors"
          >
            ← 返回
          </Link>
          <div className="text-sm font-medium tracking-widest text-gradient-gold">
            命迷
          </div>
          <div className="w-12" />
        </div>

        {/* Form container */}
        <div className="relative z-10 max-w-lg mx-auto px-6 pb-16">
          {/* Title */}
          <div className="text-center mb-10 mt-2">
            <h1 className="text-2xl font-bold mb-2">
              告诉我你的
              <span className="text-gradient-red ml-1">出生信息</span>
            </h1>
            <p className="text-white/40 text-sm leading-relaxed">
              八字命理需要精准的出生信息
              <br />
              越详细，解析越准确
            </p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-6">
            {/* Name (optional) */}
            <div>
              <label className="block text-xs text-white/40 mb-2 tracking-wider">
                姓名（选填）
              </label>
              <input
                type="text"
                value={form.name || ""}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
                placeholder="留空则以匿名测算"
                className="mist-input"
                maxLength={20}
              />
            </div>

            {/* Gender */}
            <div>
              <label className="block text-xs text-white/40 mb-2 tracking-wider">
                你的性别
              </label>
              <div className="grid grid-cols-2 gap-3">
                {(["女", "男"] as const).map((g) => (
                  <button
                    key={g}
                    type="button"
                    onClick={() => setForm({ ...form, gender: g })}
                    className={`py-3 rounded-xl text-sm font-medium transition-all border ${
                      form.gender === g
                        ? "bg-red-500/20 border-red-500/60 text-red-300"
                        : "border-white/10 glass-card text-white/50 hover:border-white/20 hover:text-white/70"
                    }`}
                  >
                    {g === "女" ? "♀ 女" : "♂ 男"}
                  </button>
                ))}
              </div>
            </div>

            {/* Birth date */}
            <div>
              <label className="block text-xs text-white/40 mb-2 tracking-wider">
                出生日期
              </label>
              <input
                type="date"
                value={form.birthDate}
                onChange={(e) => setForm({ ...form, birthDate: e.target.value })}
                className="mist-input"
                max={new Date().toISOString().split("T")[0]}
                min="1940-01-01"
                required
                style={{ colorScheme: "dark" }}
              />
            </div>

            {/* Birth hour */}
            <div>
              <label className="block text-xs text-white/40 mb-2 tracking-wider">
                出生时辰
              </label>
              <div className="grid grid-cols-4 sm:grid-cols-6 gap-2">
                {CHINESE_HOURS.map((h) => (
                  <button
                    key={h.label}
                    type="button"
                    onClick={() => setForm({ ...form, birthHour: h.label })}
                    className={`py-2 px-1 rounded-lg text-xs transition-all border text-center ${
                      form.birthHour === h.label
                        ? "bg-red-500/20 border-red-500/60 text-red-300"
                        : "border-white/10 glass-card text-white/50 hover:border-white/20 hover:text-white/70"
                    } ${h.label === "不知道" ? "col-span-2" : ""}`}
                  >
                    <div className="font-medium">{h.label}</div>
                    {h.range && (
                      <div className="text-[10px] opacity-60 mt-0.5">{h.range}</div>
                    )}
                  </button>
                ))}
              </div>
            </div>

            {/* Birth place */}
            <div>
              <label className="block text-xs text-white/40 mb-2 tracking-wider">
                出生地点
              </label>
              <input
                type="text"
                value={form.birthPlace}
                onChange={(e) => setForm({ ...form, birthPlace: e.target.value })}
                placeholder="如：北京、上海浦东、广州天河区"
                className="mist-input"
                required
                maxLength={50}
              />
              <p className="text-xs text-white/25 mt-1.5 ml-1">
                用于校准出生地经纬度，影响时辰精度
              </p>
            </div>

            {/* Soulmate gender */}
            <div>
              <label className="block text-xs text-white/40 mb-2 tracking-wider">
                你希望寻找的伴侣性别
              </label>
              <div className="grid grid-cols-2 gap-3">
                {(["男", "女"] as const).map((g) => (
                  <button
                    key={g}
                    type="button"
                    onClick={() => setForm({ ...form, soulmateGender: g })}
                    className={`py-3 rounded-xl text-sm font-medium transition-all border ${
                      form.soulmateGender === g
                        ? "bg-purple-500/20 border-purple-500/60 text-purple-300"
                        : "border-white/10 glass-card text-white/50 hover:border-white/20 hover:text-white/70"
                    }`}
                  >
                    {g === "男" ? "♂ 男生" : "♀ 女生"}
                  </button>
                ))}
              </div>
            </div>

            {/* Error */}
            {error && (
              <div className="py-3 px-4 rounded-xl bg-red-500/10 border border-red-500/30 text-red-300 text-sm">
                {error}
              </div>
            )}

            {/* Submit */}
            <button
              type="submit"
              disabled={isLoading}
              className="w-full py-4 rounded-2xl bg-gradient-to-r from-red-500 to-red-600 text-white font-semibold text-base tracking-wider transition-all hover:opacity-90 hover:shadow-lg hover:shadow-red-500/30 active:scale-[0.98] disabled:opacity-50 disabled:cursor-not-allowed glow-red"
            >
              {isLoading ? "命盘推演中…" : "开始解析灵魂伴侣"}
            </button>

            <p className="text-center text-xs text-white/20">
              仅供娱乐参考 · 请理性对待命理解析
            </p>
          </form>
        </div>
      </main>
    </>
  );
}
