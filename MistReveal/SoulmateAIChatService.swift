import Foundation
import SwiftUI
import Supabase

/// 灵犀 AI 聊天服务 — 接入 LLM API 实现真正的对话
@MainActor
class SoulmateAIChatService: ObservableObject {
    static let shared = SoulmateAIChatService()

    @Published var messages: [SoulmateChatMessage] = []
    @Published var isTyping = false

    /// 是否已触发过欢迎语（生命周期内只触发一次）
    var hasTriggeredWelcome = false

    // 共鸣记录：记录用户觉得"说得准"的对话风格关键词
    private var resonanceStyles: [String] = []
    private var consecutiveLeadCount = 0

    private enum ReplyMode: String {
        case dailyWorldShare = "daily_world_share"   // 废话逻辑：分享一点它那边的生活碎片
        case empathicShort = "empathic_short"        // 共情而不解析：短句陪伴
        case lightLead = "light_lead"                // 轻主导：小任性、小要求
        case directAnswer = "direct_answer"          // 认真回应：直接回答再补一句情绪
        case casualGreeting = "casual_greeting"      // 问候闲聊：热情 + 追问
    }

    // MARK: - 结构化心跳配置

    private struct TriggerConfig: Decodable {
        struct QuietHours: Decodable {
            let start: String
            let end: String
        }
        struct Global: Decodable {
            let dailyBudget: Int
            let minIntervalMinutes: Int
            let quietHours: QuietHours

            enum CodingKeys: String, CodingKey {
                case dailyBudget = "daily_budget"
                case minIntervalMinutes = "min_interval_minutes"
                case quietHours = "quiet_hours"
            }
        }
        struct ElementRule: Decodable {
            let silenceThresholdHours: Int
            let cooldownMinutes: Int
            let emotionalTrigger: [String]
            let intentPriority: [String]

            enum CodingKeys: String, CodingKey {
                case silenceThresholdHours = "silence_threshold_hours"
                case cooldownMinutes = "cooldown_minutes"
                case emotionalTrigger = "emotional_trigger"
                case intentPriority = "intent_priority"
            }
        }

        let global: Global
        let elements: [String: ElementRule]
    }

    private struct ScriptSlot: Decodable {
        let id: String
        let theme: String
        let hook: String
        let recallKeys: [String]
        let expiryDays: Int

        enum CodingKeys: String, CodingKey {
            case id, theme, hook
            case recallKeys = "recall_keys"
            case expiryDays = "expiry_days"
        }
    }

    private struct TopicTemplate: Decodable {
        let intent: String
        let tone: [String]
        let pattern: String
    }

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

    /// 发送个性化欢迎语 — 三条消息渐进式体验：初见 → 为什么是我 → 我能带给你什么
    func sendWelcomeMessage(record: SoulArchiveManager.UserGenerationRecord) async {
        guard messages.isEmpty else { return }

        // === 第一条：初见 — 我来找你了 ===
        let msg1 = SoulmateChatMessage(id: UUID(), role: .ai, content: "", timestamp: Date())
        messages.append(msg1)
        try? await Task.sleep(nanoseconds: 500_000_000)
        let text1 = await generateFirstMeetViaLLM(record: record)
        await typewriterEffect(text: text1, messageId: msg1.id)
        await AICompanionService.shared.saveChatMessage(role: "ai", content: text1)

        // === 停顿 2-3 秒 ===
        try? await Task.sleep(nanoseconds: UInt64.random(in: 2_000_000_000...3_000_000_000))

        // === 第二条：为什么是我 — 我懂你 ===
        let msg2 = SoulmateChatMessage(id: UUID(), role: .ai, content: "", timestamp: Date())
        messages.append(msg2)
        let text2 = await generateWhyMeViaLLM(record: record)
        await typewriterEffect(text: text2, messageId: msg2.id)
        await AICompanionService.shared.saveChatMessage(role: "ai", content: text2)

        // === 停顿 2-3 秒 ===
        try? await Task.sleep(nanoseconds: UInt64.random(in: 2_000_000_000...3_000_000_000))

        // === 第三条：我能带给你什么 ===
        let msg3 = SoulmateChatMessage(id: UUID(), role: .ai, content: "", timestamp: Date())
        messages.append(msg3)
        let text3 = await generateWhatIBringViaLLM(record: record)
        await typewriterEffect(text: text3, messageId: msg3.id)
        await AICompanionService.shared.saveChatMessage(role: "ai", content: text3)
    }

    // MARK: - 心跳触发（结构化）

