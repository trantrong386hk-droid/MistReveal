"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import StarField from "@/components/StarField";
import { invokeFunction, supabase } from "@/lib/supabase";
import {
  SESSION_KEY_ANALYSIS,
  SESSION_KEY_TASK_ID,
  SESSION_KEY_IMAGE_URL,
  SESSION_KEY_COMPANION_ID,
  type SoulAnalysisResult,
  ELEMENT_COLORS,
} from "@/lib/types";

type PollStatus = "idle" | "polling" | "completed" | "failed" | "timeout";

const MAX_POLL = 40; // 40 * 3s = 2 minutes max
const POLL_INTERVAL = 3000;

export default function ResultPage() {
  const router = useRouter();
  const [analysis, setAnalysis] = useState<SoulAnalysisResult | null>(null);
  const [imageUrl, setImageUrl] = useState<string | null>(null);
  const [pollStatus, setPollStatus] = useState<PollStatus>("idle");
  const [pollCount, setPollCount] = useState(0);
  const [revealed, setRevealed] = useState(false);
  const [activeTab, setActiveTab] = useState<"portrait" | "analysis" | "destiny">(
    "portrait"
  );
  const [companionId, setCompanionId] = useState<string | null>(null);
  const [savingImage, setSavingImage] = useState(false);
  const shareCardRef = useRef<HTMLDivElement>(null);
  const pollTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Load from sessionStorage
  useEffect(() => {
    const raw = sessionStorage.getItem(SESSION_KEY_ANALYSIS);
    if (!raw) {
      router.replace("/analyze");
      return;
    }
    try {
      setAnalysis(JSON.parse(raw));
    } catch {
      router.replace("/analyze");
      return;
    }

    const existingImageUrl = sessionStorage.getItem(SESSION_KEY_IMAGE_URL);
    if (existingImageUrl) {
      setImageUrl(existingImageUrl);
      setPollStatus("completed");
      setTimeout(() => setRevealed(true), 400);
      return;
    }

    const taskId = sessionStorage.getItem(SESSION_KEY_TASK_ID);
    if (taskId) {
      setPollStatus("polling");
    } else {
      // No task ID (mock mode), just reveal
      setTimeout(() => setRevealed(true), 800);
    }

    const cid = sessionStorage.getItem(SESSION_KEY_COMPANION_ID);
    if (cid) setCompanionId(cid);
  }, [router]);

  // Polling logic with exponential backoff
  const poll = useCallback(async () => {
    const taskId = sessionStorage.getItem(SESSION_KEY_TASK_ID);
    if (!taskId) return;

    try {
      const result = await invokeFunction<{
        status: "processing" | "completed" | "failed";
        imageUrl?: string;
      }>("volcano-poll", { taskId });

      if (result.status === "completed" && result.imageUrl) {
        setImageUrl(result.imageUrl);
        sessionStorage.setItem(SESSION_KEY_IMAGE_URL, result.imageUrl);
        setPollStatus("completed");

        // Update companion portrait if we have one
        const cid = sessionStorage.getItem(SESSION_KEY_COMPANION_ID);
        if (cid) {
          try {
            await supabase
              .from("ai_companions")
              .update({ visual_prompt: result.imageUrl })
              .eq("id", cid);
          } catch {
            // non-critical
          }
        }

        setTimeout(() => setRevealed(true), 600);
        return;
      }

      if (result.status === "failed") {
        setPollStatus("failed");
        setTimeout(() => setRevealed(true), 600);
        return;
      }

      // Still processing
      setPollCount((c) => {
        const next = c + 1;
        if (next >= MAX_POLL) {
          setPollStatus("timeout");
          setRevealed(true);
          return next;
        }
        // Exponential backoff: base 3s, up to 8s
        const delay = Math.min(POLL_INTERVAL * Math.pow(1.2, Math.min(next, 8)), 8000);
        pollTimerRef.current = setTimeout(poll, delay);
        return next;
      });
    } catch {
      setPollCount((c) => {
        const next = c + 1;
        if (next >= MAX_POLL) {
          setPollStatus("timeout");
          setRevealed(true);
          return next;
        }
        pollTimerRef.current = setTimeout(poll, POLL_INTERVAL * 2);
        return next;
      });
    }
  }, []);

  useEffect(() => {
    if (pollStatus === "polling") {
      pollTimerRef.current = setTimeout(poll, POLL_INTERVAL);
    }
    return () => {
      if (pollTimerRef.current) clearTimeout(pollTimerRef.current);
    };
  }, [pollStatus, poll]);

  // Trigger reveal after analysis loaded (no polling)
  useEffect(() => {
    if (analysis && pollStatus === "idle" && !revealed) {
      const timer = setTimeout(() => setRevealed(true), 1200);
      return () => clearTimeout(timer);
    }
  }, [analysis, pollStatus, revealed]);

  const handleSaveImage = async () => {
    if (!imageUrl) return;
    setSavingImage(true);
    try {
      const res = await fetch(imageUrl);
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = "mistreveal-soulmate.jpg";
      a.click();
      URL.revokeObjectURL(url);
    } catch {
      // Try direct open
      window.open(imageUrl, "_blank");
    } finally {
      setSavingImage(false);
    }
  };

  const handleShare = async () => {
    const text = analysis?.share_quote
      ? `"${analysis.share_quote}" — 命迷 MistReveal`
      : "我的灵魂伴侣画像来了！快来测测你的命中之人 →";

    if (navigator.share) {
      try {
        await navigator.share({
          title: "命迷 MistReveal — 灵魂伴侣解析",
          text,
          url: window.location.origin,
        });
      } catch {
        // User cancelled
      }
    } else {
      await navigator.clipboard.writeText(
        `${text} ${window.location.origin}`
      );
      alert("分享链接已复制到剪贴板");
    }
  };

  // ── Render loading state ──
  if (!analysis) {
    return (
      <div className="min-h-screen bg-mist-bg flex items-center justify-center">
        <div className="text-white/40 text-sm animate-pulse">加载中…</div>
      </div>
    );
  }

  const elementColor = ELEMENT_COLORS[analysis.soulmate_element] || "#8B5CF6";

  return (
    <main className="min-h-screen bg-mist-bg relative overflow-x-hidden">
      <StarField starCount={150} />

      {/* Mist overlay before reveal */}
      {!revealed && (
        <div className="fixed inset-0 z-40 bg-mist-bg flex flex-col items-center justify-center gap-6">
          <div className="relative">
            <div
              className="w-24 h-24 rounded-full opacity-30 animate-ping absolute inset-0"
              style={{ background: `radial-gradient(circle, ${elementColor} 0%, transparent 70%)` }}
            />
            <div
              className="w-24 h-24 rounded-full flex items-center justify-center text-4xl animate-spin-slow"
              style={{ border: `1px solid ${elementColor}40` }}
            >
              ✦
            </div>
          </div>
          <div className="text-center">
            <div className="text-white/60 text-sm mb-2 animate-pulse">
              {pollStatus === "polling"
                ? "AI画像生成中，请稍候…"
                : "命盘解析完成，正在揭晓…"}
            </div>
            {pollStatus === "polling" && (
              <div className="text-white/25 text-xs">
                {Math.round((pollCount / MAX_POLL) * 100)}%
              </div>
            )}
          </div>
          <div className="flex gap-2">
            <div className="w-1.5 h-1.5 rounded-full bg-red-400 dot-1" />
            <div className="w-1.5 h-1.5 rounded-full bg-purple-400 dot-2" />
            <div className="w-1.5 h-1.5 rounded-full bg-yellow-400 dot-3" />
          </div>
        </div>
      )}

      {/* Content (revealed) */}
      <div className={`transition-all duration-1000 ${revealed ? "opacity-100" : "opacity-0"}`}>
        {/* Header */}
        <div className="relative z-10 flex items-center justify-between px-6 py-5">
          <Link
            href="/analyze"
            className="text-white/40 hover:text-white/70 text-sm tracking-wider transition-colors"
          >
            ← 重新测算
          </Link>
          <div className="text-sm font-medium tracking-widest text-gradient-gold">
            命迷
          </div>
          <div
            className="text-xs px-2.5 py-1 rounded-full"
            style={{
              background: `${elementColor}20`,
              color: elementColor,
              border: `1px solid ${elementColor}40`,
            }}
          >
            {analysis.soulmate_element}属
          </div>
        </div>

        <div className="relative z-10 max-w-lg mx-auto px-6 pb-16">
          {/* Hero: hexagram + destiny type */}
          <div className="text-center mb-8">
            <div className="text-4xl mb-2 opacity-60">{getHexagramSymbol(analysis.hexagram)}</div>
            <h1 className="text-2xl font-bold mb-1">{analysis.hexagram}</h1>
            <div className="flex items-center justify-center gap-2 text-sm text-white/50">
              <span className="text-gradient-red font-medium">
                {analysis.destiny_type}
              </span>
              <span>·</span>
              <span>契合度 {analysis.compatibility_score}%</span>
            </div>
          </div>

          {/* Share quote */}
          {analysis.share_quote && (
            <div className="glass-card rounded-2xl px-6 py-4 mb-6 text-center border border-white/10">
              <div className="text-white/60 text-sm leading-relaxed italic">
                "{analysis.share_quote}"
              </div>
            </div>
          )}

          {/* Tab navigation */}
          <div className="flex rounded-xl glass-card border border-white/10 p-1 mb-6 gap-1">
            {(["portrait", "analysis", "destiny"] as const).map((tab) => {
              const labels = {
                portrait: "画像",
                analysis: "解析",
                destiny: "缘分",
              };
              return (
                <button
                  key={tab}
                  onClick={() => setActiveTab(tab)}
                  className={`flex-1 py-2 rounded-lg text-sm transition-all ${
                    activeTab === tab
                      ? "bg-white/10 text-white font-medium"
                      : "text-white/40 hover:text-white/60"
                  }`}
                >
                  {labels[tab]}
                </button>
              );
            })}
          </div>

          {/* ── TAB: Portrait ── */}
          {activeTab === "portrait" && (
            <div className="space-y-5">
              {/* Portrait image */}
              <div className="rounded-2xl overflow-hidden aspect-[3/4] relative">
                {imageUrl ? (
                  <img
                    src={imageUrl}
                    alt="灵魂伴侣画像"
                    className="w-full h-full object-cover mist-reveal"
                  />
                ) : (
                  <div
                    className="w-full h-full flex flex-col items-center justify-center gap-4"
                    style={{
                      background: `linear-gradient(135deg, ${elementColor}15 0%, #12082A 100%)`,
                      border: `1px solid ${elementColor}20`,
                    }}
                  >
                    {pollStatus === "failed" || pollStatus === "timeout" ? (
                      <div className="text-center text-white/40 text-sm px-6">
                        <div className="text-3xl mb-3 opacity-30">◈</div>
                        <div>画像生成超时</div>
                        <div className="text-xs mt-1 text-white/25">
                          请参考文字描述想象伴侣样貌
                        </div>
                      </div>
                    ) : (
                      <div className="text-center">
                        <div
                          className="text-5xl mb-4 animate-spin-slow"
                          style={{ color: elementColor, opacity: 0.4 }}
                        >
                          ✦
                        </div>
                        <div className="text-white/30 text-sm">画像生成中…</div>
                      </div>
                    )}
                  </div>
                )}

                {/* Overlay watermark on image */}
                {imageUrl && (
                  <div className="absolute bottom-3 right-3 text-xs text-white/40 bg-black/40 backdrop-blur-sm px-2 py-1 rounded-full">
                    命迷 MistReveal
                  </div>
                )}
              </div>

              {/* Appearance description */}
              <div className="glass-card rounded-2xl p-5 border border-white/10">
                <div className="text-xs text-white/40 tracking-wider mb-3">画像特征</div>
                <div className="grid grid-cols-2 gap-3">
                  {[
                    { label: "肤色", value: analysis.soulmate_appearance.skin_tone },
                    { label: "脸型", value: analysis.soulmate_appearance.face_shape },
                    { label: "眼睛", value: analysis.soulmate_appearance.eyes },
                    { label: "发型", value: analysis.soulmate_appearance.hair },
                  ].map(({ label, value }) => (
                    <div key={label}>
                      <div className="text-xs text-white/30 mb-0.5">{label}</div>
                      <div className="text-sm text-white/80">{value}</div>
                    </div>
                  ))}
                </div>
                {analysis.soulmate_appearance.other_features && (
                  <div className="mt-3 pt-3 border-t border-white/10">
                    <div className="text-xs text-white/30 mb-0.5">其他特征</div>
                    <div className="text-sm text-white/80">
                      {analysis.soulmate_appearance.other_features}
                    </div>
                  </div>
                )}
              </div>

              {/* Action buttons */}
              <div className="grid grid-cols-2 gap-3">
                {imageUrl && (
                  <button
                    onClick={handleSaveImage}
                    disabled={savingImage}
                    className="py-3 rounded-xl glass-card border border-white/15 text-sm text-white/70 hover:text-white hover:border-white/30 transition-all"
                  >
                    {savingImage ? "保存中…" : "保存图片"}
                  </button>
                )}
                <button
                  onClick={handleShare}
                  className={`py-3 rounded-xl bg-red-500/20 border border-red-500/40 text-red-300 text-sm hover:bg-red-500/30 transition-all ${!imageUrl ? "col-span-2" : ""}`}
                >
                  分享给朋友
                </button>
              </div>

              {/* Awaken button */}
              {companionId && (
                <Link
                  href={`/chat/${companionId}`}
                  className="block w-full py-4 rounded-2xl bg-gradient-to-r from-purple-600 to-purple-800 text-white text-center font-semibold text-base tracking-wider transition-all hover:opacity-90 hover:shadow-lg hover:shadow-purple-500/30 active:scale-[0.98] glow-purple"
                >
                  ✦ 唤醒灵犀 · 开始对话
                </Link>
              )}
            </div>
          )}

          {/* ── TAB: Analysis ── */}
          {activeTab === "analysis" && (
            <div className="space-y-5">
              {/* Personality */}
              <div className="glass-card rounded-2xl p-5 border border-white/10">
                <div className="text-xs text-white/40 tracking-wider mb-3">你的灵魂底色</div>
                <p className="text-sm text-white/80 leading-relaxed">
                  {analysis.personality_description}
                </p>
                <div className="flex flex-wrap gap-2 mt-3">
                  {analysis.personality_traits.map((trait, i) => (
                    <span
                      key={i}
                      className="px-2.5 py-1 rounded-full text-xs"
                      style={{
                        background: `${elementColor}15`,
                        color: elementColor,
                        border: `1px solid ${elementColor}30`,
                      }}
                    >
                      {trait}
                    </span>
                  ))}
                </div>
              </div>

              {/* Relationship behaviors */}
              <div className="glass-card rounded-2xl p-5 border border-white/10">
                <div className="text-xs text-white/40 tracking-wider mb-3">你在感情中</div>
                <ul className="space-y-2">
                  {analysis.relationship_behaviors.map((b, i) => (
                    <li key={i} className="flex items-start gap-2 text-sm text-white/70">
                      <span className="text-red-400 mt-0.5 flex-shrink-0">·</span>
                      {b}
                    </li>
                  ))}
                </ul>
              </div>

              {/* Emotional needs */}
              <div className="glass-card rounded-2xl p-5 border border-white/10">
                <div className="text-xs text-white/40 tracking-wider mb-3">你真正需要的</div>
                <div className="flex flex-wrap gap-2">
                  {analysis.emotional_needs.map((need, i) => (
                    <span
                      key={i}
                      className="px-3 py-1.5 rounded-full text-sm text-white/80 glass-card border border-white/15"
                    >
                      {need}
                    </span>
                  ))}
                </div>
              </div>

              {/* Soulmate analysis */}
              <div className="glass-card rounded-2xl p-5 border border-white/10">
                <div className="text-xs text-white/40 tracking-wider mb-3">
                  关于你的灵魂伴侣
                </div>
                <p className="text-sm text-white/80 leading-relaxed">
                  {analysis.soulmate_analysis}
                </p>
                <div className="flex flex-wrap gap-2 mt-3">
                  {analysis.soulmate_traits.map((trait, i) => (
                    <span
                      key={i}
                      className="px-2.5 py-1 rounded-full text-xs text-white/60 glass-card border border-white/10"
                    >
                      {trait}
                    </span>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* ── TAB: Destiny ── */}
          {activeTab === "destiny" && (
            <div className="space-y-5">
              {/* Compatibility score visual */}
              <div className="glass-card rounded-2xl p-6 border border-white/10 text-center">
                <div className="text-xs text-white/40 tracking-wider mb-4">命理契合度</div>
                <div className="relative w-32 h-32 mx-auto mb-4">
                  <svg className="w-full h-full -rotate-90" viewBox="0 0 100 100">
                    <circle
                      cx="50" cy="50" r="40"
                      fill="none"
                      stroke="rgba(255,255,255,0.08)"
                      strokeWidth="8"
                    />
                    <circle
                      cx="50" cy="50" r="40"
                      fill="none"
                      stroke={elementColor}
                      strokeWidth="8"
                      strokeLinecap="round"
                      strokeDasharray={`${2 * Math.PI * 40}`}
                      strokeDashoffset={`${2 * Math.PI * 40 * (1 - analysis.compatibility_score / 100)}`}
                      style={{ transition: "stroke-dashoffset 1.5s ease-out" }}
                    />
                  </svg>
                  <div className="absolute inset-0 flex flex-col items-center justify-center">
                    <div className="text-3xl font-bold text-white">
                      {analysis.compatibility_score}
                    </div>
                    <div className="text-xs text-white/40">分</div>
                  </div>
                </div>
                <div className="text-lg font-semibold text-gradient-red">
                  {analysis.destiny_type}
                </div>
              </div>

              {/* Matching deductions */}
              <div className="glass-card rounded-2xl p-5 border border-white/10">
                <div className="text-xs text-white/40 tracking-wider mb-4">命理推导</div>
                <div className="space-y-4">
                  {analysis.matching_deductions.map((d, i) => (
                    <div key={i} className="space-y-1">
                      <div className="text-sm text-white/70">
                        <span className="text-red-400">因为你</span>
                        {d.user_trait}
                      </div>
                      <div className="text-sm text-white/70 ml-4">
                        <span className="text-purple-400">需要</span>
                        {d.soulmate_trait}
                      </div>
                      {d.explanation && (
                        <div className="text-xs text-white/30 ml-4 italic">
                          {d.explanation}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>

              {/* Five elements summary */}
              <div className="glass-card rounded-2xl p-5 border border-white/10">
                <div className="text-xs text-white/40 tracking-wider mb-3">五行配合</div>
                <div className="flex items-center justify-around">
                  <div className="text-center">
                    <div className="text-2xl mb-1">{getElementEmoji(analysis.user_element)}</div>
                    <div className="text-xs text-white/50">你</div>
                    <div
                      className="text-sm font-medium"
                      style={{ color: ELEMENT_COLORS[analysis.user_element] || "white" }}
                    >
                      {analysis.user_element}属
                    </div>
                  </div>
                  <div className="text-2xl text-white/20">⟷</div>
                  <div className="text-center">
                    <div className="text-2xl mb-1">{getElementEmoji(analysis.soulmate_element)}</div>
                    <div className="text-xs text-white/50">TA</div>
                    <div
                      className="text-sm font-medium"
                      style={{ color: ELEMENT_COLORS[analysis.soulmate_element] || "white" }}
                    >
                      {analysis.soulmate_element}属
                    </div>
                  </div>
                </div>
              </div>

              {/* Chat CTA */}
              {companionId && (
                <Link
                  href={`/chat/${companionId}`}
                  className="block w-full py-4 rounded-2xl bg-gradient-to-r from-red-500 to-red-600 text-white text-center font-semibold text-base tracking-wider transition-all hover:opacity-90 active:scale-[0.98] glow-red"
                >
                  ✦ 唤醒灵犀 · 开始对话
                </Link>
              )}
            </div>
          )}
        </div>
      </div>
    </main>
  );
}

function getHexagramSymbol(hexagram: string): string {
  const map: Record<string, string> = {
    乾: "☰", 坤: "☷", 坎: "☵", 离: "☲",
    震: "☳", 艮: "☶", 巽: "☴", 兑: "☱",
  };
  for (const [key, sym] of Object.entries(map)) {
    if (hexagram.includes(key)) return sym;
  }
  return "☯";
}

function getElementEmoji(element: string): string {
  const map: Record<string, string> = {
    金: "⟡", 木: "✦", 水: "◈", 火: "✸", 土: "◉",
  };
  return map[element] || "✦";
}
