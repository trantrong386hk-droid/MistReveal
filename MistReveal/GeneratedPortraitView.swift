import SwiftUI

struct GeneratedPortraitView: View {
    @Environment(\.dismiss) var dismiss

    // 从上一页传递的数据
    var birthDate: Date
    var gender: String
    var birthTime: String
    var location: String

    // 动画状态
    @State private var isGenerating = true
    @State private var generationProgress: CGFloat = 0
    @State private var showPortrait = false
    @State private var showDetails = false
    @State private var particleOpacity: Double = 1
    @State private var glowAmount: CGFloat = 0

    var body: some View {
        ZStack {
            // 背景
            Color(hex: "#0A0A12").ignoresSafeArea()

            // 动态星云背景
            Circle()
                .fill(Color(hex: "#16213E").opacity(0.4))
                .frame(width: 500, height: 500)
                .blur(radius: 150)
                .offset(x: -100, y: -200)

            Circle()
                .fill(Color(hex: "#E94560").opacity(0.15))
                .frame(width: 400, height: 400)
                .blur(radius: 100)
                .offset(x: 150, y: 300)

            VStack(spacing: 0) {
                // 自定义导航栏
                customNavBar

                if isGenerating {
                    // 生成中状态
                    generatingView
                } else {
                    // 生成完成 - 显示画像
                    portraitView
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startGeneration()
        }
    }

    // MARK: - 导航栏

    var customNavBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white)
            }

            Spacer()

            Text(isGenerating ? "凝聚中" : "命定之人")
                .font(.system(size: 12, weight: .light))
                .tracking(4)
                .foregroundColor(.white.opacity(0.6))

            Spacer()

            // 进度指示 - 第四步（全部点亮）
            HStack(spacing: 4) {
                Circle().fill(Color.white).frame(width: 4, height: 4)
                Circle().fill(Color.white).frame(width: 4, height: 4)
                Circle().fill(Color.white).frame(width: 4, height: 4)
                Circle().fill(Color.white).frame(width: 4, height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .frame(height: 50)
    }

    // MARK: - 生成中视图

    var generatingView: some View {
        VStack(spacing: 40) {
            Spacer()

            // 标题
            VStack(spacing: 12) {
                Text("凝聚灵力")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(4)
                    .foregroundColor(.white)

                Text("命运之线正在交织...")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }

            // 生成动画
            ZStack {
                // 外层光环
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color(hex: "#E94560").opacity(0.3 - Double(i) * 0.1), lineWidth: 1)
                        .frame(width: 200 + CGFloat(i) * 40, height: 200 + CGFloat(i) * 40)
                        .scaleEffect(1 + generationProgress * 0.1)
                        .opacity(particleOpacity)
                }

                // 中心容器
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 220, height: 300)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "#E94560").opacity(0.5), Color.clear],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )

                // 粒子效果
                ForEach(0..<12) { i in
                    let angle = Double(i) * 30
                    let radius: CGFloat = 120 + CGFloat.random(in: -20...20)

                    Circle()
                        .fill(Color(hex: "#E94560"))
                        .frame(width: 4, height: 4)
                        .offset(
                            x: cos(angle * .pi / 180 + generationProgress * 2) * radius,
                            y: sin(angle * .pi / 180 + generationProgress * 2) * radius
                        )
                        .opacity(particleOpacity * 0.6)
                }

                // 中心图标
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "#E94560").opacity(0.6))
                    .rotationEffect(.degrees(generationProgress * 360))
            }
            .frame(height: 350)

            // 进度条
            VStack(spacing: 12) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#E94560"), Color(hex: "#E94560").opacity(0.5)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * generationProgress, height: 4)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 60)

                Text("\(Int(generationProgress * 100))%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - 画像展示视图

    var portraitView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // 标题
                VStack(spacing: 8) {
                    Text("命 定 之 人")
                        .font(.system(size: 22, weight: .bold))
                        .tracking(4)
                        .foregroundColor(.white)
                        .opacity(showPortrait ? 1 : 0)

                    Text("Ta 一直在等你")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .opacity(showPortrait ? 1 : 0)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

                // 画像主体
                ZStack {
                    // 光晕效果
                    Circle()
                        .fill(Color(hex: "#E94560").opacity(0.2))
                        .frame(width: 260, height: 260)
                        .blur(radius: 50)
                        .scaleEffect(1 + glowAmount * 0.1)

                    // 画像容器
                    RoundedRectangle(cornerRadius: 32)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.1), Color.white.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 200, height: 260)
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                        )

                    // 模拟生成的画像
                    VStack(spacing: 16) {
                        Image(systemName: gender == "女" ? "figure.stand.dress" : "figure.stand")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.8))

                        VStack(spacing: 4) {
                            Text("神秘的 Ta")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)

                            Text("等待相遇...")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                .scaleEffect(showPortrait ? 1 : 0.8)
                .opacity(showPortrait ? 1 : 0)

                // 详细信息卡片
                if showDetails {
                    VStack(alignment: .leading, spacing: 16) {
                        // 特征标签卡片
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TA 的特征")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    ForEach(["温柔", "聪慧", "艺术气质"], id: \.self) { tag in
                                        Text(tag)
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.8))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.white.opacity(0.08))
                                            .cornerRadius(14)
                                    }
                                }
                                HStack(spacing: 8) {
                                    ForEach(["善解人意", "浪漫"], id: \.self) { tag in
                                        Text(tag)
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.8))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.white.opacity(0.08))
                                            .cornerRadius(14)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)

                        // 相遇提示卡片
                        HStack(spacing: 12) {
                            Image(systemName: "heart.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Color(hex: "#E94560"))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("相遇预言")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.4))

                                Text("你们将在充满艺术气息的地方相遇")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.8))
                            }

                            Spacer()
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                }

                // 底部按钮
                VStack(spacing: 16) {
                    Button(action: {}) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.down")
                            Text("保存画像")
                        }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#E94560"), Color(hex: "#1A1A2E")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(28)
                    }

                    Button(action: {}) {
                        Text("重新推演")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 16)
                .opacity(showDetails ? 1 : 0)

                // 底部留白
                Color.clear.frame(height: 120)
            }
        }
    }

    // MARK: - 动画逻辑

    func startGeneration() {
        // 进度动画
        withAnimation(.easeInOut(duration: 3.0)) {
            generationProgress = 1.0
        }

        // 粒子闪烁
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            particleOpacity = 0.3
        }

        // 3秒后显示结果
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            withAnimation(.easeOut(duration: 0.5)) {
                isGenerating = false
            }

            // 画像出现动画
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                    showPortrait = true
                }

                // 光晕动画
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowAmount = 1
                }
            }

            // 详情出现
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeOut(duration: 0.6)) {
                    showDetails = true
                }
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
        GeneratedPortraitView(
            birthDate: Date(),
            gender: "乾",
            birthTime: "子时",
            location: "北京"
        )
    }
}
