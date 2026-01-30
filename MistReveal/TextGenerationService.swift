import Foundation

/// 阿里云百炼大模型文本生成服务
class TextGenerationService {

    static let shared = TextGenerationService()

    private init() {}

    // MARK: - 数据模型

    /// 灵魂伴侣数据响应（兼容旧版）
    struct SoulmateData: Codable {
        /// 连山易卦象名称
        let hexagram: String
        /// 给用户的真实性格与外貌描述
        let analysis: String
        /// 给即梦使用的中文绘图提示词
        let imagePrompt: String

        enum CodingKeys: String, CodingKey {
            case hexagram
            case analysis
            case imagePrompt = "image_prompt"
        }
    }

    /// API 请求体
    private struct ChatRequest: Encodable {
        let model: String
        let messages: [Message]
        let responseFormat: ResponseFormat?

        enum CodingKeys: String, CodingKey {
            case model, messages
            case responseFormat = "response_format"
        }

        struct Message: Encodable {
            let role: String
            let content: String
        }

        struct ResponseFormat: Encodable {
            let type: String
        }
    }

    /// API 响应体
    private struct ChatResponse: Decodable {
        let choices: [Choice]

        struct Choice: Decodable {
            let message: Message
        }

        struct Message: Decodable {
            let content: String
        }
    }

    // MARK: - 系统提示词

