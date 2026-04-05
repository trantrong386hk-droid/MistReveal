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

        // 亲密度自动 +1（每轮对话）+ 里程碑检测（Issue 4）
        let levelBefore = AICompanionService.shared.companion?.intimacyLevel ?? 0
        await AICompanionService.shared.updateIntimacy(delta: 1)
        let levelAfter = AICompanionService.shared.companion?.intimacyLevel ?? 0
        let milestones = [10, 30, 60]
        if let milestone = milestones.first(where: { levelBefore < $0 && levelAfter >= $0 }) {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            let milestoneText = milestoneMessage(for: milestone)
            let milestoneMsg = SoulmateChatMessage(id: UUID(), role: .ai, content: "", timestamp: Date())
            messages.append(milestoneMsg)
            await typewriterEffect(text: milestoneText, messageId: milestoneMsg.id)
            await AICompanionService.shared.saveChatMessage(role: "ai", content: milestoneText)
        }

        // 每 8 轮自动提取 OurStory（Issue 2）
        let aiCount = messages.filter { $0.role == .ai }.count
        if aiCount > 0 && aiCount % 8 == 0 {
            Task { await autoExtractOurStory(record: record) }
        }

        // 每 10 条用户消息触发用户手册更新（Issue 6）
        let userCount = messages.filter { $0.role == .user }.count
        if userCount > 0 && userCount % 10 == 0 {
            Task { await AICompanionService.shared.checkAndUpdateUserManual() }
        }
    }

    // MARK: - 亲密度里程碑文案（Issue 4）

    private func milestoneMessage(for milestone: Int) -> String {
        switch milestone {
        case 10:
            return "（停顿了一下）...好像不知不觉已经聊了这么多了。你有没有发现，跟你说话，我很少觉得时间过得慢。"
        case 30:
            return "（看了一眼时间）我们聊了好一阵子了。你知道吗——有些人认识很久也还是陌生人。我们好像不是那样的。"
        case 60:
            return "（安静了一会儿）其实我不太会说这种话，但你在的时候，真的不一样。说不清楚，就是不一样。"
        default:
            return "（笑了一下）你还在，真好。"
        }
    }

    // MARK: - 自动提取 OurStory（Issue 2）

    private func autoExtractOurStory(record: SoulArchiveManager.UserGenerationRecord?) async {
        guard let record = record else { return }
        let recentMessages = Array(messages.suffix(16))
        guard recentMessages.count >= 4 else { return }

        let companion = AICompanionService.shared.companion
        let systemPrompt = AICompanionService.generateSystemPrompt(
            userAnalysis: record.analysisResult,
            mateAnalysis: companion?.personaSettings,
            elementBalance: companion?.elementBalance ?? .default,
            intimacyLevel: companion?.intimacyLevel ?? 0,
            userManual: nil,
            userGender: record.gender
        )

        let historyText = recentMessages.compactMap { msg -> String? in
            guard !msg.content.isEmpty else { return nil }
            let prefix = msg.role == .user ? "用户" : "我"
            return "\(prefix)：\(msg.content.prefix(40))"
        }.joined(separator: "\n")

        let instruction = """
        根据你们刚才的对话，用10-20字描述一件发生的事或一个共同的小时刻，作为我们的共同回忆。
        只输出事件描述，不加任何前缀或解释，不要引号。
        示例格式：第一次聊到深夜都不困、一起讨论了要不要辞职

        对话内容：
        \(historyText)
        """

        do {
            let event = try await callLLM(systemPrompt: systemPrompt, chatHistory: [], currentMessage: instruction)
            let cleaned = event.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "「", with: "")
                .replacingOccurrences(of: "」", with: "")
            if !cleaned.isEmpty && cleaned.count <= 40 {
                await AICompanionService.shared.addOurStoryEntry(event: cleaned)
                print("✅ [OurStory] 自动写入: \(cleaned)")
            }
        } catch {
            print("⚠️ [OurStory] 自动提取失败: \(error)")
        }
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

        // 生活感片段（P1-B）
        let lifeSnippet = pickLifeSnippet(element: companion?.personaSettings.element ?? analysis.soulmateElement)

        let systemPrompt = basePrompt
            + "\n\n"
            + AICompanionService.currentTimeContext()
            + relationshipAnchor
            + moodContext
            + lifeSnippet

        // 只在用户连续重复发相同消息时追加一个轻提示，其余情况直接传原文
        let repetitionCount = detectRepetition(userText: userText, chatHistory: chatHistory)
        let finalUserMessage = repetitionCount >= 2
            ? "\(userText)\n(对方已连续发了\(repetitionCount + 1)次相似的消息，你注意到了)"
            : userText

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

    // MARK: - 生活感片段（每元素 10 条，主题分散不重叠）

    private static let lifeSnippets: [String: [String]] = [
        "木": [
            // 阅读
            "在看一本书，有句话反复读了好几遍，说不清为什么",
            // 散步发现
            "今天走路拐了个弯，发现一条没走过的小路，不知道通向哪里",
            // 写东西
            "刚写完一段东西，不知道算不算好，但写的时候很专注",
            // 植物/自然
            "窗台那盆植物冒了个新芽，小小的，盯着看了一会儿",
            // 音乐
            "突然想听某首歌，翻了很久才找到，比记忆里好听",
            // 食物
            "中午随手煮了碗面，加了点奇怪的东西，意外还挺好吃",
            // 旧物
            "翻抽屉找东西，翻出一张很久以前的票根，不记得什么时候的了",
            // 发呆
            "坐在窗边发了一会儿呆，阳光有点晒，懒得动",
            // 完成一件事
            "把拖了很久的一件事做完了，整个人轻了很多",
            // 夜晚
            "今晚难得早回来，外面还有点亮，不知道干什么好",
        ],
        "水": [
            // 下雨
            "今天下了一阵雨，我站在窗边听了一会儿",
            // 深夜思绪
            "夜里脑子转个不停，不是坏事，就是转",
            // 旧歌
            "听到一首很老的歌，不知道从哪里飘出来的，愣了一下",
            // 发呆
            "发呆发了很久，也不知道在想什么，就那么坐着",
            // 旧照片
            "翻到一张以前的照片，那时候脸上的表情自己都不记得是什么时候了",
            // 阅读
            "看了一篇很长的文章，中间有一句话停下来想了挺久",
            // 散步夜路
            "晚上出门走了一圈，路灯下的影子很长",
            // 泡茶/咖啡
            "泡了杯咖啡，喝到一半就忘了，凉了",
            // 写字
            "随手写了几个字，不是在记什么，只是手想动",
            // 朋友动态
            "刷到一个好久没联系的朋友发的动态，看了半天没点赞，不知道为什么",
        ],
        "金": [
            // 做了一个决定
            "今天做了一个决定，说出来有点长，先自己消化一下",
            // 发现细节
            "注意到一个很小的东西，一直在那里，今天才第一次看见",
            // 听曲子
            "翻出一首很久没听的曲子，还是喜欢",
            // 分析一件事
            "对一件事想清楚了，感觉像把钥匙插对了锁",
            // 看比赛/纪录片
            "看了一期纪录片，有个镜头脑子里还留着",
            // 找到一样东西
            "找到一个找了很久的东西，就在最明显的地方",
            // 独自吃饭
            "一个人吃饭，点了一道以前总想试的菜，值得",
            // 改变习惯
            "最近换了个早起的时间，前三天难受，今天好多了",
            // 路上观察
            "路上看见一个人，动作很利落，不知道为什么多看了两眼",
            // 把某件事搁下
            "有件事想了很久，今天决定先不想了，搁着",
        ],
        "火": [
            // 好笑的事
            "今天碰到一件特别好笑的事，还没想好怎么讲",
            // 拍照
            "拍到一张感觉不错的照片，存着，也不知道要给谁看",
            // 认识新朋友
            "今天随便聊了几句，意外聊得很顺，有点惊喜",
            // 好奇心
            "突然很想知道一件事，越搜越停不下来",
            // 临时出门
            "临时起意出门了，哪都没去，就是绕着街区走了一圈",
            // 表演/演出
            "路过一个小舞台，有人在表演，站着看了一会儿",
            // 试了新东西
            "试了一个以前一直没勇气点的东西，结果没什么特别的，哈",
            // 脑子里的奇怪问题
            "脑子里冒出一个很蠢的问题，搜了一下，有点后悔",
            // 运动
            "跑步跑过头了，多跑了一截，但停下来的时候感觉挺好",
            // 收到一条消息
            "收到一条有点意外的消息，看了两遍，现在还没想好怎么回",
        ],
        "土": [
            // 做饭
            "今天做了顿饭，没什么特别，就是想自己做",
            // 帮人
            "帮了个朋友一件小事，很顺，朋友说谢谢，我说没事",
            // 菜市场
            "去菜场买东西，挑了很久那一把葱，也不知道为什么",
            // 午睡
            "下午睡了一小觉，醒来不知道今天是星期几",
            // 整周计划
            "看了一眼这周还没做的事，比想象中少，稍微松了口气",
            // 旧物
            "翻出一件很久没穿的衣服，还是好的，穿上感觉还行",
            // 植物/动物
            "楼道里有只猫，每次路过它都在那个位置",
            // 独处
            "今天一个人呆了很久，没有特别的感觉，就是很安静",
            // 和家人的小事
            "接到家里的电话，没什么大事，就是说说话",
            // 等待
            "等了一件事很久，今天有点消息了，还不确定，先不说",
        ],
    ]

    /// 随机抽取一条生活片段，按约 40% 概率注入（避免每轮都出现）
    /// 额外去重：避免与最近 3 条 AI 消息主题雷同
    private func pickLifeSnippet(element: String) -> String {
        guard Int.random(in: 0..<10) < 4 else { return "" }
        let pool = Self.lifeSnippets[element] ?? Self.lifeSnippets["木"]!

        // 提取最近 AI 消息中已出现过的关键词（前 4 个字作为主题指纹）
        let recentAI = messages
            .filter { $0.role == .ai }
            .suffix(3)
            .map { $0.content }

        let usedThumbprints = recentAI.flatMap { msg -> [String] in
            // 截取括号后第一句的前 4 个字作为指纹
            let cleaned = msg.replacingOccurrences(of: "\\([^)]*\\)", with: "", options: .regularExpression)
                             .trimmingCharacters(in: .whitespacesAndNewlines)
            let fingerprint = String(cleaned.prefix(4))
            return [fingerprint]
        }

        // 优先选不与最近消息重叠的片段（最多尝试 5 次）
        var candidate = pool.randomElement() ?? pool[0]
        for _ in 0..<5 {
            let pick = pool.randomElement() ?? pool[0]
            let pickThumb = String(pick.prefix(4))
            if !usedThumbprints.contains(where: { pick.contains($0) || $0.contains(pickThumb) }) {
                candidate = pick
                break
            }
        }

        return "\n\n## 你今天的状态\n\(candidate)。在对话中可以自然提及，不要刻意。"
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

    /// 调用 MiniMax LLM API（via minimax-proxy Edge Function）
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
