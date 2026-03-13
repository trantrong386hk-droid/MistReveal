"use client";

import { useEffect, useRef } from "react";
import { ELEMENT_COLORS, type NearbyMatch } from "@/lib/types";

interface Props {
  userLocation: { latitude: number; longitude: number };
  nearbyUsers: NearbyMatch[];
  selectedUser: NearbyMatch | null;
  onSelectUser: (user: NearbyMatch | null) => void;
}

export default function StarMapLeaflet({
  userLocation,
  nearbyUsers,
  selectedUser,
  onSelectUser,
}: Props) {
  const mapRef = useRef<unknown>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const markersRef = useRef<Map<string, unknown>>(new Map());
  const userMarkerRef = useRef<unknown>(null);

  useEffect(() => {
    if (!containerRef.current || mapRef.current) return;

    // Dynamic import to avoid SSR
    import("leaflet").then((L) => {
      if (!containerRef.current || mapRef.current) return;

      // Fix default icon paths
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      delete (L.Icon.Default.prototype as any)._getIconUrl;
      L.Icon.Default.mergeOptions({
        iconRetinaUrl: "/leaflet/marker-icon-2x.png",
        iconUrl: "/leaflet/marker-icon.png",
        shadowUrl: "/leaflet/marker-shadow.png",
      });

      // Create map
      const map = L.map(containerRef.current!, {
        center: [userLocation.latitude, userLocation.longitude],
        zoom: 13,
        zoomControl: false,
        attributionControl: true,
      });

      mapRef.current = map;

      // Dark CartoDB tiles
      L.tileLayer(
        "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png",
        {
          attribution:
            '&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a> &copy; <a href="https://carto.com/attributions">CARTO</a>',
          subdomains: "abcd",
          maxZoom: 20,
        }
      ).addTo(map);

      // User marker (glowing white dot)
      const userIcon = L.divIcon({
        className: "",
        html: `
          <div style="position:relative;width:20px;height:20px;display:flex;align-items:center;justify-content:center;">
            <div style="
              position:absolute;
              width:20px;height:20px;
              border-radius:50%;
              background:rgba(255,255,255,0.15);
              border:2px solid rgba(255,255,255,0.6);
              animation:star-pulse 2s ease-in-out infinite;
            "></div>
            <div style="
              width:8px;height:8px;
              border-radius:50%;
              background:white;
              box-shadow:0 0 8px white;
            "></div>
          </div>
        `,
        iconSize: [20, 20],
        iconAnchor: [10, 10],
      });

      userMarkerRef.current = L.marker(
        [userLocation.latitude, userLocation.longitude],
        { icon: userIcon }
      )
        .addTo(map)
        .bindTooltip("你", { permanent: false, className: "star-tooltip" });

      // Add nearby user markers
      nearbyUsers.forEach((user) => {
        addUserMarker(L, map, user, onSelectUser, markersRef);
      });
    });

    return () => {
      if (mapRef.current) {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        (mapRef.current as any).remove();
        mapRef.current = null;
        markersRef.current.clear();
      }
    };
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Update nearby markers when data changes
  useEffect(() => {
    if (!mapRef.current) return;

    import("leaflet").then((L) => {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const map = mapRef.current as any;

      // Remove stale markers
      const currentIds = new Set(nearbyUsers.map((u) => u.userId));
      markersRef.current.forEach((marker, id) => {
        if (!currentIds.has(id)) {
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          (marker as any).remove();
          markersRef.current.delete(id);
        }
      });

      // Add new markers
      nearbyUsers.forEach((user) => {
        if (!markersRef.current.has(user.userId)) {
          addUserMarker(L, map, user, onSelectUser, markersRef);
        }
      });
    });
  }, [nearbyUsers, onSelectUser]);

  // Highlight selected user
  useEffect(() => {
    markersRef.current.forEach((marker, id) => {
      const user = nearbyUsers.find((u) => u.userId === id);
      if (!user) return;
      const isSelected = selectedUser?.userId === id;
      const color = ELEMENT_COLORS[user.element] || "#8B5CF6";
      const size = isSelected ? 16 : 12;
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      (marker as any).setIcon(createShadowIcon(color, size, user.isRecentlyActive, isSelected));
    });
  }, [selectedUser, nearbyUsers]);

  return (
    <div ref={containerRef} className="w-full h-full" />
  );
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function createShadowIcon(color: string, size: number, isActive: boolean, isSelected: boolean): any {
  const pulseSize = size * 2.5;
  return {
    className: "",
    html: `
      <div style="position:relative;width:${size}px;height:${size}px;display:flex;align-items:center;justify-content:center;">
        ${isActive ? `<div style="
          position:absolute;
          width:${pulseSize}px;height:${pulseSize}px;
          top:${-(pulseSize - size) / 2}px;
          left:${-(pulseSize - size) / 2}px;
          border-radius:50%;
          background:${color}20;
          border:1px solid ${color}40;
          animation:star-pulse ${isSelected ? "1s" : "3s"} ease-in-out infinite;
        "></div>` : ""}
        <div style="
          width:${size}px;height:${size}px;
          border-radius:50%;
          background:${color}30;
          border:2px dashed ${color}${isSelected ? "cc" : "60"};
          display:flex;align-items:center;justify-content:center;
          font-size:${Math.max(size * 0.45, 7)}px;
          color:${color};
          box-shadow:${isSelected ? `0 0 12px ${color}60` : "none"};
        ">
          星
        </div>
      </div>
    `,
    iconSize: [size, size],
    iconAnchor: [size / 2, size / 2],
  };
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function addUserMarker(
  L: any,
  map: any,
  user: NearbyMatch,
  onSelectUser: (u: NearbyMatch) => void,
  markersRef: React.MutableRefObject<Map<string, unknown>>
) {
  const color = ELEMENT_COLORS[user.element] || "#8B5CF6";
  const iconDef = createShadowIcon(color, 12, user.isRecentlyActive, false);

  const icon = L.divIcon(iconDef);
  const marker = L.marker([user.latitude, user.longitude], { icon })
    .addTo(map)
    .bindTooltip(
      `${user.element}属 · ${user.matchScore}%`,
      { permanent: false, className: "star-tooltip" }
    )
    .on("click", () => onSelectUser(user));

  markersRef.current.set(user.userId, marker);
}
