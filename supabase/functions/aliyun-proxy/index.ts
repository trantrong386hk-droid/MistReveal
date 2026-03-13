import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ============================================================
// aliyun-proxy — 阿里云百炼 LLM 透明代理（Prompt Token 模式）
// 客户端发送与阿里云 /chat/completions 相同的请求体，
// 并额外附加 target_age / xi_yong_shen / soulmate_gender 字段。
// 本函数：
//   1. 剥离额外字段，将纯 Aliyun 请求体转发
//   2. 解析响应，提取 image_prompt
//   3. 将 image_prompt 存入 prompt_tokens 表
//   4. 用 promptToken (UUID) 替代 image_prompt 返回给客户端
// 密钥仅存在于 Deno 环境变量，客户端永不可见。
// ============================================================

const ALIYUN_API_URL = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions";

// ============================================================
// 女性发型池 — 长/中长/及肩 多样化，避免千篇一律短发
// ============================================================

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

// 男性发型池（保留自然短到中长范围）
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

// ============================================================
// 女性服饰风格池 — 按五行分组，现代时髦，色调克制有设计感
// ============================================================

const femaleElementClothingPool: Record<string, string[]> = {
  "火": [
    "，身穿砖红色oversize针织毛衣，搭配米白宽腿裤，慵懒有质感",
    "，身穿赤陶色灯芯绒外套，内搭奶白色上衣，温暖有层次",
    "，身穿深玫红色廓形大衣，低调成熟有气场",
    "，身穿暗砖红色毛衣裙，腰间系细皮带，复古温柔",
    "，身穿樱桃棕色针织开衫，搭配同色系半裙，温柔不甜腻",
  ],
  "木": [
    "，身穿苔绿色oversize亚麻衬衫，随性自然，清新利落",
    "，身穿橄榄绿廓形夹克，内搭米白T恤，户外活力感",
    "，身穿深橄榄绿针织开衫，慵懒文艺，有生命力",
    "，身穿卡其棕灯芯绒衬衫裙，自然质朴，有质感",
    "，身穿浅苔绿宽松西装，清新有型，气质独特",
  ],
  "金": [
    "，身穿奶油白廓形西装，简约极致，高级感强",
    "，身穿冰灰色针织高领毛衣，极简利落",
    "，身穿珍珠白宽松衬衫裙，清透干净，线条流畅",
    "，身穿浅蓝色宽版牛仔外套，搭配白T，清爽随性",
    "，身穿米白色束腰风衣，优雅利落，都市感十足",
  ],
  "水": [
    "，身穿深海军蓝oversize针织毛衣，气质深邃，宽松有型",
    "，身穿烟紫色针织开衫，神秘文艺，柔软有垂感",
    "，身穿炭灰色廓形大衣，极简高冷，气场凌人",
    "，身穿深靛蓝工装风夹克，内搭黑色打底，硬朗利落",
    "，身穿墨绿色廓形西装，深邃有个性，存在感强",
  ],
  "土": [
    "，身穿驼色宽松羊绒大衣，温暖高级，质感满分",
    "，身穿焦糖棕皮质外套，复古街头，有辨识度",
    "，身穿奶咖色oversize针织毛衣，温柔慵懒，触感柔软",
    "，身穿赤土色宽松衬衫裙，质朴自然，有生活气息",
    "，身穿深棕色oversize羊毛开衫，大地系，踏实温暖",
  ],
};

// ============================================================
// 男性服饰风格池 — 按五行分组，街头/复古/极简/文艺
// ============================================================

const maleElementClothingPool: Record<string, string[]> = {
  "火": [
    "，身穿砖红色oversized卫衣，搭配黑色直筒裤，街头有分量",
    "，身穿酒红色宽松针织毛衣，慵懒有型，低调饱和度",
    "，身穿深红色绒面立领外套，色彩沉稳，有冲击力",
    "，身穿暗橘棕色灯芯绒衬衫，秋冬质感，温暖有活力",
    "，身穿砖红色棒球夹克，复古运动感，轮廓干净",
  ],
  "木": [
    "，身穿卡其色灯芯绒外套，休闲有质感，文艺气息",
    "，身穿深绿色军旅风夹克，硬朗有生命力",
    "，身穿青橄榄色oversized卫衣，街头自然风",
    "，身穿米绿色麻料宽松衬衫，慢生活气质",
    "，身穿橄榄绿工装外套，内搭白T，户外实用感",
  ],
  "金": [
    "，身穿冰灰色短款廓形夹克，线条利落，结构感强",
    "，身穿淡蓝色宽版牛仔外套，复古清爽",
    "，身穿珍珠白宽松衬衫，简约高级感",
    "，身穿浅银灰高领针织衫，极简时髦",
    "，身穿白色斜纹布休闲西装，建筑感廓形，干净有型",
  ],
  "水": [
    "，身穿深海蓝oversized毛衣，宽松垂坠，气质深邃",
    "，身穿烟紫色针织开衫，柔软有垂感，文艺气质",
    "，身穿深靛蓝工装夹克，内搭白T，硬朗利落",
    "，身穿炭灰色宽松西装，搭配黑色内搭，极简高冷",
    "，身穿深蓝色绒面衬衫，有光泽感，神秘内敛",
  ],
  "土": [
    "，身穿驼色宽松羊绒大衣，温暖有分量，沉稳感强",
    "，身穿焦糖棕皮夹克，复古街头感，轮廓硬朗",
    "，身穿赤陶色灯芯绒衬衫，厚实有手作感",
    "，身穿深棕色oversized卫衣，大地系配色，踏实自然",
    "，身穿小麦色粗织针织衫，温度感十足，质朴有力",
  ],
};

// ============================================================
// 通用服饰池（兜底，不受五行限制），色调克制，设计感优先
// ============================================================

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