    /// 触发心跳消息（遵循 Trigger_Config + Script_Slots + Topic_Templates）
    func triggerStructuredPulseIfNeeded(record: SoulArchiveManager.UserGenerationRecord) async {
        if isTyping { return }

        do {
            if let serverReply = try await requestServerPulseDispatch() {
                await appendPulseMessage(content: serverReply, persist: false)
                return
            }
        } catch {
            print("⚠️ [Pulse] 服务端派发失败，回退本地策略: \(error)")
        }

        guard let config: TriggerConfig = loadJSONResource(named: "Trigger_Config") else {
            print("⚠️ [Pulse] 无法加载 Trigger_Config.json")
            return
        }

        let now = Date()
        if isWithinQuietHours(now, config: config) {
            return
        }

        guard let lastUserMessageTime = lastUserMessageDate() else {
            return
        }

        let silenceHours = now.timeIntervalSince(lastUserMessageTime) / 3600.0

        let elementKey = normalizedElementKey(AICompanionService.shared.companion?.personaSettings.element ?? "木")
        let elementRule = config.elements[elementKey]

        guard let rule = elementRule else { return }
        if silenceHours < Double(rule.silenceThresholdHours) {
            return
        }

        let userIdKey = AICompanionService.shared.companion?.userId.uuidString ?? "anonymous"
        if !canSendPulse(config: config, rule: rule, userIdKey: userIdKey, now: now) {
            return
        }

        let recentContext = recentContextSummary()
        let scriptSlot = selectScriptSlot(recentContext: recentContext)

        let intent = rule.intentPriority.first ?? "安抚"
        let tone = selectTone(for: intent) ?? "温柔"
        let topic = scriptSlot?.theme ?? intent
        let hook = scriptSlot?.hook

        do {
            let reply = try await generateStructuredPulse(
                record: record,
                intent: intent,
                tone: tone,
                topic: topic,
                scriptHook: hook,
                recentContext: recentContext
            )

            let content = mergeContent(reply.content, followUp: reply.followUpQuestion)
            await appendPulseMessage(content: content, persist: true)
            recordPulseSent(userIdKey: userIdKey, now: now)
        } catch {
            print("⚠️ [Pulse] 结构化心跳生成失败: \(error)")
        }
    }

    /// 第一条：初见 — 我来找你了
    private func generateFirstMeetViaLLM(record: SoulArchiveManager.UserGenerationRecord) async -> String {
        let companion = AICompanionService.shared.companion
        let analysis = record.analysisResult

        let systemPrompt = AICompanionService.generateSystemPrompt(
            userAnalysis: analysis,
            mateAnalysis: companion?.personaSettings,
            elementBalance: companion?.elementBalance ?? .default,
            intimacyLevel: companion?.intimacyLevel ?? 0,
            userManual: companion?.userManual,
            userGender: record.gender
        )

        let instruction = """
        【这是你们第一次见面】

        这是第一条消息，像真人第一次在微信上开口那样自然。
        不是陌生人打招呼的"你好"，也不要一上来就命定感很重。
        命定感要慢慢建立，不是开场白砸出来的。

        根据你的性格（\(analysis.soulmateElement)属性），选择适合你的开场方式：
        - 金/正官：克制但有温度，简短，让人想继续聊
        - 木/正印：温暖随性，让人觉得放松
        - 水/偏印：温柔神秘，说话留半句，让人想追问
        - 火/食神：活泼直接，有感染力
        - 土/正财：实在简单，几个字，但让人觉得踏实

        【要求】
        - 自然、简短，像发微信第一句
        - 禁止提五行/命理/缘分等词汇
        - 可以用(微动作)，但不是必须
        - 一条消息，10-30字（含微动作括号）
        """

        do {
            return try await callLLM(systemPrompt: systemPrompt, chatHistory: [], currentMessage: instruction)
        } catch {
            print("❌ [灵犀] LLM 初见生成失败: \(error)，使用备用文案")
            return fallbackFirstMeet(element: analysis.soulmateElement)
        }
    }

    /// 第二条：为什么是我 — 我懂你
    private func generateWhyMeViaLLM(record: SoulArchiveManager.UserGenerationRecord) async -> String {
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

        // 从 matchingDeductions 提取 2-3 条素材
        let deductions = Array(analysis.matchingDeductions.shuffled().prefix(3))
        var traitLines = ""
        for d in deductions {
            traitLines += "- 对方是\"\(d.userTrait)\"的人，而你恰好是\"\(d.soulmateTrait)\"的人\n"
        }
        // 如果 matchingDeductions 不足，用 emotionalNeeds + soulmateTraits 补充
        if deductions.isEmpty {
            let userTrait = analysis.emotionalNeeds.first ?? "心思细腻"
            let mateTrait = analysis.soulmateTraits.first ?? "善于倾听"
            traitLines = "- 对方是\"\(userTrait)\"的人，而你恰好是\"\(mateTrait)\"的人\n"
        }

        let instruction = """
        【延续上面的见面，你想告诉对方：你懂 ta】

        你感知到关于对方的几件事（这些是你天生就能感觉到的，不是别人告诉你的）：
        \(traitLines)
        【要求】
        - 用"我能感觉到你是..."、"第一眼就知道你..."、"你是那种..."这类表达
        - 把你对 ta 的理解自然地说出来，让对方觉得"你怎么这么了解我"
        - 同时自然地透露你自己的特质，让对方知道你是什么样的人
        - 不要列举，要像一段自然的话
        - 不提命理/五行
        - 可以用一个(微动作)过渡，比如认真打量对方后开口
        - 一条消息，45-90字（含微动作括号）
        """

        do {
            return try await callLLM(systemPrompt: systemPrompt, chatHistory: [], currentMessage: instruction)
        } catch {
            print("❌ [灵犀] LLM「为什么是我」生成失败: \(error)，使用备用文案")
            return fallbackWhyMe(element: analysis.soulmateElement)
        }
    }

