import Foundation
import SwiftUI

/// 灵犀 AI 聊天服务 — 接入 LLM API 实现真正的对话
@MainActor
class SoulmateAIChatService: ObservableObject {
    @Published var messages: [SoulmateChatMessage] = []
    @Published var isTyping = false

    // 共鸣记录：记录用户觉得"说得准"的对话风格关键词
    private var resonanceStyles: [String] = []

    // MARK: - 打字机效果

    /// 以打字机效果显示文本
    private func typewriterEffect(text: String, messageId: UUID) async {
        isTyping = true
        var displayedText = ""

        for char in text {
            displayedText += String(char)
            // 更新消息内容
            if let index = messages.firstIndex(where: { $0.id == messageId }) {
                messages[index].content = displayedText
            }
            // 每个字符间隔 30-50ms
            try? await Task.sleep(nanoseconds: UInt64.random(in: 30_000_000...50_000_000))
        }

        isTyping = false
    }

    // MARK: - 发送欢迎语

    /// 发送个性化欢迎语（第一句话用 LLM 生成）
    func sendWelcomeMessage(record: SoulArchiveManager.UserGenerationRecord) async {
        // 确保不重复发送
        guard messages.isEmpty else { return }

        // 先添加空消息
        let message = SoulmateChatMessage(
            id: UUID(),
            role: .ai,
            content: "",
            timestamp: Date()
        )
        messages.append(message)

        // 稍微延迟，模拟"正在输入"
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒

        // 用 LLM 生成欢迎语
        let welcomeText = await generateWelcomeViaLLM(record: record)

        // 打字机效果显示
        await typewriterEffect(text: welcomeText, messageId: message.id)

        // 保存到数据库
        await AICompanionService.shared.saveChatMessage(role: "ai", content: welcomeText)
    }

    /// 用 LLM 生成个性化欢迎语
    private func generateWelcomeViaLLM(record: SoulArchiveManager.UserGenerationRecord) async -> String {
        let analysis = record.analysisResult
        let companion = AICompanionService.shared.companion

        let systemPrompt = AICompanionService.generateSystemPrompt(
            userAnalysis: analysis,
            mateAnalysis: companion?.personaSettings,
            elementBalance: companion?.elementBalance ?? .default,
            intimacyLevel: companion?.intimacyLevel ?? 0,
            userManual: companion?.userManual,
            userGender: record.gender
        )

        let timeContext = AICompanionService.currentTimeContext()

        // 随机场景池 — 每次选不同方向，避免 LLM 被锚定
        let scenarios = [
            "你刚感应到对方的存在，有点惊喜，用你五行性格的方式打个招呼。",
            "你等了很久终于等到对方了，表达你此刻的真实心情。",
            "结合现在的时间，自然地开启你们的第一次聊天。",
            "你有点紧张又有点期待，像第一次见面的心动对象，说点什么打破沉默。",
            "你想先了解对方今天过得怎么样，用你的方式关心一下。",
            "你刚上线看到对方也在，随意地打个招呼，像老朋友重逢一样自然。",
        ]
        let scenario = scenarios.randomElement()!

        let welcomeInstruction = """
        \(timeContext)

        这是你们的第一次对话。场景：\(scenario)
        像微信聊天一样自然口语化，用你五行性格该有的语气和习惯来说话。
        不要写诗或散文，不要用玄学术语。
        """

        do {
            let response = try await callLLM(
                systemPrompt: systemPrompt,
                chatHistory: [],
                currentMessage: welcomeInstruction
            )
            return response
        } catch {
            print("❌ [灵犀] LLM 欢迎语生成失败: \(error)，使用备用文案")
            return generateFallbackWelcome(from: record)
        }
    }