/**
 * 从 LLM 生成的 prompt 中剥离服饰描述，避免与追加的服饰冲突产生"两件衣服"问题。
 */
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

/**
 * 从 LLM 生成的 prompt 中剥离发型描述，统一由发型池覆盖，确保多样性。
 */
function stripHairFromPrompt(prompt: string): string {
  return prompt
    // 匹配「，*发（短发/长发/中长发/波浪卷发/bob头 etc.）」
    .replace(/[，,]\s*[^\s，,。；;\n]{0,8}(短发|长发|中长发|卷发|直发|bob头|丸子头|马尾|刘海|发型|发丝|发梢)[^，,。；;\n]*/g, "")
    // 匹配「，黑色/深色/棕色 + 发xxx」句式
    .replace(/[，,]\s*(黑色|深棕色|棕色|深色|浅色|乌黑)[^\s，,。]{0,4}(发|头发)[^，,。；;\n]*/g, "")
    .replace(/，\s*，/g, "，")
    .replace(/^，/, "")
    .trim();
}

// 眼睛与面部修正后缀 — 确保自然亚洲人特征，避免 AI 生成异色眼/发光眼
const FACE_FIX_SUFFIX = "，亚洲面孔特征，深色虹膜，双眼皮自然，眼睛有神，皮肤质感真实，自然电影光";

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  // 手动 JWT 验证（替代 verify_jwt=true，支持 ES256）
  const jwt = req.headers.get("Authorization")?.replace("Bearer ", "");
  if (!jwt) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401, headers: { "Content-Type": "application/json" }
    });
  }
  const supabaseAdmin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );
  const { data: { user }, error: authErr } = await supabaseAdmin.auth.getUser(jwt);
  if (!user || authErr) {
    console.error("[aliyun-proxy] JWT validation failed:", authErr);
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401, headers: { "Content-Type": "application/json" }
    });
  }

  const apiKey = Deno.env.get("ALIYUN_BAILIAN_API_KEY");
  if (!apiKey) {
    console.error("ALIYUN_BAILIAN_API_KEY is not set");
    return new Response(JSON.stringify({ error: "API key not configured" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Invalid JSON body" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  // 提取附加字段（不属于 Aliyun API 的部分）
  const targetAge = (body["target_age"] as number | null) ?? null;
  const xiYongShen = (body["xi_yong_shen"] as string) ?? "";
  const soulmateGender = (body["soulmate_gender"] as string) ?? "";

  // 剥离附加字段，只转发 Aliyun 标准字段
  const aliyunBody = { ...body };
  delete aliyunBody["target_age"];
  delete aliyunBody["xi_yong_shen"];
  delete aliyunBody["soulmate_gender"];

  console.log(`[aliyun-proxy] Forwarding request to Aliyun Bailian, soulmateGender=${soulmateGender}`);

  const upstream = await fetch(ALIYUN_API_URL, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(aliyunBody),
  });

  console.log(`[aliyun-proxy] Upstream status: ${upstream.status}`);

  if (upstream.status !== 200) {
    const errorText = await upstream.text();
    console.error(`[aliyun-proxy] Upstream error ${upstream.status}:`, errorText);
    const clientStatus = upstream.status === 401 || upstream.status === 403 ? 502 : upstream.status;
    return new Response(
      JSON.stringify({ error: "upstream_error", upstream_status: upstream.status, detail: errorText }),
      {
        status: clientStatus,
        headers: { "Content-Type": "application/json" },
      }
    );
  }

  // 解析上游响应
  let upstreamJson: Record<string, unknown>;
  try {
    upstreamJson = await upstream.json();
  } catch {
    return new Response(JSON.stringify({ error: "Failed to parse upstream response" }), {
      status: 502,
      headers: { "Content-Type": "application/json" },
    });
  }

  // 尝试提取 image_prompt 并存入 prompt_tokens
  try {
    const choices = upstreamJson["choices"] as Array<Record<string, unknown>> | undefined;
    const contentStr = choices?.[0]?.["message"] as Record<string, unknown> | undefined;
    const rawContent = contentStr?.["content"] as string | undefined;

    if (rawContent) {
      const content = JSON.parse(rawContent) as Record<string, unknown>;
      const rawPrompt = content["image_prompt"] as string | undefined;

      if (rawPrompt) {
        // 剥离 LLM 已生成的发型和服饰描述，再追加我们的随机发型 + 统一服饰 + 面部修正
        const strippedPrompt = stripHairFromPrompt(stripClothingFromPrompt(rawPrompt));
        const hairSuffix = pickHairStyle(soulmateGender);
        const clothingSuffix = pickClothingStyle(xiYongShen, soulmateGender);
        const enrichedPrompt = strippedPrompt + hairSuffix + clothingSuffix + FACE_FIX_SUFFIX;

        console.log(`[aliyun-proxy] Hair: ${hairSuffix.slice(0, 20)}... Clothing: ${clothingSuffix.slice(0, 20)}...`);

        // 复用顶部已验证的 supabaseAdmin 和 user
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
          // 用 promptToken 替代 image_prompt
          delete content["image_prompt"];
          content["promptToken"] = token.id;

          // 更新响应内容
          (choices![0]["message"] as Record<string, unknown>)["content"] = JSON.stringify(content);
          console.log(`[aliyun-proxy] Prompt token created: ${token.id}`);
        } else {
          console.error("[aliyun-proxy] Failed to insert prompt_token:", insertError);
        }
      }
    }
  } catch (e) {
    console.error("[aliyun-proxy] Error processing prompt token:", e);
    // 即使 token 处理失败，仍返回原始响应（降级保底）
  }

  return new Response(JSON.stringify(upstreamJson), {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      "Connection": "keep-alive",
    },
  });
});