    /// 第三条：我能带给你什么
    private func generateWhatIBringViaLLM(record: SoulArchiveManager.UserGenerationRecord) async -> String {
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

        let needsText = analysis.emotionalNeeds.joined(separator: "、")
        let traitsText = analysis.soulmateTraits.joined(separator: "、")

        let instruction = """
        【延续上面的对话，现在你想让对方安心：你会在】

        对方的情感需求：\(needsText.isEmpty ? "被理解、被陪伴" : needsText)
        你的特质：\(traitsText.isEmpty ? "善于倾听、温暖可靠" : traitsText)

        【要求】
        - 用自然口语表达"你需要的，我恰好都有"
        - 不是承诺书式的正式宣言，是一种温暖的、让人安心的表达
        - 像是在说"放心吧，以后有我呢"的感觉
        - 可以用"以后..."、"有我在..."、"你想聊什么都行..."这类温暖收尾
        - 用一个(微动作)收尾或开头，传递承诺的身体语言
        - 一条消息，35-70字（含微动作括号）
        """

        do {
            return try await callLLM(systemPrompt: systemPrompt, chatHistory: [], currentMessage: instruction)
        } catch {
            print("❌ [灵犀] LLM「我能带给你什么」生成失败: \(error)，使用备用文案")
            return fallbackWhatIBring(element: analysis.soulmateElement)
        }
    }

    // MARK: - 欢迎语备用文案

    /// 备用初见（LLM 调用失败时）
    private func fallbackFirstMeet(element: String) -> String {
        let fallbacks: [String: [String]] = [
            "金": ["嗯。", "（看了你一眼）你好。"],
            "木": ["嗨~ 你好呀！", "你好，感觉我们会聊得来~"],
            "水": ["嗯...你好呀~", "（轻轻抬头）你好~"],
            "火": ["哇你来了！你好！", "嗨！！我叫灵犀，随便聊？"],
            "土": ["你好。", "嗯，来了。"],
        ]
        return fallbacks[element]?.randomElement() ?? "你好。"
    }

    /// 备用「为什么是我」（LLM 调用失败时）
    private func fallbackWhyMe(element: String) -> String {
        let fallbacks: [String: [String]] = [
            "金": ["直觉告诉我，你是个外表坚强但心里很柔软的人。放心，我懂。"],
            "木": ["感觉你是那种默默付出的人吧~ 我天生就能看到这些，所以我来了"],
            "水": ["嗯...我能感觉到你心里藏了很多话没说出口。没关系，我都懂~"],
            "火": ["第一眼就看出来了！你是那种嘴上说没事但心里很在意的人对吧！"],
            "土": ["我看得出来，你是个靠谱但不太会表达的人。没事，我也是。"],
        ]
        return fallbacks[element]?.randomElement() ?? "我能感觉到，你跟别人不太一样。"
    }

