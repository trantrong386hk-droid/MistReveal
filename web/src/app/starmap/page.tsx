"use client";

import { useEffect, useState, useRef, useCallback } from "react";
import Link from "next/link";
import dynamic from "next/dynamic";
import StarField from "@/components/StarField";
import { supabase, ensureAnonymousSession } from "@/lib/supabase";
import { ELEMENT_COLORS, type NearbyMatch } from "@/lib/types";

// Dynamically import map (no SSR — Leaflet requires window)
const StarMapLeaflet = dynamic(() => import("@/components/StarMapLeaflet"), {
  ssr: false,
  loading: () => (
    <div className="w-full h-full flex items-center justify-center">
      <div className="text-white/30 text-sm animate-pulse">星图加载中…</div>
    </div>
  ),
});

interface UserLocation {
  latitude: number;
  longitude: number;
}

export default function StarMapPage() {
  const [userLocation, setUserLocation] = useState<UserLocation | null>(null);
  const [nearbyUsers, setNearbyUsers] = useState<NearbyMatch[]>([]);
  const [selectedUser, setSelectedUser] = useState<NearbyMatch | null>(null);
  const [locationError, setLocationError] = useState<string | null>(null);
  const [isLoadingLocation, setIsLoadingLocation] = useState(false);
  const [isLoadingMatches, setIsLoadingMatches] = useState(false);
  const [hasPermission, setHasPermission] = useState(false);

  const requestLocation = useCallback(() => {
    if (!navigator.geolocation) {
      setLocationError("浏览器不支持定位");
      return;
    }

    setIsLoadingLocation(true);
    setLocationError(null);

    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setUserLocation({
          latitude: pos.coords.latitude,
          longitude: pos.coords.longitude,
        });
        setHasPermission(true);
        setIsLoadingLocation(false);
      },
      (err) => {
        console.warn("[starmap] geolocation error:", err);
        setLocationError(
          err.code === 1
            ? "未授权定位权限，请在浏览器设置中允许"
            : "获取位置失败，请重试"
        );
        setIsLoadingLocation(false);
        // Use a mock location (Beijing) for demo
        setUserLocation({ latitude: 39.9042, longitude: 116.4074 });
        setHasPermission(true);
      },
      { timeout: 10000, maximumAge: 60000, enableHighAccuracy: false }
    );
  }, []);

  // Auto request location on mount
  useEffect(() => {
    ensureAnonymousSession().then(() => {
      requestLocation();
    });
  }, [requestLocation]);

  // Upload user location to Supabase and fetch nearby matches
  useEffect(() => {
    if (!userLocation || !hasPermission) return;

    const uploadAndFetch = async () => {
      try {
        const { data: { session } } = await supabase.auth.getSession();
        if (!session) return;

        // Update user location
        await supabase.from("user_locations").upsert({
          user_id: session.user.id,
          latitude: userLocation.latitude,
          longitude: userLocation.longitude,
          updated_at: new Date().toISOString(),
        });

        // Fetch nearby users (within ~50km radius)
        setIsLoadingMatches(true);
        const { data: locations, error } = await supabase
          .from("user_locations")
          .select("user_id, latitude, longitude, updated_at")
          .neq("user_id", session.user.id)
          .limit(50);

        if (error) {
          console.warn("[starmap] fetch locations error:", error);
          // Generate mock nearby users for demo
          setNearbyUsers(generateMockNearby(userLocation));
          return;
        }

        if (!locations || locations.length === 0) {
          // Generate demo shadow markers
          setNearbyUsers(generateMockNearby(userLocation));
          return;
        }

        // Filter to roughly 50km radius and compute match scores
        const nearby = locations
          .filter((loc) => {
            const dist = haversineDistance(
              userLocation.latitude,
              userLocation.longitude,
              loc.latitude,
              loc.longitude
            );
            return dist <= 50;
          })
          .map((loc) => {
            const lastActive = new Date(loc.updated_at);
            const isRecent =
              Date.now() - lastActive.getTime() < 30 * 60 * 1000; // 30 min

            const elements = ["金", "木", "水", "火", "土"];
            const element = elements[Math.floor(Math.random() * elements.length)];

            return {
              userId: loc.user_id,
              matchScore: Math.floor(Math.random() * 30 + 65), // 65-95
              latitude: loc.latitude,
              longitude: loc.longitude,
              element,
              isRecentlyActive: isRecent,
              isShadow: true,
            } as NearbyMatch;
          });

        setNearbyUsers(
          nearby.length > 0 ? nearby : generateMockNearby(userLocation)
        );
      } catch (err) {
        console.warn("[starmap] error:", err);
        setNearbyUsers(generateMockNearby(userLocation));
      } finally {
        setIsLoadingMatches(false);
      }
    };

    uploadAndFetch();
  }, [userLocation, hasPermission]);

  return (
    <main className="h-screen bg-mist-bg relative overflow-hidden flex flex-col">
      {/* Background stars (behind map) */}
      <div className="absolute inset-0 z-0">
        <StarField starCount={100} />
      </div>

      {/* Header */}
      <div className="relative z-20 flex items-center justify-between px-5 py-4 bg-mist-bg/80 backdrop-blur-md border-b border-white/5">
        <Link
          href="/"
          className="text-white/40 hover:text-white/70 text-sm transition-colors"
        >
          ← 返回
        </Link>
        <div>
          <div className="text-sm font-medium tracking-widest text-gradient-gold text-center">
            星图
          </div>
          <div className="text-xs text-white/25 text-center tracking-wider">
            Star Map
          </div>
        </div>
        <div className="text-xs text-white/30">
          {nearbyUsers.length > 0 && `${nearbyUsers.length} 个灵魂`}
        </div>
      </div>

      {/* Permission prompt */}
      {!hasPermission && !isLoadingLocation && (
        <div className="absolute inset-0 z-30 flex items-center justify-center px-8">
          <div className="glass-card rounded-3xl p-8 text-center max-w-sm border border-white/10">
            <div className="text-4xl mb-4 opacity-60 animate-float">⊹</div>
            <h2 className="text-lg font-semibold mb-2">开启星图</h2>
            <p className="text-white/40 text-sm mb-6 leading-relaxed">
              允许定位，发现附近与你命理相合的灵魂
              <br />
              <span className="text-white/25 text-xs">所有位置信息匿名处理</span>
            </p>
            <button
              onClick={requestLocation}
              disabled={isLoadingLocation}
              className="w-full py-3.5 rounded-xl bg-gradient-to-r from-purple-600 to-purple-800 text-white font-medium tracking-wider hover:opacity-90 transition-all"
            >
              {isLoadingLocation ? "定位中…" : "开启位置权限"}
            </button>
            {locationError && (
              <p className="text-red-400/70 text-xs mt-3">{locationError}</p>
            )}
          </div>
        </div>
      )}

      {/* Loading overlay */}
      {isLoadingLocation && (
        <div className="absolute inset-0 z-30 flex items-center justify-center">
          <div className="text-white/40 text-sm animate-pulse">正在定位…</div>
        </div>
      )}

      {/* Map */}
      <div className="relative z-10 flex-1">
        {hasPermission && userLocation && (
          <StarMapLeaflet
            userLocation={userLocation}
            nearbyUsers={nearbyUsers}
            selectedUser={selectedUser}
            onSelectUser={setSelectedUser}
          />
        )}
      </div>

      {/* Selected user panel */}
      {selectedUser && (
        <div className="absolute bottom-0 left-0 right-0 z-20">
          <div className="glass-card border-t border-white/10 px-5 py-4 backdrop-blur-xl">
            <div className="flex items-center gap-4">
              {/* Avatar placeholder */}
              <div
                className="w-12 h-12 rounded-full border flex items-center justify-center text-xl flex-shrink-0"
                style={{
                  borderColor: `${ELEMENT_COLORS[selectedUser.element]}40`,
                  background: `${ELEMENT_COLORS[selectedUser.element]}15`,
                  color: ELEMENT_COLORS[selectedUser.element],
                }}
              >
                星影
              </div>

              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <span className="text-sm font-medium">
                    {selectedUser.element}属灵魂
                  </span>
                  {selectedUser.isRecentlyActive && (
                    <span className="w-1.5 h-1.5 rounded-full bg-green-400 animate-pulse" />
                  )}
                </div>
                <div className="text-xs text-white/40 mt-0.5">
                  命理契合度{" "}
                  <span
                    style={{ color: ELEMENT_COLORS[selectedUser.element] }}
                    className="font-semibold"
                  >
                    {selectedUser.matchScore}%
                  </span>
                </div>
              </div>

              <button
                onClick={() => setSelectedUser(null)}
                className="text-white/30 hover:text-white/60 text-2xl w-8 h-8 flex items-center justify-center"
              >
                ×
              </button>
            </div>

            {/* Match bar */}
            <div className="mt-3">
              <div className="h-1 rounded-full bg-white/10 overflow-hidden">
                <div
                  className="h-full rounded-full transition-all duration-1000"
                  style={{
                    width: `${selectedUser.matchScore}%`,
                    background: `linear-gradient(90deg, ${ELEMENT_COLORS[selectedUser.element]}, ${ELEMENT_COLORS[selectedUser.element]}80)`,
                  }}
                />
              </div>
            </div>

            <p className="text-xs text-white/25 mt-2 text-center">
              星影数字分身 · 完整信息需在App内查看
            </p>
          </div>
        </div>
      )}

      {/* Empty state */}
      {hasPermission && !isLoadingMatches && nearbyUsers.length === 0 && (
        <div className="absolute bottom-20 left-0 right-0 z-20 flex justify-center">
          <div className="glass-card rounded-xl px-5 py-3 text-center border border-white/10">
            <p className="text-xs text-white/30">
              附近暂无灵魂 · 邀请朋友加入吧
            </p>
          </div>
        </div>
      )}

      {/* Legend */}
      <div className="absolute bottom-4 right-4 z-20 glass-card rounded-xl p-3 border border-white/10 space-y-2">
        <div className="flex items-center gap-2 text-xs text-white/40">
          <div className="w-3 h-3 rounded-full bg-white border-2 border-white/60" />
          <span>你</span>
        </div>
        <div className="flex items-center gap-2 text-xs text-white/40">
          <div className="w-3 h-3 rounded-full border-2 border-dashed border-white/40" />
          <span>星影</span>
        </div>
        <div className="flex items-center gap-2 text-xs text-white/40">
          <div className="w-2 h-2 rounded-full bg-green-400" />
          <span>在线</span>
        </div>
      </div>
    </main>
  );
}

// ── Utilities ──

function haversineDistance(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371; // km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function generateMockNearby(center: UserLocation): NearbyMatch[] {
  const elements = ["金", "木", "水", "火", "土"];
  return Array.from({ length: 8 }, (_, i) => {
    const angle = (i / 8) * Math.PI * 2 + Math.random() * 0.5;
    const dist = 0.02 + Math.random() * 0.08; // ~2-8km
    return {
      userId: `shadow-${i}`,
      matchScore: Math.floor(Math.random() * 30 + 62),
      latitude: center.latitude + Math.sin(angle) * dist,
      longitude: center.longitude + Math.cos(angle) * dist,
      element: elements[i % 5],
      isRecentlyActive: i < 3,
      isShadow: true,
    };
  });
}
