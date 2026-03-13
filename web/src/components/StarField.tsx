"use client";

import { useEffect, useRef } from "react";

interface Star {
  x: number;
  y: number;
  radius: number;
  opacity: number;
  speed: number;
  twinklePhase: number;
}

interface Props {
  starCount?: number;
  className?: string;
}

export default function StarField({ starCount = 200, className = "" }: Props) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const starsRef = useRef<Star[]>([]);
  const animFrameRef = useRef<number>(0);
  const timeRef = useRef<number>(0);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;

    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const resize = () => {
      canvas.width = canvas.offsetWidth;
      canvas.height = canvas.offsetHeight;
      initStars();
    };

    const initStars = () => {
      starsRef.current = Array.from({ length: starCount }, () => ({
        x: Math.random() * canvas.width,
        y: Math.random() * canvas.height,
        radius: Math.random() * 1.5 + 0.3,
        opacity: Math.random() * 0.7 + 0.1,
        speed: Math.random() * 0.3 + 0.05,
        twinklePhase: Math.random() * Math.PI * 2,
      }));
    };

    const draw = (time: number) => {
      timeRef.current = time;
      ctx.clearRect(0, 0, canvas.width, canvas.height);

      starsRef.current.forEach((star) => {
        const twinkle =
          Math.sin(time * 0.001 * star.speed + star.twinklePhase) * 0.3 + 0.7;
        const opacity = star.opacity * twinkle;

        ctx.beginPath();
        ctx.arc(star.x, star.y, star.radius, 0, Math.PI * 2);

        // Gradient for star glow
        const gradient = ctx.createRadialGradient(
          star.x,
          star.y,
          0,
          star.x,
          star.y,
          star.radius * 3
        );
        gradient.addColorStop(0, `rgba(255, 255, 255, ${opacity})`);
        gradient.addColorStop(0.5, `rgba(180, 160, 255, ${opacity * 0.4})`);
        gradient.addColorStop(1, "transparent");

        ctx.fillStyle = gradient;
        ctx.fill();
      });

      // Draw a few bright accent stars
      starsRef.current.slice(0, 15).forEach((star, i) => {
        const pulse = Math.sin(time * 0.0008 + i * 0.8) * 0.5 + 0.5;
        const r = (star.radius + 1) * (1 + pulse * 0.5);
        const hue = i % 3 === 0 ? "233, 69, 96" : i % 3 === 1 ? "139, 92, 246" : "212, 175, 55";

        ctx.beginPath();
        const g = ctx.createRadialGradient(star.x, star.y, 0, star.x, star.y, r * 4);
        g.addColorStop(0, `rgba(${hue}, ${0.9 * pulse})`);
        g.addColorStop(0.4, `rgba(${hue}, ${0.2 * pulse})`);
        g.addColorStop(1, "transparent");
        ctx.arc(star.x, star.y, r * 4, 0, Math.PI * 2);
        ctx.fillStyle = g;
        ctx.fill();
      });

      animFrameRef.current = requestAnimationFrame(draw);
    };

    resize();
    animFrameRef.current = requestAnimationFrame(draw);

    const observer = new ResizeObserver(resize);
    observer.observe(canvas);

    return () => {
      cancelAnimationFrame(animFrameRef.current);
      observer.disconnect();
    };
  }, [starCount]);

  return (
    <canvas
      ref={canvasRef}
      className={`absolute inset-0 w-full h-full pointer-events-none ${className}`}
    />
  );
}
