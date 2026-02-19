import Foundation
import CryptoKit
import Supabase

/// 图片生成服务 - 使用火山引擎即梦 4.0 异步 API
class ImageGenerationService {

    static let shared = ImageGenerationService()
    private init() {}

    // MARK: - 配置（即梦 4.0）
    private let host = "visual.volcengineapi.com"
    private let submitAction = "CVSync2AsyncSubmitTask"
    private let getResultAction = "CVSync2AsyncGetResult"
    private let version = "2022-08-31"
    private let region = "cn-north-1"
    private let service = "cv"
    private let reqKey = "jimeng_t2i_v40"

    // 轮询配置
    private let maxPollAttempts = 60       // 最多轮询 60 次
    private let pollInterval: TimeInterval = 2.0  // 每 2 秒轮询一次

    // MARK: - 视觉调色盘映射（喜用神 → 光影 + 环境）

    struct VisualPalette {
        let lighting: String    // 光影描述
        let environment: String // 环境/背景
        let skinTone: String    // 肤色倾向
        let clothing: String    // 服饰色调
    }

    /// 单元素 → 视觉调色盘（氛围感受词，不指定具体颜色）
    func elementToPalette(_ element: String) -> VisualPalette {
        switch element {
        case "火":
            return VisualPalette(
                lighting: "暖调柔光，有温度的光晕",
                environment: "温暖的场景氛围",
                skinTone: "肌肤通透有光泽，散发健康温暖感",
                clothing: "暖调厚实的面料，有温度感"
            )
        case "木":
            return VisualPalette(
                lighting: "中性暖光，清爽通透的光感",
                environment: "室内或城市质感场景，背景干净克制",
                skinTone: "肌肤自然健康，透着活力光泽",
                clothing: "自然质朴的面料，有肌理感"
            )
        case "金":
            return VisualPalette(
                lighting: "清冽通透的光线",
                environment: "干净利落的场景",
                skinTone: "肌肤干净通透，骨相分明，有健康光泽",
                clothing: "利落剪裁，有结构感"
            )
        case "水":
            return VisualPalette(
                lighting: "朦胧柔光，沉静光感",
                environment: "安静深邃的场景",
                skinTone: "肌肤细致匀净，有清润健康光泽",
                clothing: "柔软有垂感，线条流畅"
            )
        case "土":
            return VisualPalette(
                lighting: "温厚的琥珀调光线",
                environment: "沉稳厚实的场景",
                skinTone: "健康暖色调肤色，质感温润",
                clothing: "敦实有分量的面料"
            )
        default:
            return VisualPalette(
                lighting: "柔和自然的光线，温暖而均衡",
                environment: "素净的背景，淡淡雾气增添层次与深度",
                skinTone: "自然健康的肤色，均匀透亮",
                clothing: "穿着自然色系的质感面料"
            )
        }
    }

    /// 复合元素 → 融合调色盘（双元素意境）
    func compositeElementPalette(primary: String, secondary: String) -> VisualPalette {
        let key = "\(primary)+\(secondary)"
        // 对称处理：木+火 和 火+木 使用相同意境
        let sortedKey: String
        let elements = [primary, secondary].sorted()
        sortedKey = "\(elements[0])+\(elements[1])"

        switch sortedKey {
        case "木+火":
            return VisualPalette(
                lighting: "清晨暖阳的光束，空气中漂浮着细碎光粒",
                environment: "温暖的户外场景，空气温润有野花芬芳",
                skinTone: "肌肤被阳光亲吻，健康有光泽，散发自然活力",
                clothing: "自然质感面料，带有手工编织的粗犷纹理，温暖而有生命力"
            )
        case "木+水":
            return VisualPalette(
                lighting: "朦胧的清晨光线，水珠折射出细碎光点",
                environment: "雨后清新的溪畔，晨雾笼罩，空气清凉湿润",
                skinTone: "肌肤清透水润，如雨后新荷般清新通透",
                clothing: "具有流动感的深色系面料，呈现晨露润湿树皮般的细腻光泽，温润且有生长力"
            )
        case "火+金":
            return VisualPalette(
                lighting: "落日余晖与冷调光面交汇，明暗对比强烈",
                environment: "暖光与冷调碰撞的戏剧性场景",
                skinTone: "肌肤在暖光中有光泽，冷调骨相被暖光柔化",
                clothing: "冷暖对撞的面料搭配，硬朗廓形中透着锋利的温度"
            )
        case "火+土":
            return VisualPalette(
                lighting: "炉火映照在墙面上的暖光，温厚而安心",
                environment: "壁炉旁的温暖空间，原木与暖石散发沉静温度",
                skinTone: "肌肤泛着温暖光泽，从内到外透着厚实温度",
                clothing: "手工编织感的厚实面料，温暖敦实，带有匠人质感"
            )
        case "土+金":
            return VisualPalette(
                lighting: "秋日暖光与冷冽空气交汇的光感",
                environment: "秋日旷野，空气沉稳而高贵",
                skinTone: "干净匀净中带暖调，骨相优雅分明",
                clothing: "高质感面料，沉稳中带着克制的贵气"
            )
        case "水+金":
            return VisualPalette(
                lighting: "清冽通透的柔光，静谧的光感",
                environment: "清冽纯净的通透场景，空气如水晶般干净",
                skinTone: "肌肤干净如瓷，有清润光泽，骨相锋利分明",
                clothing: "冷峻有质感的垂坠面料，线条利落如水"
            )
        case "水+火":
            return VisualPalette(
                lighting: "暖光与水雾交织，蒸汽将光线柔化成朦胧光晕",
                environment: "冷暖交融的氤氲场景",
                skinTone: "肌肤内透暖光，表面有冷调水润质感",
                clothing: "深色系面料，冷暖交织的沉郁质感"
            )
        case "土+水":
            return VisualPalette(
                lighting: "厚云偶透的暖光，沉稳而湿润",
                environment: "雨后泥土气息弥漫的场景，湿润空气中有暖意",
                skinTone: "温润肤质，带着雨后的清新水润感",
                clothing: "厚实面料，沉稳中透着润泽"
            )
        case "木+金":
            return VisualPalette(
                lighting: "深秋清冽光线，通透的空气感",
                environment: "深秋中肃穆与生机并存的场景",
                skinTone: "干净健康，自然有光泽，清爽有生机",
                clothing: "自然与利落并存的质感面料，有结构但不生硬"
            )
        case "木+土":
            return VisualPalette(
                lighting: "田园午后的暖光，空气中有花粉与泥土微粒",
                environment: "山间院落，泥土芬芳弥漫，午后安定的空气",
                skinTone: "阳光亲吻过的自然暖色调肌肤，厚实质感",
                clothing: "天然面料，质朴而接地气，有手作感"
            )
        default:
            // 无匹配的复合 → 回退到主元素
            return elementToPalette(primary)
        }
    }

