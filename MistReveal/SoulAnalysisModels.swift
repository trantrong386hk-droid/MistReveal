import Foundation

/// 八字精准命理数据（由 lunar-swift 本地计算）
struct BaZiInfo: Codable, Equatable {
    // 四柱
    let yearPillar: String       // 年柱，如 "甲子"
    let monthPillar: String      // 月柱
    let dayPillar: String        // 日柱
    let timePillar: String       // 时柱

    // 日主（日干）
    let dayStem: String          // 日干，如 "甲"
    let dayStemElement: String   // 日干五行，如 "木"
    let dayStemDescription: String // 如 "甲木"

    // 五行能量得分（加权系统：天干10分 + 地支15分 + 月支40分，地支按藏干比例分配）
    let metalScore: Double       // 金的得分
    let woodScore: Double        // 木的得分
    let waterScore: Double       // 水的得分
    let fireScore: Double        // 火的得分
    let earthScore: Double       // 土的得分
    let elementSummary: String   // 如 "金15.0 木10.5 水28.0 火0.0 土21.5"

    // 缺失与旺衰
    let missingElements: [String]  // 缺失的五行（得分 < 1）
    let strongElements: [String]   // 偏旺的五行（得分 > 35）

    // 喜用神
    let xiYongShen: String       // 喜用神元素，如 "火"
    let xiYongReason: String     // 推断理由

    // 纳音
    let yearNaYin: String        // 年柱纳音，如 "海中金"
    let dayNaYin: String         // 日柱纳音

    // 伴侣年龄推算
    var targetAge: Int?          // 推算的伴侣目标年龄
    var agePreference: String?   // 如 "月柱见夫妻星", "印(无夫妻星)", "default"

    // 十神
    let dominantGod: String      // 命局力量最强的十神（排除比肩/劫财），如 "正官"
    let tenGodSummary: String    // 十神分布摘要，如 "年柱天干:偏印、月柱天干:正财、..."

    // 夫/妻星
    let spouseStarType: String?      // "正财"/"偏财"(男) 或 "正官"/"七杀"(女)，nil=无夫妻星
    let spouseStarPillars: [String]  // 夫/妻星出现的柱位，如 ["月柱", "时柱"]

    /// 判断八字数据是否有效（五行得分总和应大于0）
    var isValid: Bool {
        (metalScore + woodScore + waterScore + fireScore + earthScore) > 0
    }

    // MARK: - 成员初始化器（因为有自定义 init(from decoder:)，需要手动添加）
    init(
        yearPillar: String,
        monthPillar: String,
        dayPillar: String,
        timePillar: String,
        dayStem: String,
        dayStemElement: String,
        dayStemDescription: String,
        metalScore: Double,
        woodScore: Double,
        waterScore: Double,
        fireScore: Double,
        earthScore: Double,
        elementSummary: String,
        missingElements: [String],
        strongElements: [String],
        xiYongShen: String,
        xiYongReason: String,
        yearNaYin: String,
        dayNaYin: String,
        targetAge: Int? = nil,
        agePreference: String? = nil,
        dominantGod: String,
        tenGodSummary: String,
        spouseStarType: String? = nil,
        spouseStarPillars: [String]
    ) {
        self.yearPillar = yearPillar
        self.monthPillar = monthPillar
        self.dayPillar = dayPillar
        self.timePillar = timePillar
        self.dayStem = dayStem
        self.dayStemElement = dayStemElement
        self.dayStemDescription = dayStemDescription
        self.metalScore = metalScore
        self.woodScore = woodScore
        self.waterScore = waterScore
        self.fireScore = fireScore
        self.earthScore = earthScore
        self.elementSummary = elementSummary
        self.missingElements = missingElements
        self.strongElements = strongElements
        self.xiYongShen = xiYongShen
        self.xiYongReason = xiYongReason
        self.yearNaYin = yearNaYin
        self.dayNaYin = dayNaYin
        self.targetAge = targetAge
        self.agePreference = agePreference
        self.dominantGod = dominantGod
        self.tenGodSummary = tenGodSummary
        self.spouseStarType = spouseStarType
        self.spouseStarPillars = spouseStarPillars
    }

