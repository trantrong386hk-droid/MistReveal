import Foundation
import Supabase

/// 图片生成服务 - 使用火山引擎即梦 4.0 异步 API
class ImageGenerationService {

    static let shared = ImageGenerationService()
    private init() {}

    // MARK: - 配置（即梦 4.0）
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
    ///   - promptToken: 服务端令牌（aliyun-proxy 返回的 UUID），enhancement 在 volcano-submit EF 内进行
    func generateImage(promptToken: String) async throws -> Data {
        print("🔵 [ImageGen] ========== 开始生成图片 (即梦 4.0) ==========")
        print("🔵 [ImageGen] Prompt Token: \(promptToken)")

        let negativePrompt = "绿色头发，蓝色头发，紫色头发，银色头发，灰色头发，粉色头发，不自然的发色，头发泛绿，头发泛蓝，染发，动漫风格头发，绿色皮肤，蓝色皮肤，苍白灰暗的皮肤"

        do {
            return try await submitAndPollImage(promptToken: promptToken, negativePrompt: negativePrompt)
        } catch ImageError.contentRisk {
            print("⚠️ [ImageGen] 命中内容审核，快速退出")
            throw ImageError.contentRisk
        }
    }

    private func submitAndPollImage(promptToken: String, negativePrompt: String) async throws -> Data {
        // Submit via volcano-submit Edge Function
        struct SubmitBody: Encodable {
            let promptToken: String
            let negativePrompt: String
            let width: Int
            let height: Int
            let reqKey: String
            let returnUrl: Bool
        }
        struct SubmitResponse: Decodable {
            let task_id: String
        }
        struct PollBody: Encodable {
            let task_id: String
            let reqKey: String
        }
        struct PollResponse: Decodable {
            let status: String
            let image_urls: [String]?
            let binary_data_base64: [String]?
            let error: String?
            let resp_data: String?
            let code: Int?
        }

        let submitBody = SubmitBody(
            promptToken: promptToken,
            negativePrompt: negativePrompt,
            width: 864,
            height: 1536,
            reqKey: reqKey,
            returnUrl: true
        )

        print("🔵 [ImageGen] 提交异步任务到 volcano-submit...")
        let submitHeaders = try await edgeAuthHeaders()
        let submitResponse: SubmitResponse = try await invokeFunctionWithAuthFallback(
            "volcano-submit",
            body: submitBody,
            headers: submitHeaders
        )

        let taskId = submitResponse.task_id
        print("🔵 [ImageGen] 任务已提交，task_id: \(taskId)")

        for attempt in 1...maxPollAttempts {
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))

            let pollBody = PollBody(task_id: taskId, reqKey: reqKey)
            let pollHeaders = try await edgeAuthHeaders()
            let pollResult: PollResponse = try await invokeFunctionWithAuthFallback(
                "volcano-poll",
                body: pollBody,
                headers: pollHeaders
            )

            // Check for content risk error code
            if let code = pollResult.code, code == 50413 {
                print("⚠️ [ImageGen] 轮询阶段命中内容审核 (50413)")
                throw ImageError.contentRisk
            }

            let status = pollResult.status
            print("🔵 [ImageGen] 轮询 #\(attempt): status=\(status)")

            switch status {
            case "done":
                if let imageUrls = pollResult.image_urls,
                   let firstUrlStr = imageUrls.first,
                   let imageUrl = URL(string: firstUrlStr) {
                    print("🔵 [ImageGen] 图片URL: \(firstUrlStr)")
                    let (imageData, _) = try await URLSession.shared.data(from: imageUrl)
                    print("✅ [ImageGen] 图片下载成功: \(imageData.count) bytes")
                    return imageData
                }
                if let base64Array = pollResult.binary_data_base64,
                   let firstBase64 = base64Array.first,
                   let imageData = Data(base64Encoded: firstBase64) {
                    print("✅ [ImageGen] Base64 图片解码成功: \(imageData.count) bytes")
                    return imageData
                }
                print("❌ [ImageGen] 任务完成但无图片数据")
                throw ImageError.noImage

            case "failed":
                let errorMsg = pollResult.resp_data ?? pollResult.error ?? "生成失败"
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

    /// 获取 Edge Function 调用 headers。
    /// 与 TextGenerationService 对齐：直接调 refreshSession() 确保 token 新鲜有效。
    /// volcano-submit EF 需要真实用户 JWT（anon key 会导致 getUser 返回 null → 401）。
    private func edgeAuthHeaders() async throws -> [String: String] {
        var headers: [String: String] = [
            "apikey": AppConfig.Supabase.anonKey
        ]
        let session = try await supabase.auth.refreshSession()
        headers["Authorization"] = "Bearer \(session.accessToken)"
        return headers
    }

    private func invokeFunctionWithAuthFallback<T: Decodable, B: Encodable>(
        _ functionName: String,
        body: B,
        headers: [String: String]
    ) async throws -> T {
        do {
            return try await supabase.functions.invoke(
                functionName,
                options: FunctionInvokeOptions(
                    method: .post,
                    headers: headers,
                    body: body
                )
            )
        } catch {
            if isInvalidJWTError(error) {
                // 用户 token 过期/污染时，自动降级为 anon key，再试一次。
                var fallbackHeaders = headers
                fallbackHeaders["Authorization"] = "Bearer \(AppConfig.Supabase.anonKey)"
                print("⚠️ [ImageGen] \(functionName) JWT 无效，回退 anon key 重试")
                do {
                    return try await supabase.functions.invoke(
                        functionName,
                        options: FunctionInvokeOptions(
                            method: .post,
                            headers: fallbackHeaders,
                            body: body
                        )
                    )
                } catch {
                    logFunctionError(error, functionName: functionName)
                    throw error
                }
            }
            logFunctionError(error, functionName: functionName)
            throw error
        }
    }

    private func isInvalidJWTError(_ error: Error) -> Bool {
        guard let fnError = error as? FunctionsError else {
            return false
        }
        guard case let .httpError(code, data) = fnError else {
            return false
        }
        if code == 401 {
            let (_, message) = parseServerError(from: data)
            return message.localizedCaseInsensitiveContains("invalid jwt")
        }
        return false
    }

    private func logFunctionError(_ error: Error, functionName: String) {
        if let fnErr = error as? FunctionsError {
            switch fnErr {
            case let .httpError(code, data):
                let (_, message) = parseServerError(from: data)
                print("❌ [ImageGen] \(functionName) HTTP \(code): \(message)")
                return
            default:
                print("❌ [ImageGen] \(functionName) error: \(fnErr)")
                return
            }
        }
        print("❌ [ImageGen] \(functionName) error: \(error)")
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