    // MARK: - 十神人设映射（dominantGod → 外貌气质）

    /// 根据命局主导十神返回人物气质描述（纯表情/姿态/神态，不含颜色词和骨骼词）
    func shishenPersona(_ dominantGod: String) -> String {
        switch dominantGod {
        case "七杀":
            return "表情坚毅果断，眉宇间英气外露，眼神锐利有穿透力，姿态挺拔刚劲，浑身散发着不怒自威的气场"
        case "正官":
            return "表情从容端正，眉宇间舒展有度，眼神沉稳清澈，身姿挺拔但不紧绷，周身散发着从容儒雅的气场"
        case "正财":
            return "表情安稳真诚，笑容自然坦荡，眼神踏实笃定，体态放松可靠，散发着让人安心的沉稳气场"
        case "偏财":
            return "表情生动爽朗，笑容有感染力，眼神灵活明亮带着几分不羁，姿态轻松不拘束，周身散发着豪爽气场"
        case "食神":
            return "表情松弛舒展，眉眼之间自在放松，嘴角天然上扬，眼神柔和慵懒，体态放松自然，整个人散发着让人想靠近的气息"
        case "伤官":
            return "表情清冽不羁，眉眼锐利而有光彩，眼神中带着不服输的倔强与灵气，姿态有张力，气质桀骜中带着文艺感"
        case "正印":
            return "表情温和从容，眼神清澈而笃定，眉宇间舒展，体态从容优雅，周身散发着沉静的书卷气"
        case "偏印":
            return "表情沉思内敛，眼神深远有洞察力，神态独立疏离，体态清瘦有棱角，如不动声色的观察者"
        case "比肩":
            return "表情坦荡磊落，目光直视前方带着自信，姿态挺拔有力，整个人散发着无需证明的从容与笃定"
        case "劫财":
            return "表情锐利警觉，眼神如猎豹般专注，姿态矫健紧实，周身散发着蓄势待发的竞争力"
        default:
            return "五官端正自然，眉眼之间带着平和的力量，神态从容自信"
        }
    }

    /// 根据夫妻星类型返回骨骼体态约束（纯骨骼结构，不含表情/颜色）
    func spouseStarAppearance(_ spouseStarType: String?) -> String? {
        guard let star = spouseStarType else { return nil }
        switch star {
        case "七杀":
            return "骨架挺拔有力，轮廓清晰立体，下颌线转折分明，肩宽体健，身材匀称有肌肉线条"
        case "正官":
            return "五官端正比例协调，额头宽阔饱满，体格匀称挺拔有分量感，面部骨骼正直大气"
        case "正财":
            return "面部骨骼线条圆润柔和，体态匀称敦实健康，骨架给人安稳踏实的感觉"
        case "偏财":
            return "五官骨骼鲜明有辨识度，体态匀称灵活有张力，骨架轻盈不沉重"
        default:
            return nil
        }
    }

    // MARK: - 救赎光影

    /// 喜用神 → 救赎光影关键词（后处理阶段追加到 prompt 末尾）
    func redemptionLighting(_ xiYongShen: String) -> String {
        switch xiYongShen {
        case "火": return "，温暖的黄金时刻光线，柔和的辐射光晕"
        case "水": return "，柔和的漫射光线，沉静安宁的氛围"
        case "木": return "，柔和的中性暖光，清爽通透的氛围"
        case "金": return "，清冽通透的光线，干净精致的氛围"
        case "土": return "，温暖的琥珀色光线，沉稳踏实的氛围"
        default: return ""
        }
    }

