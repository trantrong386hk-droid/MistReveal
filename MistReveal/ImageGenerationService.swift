import Foundation
import CryptoKit

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

    /// 单元素 → 视觉调色盘（强调氛围能量感，非相机参数）
    func elementToPalette(_ element: String) -> VisualPalette {
        switch element {
        case "火":
            return VisualPalette(
                lighting: "暖阳下的柔焦质感，丁达尔效应的金色光束穿透画面，琥珀色的暖光笼罩全身",
                environment: "壁炉旁的暖褐色氛围，远处落日将天空染成熔金与绯红，温暖的光晕弥漫空气中",
                skinTone: "肌肤红润通透，泛着健康的暖光，如同被炉火映照，从内而外散发温度",
                clothing: "身穿暗红色羊绒衫，或深琥珀色的厚实面料，带有金色暗纹点缀"
            )
        case "木":
            return VisualPalette(
                lighting: "斑驳的林间光影透过密叶洒落，翠绿与金黄交织的自然光线",
                environment: "葱茏的自然绿意环绕，古树盘根错节，苔藓覆石，空气中弥漫着草木与泥土的清新气息",
                skinTone: "肌肤自然健康，白里透红，有阳光晒过的活力光泽，透着蓬勃生机",
                clothing: "身穿松绿色棉麻衬衫，或原色亚麻质地的自然系服饰，质朴而有生命力"
            )
        case "金":
            return VisualPalette(
                lighting: "清冽的银白色光线，轮廓分明的侧光勾勒出骨骼结构，冷峻而通透",
                environment: "极简素净的背景，带有冷调金属光泽的质感，空气清冽如高山之巅",
                skinTone: "肤若凝脂，白皙透亮带冷调光泽，骨相在冷光下格外分明",
                clothing: "身穿银灰色的利落剪裁外套，或黑白分明的冷调质感面料"
            )
        case "水":
            return VisualPalette(
                lighting: "朦胧的蓝调柔光弥漫，如月色笼罩水面，清冷而缥缈的光感",
                environment: "水雾氤氲的意境，深蓝灰的色调如水墨晕染，远处有水面的粼粼反光",
                skinTone: "肌肤水润细腻，透着清冷的光泽感，如月光映照下的玉石质地",
                clothing: "身穿深藏蓝色真丝衬衫，或墨黑色的垂坠感面料，流畅如水"
            )
        case "土":
            return VisualPalette(
                lighting: "午后温厚的琥珀色光线，如阳光打在石墙上的沉稳暖意",
                environment: "沉稳厚实的大地色氛围，陶土与原木的质感，空气中弥漫着温暖踏实的安全感",
                skinTone: "小麦色或蜜糖色的健康肤色，质感厚实温润，透着大地般的沉稳力量",
                clothing: "身穿驼色毛呢大衣，或陶土色的厚实棉质面料，沉稳而有质感"
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
                lighting: "暖阳穿透茂密树冠的丁达尔光束，翠绿与金黄交织，空气中漂浮着细碎的光粒",
                environment: "阳光穿透树冠的温暖森林，琥珀色的光粒悬浮在温润的空气中，远处有野花的芬芳",
                skinTone: "肌肤被阳光亲吻过的金色光泽，健康红润，散发着自然的活力",
                clothing: "身穿暖琥珀色或橄榄绿的自然质感面料，带有手工编织的粗犷纹理"
            )
        case "木+水":
            return VisualPalette(
                lighting: "竹林间的朦胧晨光，翠绿与水蓝交融的清凉光线，水珠折射出细碎光点",
                environment: "雨后青苔上的水珠折射着绿光，林木旁的溪流潺潺，晨雾笼罩着碧绿的水面",
                skinTone: "肌肤清透水润，如雨后新荷般清新，带着翠玉般的通透感",
                clothing: "身穿青碧色的丝质衬衫，或烟雨蓝的水洗棉麻，清爽而有生机"
            )
        case "火+金":
            return VisualPalette(
                lighting: "熔金般的落日余晖打在冷调金属表面，明暗对比强烈，光影冲突而震撼",
                environment: "落日映照下的玻璃幕墙，暖色与冷调在空气中碰撞，火花般的金色光点散落",
                skinTone: "肌肤在暖光中泛着金色光泽，冷调的骨相被暖光柔化，冷暖交织",
                clothing: "身穿黑色面料配熔金色点缀，或深酒红配银色暗线的对撞色调"
            )
        case "火+土":
            return VisualPalette(
                lighting: "炉火映照在陶土墙面上的深琥珀色暖光，温厚而令人安心",
                environment: "壁炉旁的暖褐色书房，烛光在陶土墙面上跳动，原木与暖石散发着沉静的温度",
                skinTone: "肌肤泛着深金琥珀色的温暖光泽，从内到外透着厚实的温度",
                clothing: "身穿深陶土色或焦糖色的手工编织面料，厚实温暖，带有匠人质感"
            )
        case "土+金":
            return VisualPalette(
                lighting: "秋日阳光打在温石上的金灰色调，温润与冷峻在光线中优雅交汇",
                environment: "秋日旷野上的金色麦浪，远处是秋光中的石砌城堡，空气沉稳而高贵",
                skinTone: "白皙中带暖调的象牙肤色，骨相优雅而分明",
                clothing: "身穿香槟金或暖灰色的高质感面料，沉稳中带着贵气"
            )
        case "水+金":
            return VisualPalette(
                lighting: "月光洒在静水面上的银蓝色光芒，清冽通透，如冰雪初融",
                environment: "月光洒在雪原上的银蓝世界，远处有雪峰的冷银轮廓，空气清冽纯净如水晶",
                skinTone: "肌肤白皙如瓷，月光映照下泛着冷润的银色光泽，骨相锋利分明",
                clothing: "身穿深夜蓝或液态银色的垂坠面料，冷峻而有质感"
            )
        case "水+火":
            return VisualPalette(
                lighting: "暖色烛火与冷蓝水雾的交织，蒸汽将暖光柔化成朦胧的光晕",
                environment: "温泉升腾的暖雾中透出的烛光，雨后的路面倒映着冷暖交融的光影",
                skinTone: "肌肤内部透出暖光，表面带着冷调的水润质感，明暗对比鲜明",
                clothing: "身穿深紫色或暗绯红色面料，搭配墨黑色的冷调衬里"
            )
        case "土+水":
            return VisualPalette(
                lighting: "阴天厚云中偶然透出的暖琥珀色光线，沉稳而湿润",
                environment: "雨后泥土气息弥漫的河畔小镇，湿漉漉的青石板反射着暖黄灯笼光",
                skinTone: "橄榄色或蜜色的温润肤质，带着雨后的清新水润感",
                clothing: "身穿深青灰色或暖灰褐色的厚实面料，沉稳中透着润泽"
            )
        case "木+金":
            return VisualPalette(
                lighting: "深秋的清冽光线，金色落叶与银色树干之间的通透空气感",
                environment: "银杏林中金叶纷飞，冷清的空气中弥漫着秋天的肃穆与生机",
                skinTone: "白皙健康的肤色，自然红润，清爽而有生机",
                clothing: "身穿象牙白或淡金色面料，配以松绿色点缀和银质细扣"
            )
        case "木+土":
            return VisualPalette(
                lighting: "田园午后的金绿色暖光，空气中漂浮着花粉与泥土的微粒",
                environment: "山间茶园的晨雾中透出的泥土芬芳，院落里的大树浓荫，藤蔓攀附着风化的石墙",
                skinTone: "阳光亲吻过的自然暖褐色肌肤，带着泥土般的厚实质感",
                clothing: "身穿暖褐色或苔绿色的天然棉麻面料，质朴而接地气"
            )
        default:
            // 无匹配的复合 → 回退到主元素
            return elementToPalette(primary)
        }
    }

    // MARK: - 十神人设映射（dominantGod → 外貌气质）

    /// 根据命局主导十神返回人物骨相气质描述（中文，强调灵魂感而非偶像感）
    /// 根据十神类型返回人设气质描述（中文）
    /// 特殊处理：如果用户日柱包含寅木能量，为偏印/七杀添加温暖特质
    func shishenPersona(_ dominantGod: String, baziInfo: BaZiInfo? = nil) -> String {
        // 检查用户是否有寅木能量（日柱天干为甲，或日柱地支为寅）
        let hasYinWoodEnergy: Bool = {
            guard let bazi = baziInfo else { return false }
            return bazi.dayPillar.contains("甲") || bazi.dayPillar.contains("寅")
        }()

        // 如果有寅木能量且十神为偏印/七杀，覆盖为温暖治愈特质
        if hasYinWoodEnergy && (dominantGod == "偏印" || dominantGod == "七杀") {
            return """
            五官立体但柔和，面部轮廓带有自然的生动感，眼神明亮温暖带着隐藏的治愈力量，\
            嘴角带着若有若无的浅笑，体态清瘦但充满活力，气质柔中带刚，\
            散发着自然有机的温暖气息，如林间清风般舒适宜人
            """
        }

        switch dominantGod {
        case "七杀":
            return "眉峰锋利上扬，颧骨突出，下颌线转折硬朗有力，眼神深邃如鹰隼，身姿挺拔刚劲，浑身散发着不怒自威的压迫感"
        case "正官":
            return "额头饱满开阔，五官端正大气，眉宇间舒展从容，眼神沉稳有智慧，身姿挺拔但不紧绷，周身散发着温文儒雅的从容气场"
        case "正财":
            return "面部线条柔和敦厚，笑容温暖真诚，眼神中带着踏实可靠的安定感，体态匀称健康，身姿挺拔可靠，散发着沉稳的力量感"
        case "偏财":
            return "五官鲜明有辨识度，笑容爽朗有感染力，眼神灵动明亮带着几分不羁，体态灵活有活力，周身散发着不拘小节的豪爽气场"
        case "食神":
            return "面容圆润舒展，眉眼之间松弛自在，嘴角天然带着一抹浅笑，眼神柔和慵懒，体态放松自然，整个人散发着让人想靠近的治愈气息"
        case "伤官":
            return "颧骨线条分明，眉眼锐利而有光彩，下颌线棱角清晰，眼神中带着不服输的倔强与灵气，体态清瘦有张力，气质桀骜中带着文艺感"
        case "正印":
            return "面容柔和温润如玉，鹅蛋脸型线条流畅，眼神清澈而笃定，眉宇间舒展，体态从容优雅，周身散发着书卷气的温和气息"
        case "偏印":
            return "五官立体深邃，面部轮廓带有独特的棱角感，眼神深远如渊，似在看向另一个维度，体态清瘦，气质孤冷疏离，如世外独行者"
        case "比肩":
            return "五官大气端正，眉眼之间坦荡磊落，目光直视前方带着天然的自信，体态挺拔有力，整个人散发着无需证明的从容与笃定"
        case "劫财":
            return "眉峰高挑带着攻击性，眼神锐利如猎豹，下颌线收紧有力，体态矫健紧实，周身散发着蓄势待发的竞争力与野心"
        default:
            return "五官端正自然，眉眼之间带着平和的力量，神态从容自信"
        }
    }

    /// 根据夫妻星类型返回骨相体态强制约束（中文）
    func spouseStarAppearance(_ spouseStarType: String?) -> String? {
        guard let star = spouseStarType else { return nil }
        switch star {
        case "七杀":
            return "骨相硬朗鲜明，颧骨突出，下颌线转折有力，眉峰锋利上扬，眼窝深邃目光如炬，身材健硕挺拔有肌肉张力"
        case "正官":
            return "五官端正大气，额头宽阔饱满，眼神沉稳清澈有定力，体格匀称挺拔有分量感，面部线条端正而有分量感"
        case "正财":
            return "面部线条温和但不软弱，眼神温暖真诚，体态敦实健康有保护感，整体气质踏实可靠，朴素中透着厚重"
        case "偏财":
            return "五官鲜明有辨识度，笑容灿烂有感染力，眼神灵活明亮，体态灵活有张力，整体气质洒脱有活力"
        default:
            return nil
        }
    }

    // MARK: - 方案C：仅追加调色盘 + 摄影参数

    /// 方案C后处理：年龄校准 + 清理冗余词 + 五行调色盘 + 摄影后缀
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

        // === 🔥 兜底保护：强制清理冷色调词汇（防御性编程，三层防御的最后防线） ===
        if let bazi = baziInfo, (bazi.xiYongShen == "木" || bazi.xiYongShen == "火") {
            let coldToWarmMapping: [String: String] = [
                "白皙透亮": "肌肤自然健康，白里透红",
                "银灰": "松绿色",
                "金属光泽": "自然光泽",
                "目光如刃": "眼神温润而坚定",
                "冷峻": "温润",
                "骨相突出": "骨架舒展",
                "轮廓分明下颌线清晰": "面部线条流畅自然",
                "眼神清冷": "眼神温暖明亮",
                "清冷": "温暖",
                "冷调": "暖调",
                "银白": "琥珀"
            ]

            var hasReplacement = false
            for (cold, warm) in coldToWarmMapping {
                if prompt.contains(cold) {
                    prompt = prompt.replacingOccurrences(of: cold, with: warm)
                    hasReplacement = true
                    print("🔥 [ImageGen] 兜底清理: \"\(cold)\" → \"\(warm)\"")
                }
            }

            if !hasReplacement {
                print("✅ [ImageGen] 兜底检查: 未检测到冷色调词汇（LLM 已遵守规则）")
            }
        }

        // === 五行调色盘（只用喜用神单元素，确保确定性） ===
        let palette: VisualPalette
        if let bazi = baziInfo {
            // 🔥 特殊处理：如果用户日柱有寅木能量，强制使用温暖调色盘（覆盖冷色调）
            let hasYinWoodEnergy = bazi.dayPillar.contains("甲") || bazi.dayPillar.contains("寅")

            if hasYinWoodEnergy && (bazi.xiYongShen == "金" || bazi.xiYongShen == "水") {
                // 寅木用户需要温暖调色盘，覆盖金/水的冷色调
                palette = VisualPalette(
                    lighting: "黄金时刻的温暖阳光洒落，琥珀色与蜜糖色的柔和光线弥漫，带来舒适宜人的光感",
                    environment: "森林边缘的自然绿意，远处有古木参天，温暖的光线穿透树冠，空气中弥漫着草木清香",
                    skinTone: "肌肤自然健康，白里透红，泛着阳光亲吻过的温润光泽，透着蓬勃生机",
                    clothing: "身穿柔和的琥珀色或橄榄绿色棉麻质地服饰，自然质朴而有生命力"
                )
                print("🔵 [ImageGen] 🌳 寅木能量覆盖: 原喜用神=\(bazi.xiYongShen) → 强制使用温暖森林调色盘")
            } else {
                palette = elementToPalette(bazi.xiYongShen)
                print("🔵 [ImageGen] 单元素调色盘: \(bazi.xiYongShen)")
            }
        } else {
            palette = elementToPalette("")
            print("🔵 [ImageGen] 无八字信息，使用中性调色盘")
        }

        // === 融合：prompt + 调色盘 + 摄影后缀（不含十神/夫妻星） ===
        let visualSuffix = """
        ，\(palette.skinTone)，\(palette.clothing)，\
        \(palette.lighting)，\(palette.environment)
        """

        let soulSuffix = "，电影级特写肖像，浅景深虚化，微米级皮肤纹理，无滤镜真实感，佳能人像色调"

        let finalPrompt = prompt + visualSuffix + soulSuffix

        return finalPrompt
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
            let persona = shishenPersona(bazi.dominantGod, baziInfo: bazi)
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
        ，\(palette.skinTone)，\(palette.clothing)，\
        \(palette.lighting)，\(palette.environment)
        """

        // 中文摄影后缀（取代旧的英文灵魂感后缀）
        let soulSuffix = "，电影级特写肖像，浅景深虚化，微米级皮肤纹理，无滤镜真实感，佳能人像色调"

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

        // 方案C：追加五行调色盘 + 摄影参数（十神/夫妻星由 LLM 负责）
        let finalPrompt = appendPaletteAndPhoto(prompt, baziInfo: baziInfo)
        print("🔵 [ImageGen] LLM 原始 Prompt: \(prompt)")
        print("🔵 [ImageGen] 最终 Prompt: \(finalPrompt)")

        // ===== 第一步：提交异步任务 =====
        let submitBody: [String: Any] = [
            "req_key": reqKey,
            "prompt": finalPrompt,
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
            throw ImageError.api("提交任务失败: \(String(data: submitResponseData, encoding: .utf8) ?? "未知错误")")
        }

        // 解析 task_id
        guard let submitJson = try JSONSerialization.jsonObject(with: submitResponseData) as? [String: Any] else {
            throw ImageError.api("提交响应格式错误")
        }

        // 兼容两种响应结构：{ data: { task_id } } 或 { Result: { data: { task_id } } }
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

        // ===== 第二步：轮询获取结果 =====
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
                print("⚠️ [ImageGen] 轮询 #\(attempt) 状态码: \(pollHttpResponse.statusCode)")
                continue
            }

            guard let pollJson = try JSONSerialization.jsonObject(with: pollResponseData) as? [String: Any] else {
                continue
            }

            // 兼容两种响应结构
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
                // 优先从 image_urls 下载
                if let imageUrls = dataObj["image_urls"] as? [String],
                   let firstUrlStr = imageUrls.first,
                   let imageUrl = URL(string: firstUrlStr) {
                    print("🔵 [ImageGen] 图片URL: \(firstUrlStr)")
                    let (imageData, _) = try await URLSession.shared.data(from: imageUrl)
                    print("✅ [ImageGen] 图片下载成功: \(imageData.count) bytes")
                    return imageData
                }
                // 兜底：尝试 binary_data_base64
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
                // 仍在处理中，继续轮询
                break
            }
        }

        print("❌ [ImageGen] 轮询超时，已尝试 \(maxPollAttempts) 次")
        throw ImageError.api("生成超时，请稍后再试")
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
        case invalidURL, noImage, timeout, api(String)
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "无效URL"
            case .noImage: return "无图片数据"
            case .timeout: return "生成超时，请稍后再试"
            case .api(let msg): return msg
            }
        }
    }
}
