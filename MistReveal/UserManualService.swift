import Foundation
import Supabase

// MARK: - 用户喜好说明书模型

/// 用户喜好说明书（从聊天记录分析生成）
struct UserManual: Codable, Equatable {
    /// 性格特点笔记
    var personalityNotes: [String]

    /// 用户喜好（喜欢什么样的回复/话题）
    var preferences: [String]

    /// 情感需求
    var emotionalNeeds: [String]

    /// 沟通风格偏好
    var communicationStyle: CommunicationStyle

    /// 雷点（用户不喜欢的）
    var redFlags: [String]

    /// 加分项（用户特别喜欢的）
    var greenFlags: [String]

    /// 一句话总结
    var summary: String

    /// 最后更新时间
    var lastUpdated: Date?

    /// 分析时的消息数量
    var analyzedMessageCount: Int

    enum CodingKeys: String, CodingKey {
        case personalityNotes = "personality_notes"
        case preferences
        case emotionalNeeds = "emotional_needs"
        case communicationStyle = "communication_style"
        case redFlags = "red_flags"
        case greenFlags = "green_flags"
        case summary
        case lastUpdated = "last_updated"
        case analyzedMessageCount = "analyzed_message_count"
    }

    init(
        personalityNotes: [String],
        preferences: [String],
        emotionalNeeds: [String],
        communicationStyle: CommunicationStyle,
        redFlags: [String],
        greenFlags: [String],
        summary: String,
        lastUpdated: Date?,
        analyzedMessageCount: Int
    ) {
        self.personalityNotes = personalityNotes
        self.preferences = preferences
        self.emotionalNeeds = emotionalNeeds
        self.communicationStyle = communicationStyle
        self.redFlags = redFlags
        self.greenFlags = greenFlags
        self.summary = summary
        self.lastUpdated = lastUpdated
        self.analyzedMessageCount = analyzedMessageCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        personalityNotes = (try? container.decode([String].self, forKey: .personalityNotes)) ?? []
        preferences = (try? container.decode([String].self, forKey: .preferences)) ?? []
        emotionalNeeds = (try? container.decode([String].self, forKey: .emotionalNeeds)) ?? []
        communicationStyle = (try? container.decode(CommunicationStyle.self, forKey: .communicationStyle)) ?? .balanced
        redFlags = (try? container.decode([String].self, forKey: .redFlags)) ?? []
        greenFlags = (try? container.decode([String].self, forKey: .greenFlags)) ?? []
        summary = (try? container.decode(String.self, forKey: .summary)) ?? "尚未收集足够的对话数据"
        lastUpdated = try? container.decode(Date.self, forKey: .lastUpdated)
        analyzedMessageCount = (try? container.decode(Int.self, forKey: .analyzedMessageCount)) ?? 0
    }

    /// 默认空手册
    static let empty = UserManual(
        personalityNotes: [],
        preferences: [],
        emotionalNeeds: [],
        communicationStyle: .balanced,
        redFlags: [],
        greenFlags: [],
        summary: "尚未收集足够的对话数据",
        lastUpdated: nil,
        analyzedMessageCount: 0
    )
}

/// 沟通风格偏好
enum CommunicationStyle: String, Codable {
    case direct = "direct"           // 直接了当
    case gentle = "gentle"           // 温柔委婉
    case humorous = "humorous"       // 幽默风趣
    case deep = "deep"               // 深度交流
    case supportive = "supportive"   // 支持鼓励型
    case balanced = "balanced"       // 平衡型

    var description: String {
        switch self {
        case .direct: return "喜欢直接了当的沟通"
        case .gentle: return "偏好温柔委婉的表达"
        case .humorous: return "喜欢幽默风趣的互动"
        case .deep: return "倾向深度情感交流"
        case .supportive: return "需要支持鼓励型的回应"
        case .balanced: return "沟通风格较为平衡"
        }
    }
}

// MARK: - 用户手册服务

/// 用户手册服务 - 分析聊天记录生成用户画像
class UserManualService {

    static let shared = UserManualService()

    /// 触发更新的消息阈值
    private let updateThreshold = 12

    /// 最小更新间隔（小时）
    private let minUpdateIntervalHours = 6

    private init() {}

    // MARK: - 核心函数：更新用户手册