    // MARK: - 随机服饰风格池（不受五行约束）

    /// 随机服饰风格关键词 —— 每次生成从池中随机选取，确保多样性
    private let clothingStylePool: [String] = [
        "，身穿深色圆领毛衣，简约质感",
        "，身穿白色衬衫，袖口自然，干净利落",
        "，身穿浅色亚麻衬衫，松弛自然",
        "，身穿黑色高领针织衫，简洁有型",
        "，身穿灰色休闲西装外套，内搭白T",
        "，身穿牛仔夹克，内搭素色T恤，休闲随性",
        "，身穿驼色风衣，质感挺括",
        "，身穿深蓝色polo衫，干净整洁",
        "，身穿条纹衬衫，文艺气质",
        "，身穿卡其色工装外套，有生活感",
        "，身穿黑色皮夹克，内搭简约",
        "，身穿米白色针织开衫，温柔随意",
        "，身穿藏青色套头卫衣，舒适日常",
        "，身穿格纹衬衫外套，复古文艺",
        "，身穿浅灰色羊毛大衣，气质沉稳",
        "，身穿橄榄绿棉质外套，户外休闲感",
        "，身穿暗红色圆领毛衣，低调温暖",
        "，身穿白色T恤外搭深色开衫，轻松自在",
    ]

    func randomClothingStyle() -> String {
        clothingStylePool.randomElement() ?? "，穿着有质感的日常服饰"
    }

    // MARK: - Edge Function 后处理（服务端）

    /// 通过 Supabase Edge Function 执行提示词后处理
    /// 服务端逻辑与本地 appendPaletteAndPhoto() 一致，但可热更新
    private func enhancePromptViaEdgeFunction(rawPrompt: String, baziInfo: BaZiInfo?) async throws -> String {
        struct RequestBody: Encodable {
            let rawPrompt: String
            let targetAge: Int?
            let xiYongShen: String
        }
        struct ResponseBody: Decodable {
            let finalPrompt: String
        }

        let body = RequestBody(
            rawPrompt: rawPrompt,
            targetAge: baziInfo?.targetAge,
            xiYongShen: baziInfo?.xiYongShen ?? ""
        )

        let session = try await supabase.auth.session

        let response: ResponseBody = try await supabase.functions.invoke(
            "enhance-image-prompt",
            options: FunctionInvokeOptions(
                method: .post,
                headers: ["Authorization": "Bearer \(session.accessToken)"],
                body: body
            )
        )

        return response.finalPrompt
    }

    // MARK: - 后处理：年龄校准 + 清理 + 救赎光影 + 摄影后缀（本地 fallback）

    /// 后处理：年龄校准 + 清理冗余词 + 救赎光影 + 摄影后缀
    /// 十神人设和夫妻星骨相由 LLM 在原始 prompt 中融入，此处不重复追加
    private func appendPaletteAndPhoto(_ rawPrompt: String, baziInfo: BaZiInfo?) -> String {
        var prompt = rawPrompt

        // === 年龄校准 ===
        if let age = baziInfo?.targetAge {
            let beforeReplace = prompt
            if let regex = try? NSRegularExpression(pattern: "约?\\d{1,3}[\\-~到至]?\\d{0,3}岁[左右]?") {
                let range = NSRange(prompt.startIndex..., in: prompt)
                prompt = regex.stringByReplacingMatches(in: prompt, range: range, withTemplate: "\(age)岁")
            }
            if prompt != beforeReplace {
                print("🔵 [ImageGen] ✅ 年龄替换成功: → \(age)岁")
            } else {
                print("🔵 [ImageGen] ⚠️ 年龄正则未命中，尝试中文数字匹配...")
                if let cnRegex = try? NSRegularExpression(pattern: "[一二三四五六七八九十百零]+[多余]?岁[左右]?") {
                    let range = NSRange(prompt.startIndex..., in: prompt)
                    prompt = cnRegex.stringByReplacingMatches(in: prompt, range: range, withTemplate: "\(age)岁")
                }
            }
            print("🔵 [ImageGen] 年龄校准: 目标伴侣年龄 \(age)岁")
        } else {
            print("⚠️ [ImageGen] targetAge 为 nil，跳过年龄校准")
        }

        // === 清理 LLM prompt 中的摄影棚/纯色背景/相机参数 ===
        let cleanupPatterns = [
            "纯灰色背景", "灰色背景", "摄影棚灯光", "柔和摄影棚灯光", "纯色背景",
            "专业人像摄影", "纪实摄影风格", "8K画质", "高清细节",
            "艺术人像", "油画质感与摄影的融合", "油画质感", "灵魂光感",
            "电影级光影", "大师级构图"
        ]
        for pattern in cleanupPatterns {
            prompt = prompt.replacingOccurrences(of: pattern, with: "")
        }
        prompt = prompt.replacingOccurrences(of: "正面面向镜头", with: "微侧面，自然不经意的回眸")

        // 清理多余逗号和空格
        prompt = prompt.replacingOccurrences(of: "，，", with: "，")
        prompt = prompt.replacingOccurrences(of: ",,", with: ",")
        prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        // === 注入辨识度特征（稳定但多样化） ===
        let distinctFeatures = pickDistinctFeatures(seed: rawPrompt)
        if !distinctFeatures.isEmpty {
            prompt += "，\(distinctFeatures)"
        }

        // === 温度泄漏监控（如果上游三轴分离正确，此处不应触发） ===
        if let bazi = baziInfo, (bazi.xiYongShen == "木" || bazi.xiYongShen == "火") {
            let coldIndicators = ["清冷", "冷峻", "银灰", "冰冷", "银白"]
            for indicator in coldIndicators {
                if prompt.contains(indicator) {
                    print("⚠️ [ImageGen] 温度泄漏: \"\(indicator)\" (xiYongShen=\(bazi.xiYongShen))，需检查上游")
                }
            }
        }

        // === 救赎光影（根据喜用神追加对应光影关键词） ===
        if let bazi = baziInfo {
            prompt += redemptionLighting(bazi.xiYongShen)
            print("🔵 [ImageGen] 救赎光影: \(bazi.xiYongShen)")
        }

        // === 随机服饰风格后缀（不受五行约束，每次随机选取） ===
        let clothingStyleSuffix = randomClothingStyle()
        print("🔵 [ImageGen] 随机服饰风格: \(clothingStyleSuffix)")

        // === 通用摄影后缀（不含服饰风格词） ===
        let photoSuffix = "，自然光人像，浅景深虚化，色调真实克制，自然深棕色瞳孔，自然黑色或深棕色头发，发色必须是东亚人自然发色，人物清晰对焦背景虚化分离，健康温暖的肤色"

        let finalPrompt = prompt + clothingStyleSuffix + photoSuffix

        return finalPrompt
    }

