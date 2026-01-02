import SwiftUI

struct WelcomeView: View {
    @State private var showContent = false
    @State private var logoScale: CGFloat = 0.8
    @State private var navigateToCoordinates = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // 背景图片
                    Image("star_background")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .ignoresSafeArea()

                // 流星效果
                ForEach(0..<3) { i in
                    MeteorView()
                        .offset(x: CGFloat.random(in: -100...100), y: CGFloat.random(in: -200...0))
                        .opacity(showContent ? 1 : 0)
                }

                VStack(spacing: 0) {
                    Spacer()

                    // Logo 区域
                    VStack(spacing: 24) {
                        // 神秘符号
                        ZStack {
                            // 外圈光环
                            Circle()
                                .stroke(
                                    AngularGradient(
                                        colors: [Color(hex: "#E94560").opacity(0.6), Color(hex: "#16213E"), Color(hex: "#E94560").opacity(0.6)],
                                        center: .center
                                    ),
                                    lineWidth: 2
                                )
                                .frame(width: 120, height: 120)
                                .rotationEffect(.degrees(showContent ? 360 : 0))
                                .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: showContent)

                            // 内圈
                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                .frame(width: 90, height: 90)

                            // 中心图标
                            Image(systemName: "sparkles")
                                .font(.system(size: 36))
                                .foregroundColor(Color(hex: "#E94560"))
                        }
                        .scaleEffect(logoScale)

                        // 标题
                        VStack(spacing: 12) {
                            Text("缘 起")
                                .font(.system(size: 42, weight: .bold))
                                .tracking(16)
                                .foregroundColor(.white)

                            Text("DESTINY AWAITS")
                                .font(.system(size: 12, weight: .light))
                                .tracking(6)
                                .foregroundColor(.white.opacity(0.4))
                        }

                        // 副标题
                        Text("探索命定之缘，遇见灵魂伴侣")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 8)
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)

                    Spacer()

                    // 底部按钮区域
                    VStack(spacing: 20) {
                        // 开始按钮
                        Button(action: {
                            navigateToCoordinates = true
                        }) {
                            HStack(spacing: 12) {
                                Text("开启命运之旅")
                                    .font(.system(size: 17, weight: .semibold))
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
                            .shadow(color: Color(hex: "#E94560").opacity(0.4), radius: 20, x: 0, y: 10)
                        }
                        .padding(.horizontal, 40)

                        // 底部说明
                        Text("基于时空坐标与灵魂共振理论")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .opacity(showContent ? 1 : 0)
                    .padding(.bottom, 40)
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: 20)
                    }
                }
                }
                .clipped()
            }
            .navigationDestination(isPresented: $navigateToCoordinates) {
                CoordinatesInputView()
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                showContent = true
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                logoScale = 1.0
            }
        }
    }
}

// 流星效果
struct MeteorView: View {
    @State private var offset: CGFloat = -200
    @State private var opacity: Double = 0

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.white, Color.white.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 100, height: 1)
            .rotationEffect(.degrees(45))
            .offset(x: offset, y: -offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: 2).repeatForever(autoreverses: false).delay(Double.random(in: 0...3))) {
                    offset = 400
                    opacity = 0.6
                }
            }
    }
}

#Preview {
    WelcomeView()
}
