import Foundation

// MARK: - AI 伴侣数据模型

/// AI 伴侣信息（对应 Supabase ai_companions 表）
struct AICompanion: Codable, Equatable {
    let id: UUID
    let userId: UUID

    /// 人设设定
    var personaSettings: PersonaSettings

    /// 画像生成 prompt
    var visualPrompt: String?

    /// 亲密度/羁绊值 (0-100)
    var intimacyLevel: Int

    /// 五行平衡值
    var elementBalance: ElementBalance

    /// 关联的灵魂分析记录 ID
    var soulAnalysisRecordId: UUID?

    /// 用户喜好说明书（从聊天记录分析生成）
    var userManual: UserManual?

    /// 用户手册最后更新时间
    var lastManualUpdate: Date?

    /// 已分析的消息数量
    var analyzedMessageCount: Int

    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case personaSettings = "persona_settings"
        case visualPrompt = "visual_prompt"
        case intimacyLevel = "intimacy_level"
        case elementBalance = "element_balance"
        case soulAnalysisRecordId = "soul_analysis_record_id"
        case userManual = "user_manual"
        case lastManualUpdate = "last_manual_update"
        case analyzedMessageCount = "analyzed_message_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        personaSettings = (try? container.decode(PersonaSettings.self, forKey: .personaSettings)) ?? .default
        visualPrompt = try? container.decodeIfPresent(String.self, forKey: .visualPrompt)
        intimacyLevel = (try? container.decode(Int.self, forKey: .intimacyLevel)) ?? 0
        elementBalance = (try? container.decode(ElementBalance.self, forKey: .elementBalance)) ?? .default
        soulAnalysisRecordId = try? container.decodeIfPresent(UUID.self, forKey: .soulAnalysisRecordId)

        // 历史数据里 user_manual 可能结构不完整，解码失败时降级为 nil，避免整条伴侣记录失败
        userManual = try? container.decodeIfPresent(UserManual.self, forKey: .userManual)

        lastManualUpdate = try? container.decodeIfPresent(Date.self, forKey: .lastManualUpdate)
        analyzedMessageCount = (try? container.decode(Int.self, forKey: .analyzedMessageCount)) ?? 0
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt = (try? container.decode(Date.self, forKey: .updatedAt)) ?? createdAt
    }
}

/// 人设设定
struct PersonaSettings: Codable, Equatable {
    /// 五行属性（金/木/水/火/土）
    var element: String

    /// 性格关键词（如：温柔、外冷内热、理性）
    var personalityKeywords: [String]

    /// 说话风格描述
    var speakingStyle: String

    /// 伴侣特质（从灵魂分析继承）
    var traits: [String]

    /// 缘分类型
    var destinyType: String?

    /// 伴侣性别（可选，兼容旧数据）
    var soulmateGender: String?

    enum CodingKeys: String, CodingKey {
        case element
        case personalityKeywords = "personality_keywords"
        case speakingStyle = "speaking_style"
        case traits
        case destinyType = "destiny_type"
        case soulmateGender = "soulmate_gender"
    }

    /// 默认设定
    static let `default` = PersonaSettings(
        element: "木",
        personalityKeywords: ["温柔", "包容", "善解人意"],
        speakingStyle: "说话温暖不急不躁，习惯鼓励人，给人安全感。语气平和有耐心，让人觉得什么都能聊。",
        traits: ["体贴", "耐心"]
    )
}

/// 五行平衡值（用于调教 AI 回复风格）
struct ElementBalance: Codable, Equatable {
    var metal: Int  // 金 - 理性、冷静、条理
    var wood: Int   // 木 - 温和、生机、成长
    var water: Int  // 水 - 温柔、包容、智慧
    var fire: Int   // 火 - 热情、主动、激情
    var earth: Int  // 土 - 稳重、踏实、安心

    /// 默认平衡（各 20%）
    static let `default` = ElementBalance(
        metal: 20, wood: 20, water: 20, fire: 20, earth: 20
    )

    /// 获取主导元素
    var dominantElement: String {
        let elements = [
            ("金", metal), ("木", wood), ("水", water), ("火", fire), ("土", earth)
        ]
        return elements.max(by: { $0.1 < $1.1 })?.0 ?? "木"
    }

    /// 获取各元素的中文描述
    func getStyleDescription() -> String {
        var styles: [String] = []
        if metal > 25 { styles.append("理性冷静") }
        if wood > 25 { styles.append("温和有生机") }
        if water > 25 { styles.append("温柔包容") }
        if fire > 25 { styles.append("热情主动") }
        if earth > 25 { styles.append("稳重踏实") }
        return styles.isEmpty ? "平衡自然" : styles.joined(separator: "、")
    }
}

// MARK: - 聊天历史数据模型

/// 聊天记录（对应 Supabase chat_history 表）
struct ChatHistoryRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let companionId: UUID

    /// 角色：user 或 ai
    let role: String

    /// 消息内容
    let content: String

    /// 标签（如：resonance, favorite）
    var tags: [String]

    /// 是否被用户标记为"有共鸣"
    var isLiked: Bool

    /// 情感倾向
    var sentiment: String?

    /// 触发此回复时的五行设置快照
    var elementContext: ElementBalance?

    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case companionId = "companion_id"
        case role
        case content
        case tags
        case isLiked = "is_liked"
        case sentiment
        case elementContext = "element_context"
        case createdAt = "created_at"
    }
}

// MARK: - 插入用的结构（不含服务端生成的字段）

/// 创建 AI 伴侣时的输入数据
struct AICompanionInsert: Codable {
    let userId: UUID
    var personaSettings: PersonaSettings
    var visualPrompt: String?
    var intimacyLevel: Int = 0
    var elementBalance: ElementBalance = .default
    var soulAnalysisRecordId: UUID?
    var analyzedMessageCount: Int = 0

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case personaSettings = "persona_settings"
        case visualPrompt = "visual_prompt"
        case intimacyLevel = "intimacy_level"
        case elementBalance = "element_balance"
        case soulAnalysisRecordId = "soul_analysis_record_id"
        case analyzedMessageCount = "analyzed_message_count"
    }
}

/// 创建聊天记录时的输入数据
struct ChatHistoryInsert: Codable {
    let userId: UUID
    let companionId: UUID
    let role: String
    let content: String
    var tags: [String] = []
    var isLiked: Bool = false
    var sentiment: String?
    var elementContext: ElementBalance?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case companionId = "companion_id"
        case role
        case content
        case tags
        case isLiked = "is_liked"
        case sentiment
        case elementContext = "element_context"
    }
}