    // MARK: - 去同质化：稳定特征注入

    /// 基于 prompt 的稳定特征选择，避免每次都同一张脸
    private func pickDistinctFeatures(seed: String) -> String {
        let faceShapes = ["脸型偏长", "鹅蛋脸偏窄", "方中带圆的脸型", "颧骨略高的脸型", "下颌线清晰的脸型"]
        let brows = ["眉形自然平直", "眉峰略有起伏", "眉形偏浓但整洁", "眉尾稍长", "眉距略窄"]
        let eyes = ["眼型偏狭长", "眼尾微上扬", "眼皮较薄", "眼睑层次清晰", "眼神沉稳而直视"]
        let nose = ["鼻梁挺直但不夸张", "鼻梁偏直略长", "鼻翼收敛", "鼻头圆润", "鼻梁与眉骨过渡自然"]
        let jaw = ["下颌线干净", "下巴偏窄", "下巴略圆", "下颌转折利落", "下颌角不外扩"]
        let contour = ["颧骨线条清晰但不过分突出", "面部轮廓柔和但有棱角", "面部轮廓立体但克制", "面部线条干净利落", "轮廓对比适中"]
        let skinDetail = ["肤质细腻自然", "肤质干净清透", "皮肤有自然光泽，不油不干", "肤质均匀柔和", "皮肤状态自然，光泽柔和"]
        let pose = [
            "平视镜头", "微低机位视角", "轻微侧脸转回", "肩部稍前倾", "姿态克制放松",
            "轻微抬下巴", "身体微侧但眼神回望", "头部轻微侧倾", "上半身微向前", "坐姿放松"
        ]

        var picks = stablePick(from: [
            faceShapes, brows, eyes, nose, jaw, contour, skinDetail, pose
        ], seed: seed)

        // 发型：根据性别随机选择（用 randomElement 而非 stablePick，确保每次生成有变化）
        let isFemale = seed.contains("女性") || seed.contains("女")
        let hairStyle: String
        if isFemale {
            let femaleHairStyles = [
                "黑色长直发自然垂落", "深棕色及肩中长发", "自然微卷长发",
                "锁骨发微微内扣", "低马尾扎起，碎发自然", "半扎发，余发披肩",
                "齐肩波波头", "侧分长发，发尾自然", "黑色大卷长发",
                "丸子头，碎发自然垂下", "耳后别发，露出侧脸线条",
                "中分长发，发丝柔顺", "偏分及腰长发", "松散编发搭在一侧",
            ]
            hairStyle = femaleHairStyles.randomElement() ?? "黑色长发自然垂落"
        } else {
            let maleHairStyles = [
                "短发干净利落", "寸头清爽", "侧分短发，纹理自然",
                "微长碎发，自然蓬松", "背头整洁有型", "短发微卷，自然不刻意",
            ]
            hairStyle = maleHairStyles.randomElement() ?? "短发干净利落"
        }
        picks.append(hairStyle)
        print("🔵 [ImageGen] 随机发型: \(hairStyle)")

        return picks.joined(separator: "，")
    }

