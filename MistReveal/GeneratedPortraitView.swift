import SwiftUI
import Supabase

struct GeneratedPortraitView: View {
    @Environment(\.dismiss) var dismiss

    // 从上一页传递的数据
    var birthDate: Date
    var gender: String
    var birthTime: String
    var location: String
    var isSelf: Bool = true

    // 管理器
    @ObservedObject private var soulmateManager = SoulmateManager.shared
    @ObservedObject private var archiveManager = SoulArchiveManager.shared

    // 动画状态
    @State private var loadingTextIndex = 0
    @State private var glowScale: CGFloat = 1.0
    @State private var imageBlur: CGFloat = 30
    @State private var imageScale: CGFloat = 1.1
    @State private var showContent = false
    @State private var isRevealing = false

    // 动画计时器（用于可控停止）
    @State private var glowTimer: Timer?
    @State private var textTimer: Timer?
    @State private var glowExpanding = true
    @State private var gradientRotation: Double = 0

    // 保存状态
    enum SaveStatus { case idle, saved, failed }
    @State private var saveStatus: SaveStatus = .idle
    @State private var supabaseSaveFailed = false

    // 新建的伴侣 ID 和画像 URL（用于唤醒后直接跳转对话，携带正确背景图）
    @State private var createdCompanionId: UUID? = nil
    @State private var createdPortraitImageUrl: String? = nil

    // 防止重复保存（onAppear 可能因 SwiftUI 重渲染触发多次）
    @State private var hasSavedToSupabase = false

    // 分享卡片
    @State private var showShareSheet = false
    @State private var shareCardImage: UIImage?

