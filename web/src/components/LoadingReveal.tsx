"use client";

import { useEffect, useState } from "react";

const MESSAGES = [
  "正在推演命盘...",
  "解析八字四柱...",
  "寻找你的灵魂频率...",
  "命运之线正在交织...",
  "AI正在感知缘分...",
  "灵魂画像即将揭晓...",
];

interface Props {
  isVisible: boolean;
  onComplete?: () => void;
}

export default function LoadingReveal({ isVisible, onComplete }: Props) {
  const [msgIndex, setMsgIndex] = useState(0);
  const [particles, setParticles] = useState<
    { x: number; y: number; size: number; delay: number; duration: number }[]
  >([]);

  useEffect(() => {
    setParticles(
      Array.from({ length: 30 }, () => ({
        x: Math.random() * 100,
        y: Math.random() * 100,
        size: Math.random() * 4 + 1,
        delay: Math.random() * 3,
        duration: Math.random() * 3 + 2,
      }))
    );
  }, []);

  useEffect(() => {
    if (!isVisible) return;
    const interval = setInterval(() => {
      setMsgIndex((i) => (i + 1) % MESSAGES.length);
    }, 1800);
    return () => clearInterval(interval);
  }, [isVisible]);

  if (!isVisible) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-mist-bg">
      {/* Floating particles */}
      <div className="absolute inset-0 overflow-hidden pointer-events-none">
        {particles.map((p, i) => (
          <div
            key={i}
            className="absolute rounded-full"
            style={{
              left: `${p.x}%`,
              top: `${p.y}%`,
              width: p.size,
              height: p.size,
              background:
                i % 3 === 0
                  ? "rgba(233,69,96,0.6)"
                  : i % 3 === 1
                  ? "rgba(139,92,246,0.6)"
                  : "rgba(212,175,55,0.4)",
              animationName: "float",
              animationDuration: `${p.duration}s`,
              animationDelay: `${p.delay}s`,
              animationTimingFunction: "ease-in-out",
              animationIterationCount: "infinite",
              filter: "blur(1px)",
            }}
          />
        ))}
      </div>

      {/* Central animation */}
      <div className="relative flex flex-col items-center gap-8">
        {/* Orbital rings */}
        <div className="relative w-32 h-32 flex items-center justify-center">
          {/* Ring 1 */}
          <div
            className="absolute inset-0 rounded-full border border-red-500/30"
            style={{ animation: "orbit 6s linear infinite" }}
          >
            <div className="absolute -top-1 left-1/2 -translate-x-1/2 w-2 h-2 rounded-full bg-red-400" />
          </div>
          {/* Ring 2 */}
          <div
            className="absolute inset-3 rounded-full border border-purple-500/30"
            style={{ animation: "orbit 9s linear infinite reverse" }}
          >
            <div className="absolute -top-1 left-1/2 -translate-x-1/2 w-1.5 h-1.5 rounded-full bg-purple-400" />
          </div>
          {/* Ring 3 */}
          <div
            className="absolute inset-6 rounded-full border border-yellow-500/20"
            style={{ animation: "orbit 12s linear infinite" }}
          >
            <div className="absolute -top-1 left-1/2 -translate-x-1/2 w-1 h-1 rounded-full bg-yellow-400" />
          </div>

          {/* Center glow */}
          <div className="w-12 h-12 rounded-full bg-gradient-to-br from-red-500/40 to-purple-500/40 flex items-center justify-center animate-pulse">
            <div className="w-6 h-6 rounded-full bg-gradient-to-br from-red-400 to-purple-400 opacity-80" />
          </div>
        </div>

        {/* Brand */}
        <div className="text-center">
          <div className="text-2xl font-bold tracking-widest text-gradient-gold mb-1">
            命迷
          </div>
          <div className="text-sm text-white/40 tracking-wider">
            MistReveal
          </div>
        </div>

        {/* Loading message */}
        <div className="text-sm text-white/60 tracking-wider animate-pulse min-h-[20px]">
          {MESSAGES[msgIndex]}
        </div>

        {/* Dots */}
        <div className="flex gap-2">
          <div className="w-1.5 h-1.5 rounded-full bg-red-400 dot-1" />
          <div className="w-1.5 h-1.5 rounded-full bg-purple-400 dot-2" />
          <div className="w-1.5 h-1.5 rounded-full bg-yellow-400 dot-3" />
        </div>
      </div>
    </div>
  );
}
