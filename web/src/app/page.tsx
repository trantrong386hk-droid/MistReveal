"use client";

import { useEffect, useRef, useState } from "react";
import Link from "next/link";
import StarField from "@/components/StarField";
import { ensureAnonymousSession } from "@/lib/supabase";

const FEATURES = [
  {
    icon: "☯",
    title: "八字解析",
    desc: "依据出生年月日时，精算四柱命盘，揭示你的五行格局与灵魂底色",
    gradient: "from-yellow-600/20 to-yellow-400/5",
    border: "border-yellow-500/20",
  },
  {
    icon: "◈",
    title: "AI灵魂画像",
    desc: "AI深度解读命理，生成你命中注定伴侣的专属肖像，从面貌到气质一一呈现",
    gradient: "from-red-600/20 to-red-400/5",
    border: "border-red-500/20",
  },
  {
    icon: "✦",
    title: "灵犀对话",
    desc: "与你的灵魂伴侣AI进行深度交流，感受那种被人完全理解的心动",
    gradient: "from-purple-600/20 to-purple-400/5",
    border: "border-purple-500/20",
  },
  {
    icon: "⊹",
    title: "星图缘分",
    desc: "实时星图展示附近缘分相近的灵魂，命中注定的人或许就在身边",
    gradient: "from-blue-600/20 to-blue-400/5",
    border: "border-blue-500/20",
  },
];

const TESTIMONIALS = [
  {
    quote: "看到画像的瞬间，我愣了好久。太像我脑子里那个人了。",
    author: "木系女生 · 28岁",
  },
  {
    quote: "分析说我需要「有力量感的稳定」，正好说中了我反复被同一类人吸引的原因。",
    author: "水系女生 · 24岁",
  },
  {
    quote: "缘分类型「镜中人」，我妈说我爸当年就是这样的。",
    author: "金系女生 · 26岁",
  },
];