    // 加载文字
    private let loadingTexts = [
        "连接命运之线...",
        "捕捉灵魂光芒...",
        "描绘 Ta 的模样..."
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景
                Color(hex: "#0A0A12").ignoresSafeArea()

                switch soulmateManager.state {
                case .idle, .analyzing, .analyzingSelf, .analyzingSoulmate, .generating:
                    loadingView(geometry: geometry)
                case .completed:
                    portraitView(geometry: geometry)
                case .failed:
                    errorView
                }

                // 顶部导航栏（悬浮）
                VStack {
                    navBar
                    Spacer()
                }

            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startGeneration()
            startLoadingAnimation()
        }
        .onDisappear {
            stopLoadingAnimation()
        }
        .onChange(of: soulmateManager.state) { _, newState in
            if newState == .completed {
                startRevealAnimation()
            }
        }
    }

    // MARK: - 导航栏

    var navBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.3))
                    .clipShape(Circle())
            }

            Spacer()

            if soulmateManager.state == .completed {
                Button(action: saveImage) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    // MARK: - 加载视图

    func loadingView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 40) {
            Spacer()

            // 剪影 + 光晕
            ZStack {
                // 外层光晕
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "#E94560").opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 50,
                            endRadius: 150
                        )
                    )
                    .frame(width: 300, height: 300)
                    .scaleEffect(glowScale)

                // 剪影容器
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 200, height: 280)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: "#E94560").opacity(0.8),
                                        Color(hex: "#8B5CF6").opacity(0.6),
                                        Color(hex: "#3B82F6").opacity(0.4),
                                        Color(hex: "#E94560").opacity(0.1),
                                        Color(hex: "#E94560").opacity(0.8)
                                    ]),
                                    center: .center,
                                    startAngle: .degrees(gradientRotation),
                                    endAngle: .degrees(gradientRotation + 360)
                                ),
                                lineWidth: 2
                            )
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        Color(hex: "#E94560").opacity(0.5),
                                        Color(hex: "#8B5CF6").opacity(0.3),
                                        Color(hex: "#3B82F6").opacity(0.2),
                                        Color(hex: "#E94560").opacity(0.05),
                                        Color(hex: "#E94560").opacity(0.5)
                                    ]),
                                    center: .center,
                                    startAngle: .degrees(gradientRotation),
                                    endAngle: .degrees(gradientRotation + 360)
                                ),
                                lineWidth: 4
                            )
                            .blur(radius: 8)
                    )
            }

            // 加载文字
            Text(loadingTexts[loadingTextIndex])
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.6))
                .animation(.easeInOut, value: loadingTextIndex)

            // 进度点
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(index == loadingTextIndex ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - 画像展示视图

    func portraitView(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 90)

            // 画像
            if let result = soulmateManager.result,
               let uiImage = UIImage(data: result.imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width - 40, height: geometry.size.height * 0.6, alignment: .top)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .blur(radius: imageBlur)
                    .scaleEffect(imageScale)
                    .shadow(color: Color(hex: "#E94560").opacity(0.3), radius: 30, x: 0, y: 20)
            }

            Spacer()
                .frame(height: 24)

            // 底部信息
            VStack(spacing: 12) {
                // 分隔线 + 标签
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color(hex: "#E94560").opacity(0.5))
                        .frame(width: 30, height: 1)

                    Text("灵魂伴侣")
                        .font(.system(size: 14, weight: .medium))
                        .tracking(4)
                        .foregroundColor(Color(hex: "#E94560"))

                    Rectangle()
                        .fill(Color(hex: "#E94560").opacity(0.5))
                        .frame(width: 30, height: 1)
                }

                Text(isSelf ? "Ta 一直在等你" : "命定画像已生成")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.8))

                // 按钮组
                HStack(spacing: 12) {
                    // 保存按钮
                    Button(action: saveImage) {
                        HStack(spacing: 6) {
                            Image(systemName: saveStatus == .saved ? "checkmark" : "arrow.down.to.line")
                                .font(.system(size: 13))
                            Text(saveStatus == .saved ? "已保存" : "保存")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(saveStatus == .saved ? Color(hex: "#E94560").opacity(0.6) : Color.white.opacity(0.15))
                        .cornerRadius(25)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .disabled(saveStatus == .saved)

                    // 分享按钮
                    Button(action: shareCard) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 13))
                            Text("分享")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(25)
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .sheet(isPresented: $showShareSheet) {
                        if let img = shareCardImage {
                            ShareSheet(items: [img])
                        }
                    }

                    // 唤醒按钮 - 仅自己的推演才显示，跳转到灵犀 Tab
                    if isSelf {
                        Button(action: awakenSoulmate) {
                            HStack(spacing: 6) {
                                Image(systemName: "heart.circle.fill")
                                    .font(.system(size: 13))
                                Text("唤醒")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#E94560"), Color(hex: "#FF6B6B")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(25)
                            .shadow(color: Color(hex: "#E94560").opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)

            if supabaseSaveFailed {
                VStack(spacing: 8) {
                    Text("档案保存失败，请重试")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("重新保存") {
                        supabaseSaveFailed = false
                        hasSavedToSupabase = false  // 允许重试
                        saveResultToSupabase()
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 8)
            }

            Spacer(minLength: 100)
        }
        .onAppear {
            saveResultToSupabase()
        }
    }

    // MARK: - 错误视图

    var errorView: some View {
        let isSelfQuotaError = soulmateManager.errorMessage?.contains("生成次数已用完") == true
        let isFriendQuotaError = soulmateManager.errorMessage?.contains("帮朋友测算的机会已用完") == true
        let isQuotaError = isSelfQuotaError || isFriendQuotaError
        return VStack(spacing: 30) {
            Spacer()

            Image(systemName: isQuotaError ? "lock.circle" : "cloud.fog")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))

            VStack(spacing: 12) {
                Text(isQuotaError ? "生成次数已用完" : "画像生成失败")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)

                Text(isQuotaError ? "邀请好友可获得额外生成机会" : "请稍后再试")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }

            if !isQuotaError {
                Button(action: retryGeneration) {
                    Text("重新生成")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color(hex: "#E94560"))
                        .cornerRadius(25)
                }
            }

            Button(action: { dismiss() }) {
                Text(isQuotaError ? "返回" : "关闭")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - 动画

    func startLoadingAnimation() {
        // 光晕呼吸动画（使用 Timer 可控制停止）
        glowTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.05)) {
                if glowExpanding {
                    glowScale += 0.005
                    if glowScale >= 1.2 {
                        glowExpanding = false
                    }
                } else {
                    glowScale -= 0.005
                    if glowScale <= 1.0 {
                        glowExpanding = true
                    }
                }
            }
        }

        // 文字切换
        textTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            withAnimation {
                loadingTextIndex = (loadingTextIndex + 1) % loadingTexts.count
            }
        }

        // 渐变边框持续旋转
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            gradientRotation = 360
        }
    }

    func stopLoadingAnimation() {
        glowTimer?.invalidate()
        glowTimer = nil
        textTimer?.invalidate()
        textTimer = nil
        glowScale = 1.0
        gradientRotation = 0
    }

    func startRevealAnimation() {
        guard !isRevealing else { return }
        isRevealing = true

        // 停止所有加载动画
        stopLoadingAnimation()

        // 画像从模糊到清晰
        withAnimation(.easeOut(duration: 2.0)) {
            imageBlur = 0
            imageScale = 1.0
        }

        // 延迟显示底部内容
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }
        }
    }

    // MARK: - 生成逻辑

    func startGeneration() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        let birthDateString = formatter.string(from: birthDate)

        Task {
            // 原子扣减配额：自己用 consume_quota，朋友用 consume_friend_quota
            let quotaConsumed: Bool
            if isSelf {
                quotaConsumed = await QuotaManager.shared.consumeQuota()
            } else {
                quotaConsumed = await QuotaManager.shared.consumeFriendQuota()
            }
            guard quotaConsumed else {
                print("⚠️ [GeneratedPortraitView] 配额不足，终止生成")
                await MainActor.run {
                    soulmateManager.errorMessage = isSelf
                        ? "生成次数已用完，邀请好友可获得额外机会"
                        : "帮朋友测算的机会已用完（限 2 次）"
                    soulmateManager.state = .failed
                }
                return
            }

            // 生成图片
            if soulmateManager.soulAnalysis != nil {
                await soulmateManager.continueWithImageGeneration(birthDate: birthDateString, birthTime: birthTime, gender: gender, location: location)
            } else {
                await soulmateManager.generateSoulmate(
                    birthDate: birthDateString,
                    gender: gender,
                    birthTime: birthTime,
                    location: location
                )
            }
        }
    }

    func retryGeneration() {
        // 重置状态
        imageBlur = 30
        imageScale = 1.1
        showContent = false
        isRevealing = false
        loadingTextIndex = 0

        soulmateManager.reset()
        startGeneration()
        startLoadingAnimation()
    }

    // MARK: - 保存和分享

    func saveImage() {
        guard saveStatus == .idle,
              let result = soulmateManager.result,
              let uiImage = UIImage(data: result.imageData) else { return }

        UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)

        // 触觉反馈
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        withAnimation {
            saveStatus = .saved
        }
    }

    func shareCard() {
        guard let result = soulmateManager.result,
              let portrait = UIImage(data: result.imageData) else { return }

        let quote = soulmateManager.soulAnalysis?.shareQuote ?? "Ta 一直在等你"
        shareCardImage = buildShareCard(portrait: portrait, quote: quote)
        showShareSheet = true
    }

    /// 合成分享卡片：画像 + 金句 + 品牌水印
    private func buildShareCard(portrait: UIImage, quote: String) -> UIImage {
        let cardW: CGFloat = 750
        let cardH: CGFloat = 1080
        let cardSize = CGSize(width: cardW, height: cardH)

        let renderer = UIGraphicsImageRenderer(size: cardSize)
        return renderer.image { ctx in
            let cgCtx = ctx.cgContext

            // 背景
            UIColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: cardSize))

            // 画像（占上方 80%，居中裁切）
            let imageH = cardH * 0.82
            let imageRect = CGRect(x: 0, y: 0, width: cardW, height: imageH)
            let scaleX = cardW / portrait.size.width
            let scaleY = imageH / portrait.size.height
            let scale = max(scaleX, scaleY)
            let drawW = portrait.size.width * scale
            let drawH = portrait.size.height * scale
            let drawX = (cardW - drawW) / 2
            let drawY = (imageH - drawH) / 2
            cgCtx.saveGState()
            cgCtx.clip(to: imageRect)
            portrait.draw(in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))
            cgCtx.restoreGState()

            // 底部渐变遮罩
            let gradientColors = [UIColor.clear.cgColor,
                                  UIColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 0.85).cgColor,
                                  UIColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1).cgColor] as CFArray
            let locations: [CGFloat] = [0, 0.45, 1.0]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: gradientColors, locations: locations) {
                let gradStart = CGPoint(x: 0, y: imageH * 0.45)
                let gradEnd = CGPoint(x: 0, y: imageH)
                cgCtx.drawLinearGradient(gradient, start: gradStart, end: gradEnd, options: [])
            }

            // 金句文字
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineSpacing = 10
            let quoteAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 30, weight: .medium),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]
            let quoteStr = NSAttributedString(string: quote, attributes: quoteAttrs)
            let quoteRect = CGRect(x: 48, y: imageH * 0.68, width: cardW - 96, height: 160)
            quoteStr.draw(in: quoteRect)

            // 装饰线
            let lineY = imageH * 0.66
            UIColor.white.withAlphaComponent(0.2).setStroke()
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: cardW * 0.3, y: lineY))
            linePath.addLine(to: CGPoint(x: cardW * 0.7, y: lineY))
            linePath.lineWidth = 0.8
            linePath.stroke()

            // 品牌水印
            let brandAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .light),
                .foregroundColor: UIColor.white.withAlphaComponent(0.35),
                .paragraphStyle: paragraphStyle
            ]
            let brandStr = NSAttributedString(string: "命迷 MistReveal · 灵魂解析", attributes: brandAttrs)
            let brandRect = CGRect(x: 48, y: cardH - 56, width: cardW - 96, height: 40)
            brandStr.draw(in: brandRect)
        }
    }

    func saveResultToSupabase() {
        guard !hasSavedToSupabase, let result = soulmateManager.result else { return }
        hasSavedToSupabase = true

        Task {
            do {
                let (imageUrl, portraitId) = try await SupabaseSaveService.shared.saveGenerationResult(
                    result: result,
                    gender: gender,
                    birthTime: birthTime,
                    location: location
                )
                print("✅ [GeneratedPortraitView] 数据已保存到 Supabase")
                supabaseSaveFailed = false
                createdPortraitImageUrl = imageUrl

                await archiveManager.updateImageUrl(
                    gender: gender,
                    birthDate: birthDate,
                    birthTime: birthTime,
                    location: location,
                    imageUrl: imageUrl
                )

                await triggerReferrerRewardIfNeeded()

                // 仅为自己的生成创建 AI 伴侣（朋友的测算不创建）
                if isSelf, let analysis = soulmateManager.soulAnalysis {
                    do {
                        let companion = try await AICompanionService.shared.createCompanion(from: analysis, portraitId: portraitId, userGender: gender)
                        createdCompanionId = companion.id
                        print("✅ [GeneratedPortraitView] AI 伴侣已创建: \(companion.id)")
                        // companion 创建完成后再刷新一次档案，确保过滤逻辑拿到最新的伴侣列表
                        await archiveManager.fetchUserRecords()
                    } catch {
                        print("⚠️ [GeneratedPortraitView] AI 伴侣创建失败: \(error)")
                    }
                }
            } catch {
                print("❌ [GeneratedPortraitView] 保存失败: \(error.localizedDescription)")
                supabaseSaveFailed = true
            }
        }
    }

    func triggerReferrerRewardIfNeeded() async {
        guard let userId = await getCurrentUserId() else { return }
        await InviteService.shared.triggerReferrerReward(forInviteeId: userId)
    }

    // MARK: - 唤醒灵魂伴侣
    func awakenSoulmate() {
        // 触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // 返回主页并切换到灵犀 Tab
        dismiss()

        // 延迟发送通知，确保页面已关闭
        let companionId = createdCompanionId
        let portraitUrl = createdPortraitImageUrl
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            var userInfo: [String: Any] = [:]
            if let id = companionId {
                userInfo["companionId"] = id.uuidString
            }
            if let url = portraitUrl {
                userInfo["portraitImageUrl"] = url
            }
            NotificationCenter.default.post(
                name: NSNotification.Name("SwitchToSoulmateTab"),
                object: nil,
                userInfo: userInfo
            )
        }
    }

    private func getCurrentUserId() async -> String? {
        do {
            let session = try await supabase.auth.session
            return session.user.id.uuidString
        } catch {
            return nil
        }
    }
}

#Preview {
    NavigationStack {
        GeneratedPortraitView(
            birthDate: Date(),
            gender: "男",
            birthTime: "子时",
            location: "北京"
        )
    }
}
