import SwiftUI

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
    var onCompassTap: (() -> Void)? = nil  // 翻转到地图的回调

    @StateObject private var chatService = SoulmateAIChatService()
    @StateObject private var archiveManager = SoulArchiveManager.shared

    @State private var inputText = ""
    @State private var hasTriggeredWelcome = false
    @State private var selectedElement: FiveElement? = nil
    @FocusState private var isInputFocused: Bool

    // 五行元素枚举
    enum FiveElement: String, CaseIterable {
        case metal = "金"
        case wood = "木"
        case water = "水"
        case fire = "火"
        case earth = "土"

        var icon: String {
            switch self {
            case .metal: return "circle.fill"      // 金 - 圆形
            case .wood: return "leaf.fill"         // 木 - 叶子
            case .water: return "drop.fill"        // 水 - 水滴
            case .fire: return "flame.fill"        // 火 - 火焰
            case .earth: return "mountain.2.fill"  // 土 - 山
            }
        }

        var color: Color {
            switch self {
            case .metal: return Color(hex: "#FFD700")  // 金色
            case .wood: return Color(hex: "#4CAF50")   // 绿色
            case .water: return Color(hex: "#2196F3")  // 蓝色
            case .fire: return Color(hex: "#FF5722")   // 红橙色
            case .earth: return Color(hex: "#8B4513")  // 棕色
            }
        }

        var prompt: String {
            switch self {
            case .metal: return "请以更加理性、冷静、有条理的方式回复"
            case .wood: return "请以更加温和、有生机、富有成长感的方式回复"
            case .water: return "请以更加温柔、包容、善解人意的方式回复"
            case .fire: return "请以更加热情、主动、充满激情的方式回复"
            case .earth: return "请以更加稳重、踏实、让人安心的方式回复"
            }
        }
    }

    var body: some View {
        ZStack {
            // 背景 - 模糊的灵魂伴侣画像
            backgroundView

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
        }
        .onAppear {
            Task {
                await archiveManager.fetchUserRecords()
                // 如果 myRecord 已经存在（从缓存加载），直接触发欢迎语
                if let record = archiveManager.myRecord, !hasTriggeredWelcome {
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
    }

    // MARK: - 背景视图
    private var backgroundView: some View {
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
                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                            .clipped()
                            .blur(radius: 30)
                            .overlay(Color.black.opacity(0.55))
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

            // 罗盘按钮（仅完成分析后显示）
            if archiveManager.myRecord != nil, let onCompassTap = onCompassTap {
                RotatingCompassButton(action: onCompassTap)
            }

            // 清空对话按钮
            if !chatService.messages.isEmpty {
                Button(action: {
                    chatService.clearMessages()
                    hasTriggeredWelcome = false
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
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
            Spacer()
        }
    }

    // MARK: - 聊天内容视图
    private var chatContentView: some View {
        VStack(spacing: 0) {
            // 聊天消息列表
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

                        // 底部留白，避免被输入框遮挡
                        Color.clear.frame(height: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively) // 滑动时可以收起键盘
                .onTapGesture {
                    // 点击空白区域收起键盘
                    isInputFocused = false
                }
                .onChange(of: chatService.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: chatService.messages.last?.content) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }

            // 五行调教选择器
            elementSelector

            // 底部输入框
            inputBar
                .padding(.bottom, isInputFocused ? 0 : 80) // 键盘弹出时不需要 TabBar 空间
        }
    }

    // MARK: - 五行调教选择器
    private var elementSelector: some View {
        HStack(spacing: 20) {
            ForEach(FiveElement.allCases, id: \.self) { element in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if selectedElement == element {
                            selectedElement = nil  // 再次点击取消选中
                        } else {
                            selectedElement = element
                        }
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: element.icon)
                            .font(.system(size: 16))
                            .foregroundColor(selectedElement == element ? element.color : .white.opacity(0.4))

                        Text(element.rawValue)
                            .font(.system(size: 10))
                            .foregroundColor(selectedElement == element ? element.color : .white.opacity(0.4))
                    }
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(selectedElement == element ? element.color.opacity(0.2) : Color.clear)
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
            TextField("说点什么...", text: $inputText, axis: .vertical)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(24)
                .lineLimit(1...4)
                .focused($isInputFocused)

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

        let elementPrompt = selectedElement?.prompt

        Task {
            await chatService.sendMessage(text, record: archiveManager.myRecord, elementPrompt: elementPrompt)
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
                                Text(hasResonance ? "有共鸣" : "说得准")
                                    .font(.system(size: 10))
                                    .foregroundColor(hasResonance ? Color(hex: "#E94560") : .white.opacity(0.4))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(hasResonance ? Color(hex: "#E94560").opacity(0.2) : Color.white.opacity(0.1))
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

#Preview {
    SoulmateAIChatView()
}
