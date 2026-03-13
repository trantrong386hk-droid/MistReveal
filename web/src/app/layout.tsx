import type { Metadata, Viewport } from "next";
import NavBar from "@/components/NavBar";
import "leaflet/dist/leaflet.css";
import "./globals.css";

export const metadata: Metadata = {
  title: "命迷 MistReveal — 你的灵魂伴侣，正在等你",
  description:
    "基于八字命理的灵魂伴侣解析。通过AI深度分析你的命盘，生成专属灵魂伴侣画像，探索命中注定的缘分。",
  keywords: ["八字", "命理", "灵魂伴侣", "AI", "星盘", "缘分"],
  openGraph: {
    title: "命迷 MistReveal",
    description: "你的灵魂伴侣，正在等你",
    type: "website",
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  themeColor: "#0A0A12",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="zh-CN">
      <body className="min-h-screen bg-mist-bg text-white antialiased">
        {children}
        <NavBar />
      </body>
    </html>
  );
}
