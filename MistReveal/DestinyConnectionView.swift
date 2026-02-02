import SwiftUI

/// 命运连接动画视图 - 点击"开始对话"时显示的光束连线动效
struct DestinyConnectionView: View {
    let fromElement: String  // 我的五行
    let toElement: String    // TA的五行
    let fromName: String     // 我的称呼
    let toName: String       // TA的称呼
    let onComplete: () -> Void

    @State private var lineProgress: CGFloat = 0
    @State private var showParticles = false
    @State private var centerGlow: CGFloat = 0
    @State private var textOpacity: CGFloat = 0
    @State private var particleOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 半透明背景
                Color.black.opacity(0.85)
                    .ignoresSafeArea()

                // 背景星光粒子
                ForEach(0..<20, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(Double.random(in: 0.1...0.4)))
                        .frame(width: CGFloat.random(in: 2...4), height: CGFloat.random(in: 2...4))
                        .position(
                            x: CGFloat.random(in: 0...geo.size.width),
                            y: CGFloat.random(in: 0...geo.size.height)
                        )
                        .blur(radius: 1)
                }

                // 连线光束
                Path { path in
                    let start = CGPoint(x: geo.size.width * 0.2, y: geo.size.height * 0.45)
                    let end = CGPoint(x: geo.size.width * 0.8, y: geo.size.height * 0.45)
                    path.move(to: start)
                    path.addLine(to: end)
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
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .shadow(color: elementColor(fromElement).opacity(0.6), radius: 8)
                .shadow(color: elementColor(toElement).opacity(0.6), radius: 8)

                // 流光粒子效果
                if showParticles {
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [elementColor(fromElement), elementColor(toElement)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 8, height: 8)
                            .blur(radius: 2)
                            .offset(x: particleOffset - geo.size.width * 0.3 + CGFloat(i) * 30)
                            .position(x: geo.size.width * 0.5, y: geo.size.height * 0.45)
                            .opacity(lineProgress > 0.5 ? 1 : 0)
                    }
                }

                // 左侧：我
                VStack(spacing: 12) {
                    ZStack {
                        // 外层光晕
                        Circle()
                            .fill(elementColor(fromElement).opacity(0.2))
                            .frame(width: 80 + centerGlow * 20, height: 80 + centerGlow * 20)
                            .blur(radius: 10)

                        // 脉冲环
                        Circle()
                            .stroke(elementColor(fromElement).opacity(0.5 - centerGlow * 0.3), lineWidth: 2)
                            .frame(width: 70 + centerGlow * 15, height: 70 + centerGlow * 15)

                        // 主圆
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [elementColor(fromElement), elementColor(fromElement).opacity(0.7)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 30
                                )
                            )
                            .frame(width: 60, height: 60)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                            )
                            .shadow(color: elementColor(fromElement), radius: centerGlow * 20)

                        // 五行符号
                        Text(elementSymbol(fromElement))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text("我")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                    Text("\(fromElement)命")
                        .font(.system(size: 12))
                        .foregroundColor(elementColor(fromElement))
                }
                .position(x: geo.size.width * 0.2, y: geo.size.height * 0.45)

                // 右侧：TA
                VStack(spacing: 12) {
                    ZStack {
                        // 外层光晕
                        Circle()
                            .fill(elementColor(toElement).opacity(0.2))
                            .frame(width: 80 + centerGlow * 20, height: 80 + centerGlow * 20)
                            .blur(radius: 10)

                        // 脉冲环
                        Circle()
                            .stroke(elementColor(toElement).opacity(0.5 - centerGlow * 0.3), lineWidth: 2)
                            .frame(width: 70 + centerGlow * 15, height: 70 + centerGlow * 15)

                        // 主圆
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [elementColor(toElement), elementColor(toElement).opacity(0.7)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 30
                                )
                            )
                            .frame(width: 60, height: 60)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                            )
                            .shadow(color: elementColor(toElement), radius: centerGlow * 20)

                        // 五行符号
                        Text(elementSymbol(toElement))
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text(toName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)

                    Text("\(toElement)命")
                        .font(.system(size: 12))
                        .foregroundColor(elementColor(toElement))
                }
                .position(x: geo.size.width * 0.8, y: geo.size.height * 0.45)
                .opacity(lineProgress > 0.3 ? 1 : 0.3)
                .scaleEffect(lineProgress > 0.8 ? 1.0 : 0.9)
                .animation(.easeOut(duration: 0.3), value: lineProgress > 0.8)

                // 文字提示
                VStack(spacing: 12) {
                    Text("命运的连接")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    Text("正在建立灵魂共振...")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))

                    // 连接成功提示
                    if lineProgress >= 1.0 {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("连接成功")
                                .foregroundColor(.green)
                        }
                        .font(.system(size: 14, weight: .medium))
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .position(x: geo.size.width * 0.5, y: geo.size.height * 0.65)
                .opacity(textOpacity)
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // 光束延伸动画
        withAnimation(.easeInOut(duration: 1.0)) {
            lineProgress = 1.0
        }

        // 文字渐显
        withAnimation(.easeIn(duration: 0.5).delay(0.3)) {
            textOpacity = 1.0
        }

        // 光晕呼吸
        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
            centerGlow = 1.0
        }

        // 粒子流动
        showParticles = true
        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            particleOffset = UIScreen.main.bounds.width * 0.6
        }

        // 动画完成后回调
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            onComplete()
        }
    }

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
    DestinyConnectionView(
        fromElement: "火",
        toElement: "水",
        fromName: "我",
        toName: "神秘人",
        onComplete: {}
    )
}
