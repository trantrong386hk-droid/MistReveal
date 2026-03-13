// ============================================================
// MistReveal Web — shared TypeScript types
// ============================================================

// --- BaZi / Analysis types ---

export interface SoulmateAppearance {
  skin_tone: string;
  face_shape: string;
  eyes: string;
  other_features: string;
  hair: string;
  clothing: string;
}

export interface MatchingDeduction {
  user_trait: string;
  soulmate_trait: string;
  explanation?: string;
}

export interface SoulAnalysisResult {
  hexagram: string;
  user_element: string;
  soulmate_element: string;
  personality_description: string;
  personality_traits: string[];
  relationship_behaviors: string[];
  emotional_needs: string[];
  matching_deductions: MatchingDeduction[];
  soulmate_traits: string[];
  compatibility_score: number;
  destiny_type: string;
  soulmate_appearance: SoulmateAppearance;
  soulmate_analysis: string;
  promptToken: string;
  share_quote?: string;
}

// --- Analysis form input ---
export interface AnalysisFormData {
  name?: string;
  gender: "男" | "女";
  birthDate: string; // YYYY-MM-DD
  birthHour: string; // Chinese shichen label e.g. "子时(23-1)"
  birthPlace: string;
  soulmateGender: "男" | "女";
}

// --- Session storage keys ---
export const SESSION_KEY_ANALYSIS = "mistreveal_analysis_result";
export const SESSION_KEY_FORM = "mistreveal_form_data";
export const SESSION_KEY_TASK_ID = "mistreveal_task_id";
export const SESSION_KEY_IMAGE_URL = "mistreveal_image_url";
export const SESSION_KEY_COMPANION_ID = "mistreveal_companion_id";

// --- AI Companion ---
export interface PersonaSettings {
  element: string;
  personality_keywords: string[];
  speaking_style: string;
  traits: string[];
  destiny_type?: string;
  soulmate_gender?: string;
  name?: string;
}

export interface ElementBalance {
  metal: number;
  wood: number;
  water: number;
  fire: number;
  earth: number;
}

export interface AICompanion {
  id: string;
  user_id: string;
  persona_settings: PersonaSettings;
  visual_prompt?: string;
  intimacy_level: number;
  element_balance: ElementBalance;
  soul_analysis_record_id?: string;
  portrait_id?: string;
  created_at: string;
  updated_at: string;
}

// --- Chat messages ---
export interface ChatMessage {
  id: string;
  role: "user" | "ai";
  content: string;
  timestamp: Date;
}

// --- Generated portraits ---
export interface GeneratedPortrait {
  id: string;
  user_id: string;
  image_url: string;
  prompt?: string;
  created_at: string;
}

// --- Nearby match (for star map) ---
export interface NearbyMatch {
  userId: string;
  matchScore: number;
  latitude: number;
  longitude: number;
  element: string;
  isRecentlyActive: boolean;
  isShadow: boolean;
}

// --- Chinese time periods ---
export const CHINESE_HOURS = [
  { label: "子时", range: "23-1时", hour: 0 },
  { label: "丑时", range: "1-3时", hour: 1 },
  { label: "寅时", range: "3-5时", hour: 3 },
  { label: "卯时", range: "5-7时", hour: 5 },
  { label: "辰时", range: "7-9时", hour: 7 },
  { label: "巳时", range: "9-11时", hour: 9 },
  { label: "午时", range: "11-13时", hour: 11 },
  { label: "未时", range: "13-15时", hour: 13 },
  { label: "申时", range: "15-17时", hour: 15 },
  { label: "酉时", range: "17-19时", hour: 17 },
  { label: "戌时", range: "19-21时", hour: 19 },
  { label: "亥时", range: "21-23时", hour: 21 },
  { label: "不知道", range: "", hour: -1 },
] as const;

// --- Element colors ---
export const ELEMENT_COLORS: Record<string, string> = {
  金: "#C0A060",
  木: "#4A9B5F",
  水: "#4A7AB5",
  火: "#C05040",
  土: "#9B7B4A",
};

export const ELEMENT_GRADIENTS: Record<string, string> = {
  金: "from-yellow-700/30 to-yellow-500/10",
  木: "from-green-700/30 to-green-500/10",
  水: "from-blue-700/30 to-blue-500/10",
  火: "from-red-700/30 to-red-500/10",
  土: "from-amber-700/30 to-amber-500/10",
};
