import Foundation

/// 完整的灵魂分析结果
struct SoulAnalysisResult: Codable, Equatable {
    // 命盘信息
    let hexagram: String                  // 卦象名称
    let userElement: String               // 用户五行属性
    let soulmateElement: String           // 伴侣五行属性

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
