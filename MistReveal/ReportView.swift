import SwiftUI

struct ReportView: View {
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
    @State private var currentSection = 0
    @State private var navigateToDestinyDeduction = false

    // 打字机动画
    @State private var displayedDescription: String = ""
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
                                Text("灵 魂 解 析")
                                    .font(.system(size: 28, weight: .bold))
                                    .tracking(6)
                                    .foregroundColor(.white)

                                Text("基于你的时空坐标，解读你的内在特质")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.top, 20)
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 20)

                            // 核心命盘图
                            destinyCircle
                                .opacity(showContent ? 1 : 0)
                                .scaleEffect(showContent ? 1 : 0.8)

                            // 你的灵魂印记（核心性格描述）
                            soulImpressionSection
                                .opacity(currentSection >= 1 ? 1 : 0)
                                .offset(y: currentSection >= 1 ? 0 : 30)

                            // 性格特质标签
                            personalityTraitsSection
                                .opacity(currentSection >= 2 ? 1 : 0)
                                .offset(y: currentSection >= 2 ? 0 : 30)

                            // 感情中的你
                            relationshipBehaviorsSection
                                .opacity(currentSection >= 3 ? 1 : 0)
                                .offset(y: currentSection >= 3 ? 0 : 30)

                            // 你的情感需求
                            emotionalNeedsSection
                                .opacity(currentSection >= 4 ? 1 : 0)
                                .offset(y: currentSection >= 4 ? 0 : 30)

                            // 底部按钮
                            Button(action: {
                                navigateToDestinyDeduction = true
                            }) {
                                HStack(spacing: 12) {
                                    Text("查看命定之缘")
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
                            .opacity(currentSection >= 4 ? 1 : 0)

                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
            .clipped()
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToDestinyDeduction) {
            DestinyDeductionView(
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

    // MARK: - 子组件

    var customNavBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white)
            }

            Spacer()

            Text("灵魂解析")
                .font(.system(size: 12, weight: .light))
                .tracking(4)
                .foregroundColor(.white.opacity(0.9))

            Spacer()

            // 进度指示 - 第二步 (2/4)
            HStack(spacing: 4) {
                Circle().fill(Color.white).frame(width: 4, height: 4)
                Circle().fill(Color.white).frame(width: 4, height: 4)
                Circle().fill(Color.white.opacity(0.3)).frame(width: 4, height: 4)
                Circle().fill(Color.white.opacity(0.3)).frame(width: 4, height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .frame(height: 50)
    }

    // 命盘圆环
    var destinyCircle: some View {
        let userElement = soulmateManager.soulAnalysis?.userElement ?? ""
        let soulmateElement = soulmateManager.soulAnalysis?.soulmateElement ?? ""
        let xiYongShen = soulmateManager.soulAnalysis?.baziInfo?.xiYongShen ?? ""

        return ZStack {
            // 外圈
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                .frame(width: 160, height: 160)

            // 内圈动态
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [Color(hex: "#E94560"), Color(hex: "#16213E"), Color(hex: "#E94560")],
                        center: .center
                    ),
                    lineWidth: 2
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(showContent ? 360 : 0))
                .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: showContent)

            // 中心内容
            VStack(spacing: 4) {
                Text(gender.isEmpty ? "你" : gender)
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

                Text(formattedBirthDate)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

                Text(birthTime)
                    .font(.system(size: 9))
                    .foregroundColor(Color(hex: "#E94560"))
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            }

            // 五行元素标记（带状态样式）
            ForEach(0..<5) { i in
                let angle = Double(i) * 72 - 90
                let element = ["金", "木", "水", "火", "土"][i]
                let isUserElement = element == userElement
                let isSoulmateElement = element == soulmateElement
                let isXiYongShen = element == xiYongShen

                elementNode(
                    element: element,
                    angle: angle,
                    isUserElement: isUserElement,
                    isSoulmateElement: isSoulmateElement,
                    isXiYongShen: isXiYongShen
                )
            }
        }
        .frame(height: 240)
    }

    // 五行节点视图
    func elementNode(element: String, angle: Double, isUserElement: Bool, isSoulmateElement: Bool, isXiYongShen: Bool) -> some View {
        let xOffset = cos(angle * .pi / 180) * 105
        let yOffset = sin(angle * .pi / 180) * 105

        return ZStack {
            // 用户本命 - 粉红光晕
            if isUserElement {
                Circle()
                    .fill(Color(hex: "#E94560").opacity(0.3))
                    .frame(width: 52, height: 52)
                    .blur(radius: 10)

                Circle()
                    .fill(Color(hex: "#E94560").opacity(0.2))
                    .frame(width: 44, height: 44)
            }

            // 伴侣五行 - 蓝紫色背景
            if isSoulmateElement && !isUserElement {
                Circle()
                    .fill(Color(hex: "#8B5CF6").opacity(0.3))
                    .frame(width: 48, height: 48)
                    .blur(radius: 8)

                Circle()
                    .fill(Color(hex: "#8B5CF6").opacity(0.2))
                    .frame(width: 40, height: 40)
            }

            // 喜用神 - 金色边框
            if isXiYongShen && !isUserElement {
                Circle()
                    .stroke(Color(hex: "#FFD700"), lineWidth: 2)
                    .frame(width: 40, height: 40)
            }

            // 元素文字
            Text(element)
                .font(.system(size: isUserElement || isSoulmateElement ? 20 : 18, weight: isUserElement ? .bold : .medium))
                .foregroundColor(elementTextColor(isUserElement: isUserElement, isSoulmateElement: isSoulmateElement, isXiYongShen: isXiYongShen))
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

            // 标签
            if isUserElement {
                Text("我")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#E94560"))
                    .cornerRadius(4)
                    .offset(y: 22)
            } else if isSoulmateElement {
                Text("TA")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color(hex: "#8B5CF6"))
                    .cornerRadius(4)
                    .offset(y: 22)
            } else if isXiYongShen {
                Text("喜用")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(Color(hex: "#FFD700"))
                    .offset(y: 20)
            }
        }
        .offset(x: xOffset, y: yOffset)
    }

    // 元素文字颜色
    func elementTextColor(isUserElement: Bool, isSoulmateElement: Bool, isXiYongShen: Bool) -> Color {
        if isUserElement {
            return Color(hex: "#E94560")
        } else if isSoulmateElement {
            return Color(hex: "#8B5CF6")
        } else if isXiYongShen {
            return Color(hex: "#FFD700")
        } else {
            return .white.opacity(0.5)
        }
    }

    // 你的灵魂印记
    var soulImpressionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#E94560"))
                Text("你的灵魂印记")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .tracking(2)
            }

            // 打字机效果显示性格描述
            Text(displayedDescription)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(8)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.08))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#E94560").opacity(0.3), lineWidth: 1)
                )
        }
    }

    // 性格特质标签
    var personalityTraitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("性格特质")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .tracking(2)

            if let analysis = soulmateManager.soulAnalysis {
                FlowLayout(spacing: 10) {
                    ForEach(analysis.personalityTraits, id: \.self) { trait in
                        traitTag(trait)
                    }
                }
            }
        }
    }

    // 感情中的你
    var relationshipBehaviorsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("感情中的你")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .tracking(2)

            VStack(alignment: .leading, spacing: 12) {
                if let analysis = soulmateManager.soulAnalysis {
                    ForEach(analysis.relationshipBehaviors, id: \.self) { behavior in
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(Color(hex: "#E94560"))
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)

                            Text(behavior)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                                .lineSpacing(4)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }

    // 你的情感需求
    var emotionalNeedsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("你的情感需求")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .tracking(2)

            VStack(alignment: .leading, spacing: 12) {
                if let analysis = soulmateManager.soulAnalysis {
                    ForEach(analysis.emotionalNeeds, id: \.self) { need in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "#E94560").opacity(0.8))
                                .padding(.top, 4)

                            Text(need)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.8))
                                .lineSpacing(4)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }

    // 特质标签
    func traitTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: "#E94560").opacity(0.3))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(hex: "#E94560").opacity(0.5), lineWidth: 1)
            )
    }

    var formattedBirthDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: birthDate)
    }

    // MARK: - 动画

    func startAnimations() {
        withAnimation(.easeOut(duration: 0.8)) {
            showContent = true
        }

        // 延迟显示各部分
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.6)) {
                currentSection = 1
            }
            // 启动打字机动画
            startTypewriterAnimation()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.6)) {
                currentSection = 2
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.6)) {
                currentSection = 3
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.6)) {
                currentSection = 4
            }
        }
    }

    func startTypewriterAnimation() {
        guard let analysis = soulmateManager.soulAnalysis else { return }

        let fullText = analysis.personalityDescription
        displayedDescription = ""
        var charIndex = 0

        typewriterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            if charIndex < fullText.count {
                let index = fullText.index(fullText.startIndex, offsetBy: charIndex)
                displayedDescription += String(fullText[index])
                charIndex += 1
            } else {
                timer.invalidate()
            }
        }
    }
}

// MARK: - Flow Layout for Tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width, x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: width, height: y + lineHeight)
        }
    }
}

#Preview {
    NavigationStack {
        ReportView(
            birthDate: Date(),
            gender: "男",
            birthTime: "子时",
            location: "北京"
        )
    }
}
