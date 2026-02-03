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

    // 五行能量分布
    let metalCount: Int          // 金的个数
    let woodCount: Int           // 木的个数
    let waterCount: Int          // 水的个数
    let fireCount: Int           // 火的个数
    let earthCount: Int          // 土的个数
    let elementSummary: String   // 如 "金2 木1 水3 火0 土2"

    // 缺失与旺衰
    let missingElements: [String]  // 缺失的五行
    let strongElements: [String]   // 偏旺的五行

    // 喜用神
    let xiYongShen: String       // 喜用神元素，如 "火"
    let xiYongReason: String     // 推断理由

    // 纳音
    let yearNaYin: String        // 年柱纳音，如 "海中金"
    let dayNaYin: String         // 日柱纳音

    enum CodingKeys: String, CodingKey {
        case yearPillar = "year_pillar"
        case monthPillar = "month_pillar"
        case dayPillar = "day_pillar"
        case timePillar = "time_pillar"
        case dayStem = "day_stem"
        case dayStemElement = "day_stem_element"
        case dayStemDescription = "day_stem_description"
        case metalCount = "metal_count"
        case woodCount = "wood_count"
        case waterCount = "water_count"
        case fireCount = "fire_count"
        case earthCount = "earth_count"
        case elementSummary = "element_summary"
        case missingElements = "missing_elements"
        case strongElements = "strong_elements"
        case xiYongShen = "xi_yong_shen"
        case xiYongReason = "xi_yong_reason"
        case yearNaYin = "year_na_yin"
        case dayNaYin = "day_na_yin"
    }
}

/// 完整的灵魂分析结果
struct SoulAnalysisResult: Codable, Equatable {
    // 命盘信息
    let hexagram: String                  // 卦象名称
    let userElement: String               // 用户五行属性（日主五行）
    let soulmateElement: String           // 伴侣五行属性

    // 八字精准命理（本地计算，不由 AI 返回）
    var baziInfo: BaZiInfo?

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
    let imagePrompt: String

    enum CodingKeys: String, CodingKey {
        case hexagram
        case userElement = "user_element"
        case soulmateElement = "soulmate_element"
        case baziInfo = "bazi_info"
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
        case imagePrompt = "image_prompt"
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
}
