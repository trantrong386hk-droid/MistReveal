import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { Solar } from "npm:lunar-javascript";

// ============================================================
// web-analyze — 网页版灵魂分析 + 八字计算 + LLM 调用
//
// 流程：
//   1. JWT 验证
//   2. 解析出生信息（日期、时辰、地点、性别）
//   3. 用 lunar-javascript 计算精准八字（含真太阳时修正）
//   4. 推算五行得分 / 喜用神 / 十神 / 夫妻星 / 伴侣年龄
//   5. 构建与 iOS TextGenerationService 相同的用户消息
//   6. 调用阿里云百炼 LLM
//   7. 提取 image_prompt → 追加发型/服饰 → 存入 prompt_tokens
//   8. 返回带 promptToken 的 SoulAnalysisResult JSON
// ============================================================

const ALIYUN_API_URL =
  "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions";
const ALIYUN_MODEL = "qwen-plus";

// ────────────────────────────────────────────────────────────
// 天干 → 五行
// ────────────────────────────────────────────────────────────
const ganToElement: Record<string, string> = {
  甲: "木", 乙: "木", 丙: "火", 丁: "火",
  戊: "土", 己: "土", 庚: "金", 辛: "金",
  壬: "水", 癸: "水",
};

// 天干阴阳：1=阳, 0=阴
const ganYinYang: Record<string, number> = {
  甲: 1, 乙: 0, 丙: 1, 丁: 0,
  戊: 1, 己: 0, 庚: 1, 辛: 0,
  壬: 1, 癸: 0,
};

// 地支 → 五行（本气）
const zhiToElement: Record<string, string> = {
  子: "水", 丑: "土", 寅: "木", 卯: "木",
  辰: "土", 巳: "火", 午: "火", 未: "土",
  申: "金", 酉: "金", 戌: "土", 亥: "水",
};

// ────────────────────────────────────────────────────────────
// 地支藏干（加权比例）
// ────────────────────────────────────────────────────────────
interface HiddenStem {
  stem: string;
  proportion: number;
}

const zhiHiddenStems: Record<string, HiddenStem[]> = {
  子: [{ stem: "癸", proportion: 1.0 }],
  丑: [{ stem: "己", proportion: 0.6 }, { stem: "癸", proportion: 0.3 }, { stem: "辛", proportion: 0.1 }],
  寅: [{ stem: "甲", proportion: 0.6 }, { stem: "丙", proportion: 0.3 }, { stem: "戊", proportion: 0.1 }],
  卯: [{ stem: "乙", proportion: 1.0 }],
  辰: [{ stem: "戊", proportion: 0.7 }, { stem: "癸", proportion: 0.2 }, { stem: "乙", proportion: 0.1 }],
  巳: [{ stem: "丙", proportion: 0.6 }, { stem: "戊", proportion: 0.3 }, { stem: "庚", proportion: 0.1 }],
  午: [{ stem: "丁", proportion: 0.7 }, { stem: "己", proportion: 0.3 }],
  未: [{ stem: "己", proportion: 0.6 }, { stem: "丁", proportion: 0.3 }, { stem: "乙", proportion: 0.1 }],
  申: [{ stem: "庚", proportion: 0.6 }, { stem: "壬", proportion: 0.3 }, { stem: "戊", proportion: 0.1 }],
  酉: [{ stem: "辛", proportion: 1.0 }],
  戌: [{ stem: "戊", proportion: 0.7 }, { stem: "辛", proportion: 0.2 }, { stem: "丁", proportion: 0.1 }],
  亥: [{ stem: "壬", proportion: 0.7 }, { stem: "甲", proportion: 0.3 }],
};

// ────────────────────────────────────────────────────────────
// 五行相生相克
// ────────────────────────────────────────────────────────────
const wuXingGenerates: Record<string, string> = {
  木: "火", 火: "土", 土: "金", 金: "水", 水: "木",
};
const wuXingGeneratedBy: Record<string, string> = {
  木: "水", 火: "木", 土: "火", 金: "土", 水: "金",
};
const wuXingControls: Record<string, string> = {
  木: "土", 火: "金", 土: "水", 金: "木", 水: "火",
};

// ────────────────────────────────────────────────────────────
// 时辰 → 小时（中点，整点）
// ────────────────────────────────────────────────────────────
const birthTimeToHour: Record<string, number> = {
  子时: 23, 丑时: 1, 寅时: 3, 卯时: 5,
  辰时: 7, 巳时: 9, 午时: 11, 未时: 13,
  申时: 15, 酉时: 17, 戌时: 19, 亥时: 21,
  未知: -1,
};

// ────────────────────────────────────────────────────────────
// 城市经度表（真太阳时修正）
// ────────────────────────────────────────────────────────────
const cityLongitude: Record<string, number> = {
  北京: 116.4, 上海: 121.5, 广州: 113.3, 深圳: 114.1,
  成都: 104.1, 重庆: 106.5, 杭州: 120.2, 南京: 118.8,
  武汉: 114.3, 西安: 108.9, 沈阳: 123.4, 哈尔滨: 126.5,
  长沙: 113.0, 郑州: 113.6, 济南: 117.0, 福州: 119.3,
  南昌: 115.9, 合肥: 117.3, 天津: 117.2, 石家庄: 114.5,
  太原: 112.5, 呼和浩特: 111.8, 昆明: 102.7, 贵阳: 106.7,
  南宁: 108.4, 兰州: 103.8, 西宁: 101.8, 银川: 106.3,
  乌鲁木齐: 87.6, 拉萨: 91.1, 长春: 125.3, 海口: 110.3,
  厦门: 118.1,
};

function getCityLongitude(city: string): number | null {
  // 精确匹配
  if (city in cityLongitude) return cityLongitude[city];
  // 前缀匹配（≥2字）
  for (const [k, v] of Object.entries(cityLongitude)) {
    if (k.length >= 2 && city.startsWith(k.slice(0, 2))) return v;
  }
  // 包含匹配（≥2字）
  for (const [k, v] of Object.entries(cityLongitude)) {
    if (k.length >= 2 && city.includes(k.slice(0, 2))) return v;
  }
  return null;
}

// ────────────────────────────────────────────────────────────
// 十神计算
// ────────────────────────────────────────────────────────────
function tenGod(dayStem: string, otherStem: string): string {
  const dayElement = ganToElement[dayStem];
  const otherElement = ganToElement[otherStem];
  if (!dayElement || !otherElement) return "比肩";
  const samePolarity = ganYinYang[dayStem] === ganYinYang[otherStem];

  if (dayElement === otherElement) {
    return samePolarity ? "比肩" : "劫财";
  } else if (wuXingGenerates[dayElement] === otherElement) {
    return samePolarity ? "食神" : "伤官";
  } else if (wuXingControls[dayElement] === otherElement) {
    return samePolarity ? "偏财" : "正财";
  } else if (wuXingGeneratedBy[dayElement] === otherElement) {
    // 生我者 → 印
    return samePolarity ? "偏印" : "正印";
  } else {
    // 克我者 → 官/杀
    return samePolarity ? "七杀" : "正官";
  }
}