    /// 稳定选择：对 seed 做 hash，从每个列表取一个
    private func stablePick(from groups: [[String]], seed: String) -> [String] {
        guard let data = seed.data(using: .utf8) else { return [] }
        let digest = SHA256.hash(data: data)
        let bytes = Array(digest)
        var result: [String] = []
        for (index, group) in groups.enumerated() {
            if group.isEmpty { continue }
            let byte = bytes[index % bytes.count]
            let pickIndex = Int(byte) % group.count
            result.append(group[pickIndex])
        }
        return result
    }

    // MARK: - 提示词后处理（旧版完整版，保留参考）

    /// 对 AI 返回的 image_prompt 进行灵魂感强化 + 八字视觉融合 + 年龄校准
    /// 融合四层视觉信息：1) 喜用神调色盘 2) 十神人设气质 3) 夫妻星骨相约束 4) 灵魂感关键词
    private func enhancePrompt(_ rawPrompt: String, baziInfo: BaZiInfo?) -> String {
        var prompt = rawPrompt

        // === 年龄校准 ===
        if let age = baziInfo?.targetAge {
            let beforeReplace = prompt
            if let regex = try? NSRegularExpression(pattern: "约?\\d{1,3}[\\-~到至]?\\d{0,3}岁[左右]?") {
                let range = NSRange(prompt.startIndex..., in: prompt)
                prompt = regex.stringByReplacingMatches(in: prompt, range: range, withTemplate: "\(age)岁")
            }
            if prompt != beforeReplace {
                print("🔵 [ImageGen] ✅ 年龄替换成功: → \(age)岁")
            } else {
                print("🔵 [ImageGen] ⚠️ 年龄正则未命中，尝试中文数字匹配...")
                if let cnRegex = try? NSRegularExpression(pattern: "[一二三四五六七八九十百零]+[多余]?岁[左右]?") {
                    let range = NSRange(prompt.startIndex..., in: prompt)
                    prompt = cnRegex.stringByReplacingMatches(in: prompt, range: range, withTemplate: "\(age)岁")
                }
            }
            print("🔵 [ImageGen] 年龄校准: 目标伴侣年龄 \(age)岁")
        } else {
            print("⚠️ [ImageGen] targetAge 为 nil，跳过年龄校准")
        }

        // === 清理 LLM prompt 中的摄影棚/纯色背景/相机参数 ===
        let cleanupPatterns = [
            "纯灰色背景", "灰色背景", "摄影棚灯光", "柔和摄影棚灯光", "纯色背景",
            "专业人像摄影", "纪实摄影风格", "8K画质", "高清细节",
            "艺术人像", "油画质感与摄影的融合", "油画质感", "灵魂光感",
            "电影级光影", "大师级构图"
        ]
        for pattern in cleanupPatterns {
            prompt = prompt.replacingOccurrences(of: pattern, with: "")
        }
        prompt = prompt.replacingOccurrences(of: "正面面向镜头", with: "微侧面，自然不经意的回眸")

        // 清理多余逗号和空格
        prompt = prompt.replacingOccurrences(of: "，，", with: "，")
        prompt = prompt.replacingOccurrences(of: ",,", with: ",")
        prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        // === 视觉调色盘（喜用神 + 复合元素） ===
        let palette: VisualPalette
        if let bazi = baziInfo {
            let primaryElement = bazi.xiYongShen
            let secondaryElement = detectSecondaryElement(bazi: bazi)

            if let secondary = secondaryElement, secondary != primaryElement {
                palette = compositeElementPalette(primary: primaryElement, secondary: secondary)
                print("🔵 [ImageGen] 复合调色盘: \(primaryElement)+\(secondary)")
            } else {
                palette = elementToPalette(primaryElement)
                print("🔵 [ImageGen] 单元素调色盘: \(primaryElement)")
            }
        } else {
            palette = elementToPalette("")
            print("🔵 [ImageGen] 无八字信息，使用中性调色盘")
        }

        // === 十神人设气质 ===
        let personaSuffix: String
        if let bazi = baziInfo {
            let persona = shishenPersona(bazi.dominantGod)
            personaSuffix = "，\(persona)"
            print("🔵 [ImageGen] 十神人设: \(bazi.dominantGod) → \(persona.prefix(50))...")
        } else {
            personaSuffix = ""
        }

        // === 夫妻星骨相约束 ===
        let spouseConstraint: String
        if let bazi = baziInfo, let constraint = spouseStarAppearance(bazi.spouseStarType) {
            spouseConstraint = "，\(constraint)"
            print("🔵 [ImageGen] 夫妻星约束: \(bazi.spouseStarType ?? "无") → \(constraint.prefix(50))...")
        } else {
            spouseConstraint = ""
            print("🔵 [ImageGen] 无夫妻星骨相约束")
        }

        // === 融合：LLM prompt + 十神人设 + 夫妻星约束 + 调色盘 + 灵魂感后缀 ===
        let visualSuffix = """
        ，\(palette.skinTone)，\
        \(palette.lighting)，\(palette.environment)
        """

        // 中文摄影后缀（取代旧的英文灵魂感后缀）
        let soulSuffix = "，电影感肖像，浅景深，肤质细节自然，色调自然克制，中性室内或城市背景"

        prompt += personaSuffix + spouseConstraint + visualSuffix + soulSuffix

        return prompt
    }

