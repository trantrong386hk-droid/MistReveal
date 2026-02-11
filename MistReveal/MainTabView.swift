import SwiftUI
import CoreLocation
import Combine
import PhotosUI
import Supabase

// MARK: - TabBar 隐藏环境变量
private struct HideTabBarKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var hideTabBar: Binding<Bool> {
        get { self[HideTabBarKey.self] }
        set { self[HideTabBarKey.self] = newValue }
    }
}

// MARK: - CLLocationCoordinate2D Equatable
extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var hideTabBar = false  // 控制 TabBar 显示/隐藏

    var body: some View {
        ZStack(alignment: .bottom) {
            // 主内容区域 - 根据选中的 tab 显示对应视图
            Group {
                switch selectedTab {
                case 0:
                    HomeView()
                case 1:
                    SoulmateAIChatView()  // 灵犀：直接显示 AI 聊天
                case 2:
                    ConnectionView(onBackTap: nil)  // 星图：缘分探索
                case 3:
                    ProfileView()
                default:
                    HomeView()
                }
            }

            // 自定义底部导航栏
            if !hideTabBar {
                customTabBar
            }
        }
        .ignoresSafeArea(.keyboard)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToHomeTab"))) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToSoulmateTab"))) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = 1
            }
        }
    }

    // MARK: - 自定义底部导航栏
    var customTabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // 命理
                tabBarItem(icon: "sparkles", title: "命理", index: 0)

                // 灵犀
                tabBarItem(icon: "heart.fill", title: "灵犀", index: 1)

                // 星图（缘分探索）
                tabBarItem(icon: "map", title: "星图", index: 2)

                // 我的
                tabBarItem(icon: "person", title: "我的", index: 3)
            }
            .padding(.horizontal, 16)
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

    // MARK: - 灵犀 Tab（中间放大突出）
    var soulmateTabItem: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = 1
            }
        }) {
            VStack(spacing: 4) {
                ZStack {
                    // 发光圆形背景
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#E94560"), Color(hex: "#FF6B6B")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: Color(hex: "#E94560").opacity(selectedTab == 1 ? 0.6 : 0.3), radius: selectedTab == 1 ? 12 : 8)

                    // 图标
                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                .offset(y: -12) // 向上突出

                Text("灵犀")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(selectedTab == 1 ? .white : .white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)
        }
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
            GeometryReader { geometry in
                ZStack {
                    // 背景
                    Color(hex: "#0A0A12").ignoresSafeArea()

                    // 星云装饰 - 使用相对尺寸
                    Circle()
                        .fill(Color(hex: "#16213E").opacity(0.6))
                        .frame(width: min(geometry.size.width * 1.2, 400), height: min(geometry.size.width * 1.2, 400))
                        .blur(radius: 150)
                        .offset(x: -geometry.size.width * 0.25, y: -geometry.size.height * 0.35)

                    Circle()
                        .fill(Color(hex: "#E94560").opacity(0.15))
                        .frame(width: min(geometry.size.width, 350), height: min(geometry.size.width, 350))
                        .blur(radius: 120)
                        .offset(x: geometry.size.width * 0.35, y: geometry.size.height * 0.45)

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
                    .padding(.bottom, 100)
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: 60)
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

// MARK: - 搜索范围枚举
enum SearchScope: String, CaseIterable {
    case local = "同城"
    case provincial = "跨省"
    case global = "全球"

    var maxRadius: Double {
        switch self {
        case .local: return 100
        case .provincial: return 2000
        case .global: return 20000
        }
    }

    var minRadius: Double {
        switch self {
        case .local: return 10
        case .provincial: return 100
        case .global: return 1000
        }
    }

    var step: Double {
        switch self {
        case .local: return 10
        case .provincial: return 100
        case .global: return 1000
        }
    }

    var icon: String {
        switch self {
        case .local: return "📍"
        case .provincial: return "🚄"
        case .global: return "🌍"
        }
    }
}

// MARK: - 缘分视图（地图匹配）
struct ConnectionView: View {
    var onBackTap: (() -> Void)? = nil  // 从翻转容器传入的返回回调

    @StateObject private var locationManager = LocationManager.shared
    @StateObject private var matchingService = MatchingService.shared
    @ObservedObject private var archiveManager = SoulArchiveManager.shared
    @StateObject private var chatService = ChatService.shared

    @Environment(\.hideTabBar) private var hideTabBar

    @State private var selectedUser: MatchingService.MatchedUser?
    @State private var showUserCard = false
    @State private var matchThreshold: Double = 60
    @State private var searchRadius: Double = 50
    @State private var searchScope: SearchScope = .local
    @State private var hasUpdatedLocation = false
    @State private var shouldRecenterMap = false

    // 用户定位优化 - 新增状态
    @State private var currentFocusIndex: Int = 0  // 当前聚焦的用户索引
    @State private var showMiniList: Bool = false  // 是否显示迷你列表
    @State private var focusCoordinate: CLLocationCoordinate2D?  // 跳转目标坐标

    // 聊天相关状态
    @State private var showIceBreaker = false  // 显示破冰界面
    @State private var showChat = false  // 显示聊天界面
    @State private var chatConversationId: String?  // 当前对话ID
    @State private var initialChatMessage: String?  // 破冰话题

    // 连线动画状态
    @State private var showConnectionAnimation = false

    // 连接线显示状态
    @State private var showConnectionLines = false
    @State private var shouldFitAllAnnotations = false

    // 控制面板收起状态
    @State private var isControlPanelExpanded = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0A0A12").ignoresSafeArea()

                // 检查是否完成灵魂分析
                if archiveManager.myRecord == nil {
                    // 未完成分析的提示
                    unlockedView
                } else {
                    // 已完成分析，显示地图
                    mapContentView
                }

                // 用户卡片弹窗
                if showUserCard, let user = selectedUser {
                    userCardOverlay(user: user)
                }

                // 破冰话题界面
                if showIceBreaker, let user = selectedUser, let myRecord = archiveManager.myRecord {
                    IceBreakerView(
                        user: user,
                        myRecord: myRecord,
                        onStartChat: { topic in
                            startChatWithTopic(topic, user: user)
                        },
                        onDismiss: {
                            withAnimation(.spring(response: 0.3)) {
                                showIceBreaker = false
                            }
                        }
                    )
                    .transition(.opacity)
                }

                // 命运连接动画
                if showConnectionAnimation, let user = selectedUser, let myRecord = archiveManager.myRecord {
                    DestinyConnectionView(
                        fromElement: myRecord.analysisResult.userElement,
                        toElement: user.userElement,
                        fromName: "我",
                        toName: user.nickname,
                        onComplete: {
                            withAnimation(.easeOut(duration: 0.3)) {
                                showConnectionAnimation = false
                            }
                            // 动画完成后继续原有的对话流程
                            proceedToConversation(with: user)
                        }
                    )
                    .transition(.opacity)
                    .zIndex(100)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showChat) {
                if let user = selectedUser, let conversationId = chatConversationId {
                    ChatView(
                        user: user,
                        conversationId: conversationId,
                        initialMessage: initialChatMessage
                    )
                    .onDisappear {
                        // 返回时恢复 TabBar
                        hideTabBar.wrappedValue = false
                    }
                }
            }
        }
        .onAppear {
            Task {
                await archiveManager.fetchUserRecords()
            }
            // 请求定位权限
            locationManager.requestAuthorization()
        }
        .onChange(of: locationManager.userLocation) { _, newLocation in
            guard let location = newLocation, !hasUpdatedLocation else { return }
            hasUpdatedLocation = true

            Task {
                // 更新自己的位置到数据库
                let success = await matchingService.updateUserLocation(
                    latitude: location.latitude,
                    longitude: location.longitude
                )
                if success {
                    // 搜索附近匹配的用户
                    await matchingService.findNearbyMatches(
                        center: location,
                        radiusKm: searchRadius,
                        minMatchScore: Int(matchThreshold)
                    )
                }
            }
        }
    }

    // MARK: - 地图空状态浮层
    private var mapEmptyStateOverlay: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color(hex: "#E94560").opacity(0.15), lineWidth: 1)
                    .frame(width: 120, height: 120)

                Circle()
                    .stroke(Color(hex: "#E94560").opacity(0.25), lineWidth: 1)
                    .frame(width: 100, height: 100)

                Image(systemName: "person.2.wave.2")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "#E94560").opacity(0.5))
            }

            VStack(spacing: 12) {
                Text("你的命定之人尚未出现")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                Text("在遇见 Ta 之前，先遇见自己...")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }

            if let onBackTap = onBackTap {
                Button(action: onBackTap) {
                    HStack(spacing: 8) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 14))
                        Text("回到灵犀对话")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#E94560"), Color(hex: "#1A1A2E")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                }
                .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#0A0A12").opacity(0.85))
    }

    // MARK: - 未解锁视图
    private var unlockedView: some View {
        VStack(spacing: 24) {
            // 锁定图标
            ZStack {
                Circle()
                    .stroke(Color(hex: "#E94560").opacity(0.3), lineWidth: 2)
                    .frame(width: 100, height: 100)

                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "#E94560").opacity(0.6))
            }

            VStack(spacing: 12) {
                Text("星图")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("完成灵魂推演后\n即可在星图上探索与你灵魂共振的人")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // 引导按钮
            Button(action: {
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
            }) {
                HStack(spacing: 8) {
                    Text("开始灵魂推演")
                        .font(.system(size: 15, weight: .medium))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#E94560"), Color(hex: "#1A1A2E")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - 地图内容视图
    private var mapContentView: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("星图")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    if matchingService.isLoading {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(.white)
                            Text("正在搜索...")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    } else if matchingService.nearbyMatches.isEmpty {
                        Text("附近暂无灵魂共振")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    } else {
                        // 可点击的提示文字
                        Button(action: {
                            focusNextUser()
                        }) {
                            HStack(spacing: 4) {
                                Text("附近 \(matchingService.nearbyMatches.count) 人与你灵魂共振")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color(hex: "#E94560"))
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: "#E94560").opacity(0.8))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "#E94560").opacity(0.15))
                            .cornerRadius(8)
                        }
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5)
                                .onEnded { _ in
                                    withAnimation(.spring(response: 0.3)) {
                                        showMiniList.toggle()
                                    }
                                }
                        )
                    }
                }

                Spacer()

                // 刷新按钮
                Button(action: {
                    refreshMatches()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }

                // 罗盘返回按钮（从翻转容器进入时显示）
                if let onBackTap = onBackTap {
                    RotatingCompassButton(action: onBackTap)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // 地图
            ZStack(alignment: .bottom) {
                MapViewRepresentable(
                    userLocation: $locationManager.userLocation,
                    matchedUsers: $matchingService.nearbyMatches,
                    selectedUser: $selectedUser,
                    shouldRecenter: $shouldRecenterMap,
                    focusCoordinate: $focusCoordinate,
                    showConnectionLines: $showConnectionLines,
                    shouldFitAllAnnotations: $shouldFitAllAnnotations,
                    onAnnotationSelected: { user in
                        selectedUser = user
                        withAnimation(.spring(response: 0.3)) {
                            showUserCard = true
                        }
                    }
                )
                .ignoresSafeArea(edges: .bottom)

                // 空状态浮层（无匹配用户时覆盖在地图上）
                if !matchingService.isLoading && matchingService.nearbyMatches.isEmpty {
                    mapEmptyStateOverlay
                }

                // 迷你列表弹窗
                if showMiniList && !matchingService.nearbyMatches.isEmpty {
                    miniListOverlay
                }

                // 右下角按钮组
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            // 显示全部/连接线按钮
                            Button(action: {
                                showConnectionLines.toggle()
                                if showConnectionLines {
                                    shouldFitAllAnnotations = true
                                }
                            }) {
                                Image(systemName: showConnectionLines ? "link.circle.fill" : "link.circle")
                                    .font(.system(size: 18))
                                    .foregroundColor(showConnectionLines ? Color(hex: "#E94560") : .white.opacity(0.8))
                                    .frame(width: 44, height: 44)
                                    .background(Color(hex: "#1A1A2E").opacity(0.95))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(showConnectionLines ? Color(hex: "#E94560").opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }

                            // 定位到我按钮
                            Button(action: {
                                shouldRecenterMap = true
                            }) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(hex: "#E94560"))
                                    .frame(width: 44, height: 44)
                                    .background(Color(hex: "#1A1A2E").opacity(0.95))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                        }
                        .padding(.trailing, 16)
                        .padding(.bottom, isControlPanelExpanded ? 320 : 150) // 根据面板状态调整
                    }
                }

                // 底部控制面板
                controlPanel
            }
        }
    }

    // MARK: - 控制面板（底部抽屉式）
    private var controlPanel: some View {
        VStack(spacing: 0) {
            if isControlPanelExpanded {
                // 展开状态：完整控制面板
                VStack(spacing: 0) {
                    // 顶部拉手
                    controlPanelHandle

                    // 筛选控件
                    VStack(spacing: 16) {
                        // 搜索范围选择器（三档模式）
                        VStack(alignment: .leading, spacing: 8) {
                            Text("搜索范围")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.8))

                            HStack(spacing: 8) {
                                ForEach(SearchScope.allCases, id: \.self) { scope in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            searchScope = scope
                                            searchRadius = scope.minRadius
                                        }
                                        refreshMatches()
                                    }) {
                                        HStack(spacing: 4) {
                                            Text(scope.icon)
                                                .font(.system(size: 12))
                                            Text(scope.rawValue)
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .foregroundColor(searchScope == scope ? .white : .white.opacity(0.5))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(searchScope == scope ? Color(hex: "#E94560") : Color.white.opacity(0.1))
                                        )
                                    }
                                }
                            }
                        }

                        // 匹配度阈值
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("最低匹配度")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                                Text("\(Int(matchThreshold))%")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color(hex: "#E94560"))
                            }

                            Slider(value: $matchThreshold, in: 40...90, step: 5)
                                .tint(Color(hex: "#E94560"))
                                .onChange(of: matchThreshold) { _, _ in
                                    refreshMatches()
                                }
                        }

                        // 搜索半径
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("搜索半径")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                                Text(formatDistance(searchRadius))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color(hex: "#E94560"))
                            }

                            Slider(value: $searchRadius, in: searchScope.minRadius...searchScope.maxRadius, step: searchScope.step)
                                .tint(Color(hex: "#E94560"))
                                .onChange(of: searchRadius) { _, _ in
                                    refreshMatches()
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "#1A1A2E").opacity(0.95))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // 收起状态：只显示小拉手
                controlPanelHandle
            }
        }
        .padding(.bottom, 100) // 为 TabBar 留空间
    }

    // MARK: - 控制面板拉手
    private var controlPanelHandle: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isControlPanelExpanded.toggle()
            }
        }) {
            HStack(spacing: 8) {
                // 左侧横线
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 2)
                    .cornerRadius(1)

                // 中间箭头
                Image(systemName: isControlPanelExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                // 右侧横线
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 40, height: 2)
                    .cornerRadius(1)
            }
            .frame(width: 120, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(hex: "#1A1A2E").opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .padding(.vertical, isControlPanelExpanded ? 12 : 0)
    }

    // MARK: - 用户卡片弹窗
    private func userCardOverlay(user: MatchingService.MatchedUser) -> some View {
        ZStack {
            // 背景遮罩
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        showUserCard = false
                    }
                }

            // 卡片
            VStack(spacing: 20) {
                // 关闭按钮
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            showUserCard = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }

                // 头像和匹配度
                ZStack {
                    Circle()
                        .fill(matchScoreColor(user.matchScore).opacity(0.2))
                        .frame(width: 90, height: 90)

                    Circle()
                        .stroke(matchScoreColor(user.matchScore), lineWidth: 3)
                        .frame(width: 90, height: 90)

                    if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 84, height: 84)
                                    .clipShape(Circle())
                            case .failure(_), .empty:
                                Image(systemName: "person.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(matchScoreColor(user.matchScore))
                            @unknown default:
                                Image(systemName: "person.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(matchScoreColor(user.matchScore))
                            }
                        }
                    } else {
                        Image(systemName: "person.fill")
                            .font(.system(size: 36))
                            .foregroundColor(matchScoreColor(user.matchScore))
                    }
                }

                // 用户信息
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Text(user.nickname)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        // 测试用户标签
                        if user.isTestUser {
                            Text("测试")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }

                    HStack(spacing: 16) {
                        // 匹配度
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundColor(matchScoreColor(user.matchScore))
                            Text("匹配度 \(user.matchScore)%")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.8))
                        }

                        // 距离
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                            Text(formatUserDistance(user.distance))
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }

                // 五行标签
                HStack(spacing: 8) {
                    elementTag(user.userElement)
                }

                // 性格特质
                if !user.personalityTraits.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(user.personalityTraits.prefix(4), id: \.self) { trait in
                            Text(trait)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }

                // 开始对话按钮
                Button(action: {
                    startConversation(with: user)
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "bubble.left.fill")
                            .font(.system(size: 14))
                        Text("开始对话")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#E94560"), Color(hex: "#1A1A2E")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(hex: "#1A1A2E"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 24)
        }
    }

    // MARK: - 迷你列表弹窗
    private var miniListOverlay: some View {
        VStack(spacing: 0) {
            // 列表头部
            HStack {
                Text("灵魂共振列表")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        showMiniList = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()
                .background(Color.white.opacity(0.1))

            // 用户列表
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(matchingService.nearbyMatches.enumerated()), id: \.element.id) { index, user in
                        Button(action: {
                            focusOnUser(user, at: index)
                            withAnimation(.spring(response: 0.3)) {
                                showMiniList = false
                            }
                        }) {
                            HStack(spacing: 12) {
                                // 用户头像
                                ZStack {
                                    Circle()
                                        .fill(matchScoreColor(user.matchScore).opacity(0.2))
                                        .frame(width: 32, height: 32)

                                    if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 28, height: 28)
                                                    .clipShape(Circle())
                                            default:
                                                Image(systemName: "person.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(matchScoreColor(user.matchScore))
                                            }
                                        }
                                    } else {
                                        Image(systemName: "person.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(matchScoreColor(user.matchScore))
                                    }
                                }

                                // 用户信息
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(user.nickname)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.white)
                                        if user.isTestUser {
                                            Text("测试")
                                                .font(.system(size: 9))
                                                .foregroundColor(.orange)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.orange.opacity(0.2))
                                                .cornerRadius(3)
                                        }
                                    }
                                    Text("\(user.userElement)命")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.5))
                                }

                                Spacer()

                                // 匹配度
                                Text("\(user.matchScore)%")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(matchScoreColor(user.matchScore))

                                // 距离
                                Text(formatUserDistance(user.distance))
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                                    .frame(width: 50, alignment: .trailing)

                                // 箭头
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                currentFocusIndex == index ?
                                Color(hex: "#E94560").opacity(0.1) : Color.clear
                            )
                        }

                        if index < matchingService.nearbyMatches.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.05))
                                .padding(.leading, 32)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#1A1A2E").opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(maxHeight: .infinity, alignment: .top)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - 辅助方法

    /// 跳转到指定用户位置
    private func focusOnUser(_ user: MatchingService.MatchedUser, at index: Int) {
        currentFocusIndex = index
        focusCoordinate = user.coordinate
        selectedUser = user
        withAnimation(.spring(response: 0.3)) {
            showUserCard = true
        }
    }

    /// 跳转到下一个用户（循环）
    private func focusNextUser() {
        let users = matchingService.nearbyMatches
        guard !users.isEmpty else { return }
        currentFocusIndex = (currentFocusIndex + 1) % users.count
        let user = users[currentFocusIndex]
        focusOnUser(user, at: currentFocusIndex)
    }

    private func refreshMatches() {
        guard let location = locationManager.userLocation else { return }
        // 重置聚焦索引
        currentFocusIndex = 0
        Task {
            await matchingService.findNearbyMatches(
                center: location,
                radiusKm: searchRadius,
                minMatchScore: Int(matchThreshold)
            )
        }
    }

    // MARK: - 聊天相关方法

    /// 开始与用户对话（先播放连线动画）
    private func startConversation(with user: MatchingService.MatchedUser) {
        print("🔵 [ConnectionView] 开始对话，用户ID: \(user.id), 是否测试用户: \(user.isTestUser)")

        // 关闭用户卡片，播放连线动画
        withAnimation(.spring(response: 0.3)) {
            showUserCard = false
            showConnectionAnimation = true
        }
    }

    /// 连线动画完成后，继续对话流程
    private func proceedToConversation(with user: MatchingService.MatchedUser) {
        Task {
            // 获取或创建对话
            print("🔵 [ConnectionView] 正在获取/创建对话...")
            if let conversation = await chatService.getOrCreateConversation(with: user.id) {
                print("✅ [ConnectionView] 对话创建成功: \(conversation.id)")

                // 检查是否已有消息（非首次对话）
                await chatService.fetchMessages(conversationId: conversation.id)

                if chatService.messages.isEmpty {
                    // 首次对话 - 显示破冰界面
                    print("🔵 [ConnectionView] 首次对话，显示破冰界面")
                    withAnimation(.spring(response: 0.3)) {
                        showIceBreaker = true
                    }
                } else {
                    // 已有对话 - 直接进入聊天
                    print("🔵 [ConnectionView] 已有对话，直接进入聊天")
                    chatConversationId = conversation.id
                    initialChatMessage = nil
                    // 延迟导航，等待动画完成
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        hideTabBar.wrappedValue = true
                        showChat = true
                    }
                }
            } else {
                print("❌ [ConnectionView] 创建对话失败")
            }
        }
    }

    /// 使用破冰话题开始聊天
    private func startChatWithTopic(_ topic: String, user: MatchingService.MatchedUser) {
        Task {
            if let conversation = await chatService.getOrCreateConversation(with: user.id) {
                // 保存破冰话题
                await chatService.saveIceBreakers(conversationId: conversation.id, topics: [topic])

                chatConversationId = conversation.id
                initialChatMessage = topic

                withAnimation(.spring(response: 0.3)) {
                    showIceBreaker = false
                }

                // 延迟导航
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    hideTabBar.wrappedValue = true
                    showChat = true
                }
            }
        }
    }

    /// 格式化距离显示
    private func formatDistance(_ km: Double) -> String {
        if km < 1 {
            return String(format: "%.0f 米", km * 1000)
        } else if km < 100 {
            return String(format: "%.1f 公里", km)
        } else if km < 1000 {
            return String(format: "%.0f 公里", km)
        } else {
            return String(format: "%.1f 千公里", km / 1000)
        }
    }

    /// 格式化用户距离显示
    private func formatUserDistance(_ km: Double) -> String {
        if km < 1 {
            return String(format: "%.0f 米", km * 1000)
        } else if km < 100 {
            return String(format: "%.1f km", km)
        } else if km < 1000 {
            return String(format: "%.0f km", km)
        } else {
            return String(format: "%.0f km", km)
        }
    }

    private func matchScoreColor(_ score: Int) -> Color {
        if score >= 95 {
            return Color(hex: "#FFD700") // 命中注定 - 金色
        } else if score >= 85 {
            return Color(hex: "#E94560") // 高度契合 - 粉红
        } else if score >= 75 {
            return Color(hex: "#FF8C00") // 相当匹配 - 橙色
        } else if score >= 65 {
            return Color(hex: "#8B5CF6") // 值得关注 - 紫色
        } else {
            return Color(hex: "#9CA3AF") // 一般匹配 - 灰色
        }
    }

    private func elementTag(_ element: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: elementIcon(element))
                .font(.system(size: 12))
            Text("\(element)命")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(elementColor(element))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(elementColor(element).opacity(0.15))
        .cornerRadius(12)
    }

    private func elementIcon(_ element: String) -> String {
        switch element {
        case "金": return "sparkle"
        case "木": return "leaf.fill"
        case "水": return "drop.fill"
        case "火": return "flame.fill"
        case "土": return "mountain.2.fill"
        default: return "sparkles"
        }
    }

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
}