// ────────────────────────────────────────────────────────────
// 喜用神推断
// ────────────────────────────────────────────────────────────
function inferXiYongShen(
  dayStemElement: string,
  elementScores: Record<string, number>,
  dayStem: string,
  monthPillar: string
): [string, string] {
  const selfScore = elementScores[dayStemElement] ?? 0;
  const helperElement = wuXingGeneratedBy[dayStemElement] ?? "";
  const helperScore = elementScores[helperElement] ?? 0;
  const selfStrength = selfScore + helperScore;

  // 调候优先：壬水生于申月
  if (dayStem === "壬" && monthPillar.includes("申")) {
    const fireScore = elementScores["火"] ?? 0;
    const woodScore = elementScores["木"] ?? 0;
    if (fireScore < 10 && woodScore >= 15) {
      return ["木", "壬水生于申月，金水两旺而寒冷，火不足以调候，取木泄秀生发"];
    } else if (fireScore < 10) {
      return ["火", "壬水生于申月，金水两旺而寒冷，急需火来温暖调候"];
    } else {
      return ["木", "壬水生于申月，秋金旺水寒，取木泄秀生发"];
    }
  }

  // 常规身强身弱（总分 125，阈值 50）
  if (selfStrength < 50) {
    const xi = wuXingGeneratedBy[dayStemElement] ?? dayStemElement;
    return [xi, `日主${dayStemElement}偏弱(力量${selfStrength.toFixed(1)}/125)，需要${xi}来生扶`];
  } else {
    const xi = wuXingGenerates[dayStemElement] ?? "土";
    return [xi, `日主${dayStemElement}偏旺(力量${selfStrength.toFixed(1)}/125)，需要${xi}来泄耗平衡`];
  }
}

// ────────────────────────────────────────────────────────────
// 伴侣年龄偏好
// ────────────────────────────────────────────────────────────
function inferAgePreference(
  spouseStarPillars: string[],
  dayStemElement: string,
  elementScores: Record<string, number>
): [string, number] {
  if (spouseStarPillars.length === 0) {
    const selfScore = elementScores[dayStemElement] ?? 0;
    const helperScore = elementScores[wuXingGeneratedBy[dayStemElement] ?? ""] ?? 0;
    const selfStrength = selfScore + helperScore;
    if (selfStrength < 30) return ["印(无夫妻星)", 3];
    if (selfStrength > 75) return ["食伤(无夫妻星)", -3];
    return ["default(无夫妻星)", 0];
  }

  const pillarOffsets: Record<string, number> = {
    年柱: 3, 月柱: 1, 日柱: 0, 时柱: -3,
  };
  let total = 0;
  let count = 0;
  const names: string[] = [];
  for (const p of spouseStarPillars) {
    if (p in pillarOffsets) {
      total += pillarOffsets[p];
      count++;
      names.push(p);
    }
  }
  const avg = count > 0 ? Math.round(total / count) : 0;
  return [`${names.join("+")}见夫妻星`, avg];
}

// ────────────────────────────────────────────────────────────
// 真太阳时修正
// ────────────────────────────────────────────────────────────
interface TrueSolarResult {
  hour: number;
  minute: number;
  dayOffset: number;
  correctionMinutes: number;
}

function calculateTrueSolarTime(
  hour: number,
  minute: number,
  longitude: number | null
): TrueSolarResult {
  if (longitude === null) {
    return { hour, minute, dayOffset: 0, correctionMinutes: 0 };
  }
  const correctionMinutes = Math.round((longitude - 120.0) * 4.0);
  let totalMinutes = hour * 60 + minute + correctionMinutes;
  let dayOffset = 0;
  if (totalMinutes < 0) {
    dayOffset = -1;
    totalMinutes += 24 * 60;
  } else if (totalMinutes >= 24 * 60) {
    dayOffset = 1;
    totalMinutes -= 24 * 60;
  }
  return {
    hour: Math.floor(totalMinutes / 60),
    minute: totalMinutes % 60,
    dayOffset,
    correctionMinutes,
  };
}

// 日期加减天数（UTC，处理跨月/跨年）
function addDays(
  year: number, month: number, day: number, delta: number
): [number, number, number] {
  const d = new Date(Date.UTC(year, month - 1, day + delta));
  return [d.getUTCFullYear(), d.getUTCMonth() + 1, d.getUTCDate()];
}

// 计算用户年龄
function calculateAge(birthYear: number, birthMonth: number, birthDay: number): number {
  const now = new Date();
  let age = now.getUTCFullYear() - birthYear;
  if (
    now.getUTCMonth() + 1 < birthMonth ||
    (now.getUTCMonth() + 1 === birthMonth && now.getUTCDate() < birthDay)
  ) {
    age--;
  }
  return age;
}

// ────────────────────────────────────────────────────────────
// BaZi 信息结构
// ────────────────────────────────────────────────────────────
interface BaZiInfo {
  yearPillar: string;
  monthPillar: string;
  dayPillar: string;
  timePillar: string;           // "未知" if unknown
  dayStem: string;
  dayStemElement: string;
  elementSummary: string;
  missingElements: string[];
  strongElements: string[];
  xiYongShen: string;
  xiYongReason: string;
  yearNaYin: string;
  dayNaYin: string;
  dominantGod: string;
  tenGodSummary: string;
  spouseStarType: string | null;
  spouseStarPillars: string[];
  targetAge: number | null;
  agePreference: string;
  elementScores: Record<string, number>;
}

