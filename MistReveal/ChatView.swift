import SwiftUI
import Combine

/// 聊天界面
struct ChatView: View {
    let user: MatchingService.MatchedUser
    let conversationId: String
    let initialMessage: String?  // 破冰话题作为第一条消息

    @StateObject private var chatService = ChatService.shared
    @State private var inputMessage = ""
    @State private var scrollToBottom = false
    @State private var currentUserId: String?
    @State private var isAITyping = false  // AI 正在输入状态
    @FocusState private var isInputFocused: Bool

    // 错误提示状态
    @State private var showError = false
    @State private var errorMessage = ""

    // 键盘适配
    @State private var keyboardHeight: CGFloat = 0

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            let topSafeArea = geometry.safeAreaInsets.top
            let bottomSafeArea = geometry.safeAreaInsets.bottom

            ZStack {
                // 背景
                Color(hex: "#0A0A12")
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 导航栏 - 需要顶部安全区 padding
                    navigationBar
                        .padding(.top, topSafeArea)

                    // 消息列表 - 占据所有剩余空间
                    messageList
                        .frame(maxHeight: .infinity)

                    // 输入框 - 固定在底部
                    inputBar
                        .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - bottomSafeArea : max(bottomSafeArea, 90))
                        .animation(.easeOut(duration: 0.25), value: keyboardHeight)
                }
            }
            .ignoresSafeArea()
        }
        .navigationBarHidden(true)
        .onAppear {
            setupChat()
        }
        .onDisappear {
            chatService.unsubscribe()
        }
        // 键盘监听
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        // 错误提示 Alert
        .alert("发送失败", isPresented: $showError) {
            Button("重试") {
                // 重试发送
                if !inputMessage.isEmpty {
                    sendMessage()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - 导航栏

    private var navigationBar: some View {
        HStack(spacing: 12) {
            // 返回按钮
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
            }

            // 用户信息
            HStack(spacing: 10) {
                // 头像
                ZStack {
                    Circle()
                        .fill(elementColor(user.userElement).opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundColor(elementColor(user.userElement))
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(user.nickname)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        if user.isTestUser {
                            Text("测试")
                                .font(.system(size: 9))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(3)
                        }
                    }

                    HStack(spacing: 4) {
                        Text("\(user.userElement)命")
                            .font(.system(size: 11))
                            .foregroundColor(elementColor(user.userElement))

                        Text("•")
                            .foregroundColor(.white.opacity(0.3))

                        Text("\(user.matchScore)%匹配")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#E94560"))
                    }
                }
            }

            Spacer()

            // 更多按钮
            Button(action: {
                // TODO: 显示更多选项
            }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            Color(hex: "#1A1A2E")
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }

    // MARK: - 消息列表

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12, pinnedViews: []) {
                    // 顶部提示
                    if chatService.messages.isEmpty && initialMessage == nil {
                        emptyStateView
                    } else {
                        // 聊天开始提示
                        chatStartHint

                        // 消息列表
                        ForEach(chatService.messages) { message in
                            MessageBubble(
                                message: message,
                                isFromMe: message.senderId == currentUserId,
                                userElement: user.userElement
                            )
                            .id(message.id)
                        }

                        // AI 正在输入指示器
                        if isAITyping {
                            HStack {
                                AITypingIndicator()
                                Spacer()
                            }
                            .padding(.leading, 8)
                            .transition(.opacity)
                            .id("ai_typing")
                        }

                        // 底部占位符，用于滚动锚点
                        Color.clear
                            .frame(height: 1)
                            .id("bottom_anchor")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: chatService.messages.count) { _, _ in
                // 滚动到底部
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isAITyping) { _, newValue in
                // AI 输入状态变化时滚动
                if newValue {
                    scrollToBottom(proxy: proxy)
                }
            }
            .onChange(of: keyboardHeight) { _, newHeight in
                // 键盘弹出时滚动到底部
                if newHeight > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
            .onAppear {
                // 初始滚动到底部
                scrollToBottom(proxy: proxy)
            }
        }
    }

    /// 滚动到底部的辅助方法
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if isAITyping {
                proxy.scrollTo("ai_typing", anchor: .bottom)
            } else if let lastMessage = chatService.messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.2))

            Text("开始你们的对话吧")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    // MARK: - 聊天开始提示

    private var chatStartHint: some View {
        VStack(spacing: 8) {
            Text("💫 灵魂共振连接成功")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))

            Text("你们的匹配度高达 \(user.matchScore)%")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#E94560").opacity(0.8))
        }
        .padding(.vertical, 16)
    }

    // MARK: - 输入框

    private var inputBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // 输入框
                HStack {
                    TextField("发送消息...", text: $inputMessage)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .focused($isInputFocused)
                        .submitLabel(.send)
                        .onSubmit {
                            if canSend {
                                sendMessage()
                            }
                        }

                    if !inputMessage.isEmpty {
                        Button(action: {
                            inputMessage = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.3))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )

                // 发送按钮
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: canSend ? [Color(hex: "#E94560"), Color(hex: "#1A1A2E")] : [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(22)
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(
            Color(hex: "#1A1A2E")
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }

    // MARK: - 计算属性

    private var canSend: Bool {
        !inputMessage.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - 方法

    private func setupChat() {
        Task {
            print("🔵 [ChatView] setupChat 开始")

            // 1. 获取当前用户ID
            currentUserId = await chatService.getAuthenticatedUserId()
            if currentUserId == nil {
                print("❌ [ChatView] 无法获取用户ID，用户可能未登录")
                await MainActor.run {
                    errorMessage = "用户未登录，请重新登录"
                    showError = true
                }
                return
            }
            print("🔵 [ChatView] 当前用户ID: \(currentUserId ?? "nil")")

            // 2. 先订阅实时消息（避免错过消息）
            chatService.subscribeToMessages(conversationId: conversationId)
            print("🔵 [ChatView] 已订阅实时消息")

            // 3. 获取历史消息
            await chatService.fetchMessages(conversationId: conversationId)
            print("🔵 [ChatView] 已获取历史消息: \(chatService.messages.count) 条")

            // 4. 如果有初始消息（破冰话题），发送它（带重试）
            if let initial = initialMessage {
                await sendIceBreakerWithRetry(topic: initial, maxRetries: 3)
            }

            // 5. 标记已读
            await chatService.markAsRead(conversationId: conversationId)
            print("🔵 [ChatView] setupChat 完成")
        }
    }

    /// 带重试的破冰话题发送
    private func sendIceBreakerWithRetry(topic: String, maxRetries: Int) async {
        // 检查破冰消息是否已存在
        let hasIceBreakerMessage = chatService.messages.contains { message in
            message.content == topic && message.isIceBreaker
        }

        guard !hasIceBreakerMessage else {
            print("🔵 [ChatView] 破冰消息已存在，跳过发送")
            return
        }

        print("🔵 [ChatView] 发送破冰话题: \(topic)")

        var retryCount = 0
        while retryCount < maxRetries {
            let result = await chatService.sendMessage(
                conversationId: conversationId,
                content: topic,
                type: "ice_breaker"
            )

            switch result {
            case .success(let message):
                print("✅ [ChatView] 破冰话题发送成功: \(message.id)")
                // 成功 - 触发 AI 回复（如果是测试用户）
                if user.isTestUser {
                    await triggerAIReply()
                }
                return

            case .failure(let error):
                retryCount += 1
                print("⚠️ [ChatView] 破冰话题发送失败 (第 \(retryCount) 次): \(error.localizedDescription)")

                if retryCount < maxRetries {
                    // 等待 1 秒后重试
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
        }

        // 重试失败 - 显示错误提示
        print("❌ [ChatView] 破冰话题发送失败，已重试 \(maxRetries) 次")
        await MainActor.run {
            errorMessage = "发送破冰话题失败，请稍后重试"
            showError = true
        }
    }

    private func sendMessage() {
        let content = inputMessage.trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return }

        // 先清空输入框，提供即时反馈
        let messageToSend = inputMessage
        inputMessage = ""

        print("🔵 [ChatView] 用户发送消息: \(messageToSend)")

        Task {
            let result = await chatService.sendMessage(
                conversationId: conversationId,
                content: messageToSend,
                type: "text"
            )

            switch result {
            case .success(let message):
                print("✅ [ChatView] 消息发送成功: \(message.id)")
                // 如果对方是测试用户，触发 AI 回复
                if user.isTestUser {
                    await triggerAIReply()
                }

            case .failure(let error):
                print("❌ [ChatView] 消息发送失败: \(error.localizedDescription)")
                // 发送失败 - 恢复输入内容并提示
                await MainActor.run {
                    inputMessage = messageToSend  // 恢复用户输入
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    /// 触发 AI 回复（仅测试用户）
    private func triggerAIReply() async {
        // 显示"正在输入"指示器
        await MainActor.run {
            isAITyping = true
        }

        // 模拟真人打字延迟（1-2.5 秒）
        let delay = Double.random(in: 1.0...2.5)
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        // 生成 AI 回复
        if let reply = await chatService.generateAIReply(
            testUser: user,
            chatHistory: chatService.messages
        ) {
            // 发送 AI 回复
            await chatService.sendAIMessage(
                conversationId: conversationId,
                content: reply,
                testUserId: user.id
            )
        }

        // 隐藏"正在输入"指示器
        await MainActor.run {
            isAITyping = false
        }
    }

    private func elementColor(_ element: String) -> Color {
        switch element {
        case "金": return Color(hex: "#FFD700")
        case "木": return Color(hex: "#4CAF50")
        case "水": return Color(hex: "#2196F3")
        case "火": return Color(hex: "#FF5722")
        case "土": return Color(hex: "#8D6E63")
        default: return Color.white
        }
    }
}

// MARK: - 消息气泡

struct MessageBubble: View {
    let message: ChatService.Message
    let isFromMe: Bool
    let userElement: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromMe {
                Spacer(minLength: 60)
                timeLabel
                bubbleContent
            } else {
                bubbleContent
                timeLabel
                Spacer(minLength: 60)
            }
        }
    }

    private var bubbleContent: some View {
        VStack(alignment: isFromMe ? .trailing : .leading, spacing: 4) {
            // 破冰话题标签
            if message.isIceBreaker {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                    Text("破冰话题")
                        .font(.system(size: 10))
                }
                .foregroundColor(Color(hex: "#E94560"))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(hex: "#E94560").opacity(0.15))
                .cornerRadius(8)
            }

            // 消息内容
            Text(message.content)
                .font(.system(size: 15))
                .foregroundColor(isFromMe ? .white : .white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            isFromMe
                            ? LinearGradient(
                                colors: [Color(hex: "#E94560"), Color(hex: "#1A1A2E")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            isFromMe ? Color.clear : Color.white.opacity(0.1),
                            lineWidth: 1
                        )
                )
        }
    }

    private var timeLabel: some View {
        Text(message.formattedTime)
            .font(.system(size: 10))
            .foregroundColor(.white.opacity(0.3))
    }
}

// MARK: - AI 正在输入指示器

struct AITypingIndicator: View {
    @State private var animationOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 6) {
            // 三个跳动的点
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 8, height: 8)
                    .offset(y: animationOffset)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: animationOffset
                    )
            }

            Text("正在输入...")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .onAppear {
            animationOffset = -4
        }
    }
}

