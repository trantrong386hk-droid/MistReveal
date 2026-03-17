import SwiftUI

struct DestinyDeductionView: View {
    @Environment(\.dismiss) var dismiss

    // 从上一页传递的数据
    var birthDate: Date
    var gender: String
    var birthTime: String
    var location: String
    var isSelf: Bool = true

    // SoulmateManager
    @ObservedObject private var soulmateManager = SoulmateManager.shared

    // 动画状态
    @State private var showContent = false
    @State private var currentCard = 0
    @State private var showAppearance = false
    @State private var showSoulmateTraits = false
    @State private var showCompatibility = false

    // 导航
    @State private var navigateToPortrait = false

    // 深度报告付费墙
    @State private var showDeepReportPaywall = false
    @ObservedObject private var purchaseManager = PurchaseManager.shared

    // 打字机动画
    @State private var displayedFirstImpression: String = ""
    @State private var typewriterTimer: Timer?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 纯色背景
                Color(hex: "#0A0A12").ignoresSafeArea()

                VStack(spacing: 0) {
                    // 自定义导航栏
                    customNavBar

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 32) {
                            // 标题区域
                            VStack(spacing: 12) {
                                Text("命 定 缘 分")
                                    .font(.system(size: 28, weight: .bold))
                                    .tracking(6)
                                    .foregroundColor(.white)

                                Text("为什么是 Ta？")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding(.top, 20)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)

                            // 推导卡片
                            deductionCardsSection
                                .opacity(showContent ? 1 : 0)

                            // Ta 的模样（详细画像描述）
                            soulmateAppearanceSection
                                .opacity(showAppearance ? 1 : 0)
                                .offset(y: showAppearance ? 0 : 30)

                            // 深度报告付费墙（包含：灵魂特质 + 契合度 + 感情伤口 + 隐藏面 + 相遇时机 + 一句话）
                            ZStack {
                                deepReportContent
                                    .opacity(showSoulmateTraits ? 1 : 0)
                                    .offset(y: showSoulmateTraits ? 0 : 30)
                                    .blur(radius: purchaseManager.hasDeepReport ? 0 : 8)
                                    .allowsHitTesting(purchaseManager.hasDeepReport)

                                if !purchaseManager.hasDeepReport {
                                    deepReportLockOverlay
                                }
                            }

                            // 底部按钮
                            Button(action: {
                                navigateToGeneration()
                            }) {
                                HStack(spacing: 12) {
                                    Text("揭示命定之人")
                                        .font(.system(size: 16, weight: .bold))
                                        .tracking(4)

                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "#E94560"), Color(hex: "#1A1A2E")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(30)
                                .shadow(color: Color(hex: "#E94560").opacity(0.3), radius: 20, x: 0, y: 10)
                            }
                            .padding(.horizontal, 40)
                            .padding(.top, 20)
                            .opacity(showSoulmateTraits ? 1 : 0)

                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            .clipped()
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showDeepReportPaywall) {
            DeepReportPaywallView(purchaseManager: purchaseManager)
        }
        .fullScreenCover(isPresented: $navigateToPortrait) {
            GeneratedPortraitView(
                birthDate: birthDate,
                gender: gender,
                birthTime: birthTime,
                location: location,
                isSelf: isSelf
            )
        }
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            typewriterTimer?.invalidate()
        }
    }

    // MARK: - 深度报告锁定遮罩

    var deepReportLockOverlay: some View {
        Button(action: { showDeepReportPaywall = true }) {
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.7))

                Text("解锁完整命盘")
                    .font(.system(size: 13, weight: .medium))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.8))

                Text("¥8 · 一次解锁永久查看")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.35))
            .cornerRadius(20)
        }
    }

    // MARK: - 配额检查

    func navigateToGeneration() {
        navigateToPortrait = true
    }

    // MARK: - 子组件

    var customNavBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white)
            }

            Spacer()

            Text("命定缘分")
                .font(.system(size: 12, weight: .light))
                .tracking(4)
                .foregroundColor(.white.opacity(0.9))

            Spacer()

            // 进度指示 - 第三步 (3/4)
            HStack(spacing: 4) {
                Circle().fill(Color.white).frame(width: 4, height: 4)
                Circle().fill(Color.white).frame(width: 4, height: 4)
                Circle().fill(Color.white).frame(width: 4, height: 4)
                Circle().fill(Color.white.opacity(0.3)).frame(width: 4, height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .frame(height: 50)
    }

    // 推导卡片区域
    var deductionCardsSection: some View {
        VStack(spacing: 16) {
            if let analysis = soulmateManager.soulAnalysis {
                ForEach(Array(analysis.matchingDeductions.enumerated()), id: \.offset) { index, deduction in
                    deductionCard(deduction: deduction, index: index)
                        .opacity(currentCard > index ? 1 : 0)
                        .offset(y: currentCard > index ? 0 : 20)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.3), value: currentCard)
                }
            }
        }
    }

    // 单个推导卡片
    func deductionCard(deduction: MatchingDeduction, index: Int) -> some View {
        VStack(spacing: 16) {
            // 因为你...
            HStack {
                Text("因为你")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))

                Text("【\(deduction.userTrait)】")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }

            // 箭头
            Image(systemName: "arrow.down")
                .font(.system(size: 16))
                .foregroundColor(Color(hex: "#E94560").opacity(0.6))

            // 需要...的人
            HStack {
                Text("需要")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))

                Text("【\(deduction.soulmateTrait)】")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "#E94560"))

                Text("的人")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }

            // 解释（如果有）
            if let explanation = deduction.explanation, !explanation.isEmpty {
                Text(explanation)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.top, 4)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#E94560").opacity(0.3), lineWidth: 1)
        )
    }

    // Ta 的模样（详细画像描述）
    var soulmateAppearanceSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#E94560"))
                Text("Ta 的模样")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .tracking(2)
            }

            if let analysis = soulmateManager.soulAnalysis {
                VStack(alignment: .leading, spacing: 20) {
                    // 初见印象（打字机效果）
                    VStack(alignment: .leading, spacing: 8) {
                        Text("初见印象")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#E94560").opacity(0.8))

                        Text(displayedFirstImpression)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.9))
                            .lineSpacing(6)
                    }

                    // 分隔线
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 1)

                    // 肤色脸型
                    appearanceDetailRow(
                        icon: "face.smiling",
                        title: "肤色脸型",
                        content: "\(analysis.soulmateAppearance.skinTone)，\(analysis.soulmateAppearance.faceShape)"
                    )

                    // 五官特征
                    appearanceDetailRow(
                        icon: "eyes",
                        title: "五官特征",
                        content: "\(analysis.soulmateAppearance.eyes)，\(analysis.soulmateAppearance.otherFeatures)"
                    )

                    // 发型穿着
                    appearanceDetailRow(
                        icon: "tshirt",
                        title: "发型穿着",
                        content: "\(analysis.soulmateAppearance.hair)；\(analysis.soulmateAppearance.clothing)"
                    )
                }
                .padding(20)
                .background(Color.white.opacity(0.08))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "#E94560").opacity(0.3), lineWidth: 1)
                )
            }
        }
    }

    // 画像详情行
    func appearanceDetailRow(icon: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#E94560").opacity(0.7))

                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }

            Text(content)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(5)
        }
    }

    // 深度报告完整内容（付费解锁后展示）
    var deepReportContent: some View {
        VStack(spacing: 24) {
            soulmateTraitsSection
            compatibilitySection
            if let analysis = soulmateManager.soulAnalysis {
                if let wound = analysis.loveWound, !wound.isEmpty {
                    deepReportTextBlock(
                        icon: "heart.slash",
                        title: "你的感情伤口",
                        content: wound,
                        accentColor: Color(hex: "#E94560")
                    )
                }
                if let shadow = analysis.shadowTrait, !shadow.isEmpty {
                    deepReportTextBlock(
                        icon: "moon.fill",
                        title: "你不说的那一面",
                        content: shadow,
                        accentColor: Color(hex: "#8B7FD4")
                    )
                }
                if let timing = analysis.meetingTiming, !timing.isEmpty {
                    deepReportTextBlock(
                        icon: "clock",
                        title: "Ta 会在什么时候出现",
                        content: timing,
                        accentColor: Color(hex: "#E94560")
                    )
                }
                if let msg = analysis.messageToSoulmate, !msg.isEmpty {
                    messageToSoulmateCard(msg)
                }
            }
        }
    }

    // 深度报告文字块（通用）
    func deepReportTextBlock(icon: String, title: String, content: String, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(accentColor)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .tracking(1)
            }
            Text(content)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.82))
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(accentColor.opacity(0.2), lineWidth: 1)
        )
    }

    // 给 Ta 的一句话（特殊样式）
    func messageToSoulmateCard(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("如果你已经在某个地方")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.35))
                .tracking(2)

            Text("\u{201C}" + message + "\u{201D}")
                .font(.system(size: 17, weight: .light))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .italic()
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: "#E94560").opacity(0.12), Color(hex: "#8B7FD4").opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "#E94560").opacity(0.25), lineWidth: 1)
        )
    }

    // Ta 的灵魂特质
    var soulmateTraitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#E94560"))
                Text("Ta 的灵魂特质")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .tracking(2)
            }

            if let analysis = soulmateManager.soulAnalysis {
                FlowLayout(spacing: 10) {
                    ForEach(analysis.soulmateTraits, id: \.self) { trait in
                        soulmateTraitTag(trait)
                    }
                }
            }
        }
    }

    // 伴侣特质标签
    func soulmateTraitTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Color(hex: "#E94560"))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: "#E94560").opacity(0.15))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(hex: "#E94560").opacity(0.4), lineWidth: 1)
            )
    }

    // 契合度 + 缘分类型 + 深度解析
    var compatibilitySection: some View {
        VStack(spacing: 0) {
            if let analysis = soulmateManager.soulAnalysis {
                HStack(spacing: 0) {
                    // 契合度
                    VStack(spacing: 8) {
                        Text("契合度")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))

                        Text("\(analysis.compatibilityScore)%")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Color(hex: "#E94560"))
                    }
                    .frame(maxWidth: .infinity)

                    // 分隔线
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 60)

                    // 缘分类型
                    VStack(spacing: 8) {
                        Text("缘分类型")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))

                        Text(analysis.destinyType)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 24)

                // 契合度深度解析
                if let detail = analysis.compatibilityAnalysis, !detail.isEmpty {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                        .padding(.horizontal, 20)

                    Text(detail)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.72))
                        .lineSpacing(7)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .background(Color.white.opacity(0.08))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - 动画

    func startAnimations() {
        // 标题出现
        withAnimation(.easeOut(duration: 0.8)) {
            showContent = true
        }

        // 推导卡片依次出现
        let deductionCount = soulmateManager.soulAnalysis?.matchingDeductions.count ?? 3
        for i in 1...deductionCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    currentCard = i
                }
            }
        }

        let baseDelay = Double(deductionCount) * 0.5

        // Ta的模样出现
        DispatchQueue.main.asyncAfter(deadline: .now() + baseDelay + 0.5) {
            withAnimation(.easeOut(duration: 0.6)) {
                showAppearance = true
            }
            // 启动打字机动画
            startTypewriterAnimation()
        }

        // 伴侣特质出现
        DispatchQueue.main.asyncAfter(deadline: .now() + baseDelay + 1.5) {
            withAnimation(.easeOut(duration: 0.6)) {
                showSoulmateTraits = true
            }
        }

        // 契合度出现
        DispatchQueue.main.asyncAfter(deadline: .now() + baseDelay + 2.0) {
            withAnimation(.easeOut(duration: 0.6)) {
                showCompatibility = true
            }
        }
    }

    func startTypewriterAnimation() {
        guard let analysis = soulmateManager.soulAnalysis else { return }

        let fullText = analysis.soulmateAnalysis
        displayedFirstImpression = ""
        var charIndex = 0

        typewriterTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { timer in
            if charIndex < fullText.count {
                let index = fullText.index(fullText.startIndex, offsetBy: charIndex)
                displayedFirstImpression += String(fullText[index])
                charIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
}

// MARK: - 深度报告付费墙

struct DeepReportPaywallView: View {
    @ObservedObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(hex: "#0A0A12").ignoresSafeArea()

            VStack(spacing: 0) {
                // 顶部装饰
                ZStack {
                    Circle()
                        .fill(Color(hex: "#E94560").opacity(0.12))
                        .frame(width: 200, height: 200)
                        .blur(radius: 60)

                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 44))
                            .foregroundColor(Color(hex: "#E94560"))

                        Text("完整命盘报告")
                            .font(.system(size: 24, weight: .bold))
                            .tracking(2)
                            .foregroundColor(.white)

                        Text("解锁 Ta 的灵魂特质与契合度\n一次购买，永久查看")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.55))
                            .multilineTextAlignment(.center)
                            .lineSpacing(5)
                    }
                }
                .padding(.top, 48)

                Spacer()

                // 内容预览
                VStack(alignment: .leading, spacing: 8) {
                    paywallFeatureRow(icon: "sparkles", text: "Ta 的完整灵魂特质标签")
                    paywallFeatureRow(icon: "heart.fill", text: "双方契合度评分与缘分类型")
                    paywallFeatureRow(icon: "lock.open.fill", text: "永久解锁，无需重复购买")
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

                VStack(spacing: 16) {
                    // 购买按钮
                    Button(action: {
                        Task {
                            if let product = purchaseManager.deepReportProduct {
                                try? await purchaseManager.purchase(product)
                                if purchaseManager.hasDeepReport {
                                    dismiss()
                                }
                            }
                        }
                    }) {
                        Group {
                            if purchaseManager.isPurchasing {
                                ProgressView().tint(.white)
                            } else {
                                let priceText = purchaseManager.deepReportProduct?.displayPrice ?? "¥8"
                                Text("解锁完整命盘  \(priceText)")
                                    .font(.system(size: 16, weight: .bold))
                                    .tracking(2)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#E94560"), Color(hex: "#FF6B6B")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(28)
                        .shadow(color: Color(hex: "#E94560").opacity(0.35), radius: 16, x: 0, y: 8)
                    }
                    .disabled(purchaseManager.isPurchasing)

                    Button(action: {
                        Task {
                            await purchaseManager.restorePurchases()
                            if purchaseManager.hasDeepReport { dismiss() }
                        }
                    }) {
                        Text("恢复购买")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)

                if let error = purchaseManager.errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#E94560"))
                        .padding(.bottom, 12)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func paywallFeatureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#E94560"))
                .frame(width: 20)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.75))
        }
    }
}

#Preview {
    NavigationStack {
        DestinyDeductionView(
            birthDate: Date(),
            gender: "男",
            birthTime: "子时",
            location: "北京"
        )
    }
}