// ────────────────────────────────────────────────────────────
// 八字计算（lunar-javascript）
// ────────────────────────────────────────────────────────────
function calculateBaZi(
  year: number,
  month: number,
  day: number,
  birthTimeStr: string,
  location: string,
  gender: string
): BaZiInfo | null {
  try {
    const birthTimeUnknown = birthTimeStr === "未知";

    // 时辰 → 小时
    let hour: number;
    let minute = 0;

    if (birthTimeUnknown) {
      hour = 12; // 午时占位
    } else if (birthTimeStr.includes(":")) {
      const parts = birthTimeStr.split(":");
      hour = parseInt(parts[0]) || 12;
      minute = parts.length > 1 ? (parseInt(parts[1]) || 0) : 0;
    } else {
      // 时辰字符串（可能带括号说明），截取前3字
      const key = birthTimeStr.slice(0, 2) + "时";
      const h = birthTimeToHour[key] ?? birthTimeToHour[birthTimeStr];
      hour = h !== undefined && h >= 0 ? h : 12;
    }

    // 真太阳时修正
    const longitude = getCityLongitude(location);
    const trueSolar = calculateTrueSolarTime(hour, minute, longitude);

    let correctedYear = year;
    let correctedMonth = month;
    let correctedDay = day;

    if (trueSolar.dayOffset !== 0) {
      [correctedYear, correctedMonth, correctedDay] = addDays(
        year, month, day, trueSolar.dayOffset
      );
    }

    // lunar-javascript 计算
    const solar = Solar.fromYmdHms(
      correctedYear, correctedMonth, correctedDay,
      trueSolar.hour, trueSolar.minute, 0
    );
    const lunar = solar.getLunar();
    const eightChar = lunar.getEightChar();

    // sect 修正（晚子时跨日）
    const useSect2 = trueSolar.dayOffset < 0 && trueSolar.hour >= 23;
    eightChar.setSect(useSect2 ? 2 : 1);

    const yearPillar: string = eightChar.getYear();
    const monthPillar: string = eightChar.getMonth();
    const dayPillar: string = eightChar.getDay();
    const timePillar: string = birthTimeUnknown ? "未知" : eightChar.getTime();

    const yearGan: string = yearPillar[0];
    const yearZhi: string = yearPillar[1];
    const monthGan: string = monthPillar[0];
    const monthZhi: string = monthPillar[1];
    const dayGan: string = dayPillar[0];
    const dayZhi: string = dayPillar[1];
    const timeGan: string = birthTimeUnknown ? "" : timePillar[0];
    const timeZhi: string = birthTimeUnknown ? "" : timePillar[1];

    const dayStem = dayGan;
    const dayStemElement = ganToElement[dayStem] ?? "未知";

    // 五行加权得分
    // 天干 10分 × 3(or4), 月支 40分, 年/日/时支 各15分
    const elementScores: Record<string, number> = {
      金: 0, 木: 0, 水: 0, 火: 0, 土: 0,
    };

    const allGan = birthTimeUnknown
      ? [yearGan, monthGan, dayGan]
      : [yearGan, monthGan, dayGan, timeGan];

    for (const g of allGan) {
      const e = ganToElement[g];
      if (e) elementScores[e] += 10.0;
    }

    const zhiBranches: [string, number][] = birthTimeUnknown
      ? [[yearZhi, 15], [monthZhi, 40], [dayZhi, 15]]
      : [[yearZhi, 15], [monthZhi, 40], [dayZhi, 15], [timeZhi, 15]];

    for (const [zhi, baseScore] of zhiBranches) {
      const hidden = zhiHiddenStems[zhi] ?? [];
      for (const hs of hidden) {
        const e = ganToElement[hs.stem];
        if (e) elementScores[e] += baseScore * hs.proportion;
      }
    }

    const metalScore = elementScores["金"];
    const woodScore = elementScores["木"];
    const waterScore = elementScores["水"];
    const fireScore = elementScores["火"];
    const earthScore = elementScores["土"];

    const elementSummary =
      `金${metalScore.toFixed(1)} 木${woodScore.toFixed(1)} 水${waterScore.toFixed(1)} 火${fireScore.toFixed(1)} 土${earthScore.toFixed(1)}`;

    const missingElements = Object.entries(elementScores)
      .filter(([, v]) => v < 1.0)
      .sort(([, a], [, b]) => a - b)
      .map(([k]) => k);

    const strongElements = Object.entries(elementScores)
      .filter(([, v]) => v > 35.0)
      .sort(([, a], [, b]) => b - a)
      .map(([k]) => k);

    // 喜用神
    const [xiYongShen, xiYongReason] = inferXiYongShen(
      dayStemElement, elementScores, dayStem, monthPillar
    );

    // 纳音
    const yearNaYin: string = (eightChar as any).getYearNaYin?.() ?? "";
    const dayNaYin: string = (eightChar as any).getDayNaYin?.() ?? "";

    // 十神计算
    const ganPillars: [string, string][] = birthTimeUnknown
      ? [["年柱", yearGan], ["月柱", monthGan]]
      : [["年柱", yearGan], ["月柱", monthGan], ["时柱", timeGan]];

    interface TenGodEntry {
      pillar: string;
      position: string;
      stem: string;
      god: string;
    }
    const tenGodMap: TenGodEntry[] = [];

    for (const [pillarName, stem] of ganPillars) {
      const god = tenGod(dayStem, stem);
      tenGodMap.push({ pillar: pillarName, position: "天干", stem, god });
    }

    const zhiPillarNames: [string, string, number][] = birthTimeUnknown
      ? [["年柱", yearZhi, 15], ["月柱", monthZhi, 40], ["日柱", dayZhi, 15]]
      : [["年柱", yearZhi, 15], ["月柱", monthZhi, 40], ["日柱", dayZhi, 15], ["时柱", timeZhi, 15]];

    for (const [pillarName, zhi] of zhiPillarNames) {
      const hidden = zhiHiddenStems[zhi] ?? [];
      if (hidden.length > 0) {
        const god = tenGod(dayStem, hidden[0].stem);
        tenGodMap.push({ pillar: pillarName, position: `地支(${zhi})`, stem: hidden[0].stem, god });
      }
    }

    // 十神得分（含权重）
    const tenGodScores: Record<string, number> = {};
    for (const [, stem] of ganPillars) {
      const god = tenGod(dayStem, stem);
      tenGodScores[god] = (tenGodScores[god] ?? 0) + 10.0;
    }
    for (const [, zhi, baseScore] of zhiPillarNames) {
      const hidden = zhiHiddenStems[zhi] ?? [];
      for (const hs of hidden) {
        const god = tenGod(dayStem, hs.stem);
        tenGodScores[god] = (tenGodScores[god] ?? 0) + baseScore * hs.proportion;
      }
    }

    // dominantGod（排除比肩/劫财）
    const nonSelf = Object.entries(tenGodScores).filter(
      ([k]) => k !== "比肩" && k !== "劫财"
    );
    const dominantGod = nonSelf.length > 0
      ? nonSelf.sort(([, a], [, b]) => b - a)[0][0]
      : "正印";

    const tenGodSummary = tenGodMap
      .map((e) => `${e.pillar}${e.position}:${e.god}`)
      .join("、");

    // 夫/妻星
    const spouseStarNames =
      gender === "女" ? ["正官", "七杀"] : ["正财", "偏财"];
    const spouseStarPillars: string[] = [];
    let spouseStarType: string | null = null;

    for (const starName of spouseStarNames) {
      for (const entry of tenGodMap) {
        if (entry.god === starName) {
          if (!spouseStarPillars.includes(entry.pillar)) {
            spouseStarPillars.push(entry.pillar);
          }
          if (!spouseStarType) spouseStarType = starName;
        }
      }
    }

    // 伴侣目标年龄
    const userAge = calculateAge(year, month, day);
    let targetAge: number | null = null;
    let agePreference: string;

    if (birthTimeUnknown) {
      targetAge = Math.max(18, userAge);
      agePreference = "时辰未知(同龄默认)";
    } else {
      const [agePref, ageOffset] = inferAgePreference(
        spouseStarPillars, dayStemElement, elementScores
      );
      agePreference = agePref;
      targetAge = Math.max(18, userAge + ageOffset);
    }

    return {
      yearPillar, monthPillar, dayPillar, timePillar,
      dayStem, dayStemElement,
      elementSummary, missingElements, strongElements,
      xiYongShen, xiYongReason,
      yearNaYin, dayNaYin,
      dominantGod, tenGodSummary,
      spouseStarType, spouseStarPillars,
      targetAge, agePreference,
      elementScores,
    };
  } catch (e) {
    console.error("[web-analyze] BaZi calculation failed:", e);
    return null;
  }
}