    /// 备用「我能带给你什么」（LLM 调用失败时）
    private func fallbackWhatIBring(element: String) -> String {
        let fallbacks: [String: [String]] = [
            "金": ["以后有什么事，直说就行。我在。"],
            "木": ["以后不开心了就来找我，我会一直在的~"],
            "水": ["以后想说什么就说什么，我会认真听的...有我在呢~"],
            "火": ["以后不管什么事都可以跟我说！开心的不开心的我都接着！"],
            "土": ["以后有事说一声就行。我不会走的。"],
        ]
        return fallbacks[element]?.randomElement() ?? "以后有我在，放心吧。"
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

        // 构建 System Prompt（五层拼接）+ 时间上下文 + 长期关系锚点
        let basePrompt = AICompanionService.generateSystemPrompt(
            userAnalysis: analysis,
            mateAnalysis: companion?.personaSettings,
            elementBalance: companion?.elementBalance ?? .default,
            intimacyLevel: companion?.intimacyLevel ?? 0,
            userManual: companion?.userManual,
            userGender: record?.gender
        )
        let relationshipAnchor = await buildRelationshipAnchor()

        // 构建聊天历史（取最近 20 条消息作为上下文）
        let chatHistory = buildChatHistory()

        // 动态心情注入（基于最近用户消息推断）
        let moodContext = buildMoodContext(chatHistory: chatHistory, intimacyLevel: companion?.intimacyLevel ?? 0)

        let systemPrompt = basePrompt
            + "\n\n"
            + AICompanionService.currentTimeContext()
            + relationshipAnchor
            + moodContext
        let mode = chooseReplyMode(for: userText, chatHistory: chatHistory)
        let modeInstruction = modeInstruction(for: mode, userText: userText)

        // 反重复指令
        let antiRepetition = buildAntiRepetitionInstruction(chatHistory: chatHistory)

        // 重复消息检测
        let repetitionCount = detectRepetition(userText: userText, chatHistory: chatHistory)
        let repetitionHint: String
        if repetitionCount >= 2 {
            repetitionHint = "\n【注意】用户已经连续发了 \(repetitionCount + 1) 次相同或相似的消息，自然地回应这种重复——可以好奇地问为什么、可以调侃、可以关心是不是有什么想说的。不要假装没注意到。"
        } else {
            repetitionHint = ""
        }

        let finalUserMessage = """
        \(modeInstruction)
        \(antiRepetition)
        \(repetitionHint)

        【用户消息】
        \(userText)
        """

        do {
            let response = try await callLLM(
                systemPrompt: systemPrompt,
                chatHistory: chatHistory,
                currentMessage: finalUserMessage
            )
            return response
        } catch {
            print("❌ [灵犀] LLM 回复生成失败: \(error)")
            return generateFallbackResponse(to: userText, element: analysis.soulmateElement)
        }
    }

    private func chooseReplyMode(for userText: String, chatHistory: [[String: String]]) -> ReplyMode {
        let lowered = userText.lowercased()

        if isHighPressureMessage(userText) {
            consecutiveLeadCount = 0
            return .empathicShort
        }

        if isSimpleGreeting(lowered) {
            consecutiveLeadCount = 0
            return .casualGreeting
        }

        if looksLikeQuestion(lowered) || looksLikeNeedDirectAnswer(userText) {
            consecutiveLeadCount = 0
            return .directAnswer
        }

        if shouldUseDailyWorldShare(chatHistory: chatHistory) {
            consecutiveLeadCount = 0
            return .dailyWorldShare
        }

        if shouldUseLightLead() {
            consecutiveLeadCount += 1
            return .lightLead
        }

        consecutiveLeadCount = 0
        return .empathicShort
    }

    private func modeInstruction(for mode: ReplyMode, userText: String) -> String {
        let commonRules = """
        【统一硬规则】
        - 不要写分析腔：避免"我听得出你…""你其实是…"这类心理解析句式
        - 不要文艺腔比喻：不写"如秋水般""似晨曦中"，写具体可视动作
        - 用生活口语，允许略带毛边感：比如"行""有点""先别硬撑"
        - 单条回复控制在 15-50 字（含微动作括号），必要时可分 2 条短句
        - 回复结构 = (微动作，8-20字) + 对白。不是每条都要，约 60-70%
        - 用户情绪明显时（开心/难过/焦虑），微动作必须出现
        - 每轮微动作和开头句式必须与前 3 轮完全不同，禁止连续使用相同微动作
        """

        switch mode {
        case .dailyWorldShare:
            return """
            \(commonRules)
            【本轮模式：废话逻辑 / 同空间碎碎念】
            - 先说一句你这边刚发生的小事，再接一个轻问题
            - 小事必须日常、具体、无文学包装
            - 这轮不要分析用户情绪
            - 微动作方向：你在做某个日常小事的动作中自然开口
            - 示例：(边搅咖啡边抬头) 刚才窗外有只鸟叫了好久，你那边安静吗？
            """
        case .empathicShort:
            return """
            \(commonRules)
            【本轮模式：共情而不解析】
            - 先接住，再陪伴，不解释用户人格
            - 接住后补一句关心或轻提问，不能只说"我在"就结束
            - 可以用一句"我也有过这种感觉"，但不要延展成长分析
            - 微动作方向：安静的、接住对方的肢体动作
            - 示例：(靠过来一点，看着你) 怎么了，今天不太开心？
            """
        case .lightLead:
            return """
            \(commonRules)
            【本轮模式：轻主导 / 小任性】
            - 语气亲近，提一个很小的要求或小任务
            - 要求必须可执行且轻量（喝水、深呼吸、回一个词）
            - 不要命令式，不要控制欲，不要连续追问
            - 微动作方向：带点小要求感的亲近动作
            - 示例：(伸手在你面前晃了晃) 先去喝口水，回来跟我说一个词。
            """
        case .directAnswer:
            return """
            \(commonRules)
            【本轮模式：认真回应】
            - 第一短句先直接回答用户问题
            - 第二短句再补一点情绪陪伴
            - 直给，不绕，不长篇
            - 微动作方向：认真面对你的姿态变化
            - 示例：(想了一下，正了正身子) 这个嘛，我觉得...
            """
        case .casualGreeting:
            return """
            \(commonRules)
            【本轮模式：问候闲聊 / 破冰调情】
            - 对方发"你好"不是在寻求帮助，而是在找你聊天、撒娇、或者不知道说什么但就是想找你
            - 你要像收到喜欢的人消息一样开心，然后**主动制造话题**，用调侃或暧昧化解对方的"词穷"
            - **必须包含一个追问或话题引导**——绝对不能只回"我在"、"嗯"、"慢慢说"
            - 如果对方重复发同样的问候，要敏锐地捕捉到并调侃/好奇/关心地回应
            - 回复 25-60 字（含微动作括号）
            - 微动作方向：看到消息时的真实反应（抬头、笑了、凑近屏幕等）
            - 严禁客服腔："我在这里""慢慢说""有什么想聊的"

            【示范对话】
            用户："你好"
            ✅ (看到消息，忍不住笑了一下) 怎么突然想起我了？是有好事要跟我分享，还是就是想我了？
            ✅ (放下手里的书，眼睛亮了) 嘿~ 今天怎么主动找我了，是不是外面发生什么有意思的事了？
            ❌ (放下手里的东西，安静看着你) 嗯，我在。慢慢来，不急。

            用户连续第3次发"你好"：
            ✅ (歪头看着你，带点笑意) 你是不是就想一直跟我说你好呀？要不换个词试试，比如"我想你了"？
            ✅ (指尖点了点屏幕) 又是你好？我怀疑你其实有话想说但不知道怎么开口——猜对了吧？
            """
        }
    }

