import SwiftUI
import Combine

// MARK: - 聊天消息模型
struct SoulmateChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date

    enum MessageRole {
        case ai
        case user
    }

    static func == (lhs: SoulmateChatMessage, rhs: SoulmateChatMessage) -> Bool {
        lhs.id == rhs.id && lhs.content == rhs.content
    }
}

// MARK: - 灵犀聊天主视图
struct SoulmateAIChatView: View {
    @StateObject private var chatService = SoulmateAIChatService()
    @ObservedObject private var archiveManager = SoulArchiveManager.shared

    @State private var inputText = ""
    @State private var hasTriggeredWelcome = false
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isInputFocused: Bool

    var body: some View {
        // 主内容
        VStack(spacing: 0) {
            // 顶部标题栏
            headerView

            // 检查是否已完成灵魂分析
            if archiveManager.myRecord == nil {
                // 未完成分析的提示
                unlockedView
            } else {
                // 聊天内容
                chatContentView
            }
        }
        // 使用 background 修饰符，背景不参与布局计算
        .background(backgroundView)
        .onAppear {
            Task {
                await archiveManager.fetchUserRecords()
                // 加载 AI 伴侣数据（必须在发送消息前加载，否则消息无法保存）
                await AICompanionService.shared.fetchCompanion()
                // 加载历史聊天记录
                await chatService.loadChatHistory()

                // 只有历史为空时才发送欢迎语
                if chatService.messages.isEmpty, let record = archiveManager.myRecord, !hasTriggeredWelcome {
                    hasTriggeredWelcome = true
                    await chatService.sendWelcomeMessage(record: record)
                }
            }
        }
        .onChange(of: archiveManager.myRecord) { _, newRecord in
            // 当 myRecord 从 nil 变为有值时触发
            if newRecord != nil && !hasTriggeredWelcome {
                hasTriggeredWelcome = true
                Task {
                    await chatService.sendWelcomeMessage(record: newRecord!)
                }
            }
        }
        // 监听高匹配用户出现的通知
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HighMatchUserAppeared"))) { _ in
            Task {
                // 延迟一点，让用户看到消息
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                // TODO: 实现高匹配通知处理
            }
        }
    }

    // MARK: - 背景视图
    private var backgroundView: some View {
        GeometryReader { geometry in
            ZStack {
                // 底色兜底，防止白色露出
                Color(hex: "#0A0A12")

                if let imageUrl = archiveManager.myRecord?.imageUrl,
                   let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                                .blur(radius: 15)
                                .overlay(Color.black.opacity(0.35))
                        case .failure(_), .empty:
                            defaultBackground
                        @unknown default:
                            defaultBackground
                        }
                    }
                } else {
                    defaultBackground
                }
            }
        }
        .ignoresSafeArea()
    }

    private var defaultBackground: some View {
        ZStack {
            Color(hex: "#0A0A12")

            // 星云装饰
            Circle()
                .fill(Color(hex: "#16213E").opacity(0.6))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: -100, y: -200)

            Circle()
                .fill(Color(hex: "#E94560").opacity(0.15))
                .frame(width: 250, height: 250)
                .blur(radius: 80)
                .offset(x: 100, y: 300)
        }
    }

    // MARK: - 顶部标题栏
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("灵犀")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                if archiveManager.myRecord != nil {
                    Text("与 Ta 心有灵犀")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 60)  // 增加顶部间距，避免与状态栏重叠
        .padding(.bottom, 12)
    }

    // MARK: - 未解锁视图
    private var unlockedView: some View {
        VStack(spacing: 24) {
            Spacer()

            // 锁定图标
            ZStack {
                Circle()
                    .stroke(Color(hex: "#E94560").opacity(0.3), lineWidth: 2)
                    .frame(width: 100, height: 100)

                Image(systemName: "heart.slash")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "#E94560").opacity(0.6))
            }

            VStack(spacing: 12) {
                Text("灵犀未开启")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("完成灵魂推演后\n即可与你的灵魂伴侣对话")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // 引导按钮
            Button(action: {
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
            }) {
                HStack(spacing: 8) {
                    Text("开始灵魂推演")
                        .font(.system(size: 15, weight: .medium))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#E94560"), Color(hex: "#1A1A2E")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
            }
            .padding(.top, 8)

            Spacer()
        }
        .padding(.bottom, 100)  // 给 TabBar 留空间
    }

    // MARK: - 聊天内容视图
    private var chatContentView: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(chatService.messages) { message in
                                ChatBubbleView(message: message) {
                                    chatService.recordResonance(for: message)
                                }
                                .id(message.id)
                            }

                            // 打字指示器
                            if chatService.isTyping {
                                TypingIndicator()
                                    .id("typing")
                            }

                            // 底部留白
                            Color.clear.frame(height: 20)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onTapGesture {
                        isInputFocused = false
                    }
                    .onChange(of: chatService.messages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: chatService.messages.last?.content) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: keyboardHeight) { _, _ in
                        // 键盘高度变化时滚动到底部
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }

                // 底部输入框
                inputBar
            }
            // 键盘弹出时紧贴键盘顶部（减去底部安全区域），收起时给 TabBar 留 90pt 空间
            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - geometry.safeAreaInsets.bottom : 90)
        }
        .onReceive(Publishers.keyboardHeight) { height in
            withAnimation(.easeOut(duration: 0.25)) {
                self.keyboardHeight = height
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if chatService.isTyping {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let lastMessage = chatService.messages.last {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }

    // MARK: - 输入框
    private var inputBar: some View {
        HStack(spacing: 12) {
            // 输入框
            TextField("说点什么...", text: $inputText)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(24)
                .focused($isInputFocused)
                .submitLabel(.send)  // 键盘回车键显示"发送"
                .onSubmit {
                    sendMessage()  // 按回车键发送消息
                }

            // 发送按钮
            Button(action: sendMessage) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Group {
                            if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Circle().fill(Color.gray.opacity(0.3))
                            } else {
                                Circle().fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#E94560"), Color(hex: "#FF6B6B")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            }
                        }
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatService.isTyping)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color(hex: "#0A0A12").opacity(0.8))
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        isInputFocused = false

        Task {
            await chatService.sendMessage(text, record: archiveManager.myRecord)
        }
    }
}

// MARK: - 聊天气泡视图
struct ChatBubbleView: View {
    let message: SoulmateChatMessage
    var onResonance: (() -> Void)? = nil  // 共鸣反馈回调

    @State private var hasResonance = false  // 是否已点击共鸣

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .ai {
                // AI 头像
                aiAvatar

                // AI 消息气泡（左侧）+ 反馈按钮
                VStack(alignment: .leading, spacing: 6) {
                    messageBubble
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)

                    // 共鸣反馈按钮（仅 AI 消息显示）
                    if !message.content.isEmpty {
                        Button(action: {
                            if !hasResonance {
                                hasResonance = true
                                onResonance?()
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text("🔮")
                                    .font(.system(size: 12))
                                Text("有共鸣")
                                    .font(.system(size: 10))
                                    .foregroundColor(hasResonance ? Color(hex: "#E94560") : .white.opacity(0.5))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(hasResonance ? Color(hex: "#E94560").opacity(0.2) : Color.white.opacity(0.08))
                            )
                        }
                        .disabled(hasResonance)
                    }
                }

                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)

                // 用户消息气泡（右侧）
                messageBubble
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
            }
        }
    }

    private var aiAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#E94560"), Color(hex: "#FF6B6B")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)

            Image(systemName: "heart.fill")
                .font(.system(size: 14))
                .foregroundColor(.white)
        }
    }

    @ViewBuilder
    private var messageBubble: some View {
        if message.role == .ai {
            Text(message.content)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 20))
        } else {
            Text(message.content)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#E94560"), Color(hex: "#1A1A2E")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

// MARK: - 打字指示器
struct TypingIndicator: View {
    @State private var animationOffset: CGFloat = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // AI 头像
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#E94560"), Color(hex: "#FF6B6B")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: "heart.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }

            // 打字动画
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 8, height: 8)
                        .offset(y: animationOffset(for: index))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 20))

            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                animationOffset = -5
            }
        }
    }

    private func animationOffset(for index: Int) -> CGFloat {
        let delay = Double(index) * 0.15
        return animationOffset * cos(delay * .pi)
    }
}

// MARK: - 键盘高度监听
extension Publishers {
    static var keyboardHeight: AnyPublisher<CGFloat, Never> {
        let willShow = NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { notification -> CGFloat in
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
            }

        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .map { _ -> CGFloat in 0 }

        return MergeMany(willShow, willHide)
            .eraseToAnyPublisher()
    }
}

#Preview {
    SoulmateAIChatView()
}