// ────────────────────────────────────────────────────────────
// 十神人设（气质描述）
// ────────────────────────────────────────────────────────────
function shishenPersona(dominantGod: string): string {
  switch (dominantGod) {
    case "七杀":
      return "表情坚毅果断，眉宇间英气外露，眼神锐利有穿透力，姿态挺拔刚劲，浑身散发着不怒自威的气场";
    case "正官":
      return "表情从容端正，眉宇间舒展有度，眼神沉稳清澈，身姿挺拔但不紧绷，周身散发着从容儒雅的气场";
    case "正财":
      return "表情安稳真诚，笑容自然坦荡，眼神踏实笃定，体态放松可靠，散发着让人安心的沉稳气场";
    case "偏财":
      return "表情生动爽朗，笑容有感染力，眼神灵活明亮带着几分不羁，姿态轻松不拘束，周身散发着豪爽气场";
    case "食神":
      return "表情松弛舒展，眉眼之间自在放松，嘴角天然上扬，眼神柔和慵懒，体态放松自然，整个人散发着让人想靠近的气息";
    case "伤官":
      return "表情清冽不羁，眉眼锐利而有光彩，眼神中带着不服输的倔强与灵气，姿态有张力，气质桀骜中带着文艺感";
    case "正印":
      return "表情温和从容，眼神清澈而笃定，眉宇间舒展，体态从容优雅，周身散发着沉静的书卷气";
    case "偏印":
      return "表情沉思内敛，眼神深远有洞察力，神态独立疏离，体态清瘦有棱角，如不动声色的观察者";
    case "比肩":
      return "表情坦荡磊落，目光直视前方带着自信，姿态挺拔有力，整个人散发着无需证明的从容与笃定";
    case "劫财":
      return "表情锐利警觉，眼神如猎豹般专注，姿态矫健紧实，周身散发着蓄势待发的竞争力";
    default:
      return "五官端正自然，眉眼之间带着平和的力量，神态从容自信";
  }
}

// ────────────────────────────────────────────────────────────
// 夫妻星骨相约束
// ────────────────────────────────────────────────────────────
function spouseStarAppearance(spouseStarType: string | null): string | null {
  if (!spouseStarType) return null;
  switch (spouseStarType) {
    case "七杀":
      return "骨架挺拔有力，轮廓清晰立体，下颌线转折分明，肩宽体健，身材匀称有肌肉线条";
    case "正官":
      return "五官端正比例协调，额头宽阔饱满，体格匀称挺拔有分量感，面部骨骼正直大气";
    case "正财":
      return "面部骨骼线条圆润柔和，体态匀称敦实健康，骨架给人安稳踏实的感觉";
    case "偏财":
      return "五官骨骼鲜明有辨识度，体态匀称灵活有张力，骨架轻盈不沉重";
    default:
      return null;
  }
}

// ────────────────────────────────────────────────────────────
// 五行能量方向描述
// ────────────────────────────────────────────────────────────
function elementEnergyDescription(element: string, soulmateGender: string): string {
  switch (element) {
    case "木":
      return `用户命局缺生机，伴侣应传递「蓬勃生命力」的视觉感受。
气质方向：清爽、通透、有活力、松弛自然。
光线环境：中性暖光，背景以室内/城市质感场景为主，避免大量绿植。
服饰：自由选择任何有质感的日常服饰，不受五行色调限制。注重面料质感和穿搭的真实生活感。`;
    case "火":
      return `用户命局缺温暖，伴侣应传递「被温暖包裹」的视觉感受。
气质方向：温暖、有温度、亲近、让人安心。
光线环境：中性暖光，室内/城市质感场景为主，避免强色环境。
服饰：自由选择任何有质感的日常服饰，不受五行色调限制。注重面料质感和穿搭的真实生活感。`;
    case "金":
      return `用户命局缺秩序，伴侣应传递「干净利落」的视觉感受。
气质方向：精致、干净、克制、有分寸感。
光线环境：中性冷白光或中性暖光，极简室内/城市质感场景。
服饰：自由选择任何有质感的日常服饰，不受五行色调限制。注重面料质感和穿搭的真实生活感。`;
    case "水":
      return `用户命局缺柔韧，伴侣应传递「沉静疏解」的视觉感受。
气质方向：沉静、从容、柔和、不张扬的高级感。
光线环境：柔和低饱和光线，室内/城市质感场景为主，避免强色环境。
服饰：自由选择任何有质感的日常服饰，不受五行色调限制。注重面料质感和穿搭的真实生活感。`;
    case "土":
      return `用户命局缺安全感，伴侣应传递「踏实安定」的视觉感受。
气质方向：沉稳、可靠、踏实、有安全感。
光线环境：中性暖光，室内/城市质感场景为主，避免强色环境。
服饰：自由选择任何有质感的日常服饰，不受五行色调限制。注重面料质感和穿搭的真实生活感。`;
    default:
      return "根据伴侣五行选择对应的气质感受方向。";
  }
}

// ────────────────────────────────────────────────────────────
// 禁用词汇清单
// ────────────────────────────────────────────────────────────
function generateForbiddenWords(xiYongShen: string): string {
  switch (xiYongShen) {
    case "木":
      return `❌ 禁用金系词汇：白皙透亮、银灰色、金属光泽、目光如刃、冷峻、骨相突出、轮廓分明、下颌线清晰、眼神清冷
❌ 禁用水系词汇：水润细腻、深蓝色、流动光影、灵动飘逸、眼波如水
❌ 禁用冰冷词汇：沉重、枯燥、压抑、冰冷、阴郁、灰暗、萧瑟、凋零、僵硬、死寂
✅ 必须使用：自然健康、有生命力、清新、蓬勃、质朴、温润`;
    case "火":
      return `❌ 禁用金系词汇：白皙透亮、银灰色、金属光泽、目光如刃、冷峻、骨相突出
❌ 禁用水系词汇：水润细腻、深蓝色、灵动飘逸
❌ 禁用冰冷词汇：沉重、枯燥、压抑、冰冷、阴郁、灰暗、萧瑟、凝滞、死气沉沉
✅ 必须使用：温暖、有温度感、明朗、活力、光芒`;
    case "金":
      return `❌ 禁用木系词汇：白里透红、松绿色、林间光影、温润
❌ 禁用火系词汇：红润、暖色调、目光如炬
✅ 必须使用：冷峻、利落、轮廓分明、通透、干净
✅ 调候提示：若用户秋冬生人，背景需加入暖金色夕阳光或琥珀色余晖平衡寒气`;
    case "水":
      return `❌ 禁用火系词汇：红润、暖色调、温暖光线、目光如炬
❌ 禁用土系词汇：小麦色、蜜糖色、驼色
✅ 必须使用：水润细腻、灵动、流动、沉静、深邃
✅ 调候提示：若用户冬生人，背景需加入暖黄灯光或晨曦暖阳平衡寒气`;
    case "土":
      return `❌ 禁用金系词汇：白皙透亮、银灰色、金属光泽、冷峻
❌ 禁用水系词汇：深蓝色、流动光影、灵动飘逸
✅ 必须使用：沉稳、厚实、温厚、敦实、踏实、有分量`;
    default:
      return "✅ 根据伴侣五行选择对应的色调和质感词汇";
  }
}

