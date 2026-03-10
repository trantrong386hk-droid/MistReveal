import SwiftUI

/// 命运连接动画视图 - 点击"开始对话"时显示的底部 HUD 连线动效
struct DestinyConnectionView: View {
    let fromElement: String  // 我的五行
    let toElement: String    // TA的五行
    let fromName: String     // 我的称呼
    let toName: String       // TA的称呼
    let fromCity: String?    // 我的城市
    let toCity: String?      // TA的城市
    let onComplete: () -> Void

    @State private var lineProgress: CGFloat = 0
    @State private var showParticles = false
    @State private var centerGlow: CGFloat = 0
    @State private var hudOpacity: CGFloat = 0
    @State private var particleOffset: CGFloat = 0  // 0-1，粒子在线上的相对位置

    var body: some View {
        ZStack(alignment: .bottom) {
            // 半透明背景（地图透过）
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            // 底部 HUD 卡片
            VStack(spacing: 16) {
                // 连线 + 两侧元素圆圈
                HStack(spacing: 0) {
                    // 左侧：我
                    VStack(spacing: 6) {
                        elementCircle(element: fromElement)
                        Text(fromName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                        if let city = fromCity {
                            Text(city)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .frame(width: 76)

                    // 中间：动画连线
                    GeometryReader { lineGeo in
                        let lineY = lineGeo.size.height / 2

                        ZStack {
                            // 连线光束
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: lineY))
                                path.addLine(to: CGPoint(x: lineGeo.size.width, y: lineY))
                            }
                            .trim(from: 0, to: lineProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        elementColor(fromElement),
                                        elementColor(fromElement).opacity(0.8),
                                        elementColor(toElement).opacity(0.8),
                                        elementColor(toElement)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .shadow(color: elementColor(fromElement).opacity(0.5), radius: 6)
                            .shadow(color: elementColor(toElement).opacity(0.5), radius: 6)

                            // 流光粒子
                            if showParticles {
                                ForEach(0..<3, id: \.self) { i in
                                    let t = (particleOffset + CGFloat(i) * 0.33)
                                        .truncatingRemainder(dividingBy: 1.0)
                                    Circle()
                                        .fill(Color.white.opacity(0.85))
                                        .frame(width: 5, height: 5)
                                        .blur(radius: 1)
                                        .position(
                                            x: t * lineGeo.size.width,
                                            y: lineY
                                        )
                                        .opacity(lineProgress > 0.5 && t < lineProgress ? 1 : 0)
                                }
                            }
                        }
                    }
                    .frame(height: 80)

                    // 右侧：TA
                    VStack(spacing: 6) {
                        elementCircle(element: toElement)
                            .opacity(lineProgress > 0.3 ? 1 : 0.3)
                            .scaleEffect(lineProgress > 0.8 ? 1.0 : 0.9)
                            .animation(.easeOut(duration: 0.3), value: lineProgress > 0.8)
                        Text(toName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                        if let city = toCity {
                            Text(city)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .frame(width: 76)
                    .opacity(lineProgress > 0.3 ? 1 : 0.3)
                }
                .padding(.horizontal, 8)

                // 文字提示
                VStack(spacing: 6) {
                    Text("命运的连接 · 正在建立灵魂共振...")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))

                    // 连接成功提示
                    if lineProgress >= 1.0 {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("连接成功")
                                .foregroundColor(.green)
                        }
                        .font(.system(size: 13, weight: .medium))
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "#1A1A2E").opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 100)  // 为 TabBar 留空间
            .opacity(hudOpacity)
        }
        .onAppear {
            startAnimation()
        }
    }

    // MARK: - 元素圆圈

    @ViewBuilder
    private func elementCircle(element: String) -> some View {
        ZStack {
            // 外层光晕
            Circle()
                .fill(elementColor(element).opacity(0.2))
                .frame(width: 52 + centerGlow * 14, height: 52 + centerGlow * 14)
                .blur(radius: 8)

            // 主圆
            Circle()
                .fill(
                    RadialGradient(
                        colors: [elementColor(element), elementColor(element).opacity(0.7)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 22
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.45), lineWidth: 1.5)
                )
                .shadow(color: elementColor(element), radius: centerGlow * 10)

            // 五行符号
            Text(elementSymbol(element))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
    }

    // MARK: - 动画

    private func startAnimation() {
        // HUD 渐显
        withAnimation(.easeIn(duration: 0.25)) {
            hudOpacity = 1.0
        }

        // 光束延伸动画
        withAnimation(.easeInOut(duration: 1.0).delay(0.1)) {
            lineProgress = 1.0
        }

        // 光晕呼吸
        withAnimation(.easeInOut(duration: 0.8).delay(0.1).repeatForever(autoreverses: true)) {
            centerGlow = 1.0
        }

        // 粒子流动（particleOffset 从 0 到 1 循环）
        showParticles = true
        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
            particleOffset = 1.0
        }

        // 动画完成后回调
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            onComplete()
        }
    }

    // MARK: - 辅助

    /// 根据五行获取颜色
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

    /// 根据五行获取符号
    private func elementSymbol(_ element: String) -> String {
        switch element {
        case "金": return "金"
        case "木": return "木"
        case "水": return "水"
        case "火": return "火"
        case "土": return "土"
        default: return "☯"
        }
    }
}

#Preview {
    ZStack {
        Color(hex: "#0A0A12").ignoresSafeArea()
        DestinyConnectionView(
            fromElement: "火",
            toElement: "水",
            fromName: "我",
            toName: "神秘人",
            fromCity: "北京",
            toCity: "上海",
            onComplete: {}
        )
    }
}
