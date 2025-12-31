import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // 主内容区域 - 根据选中的 tab 显示对应视图
            Group {
                switch selectedTab {
                case 0:
                    HomeView()
                case 1:
                    ConnectionView()
                case 2:
                    ProfileView()
                default:
                    HomeView()
                }
            }

            // 自定义底部导航栏
            customTabBar
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - 自定义底部导航栏
    var customTabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // 首页
                tabBarItem(icon: "house.fill", title: "首页", index: 0)

                // 缘分
                tabBarItem(icon: "heart.circle", title: "缘分", index: 1)

                // 我的
                tabBarItem(icon: "person", title: "我的", index: 2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(
            Rectangle()
                .fill(Color(hex: "#0A0A12"))
                .ignoresSafeArea(edges: .bottom)
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.1), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 0.5),
                    alignment: .top
                )
        )
    }

    func tabBarItem(icon: String, title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        }) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(selectedTab == index ? .white : .white.opacity(0.4))

                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(selectedTab == index ? .white : .white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 首页视图
struct HomeView: View {
    @State private var navigateToCoordinates = false
    @State private var showContent = false
    @State private var logoScale: CGFloat = 0.8

    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color(hex: "#0A0A12").ignoresSafeArea()

                // 星云装饰
                Circle()
                    .fill(Color(hex: "#16213E").opacity(0.6))
                    .frame(width: 500, height: 500)
                    .blur(radius: 150)
                    .offset(x: -100, y: -300)

                Circle()
                    .fill(Color(hex: "#E94560").opacity(0.15))
                    .frame(width: 400, height: 400)
                    .blur(radius: 120)
                    .offset(x: 150, y: 400)

                VStack(spacing: 0) {
                    Spacer()

                    // Logo 区域
                    VStack(spacing: 24) {
                        // 神秘符号
                        ZStack {
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

                            Circle()
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                .frame(width: 90, height: 90)

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

                        Text("探索命定之缘，遇见灵魂伴侣")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 8)
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)

                    Spacer()

                    // 开始按钮
                    VStack(spacing: 20) {
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

                        Text("基于时空坐标与灵魂共振理论")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .opacity(showContent ? 1 : 0)
                    .padding(.bottom, 140)
                }
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

// MARK: - 缘分视图（占位）
struct ConnectionView: View {
    var body: some View {
        ZStack {
            Color(hex: "#0A0A12").ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "heart.circle")
                    .font(.system(size: 60))
                    .foregroundColor(Color(hex: "#E94560").opacity(0.6))

                Text("缘分匹配")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("完成灵魂推演后\n解锁更多缘分功能")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - 个人中心视图（占位）
struct ProfileView: View {
    var body: some View {
        ZStack {
            Color(hex: "#0A0A12").ignoresSafeArea()

            VStack(spacing: 20) {
                // 头像
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.6))
                    )

                Text("我的")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("登录后查看你的灵魂档案")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))

                // 登录按钮
                Button(action: {}) {
                    Text("登录 / 注册")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color(hex: "#E94560").opacity(0.8))
                        .cornerRadius(25)
                }
                .padding(.top, 20)
            }
        }
    }
}

#Preview {
    MainTabView()
}