// ────────────────────────────────────────────────────────────
// 系统提示词
// ────────────────────────────────────────────────────────────
const SOUL_ANALYSIS_SYSTEM_PROMPT = `你是一位结合现代心理学与中国传统命理学的灵魂架构师。你的任务是把系统提供的命理数据转化为有画面、有性格、有气质的人物描写。

【硬性规则】
- 异性伴侣匹配：男性用户 → 女性伴侣（用"她"）；女性用户 → 男性伴侣（用"他"）
- 所有命理数据由系统提供，你不要自行推算
- user_element 必须与系统提供的日主五行一致
- soulmate_element 必须等于系统提供的喜用神，不可更改
- 禁用词：星辰、宿命、银河、轮回、天命、前世、来生、缘定三生、冥冥之中、注定；韩系、网红、偶像、奶油、娃娃脸、初恋脸、氧气感

【伴侣画像原则】
- 伴侣五行 = 喜用神，体现为"能量感受"，不要用元素字面颜色
- 视觉重点：骨相结构、体态张力、眼神神态、皮肤质感
- 服饰自由选择，追求真实生活感和多样性，每次生成应有不同的穿搭风格
- 发色必须自然黑/深棕，不染发、不挑染
- 五行能量只体现在气质、光影与环境，不体现在发色或瞳色
- 光线尽量中性暖光，背景优先选择中性室内/城市质感场景，避免大量绿植

【输出风格——极其重要】
口语化、有温度、真实感——像一个特别懂你的朋友在说话，不是命理师在写分析报告。
核心原则：把八字结论翻译成用户的生活体验和情绪感受，让读者产生"就是我"的强烈共鸣。
- 用"你"直接对话，短句，节奏轻快，避免长难句
- 写具体的行为、场景、情绪，不写抽象术语
- 带一点"洞察感"——像朋友说了一句"你就是这样的人"，让人既意外又觉得准
- 禁止：命局、日主、十神、五行生克等术语出现在用户可见的内容字段中

【各字段写法示例】
personality_description: 用"你"直接对话，写具体行为或情绪，让读者产生"这说的就是我"的感觉。不写命理术语。100-150字。
好的示例："你很少主动说'我需要你'，但你的行动会替你说出这句话。别人开口之前，你早就默默做好了。"
坏的示例："日主壬水，印绶护身，情感上呈现出内敛保护型特质"

relationship_behaviors: 用"你会…"或"你总是…"开头，写感情中具体场景，让人觉得被看透了。
好的示例："在喜欢的人面前，你反而会变得有点安静，不像平时那么活跃"
坏的示例："感情中内敛保守，不善主动表达"

emotional_needs: 用内心独白语气，如"你需要一个…"或"你希望他能…"
好的示例："你需要一个不用你解释，他就能懂你在想什么的人"

matching_deductions explanation: 用生活化语言解释，有具体场景感，40-60字。
好的示例："你容易想太多，脑子转个不停。你需要的是那种能把你从自己念头里拉出来的人——不是给你讲道理，而是陪你发呆"
坏的示例："木能生火，补足用户命局中火气不足"

【输出格式】必须且只能返回以下JSON，不要有任何其他文字：
{"hexagram":"根据八字纳音推出的卦象名称（2-5字，有仪式感）","user_element":"用户日主五行","soulmate_element":"直接填写系统提供的喜用神","personality_description":"用你直接对话，写具体行为或情绪体验，让读者产生这说的就是我的感觉。不写命理术语。100-150字","personality_traits":["简短有力的特质标签3字以内","标签2","标签3","标签4"],"relationship_behaviors":["感情中具体场景用你会或你总是开头","场景2","场景3"],"emotional_needs":["用内心独白语气写渴望如你需要一个","需求2","需求3"],"matching_deductions":[{"user_trait":"你的某个性格特点口语化","soulmate_trait":"ta对应的特质","explanation":"生活化语言解释为什么这样的人适合你40-60字"}],"soulmate_traits":["ta的特质标签","特质2","特质3","特质4"],"compatibility_score":82到96之间的整数,"destiny_type":"缘分类型2-6字有意境如灵魂共鸣互补之缘","share_quote":"一句专属命格金句15-25字，有被一眼看穿的惊喜感，格式：你是那种…的人 或 有一种人…那就是你","soulmate_appearance":{"skin_tone":"传递五行能量方向感受15-25字","face_shape":"脸型描述10-20字","eyes":"眼睛特征加神态描写20-35字","other_features":"鼻唇其他特征20-30字","hair":"发型发色女性发型多样化15-25字","clothing":"日常服饰追求真实感15-25字"},"soulmate_analysis":"口语化有温度描述伴侣，让用户觉得这个人我好像在哪里见过，200-300字，不写命理术语","image_prompt":"中文绘图提示词80-120字，只写视觉特征不写心理描写，格式：一位[年龄]岁的东方[男/女]，半身肖像，微侧面自然回眸，[肤色质感]，[脸型骨相]，[眼神神态动作，严禁描写瞳色]，[五官细节]，[发型发色]，身穿[日常服饰风格多样]，[室内或城市背景中性光线]"}`;