    /// 检查并更新用户手册
    /// - Parameters:
    ///   - companion: 用户的 AI 伴侣
    ///   - chatHistory: 聊天记录
    ///   - forceUpdate: 是否强制更新（忽略阈值）
    /// - Returns: 更新后的用户手册，如果无需更新则返回 nil
    func updateUserManualIfNeeded(
        companion: AICompanion,
        chatHistory: [ChatHistoryRecord],
        forceUpdate: Bool = false
    ) async -> UserManual? {

        let totalMessages = chatHistory.count
        let analyzedCount = companion.analyzedMessageCount
        let newMessages = totalMessages - analyzedCount

        // 检查是否需要更新
        if !forceUpdate {
            // 条件1：新消息数量达到阈值
            guard newMessages >= updateThreshold else {
                print("📊 [UserManual] 新消息不足 \(updateThreshold) 条，跳过更新 (当前: \(newMessages))")
                return nil
            }

            // 条件2：距离上次更新超过最小间隔
            if let lastUpdate = companion.lastManualUpdate {
                let hoursSinceUpdate = Date().timeIntervalSince(lastUpdate) / 3600
                guard hoursSinceUpdate >= Double(minUpdateIntervalHours) else {
                    print("📊 [UserManual] 距上次更新不足 \(minUpdateIntervalHours) 小时，跳过")
                    return nil
                }
            }
        }

        print("📊 [UserManual] 开始分析 \(totalMessages) 条聊天记录...")

        // 调用 LLM 分析
        do {
            let manual = try await analyzeChatHistory(chatHistory)
            print("✅ [UserManual] 用户手册生成成功")
            print("   - 性格特点: \(manual.personalityNotes.joined(separator: ", "))")
            print("   - 沟通风格: \(manual.communicationStyle.description)")
            print("   - 总结: \(manual.summary)")
            return manual
        } catch {
            print("❌ [UserManual] 分析失败: \(error)")
            return nil
        }
    }

    // MARK: - LLM 分析聊天记录

    /// 调用 LLM 分析聊天记录，生成用户手册
    private func analyzeChatHistory(_ history: [ChatHistoryRecord]) async throws -> UserManual {

        // 准备聊天记录文本
        let chatText = prepareChatText(from: history)

        // 标记用户喜欢的消息
        let likedMessages = history.filter { $0.isLiked && $0.role == "ai" }
        let likedText = likedMessages.map { "- \($0.content)" }.joined(separator: "\n")

        // 构建分析 Prompt
        let systemPrompt = """
        你是一个用户行为分析专家。你的任务是分析用户与 AI 伴侣的聊天记录，生成一份《用户喜好说明书》。

        这份说明书将用于：
        1. 让 AI 伴侣更好地理解和回应用户
        2. 未来为用户匹配真人伴侣时作为参考

        请从以下维度分析：

        1. **性格特点** (personality_notes)
           - 用户是内向还是外向？
           - 情绪表达方式如何？
           - 处理问题的态度？

        2. **喜好偏好** (preferences)
           - 喜欢聊什么话题？
           - 对回复长度/风格的偏好？
           - 什么让 ta 开心？

        3. **情感需求** (emotional_needs)
           - 用户在寻找什么样的情感支持？
           - 什么时候最需要陪伴？
           - 安全感来源是什么？

        4. **沟通风格** (communication_style)
           - direct: 喜欢直接了当
           - gentle: 偏好温柔委婉
           - humorous: 喜欢幽默风趣
           - deep: 倾向深度交流
           - supportive: 需要支持鼓励型
           - balanced: 较为平衡

        5. **雷点** (red_flags)
           - 用户明显不喜欢什么？
           - 什么话题/方式会让 ta 不舒服？
           - 要避免什么？

        6. **加分项** (green_flags)
           - 什么让用户特别有共鸣？
           - 什么方式的回复被点赞？
           - 什么能快速拉近距离？

        7. **一句话总结** (summary)
           - 用一句话概括这个用户的核心特点和需求

        请用 JSON 格式输出，确保可以被解析。
        """

        let userMessage = """
        ## 聊天记录

        \(chatText)

        ## 用户标记为「有共鸣」的回复

        \(likedText.isEmpty ? "暂无标记" : likedText)

        ---

        请分析以上内容，生成《用户喜好说明书》。

        输出格式（JSON）：
        ```json
        {
            "personality_notes": ["特点1", "特点2", ...],
            "preferences": ["喜好1", "喜好2", ...],
            "emotional_needs": ["需求1", "需求2", ...],
            "communication_style": "gentle",
            "red_flags": ["雷点1", "雷点2", ...],
            "green_flags": ["加分项1", "加分项2", ...],
            "summary": "一句话总结"
        }
        ```
        """

        // 调用阿里云百炼 API
        let manual = try await callLLMForAnalysis(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            messageCount: history.count
        )

        return manual
    }

