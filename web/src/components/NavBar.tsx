"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const NAV_ITEMS = [
  { href: "/", label: "首页", icon: "◎" },
  { href: "/analyze", label: "测算", icon: "☯" },
  { href: "/starmap", label: "星图", icon: "⊹" },
];

export default function NavBar() {
  const pathname = usePathname();

  // Hide nav on chat pages
  if (pathname.startsWith("/chat/")) return null;

  return (
    <nav className="fixed bottom-0 left-0 right-0 z-50 border-t border-white/10 bg-mist-bg/90 backdrop-blur-xl">
      <div className="max-w-lg mx-auto flex">
        {NAV_ITEMS.map((item) => {
          const isActive = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex-1 flex flex-col items-center gap-1 py-3 transition-all ${
                isActive ? "text-red-400" : "text-white/30 hover:text-white/60"
              }`}
            >
              <span className={`text-lg ${isActive ? "scale-110" : ""} transition-transform`}>
                {item.icon}
              </span>
              <span className="text-[10px] tracking-wider">{item.label}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
