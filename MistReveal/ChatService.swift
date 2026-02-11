import Foundation
import Supabase

// MARK: - 聊天错误枚举
enum ChatError: Error, LocalizedError {
    case notAuthenticated
    case insertFailed
    case networkError(String)
    case conversationNotFound
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "用户未登录，请重新登录"
        case .insertFailed:
            return "消息发送失败，请重试"
        case .networkError(let message):
            return "网络错误: \(message)"
        case .conversationNotFound:
            return "对话不存在"
        case .unknown(let message):
            return "未知错误: \(message)"
        }
    }
}

/// 聊天服务 - 处理对话和消息
@MainActor
class ChatService: ObservableObject {

    static let shared = ChatService()

    // MARK: - 发布属性

    @Published var currentConversation: Conversation?
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastError: ChatError?  // 最后一次错误

    // MARK: - 数据模型

    struct Conversation: Codable, Identifiable {
        let id: String
        let user1Id: String
        let user2Id: String
        let status: String
        let createdAt: String
        let lastMessageAt: String?

        enum CodingKeys: String, CodingKey {
            case id
            case user1Id = "user1_id"
            case user2Id = "user2_id"
            case status
            case createdAt = "created_at"
            case lastMessageAt = "last_message_at"
        }

        /// 获取对方的用户ID
        func otherUserId(myId: String) -> String {
            return myId == user1Id ? user2Id : user1Id
        }
    }

    struct Message: Codable, Identifiable, Equatable {
        let id: String
        let conversationId: String
        let senderId: String
        let content: String
        let messageType: String
        let isRead: Bool
        let createdAt: String

        enum CodingKeys: String, CodingKey {
            case id
            case conversationId = "conversation_id"
            case senderId = "sender_id"
            case content
            case messageType = "message_type"
            case isRead = "is_read"
            case createdAt = "created_at"
        }

        var isIceBreaker: Bool {
            // 兼容多种拼写格式
            let type = messageType.lowercased()
            return type == "ice_breaker" || type == "icebreaker" || type == "ice-breaker"
        }

        var isSystem: Bool {
            messageType == "system"
        }

        var formattedTime: String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            guard let date = formatter.date(from: createdAt) else {
                // 尝试不带毫秒的格式
                formatter.formatOptions = [.withInternetDateTime]
                guard let date = formatter.date(from: createdAt) else {
                    return ""
                }
                return formatDate(date)
            }
            return formatDate(date)
        }