    enum CodingKeys: String, CodingKey {
        case yearPillar = "year_pillar"
        case monthPillar = "month_pillar"
        case dayPillar = "day_pillar"
        case timePillar = "time_pillar"
        case dayStem = "day_stem"
        case dayStemElement = "day_stem_element"
        case dayStemDescription = "day_stem_description"
        case metalScore = "metal_score"
        case woodScore = "wood_score"
        case waterScore = "water_score"
        case fireScore = "fire_score"
        case earthScore = "earth_score"
        case elementSummary = "element_summary"
        case missingElements = "missing_elements"
        case strongElements = "strong_elements"
        case xiYongShen = "xi_yong_shen"
        case xiYongReason = "xi_yong_reason"
        case yearNaYin = "year_na_yin"
        case dayNaYin = "day_na_yin"
        case targetAge = "target_age"
        case agePreference = "age_preference"
        case dominantGod = "dominant_god"
        case tenGodSummary = "ten_god_summary"
        case spouseStarType = "spouse_star_type"
        case spouseStarPillars = "spouse_star_pillars"
    }

    // MARK: - 自定义解码器（兼容旧数据）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 四柱（必需字段，提供默认值防止崩溃）
        yearPillar = (try? container.decode(String.self, forKey: .yearPillar)) ?? "未知"
        monthPillar = (try? container.decode(String.self, forKey: .monthPillar)) ?? "未知"
        dayPillar = (try? container.decode(String.self, forKey: .dayPillar)) ?? "未知"
        timePillar = (try? container.decode(String.self, forKey: .timePillar)) ?? "未知"

        // 日主
        dayStem = (try? container.decode(String.self, forKey: .dayStem)) ?? "甲"
        dayStemElement = (try? container.decode(String.self, forKey: .dayStemElement)) ?? "木"
        dayStemDescription = (try? container.decode(String.self, forKey: .dayStemDescription)) ?? "甲木"

        // 五行得分（默认0）
        metalScore = (try? container.decode(Double.self, forKey: .metalScore)) ?? 0
        woodScore = (try? container.decode(Double.self, forKey: .woodScore)) ?? 0
        waterScore = (try? container.decode(Double.self, forKey: .waterScore)) ?? 0
        fireScore = (try? container.decode(Double.self, forKey: .fireScore)) ?? 0
        earthScore = (try? container.decode(Double.self, forKey: .earthScore)) ?? 0
        elementSummary = (try? container.decode(String.self, forKey: .elementSummary)) ?? ""

        // 缺失与旺衰（默认空数组）
        missingElements = (try? container.decode([String].self, forKey: .missingElements)) ?? []
        strongElements = (try? container.decode([String].self, forKey: .strongElements)) ?? []

        // 喜用神
        xiYongShen = (try? container.decode(String.self, forKey: .xiYongShen)) ?? "木"
        xiYongReason = (try? container.decode(String.self, forKey: .xiYongReason)) ?? ""

        // 纳音
        yearNaYin = (try? container.decode(String.self, forKey: .yearNaYin)) ?? ""
        dayNaYin = (try? container.decode(String.self, forKey: .dayNaYin)) ?? ""

        // 伴侣年龄推算（可选）
        targetAge = try? container.decode(Int.self, forKey: .targetAge)
        agePreference = try? container.decode(String.self, forKey: .agePreference)

        // 十神
        dominantGod = (try? container.decode(String.self, forKey: .dominantGod)) ?? "正官"
        tenGodSummary = (try? container.decode(String.self, forKey: .tenGodSummary)) ?? ""

        // 夫/妻星（可选）
        spouseStarType = try? container.decode(String.self, forKey: .spouseStarType)
        spouseStarPillars = (try? container.decode([String].self, forKey: .spouseStarPillars)) ?? []
    }
}

