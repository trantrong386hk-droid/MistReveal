import Foundation
import LunarSwift

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
        /// 用户八字信息（用于五行互补计算）
        var baziInfo: BaZiInfo?

        enum CodingKeys: String, CodingKey {
            case hexagram
            case analysis
            case imagePrompt = "image_prompt"
            case baziInfo = "bazi_info"
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

    /// 灵魂分析系统提示词
    private let soulAnalysisSystemPrompt = """
    你是一位结合现代心理学与中国传统命理学的灵魂架构师。你的工作方式：接收由专业历法引擎精确计算的八字命理数据，然后进行深度灵魂解析与伴侣推演。

    你说话的方式：神秘但不虚浮，专业但不晦涩，像一个看透了命盘却懒得装腔作势的人。你是赛博时代的命理师——用数据说话，用直觉收尾。

    【核心规则】
    - 异性伴侣匹配：男性用户 → 女性伴侣（用"她"）；女性用户 → 男性伴侣（用"他"）
    - 用户的八字、日主、五行分布、喜用神等硬核数据已由系统精确计算并提供，你不要自行推算，直接采用
    - user_element 字段必须与系统提供的日主五行完全一致

    【禁用词汇】
    星辰、宿命、银河、轮回、天命、前世、来生、缘定三生、冥冥之中、冥冥中、注定

    ========== 灵魂解析框架 ==========

    【第一层：日主解码 → 灵魂内核】
    根据系统提供的日主天干，解读其灵魂底色：
    - 甲木：参天大树型人格。有野心有骨气，但有时候硬得像块木头，不懂转弯
    - 乙木：藤蔓型人格。柔软但有韧性，看着好说话，其实内心有自己的一套
    - 丙火：太阳型人格。走到哪里都是焦点，热情到让人觉得有点"过"
    - 丁火：烛光型人格。表面安静，内心戏丰富到能写连续剧
    - 戊土：大山型人格。稳得像块石头，但浪漫对你来说是个技术难题
    - 己土：田园型人格。包容力强到有点没原则，什么人都想照顾
    - 庚金：利刃型人格。做事果断不拖泥带水，但说话也跟刀子一样
    - 辛金：珠玉型人格。精致、敏感、有品味，但有时候矫情得很
    - 壬水：大海型人格。脑子转得快，想法多到自己都管不住
    - 癸水：细雨型人格。敏锐、共情力强，但容易被别人的情绪影响

    【第二层：五行能量场 → 性格明暗面】
    结合五行分布的旺衰，分析性格的明面和暗面：
    - 某五行 ≥3 为偏旺：该特质外显、过度，需要抑制
    - 某五行 = 0 为缺失：该特质缺失，渴望补足
    - 喜用神所代表的特质 = 此人最需要、最向往、最容易被吸引的能量

    这一层要写出"你以为你是XX，其实你是YY"的洞察感。

    【第三层：喜用神 → 灵魂伴侣密码】
    喜用神是此人命格中最需要补足的能量，也是其灵魂伴侣的核心特质来源：
    - 喜金：需要一个有边界感、做事有章法、冷静理性的人来收住你
    - 喜木：需要一个有生命力、正能量、能带你成长的人来唤醒你
    - 喜水：需要一个灵活变通、懂你不说出口的话、情商在线的人来融化你
    - 喜火：需要一个热情主动、能点燃你激情、给你方向感的人来照亮你
    - 喜土：需要一个踏实靠谱、稳定输出安全感、让你放心的人来托住你

    【第四层：伴侣命格推导】
    五行相配（互补原则）：
    - 木命 → 配水命或火命（水生木滋养，木生火释放）
    - 火命 → 配木命或土命（木生火助燃，火生土收敛）
    - 土命 → 配火命或金命（火生土温暖，土生金沉稳）
    - 金命 → 配土命或水命（土生金厚重，金生水灵动）
    - 水命 → 配金命或木命（金生水清澈，水生木成长）

    【第五层：伴侣视觉特征】（必须严格遵循五行属性）

    金命伴侣：白皙透亮的肤色 / 轮廓分明下颌线清晰 / 眼神清冷有光 / 冷峻高雅 / 白色银灰黑色冷色调，丝绸羊绒
    木命伴侣：自然健康白里透红 / 鹅蛋脸线条柔和 / 眉清目秀眼神温润 / 儒雅温和 / 绿色米色棕色自然色，棉麻针织
    水命伴侣：细腻水润有光泽 / 圆润饱满有亲和力 / 眼睛灵动眼波流转 / 灵动飘逸 / 蓝色黑色白色清爽色，雪纺真丝
    火命伴侣：红润有光泽健康活力 / 轮廓立体颧骨适中 / 眼神明亮目光热烈 / 热情感染力强 / 红色橙色暖黄暖色调，呢绒皮革
    土命伴侣：小麦色蜜糖色温暖 / 方圆适中敦厚端正 / 眼神温和坚定 / 沉稳可靠 / 卡其驼色大地色系，毛呢棉质

    【第六层：性格互补映射】
    必须基于用户八字的真实弱点来推导，不要泛泛而谈：
    - 用户五行缺什么 → 伴侣在那方面补足
    - 用户五行旺什么 → 伴侣在那方面克制平衡
    - 要写出具体场景，不要只写抽象标签

    ========== 输出要求 ==========

    【语气风格】
    1. 赛博玄学感：像是一个能读取你灵魂数据的AI，冷静地告诉你真相
    2. 场景化洞察：如"你的八字里金太重——所以你是那种吵完架第二天就当没事的人，但对方可能已经哭了一晚上"
    3. 标签要精准毒辣：如"嘴硬心软""社交NPC""情绪黑洞""慢热到让人想放弃"
    4. 推导逻辑锋利：你的日主是X → 你的五行Y偏旺 → 所以你在感情中会Z → 因此你需要一个能A的人
    5. 外貌描述要让人"看到"那个人：具体到光影、质感、神态

    【画像生成规则 - image_prompt】
    必须结合伴侣五行和用户喜用神来设定画面氛围：
    - 喜金：画面加入金属光泽质感、银白色调的环境光
    - 喜木：画面加入自然光影、绿意或木质纹理的温暖氛围
    - 喜水：画面加入流动感、深蓝色调、水雾或柔光氛围
    - 喜火：画面加入温暖的黄金时刻光线、暖橙红色氛围光
    - 喜土：画面加入柔和的大地色暖光、沉稳厚实的背景质感

    【输出格式】
    必须且只能返回以下 JSON，不要有任何其他文字：

    {
      "hexagram": "根据八字纳音推出的卦象或命格名称",
      "user_element": "用户日主五行（必须与系统提供的一致）",
      "soulmate_element": "伴侣五行（根据相配规则推导）",
      "personality_description": "基于日主天干+五行旺衰+喜用神的深度灵魂解析，赛博玄学风格，要有洞察感和共鸣感，100-150字",
      "personality_traits": ["精准毒辣的标签1", "标签2", "标签3", "标签4"],
      "relationship_behaviors": ["感情中的具体场景化表现1", "场景2", "场景3"],
      "emotional_needs": ["基于喜用神推导的情感需求1", "需求2", "需求3"],
      "matching_deductions": [
        {"user_trait": "你的命格特质（引用八字数据）", "soulmate_trait": "伴侣对应特质", "explanation": "五行生克逻辑解释"}
      ],
      "soulmate_traits": ["基于伴侣五行+喜用神推出的特质1", "特质2", "特质3", "特质4"],
      "compatibility_score": 82到96之间的整数,
      "destiny_type": "缘分类型（要有赛博感，如'量子纠缠型'、'引力共振型'）",
      "soulmate_appearance": {
        "skin_tone": "根据伴侣五行的肤色质感描述，15-25字",
        "face_shape": "根据伴侣五行的脸型描述，10-20字",
        "eyes": "根据伴侣五行的眼睛特征，要有神态描写，20-35字",
        "other_features": "鼻、唇、其他特征，有辨识度，20-30字",
        "hair": "发型发色，与伴侣五行气质一致，15-25字",
        "clothing": "穿着偏好，具体颜色材质，与五行一致，15-25字"
      },
      "soulmate_analysis": "综合伴侣五行+外貌+性格+与用户的互补关系，写一段完整生动的描述。要让用户觉得'这个人我好像在哪里见过'，200-300字",
      "image_prompt": "中文绘图提示词。格式：一位[年龄]的东方[男性/女性]，头肩肖像照，正面面向镜头，[skin_tone]，[face_shape]，[eyes]，[other_features]，[hair]，身穿[clothing]，[根据喜用神插入氛围光效描述]，专业人像摄影，真实皮肤质感，高清细节，8K画质"
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

        // 从 SecretsManager 获取 API Key
        guard let apiKey = await SecretsManager.shared.getSecret("ALIYUN_BAILIAN_API_KEY") else {
            throw TextGenerationError.apiError(statusCode: 0, message: "无法获取 API 密钥")
        }

        let url = URL(string: "\(AppConfig.AliyunBailian.baseURL)/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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

        var soulmateData = try JSONDecoder().decode(SoulmateData.self, from: jsonData)

        // 计算八字信息用于五行互补
        if let baziInfo = calculateBaZi(birthDate: birthDate, birthTime: birthTime) {
            soulmateData.baziInfo = baziInfo
            print("✅ [TextGeneration] 八字计算成功: \(baziInfo.elementSummary)")
        }

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

        // 从 SecretsManager 获取 API Key
        guard let apiKey = await SecretsManager.shared.getSecret("ALIYUN_BAILIAN_API_KEY") else {
            throw TextGenerationError.apiError(statusCode: 0, message: "无法获取 API 密钥")
        }

        let url = URL(string: "\(AppConfig.AliyunBailian.baseURL)/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 根据用户性别确定伴侣性别
        let soulmateGender = gender == "男" ? "女" : "男"
        let pronounHeShe = gender == "男" ? "她" : "他"

        // 使用 lunar-swift 计算精准八字
        let baziInfo = calculateBaZi(birthDate: birthDate, birthTime: birthTime)

        // 构建用户消息
        var userMessage: String

        if let bazi = baziInfo {
            userMessage = """
            我已经通过专业历法引擎完成了这位用户的精准八字排盘。以下是硬核数据，请直接采用，不要自行推算：

            ═══ 系统排盘数据 ═══
            四柱：\(bazi.yearPillar) \(bazi.monthPillar) \(bazi.dayPillar) \(bazi.timePillar)
            日主：\(bazi.dayStem)（\(bazi.dayStemElement)命）
            年柱纳音：\(bazi.yearNaYin)
            日柱纳音：\(bazi.dayNaYin)
            五行能量分布：\(bazi.elementSummary)
            五行缺失：\(bazi.missingElements.isEmpty ? "无" : bazi.missingElements.joined(separator: "、"))
            五行偏旺：\(bazi.strongElements.isEmpty ? "均衡" : bazi.strongElements.joined(separator: "、"))
            喜用神：\(bazi.xiYongShen)（\(bazi.xiYongReason)）
            ═══════════════════

            用户基本信息：\(gender)性，\(birthDate) \(birthTime)生，现居\(location)

            【强制规则】
            1. user_element 必须填"\(bazi.dayStemElement)"
            2. 伴侣必须是\(soulmateGender)性，全文用"\(pronounHeShe)"称呼
            3. image_prompt 的氛围光效必须匹配喜用神"\(bazi.xiYongShen)"的视觉特征

            请基于以上数据，进行深度灵魂解析和伴侣推演。
            """
        } else {
            userMessage = """
            请根据以下信息分析这个人的性格特质，并推导出最适合的伴侣类型：

            用户信息：\(gender)性，\(birthDate) \(birthTime)生，现居\(location)

            伴侣必须是\(soulmateGender)性，全文用"\(pronounHeShe)"称呼。
            """
        }

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

        var soulAnalysis = try JSONDecoder().decode(SoulAnalysisResult.self, from: jsonData)

        // 附加本地计算的八字数据
        soulAnalysis.baziInfo = baziInfo

        print("✅ [TextGeneration] 灵魂分析解析成功")
        print("   - 日主五行: \(baziInfo?.dayStemDescription ?? "未计算")")
        print("   - 性格描述: \(soulAnalysis.personalityDescription.prefix(50))...")
        print("   - 性格特质: \(soulAnalysis.personalityTraits)")
        print("   - 契合度: \(soulAnalysis.compatibilityScore)%")

        return soulAnalysis
    }

    // MARK: - 八字推演（lunar-swift）

    /// 时辰名称映射到小时
    private let birthTimeToHour: [String: Int] = [
        "子时": 0, "丒时": 2, "丑时": 2, "寅时": 4, "卯时": 6,
        "辰时": 8, "巳时": 10, "午时": 12, "未时": 14,
        "申时": 16, "酉时": 18, "戌时": 20, "亥时": 22
    ]

    /// 天干对应五行
    private let ganToElement: [String: String] = [
        "甲": "木", "乙": "木", "丙": "火", "丁": "火",
        "戊": "土", "己": "土", "庚": "金", "辛": "金",
        "壬": "水", "癸": "水"
    ]

    /// 地支对应五行
    private let zhiToElement: [String: String] = [
        "子": "水", "丑": "土", "寅": "木", "卯": "木",
        "辰": "土", "巳": "火", "午": "火", "未": "土",
        "申": "金", "酉": "金", "戌": "土", "亥": "水"
    ]

    /// 从生辰信息计算精准八字
    func calculateBaZi(birthDate: String, birthTime: String) -> BaZiInfo? {
        // 解析日期字符串，如 "1990年5月15日"
        guard let (year, month, day) = parseBirthDate(birthDate) else {
            print("❌ [BaZi] 无法解析日期: \(birthDate)")
            return nil
        }

        let hour = birthTimeToHour[birthTime] ?? 12

        print("🔮 [BaZi] 排盘: \(year)年\(month)月\(day)日 \(hour)时")

        // 使用 lunar-swift 创建 Solar 日期并转换
        let solar = Solar.fromYmdHms(year: year, month: month, day: day, hour: hour, minute: 0, second: 0)
        let lunar = solar.lunar
        let eightChar = lunar.eightChar

        // 四柱
        let yearPillar = eightChar.year
        let monthPillar = eightChar.month
        let dayPillar = eightChar.day
        let timePillar = eightChar.time

        // 日主（日干）
        let dayStem = eightChar.dayGan
        let dayStemElement = ganToElement[dayStem] ?? "未知"

        // 统计八字中五行个数
        var elementCounts: [String: Int] = ["金": 0, "木": 0, "水": 0, "火": 0, "土": 0]

        // 统计天干
        let allGan = [eightChar.yearGan, eightChar.monthGan, eightChar.dayGan, eightChar.timeGan]
        for gan in allGan {
            if let e = ganToElement[gan] {
                elementCounts[e, default: 0] += 1
            }
        }

        // 统计地支
        let allZhi = [eightChar.yearZhi, eightChar.monthZhi, eightChar.dayZhi, eightChar.timeZhi]
        for zhi in allZhi {
            if let e = zhiToElement[zhi] {
                elementCounts[e, default: 0] += 1
            }
        }

        let metalCount = elementCounts["金"] ?? 0
        let woodCount = elementCounts["木"] ?? 0
        let waterCount = elementCounts["水"] ?? 0
        let fireCount = elementCounts["火"] ?? 0
        let earthCount = elementCounts["土"] ?? 0

        let summary = "金\(metalCount) 木\(woodCount) 水\(waterCount) 火\(fireCount) 土\(earthCount)"

        // 缺失五行
        let missing = elementCounts.filter { $0.value == 0 }.map { $0.key }
        // 偏旺五行（>=3 个）
        let strong = elementCounts.filter { $0.value >= 3 }.map { $0.key }

        // 简易喜用神推断：日主弱则喜生助，日主强则喜克泄
        let (xiYong, xiReason) = inferXiYongShen(
            dayStemElement: dayStemElement,
            elementCounts: elementCounts
        )

        // 纳音
        let yearNaYin = eightChar.yearNaYin
        let dayNaYin = eightChar.dayNaYin

        let baziInfo = BaZiInfo(
            yearPillar: yearPillar,
            monthPillar: monthPillar,
            dayPillar: dayPillar,
            timePillar: timePillar,
            dayStem: dayStem,
            dayStemElement: dayStemElement,
            dayStemDescription: "\(dayStem)\(dayStemElement)",
            metalCount: metalCount,
            woodCount: woodCount,
            waterCount: waterCount,
            fireCount: fireCount,
            earthCount: earthCount,
            elementSummary: summary,
            missingElements: missing,
            strongElements: strong,
            xiYongShen: xiYong,
            xiYongReason: xiReason,
            yearNaYin: yearNaYin,
            dayNaYin: dayNaYin
        )

        print("✅ [BaZi] 四柱: \(yearPillar) \(monthPillar) \(dayPillar) \(timePillar)")
        print("   日主: \(dayStem)\(dayStemElement)  五行分布: \(summary)")
        print("   喜用神: \(xiYong) (\(xiReason))")
        print("   年纳音: \(yearNaYin)  日纳音: \(dayNaYin)")

        return baziInfo
    }

    /// 解析 "1990年5月15日" 格式的日期字符串
    private func parseBirthDate(_ dateString: String) -> (Int, Int, Int)? {
        let pattern = #"(\d{4})年(\d{1,2})月(\d{1,2})日"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: dateString, range: NSRange(dateString.startIndex..., in: dateString)),
              match.numberOfRanges == 4 else {
            return nil
        }

        let yearRange = Range(match.range(at: 1), in: dateString)!
        let monthRange = Range(match.range(at: 2), in: dateString)!
        let dayRange = Range(match.range(at: 3), in: dateString)!

        guard let year = Int(dateString[yearRange]),
              let month = Int(dateString[monthRange]),
              let day = Int(dateString[dayRange]) else {
            return nil
        }

        return (year, month, day)
    }

    /// 简易喜用神推断
    private func inferXiYongShen(dayStemElement: String, elementCounts: [String: Int]) -> (String, String) {
        // 五行相生关系：木→火→土→金→水→木
        // 五行相克关系：木→土→水→火→金→木
        let generates: [String: String] = ["木": "火", "火": "土", "土": "金", "金": "水", "水": "木"]
        let generatedBy: [String: String] = ["木": "水", "火": "木", "土": "火", "金": "土", "水": "金"]
        let controls: [String: String] = ["木": "土", "火": "金", "土": "水", "金": "木", "水": "火"]
        let controlledBy: [String: String] = ["木": "金", "火": "水", "土": "木", "金": "火", "水": "土"]

        let selfCount = elementCounts[dayStemElement] ?? 0
        let helperElement = generatedBy[dayStemElement] ?? ""
        let helperCount = elementCounts[helperElement] ?? 0
        let selfStrength = selfCount + helperCount

        if selfStrength <= 3 {
            // 日主偏弱，喜生助（印星、比劫）
            let xiElement = generatedBy[dayStemElement] ?? dayStemElement
            return (xiElement, "日主\(dayStemElement)偏弱，需要\(xiElement)来生扶")
        } else {
            // 日主偏强，喜克泄（食伤、财星、官杀）
            let xiElement = generates[dayStemElement] ?? controlledBy[dayStemElement] ?? "土"
            return (xiElement, "日主\(dayStemElement)偏旺，需要\(xiElement)来泄耗平衡")
        }
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
