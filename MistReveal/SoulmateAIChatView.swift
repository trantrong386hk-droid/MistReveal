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
    @ObservedObject private var chatService = SoulmateAIChatService.shared
    @ObservedObject private var archiveManager = SoulArchiveManager.shared
    @ObservedObject private var companionService = AICompanionService.shared

    @State private var inputText = ""
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isInputFocused: Bool

    @State private var backgroundImage: UIImage?

    @State private var showNameEditor = false
    @State private var editingName = ""

    /// 伴侣名字：优先使用用户自定义名字，否则默认"灵犀"
    private var companionName: String {
        companionService.companion?.personaSettings.name ?? "灵犀"
    }

    var body: some View {
        // ZStack 分层：底层背景 + 上层内容
        ZStack {
            // 底层：全屏清晰背景
            backgroundView

            // 上层：内容
            VStack(spacing: 0) {
                // 顶部信息栏
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
                // 背景图加载放到独立 Task，不阻塞聊天功能
                Task { await loadBackgroundImage() }
                // 加载 AI 伴侣数据（必须在发送消息前加载，否则消息无法保存）
                await AICompanionService.shared.fetchCompanion()
                // 加载历史聊天记录
                await chatService.loadChatHistory()

                // 只有历史为空且未触发过欢迎语时才发送
                if chatService.messages.isEmpty, let record = archiveManager.myRecord, !chatService.hasTriggeredWelcome {
                    chatService.hasTriggeredWelcome = true
                    await chatService.sendWelcomeMessage(record: record)
                }
            }
        }
        .onChange(of: archiveManager.myRecord?.imageUrl) { _, _ in
            Task {
                backgroundImage = nil
                await loadBackgroundImage()
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
        // 命名弹窗
        .alert("给 Ta 起个名字", isPresented: $showNameEditor) {
            TextField("输入名字", text: $editingName)
            Button("确定") {
                let name = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return }
                Task {
                    await companionService.updateCompanionName(name)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这个名字会显示在聊天界面顶部")
        }
    }

    // MARK: - 背景视图（清晰全屏人像）
    private var backgroundView: some View {
        GeometryReader { geometry in
            ZStack {
                // 底色兜底，防止白色露出
                Color(hex: "#0A0A12")

                if let uiImage = backgroundImage {
                    // 根据图片宽高比计算 scaledToFit 后的实际高度
                    let aspect = uiImage.size.height / uiImage.size.width
                    let fittedHeight = geometry.size.width * aspect
                    let fadeZone: CGFloat = 180  // 清晰→模糊过渡区域

                    // 第1层：模糊图铺满全屏，作为底部延伸
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .blur(radius: 30)
                        .overlay(Color.black.opacity(0.45))

                    // 第2层：清晰主图（不裁切），底部渐变透明过渡到模糊层
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geometry.size.width)
                        .mask(
                            VStack(spacing: 0) {
                                Color.black
                                    .frame(height: max(fittedHeight - fadeZone, 0))
                                LinearGradient(
                                    colors: [.black, .clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                .frame(height: fadeZone)
                            }
                        )
                        .frame(maxHeight: .infinity, alignment: .top)

                    // 第3层：整体暗角渐变（聊天文字可读性）
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.18),
                            Color.black.opacity(0.04),
                            Color.black.opacity(0.25),
                            Color.black.opacity(0.65)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
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

    // MARK: - 顶部信息栏（星野风格）
    private var headerView: some View {
        HStack(spacing: 12) {
            // 返回按钮
            Button(action: {
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }

            // 左侧：小圆形头像
            if let uiImage = backgroundImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } else {
                headerAvatarPlaceholder
            }

            // 名字 + 标签
            VStack(alignment: .leading, spacing: 2) {
                Text(companionName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .onTapGesture {
                        editingName = companionName == "灵犀" ? "" : companionName
                        showNameEditor = true
                    }

            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.3), Color.black.opacity(0.12), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    private var headerAvatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#E94560").opacity(0.6))
                .frame(width: 36, height: 36)
            Image(systemName: "heart.fill")
                .font(.system(size: 14))
                .foregroundColor(.white)
        }
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
        .padding(.bottom, 20)
    }

    // MARK: - 聊天内容视图
    private var chatContentView: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // 顶部留白 — 让初始消息从屏幕中下部开始，不遮挡人物面部
                            Color.clear.frame(height: geometry.size.height * 0.4)

                            ForEach(chatService.messages) { message in
                                ChatBubbleView(message: message)
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
                    // 顶部消息渐隐 mask
                    .mask(
                        VStack(spacing: 0) {
                            // 顶部 ~120pt 从透明渐变到不透明
                            LinearGradient(
                                colors: [.clear, .black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 120)

                            // 其余部分完全不透明
                            Color.black
                        }
                    )
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

                // 底部输入框 + 渐变过渡
                inputBar
            }
            // 键盘弹出时紧贴键盘顶部（减去底部安全区域），收起时给 TabBar 留 90pt 空间
            .padding(.bottom, keyboardHeight > 0 ? keyboardHeight - geometry.safeAreaInsets.bottom : 0)
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
            TextField("发送消息给\(companionName)", text: $inputText)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: "#1A1A2E").opacity(0.78),
                                    Color(hex: "#0F1020").opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.09), lineWidth: 0.8)
                        )
                )
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private func loadBackgroundImage() async {
        guard let imageUrl = archiveManager.myRecord?.imageUrl,
              let url = URL(string: imageUrl),
              backgroundImage == nil else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: data) {
                backgroundImage = image
            }
        } catch {
            print("❌ 背景图片加载失败: \(error)")
        }
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
    private let screenWidth = UIScreen.main.bounds.width

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .ai {
                // AI 消息气泡（左侧，无头像）
                messageBubble
                    .frame(maxWidth: screenWidth * 0.8, alignment: .leading)

                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)

                // 用户消息气泡（右侧）
                messageBubble
                    .frame(maxWidth: screenWidth * 0.8, alignment: .trailing)
            }
        }
    }

    @ViewBuilder
    private var messageBubble: some View {
        if message.role == .ai {
            // AI 气泡：深色半透明 + 微动作分色
            styledAIText(message.content)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.5))
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.07), lineWidth: 0.8)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            // 用户气泡：保持原有红色渐变
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
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    /// 解析 AI 文本中的微动作（括号内容）并使用不同样式渲染
    private func styledAIText(_ text: String) -> Text {
        // 正则匹配中英文括号内的微动作
        let pattern = "[（(][^）)]+[）)]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return Text(text)
                .font(.system(size: 15, weight: .medium))
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        if matches.isEmpty {
            return Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
        }

        var result = Text("")
        var lastEnd = 0

        for match in matches {
            let matchRange = match.range

            // 匹配之前的对白部分
            if matchRange.location > lastEnd {
                let dialogueRange = NSRange(location: lastEnd, length: matchRange.location - lastEnd)
                let dialogue = nsText.substring(with: dialogueRange)
                if !dialogue.isEmpty {
                    result = result + Text(dialogue)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                }
            }

            // 微动作部分（括号内容）
            let action = nsText.substring(with: matchRange)
            result = result + Text(action)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.55))

            lastEnd = matchRange.location + matchRange.length
        }

        // 剩余的对白部分
        if lastEnd < nsText.length {
            let remaining = nsText.substring(from: lastEnd)
            if !remaining.isEmpty {
                result = result + Text(remaining)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }
        }

        return result
    }
}

// MARK: - 打字指示器（无头像，深色气泡）
struct TypingIndicator: View {
    @State private var animationOffset: CGFloat = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // 打字动画（无头像，左对齐）
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
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.5))
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.07), lineWidth: 0.8)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))

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