    /// 灵魂分析系统提示词（连山易规则体系）
    private let soulAnalysisSystemPrompt = """
    你是一位精通连山易的命理大师，通过生辰信息推演命盘，洞察灵魂本质与命定姻缘。

    【核心规则 - 伴侣性别】
    异性伴侣匹配：男性用户 → 女性伴侣（用"她"）；女性用户 → 男性伴侣（用"他"）

    【禁用词汇】
    禁止使用：星辰、宿命、银河、轮回、天命、前世、来生、缘定三生、冥冥之中

    ========== 连山易推演体系 ==========

    【第一步：根据出生月份确定主卦五行】
    - 1-2月（寅卯月）→ 木象，主卦：震/巽
    - 3-4月（辰巳月）→ 火象，主卦：离
    - 5-6月（午未月）→ 土象，主卦：坤/艮
    - 7-8月（申酉月）→ 金象，主卦：乾/兑
    - 9-10月（戌亥月）→ 水象，主卦：坎
    - 11-12月（子丑月）→ 土水交汇，主卦：艮/坎

    【第二步：根据时辰确定性格基调】
    - 子时(23-1点)：深沉内敛，思维缜密，情感丰富但不轻易表露
    - 丑时(1-3点)：踏实稳重，耐心坚韧，外表冷静内心温热
    - 寅时(3-5点)：朝气蓬勃，有冲劲，直率但有时冲动
    - 卯时(5-7点)：温和细腻，善解人意，追求和谐但易犹豫
    - 辰时(7-9点)：志向远大，有领导力，自信但有时固执
    - 巳时(9-11点)：聪慧机敏，口才好，热情但有时浮躁
    - 午时(11-13点)：热情开朗，感染力强，爱表达但有时急躁
    - 未时(13-15点)：温厚包容，重感情，顾家但有时优柔寡断
    - 申时(15-17点)：灵活变通，适应力强，聪明但有时投机
    - 酉时(17-19点)：精致讲究，审美好，有原则但有时挑剔
    - 戌时(19-21点)：忠诚可靠，责任感强，正直但有时过于严肃
    - 亥时(21-23点)：浪漫感性，想象力丰富，温柔但有时不切实际

    【第三步：五行相配推导伴侣命格】
    用户五行 → 伴侣五行（互补原则）：
    - 木命 → 配水命或火命（水生木滋养，木生火释放）
    - 火命 → 配木命或土命（木生火助燃，火生土收敛）
    - 土命 → 配火命或金命（火生土温暖，土生金沉稳）
    - 金命 → 配土命或水命（土生金厚重，金生水灵动）
    - 水命 → 配金命或木命（金生水清澈，水生木成长）

    【第四步：五行决定伴侣外貌特征】（必须严格遵循）

    金命伴侣外貌：
    - 肤色：白皙透亮，如瓷器般细腻
    - 脸型：轮廓分明，下颌线清晰
    - 眼睛：眼神清冷有光，眼型细长或杏眼
    - 气质：冷峻高雅，不怒自威
    - 穿着：偏好白色、银灰、黑色等冷色调，材质精致如丝绸、羊绒

    木命伴侣外貌：
    - 肤色：自然健康，白里透红
    - 脸型：鹅蛋脸或瓜子脸，线条柔和
    - 眼睛：眉清目秀，眼神温润如玉
    - 气质：儒雅温和，书卷气息
    - 穿着：偏好绿色、米色、棕色等自然色，材质舒适如棉麻、针织

    水命伴侣外貌：
    - 肤色：细腻水润，有光泽
    - 脸型：圆润饱满，有亲和力
    - 眼睛：眼睛灵动明亮，眼波流转，睫毛浓密
    - 气质：灵动飘逸，机智聪慧
    - 穿着：偏好蓝色、黑色、白色等清爽色，材质轻盈如雪纺、真丝

    火命伴侣外貌：
    - 肤色：红润有光泽，健康活力
    - 脸型：轮廓立体，颧骨适中
    - 眼睛：眼神明亮有神，目光热烈，双眼皮明显
    - 气质：热情开朗，感染力强
    - 穿着：偏好红色、橙色、暖黄等暖色调，材质有质感如呢绒、皮革

    土命伴侣外貌：
    - 肤色：小麦色或蜜糖色，温暖健康
    - 脸型：方圆适中，敦厚端正
    - 眼睛：眼神温和坚定，给人安全感
    - 气质：沉稳大气，值得信赖
    - 穿着：偏好卡其、驼色、大地色系，材质厚实如毛呢、棉质

    【第五步：性格互补映射】
    - 用户"内敛" → 伴侣"主动开朗"，主动打破沉默
    - 用户"急躁" → 伴侣"沉稳耐心"，平衡情绪
    - 用户"理性" → 伴侣"感性细腻"，增添温度
    - 用户"优柔" → 伴侣"果断利落"，帮助决策
    - 用户"固执" → 伴侣"灵活变通"，化解僵局

    ========== 输出要求 ==========

    【分析风格】
    1. 场景化描述：如"你是那种在聚会上看起来随和，其实内心早就想回家的人"
    2. 标签接地气：如"外冷内热"、"嘴硬心软"、"表面佛系"
    3. 外貌描述要生动具体，让人脑海中能形成清晰画面，至少50字
    4. 推导逻辑清晰：因为你XX → 所以需要YY的人

    【输出格式】
    必须且只能返回以下 JSON，不要有任何其他文字：

    {
      "hexagram": "根据月份推出的卦象名称",
      "user_element": "用户的五行属性（金/木/水/火/土）",
      "soulmate_element": "伴侣的五行属性（根据相配规则）",
      "personality_description": "核心性格描述，结合卦象和时辰，场景化表达，80-120字",
      "personality_traits": ["性格标签1", "性格标签2", "性格标签3", "性格标签4"],
      "relationship_behaviors": ["感情中的表现1（具体场景）", "感情中的表现2", "感情中的表现3"],
      "emotional_needs": ["情感需求1", "情感需求2", "情感需求3"],
      "matching_deductions": [
        {"user_trait": "你的特质", "soulmate_trait": "伴侣特质", "explanation": "五行相配解释"}
      ],
      "soulmate_traits": ["根据伴侣五行推出的特质1", "特质2", "特质3", "特质4"],
      "compatibility_score": 85到95之间的整数,
      "destiny_type": "缘分类型",
      "soulmate_appearance": {
        "skin_tone": "根据伴侣五行，详细描述肤色质感，15-25字",
        "face_shape": "根据伴侣五行，描述脸型轮廓，10-20字",
        "eyes": "根据伴侣五行，详细描述眼睛特征，20-35字",
        "other_features": "鼻子、嘴唇、其他特征，20-30字",
        "hair": "发型发色，与五行气质匹配，15-25字",
        "clothing": "根据伴侣五行的穿着偏好，具体到颜色和材质，15-25字"
      },
      "soulmate_analysis": "综合伴侣的五行属性、性格特质、外貌特征，写一段完整生动的描述，要有画面感，200-300字",
      "image_prompt": "根据上述外貌描述，生成中文绘图提示词，格式：一位[年龄]的东方[男性/女性]，头肩肖像照，正面面向镜头，[将skin_tone的内容写入]，[将face_shape的内容写入]，[将eyes的内容写入]，[将other_features的内容写入]，[将hair的内容写入]，身穿[将clothing的内容写入]，纯灰色背景，柔和摄影棚灯光，专业人像摄影，真实皮肤质感，高清细节，8K画质"
    }
    """