/// 完整的灵魂分析结果
struct SoulAnalysisResult: Codable, Equatable {
    // 命盘信息
    let hexagram: String                  // 卦象名称
    let userElement: String               // 用户五行属性（日主五行）
    var soulmateElement: String           // 伴侣五行属性（var: 允许代码层校正 LLM 覆写）

    // 八字精准命理（本地计算，不由 AI 返回）
    var baziInfo: BaZiInfo?

    // 提示词版本（用于缓存失效）
    var promptVersion: String?

    // 用户分析
    let personalityDescription: String    // 核心性格描述
    let personalityTraits: [String]       // 性格特质标签
    let relationshipBehaviors: [String]   // 感情中的表现
    let emotionalNeeds: [String]          // 情感需求

    // 推导逻辑
    let matchingDeductions: [MatchingDeduction]

    // 伴侣分析
    let soulmateTraits: [String]          // 伴侣特质
    let compatibilityScore: Int           // 契合度
    let destinyType: String               // 缘分类型

    // 伴侣画像描述（详细文字）
    let soulmateAppearance: SoulmateAppearance

    // 生图相关
    let soulmateAnalysis: String
    let promptToken: String    // 服务端令牌，替代明文 image_prompt

    // MARK: - 成员初始化器
    init(
        hexagram: String,
        userElement: String,
        soulmateElement: String,
        baziInfo: BaZiInfo? = nil,
        promptVersion: String? = nil,
        personalityDescription: String,
        personalityTraits: [String],
        relationshipBehaviors: [String],
        emotionalNeeds: [String],
        matchingDeductions: [MatchingDeduction],
        soulmateTraits: [String],
        compatibilityScore: Int,
        destinyType: String,
        soulmateAppearance: SoulmateAppearance,
        soulmateAnalysis: String,
        promptToken: String
    ) {
        self.hexagram = hexagram
        self.userElement = userElement
        self.soulmateElement = soulmateElement
        self.baziInfo = baziInfo
        self.promptVersion = promptVersion
        self.personalityDescription = personalityDescription
        self.personalityTraits = personalityTraits
        self.relationshipBehaviors = relationshipBehaviors
        self.emotionalNeeds = emotionalNeeds
        self.matchingDeductions = matchingDeductions
        self.soulmateTraits = soulmateTraits
        self.compatibilityScore = compatibilityScore
        self.destinyType = destinyType
        self.soulmateAppearance = soulmateAppearance
        self.soulmateAnalysis = soulmateAnalysis
        self.promptToken = promptToken
    }

    enum CodingKeys: String, CodingKey {
        case hexagram
        case userElement = "user_element"
        case soulmateElement = "soulmate_element"
        case baziInfo = "bazi_info"
        case promptVersion = "prompt_version"
        case personalityDescription = "personality_description"
        case personalityTraits = "personality_traits"
        case relationshipBehaviors = "relationship_behaviors"
        case emotionalNeeds = "emotional_needs"
        case matchingDeductions = "matching_deductions"
        case soulmateTraits = "soulmate_traits"
        case compatibilityScore = "compatibility_score"
        case destinyType = "destiny_type"
        case soulmateAppearance = "soulmate_appearance"
        case soulmateAnalysis = "soulmate_analysis"
        case promptToken = "promptToken"
    }

    // MARK: - 自定义解码器（兼容旧数据）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 命盘信息
        hexagram = (try? container.decode(String.self, forKey: .hexagram)) ?? "未知卦象"
        userElement = (try? container.decode(String.self, forKey: .userElement)) ?? "木"
        soulmateElement = (try? container.decode(String.self, forKey: .soulmateElement)) ?? "火"

        // 八字（可选）
        baziInfo = try? container.decode(BaZiInfo.self, forKey: .baziInfo)

        // 用户分析
        personalityDescription = (try? container.decode(String.self, forKey: .personalityDescription)) ?? ""
        personalityTraits = (try? container.decode([String].self, forKey: .personalityTraits)) ?? []
        relationshipBehaviors = (try? container.decode([String].self, forKey: .relationshipBehaviors)) ?? []
        emotionalNeeds = (try? container.decode([String].self, forKey: .emotionalNeeds)) ?? []