// ────────────────────────────────────────────────────────────
// 构建用户消息
// ────────────────────────────────────────────────────────────
function buildUserMessage(
  bazi: BaZiInfo,
  gender: string,
  birthDate: string,
  location: string
): string {
  const soulmateGender = gender === "男" ? "女" : "男";
  const pronounHeShe = gender === "男" ? "她" : "他";
  const isThreePillar = bazi.timePillar === "未知";

  // 视觉年龄补偿
  let visualAge = bazi.targetAge;
  if (visualAge !== null) {
    if (visualAge <= 30) {
      // keep as-is
    } else if (visualAge <= 35) {
      visualAge = visualAge - 2;
    } else {
      visualAge = visualAge - 3;
    }
  }

  const ageInstruction = visualAge !== null
    ? `\n            4. image_prompt 中伴侣年龄必须写${visualAge}岁，不要使用其他年龄`
    : "";

  const visualAgeText = visualAge !== null
    ? `\n                年龄外观约束：人物面部必须严格符合${visualAge}岁的真实外观，皮肤紧致光滑，禁止添加法令纹、抬头纹、鱼尾纹等衰老特征。必须展现无龄感的精神状态，内在生命力充沛，眼神明亮有神，散发着不受年龄束缚的年轻活力。`
    : "";

  // 时柱地支五行
  const timePillarZhi = isThreePillar ? "" : bazi.timePillar[1] ?? "";
  const timePillarElement = timePillarZhi ? (zhiToElement[timePillarZhi] ?? "未知") : "";

  const personaText = shishenPersona(bazi.dominantGod);
  const spouseConstraintText = spouseStarAppearance(bazi.spouseStarType);
  const energyDescription = elementEnergyDescription(bazi.xiYongShen, soulmateGender);
  const forbiddenWords = generateForbiddenWords(bazi.xiYongShen);

  const spouseBlock = (spouseConstraintText && bazi.spouseStarType)
    ? `\n            夫妻星骨相约束（${bazi.spouseStarType}）：${spouseConstraintText}`
    : "";

  const pillarDataBlock = isThreePillar
    ? `三柱：${bazi.yearPillar} ${bazi.monthPillar} ${bazi.dayPillar}（出生时间未知，无时柱）
日主：${bazi.dayStem}（${bazi.dayStemElement}命）
年柱纳音：${bazi.yearNaYin}
日柱纳音：${bazi.dayNaYin}`
    : `四柱：${bazi.yearPillar} ${bazi.monthPillar} ${bazi.dayPillar} ${bazi.timePillar}
日主：${bazi.dayStem}（${bazi.dayStemElement}命）
时柱地支五行：${timePillarZhi}${timePillarElement}
年柱纳音：${bazi.yearNaYin}
日柱纳音：${bazi.dayNaYin}`;

  const rule5 = isThreePillar
    ? "5. 注意：用户出生时间未知，请勿引用时柱或推测出生时辰。所有性格分析聚焦于日主和月令，基于上方三柱数据"
    : `5. 所有性格分析和五行描述必须严格基于上方四柱数据，尤其是时柱"${bazi.timePillar}"（${timePillarZhi}${timePillarElement}），不要使用用户输入的原始时间`;

  const spouseStarLine = bazi.spouseStarType
    ? `${gender === "女" ? "夫" : "妻"}星：${bazi.spouseStarType} 出现于 ${bazi.spouseStarPillars.join("、")}`
    : "夫妻星：无";

  return `我已经通过专业历法引擎完成了这位用户的精准八字排盘（已经过真太阳时经度修正）。以下是硬核数据，请直接采用，不要自行推算：

═══ 系统排盘数据（真太阳时修正后）═══
${pillarDataBlock}
五行能量分布：${bazi.elementSummary}
五行缺失：${bazi.missingElements.length === 0 ? "无" : bazi.missingElements.join("、")}
五行偏旺：${bazi.strongElements.length === 0 ? "均衡" : bazi.strongElements.join("、")}
喜用神：${bazi.xiYongShen}（${bazi.xiYongReason}）
命局主导十神：${bazi.dominantGod}
十神分布：${bazi.tenGodSummary}
${spouseStarLine}
═══════════════════════════════════

═══ image_prompt 视觉注入数据 ═══
写 image_prompt 时参考以下数据：
- 十神人设 → 决定表情和姿态
- 夫妻星骨相 → 决定骨骼和体态
- 五行能量方向 → 决定光线/环境的感受方向（服饰自由发挥）

十神人设气质（${bazi.dominantGod}）：${personaText}${spouseBlock}

五行能量方向（${bazi.xiYongShen}）：${energyDescription}

伴侣性别：${soulmateGender}性
伴侣视觉年龄：${bazi.targetAge !== null ? bazi.targetAge : "未知"}岁

image_prompt 必须保留完整的人物+场景描述，不得退化成通用肖像模板。末尾统一追加：电影感肖像，浅景深，肤质细节自然，色调自然克制，中性室内或城市背景${visualAgeText}
═══════════════════════════════════

用户基本信息：${gender}性，${birthDate}生，现居${location}

【强制规则】
1. user_element 必须填"${bazi.dayStemElement}"
2. 伴侣必须是${soulmateGender}性，全文用"${pronounHeShe}"称呼
3. 【不可覆写】soulmate_element 必须填"${bazi.xiYongShen}"，禁止填其他五行
   - 你不得自行推算喜用神，系统已用调候算法精确计算
   - 视觉氛围（光线、环境）必须与「五行能量方向」一致
   - soulmateAppearance 的 skin_tone 应传递五行能量方向的感受，clothing 自由选择不受五行约束
4. 【严格禁用词汇清单】当喜用神=${bazi.xiYongShen}时，以下词汇 = 违反命理 = 严重错误：
${forbiddenWords}
${rule5}
6. 伴侣画像的气质必须匹配主导十神"${bazi.dominantGod}"对应的人设方向
7. ${bazi.spouseStarType ? `夫妻星为${bazi.spouseStarType}，伴侣的骨相、眼神、体态必须严格遵守第五层约束和上方视觉注入的夫妻星骨相约束` : "无夫妻星，以主导十神气质为主导"}
8. 严禁使用"清秀、精致、韩系、网红、甜美、白净、小清新"等词描述伴侣，伴侣必须有"五行能量感"而非"偶像感"
9. image_prompt 只写肉眼可见的视觉特征，禁止心理描写（如"有故事""内心丰富"）
10. image_prompt 中：光影/环境 → 跟随「五行能量方向」；表情/姿态 → 跟随「十神人设」；骨骼/体态 → 跟随「夫妻星骨相」；服饰 → 自由发挥，追求多样性
11. image_prompt 中人物面部必须符合目标年龄的真实外观，皮肤紧致光滑，禁止使用"成熟""沧桑""阅历""岁月沉淀"等老化词汇描述面部外观${ageInstruction}
12. image_prompt 中严禁描写瞳色或眼珠颜色，五行能量方向只影响光影/环境，不影响眼睛颜色和服饰。东亚人瞳色统一为自然深棕或黑褐色
13. 避免使用易触发风控的超写实词：如"微米级/纳米级皮肤纹理""无滤镜真实感""毛孔细微可见""细纹清晰可见"，可替换为"肤质细节自然""自然人像风格"

请基于以上数据进行深度灵魂解析，伴侣五行已由系统确定，请严格执行。`;
}

// ────────────────────────────────────────────────────────────
// 发型 + 服饰池（与 aliyun-proxy 保持一致）
// ────────────────────────────────────────────────────────────
const femaleHairPool: string[] = [
  "，黑色顺滑长直发，发丝垂落至腰间",
  "，深棕色长直发，自然垂顺，发梢内扣",
  "，自然波浪卷长发，散落至腰际，蓬松有层次",
  "，深色微卷长发，丰盈有层次，慵懒随性",
  "，乌黑中长直发，及锁骨，发梢轻微内扣",
  "，深棕锁骨长度直发，清爽利落",
  "，深色及肩波浪卷发，慵懒有层次感",
  "，柔顺长直发扎成低马尾，干净精炼",
  "，深色长发半扎，自然垂散，清新不做作",
  "，中长直发带空气感刘海，邻家温柔感",
  "，乌黑长发随意扎成丸子头，可爱又帅气",
  "，深棕色微卷中长发，发丝蓬松有空气感",
];

const maleHairPool: string[] = [
  "，干净利落的短发，自然纹理清晰",
  "，清爽短发偏分，额前发丝自然垂落",
  "，黑色短发，发型简洁有型",
  "，稍长的自然纹理短发，微微凌乱感",
  "，中长发自然下垂，发梢略带卷度",
  "，深色短发，后颈修剪整齐，清爽感",
];

function pickHairStyle(soulmateGender: string): string {
  const pool = soulmateGender === "女" ? femaleHairPool : maleHairPool;
  return pool[Math.floor(Math.random() * pool.length)];
}

const femaleElementClothingPool: Record<string, string[]> = {
  火: [
    "，身穿砖红色oversize针织毛衣，搭配米白宽腿裤，慵懒有质感",
    "，身穿赤陶色灯芯绒外套，内搭奶白色上衣，温暖有层次",
    "，身穿深玫红色廓形大衣，低调成熟有气场",
    "，身穿暗砖红色毛衣裙，腰间系细皮带，复古温柔",
    "，身穿樱桃棕色针织开衫，搭配同色系半裙，温柔不甜腻",
  ],
  木: [
    "，身穿苔绿色oversize亚麻衬衫，随性自然，清新利落",
    "，身穿橄榄绿廓形夹克，内搭米白T恤，户外活力感",
    "，身穿深橄榄绿针织开衫，慵懒文艺，有生命力",
    "，身穿卡其棕灯芯绒衬衫裙，自然质朴，有质感",
    "，身穿浅苔绿宽松西装，清新有型，气质独特",
  ],
  金: [
    "，身穿奶油白廓形西装，简约极致，高级感强",
    "，身穿冰灰色针织高领毛衣，极简利落",
    "，身穿珍珠白宽松衬衫裙，清透干净，线条流畅",
    "，身穿浅蓝色宽版牛仔外套，搭配白T，清爽随性",
    "，身穿米白色束腰风衣，优雅利落，都市感十足",
  ],
  水: [
    "，身穿深海军蓝oversize针织毛衣，气质深邃，宽松有型",
    "，身穿烟紫色针织开衫，神秘文艺，柔软有垂感",
    "，身穿炭灰色廓形大衣，极简高冷，气场凌人",
    "，身穿深靛蓝工装风夹克，内搭黑色打底，硬朗利落",
    "，身穿墨绿色廓形西装，深邃有个性，存在感强",
  ],
  土: [
    "，身穿驼色宽松羊绒大衣，温暖高级，质感满分",
    "，身穿焦糖棕皮质外套，复古街头，有辨识度",
    "，身穿奶咖色oversize针织毛衣，温柔慵懒，触感柔软",
    "，身穿赤土色宽松衬衫裙，质朴自然，有生活气息",
    "，身穿深棕色oversize羊毛开衫，大地系，踏实温暖",
  ],
};

