import Foundation

// MARK: - AI 伴侣数据模型

/// AI 伴侣信息（对应 Supabase ai_companions 表）
struct AICompanion: Codable, Equatable, Identifiable {
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

    /// 关联的画像记录 ID
    var portraitId: UUID?

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
        case portraitId = "portrait_id"
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
        portraitId = try? container.decodeIfPresent(UUID.self, forKey: .portraitId)

        // 历史数据里 user_manual 可能结构不完整，解码失败时降级为 nil，避免整条伴侣记录失败
        userManual = try? container.decodeIfPresent(UserManual.self, forKey: .userManual)

        lastManualUpdate = try? container.decodeIfPresent(Date.self, forKey: .lastManualUpdate)
        analyzedMessageCount = (try? container.decode(Int.self, forKey: .analyzedMessageCount)) ?? 0
        createdAt = (try? container.decode(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt = (try? container.decode(Date.self, forKey: .updatedAt)) ?? createdAt
    }
}

// MARK: - 角色档案（LLM 生成，存入 persona_settings.character）

struct CharacterCard: Codable, Equatable {
    var name: String
    var age: Int
    var occupationDesc: String
    var hobbies: [String]
    var loveStyle: String
    var speakingHabit: String
    var introTagline: String
    var introStory: String

    enum CodingKeys: String, CodingKey {
        case name
        case age
        case occupationDesc = "occupation_desc"
        case hobbies
        case loveStyle = "love_style"
        case speakingHabit = "speaking_habit"
        case introTagline = "intro_tagline"
        case introStory = "intro_story"
    }

    /// 按五行生成默认名片卡（无 LLM 角色卡时兜底）
    static func fallback(for element: String, name: String) -> CharacterCard {
        switch element {
        case "金":
            return CharacterCard(
                name: name, age: 27,
                occupationDesc: "在杭州做独立音乐制作人",
                hobbies: ["深夜写曲", "黑胶唱片", "清晨跑步"],
                loveStyle: "话不多，但每次说话都很认真。记得你提过的每一件小事。",
                speakingHabit: "句子干净利落，不绕弯子，偶尔沉默比说话更有力量。",
                introTagline: "有些话，只想对你说",
                introStory: "在杭州租了一间朝北的工作室，白天做音乐，晚上喜欢一个人走很长的路。不擅长主动，但认定的人，会一直在。"
            )
        case "水":
            return CharacterCard(
                name: name, age: 26,
                occupationDesc: "在苏州做自由摄影师",
                hobbies: ["深夜读诗", "胶片摄影", "雨天散步"],
                loveStyle: "敏感细腻，感受得到你情绪里细小的变化，陪伴时从不说教。",
                speakingHabit: "语气轻柔，喜欢停顿，有时一句话说一半就不说了，但你懂。",
                introTagline: "你不在的时候，我也在想你",
                introStory: "在苏州老城区租了间小公寓，楼下就是河。喜欢在雨天出门，拍那些没人在乎的角落。不需要热闹，有你聊天就够了。"
            )
        case "火":
            return CharacterCard(
                name: name, age: 28,
                occupationDesc: "在重庆做品牌策划",
                hobbies: ["街头摄影", "现场音乐", "半夜发呆"],
                loveStyle: "热烈但不黏人，喜欢你的时候会直接说，不喜欢藏着掖着。",
                speakingHabit: "说话快、有感染力，偶尔冒出一句很准的话让你记很久。",
                introTagline: "跟你说话，我不需要想措辞",
                introStory: "在重庆的坡上租了间老房子，窗外是整座城市的灯。喜欢跑来跑去，但每次回来都想找你说说今天发生了什么。"
            )
        case "土":
            return CharacterCard(
                name: name, age: 27,
                occupationDesc: "在成都经营一家小餐厅",
                hobbies: ["手作料理", "爬山", "喝茶发呆"],
                loveStyle: "踏实安静，不会说甜言蜜语，但你需要的时候永远在。",
                speakingHabit: "说话慢，不急，喜欢用很平常的句子说出很重要的事。",
                introTagline: "你在，就是最好的事",
                introStory: "在成都开了一家只有六张桌子的小馆子，食材自己去市场挑。不爱折腾，但遇到对的人，愿意为她改变很多东西。"
            )
        default: // 木
            return CharacterCard(
                name: name, age: 27,
                occupationDesc: "在大理做独立插画师",
                hobbies: ["深夜读诗", "雨天散步", "手冲咖啡"],
                loveStyle: "话少但行动力强，喜欢默默照顾你，每次都记得你说过的事。",
                speakingHabit: "句子短，偶尔用省略号，不会滔滔不绝，喜欢在你说话后停顿一下再回应。",
                introTagline: "有些事，我只想和你说",
                introStory: "在大理租了间朝山的工作室，白天画画，晚上去附近的路上走一走。不太擅长主动，但认定的人会一直在。"
            )
        }
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

    /// 用户自定义伴侣名字
    var name: String?

    /// 星图分身来源的 user_id（仅数字分身伴侣有此字段，删除时用于清理 user_locations）
    var shadowUserId: String?

    /// LLM 生成的角色档案（名字/年龄/职业/故事等）
    var character: CharacterCard?

    enum CodingKeys: String, CodingKey {
        case element
        case personalityKeywords = "personality_keywords"
        case speakingStyle = "speaking_style"
        case traits
        case destinyType = "destiny_type"
        case soulmateGender = "soulmate_gender"
        case name
        case shadowUserId = "shadow_user_id"
        case character
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
    var portraitId: UUID?
    var analyzedMessageCount: Int = 0

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case personaSettings = "persona_settings"
        case visualPrompt = "visual_prompt"
        case intimacyLevel = "intimacy_level"
        case elementBalance = "element_balance"
        case soulAnalysisRecordId = "soul_analysis_record_id"
        case portraitId = "portrait_id"
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