        // 推导逻辑
        matchingDeductions = (try? container.decode([MatchingDeduction].self, forKey: .matchingDeductions)) ?? []

        // 伴侣分析
        soulmateTraits = (try? container.decode([String].self, forKey: .soulmateTraits)) ?? []
        compatibilityScore = (try? container.decode(Int.self, forKey: .compatibilityScore)) ?? 80
        destinyType = (try? container.decode(String.self, forKey: .destinyType)) ?? "灵魂共鸣"

        // 伴侣画像描述（使用默认值）
        soulmateAppearance = (try? container.decode(SoulmateAppearance.self, forKey: .soulmateAppearance)) ?? SoulmateAppearance.default

        // 生图相关
        soulmateAnalysis = (try? container.decode(String.self, forKey: .soulmateAnalysis)) ?? ""
        promptToken = (try? container.decode(String.self, forKey: .promptToken)) ?? ""
    }
}

/// 伴侣画像描述（用于生成肖像图）
struct SoulmateAppearance: Codable, Equatable {
    let skinTone: String        // 肤色：白皙/象牙白/小麦色/蜜糖色
    let faceShape: String       // 脸型：鹅蛋脸/瓜子脸/方脸
    let eyes: String            // 眼睛：杏仁眼、双眼皮、眼尾微翘
    let otherFeatures: String   // 其他五官：高挺鼻梁、饱满嘴唇、有酒窝
    let hair: String            // 发型发色：黑色中长发、自然微卷
    let clothing: String        // 衣着材质和颜色：米白色羊绒毛衣

    enum CodingKeys: String, CodingKey {
        case skinTone = "skin_tone"
        case faceShape = "face_shape"
        case eyes
        case otherFeatures = "other_features"
        case hair
        case clothing
    }

    // MARK: - 默认值
    static let `default` = SoulmateAppearance(
        skinTone: "白皙",
        faceShape: "鹅蛋脸",
        eyes: "杏仁眼",
        otherFeatures: "高挺鼻梁",
        hair: "黑色长发",
        clothing: "白色衬衫"
    )

    // MARK: - 成员初始化器
    init(skinTone: String, faceShape: String, eyes: String, otherFeatures: String, hair: String, clothing: String) {
        self.skinTone = skinTone
        self.faceShape = faceShape
        self.eyes = eyes
        self.otherFeatures = otherFeatures
        self.hair = hair
        self.clothing = clothing
    }

    // MARK: - 自定义解码器（兼容旧数据）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        skinTone = (try? container.decode(String.self, forKey: .skinTone)) ?? "白皙"
        faceShape = (try? container.decode(String.self, forKey: .faceShape)) ?? "鹅蛋脸"
        eyes = (try? container.decode(String.self, forKey: .eyes)) ?? "杏仁眼"
        otherFeatures = (try? container.decode(String.self, forKey: .otherFeatures)) ?? "高挺鼻梁"
        hair = (try? container.decode(String.self, forKey: .hair)) ?? "黑色长发"
        clothing = (try? container.decode(String.self, forKey: .clothing)) ?? "白色衬衫"
    }
}

/// 匹配推导逻辑
struct MatchingDeduction: Codable, Equatable {
    let userTrait: String       // 因为你...
    let soulmateTrait: String   // 需要...的人
    let explanation: String?    // 简短解释

    enum CodingKeys: String, CodingKey {
        case userTrait = "user_trait"
        case soulmateTrait = "soulmate_trait"
        case explanation
    }

    // MARK: - 成员初始化器
    init(userTrait: String, soulmateTrait: String, explanation: String? = nil) {
        self.userTrait = userTrait
        self.soulmateTrait = soulmateTrait
        self.explanation = explanation
    }

    // MARK: - 自定义解码器（兼容旧数据）
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userTrait = (try? container.decode(String.self, forKey: .userTrait)) ?? ""
        soulmateTrait = (try? container.decode(String.self, forKey: .soulmateTrait)) ?? ""
        explanation = try? container.decode(String.self, forKey: .explanation)
    }
}