        private func formatDate(_ date: Date) -> String {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "HH:mm"
            return displayFormatter.string(from: date)
        }
    }

    struct NewMessage: Codable {
        let conversationId: String
        let senderId: String
        let content: String
        let messageType: String

        enum CodingKeys: String, CodingKey {
            case conversationId = "conversation_id"
            case senderId = "sender_id"
            case content
            case messageType = "message_type"
        }
    }

    struct NewConversation: Codable {
        let user1Id: String
        let user2Id: String

        enum CodingKeys: String, CodingKey {
            case user1Id = "user1_id"
            case user2Id = "user2_id"
        }
    }

    struct IceBreaker: Codable {
        let conversationId: String
        let topics: [String]

        enum CodingKeys: String, CodingKey {
            case conversationId = "conversation_id"
            case topics
        }
    }

    private var realtimeChannel: RealtimeChannelV2?

    // MARK: - 初始化

    private init() {}

    // MARK: - 公开方法

    /// 获取或创建与指定用户的对话
    func getOrCreateConversation(with otherUserId: String) async -> Conversation? {
        print("🔵 [ChatService] getOrCreateConversation - otherUserId: \(otherUserId)")

        guard let myId = await getCurrentUserId() else {
            print("❌ [ChatService] 用户未登录")
            return nil
        }

        print("🔵 [ChatService] 我的ID: \(myId)")

        isLoading = true
        defer { isLoading = false }

        do {
            // 先查找是否已有对话（两种顺序都要查）
            print("🔵 [ChatService] 查找已有对话...")
            let existing: [Conversation] = try await supabase
                .from("conversations")
                .select()
                .or("and(user1_id.eq.\(myId),user2_id.eq.\(otherUserId)),and(user1_id.eq.\(otherUserId),user2_id.eq.\(myId))")
                .execute()
                .value

            if let conversation = existing.first {
                print("✅ [ChatService] 找到已有对话: \(conversation.id)")
                currentConversation = conversation
                return conversation
            }

            // 创建新对话
            print("🔵 [ChatService] 创建新对话...")
            let newConv = NewConversation(user1Id: myId, user2Id: otherUserId)
            let created: [Conversation] = try await supabase
                .from("conversations")
                .insert(newConv)
                .select()
                .execute()
                .value

            if let conversation = created.first {
                print("✅ [ChatService] 创建新对话: \(conversation.id)")
                currentConversation = conversation
                return conversation
            }

            return nil
        } catch {
            print("❌ [ChatService] 获取/创建对话失败: \(error)")
            errorMessage = "无法创建对话"
            return nil
        }
    }

    /// 生成破冰话题
    func generateIceBreakers(
        myElement: String,
        myTraits: [String],
        theirElement: String,
        theirTraits: [String],
        matchScore: Int
    ) async -> [String] {
        let prompt = """
        你是一个社交破冰专家。根据两个用户的灵魂档案，生成3个有趣的破冰话题。

        用户A（我）：
        - 五行：\(myElement)命
        - 性格特质：\(myTraits.joined(separator: "、"))

        用户B（对方）：
        - 五行：\(theirElement)命
        - 性格特质：\(theirTraits.joined(separator: "、"))

        匹配度：\(matchScore)%

        要求：
        1. 话题要有趣、轻松，避免太严肃
        2. 结合双方特质找共同点或有趣对比
        3. 每个话题不超过25字，要像朋友聊天的开场白
        4. 可以用emoji增加趣味
        5. 直接返回3个话题，每行一个，不要序号
        """

        do {
            let topics = try await callTextGeneration(prompt: prompt)
            let topicList = topics
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(3)

            return Array(topicList)
        } catch {
            print("❌ [ChatService] 生成破冰话题失败: \(error)")
            // 返回默认话题
            return [
                "你平时喜欢做什么放松呢？",
                "最近有什么开心的事想分享吗？",
                "你相信命运的安排吗？"
            ]
        }
    }

    /// 保存破冰话题
    func saveIceBreakers(conversationId: String, topics: [String]) async {
        let iceBreaker = IceBreaker(conversationId: conversationId, topics: topics)

        do {
            try await supabase
                .from("ice_breakers")
                .insert(iceBreaker)
                .execute()
            print("✅ [ChatService] 保存破冰话题成功")
        } catch {
            print("❌ [ChatService] 保存破冰话题失败: \(error)")
        }
    }

    /// 发送消息 - 返回 Result 类型，提供详细错误信息
    func sendMessage(conversationId: String, content: String, type: String = "text") async -> Result<Message, ChatError> {
        print("🔵 [ChatService] sendMessage 开始 - conversationId: \(conversationId), type: \(type)")

        // 1. 检查登录状态
        guard let senderId = await getCurrentUserId() else {
            print("❌ [ChatService] 用户未登录 - getCurrentUserId 返回 nil")
            lastError = .notAuthenticated
            return .failure(.notAuthenticated)
        }

        print("🔵 [ChatService] 当前用户ID: \(senderId)")

        let newMessage = NewMessage(
            conversationId: conversationId,
            senderId: senderId,
            content: content,
            messageType: type
        )

        // 2. 发送消息到数据库
        do {
            print("🔵 [ChatService] 正在插入消息到数据库...")
            let inserted: [Message] = try await supabase
                .from("messages")
                .insert(newMessage)
                .select()
                .execute()
                .value

            guard let message = inserted.first else {
                print("❌ [ChatService] 插入成功但返回为空")
                lastError = .insertFailed
                return .failure(.insertFailed)
            }

            // 本地添加消息（实时订阅也会收到，但先本地显示更快）
            if !messages.contains(where: { $0.id == message.id }) {
                messages.append(message)
                print("✅ [ChatService] 消息已添加到本地列表")
            }

            // 更新对话的最后消息时间
            do {
                try await supabase
                    .from("conversations")
                    .update(["last_message_at": ISO8601DateFormatter().string(from: Date())])
                    .eq("id", value: conversationId)
                    .execute()
                print("✅ [ChatService] 对话时间戳已更新")
            } catch {
                // 更新时间戳失败不影响主流程
                print("⚠️ [ChatService] 更新对话时间戳失败（非致命）: \(error)")
            }

            print("✅ [ChatService] 发送消息成功 - messageId: \(message.id)")
            lastError = nil
            return .success(message)

        } catch {
            let errorMsg = error.localizedDescription
            print("❌ [ChatService] 发送消息失败: \(error)")
            print("❌ [ChatService] 错误详情: \(errorMsg)")
            lastError = .networkError(errorMsg)
            errorMessage = "发送失败: \(errorMsg)"
            return .failure(.networkError(errorMsg))
        }
    }

    /// 发送消息 - 兼容旧的 Bool 返回值接口
    func sendMessageLegacy(conversationId: String, content: String, type: String = "text") async -> Bool {
        let result = await sendMessage(conversationId: conversationId, content: content, type: type)
        switch result {
        case .success:
            return true
        case .failure:
            return false
        }
    }

    /// 发送 AI 消息（测试用户自动回复）
    func sendAIMessage(conversationId: String, content: String, testUserId: String) async -> Bool {
        let newMessage = NewMessage(
            conversationId: conversationId,
            senderId: testUserId,  // 使用测试用户的 ID
            content: content,
            messageType: "ai"
        )

        do {
            let inserted: [Message] = try await supabase
                .from("messages")
                .insert(newMessage)
                .select()
                .execute()
                .value

            if let message = inserted.first {
                // 本地添加消息
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                }

                // 更新对话的最后消息时间
                try await supabase
                    .from("conversations")
                    .update(["last_message_at": ISO8601DateFormatter().string(from: Date())])
                    .eq("id", value: conversationId)
                    .execute()

                print("✅ [ChatService] 发送 AI 消息成功")
                return true
            }
            return false
        } catch {
            print("❌ [ChatService] 发送 AI 消息失败: \(error)")
            return false
        }
    }

    /// 生成 AI 回复（仅用于测试用户）
    func generateAIReply(
        testUser: MatchingService.MatchedUser,
        chatHistory: [Message]
    ) async -> String? {
        // 构建 AI prompt
        let prompt = buildAIPrompt(
            element: testUser.userElement,
            traits: testUser.personalityTraits,
            chatHistory: chatHistory
        )

        do {
            let reply = try await callTextGeneration(prompt: prompt)
            print("✅ [ChatService] AI 生成回复: \(reply)")
            return reply
        } catch {
            print("❌ [ChatService] AI 生成回复失败: \(error)")
            // 返回默认回复
            return generateFallbackReply()
        }
    }

    /// 构建 AI prompt
    private func buildAIPrompt(
        element: String,
        traits: [String],
        chatHistory: [Message]
    ) -> String {
        // 角色设定
        let roleDescription = """
        你是一个正在使用交友 app 的用户，你的资料如下：
        - 五行属性：\(element)命
        - 性格特质：\(traits.joined(separator: "、"))

        请以这个角色的口吻与对方聊天。
        """

        // 聊天上下文（最近 10 条消息）
        var contextStr = ""
        let recentMessages = chatHistory.suffix(10)
        if !recentMessages.isEmpty {
            contextStr = "\n聊天历史：\n"
            for msg in recentMessages {
                let role = msg.messageType == "ai" || msg.senderId.hasPrefix("test-user-") ? "你" : "对方"
                let content = msg.content
                contextStr += "\(role): \(content)\n"
            }
        }

        // 获取最新消息
        let latestMessage = chatHistory.last?.content ?? "你好"

        // 完整 prompt
        return """
        \(roleDescription)
        \(contextStr)

        对方刚刚说："\(latestMessage)"

        要求：
        1. 展现你的性格特质（\(traits.joined(separator: "、"))）
        2. 回复要自然、真实、有亲和力
        3. 不要过于正式或生硬
        4. 回复控制在 50 字以内
        5. 可以适当提问，引导对话继续
        6. 不要说"作为 AI"之类的话，你就是这个角色本人

        只返回你的回复内容，不要有任何前缀、说明或多余的标点符号。
        """
    }

    /// 生成备用回复（当 AI 调用失败时）
    private func generateFallbackReply() -> String {
        let fallbacks = [
            "这个话题很有意思！",
            "我也有同样的感觉",
            "说的对，我很赞同",
            "能认识你真好",
            "你说的我很感兴趣"
        ]
        return fallbacks.randomElement() ?? "嗯嗯，我也这么觉得"
    }

    /// 检查用户是否为测试用户
    func isTestUser(_ userId: String) -> Bool {
        return userId.hasPrefix("test-user-")
    }

    /// 获取历史消息
    func fetchMessages(conversationId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetched: [Message] = try await supabase
                .from("messages")
                .select()
                .eq("conversation_id", value: conversationId)
                .order("created_at", ascending: true)
                .execute()
                .value

            messages = fetched
            print("✅ [ChatService] 获取消息 \(fetched.count) 条")
        } catch {
            print("❌ [ChatService] 获取消息失败: \(error)")
            errorMessage = "加载消息失败"
        }
    }

    /// 订阅实时消息
    func subscribeToMessages(conversationId: String) {
        // 先取消之前的订阅
        unsubscribe()

        Task {
            let channel = supabase.realtimeV2.channel("messages:\(conversationId)")

            let insertions = channel.postgresChange(
                InsertAction.self,
                schema: "public",
                table: "messages",
                filter: "conversation_id=eq.\(conversationId)"
            )

            await channel.subscribe()

            for await insertion in insertions {
                do {
                    let message = try insertion.decodeRecord(as: Message.self, decoder: JSONDecoder())
                    await MainActor.run {
                        if !self.messages.contains(where: { $0.id == message.id }) {
                            self.messages.append(message)
                            print("🔔 [ChatService] 收到新消息")
                        }
                    }
                } catch {
                    print("❌ [ChatService] 解析实时消息失败: \(error)")
                }
            }

            self.realtimeChannel = channel
        }
    }

    /// 取消订阅
    func unsubscribe() {
        Task {
            if let channel = realtimeChannel {
                await supabase.realtimeV2.removeChannel(channel)
                realtimeChannel = nil
                print("🔕 [ChatService] 已取消订阅")
            }
        }
    }

    /// 标记消息已读
    func markAsRead(conversationId: String) async {
        guard let myId = await getCurrentUserId() else { return }

        do {
            try await supabase
                .from("messages")
                .update(["is_read": true])
                .eq("conversation_id", value: conversationId)
                .neq("sender_id", value: myId)
                .eq("is_read", value: false)
                .execute()

            print("✅ [ChatService] 标记已读")
        } catch {
            print("❌ [ChatService] 标记已读失败: \(error)")
        }
    }

    /// 获取用户的所有对话
    func fetchConversations() async -> [Conversation] {
        guard let myId = await getCurrentUserId() else { return [] }

        do {
            let conversations: [Conversation] = try await supabase
                .from("conversations")
                .select()
                .or("user1_id.eq.\(myId),user2_id.eq.\(myId)")
                .order("last_message_at", ascending: false)
                .execute()
                .value

            return conversations
        } catch {
            print("❌ [ChatService] 获取对话列表失败: \(error)")
            return []
        }
    }

    /// 清理当前状态
    func clearCurrentChat() {
        currentConversation = nil
        messages = []
        unsubscribe()
    }

    // MARK: - 私有方法

    private func getCurrentUserId() async -> String? {
        do {
            let session = try await supabase.auth.session
            let userId = session.user.id.uuidString
            print("🔵 [ChatService] getCurrentUserId 成功: \(userId)")
            return userId
        } catch {
            print("❌ [ChatService] getCurrentUserId 失败: \(error)")
            print("❌ [ChatService] 用户可能未登录或 session 已过期")
            return nil
        }
    }

    /// 公开的获取用户ID方法（供外部使用）
    func getAuthenticatedUserId() async -> String? {
        return await getCurrentUserId()
    }

    /// 调用文本生成 API
    private func callTextGeneration(prompt: String) async throws -> String {
        // 从 SecretsManager 获取 API Key
        guard let apiKey = await SecretsManager.shared.getSecret("ALIYUN_BAILIAN_API_KEY") else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取 API Key"])
        }

        guard let url = URL(string: "\(AppConfig.AliyunBailian.baseURL)/chat/completions") else {
            throw NSError(domain: "ChatService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": AppConfig.AliyunBailian.model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.8
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        }

        throw NSError(domain: "ChatService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
    }
}