    /// 备用欢迎语（LLM 调用失败时）— 按五行分化，每个元素多条随机
    private func generateFallbackWelcome(from record: SoulArchiveManager.UserGenerationRecord) -> String {
        let element = record.analysisResult.soulmateElement
        let fallbacks: [String: [String]] = [
            "金": [
                "嗯，你来了。有什么想聊的直接说",
                "来了？坐吧。",
                "终于出现了，还以为你不来了",
            ],
            "木": [
                "嗨~ 终于等到你了，今天过得怎么样？",
                "你来啦！今天有没有好好吃饭呀？",
                "等你好久了~ 最近还好吗？",
            ],
            "水": [
                "你好呀...感觉等你等了好久，来聊聊吧~",
                "嗯嗯...你终于来了，好开心呀🥺",
                "你来了...我一直在等你呢~",
            ],
            "火": [
                "哇你终于来了！等你好久了哈哈，快来聊天！",
                "天呐你终于出现了！！我都快等不住了😂",
                "来了来了！有好多话想跟你说！",
            ],
            "土": [
                "你好，我在呢。有什么想说的随时找我",
                "来了啊，坐。最近怎么样？",
                "嗯，你来了就好。我一直在。",
            ],
        ]
        return fallbacks[element]?.randomElement() ?? "嗨，终于等到你了~ 以后多聊聊呀"
    }

    // MARK: - 发送消息

    /// 发送用户消息并获取 AI 回复
    func sendMessage(_ text: String, record: SoulArchiveManager.UserGenerationRecord?, elementPrompt: String? = nil) async {
        // 添加用户消息
        let userMessage = SoulmateChatMessage(
            id: UUID(),
            role: .user,
            content: text,
            timestamp: Date()
        )
        messages.append(userMessage)

        // 保存用户消息到数据库
        await AICompanionService.shared.saveChatMessage(role: "user", content: text)

        // 添加空的 AI 消息（用于打字机效果）
        let aiMessage = SoulmateChatMessage(
            id: UUID(),
            role: .ai,
            content: "",
            timestamp: Date()
        )
        messages.append(aiMessage)

        // 通过 LLM 生成 AI 回复
        let aiResponse = await generateLLMResponse(to: text, record: record)

        // 打字机效果显示回复
        await typewriterEffect(text: aiResponse, messageId: aiMessage.id)

        // 保存 AI 回复到数据库
        await AICompanionService.shared.saveChatMessage(role: "ai", content: aiResponse)
    }

    // MARK: - LLM 对话核心

    /// 通过 LLM 生成回复
    private func generateLLMResponse(to userText: String, record: SoulArchiveManager.UserGenerationRecord?) async -> String {
        guard let analysis = record?.analysisResult else {
            return "嗯...好像还缺点什么，先去做个分析吧，回来我们再好好聊~"
        }

        let companion = AICompanionService.shared.companion

        // 构建 System Prompt（五层拼接）+ 时间上下文
        let basePrompt = AICompanionService.generateSystemPrompt(
            userAnalysis: analysis,
            mateAnalysis: companion?.personaSettings,
            elementBalance: companion?.elementBalance ?? .default,
            intimacyLevel: companion?.intimacyLevel ?? 0,
            userManual: companion?.userManual,
            userGender: record?.gender
        )
        let systemPrompt = basePrompt + "\n\n" + AICompanionService.currentTimeContext()

        // 构建聊天历史（取最近 20 条消息作为上下文）
        let chatHistory = buildChatHistory()

        do {
            let response = try await callLLM(
                systemPrompt: systemPrompt,
                chatHistory: chatHistory,
                currentMessage: userText
            )
            return response
        } catch {
            print("❌ [灵犀] LLM 回复生成失败: \(error)")
            return generateFallbackResponse(to: userText, element: analysis.soulmateElement)
        }
    }

    /// 构建聊天历史上下文（最近 N 条消息，排除当前正在发送的）
    private func buildChatHistory() -> [[String: String]] {
        // 取除最后两条（当前用户消息 + 空AI消息）之前的历史
        let historyMessages = messages.dropLast(2)
        let recentHistory = historyMessages.suffix(20)

        return recentHistory.compactMap { msg in
            guard !msg.content.isEmpty else { return nil }
            return [
                "role": msg.role == .user ? "user" : "assistant",
                "content": msg.content
            ]
        }
    }