// MARK: - 头像响应模型
private struct AvatarResponse: Codable {
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case avatarUrl = "avatar_url"
    }
}

// MARK: - 个人中心视图
struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showDeleteConfirmation = false
    @State private var deleteConfirmText = ""
    @State private var isDeleting = false
    @State private var navigateToArchive = false
    @State private var navigateToInvite = false

    // 头像上传相关状态
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarUrl: String?
    @State private var isUploadingAvatar = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0A0A12").ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // 头像 - 可点击上传
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            ZStack {
                                if let avatarUrl = avatarUrl, let url = URL(string: avatarUrl) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFill()
                                        case .failure(_):
                                            defaultAvatarView
                                        case .empty:
                                            ProgressView()
                                                .tint(.white)
                                        @unknown default:
                                            defaultAvatarView
                                        }
                                    }
                                } else {
                                    defaultAvatarView
                                }

                                // 上传中显示加载指示器
                                if isUploadingAvatar {
                                    Color.black.opacity(0.5)
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(1.2)
                                }
                            }
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 2)
                            )
                            .overlay(
                                // 编辑图标
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color(hex: "#E94560"))
                                    .clipShape(Circle())
                                    .offset(x: 35, y: 35)
                            )
                        }
                        .disabled(isUploadingAvatar)
                        .onChange(of: selectedPhoto) { _, newValue in
                            Task { await uploadAvatar(newValue) }
                        }

                        Text("我的")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        // 显示用户邮箱
                        if let user = authManager.currentUser {
                            Text(user.email ?? "未知邮箱")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.7))
                        }

                        // 功能列表
                        VStack(spacing: 12) {
                            // 灵魂档案 - 可导航
                            Button(action: {
                                navigateToArchive = true
                            }) {
                                profileMenuItemContent(icon: "sparkles", title: "我的灵魂档案", subtitle: "查看你的命理分析")
                            }

                            // 邀请好友 - 可导航
                            Button(action: {
                                navigateToInvite = true
                            }) {
                                profileMenuItemContent(icon: "gift.fill", title: "邀请好友", subtitle: "邀请好友获得生成次数")
                            }

                            // 缘分记录
                            profileMenuItem(icon: "heart.circle", title: "缘分记录", subtitle: "查看历史匹配")

                            // 设置
                            profileMenuItem(icon: "gearshape", title: "设置", subtitle: "账号与偏好设置")
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, 24)

                        // 退出登录按钮
                        Button(action: {
                            Task {
                                await authManager.signOut()
                            }
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 16))
                                Text("退出登录")
                                    .font(.system(size: 15))
                            }
                            .foregroundColor(Color(hex: "#E94560"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(hex: "#E94560").opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#E94560").opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 30)

                        // 删除账户按钮
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                    .font(.system(size: 16))
                                Text("删除账户")
                                    .font(.system(size: 15))
                            }
                            .foregroundColor(.red.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 120)
                    }
                    .padding(.top, 60)
                }
            }
            .alert("删除账户", isPresented: $showDeleteConfirmation) {
                TextField("请输入「删除」确认", text: $deleteConfirmText)
                Button("取消", role: .cancel) {
                    deleteConfirmText = ""
                }
                Button("确认删除", role: .destructive) {
                    if deleteConfirmText == "删除" {
                        Task {
                            await performDeleteAccount()
                        }
                    }
                }
                .disabled(deleteConfirmText != "删除")
            } message: {
                Text("此操作不可撤销！您的所有数据将被永久删除。\n\n请输入「删除」以确认。")
            }
            .overlay {
                if isDeleting {
                    ZStack {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("正在删除账户...")
                                .foregroundColor(.white)
                        }
                        .padding(30)
                        .background(Color(hex: "#1A1A2E"))
                        .cornerRadius(16)
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToArchive) {
                SoulArchiveView()
            }
            .navigationDestination(isPresented: $navigateToInvite) {
                InviteFriendsView()
            }
            .onAppear {
                Task {
                    await loadCurrentAvatar()
                }
            }
        }
    }

    // 执行删除账户
    private func performDeleteAccount() async {
        print("🗑️ 用户确认删除账户")
        isDeleting = true
        deleteConfirmText = ""

        let success = await authManager.deleteAccount()

        if success {
            print("✅ 账户删除成功，即将跳转到登录页面")
            // 删除成功后不需要关闭遮罩，因为整个页面会被替换
        } else {
            print("❌ 账户删除失败: \(authManager.errorMessage ?? "未知错误")")
            // 只有失败时才关闭遮罩，让用户可以重试
            isDeleting = false
        }
    }

    // MARK: - 头像相关

    // 默认头像视图
    private var defaultAvatarView: some View {
        Circle()
            .fill(Color.white.opacity(0.1))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white.opacity(0.6))
            )
    }

    // 上传头像
    private func uploadAvatar(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        guard let userId = authManager.currentUser?.id.uuidString else {
            print("❌ [ProfileView] 用户未登录，无法上传头像")
            return
        }

        isUploadingAvatar = true
        defer { isUploadingAvatar = false }

        do {
            // 1. 加载图片数据
            guard let data = try await item.loadTransferable(type: Data.self) else {
                print("❌ [ProfileView] 无法加载图片数据")
                return
            }

            // 2. 压缩图片
            guard let uiImage = UIImage(data: data),
                  let compressedData = uiImage.jpegData(compressionQuality: 0.7) else {
                print("❌ [ProfileView] 无法压缩图片")
                return
            }

            print("📷 [ProfileView] 开始上传头像，大小: \(compressedData.count / 1024)KB")

            // 3. 构建文件路径
            let fileName = "\(userId)/avatar_\(Int(Date().timeIntervalSince1970)).jpg"

            // 4. 上传到 Supabase Storage
            try await supabase.storage
                .from("avatars")
                .upload(
                    path: fileName,
                    file: compressedData,
                    options: FileOptions(contentType: "image/jpeg", upsert: true)
                )

            // 5. 获取公开URL
            let publicUrl = try supabase.storage
                .from("avatars")
                .getPublicURL(path: fileName)

            print("✅ [ProfileView] 头像上传成功: \(publicUrl.absoluteString)")

            // 6. 更新 user_locations 表
            try await supabase
                .from("user_locations")
                .update(["avatar_url": publicUrl.absoluteString])
                .eq("user_id", value: userId)
                .execute()

            print("✅ [ProfileView] 用户位置表更新成功")

            // 7. 更新本地状态
            await MainActor.run {
                self.avatarUrl = publicUrl.absoluteString
            }

        } catch {
            print("❌ [ProfileView] 头像上传失败: \(error)")
        }
    }

    // 加载当前头像
    private func loadCurrentAvatar() async {
        guard let userId = authManager.currentUser?.id.uuidString else { return }

        do {
            let response: [AvatarResponse] = try await supabase
                .from("user_locations")
                .select("avatar_url")
                .eq("user_id", value: userId)
                .execute()
                .value

            if let record = response.first, let url = record.avatarUrl {
                await MainActor.run {
                    self.avatarUrl = url
                }
            }
        } catch {
            print("❌ [ProfileView] 加载头像失败: \(error)")
        }
    }

    // 菜单项组件（不可点击）
    func profileMenuItem(icon: String, title: String, subtitle: String) -> some View {
        Button(action: {}) {
            profileMenuItemContent(icon: icon, title: title, subtitle: subtitle)
        }
    }

    // 菜单项内容（可复用）
    func profileMenuItemContent(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color(hex: "#E94560"))
                .frame(width: 40, height: 40)
                .background(Color(hex: "#E94560").opacity(0.1))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
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
    MainTabView()
}