export default function HomePage() {
  const [sessionReady, setSessionReady] = useState(false);
  const [activeTestimonial, setActiveTestimonial] = useState(0);
  const heroRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    ensureAnonymousSession().then(() => setSessionReady(true));
  }, []);

  // Rotate testimonials
  useEffect(() => {
    const t = setInterval(() => {
      setActiveTestimonial((i) => (i + 1) % TESTIMONIALS.length);
    }, 4000);
    return () => clearInterval(t);
  }, []);

  // Parallax on scroll
  useEffect(() => {
    const handleScroll = () => {
      if (!heroRef.current) return;
      const y = window.scrollY;
      heroRef.current.style.transform = `translateY(${y * 0.3}px)`;
    };
    window.addEventListener("scroll", handleScroll, { passive: true });
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  return (
    <main className="min-h-screen bg-mist-bg overflow-x-hidden">
      {/* ========== HERO ========== */}
      <section className="relative min-h-screen flex items-center justify-center overflow-hidden">
        {/* Animated starfield */}
        <StarField starCount={250} />

        {/* Background gradient blobs */}
        <div className="absolute inset-0 pointer-events-none">
          <div
            className="absolute top-1/4 left-1/3 w-96 h-96 rounded-full opacity-20 animate-pulse"
            style={{
              background: "radial-gradient(circle, rgba(233,69,96,0.4) 0%, transparent 70%)",
              filter: "blur(60px)",
            }}
          />
          <div
            className="absolute bottom-1/3 right-1/4 w-80 h-80 rounded-full opacity-15 animate-pulse"
            style={{
              background: "radial-gradient(circle, rgba(139,92,246,0.4) 0%, transparent 70%)",
              filter: "blur(60px)",
              animationDelay: "1.5s",
            }}
          />
        </div>

        {/* Hero content */}
        <div ref={heroRef} className="relative z-10 text-center px-6 max-w-2xl mx-auto">
          {/* Badge */}
          <div className="inline-flex items-center gap-2 px-4 py-1.5 rounded-full glass-card border border-white/10 text-xs text-white/60 mb-8 tracking-widest">
            <span className="w-1.5 h-1.5 rounded-full bg-red-400 animate-pulse" />
            基于八字命理 · AI深度解析
          </div>

          {/* Title */}
          <h1 className="text-6xl sm:text-7xl font-bold tracking-wider mb-3">
            <span className="text-gradient-gold">命迷</span>
          </h1>
          <div className="text-xl sm:text-2xl text-white/40 tracking-widest mb-4 font-light">
            MistReveal
          </div>

          {/* Subtitle */}
          <p className="text-xl sm:text-2xl text-white/80 mb-4 leading-relaxed font-light">
            你的灵魂伴侣
            <br />
            <span className="text-gradient-red font-medium">正在等你</span>
          </p>

          <p className="text-sm text-white/40 mb-10 leading-relaxed tracking-wide">
            八字四柱 · AI命盘解读 · 专属肖像生成
          </p>

          {/* CTA */}
          <Link
            href="/analyze"
            className="inline-flex items-center gap-3 px-10 py-4 rounded-full bg-gradient-to-r from-red-500 to-red-600 text-white font-medium text-lg tracking-wider shadow-lg glow-red transition-all hover:scale-105 hover:shadow-red-500/30 hover:shadow-2xl active:scale-95"
          >
            <span>开始测算</span>
            <span className="text-xl">→</span>
          </Link>

          {/* Sub-CTA */}
          <div className="mt-4 flex items-center justify-center gap-4 text-xs text-white/30">
            <span>免费体验</span>
            <span>·</span>
            <span>无需注册</span>
            <span>·</span>
            <span>30秒出结果</span>
          </div>
        </div>

        {/* Scroll indicator */}
        <div className="absolute bottom-8 left-1/2 -translate-x-1/2 flex flex-col items-center gap-2 text-white/20 animate-bounce">
          <span className="text-xs tracking-widest">探索</span>
          <span className="text-lg">↓</span>
        </div>
      </section>

      {/* ========== FEATURES ========== */}
      <section className="relative py-24 px-6">
        <div className="max-w-4xl mx-auto">
          <div className="text-center mb-14">
            <div className="text-xs text-white/30 tracking-[0.3em] mb-3 uppercase">
              Features
            </div>
            <h2 className="text-3xl font-bold mb-3">
              命理 × AI
              <span className="text-gradient-purple ml-2">四维解析</span>
            </h2>
            <p className="text-white/40 text-sm">
              不只是算命，而是一次关于自己的深度对话
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {FEATURES.map((f, i) => (
              <div
                key={i}
                className={`relative p-6 rounded-2xl glass-card border ${f.border} overflow-hidden group hover:-translate-y-1 transition-transform duration-300`}
              >
                {/* Bg gradient */}
                <div
                  className={`absolute inset-0 bg-gradient-to-br ${f.gradient} opacity-0 group-hover:opacity-100 transition-opacity duration-300`}
                />

                <div className="relative z-10">
                  <div className="text-3xl mb-3 opacity-80">{f.icon}</div>
                  <h3 className="text-lg font-semibold mb-2">{f.title}</h3>
                  <p className="text-sm text-white/50 leading-relaxed">{f.desc}</p>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* ========== HOW IT WORKS ========== */}
      <section className="relative py-20 px-6 overflow-hidden">
        <div
          className="absolute inset-0 opacity-5"
          style={{
            backgroundImage:
              "radial-gradient(circle at 50% 50%, rgba(233,69,96,0.8) 0%, transparent 60%)",
          }}
        />

        <div className="max-w-3xl mx-auto">
          <div className="text-center mb-14">
            <div className="text-xs text-white/30 tracking-[0.3em] mb-3 uppercase">
              How it works
            </div>
            <h2 className="text-3xl font-bold">
              三步，遇见
              <span className="text-gradient-red ml-2">命中之人</span>
            </h2>
          </div>

          <div className="space-y-6">
            {[
              {
                step: "01",
                title: "输入出生信息",
                desc: "填写出生年月日、时辰和出生地点，系统自动推算八字四柱",
                icon: "◎",
              },
              {
                step: "02",
                title: "AI深度解析",
                desc: "大模型解读你的命盘格局，推演灵魂伴侣的性格特质与面貌描述",
                icon: "◈",
              },
              {
                step: "03",
                title: "画像揭晓 · 灵魂共鸣",
                desc: "AI绘图生成专属伴侣肖像，开启与灵犀的深度对话",
                icon: "✦",
              },
            ].map((item, i) => (
              <div key={i} className="flex gap-5 items-start">
                <div className="flex-shrink-0 w-12 h-12 rounded-full glass-card border border-red-500/20 flex items-center justify-center">
                  <span className="text-red-400 text-xl">{item.icon}</span>
                </div>
                <div className="flex-1 pt-1">
                  <div className="flex items-center gap-3 mb-1">
                    <span className="text-xs text-white/20 font-mono tracking-wider">
                      {item.step}
                    </span>
                    <h3 className="text-base font-semibold">{item.title}</h3>
                  </div>
                  <p className="text-sm text-white/50 leading-relaxed">{item.desc}</p>
                </div>
              </div>
            ))}
          </div>

          <div className="mt-12 text-center">
            <Link
              href="/analyze"
              className="inline-flex items-center gap-2 px-8 py-3.5 rounded-full border border-red-500/50 text-red-400 text-sm tracking-wider hover:bg-red-500/10 transition-all hover:border-red-400"
            >
              立即开始 →
            </Link>
          </div>
        </div>
      </section>

      {/* ========== TESTIMONIALS ========== */}
      <section className="py-20 px-6">
        <div className="max-w-2xl mx-auto text-center">
          <div className="text-xs text-white/30 tracking-[0.3em] mb-10 uppercase">
            Voices
          </div>

          <div className="glass-card rounded-2xl p-8 min-h-[140px] flex flex-col items-center justify-center">
            <div className="text-4xl text-white/10 mb-4 font-serif">"</div>
            <p className="text-white/70 text-base leading-relaxed mb-4 transition-all duration-500">
              {TESTIMONIALS[activeTestimonial].quote}
            </p>
            <p className="text-xs text-white/30">
              — {TESTIMONIALS[activeTestimonial].author}
            </p>
          </div>

          {/* Dots */}
          <div className="flex justify-center gap-2 mt-4">
            {TESTIMONIALS.map((_, i) => (
              <button
                key={i}
                onClick={() => setActiveTestimonial(i)}
                className={`w-1.5 h-1.5 rounded-full transition-all ${
                  i === activeTestimonial
                    ? "bg-red-400 w-4"
                    : "bg-white/20"
                }`}
              />
            ))}
          </div>
        </div>
      </section>

      {/* ========== FINAL CTA ========== */}
      <section className="py-24 px-6 text-center relative overflow-hidden">
        <div
          className="absolute inset-0 opacity-10"
          style={{
            backgroundImage:
              "radial-gradient(ellipse at 50% 100%, rgba(139,92,246,0.8) 0%, transparent 60%)",
          }}
        />
        <div className="relative z-10 max-w-lg mx-auto">
          <div className="text-5xl mb-6 animate-float inline-block">✦</div>
          <h2 className="text-3xl font-bold mb-4">
            命中注定的那个人
            <br />
            <span className="text-gradient-purple">你还没见过</span>
          </h2>
          <p className="text-white/40 text-sm mb-8 leading-relaxed">
            三千命盘，一面镜像。
            <br />
            你的灵魂伴侣，早已刻在你的八字里。
          </p>
          <Link
            href="/analyze"
            className="inline-flex items-center gap-3 px-12 py-4 rounded-full bg-gradient-to-r from-purple-500 to-purple-700 text-white font-medium text-lg tracking-wider shadow-lg glow-purple transition-all hover:scale-105 active:scale-95"
          >
            <span>开始测算</span>
            <span>→</span>
          </Link>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-white/5 py-8 px-6 text-center">
        <p className="text-white/20 text-xs tracking-wider">
          命迷 MistReveal · 八字命理 × AI深度解析
        </p>
        <p className="text-white/10 text-xs mt-1">
          仅供娱乐参考，请理性对待命理解析
        </p>
      </footer>
    </main>
  );
}