    /// 准备聊天记录文本（限制长度，保留关键信息）
    private func prepareChatText(from history: [ChatHistoryRecord]) -> String {
        // 最多取最近 100 条消息
        let recentMessages = history.suffix(100)

        var chatLines: [String] = []

        for message in recentMessages {
            let role = message.role == "user" ? "用户" : "AI"
            let liked = message.isLiked ? " [有共鸣]" : ""
            let line = "[\(role)]\(liked): \(message.content)"
            chatLines.append(line)
        }

        return chatLines.joined(separator: "\n")
    }

    /// 调用 LLM API 进行分析
    private func callLLMForAnalysis(
        systemPrompt: String,
        userMessage: String,
        messageCount: Int
    ) async throws -> UserManual {

        guard let apiKey = await SecretsManager.shared.getSecret("ALIYUN_BAILIAN_API_KEY") else {
            throw UserManualError.apiKeyMissing
        }

        let url = URL(string: "\(AppConfig.AliyunBailian.baseURL)/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "model": AppConfig.AliyunBailian.model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userMessage]
            ],
            "response_format": ["type": "json_object"]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw UserManualError.apiError
        }

        // 解析响应
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String,
              let contentData = content.data(using: .utf8) else {
            throw UserManualError.parseError
        }

        // 解析 LLM 返回的 JSON
        let manualResponse = try JSONDecoder().decode(UserManualResponse.self, from: contentData)

        // 转换为 UserManual
        let manual = UserManual(
            personalityNotes: manualResponse.personalityNotes,
            preferences: manualResponse.preferences,
            emotionalNeeds: manualResponse.emotionalNeeds,
            communicationStyle: CommunicationStyle(rawValue: manualResponse.communicationStyle) ?? .balanced,
            redFlags: manualResponse.redFlags,
            greenFlags: manualResponse.greenFlags,
            summary: manualResponse.summary,
            lastUpdated: Date(),
            analyzedMessageCount: messageCount
        )

        return manual
    }

    // MARK: - 保存用户手册

    /// 保存用户手册到数据库
    func saveUserManual(_ manual: UserManual, companionId: UUID) async throws {
        let updatePayload = UserManualUpdate(
            user_manual: manual,
            last_manual_update: ISO8601DateFormatter().string(from: Date()),
            analyzed_message_count: manual.analyzedMessageCount
        )

        try await supabase
            .from("ai_companions")
            .update(updatePayload)
            .eq("id", value: companionId.uuidString)
            .execute()

        print("✅ [UserManual] 用户手册已保存到数据库")
    }

    // MARK: - 生成匹配用的简介

    /// 根据用户手册生成用于真人匹配的简介
    func generateMatchingProfile(from manual: UserManual) -> String {
        """
        【用户画像】

        性格特点：\(manual.personalityNotes.joined(separator: "、"))

        沟通风格：\(manual.communicationStyle.description)

        情感需求：\(manual.emotionalNeeds.joined(separator: "、"))

        喜欢的互动方式：\(manual.greenFlags.joined(separator: "、"))

        需要注意：\(manual.redFlags.joined(separator: "、"))

        一句话：\(manual.summary)
        """
    }

    // MARK: - 错误类型

    enum UserManualError: LocalizedError {
        case apiKeyMissing
        case apiError
        case parseError

        var errorDescription: String? {
            switch self {
            case .apiKeyMissing: return "API 密钥缺失"
            case .apiError: return "API 调用失败"
            case .parseError: return "解析响应失败"
            }
        }
    }
}

// MARK: - LLM 响应模型

/// LLM 返回的用户手册 JSON 结构
private struct UserManualResponse: Codable {
    let personalityNotes: [String]
    let preferences: [String]
    let emotionalNeeds: [String]
    let communicationStyle: String
    let redFlags: [String]
    let greenFlags: [String]
    let summary: String

    enum CodingKeys: String, CodingKey {
        case personalityNotes = "personality_notes"
        case preferences
        case emotionalNeeds = "emotional_needs"
        case communicationStyle = "communication_style"
        case redFlags = "red_flags"
        case greenFlags = "green_flags"
        case summary
    }
}

// MARK: - Supabase Update Struct

/// 用于更新用户手册的结构体
private struct UserManualUpdate: Codable {
    let user_manual: UserManual
    let last_manual_update: String
    let analyzed_message_count: Int
}