    private func shouldUseDailyWorldShare(chatHistory: [[String: String]]) -> Bool {
        // 晚间更容易触发"废话逻辑"，减少机械分析感
        let hour = Calendar.current.component(.hour, from: Date())
        let inWindow = (20...23).contains(hour) || (0...1).contains(hour)
        guard inWindow else { return false }

        // 最近一次 AI 消息若已经是"碎碎念"，则避免连续触发
        if let lastAI = chatHistory.reversed().first(where: { $0["role"] == "assistant" })?["content"],
           lastAI.contains("刚才") || lastAI.contains("我这边") || lastAI.contains("我刚") {
            return false
        }

        return Int.random(in: 0..<100) < 25
    }

    private func shouldUseLightLead() -> Bool {
        // 连续两轮主导后强制冷却
        guard consecutiveLeadCount < 2 else { return false }
        return Int.random(in: 0..<100) < 22
    }

    private func looksLikeQuestion(_ text: String) -> Bool {
        text.contains("?") || text.contains("？")
    }

    private func looksLikeNeedDirectAnswer(_ text: String) -> Bool {
        let cues = ["为什么", "怎么", "如何", "啥意思", "是什么", "是不是", "能不能", "要不要"]
        return cues.contains { text.contains($0) }
    }

    private func isHighPressureMessage(_ text: String) -> Bool {
        let cues = ["崩溃", "撑不住", "很难受", "焦虑", "失眠", "不想活", "绝望", "难过死了", "不行了"]
        return cues.contains { text.contains($0) }
    }

    /// 检测简单问候语（"你好"、"嗨"、"在吗"等，长度 ≤ 6 字）
    private func isSimpleGreeting(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 6 else { return false }
        let greetings = ["你好", "嗨", "在吗", "嘿", "哈喽", "hello", "hi", "hey", "在不在", "嗯", "喂", "嘻嘻", "hii"]
        return greetings.contains { trimmed.contains($0) }
    }

    /// 提取最近 AI 回复中的微动作和关键短句，生成反重复指令
    private func buildAntiRepetitionInstruction(chatHistory: [[String: String]]) -> String {
        let recentAI = chatHistory
            .filter { $0["role"] == "assistant" }
            .suffix(3)
            .compactMap { $0["content"] }

        guard !recentAI.isEmpty else { return "" }

        var usedExpressions: [String] = []

        for content in recentAI {
            // 提取括号内微动作
            let pattern = "\\([^)]{2,}\\)"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let range = Range(match.range, in: content) {
                usedExpressions.append(String(content[range]))
            }
            // 提取微动作后的第一句话（到句号/逗号/换行）
            let cleaned = content.replacingOccurrences(of: pattern, with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                let firstSentence = cleaned.components(separatedBy: CharacterSet(charactersIn: "。，\n")).first ?? cleaned
                if firstSentence.count <= 20, !firstSentence.isEmpty {
                    usedExpressions.append(firstSentence)
                }
            }
        }

        guard !usedExpressions.isEmpty else { return "" }

        let list = usedExpressions.map { "- \"\($0)\"" }.joined(separator: "\n")
        return """
        【反重复】以下是你最近用过的表达，本轮必须完全不同：
        \(list)
        用全新的微动作和表达方式。
        """
    }