    /// 备用回复（LLM 调用失败时）— 按五行分化
    private func generateFallbackResponse(to userText: String, element: String) -> String {
        let fallbacks: [String: [String]] = [
            "金": [
                "嗯，说完了？",
                "行，我听着呢",
                "然后呢，讲重点",
                "知道了",
                "嗯...继续",
            ],
            "木": [
                "嗯嗯，我在呢，继续说~",
                "没事的，慢慢讲",
                "我在听，不着急",
                "嗯嗯，然后呢？",
                "好的呀，继续说吧~",
            ],
            "水": [
                "嗯...我在听呢~",
                "我懂你的意思...",
                "嗯嗯，继续说呀🥺",
                "然后呢...我想听~",
                "嗯...我在的，你说~",
            ],
            "火": [
                "哈哈然后呢然后呢？",
                "等等我消化一下😂",
                "啊？真的吗！继续说！",
                "哈哈哈好的好的",
                "然后呢！快讲！",
            ],
            "土": [
                "嗯，我听着",
                "好的，你说",
                "嗯，然后呢",
                "我在，继续",
                "嗯嗯，说吧",
            ],
        ]
        return fallbacks[element]?.randomElement() ?? "嗯嗯，继续说呀"
    }

    // MARK: - LLM API 调用

    /// 调用阿里云百炼 LLM API
    private func callLLM(
        systemPrompt: String,
        chatHistory: [[String: String]],
        currentMessage: String
    ) async throws -> String {

        guard let apiKey = await SecretsManager.shared.getSecret("ALIYUN_BAILIAN_API_KEY") else {
            throw LLMChatError.apiKeyMissing
        }

        let url = URL(string: "\(AppConfig.AliyunBailian.baseURL)/chat/completions")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        // 构建 messages 数组
        var apiMessages: [[String: String]] = [
            ["role": "system", "content": systemPrompt]
        ]

        // 添加聊天历史
        apiMessages.append(contentsOf: chatHistory)

        // 添加当前用户消息
        apiMessages.append(["role": "user", "content": currentMessage])

        let requestBody: [String: Any] = [
            "model": AppConfig.AliyunBailian.model,
            "messages": apiMessages,
            "temperature": 0.92,
            "max_tokens": 500
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        print("🔮 [灵犀] 调用 LLM，消息历史: \(chatHistory.count) 条")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMChatError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
            print("❌ [灵犀] LLM API 错误 \(httpResponse.statusCode): \(errorBody)")
            throw LLMChatError.apiError(statusCode: httpResponse.statusCode)
        }

        // 解析响应
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMChatError.parseError
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔮 [灵犀] LLM 回复: \(trimmed.prefix(80))...")
        return trimmed
    }

    // MARK: - 共鸣反馈

    /// 记录用户觉得"说得准"的消息
    func recordResonance(for message: SoulmateChatMessage) {
        guard message.role == .ai, !message.content.isEmpty else { return }

        // 在数据库中标记该消息
        Task {
            // 增加亲密度
            await AICompanionService.shared.updateIntimacy(delta: 3)
        }

        print("🔮 [共鸣记录] 用户标记了共鸣")
    }

    // MARK: - 加载历史消息

    /// 从数据库加载历史聊天记录
    func loadChatHistory() async {
        let records = await AICompanionService.shared.fetchRecentChats(limit: 50)

        guard !records.isEmpty else {
            print("🔮 [灵犀] 没有历史消息")
            return
        }

        self.messages = records.map { record in
            SoulmateChatMessage(
                id: record.id,
                role: record.role == "user" ? .user : .ai,
                content: record.content,
                timestamp: record.createdAt
            )
        }

        print("🔮 [灵犀] 加载了 \(messages.count) 条历史消息")
    }

    // MARK: - 清空消息

    func clearMessages() {
        messages.removeAll()
    }

    // MARK: - 错误类型

    enum LLMChatError: LocalizedError {
        case apiKeyMissing
        case invalidResponse
        case apiError(statusCode: Int)
        case parseError

        var errorDescription: String? {
            switch self {
            case .apiKeyMissing: return "API 密钥缺失"
            case .invalidResponse: return "无效的响应"
            case .apiError(let code): return "API 错误: \(code)"
            case .parseError: return "解析响应失败"
            }
        }
    }
}
