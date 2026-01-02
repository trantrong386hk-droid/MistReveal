import SwiftUI

struct ReportView: View {
    @Environment(\.dismiss) var dismiss

    // 从上一页传递的数据
    var birthDate: Date
    var gender: String
    var birthTime: String
    var location: String

    // 动画状态
    @State private var showContent = false
    @State private var currentSection = 0
    @State private var navigateToMistReveal = false

    // 模拟的报告数据
    let soulTraits = ["温柔如水", "坚韧不拔", "灵性通透", "情感细腻"]
    let destinyElements = ["木", "水"]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景图片（轻微虚化）
                Image("star_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .blur(radius: 4)
                    .ignoresSafeArea()

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

                            Text("基于你的时空坐标，命运已为你勾勒轮廓")
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

                        // 灵魂特质卡片
                        soulTraitsSection
                            .opacity(currentSection >= 1 ? 1 : 0)
                            .offset(y: currentSection >= 1 ? 0 : 30)

                        // 命定缘分预览
                        destinyPreviewSection
                            .opacity(currentSection >= 2 ? 1 : 0)
                            .offset(y: currentSection >= 2 ? 0 : 30)

                        // 底部按钮
                        Button(action: {
                            navigateToMistReveal = true
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
                        .opacity(currentSection >= 2 ? 1 : 0)

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 24)
                }
            }
            }
            .clipped()
        }
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $navigateToMistReveal) {
            MistRevealView(
                birthDate: birthDate,
                gender: gender,
                birthTime: birthTime,
                location: location
            )
        }
        .onAppear {
            startAnimations()
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

            // 进度指示 - 第二步
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
        ZStack {
            // 外圈
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                .frame(width: 200, height: 200)

            // 内圈动态
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [Color(hex: "#E94560"), Color(hex: "#16213E"), Color(hex: "#E94560")],
                        center: .center
                    ),
                    lineWidth: 3
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(showContent ? 360 : 0))
                .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: showContent)

            // 中心内容
            VStack(spacing: 8) {
                Text(gender.isEmpty ? "乾" : gender)
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

                Text(formattedBirthDate)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

                Text(birthTime)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "#E94560"))
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
            }

            // 五行元素标记
            ForEach(0..<5) { i in
                let angle = Double(i) * 72 - 90
                let element = ["金", "木", "水", "火", "土"][i]
                let isActive = destinyElements.contains(element)

                Text(element)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isActive ? Color(hex: "#E94560") : .white.opacity(0.8))
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    .offset(
                        x: cos(angle * .pi / 180) * 90,
                        y: sin(angle * .pi / 180) * 90
                    )
            }
        }
        .frame(height: 220)
    }

    // 灵魂特质
    var soulTraitsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("灵魂特质")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .tracking(2)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(soulTraits, id: \.self) { trait in
                    HStack {
                        Circle()
                            .fill(Color(hex: "#E94560"))
                            .frame(width: 6, height: 6)

                        Text(trait)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
            }
        }
    }

    // 命定缘分预览
    var destinyPreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("命定缘分")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .tracking(2)

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("契合度")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))

                        Text("96%")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color(hex: "#E94560"))
                    }

                    Spacer()

                    // 模糊的剪影预览
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 80, height: 80)

                        Image(systemName: "person.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white.opacity(0.3))
                            .blur(radius: 4)

                        Text("?")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(20)

                Divider()
                    .background(Color.white.opacity(0.1))

                HStack(spacing: 20) {
                    destinyInfoItem(title: "相遇时机", value: "近期")
                    destinyInfoItem(title: "缘分类型", value: "灵魂伴侣")
                    destinyInfoItem(title: "羁绊强度", value: "极深")
                }
                .padding(20)
            }
            .background(Color.white.opacity(0.1))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }

    func destinyInfoItem(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.85))

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeOut(duration: 0.6)) {
                currentSection = 1
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.6)) {
                currentSection = 2
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReportView(
            birthDate: Date(),
            gender: "乾",
            birthTime: "子时",
            location: "北京"
        )
    }
}