    /// 旧版系统提示词（保留兼容）
    private let systemPrompt = """
    你是一位深藏不露的连山易专家。你通过生辰八字推算艮卦山势，洞察命中注定的缘分。

    你的回复规范：

    【人设】
    说话直白、干练、带点看透世俗的冷静。拒绝任何虚假、诗意、玄幻的词汇。
    严禁使用这些词：星辰、宿命、银河、轮回、天命、前世、来生、缘定三生。

    【内容要求】
    必须描述一个真实存在的人。包括：
    1. 外貌细节（占40%）：发型、肤色、五官特征、身材、穿衣偏好
    2. 性格特点（占40%）：性格短板（如固执、慢热、话少等）、脾气、待人方式
    3. 职业状态（占10%）：可能的职业类型、工作状态
    4. 生活习惯（占10%）：作息规律、兴趣爱好、日常习惯

    描述必须具体、接地气，避免笼统和套话。总字数控制在 200-300 字。

    【输出格式】
    为了方便 App 解析，请务必只返回以下 JSON 格式，不要有任何开场白或结尾文字：

    {
      "hexagram": "连山易卦象名称（如：艮为山、山天大畜、山地剥等）",
      "analysis": "这里写给用户的、接地气的性格与缘分描述文字（200-300字）",
      "image_prompt": "这里写一段专门给 AI 生图模型（如即梦/Flux）使用的中文描述词（100-150字）。必须强调：纪实摄影风格、真实人物、自然光影。描述五官、发型、气质、穿着等外在特征。"
    }
    """

    // MARK: - 公开方法