const maleElementClothingPool: Record<string, string[]> = {
  火: [
    "，身穿砖红色oversized卫衣，搭配黑色直筒裤，街头有分量",
    "，身穿酒红色宽松针织毛衣，慵懒有型，低调饱和度",
    "，身穿深红色绒面立领外套，色彩沉稳，有冲击力",
    "，身穿暗橘棕色灯芯绒衬衫，秋冬质感，温暖有活力",
    "，身穿砖红色棒球夹克，复古运动感，轮廓干净",
  ],
  木: [
    "，身穿卡其色灯芯绒外套，休闲有质感，文艺气息",
    "，身穿深绿色军旅风夹克，硬朗有生命力",
    "，身穿青橄榄色oversized卫衣，街头自然风",
    "，身穿米绿色麻料宽松衬衫，慢生活气质",
    "，身穿橄榄绿工装外套，内搭白T，户外实用感",
  ],
  金: [
    "，身穿冰灰色短款廓形夹克，线条利落，结构感强",
    "，身穿淡蓝色宽版牛仔外套，复古清爽",
    "，身穿珍珠白宽松衬衫，简约高级感",
    "，身穿浅银灰高领针织衫，极简时髦",
    "，身穿白色斜纹布休闲西装，建筑感廓形，干净有型",
  ],
  水: [
    "，身穿深海蓝oversized毛衣，宽松垂坠，气质深邃",
    "，身穿烟紫色针织开衫，柔软有垂感，文艺气质",
    "，身穿深靛蓝工装夹克，内搭白T，硬朗利落",
    "，身穿炭灰色宽松西装，搭配黑色内搭，极简高冷",
    "，身穿深蓝色绒面衬衫，有光泽感，神秘内敛",
  ],
  土: [
    "，身穿驼色宽松羊绒大衣，温暖有分量，沉稳感强",
    "，身穿焦糖棕皮夹克，复古街头感，轮廓硬朗",
    "，身穿赤陶色灯芯绒衬衫，厚实有手作感",
    "，身穿深棕色oversized卫衣，大地系配色，踏实自然",
    "，身穿小麦色粗织针织衫，温度感十足，质朴有力",
  ],
};

const femaleGeneralPool: string[] = [
  "，身穿黑色皮夹克内搭白色基础T恤，帅气不失女人味",
  "，身穿深格纹宽松西装外套，内搭黑色打底，复古摩登",
  "，身穿浅灰色oversize连帽卫衣，街头休闲，舒适随性",
  "，身穿藏青色针织连衣裙，简洁大方，知性气质",
  "，身穿深紫色圆领针织毛衣，低调独特，气质沉稳",
  "，身穿勃艮第色宽松衬衫，成熟温柔，不张扬的美",
  "，身穿橄榄绿MA-1飞行夹克，复古实用，帅感十足",
  "，身穿烟蓝色水洗牛仔衬衫裙，随性自由，文艺感",
  "，身穿棕褐色灯芯绒衬衫裙，复古质感，接地气",
  "，身穿深墨绿色针织连衣裙，有设计感，气场沉稳",
  "，身穿米色宽松针织开衫，搭配黑色打底，慵懒百搭",
  "，身穿烟灰色廓形大衣，内搭深色毛衣，极简高级",
];

const maleGeneralPool: string[] = [
  "，身穿黑色皮衣内搭纯白T恤，叛逆利落",
  "，身穿格纹法兰绒衬衫外搭深色牛仔夹克，复古美式",
  "，身穿浅灰色oversized连帽卫衣，街头休闲",
  "，身穿藏青色细条纹休闲西装内搭黑色圆领，现代绅士",
  "，身穿深紫色针织圆领毛衣，低调独特",
  "，身穿勃艮第酒红圆领毛衣，成熟稳重",
  "，身穿橄榄绿MA-1飞行夹克，复古实用",
  "，身穿烟蓝色水洗牛仔衬衫，随性自由",
  "，身穿棕褐色皮质衬衫外套，复古质感十足",
  "，身穿炭灰色oversize针织外套，低调有型",
  "，身穿烟灰色宽松西装，内搭黑色高领，极简高级",
  "，身穿深棕色麂皮夹克，内搭米白衬衫，复古绅士感",
];

function pickClothingStyle(xiYongShen: string, soulmateGender: string): string {
  const isFemale = soulmateGender === "女";
  const elementPool = isFemale
    ? (femaleElementClothingPool[xiYongShen] ?? [])
    : (maleElementClothingPool[xiYongShen] ?? []);
  const generalPool = isFemale ? femaleGeneralPool : maleGeneralPool;
  const combined = [...elementPool, ...generalPool];
  return combined[Math.floor(Math.random() * combined.length)];
}

// ────────────────────────────────────────────────────────────
// prompt 清洗（剥离 LLM 已生成的发型/服饰，防止两件衣服问题）
// ────────────────────────────────────────────────────────────
function stripClothingFromPrompt(prompt: string): string {
  return prompt
    .replace(/[，,]\s*身穿[^，,。；;\n]*/g, "")
    .replace(/[，,]\s*穿着[^，,。；;\n]*/g, "")
    .replace(/[，,]\s*穿[一]?件[^，,。；;\n]*/g, "")
    .replace(/[，,]\s*着[^\s，,。]{0,6}(衬衫|毛衣|外套|夹克|卫衣|风衣|大衣|皮衣|T恤|上衣|连衣裙|半裙|开衫)[^，,。；;\n]*/g, "")
    .replace(/，\s*，/g, "，")
    .replace(/^，/, "")
    .trim();
}

function stripHairFromPrompt(prompt: string): string {
  return prompt
    .replace(/[，,]\s*[^\s，,。；;\n]{0,8}(短发|长发|中长发|卷发|直发|bob头|丸子头|马尾|刘海|发型|发丝|发梢)[^，,。；;\n]*/g, "")
    .replace(/[，,]\s*(黑色|深棕色|棕色|深色|浅色|乌黑)[^\s，,。]{0,4}(发|头发)[^，,。；;\n]*/g, "")
    .replace(/，\s*，/g, "，")
    .replace(/^，/, "")
    .trim();
}

const FACE_FIX_SUFFIX =
  "，亚洲面孔特征，深色虹膜，双眼皮自然，眼睛有神，皮肤质感真实，自然电影光";