    /// 检测八字中的第二强元素（用于复合意境）
    /// 逻辑：从 strongElements 中找一个不等于喜用神的元素；
    ///       若无 strongElements，取五行得分第二高的元素（需 > 20 分才有意义）
    func detectSecondaryElement(bazi: BaZiInfo) -> String? {
        // 优先从 strongElements 中找
        for element in bazi.strongElements {
            if element != bazi.xiYongShen {
                return element
            }
        }

        // 回退：取五行得分第二高且 > 20 分的元素
        let scores: [(String, Double)] = [
            ("金", bazi.metalScore),
            ("木", bazi.woodScore),
            ("水", bazi.waterScore),
            ("火", bazi.fireScore),
            ("土", bazi.earthScore)
        ]
        let sorted = scores.sorted { $0.1 > $1.1 }

        // 找到非喜用神的最高分元素
        for (element, score) in sorted {
            if element != bazi.xiYongShen && score > 20.0 {
                return element
            }
        }

        return nil
    }

    // MARK: - 生成图片

    /// 生成伴侣画像
    /// - Parameters:
    ///   - prompt: AI 生成的原始 image_prompt
    ///   - baziInfo: 用户的八字信息（用于五行互补计算），可选
    func generateImage(prompt: String, baziInfo: BaZiInfo? = nil) async throws -> Data {
        print("🔵 [ImageGen] ========== 开始生成图片 (即梦 4.0) ==========")

        // 打印八字摘要
        if let bazi = baziInfo {
            print("🔵 [ImageGen] 用户五行: 金\(String(format: "%.1f", bazi.metalScore)) 木\(String(format: "%.1f", bazi.woodScore)) 水\(String(format: "%.1f", bazi.waterScore)) 火\(String(format: "%.1f", bazi.fireScore)) 土\(String(format: "%.1f", bazi.earthScore))")
            print("🔵 [ImageGen] 喜用神: \(bazi.xiYongShen) → 伴侣追加\(bazi.xiYongShen)系视觉能量")
            print("🔵 [ImageGen] 主导十神: \(bazi.dominantGod)")
            if let star = bazi.spouseStarType {
                print("🔵 [ImageGen] 夫妻星: \(star) → 骨相约束激活")
            }
            if let age = bazi.targetAge {
                print("🔵 [ImageGen] 伴侣目标年龄: \(age)岁 (喜\(bazi.agePreference ?? "default"))")
            }
        } else {
            print("🔵 [ImageGen] 无八字信息，使用中性色调")
        }

        // 后处理：优先走 Edge Function，失败时降级到本地逻辑
        let finalPrompt: String
        do {
            finalPrompt = try await enhancePromptViaEdgeFunction(rawPrompt: prompt, baziInfo: baziInfo)
            print("🔵 [ImageGen] ✅ Edge Function 后处理成功")
        } catch {
            print("⚠️ [ImageGen] Edge Function 失败，降级到本地: \(error)")
            finalPrompt = appendPaletteAndPhoto(prompt, baziInfo: baziInfo)
        }
        print("🔵 [ImageGen] LLM 原始 Prompt: \(prompt)")
        print("🔵 [ImageGen] 最终 Prompt: \(finalPrompt)")

        let safePrompt = sanitizePromptForPolicy(finalPrompt)
        if safePrompt != finalPrompt {
            print("🔵 [ImageGen] 风控清洗: 已对 prompt 做温和化处理")
        }

        let negativePrompt = "绿色头发，蓝色头发，紫色头发，银色头发，灰色头发，粉色头发，不自然的发色，头发泛绿，头发泛蓝，染发，动漫风格头发，绿色皮肤，蓝色皮肤，苍白灰暗的皮肤"
        let safeNegativePrompt = sanitizePromptForPolicy(negativePrompt)
        print("🔵 [ImageGen] 提交尝试 #1（保留原始人物与场景，不使用温和版替换）")
        do {
            return try await submitAndPollImage(prompt: safePrompt, negativePrompt: safeNegativePrompt)
        } catch ImageError.contentRisk {
            print("⚠️ [ImageGen] 命中内容审核，快速退出")
            throw ImageError.contentRisk
        }
    }