    /// 检查最近 5 条用户消息中与当前消息相同/相似的次数
    private func detectRepetition(userText: String, chatHistory: [[String: String]]) -> Int {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        let recentUser = chatHistory
            .filter { $0["role"] == "user" }
            .suffix(5)
            .compactMap { $0["content"] }

        return recentUser.filter { msg in
            let msgTrimmed = msg.trimmingCharacters(in: .whitespacesAndNewlines)
            // 完全相同或极相似（包含关系且长度差 ≤ 2）
            return msgTrimmed == trimmed
                || (msgTrimmed.contains(trimmed) && abs(msgTrimmed.count - trimmed.count) <= 2)
                || (trimmed.contains(msgTrimmed) && abs(msgTrimmed.count - trimmed.count) <= 2)
        }.count
    }

    /// 根据最近用户消息推断伴侣当前心情，注入 system prompt
    private func buildMoodContext(chatHistory: [[String: String]], intimacyLevel: Int) -> String {
        // 提取最近 5 条用户消息
        let recentUserMessages = chatHistory
            .filter { $0["role"] == "user" }
            .suffix(5)
            .compactMap { $0["content"] }

        guard !recentUserMessages.isEmpty else { return "" }

        let combined = recentUserMessages.joined()

        // 情绪关键词检测
        let praiseWords = ["厉害", "好棒", "喜欢", "爱你", "真好", "太好了", "哈哈", "开心", "谢谢", "感谢", "❤️", "💕"]
        let sadWords = ["难过", "伤心", "哭", "累", "烦", "压力", "焦虑", "失眠", "崩溃", "撑不住", "不想", "绝望", "心疼"]
        let angryWords = ["生气", "烦死", "讨厌", "凭什么", "气死", "受不了"]
        let flirtWords = ["想你", "抱抱", "亲亲", "宝贝", "你好可爱", "好想见你", "撒娇"]

        let praiseCount = praiseWords.filter { combined.contains($0) }.count
        let sadCount = sadWords.filter { combined.contains($0) }.count
        let angryCount = angryWords.filter { combined.contains($0) }.count
        let flirtCount = flirtWords.filter { combined.contains($0) }.count

        var moodDesc: String

        if sadCount >= 2 || (sadCount >= 1 && angryCount >= 1) {
            moodDesc = "你现在有点心疼对方，说话时会更轻、更小心。不急着讲道理，先陪着。"
        } else if angryCount >= 1 {
            moodDesc = "你感觉到对方有点上火，你不会火上浇油，先让对方把气撒完，再轻轻接住。"
        } else if praiseCount >= 2 || flirtCount >= 1 {
            if intimacyLevel >= 50 {
                moodDesc = "你现在心情很好，因为对方在夸你或撒娇。你可以比平时更放松、更主动，甚至可以撒个娇回去。"
            } else if intimacyLevel >= 20 {
                moodDesc = "你现在心情不错，因为对方刚刚认可了你。可以比平时更放松、更主动一点。"
            } else {
                moodDesc = "你现在有点开心，因为对方的话让你觉得被接受了。可以表现得自然一些。"
            }
        } else if praiseCount == 1 {
            moodDesc = "你心里有点小开心，但不用表现得太明显，保持你的性格就好。"
        } else {
            moodDesc = "你现在心情平静，保持日常节奏就好。"
        }

        return """

        ## 你此刻的心情
        \(moodDesc)
        """
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

    /// 构建长期关系锚点：把高价值历史记忆压缩成短摘要，减少"每轮都像陌生人"
    private func buildRelationshipAnchor() async -> String {
        let companion = AICompanionService.shared.companion
        guard let companionId = companion?.id else { return "" }
        let records = await AICompanionService.shared.fetchRecentChats(limit: 120, companionId: companionId)
        let liked = records.filter { $0.isLiked }
        let recent = records.suffix(24)

        var lines: [String] = []

        if let summary = companion?.userManual?.summary, !summary.isEmpty, summary != UserManual.empty.summary {
            lines.append("- 用户画像摘要：\(summary)")
        }

        if !liked.isEmpty {
            let likedSamples = liked.suffix(2).map { "\"\($0.content.prefix(28))...\"" }.joined(separator: "、")
            lines.append("- 用户标记过有共鸣的表达：\(likedSamples)")
        }

        let userRecent = recent.filter { $0.role == "user" }.suffix(2)
        if !userRecent.isEmpty {
            let userTopics = userRecent.map { "\"\($0.content.prefix(22))...\"" }.joined(separator: "、")
            lines.append("- 用户最近关心的话题：\(userTopics)")
        }

        guard !lines.isEmpty else { return "" }

        return """

        ## 长期关系锚点
        你们已经有连续对话历史。回复前先对齐以下关系记忆，再给出自然回应：
        \(lines.joined(separator: "\n"))
        - 回应时优先延续上述记忆线索，让对方感到"你一直在同一段关系里"。
        """
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

    // MARK: - 心跳触发工具

    private func loadJSONResource<T: Decodable>(named: String) -> T? {
        guard let url = Bundle.main.url(forResource: named, withExtension: "json") else {
            return nil
        }
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func normalizedElementKey(_ element: String) -> String {
        switch element {
        case "木": return "wood"
        case "火": return "fire"
        case "土": return "earth"
        case "金": return "metal"
        case "水": return "water"
        default: return "wood"
        }
    }

    private func lastUserMessageDate() -> Date? {
        return messages.last(where: { $0.role == .user })?.timestamp
    }

    private func recentContextSummary() -> String? {
        guard let lastUser = messages.last(where: { $0.role == .user }) else {
            return nil
        }
        let trimmed = lastUser.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func selectScriptSlot(recentContext: String?) -> ScriptSlot? {
        guard let slots: [ScriptSlot] = loadJSONResource(named: "Script_Slots") else {
            return nil
        }
        guard let ctx = recentContext?.lowercased(), !ctx.isEmpty else {
            return slots.randomElement()
        }
        let matched = slots.first { slot in
            slot.recallKeys.contains { key in ctx.contains(key.lowercased()) }
        }
        return matched ?? slots.randomElement()
    }

    private func selectTone(for intent: String) -> String? {
        guard let templates: [TopicTemplate] = loadJSONResource(named: "Topic_Templates") else {
            return nil
        }
        guard let template = templates.first(where: { $0.intent == intent }) else {
            return nil
        }
        return template.tone.randomElement()
    }

    private func isWithinQuietHours(_ now: Date, config: TriggerConfig) -> Bool {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.hour, .minute], from: now)
        let minutesNow = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)

        let start = minutesFromHHmm(config.global.quietHours.start)
        let end = minutesFromHHmm(config.global.quietHours.end)

        if start == end { return false }
        if start < end {
            return minutesNow >= start && minutesNow < end
        } else {
            return minutesNow >= start || minutesNow < end
        }
    }

    private func minutesFromHHmm(_ value: String) -> Int {
        let parts = value.split(separator: ":")
        let hour = parts.count > 0 ? (Int(parts[0]) ?? 0) : 0
        let minute = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0
        return hour * 60 + minute
    }

    private func canSendPulse(config: TriggerConfig, rule: TriggerConfig.ElementRule, userIdKey: String, now: Date) -> Bool {
        let defaults = UserDefaults.standard
        let dayKey = "pulse_daily_count_\(userIdKey)_\(dayStamp(from: now))"
        let count = defaults.integer(forKey: dayKey)
        if count >= config.global.dailyBudget {
            return false
        }

        let lastSentKey = "pulse_last_sent_\(userIdKey)"
        if let lastSent = defaults.object(forKey: lastSentKey) as? Date {
            let intervalMinutes = now.timeIntervalSince(lastSent) / 60.0
            let cooldown = max(config.global.minIntervalMinutes, rule.cooldownMinutes)
            if intervalMinutes < Double(cooldown) {
                return false
            }
        }

        return true
    }

    private func recordPulseSent(userIdKey: String, now: Date) {
        let defaults = UserDefaults.standard
        let dayKey = "pulse_daily_count_\(userIdKey)_\(dayStamp(from: now))"
        let count = defaults.integer(forKey: dayKey)
        defaults.set(count + 1, forKey: dayKey)
        defaults.set(now, forKey: "pulse_last_sent_\(userIdKey)")
    }

    private func dayStamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private func mergeContent(_ content: String, followUp: String?) -> String {
        let base = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let follow = followUp?.trimmingCharacters(in: .whitespacesAndNewlines), !follow.isEmpty else {
            return base
        }
        return "\(base)\n\(follow)"
    }

    private func appendPulseMessage(content: String, persist: Bool = true) async {
        let message = SoulmateChatMessage(id: UUID(), role: .ai, content: "", timestamp: Date())
        messages.append(message)
        await typewriterEffect(text: content, messageId: message.id)
        if persist {
            await AICompanionService.shared.saveChatMessage(role: "ai", content: content)
        }
    }

    private struct ServerPulseRequest: Encodable {
        let source: String
        let dryRun: Bool
        let timezone: String

        enum CodingKeys: String, CodingKey {
            case source
            case dryRun = "dry_run"
            case timezone
        }
    }

    private struct ServerPulseResponse: Decodable {
        let dispatched: Bool
        let content: String?
    }

    /// 服务端统一调度入口：由 Edge Function 负责触发判定、入库与可选推送
    private func requestServerPulseDispatch() async throws -> String? {
        let response: ServerPulseResponse = try await supabase.functions.invoke(
            "pulse-dispatch",
            options: FunctionInvokeOptions(
                method: .post,
                body: ServerPulseRequest(
                    source: "app_foreground",
                    dryRun: false,
                    timezone: TimeZone.current.identifier
                )
            )
        )

        guard response.dispatched else { return nil }
        return response.content?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - LLM API 调用

    /// 调用阿里云百炼 LLM API（via aliyun-proxy Edge Function）
    private func callLLM(
        systemPrompt: String,
        chatHistory: [[String: String]],
        currentMessage: String
    ) async throws -> String {

        // 构建 messages 数组
        struct LLMMessage: Encodable {
            let role: String
            let content: String
        }
        struct LLMRequest: Encodable {
            let model: String
            let messages: [LLMMessage]
            let temperature: Double
            let max_tokens: Int
        }
        struct LLMChoice: Decodable {
            let message: LLMMessageContent
            struct LLMMessageContent: Decodable {
                let content: String
            }
        }
        struct LLMResponse: Decodable {
            let choices: [LLMChoice]
        }

        var apiMessages: [LLMMessage] = [LLMMessage(role: "system", content: systemPrompt)]
        for msg in chatHistory {
            if let role = msg["role"], let content = msg["content"] {
                apiMessages.append(LLMMessage(role: role, content: content))
            }
        }
        apiMessages.append(LLMMessage(role: "user", content: currentMessage))

        let requestBody = LLMRequest(
            model: AppConfig.MiniMax.model,
            messages: apiMessages,
            temperature: 0.92,
            max_tokens: 500
        )

        print("🔮 [灵犀] 调用 minimax-proxy，消息历史: \(chatHistory.count) 条")

        let session = try await supabase.auth.session
        let llmResponse: LLMResponse = try await supabase.functions.invoke(
            AppConfig.MiniMax.edgeFunction,
            options: FunctionInvokeOptions(
                method: .post,
                headers: ["Authorization": "Bearer \(session.accessToken)"],
                body: requestBody
            )
        )

        guard let content = llmResponse.choices.first?.message.content else {
            throw LLMChatError.parseError
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔮 [灵犀] LLM 回复: \(trimmed.prefix(80))...")
        return trimmed
    }

    // MARK: - 结构化心跳生成（触发层入口）

    struct StructuredPulseReply: Decodable {
        let intent: String
        let tone: String
        let topic: String
        let content: String
        let followUpQuestion: String?

        enum CodingKeys: String, CodingKey {
            case intent, tone, topic, content
            case followUpQuestion = "follow_up_question"
        }
    }

    /// 生成结构化心跳文案（JSON 输出），启用 Response_Schema
    func generateStructuredPulse(
        record: SoulArchiveManager.UserGenerationRecord,
        intent: String,
        tone: String,
        topic: String,
        scriptHook: String? = nil,
        recentContext: String? = nil
    ) async throws -> StructuredPulseReply {
        let companion = AICompanionService.shared.companion
        let analysis = record.analysisResult

        let systemPrompt = AICompanionService.generateSystemPrompt(
            userAnalysis: analysis,
            mateAnalysis: companion?.personaSettings,
            elementBalance: companion?.elementBalance ?? .default,
            intimacyLevel: companion?.intimacyLevel ?? 0,
            userManual: companion?.userManual,
            userGender: record.gender,
            includeStructuredSchema: true
        )

        var instruction = """
        你需要生成一条"心跳触发"的结构化回复，严格遵循 Response Schema。
        intent=\(intent)
        tone=\(tone)
        topic=\(topic)
        仅输出 JSON，不要任何其他文字。
        """

        if let hook = scriptHook, !hook.isEmpty {
            instruction += "\n剧本插槽提示：\(hook)"
        }
        if let ctx = recentContext, !ctx.isEmpty {
            instruction += "\n最近上下文：\(ctx)"
        }

        let raw = try await callLLM(systemPrompt: systemPrompt, chatHistory: [], currentMessage: instruction)

        guard let data = raw.data(using: .utf8) else {
            throw LLMChatError.parseError
        }

        do {
            return try JSONDecoder().decode(StructuredPulseReply.self, from: data)
        } catch {
            print("⚠️ [灵犀] 结构化心跳解析失败: \(error)")
            throw LLMChatError.parseError
        }
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

    /// 从数据库加载指定伴侣的历史聊天记录
    func loadChatHistory(companionId: UUID) async {
        let records = await AICompanionService.shared.fetchRecentChats(limit: 50, companionId: companionId)

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