    /// 根据完整生辰信息获取灵魂伴侣数据
    /// - Parameters:
    ///   - birthDate: 生辰日期字符串，如 "1990年5月15日"
    ///   - gender: 性灵属性（乾/坤）
    ///   - birthTime: 出生时辰（子时、丑时等）
    ///   - location: 出生地点
    /// - Returns: 灵魂伴侣数据
    func fetchSoulmateData(
        birthDate: String,
        gender: String,
        birthTime: String,
        location: String
    ) async throws -> SoulmateData {
        print("🔵 [TextGeneration] 开始生成灵魂伴侣数据")
        print("   - 生辰: \(birthDate)")
        print("   - 性别: \(gender)")
        print("   - 时辰: \(birthTime)")
        print("   - 地点: \(location)")

        let url = URL(string: "\(AppConfig.AliyunBailian.baseURL)/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(AppConfig.AliyunBailian.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let userMessage = """
        请根据以下信息推演这个人的灵魂伴侣：
        - 性灵属性：\(gender)
        - 降临日期：\(birthDate)
        - 出生时辰：\(birthTime)
        - 现世坐标：\(location)

        请推算艮卦山势，描述 ta 的灵魂伴侣的真实外貌、性格、职业和生活习惯。
        """

        let chatRequest = ChatRequest(
            model: AppConfig.AliyunBailian.model,
            messages: [
                ChatRequest.Message(role: "system", content: systemPrompt),
                ChatRequest.Message(role: "user", content: userMessage)
            ],
            responseFormat: ChatRequest.ResponseFormat(type: "json_object")
        )

        request.httpBody = try JSONEncoder().encode(chatRequest)

        print("🔵 [TextGeneration] 发送请求到阿里云百炼...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TextGenerationError.invalidResponse
        }

        print("🔵 [TextGeneration] 收到响应，状态码: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "未知错误"
            print("❌ [TextGeneration] API 错误: \(errorText)")
            throw TextGenerationError.apiError(statusCode: httpResponse.statusCode, message: errorText)
        }

        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)

        guard let content = chatResponse.choices.first?.message.content else {
            throw TextGenerationError.emptyResponse
        }

        print("🔵 [TextGeneration] AI 返回内容: \(content.prefix(200))...")

        // 解析 JSON 内容
        guard let jsonData = content.data(using: .utf8) else {
            throw TextGenerationError.invalidJSON
        }

        let soulmateData = try JSONDecoder().decode(SoulmateData.self, from: jsonData)

        print("✅ [TextGeneration] 解析成功")
        print("   - analysis: \(soulmateData.analysis.prefix(50))...")
        print("   - image_prompt: \(soulmateData.imagePrompt.prefix(50))...")

        return soulmateData
    }

    // MARK: - 灵魂分析（新版完整分析）

    /// 获取完整的灵魂分析结果
    /// - Parameters:
    ///   - birthDate: 生辰日期字符串，如 "1990年5月15日"
    ///   - gender: 性别（男/女）
    ///   - birthTime: 出生时辰（子时、丑时等）
    ///   - location: 出生地点
    /// - Returns: 完整的灵魂分析结果
    func fetchSoulAnalysis(
        birthDate: String,
        gender: String,
        birthTime: String,
        location: String
    ) async throws -> SoulAnalysisResult {
        print("🔵 [TextGeneration] 开始生成灵魂分析")
        print("   - 生辰: \(birthDate)")
        print("   - 性别: \(gender)")
        print("   - 时辰: \(birthTime)")
        print("   - 地点: \(location)")

        let url = URL(string: "\(AppConfig.AliyunBailian.baseURL)/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(AppConfig.AliyunBailian.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 根据用户性别确定伴侣性别
        let soulmateGender = gender == "男" ? "女" : "男"
        let pronounHeShe = gender == "男" ? "她" : "他"

        let userMessage = """
        请根据以下信息分析这个人的性格特质，并推导出最适合的伴侣类型：

        【用户信息】
        - 用户性别：\(gender)（用户本人）
        - 出生日期：\(birthDate)
        - 出生时辰：\(birthTime)
        - 出生地点：\(location)

        【重要提醒】
        用户是\(gender)性，所以伴侣必须是【\(soulmateGender)性】。
        所有关于伴侣的描述都要用"\(pronounHeShe)"来称呼，描述\(soulmateGender)性的外貌特征。

        请先分析用户本人的性格特质，然后基于"因为你XX，所以需要YY的人"的逻辑，推导出最适合的\(soulmateGender)性伴侣特质。
        """

        let chatRequest = ChatRequest(
            model: AppConfig.AliyunBailian.model,
            messages: [
                ChatRequest.Message(role: "system", content: soulAnalysisSystemPrompt),
                ChatRequest.Message(role: "user", content: userMessage)
            ],
            responseFormat: ChatRequest.ResponseFormat(type: "json_object")
        )

        request.httpBody = try JSONEncoder().encode(chatRequest)

        print("🔵 [TextGeneration] 发送灵魂分析请求到阿里云百炼...")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TextGenerationError.invalidResponse
        }

        print("🔵 [TextGeneration] 收到响应，状态码: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "未知错误"
            print("❌ [TextGeneration] API 错误: \(errorText)")
            throw TextGenerationError.apiError(statusCode: httpResponse.statusCode, message: errorText)
        }

        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)

        guard let content = chatResponse.choices.first?.message.content else {
            throw TextGenerationError.emptyResponse
        }

        print("🔵 [TextGeneration] AI 返回内容: \(content.prefix(300))...")

        // 解析 JSON 内容
        guard let jsonData = content.data(using: .utf8) else {
            throw TextGenerationError.invalidJSON
        }

        let soulAnalysis = try JSONDecoder().decode(SoulAnalysisResult.self, from: jsonData)

        print("✅ [TextGeneration] 灵魂分析解析成功")
        print("   - 性格描述: \(soulAnalysis.personalityDescription.prefix(50))...")
        print("   - 性格特质: \(soulAnalysis.personalityTraits)")
        print("   - 契合度: \(soulAnalysis.compatibilityScore)%")

        return soulAnalysis
    }

    // MARK: - 错误类型

    enum TextGenerationError: LocalizedError {
        case invalidResponse
        case apiError(statusCode: Int, message: String)
        case emptyResponse
        case invalidJSON

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "无效的响应"
            case .apiError(let statusCode, let message):
                return "API 错误 (\(statusCode)): \(message)"
            case .emptyResponse:
                return "AI 返回内容为空"
            case .invalidJSON:
                return "无法解析 AI 返回的 JSON"
            }
        }
    }
}
