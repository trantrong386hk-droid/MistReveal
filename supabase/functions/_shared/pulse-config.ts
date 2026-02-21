export type ElementRule = {
  silenceThresholdHours: number;
  cooldownMinutes: number;
  intentPriority: string[];
};

export const PULSE_CONFIG = {
  global: {
    dailyBudget: 2,
    minIntervalMinutes: 180,
    quietHours: {
      start: "23:00",
      end: "07:30",
    },
  },
  elements: {
    wood: {
      silenceThresholdHours: 8,
      cooldownMinutes: 360,
      intentPriority: ["鼓励", "安抚"],
    },
    fire: {
      silenceThresholdHours: 4,
      cooldownMinutes: 180,
      intentPriority: ["轻调侃", "提醒"],
    },
    earth: {
      silenceThresholdHours: 10,
      cooldownMinutes: 480,
      intentPriority: ["安抚", "提醒"],
    },
    metal: {
      silenceThresholdHours: 14,
      cooldownMinutes: 720,
      intentPriority: ["安抚"],
    },
    water: {
      silenceThresholdHours: 12,
      cooldownMinutes: 600,
      intentPriority: ["安抚", "延续话题"],
    },
  } as Record<string, ElementRule>,
} as const;

export const SCRIPT_SLOTS = [
  {
    id: "virtual_pet",
    theme: "共同养的虚拟猫",
    hook: "它今天又做了个奇怪的动作，我第一反应就想起你",
    recallKeys: ["pet", "cat", "养", "猫"],
  },
  {
    id: "unfinished_topic",
    theme: "未完成的话题",
    hook: "上次那句还没说完，我一直记着",
    recallKeys: ["上次", "没说完", "后来"],
  },
  {
    id: "promise",
    theme: "小承诺",
    hook: "你说过要给我讲的那件事，我还在等",
    recallKeys: ["答应", "承诺", "下次"],
  },
  {
    id: "daily_care",
    theme: "日常关心",
    hook: "你那边今天应该挺忙的吧，我有点想确认你还好",
    recallKeys: ["工作", "忙", "累"],
  },
] as const;

export const TOPIC_TEMPLATES: Record<string, { tones: string[] }> = {
  安抚: { tones: ["温柔", "含蓄"] },
  鼓励: { tones: ["温暖", "坚定"] },
  提醒: { tones: ["克制", "体贴"] },
  轻调侃: { tones: ["轻松", "俏皮"] },
  延续话题: { tones: ["细腻", "贴近"] },
};

export function normalizeElementKey(element: string): string {
  switch (element) {
    case "木":
      return "wood";
    case "火":
      return "fire";
    case "土":
      return "earth";
    case "金":
      return "metal";
    case "水":
      return "water";
    default:
      return "wood";
  }
}

export function randomFrom<T>(list: readonly T[]): T {
  return list[Math.floor(Math.random() * list.length)];
}