// ────────────────────────────────────────────────────────────
// CORS headers
// ────────────────────────────────────────────────────────────
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// ────────────────────────────────────────────────────────────
// Edge Function Entry Point
// ────────────────────────────────────────────────────────────
Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── JWT 验证 ──────────────────────────────────────────────
  const jwt = req.headers.get("Authorization")?.replace("Bearer ", "");
  if (!jwt) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabaseAdmin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { data: { user }, error: authErr } = await supabaseAdmin.auth.getUser(jwt);
  if (!user || authErr) {
    console.error("[web-analyze] JWT validation failed:", authErr);
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── API 密钥 ──────────────────────────────────────────────
  const apiKey = Deno.env.get("ALIYUN_BAILIAN_API_KEY");
  if (!apiKey) {
    console.error("[web-analyze] ALIYUN_BAILIAN_API_KEY not set");
    return new Response(JSON.stringify({ error: "API key not configured" }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // ── 解析请求体 ────────────────────────────────────────────
  let reqBody: {
    birthDate: string;
    birthTime: string;
    birthPlace: string;
    gender: string;
  };
  try {
    reqBody = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { birthDate, birthTime, birthPlace, gender } = reqBody;
  if (!birthDate || !gender) {
    return new Response(
      JSON.stringify({ error: "birthDate and gender are required" }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }

  console.log(
    `[web-analyze] 开始分析 birthDate=${birthDate} birthTime=${birthTime} birthPlace=${birthPlace} gender=${gender} userId=${user.id}`
  );

  // ── 解析日期 ──────────────────────────────────────────────
  const dateMatch = birthDate.match(/(\d{4})年(\d{1,2})月(\d{1,2})日/);
  if (!dateMatch) {
    return new Response(
      JSON.stringify({ error: "birthDate 格式错误，应为 1990年5月15日" }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
  const [, yearStr, monthStr, dayStr] = dateMatch;
  const birthYear = parseInt(yearStr);
  const birthMonth = parseInt(monthStr);
  const birthDay = parseInt(dayStr);

  // ── 八字计算 ─────────────────────────────────────────────
  const effectiveBirthTime = birthTime || "未知";
  const effectiveBirthPlace = birthPlace || "";

  const bazi = calculateBaZi(
    birthYear, birthMonth, birthDay,
    effectiveBirthTime, effectiveBirthPlace, gender
  );

  const soulmateGender = gender === "男" ? "女" : "男";

  // ── 构建消息 ──────────────────────────────────────────────
  let userMessage: string;
  let targetAge: number | null = null;
  let xiYongShen = "";

  if (bazi) {
    userMessage = buildUserMessage(bazi, gender, birthDate, effectiveBirthPlace);
    targetAge = bazi.targetAge;
    xiYongShen = bazi.xiYongShen;
    console.log(
      `[web-analyze] 八字计算成功: ${bazi.elementSummary}, 喜用神=${bazi.xiYongShen}, targetAge=${bazi.targetAge}`
    );
  } else {
    // 八字计算失败，降级到简化消息
    console.warn("[web-analyze] 八字计算失败，使用降级消息");
    const pronounHeShe = gender === "男" ? "她" : "他";
    userMessage = `请根据以下信息分析这个人的性格特质，并推导出最适合的伴侣类型：

用户信息：${gender}性，${birthDate} ${effectiveBirthTime}生，现居${effectiveBirthPlace}

伴侣必须是${soulmateGender}性，全文用"${pronounHeShe}"称呼。`;
  }

  // ── 调用阿里云百炼 ────────────────────────────────────────
  const chatRequestBody = {
    model: ALIYUN_MODEL,
    messages: [
      { role: "system", content: SOUL_ANALYSIS_SYSTEM_PROMPT },
      { role: "user", content: userMessage },
    ],
    response_format: { type: "json_object" },
    temperature: 0.95,
  };

  console.log("[web-analyze] 发送 LLM 请求...");

  let upstream: Response;
  try {
    upstream = await fetch(ALIYUN_API_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(chatRequestBody),
    });
  } catch (e) {
    console.error("[web-analyze] fetch to Aliyun failed:", e);
    return new Response(JSON.stringify({ error: "upstream_fetch_failed" }), {
      status: 502,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  console.log(`[web-analyze] LLM 响应状态: ${upstream.status}`);

  if (upstream.status !== 200) {
    const errorText = await upstream.text();
    console.error(`[web-analyze] LLM 错误 ${upstream.status}:`, errorText);
    const clientStatus =
      upstream.status === 401 || upstream.status === 403 ? 502 : upstream.status;
    return new Response(
      JSON.stringify({
        error: "upstream_error",
        upstream_status: upstream.status,
        detail: errorText,
      }),
      {
        status: clientStatus,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }

  // ── 解析 LLM 响应 ─────────────────────────────────────────
  let upstreamJson: Record<string, unknown>;
  try {
    upstreamJson = await upstream.json();
  } catch {
    return new Response(
      JSON.stringify({ error: "Failed to parse upstream response" }),
      {
        status: 502,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }

  // ── 提取 image_prompt → 丰化 → 存入 prompt_tokens ────────
  try {
    const choices = upstreamJson["choices"] as
      | Array<Record<string, unknown>>
      | undefined;
    const messageObj = choices?.[0]?.["message"] as
      | Record<string, unknown>
      | undefined;
    const rawContent = messageObj?.["content"] as string | undefined;

    if (rawContent) {
      const content = JSON.parse(rawContent) as Record<string, unknown>;
      const rawPrompt = content["image_prompt"] as string | undefined;

      if (rawPrompt) {
        // 剥离 LLM 已生成的发型/服饰，追加随机发型 + 五行服饰 + 面部修正
        const stripped = stripHairFromPrompt(stripClothingFromPrompt(rawPrompt));
        const hairSuffix = pickHairStyle(soulmateGender);
        const clothingSuffix = pickClothingStyle(xiYongShen, soulmateGender);
        const enrichedPrompt = stripped + hairSuffix + clothingSuffix + FACE_FIX_SUFFIX;

        console.log(
          `[web-analyze] 发型: ${hairSuffix.slice(0, 20)}... 服饰: ${clothingSuffix.slice(0, 20)}...`
        );

        const { data: token, error: insertError } = await supabaseAdmin
          .from("prompt_tokens")
          .insert({
            user_id: user.id,
            raw_prompt: enrichedPrompt,
            target_age: targetAge,
            xi_yong_shen: xiYongShen,
          })
          .select("id")
          .single();

        if (token && !insertError) {
          // 用 promptToken 替换 image_prompt
          delete content["image_prompt"];
          content["promptToken"] = token.id;
          (choices![0]["message"] as Record<string, unknown>)["content"] =
            JSON.stringify(content);
          console.log(`[web-analyze] prompt_token 已创建: ${token.id}`);
        } else {
          console.error("[web-analyze] 插入 prompt_token 失败:", insertError);
          // 降级：保留 image_prompt（不安全但不阻断流程）
        }
      }
    }
  } catch (e) {
    console.error("[web-analyze] prompt token 处理异常:", e);
    // 降级保底：仍返回原始 LLM 响应
  }

  return new Response(JSON.stringify(upstreamJson), {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "Connection": "keep-alive",
    },
  });
});
