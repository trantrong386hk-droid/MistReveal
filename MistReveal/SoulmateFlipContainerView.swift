import SwiftUI

// MARK: - 翻转容器（灵犀 Tab 的根视图）
struct SoulmateFlipContainerView: View {
    @State private var showingMap = false

    var body: some View {
        ZStack {
            // 正面：AI 聊天
            SoulmateAIChatView(onCompassTap: { flip() })
                .opacity(showingMap ? 0 : 1)
                .allowsHitTesting(!showingMap)
                .rotation3DEffect(
                    .degrees(showingMap ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.8
                )

            // 背面：地图匹配（复用已有的 ConnectionView）
            ConnectionView(onBackTap: { flip() })
                .opacity(showingMap ? 1 : 0)
                .allowsHitTesting(showingMap)
                .rotation3DEffect(
                    .degrees(showingMap ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.8
                )
        }
    }

    private func flip() {
        withAnimation(.easeInOut(duration: 0.6)) {
            showingMap.toggle()
        }
    }
}

// MARK: - 旋转罗盘按钮
struct RotatingCompassButton: View {
    let action: () -> Void
    @State private var rotation: Double = 0

    var body: some View {
        Button(action: action) {
            ZStack {
                // 外圈：雷达扫描光环
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(hex: "#E94560").opacity(0.8),
                                Color(hex: "#E94560").opacity(0.1),
                                Color(hex: "#E94560").opacity(0.8)
                            ],
                            center: .center
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(rotation))

                // 罗盘图标
                Image(systemName: "location.north.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#E94560"), Color(hex: "#FF6B6B")],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .rotationEffect(.degrees(rotation))
            }
            .frame(width: 36, height: 36)
            .background(Color.white.opacity(0.1))
            .clipShape(Circle())
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

#Preview {
    SoulmateFlipContainerView()
}