    private func submitAndPollImage(prompt: String, negativePrompt: String) async throws -> Data {
        let submitBody: [String: Any] = [
            "req_key": reqKey,
            "prompt": prompt,
            "negative_prompt": negativePrompt,
            "width": 864,
            "height": 1536,
            "return_url": true
        ]
        let submitData = try JSONSerialization.data(withJSONObject: submitBody, options: [])

        print("🔵 [ImageGen] 提交异步任务...")
        let submitRequest = try await buildRequest(action: submitAction, bodyData: submitData)
        let (submitResponseData, submitResponse) = try await URLSession.shared.data(for: submitRequest)
        let submitHttpResponse = submitResponse as! HTTPURLResponse

        print("🔵 [ImageGen] 提交响应状态码: \(submitHttpResponse.statusCode)")
        if let text = String(data: submitResponseData, encoding: .utf8) {
            print("🔵 [ImageGen] 提交响应: \(text.prefix(500))")
        }

        guard submitHttpResponse.statusCode == 200 else {
            let (code, message) = parseServerError(from: submitResponseData)
            if code == 50413 {
                print("⚠️ [ImageGen] 提交阶段命中内容审核 (50413): \(message)")
                throw ImageError.contentRisk
            }
            throw ImageError.api("提交任务失败: \(message)")
        }

        guard let submitJson = try JSONSerialization.jsonObject(with: submitResponseData) as? [String: Any] else {
            throw ImageError.api("提交响应格式错误")
        }

        let submitDataObj: [String: Any]?
        if let directData = submitJson["data"] as? [String: Any] {
            submitDataObj = directData
        } else if let result = submitJson["Result"] as? [String: Any],
                  let resultData = result["data"] as? [String: Any] {
            submitDataObj = resultData
        } else {
            submitDataObj = nil
        }

        guard let taskId = submitDataObj?["task_id"] as? String else {
            print("❌ [ImageGen] 无法获取 task_id，完整响应: \(String(data: submitResponseData, encoding: .utf8) ?? "")")
            throw ImageError.api("无法获取 task_id")
        }

        print("🔵 [ImageGen] 任务已提交，task_id: \(taskId)")

        for attempt in 1...maxPollAttempts {
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))

            let pollBody: [String: Any] = [
                "req_key": reqKey,
                "task_id": taskId
            ]
            let pollData = try JSONSerialization.data(withJSONObject: pollBody, options: [])
            let pollRequest = try await buildRequest(action: getResultAction, bodyData: pollData)
            let (pollResponseData, pollResponse) = try await URLSession.shared.data(for: pollRequest)
            let pollHttpResponse = pollResponse as! HTTPURLResponse

            guard pollHttpResponse.statusCode == 200 else {
                let (code, message) = parseServerError(from: pollResponseData)
                print("⚠️ [ImageGen] 轮询 #\(attempt) 状态码: \(pollHttpResponse.statusCode), body: \(message.prefix(500))")
                if code == 50413 {
                    print("⚠️ [ImageGen] 轮询阶段命中内容审核 (50413): \(message)")
                    throw ImageError.contentRisk
                }
                continue
            }

            guard let pollJson = try JSONSerialization.jsonObject(with: pollResponseData) as? [String: Any] else {
                continue
            }

            let pollDataObj: [String: Any]?
            if let directData = pollJson["data"] as? [String: Any] {
                pollDataObj = directData
            } else if let result = pollJson["Result"] as? [String: Any],
                      let resultData = result["data"] as? [String: Any] {
                pollDataObj = resultData
            } else {
                pollDataObj = nil
            }

            guard let dataObj = pollDataObj,
                  let status = dataObj["status"] as? String else {
                print("⚠️ [ImageGen] 轮询 #\(attempt) 无法解析状态")
                continue
            }

            print("🔵 [ImageGen] 轮询 #\(attempt): status=\(status)")

            switch status {
            case "done":
                if let imageUrls = dataObj["image_urls"] as? [String],
                   let firstUrlStr = imageUrls.first,
                   let imageUrl = URL(string: firstUrlStr) {
                    print("🔵 [ImageGen] 图片URL: \(firstUrlStr)")
                    let (imageData, _) = try await URLSession.shared.data(from: imageUrl)
                    print("✅ [ImageGen] 图片下载成功: \(imageData.count) bytes")
                    return imageData
                }
                if let base64Array = dataObj["binary_data_base64"] as? [String],
                   let firstBase64 = base64Array.first,
                   let imageData = Data(base64Encoded: firstBase64) {
                    print("✅ [ImageGen] Base64 图片解码成功: \(imageData.count) bytes")
                    return imageData
                }
                print("❌ [ImageGen] 任务完成但无图片数据")
                throw ImageError.noImage

            case "failed":
                let errorMsg = (dataObj["resp_data"] as? String)
                    ?? (dataObj["error"] as? String)
                    ?? "生成失败"
                print("❌ [ImageGen] 任务失败: \(errorMsg)")
                throw ImageError.api("生成失败: \(errorMsg)")

            default:
                break
            }
        }

        print("❌ [ImageGen] 轮询超时，已尝试 \(maxPollAttempts) 次")
        throw ImageError.api("生成超时，请稍后再试")
    }

    private func parseServerError(from data: Data) -> (Int?, String) {
        let rawText = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (nil, rawText)
        }
        let code = json["code"] as? Int
        let message = (json["message"] as? String) ?? rawText
        return (code, message)
    }

    private func sanitizePromptForPolicy(_ text: String) -> String {
        let replacements: [(String, String)] = [
            ("blood", "red stain"),
            ("bloody", "stained"),
            ("gore", ""),
            ("gory", ""),
            ("corpse", "person"),
            ("dead body", "person"),
            ("kill", "defeat"),
            ("murder", "conflict"),
            ("suicide", "despair"),
            ("self-harm", "distress"),
            ("nudity", "portrait"),
            ("nude", "portrait"),
            ("sexual", "romantic"),
            ("explicit", "detailed"),
            ("血腥", ""),
            ("流血", ""),
            ("尸体", "人物"),
            ("杀人", "冲突"),
            ("自杀", "绝望"),
            ("裸露", "肖像"),
            ("色情", "浪漫"),
            ("微米级皮肤纹理", "肤质细节自然"),
            ("纳米级皮肤纹理", "肤质细节自然"),
            ("无滤镜真实感", "自然人像风格"),
            ("真实质感人像", "自然人像风格"),
            ("真实感人像", "自然人像风格"),
            ("毛孔细微可见", "肤质细腻自然"),
            ("细纹轻微可见", "肤质细节自然"),
            ("佳能人像色调", "自然人像色调"),
            ("sharp focus", "clear portrait"),
            ("blurred background separation", "soft background"),
            ("East Asian hair color", "natural hair color")
        ]

        var sanitized = text
        for (source, target) in replacements {
            sanitized = sanitized.replacingOccurrences(of: source, with: target, options: .caseInsensitive)
        }

        let compact = sanitized
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return compact
    }

    // MARK: - 构建签名请求
    private func buildRequest(action: String, bodyData: Data) async throws -> URLRequest {
        // ===== 从 SecretsManager 获取凭证 =====
        guard let ak = await SecretsManager.shared.getSecret("VOLCANO_ACCESS_KEY_ID") else {
            throw ImageError.api("无法获取 Access Key ID")
        }
        guard let sk = await SecretsManager.shared.getSecret("VOLCANO_SECRET_ACCESS_KEY") else {
            throw ImageError.api("无法获取 Secret Access Key")
        }

        // ===== 时间 (UTC) =====
        let now = Date()
        let fmt = DateFormatter()
        fmt.timeZone = TimeZone(identifier: "UTC")
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let xDate = fmt.string(from: now)
        fmt.dateFormat = "yyyyMMdd"
        let dateStamp = fmt.string(from: now)

        // ===== URL =====
        let urlString = "https://\(host)/?Action=\(action)&Version=\(version)"
        guard let url = URL(string: urlString) else {
            throw ImageError.invalidURL
        }

        // ===== Body Hash =====
        let bodyHash = sha256Hex(bodyData)

        // ===== Step 1: Canonical Request =====
        let httpMethod = "POST"
        let canonicalUri = "/"
        let canonicalQueryString = "Action=\(action)&Version=\(version)"
        let contentType = "application/json"

        let canonicalHeaders = "content-type:\(contentType)\nhost:\(host)\nx-content-sha256:\(bodyHash)\nx-date:\(xDate)\n"
        let signedHeaders = "content-type;host;x-content-sha256;x-date"

        let canonicalRequest = "\(httpMethod)\n\(canonicalUri)\n\(canonicalQueryString)\n\(canonicalHeaders)\n\(signedHeaders)\n\(bodyHash)"

        // ===== Step 2: String to Sign =====
        let algorithm = "HMAC-SHA256"
        let credentialScope = "\(dateStamp)/\(region)/\(service)/request"
        let hashedCanonicalRequest = sha256Hex(canonicalRequest.data(using: String.Encoding.utf8)!)

        let stringToSign = "\(algorithm)\n\(xDate)\n\(credentialScope)\n\(hashedCanonicalRequest)"

        // ===== Step 3: 派生签名密钥 =====
        let skData: Data = sk.data(using: String.Encoding.utf8)!
        let dateStampData: Data = dateStamp.data(using: String.Encoding.utf8)!
        let regionData: Data = region.data(using: String.Encoding.utf8)!
        let serviceData: Data = service.data(using: String.Encoding.utf8)!
        let requestData: Data = "request".data(using: String.Encoding.utf8)!

        let kDate = hmacSHA256(key: skData, data: dateStampData)
        let kRegion = hmacSHA256(key: kDate, data: regionData)
        let kService = hmacSHA256(key: kRegion, data: serviceData)
        let kSigning = hmacSHA256(key: kService, data: requestData)

        // ===== Step 4: 计算签名 =====
        let stringToSignData: Data = stringToSign.data(using: String.Encoding.utf8)!
        let signatureData = hmacSHA256(key: kSigning, data: stringToSignData)
        let signature = signatureData.map { String(format: "%02x", $0) }.joined()

        // ===== Step 5: Authorization Header =====
        let authorization = "\(algorithm) Credential=\(ak)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"

        // ===== 构建 URLRequest =====
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.httpBody = bodyData
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue(xDate, forHTTPHeaderField: "X-Date")
        request.setValue(bodyHash, forHTTPHeaderField: "X-Content-Sha256")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        return request
    }

    // MARK: - SHA256 (返回小写十六进制)
    private func sha256Hex(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - HMAC-SHA256 (返回 Data)
    private func hmacSHA256(key: Data, data: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
        return Data(mac)
    }

    // MARK: - 错误
    enum ImageError: LocalizedError {
        case invalidURL, noImage, timeout, contentRisk, api(String)
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "无效URL"
            case .noImage: return "无图片数据"
            case .timeout: return "生成超时，请稍后再试"
            case .contentRisk: return "图片内容未通过审核，请调整描述后重试"
            case .api(let msg): return msg
            }
        }
    }
}
