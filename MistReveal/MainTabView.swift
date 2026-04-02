import SwiftUI
import CoreLocation
import Combine
import PhotosUI
import Supabase

// MARK: - 分享图片 Identifiable 包装（用于 .sheet(item:) 消除 race condition）
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

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

/// 唤醒后直接跳转聊天的目标（用于 fullScreenCover）
private struct ChatDestination: Identifiable {
    let id = UUID()
    let companionId: UUID
    let portraitUrl: String?
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var hideTabBar = false  // 控制 TabBar 显示/隐藏
    @State private var pendingChatDestination: ChatDestination? = nil  // 唤醒后直接弹出聊天

    var body: some View {
        ZStack(alignment: .bottom) {
            // 主内容区域 - 根据选中的 tab 显示对应视图
            Group {
                switch selectedTab {
                case 0:
                    HomeView()
                case 1:
                    NavigationStack {
                        SoulmateGalleryView()
                    }
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("HideTabBar"))) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                hideTabBar = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowTabBar"))) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                hideTabBar = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToHomeTab"))) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToSoulmateTab"))) { notification in
            let portraitUrl = notification.userInfo?["portraitImageUrl"] as? String
            if let idString = notification.userInfo?["companionId"] as? String,
               let uuid = UUID(uuidString: idString) {
                // 直接弹出聊天，不经过画廊
                pendingChatDestination = ChatDestination(companionId: uuid, portraitUrl: portraitUrl)
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = 1
            }
        }
        .fullScreenCover(item: $pendingChatDestination) { dest in
            SoulmateAIChatView(
                companionId: dest.companionId,
                portraitImageUrl: dest.portraitUrl
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToGalleryTab"))) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToStarMapTab"))) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = 2
            }
        }
    }

    // MARK: - 自定义底部导航栏
    var customTabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // 探索
                tabBarItem(icon: "sparkles", title: "探索", index: 0)

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

    func tabBarItem(icon: String, title: LocalizedStringKey, index: Int) -> some View {
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
    @State private var existingCompanions: [AICompanion] = []
    @State private var isCheckingCompanions = true
    @State private var showQuotaAlert = false
    @ObservedObject private var quotaManager = QuotaManager.shared

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
                        if isCheckingCompanions {
                            ProgressView()
                                .tint(.white)
                                .frame(height: 60)
                        } else if existingCompanions.isEmpty {
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
                        } else {
                            Button(action: {
                                NotificationCenter.default.post(name: NSNotification.Name("SwitchToGalleryTab"), object: nil)
                            }) {
                                HStack(spacing: 12) {
                                    Text("前往画廊")
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

                            Button(action: {
                                if QuotaManager.shared.canGenerate() {
                                    navigateToCoordinates = true
                                } else {
                                    showQuotaAlert = true
                                }
                            }) {
                                Text("探索新命定 →")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.45))
                                    .underline()
                            }
                            .padding(.top, 8)
                            .alert("生成次数已用完", isPresented: $showQuotaAlert) {
                                Button("好的") {}
                            } message: {
                                Text("每人有一次免费机会，邀请好友可获得额外生成次数")
                            }
                        }

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
            Task {
                existingCompanions = await AICompanionService.shared.fetchAllCompanions()
                isCheckingCompanions = false
            }
            Task { await QuotaManager.shared.fetchQuota() }
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

    // 高亮连接目标（我 → TA 的大圆弧线）
    @State private var highlightTarget: CLLocationCoordinate2D?

    // 连接线显示状态
    @State private var showConnectionLines = false
    @State private var shouldFitAllAnnotations = false

    // 控制面板收起状态
    @State private var isControlPanelExpanded = false

    // 注册城市坐标（上传后存储，供 threshold 重搜用）
    @State private var registeredCoord: CLLocationCoordinate2D?

    // 命盘切换栏（多命盘时显示）
    // 无额外状态：直接通过 archiveManager.myRecords.count > 1 控制显示

    @State private var starMapShareItem: IdentifiableImage?

    // 星影对话
    @State private var showShadowChat = false
    @State private var shadowCompanionId: UUID?
    @State private var shadowPortraitUrl: String?

    // 首次引导（T7）
    @State private var showStarMapGuide = !UserDefaults.standard.bool(forKey: "hasSeenStarMapGuide")
    @State private var guideStep = 0

    // 开发者工具
    #if DEBUG
    @State private var showDevMenu = false
    #endif

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
                if showIceBreaker, let user = selectedUser, let myRecord = archiveManager.activeRecord ?? archiveManager.myRecord {
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

                // 首次进入星图引导浮层（T7）
                if showStarMapGuide {
                    starMapGuideOverlay
                }

                // 命运连接动画（底部 HUD，地图透过）
                if showConnectionAnimation, let user = selectedUser, let myRecord = archiveManager.activeRecord ?? archiveManager.myRecord {
                    DestinyConnectionView(
                        fromElement: myRecord.analysisResult.userElement,
                        toElement: user.userElement,
                        fromName: "我",
                        toName: user.nickname,
                        fromCity: matchingService.myCity,
                        toCity: user.city,
                        onComplete: {
                            // 清除高亮连接线
                            highlightTarget = nil
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
                        hideTabBar.wrappedValue = false
                    }
                }
            }
            .navigationDestination(isPresented: $showShadowChat) {
                if let companionId = shadowCompanionId {
                    SoulmateAIChatView(
                        companionId: companionId,
                        portraitImageUrl: shadowPortraitUrl
                    )
                    .onDisappear {
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
        .onChange(of: locationManager.userLocation) { _, _ in
            // GPS 仅用于地图视觉定心，上传/搜索由注册城市坐标驱动（见下方 onChange）
        }
        .onChange(of: archiveManager.myRecord != nil) { _, hasRecord in
            guard hasRecord, !hasUpdatedLocation else { return }
            hasUpdatedLocation = true
            Task {
                // GPS 坐标作为 fallback（城市未匹配时使用）
                let gpsLat = locationManager.userLocation?.latitude ?? 0
                let gpsLon = locationManager.userLocation?.longitude ?? 0
                if let coord = await matchingService.updateUserLocation(
                    latitude: gpsLat, longitude: gpsLon
                ) {
                    registeredCoord = coord
                    await matchingService.findMatchesWithExpansion(
                        center: coord,
                        minMatchScore: Int(matchThreshold)
                    )
                }
            }
        }
    }

    // MARK: - 命盘切换栏

    private var recordSwitcherBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(archiveManager.myRecords) { record in
                    let isActive = record.id == archiveManager.activeRecord?.id
                    Button {
                        switchActiveRecord(record)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.nickname)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(isActive ? Color(hex: "#E94560") : .white)
                                .lineLimit(1)
                            HStack(spacing: 4) {
                                Text(record.analysisResult.userElement)
                                    .font(.system(size: 10))
                                    .foregroundColor(isActive ? Color(hex: "#E94560") : .gray)
                                Text("·")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                                Text(record.location.isEmpty ? "未知" : record.location)
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isActive
                                      ? Color(hex: "#E94560").opacity(0.15)
                                      : Color(hex: "#1A1A2E"))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isActive ? Color(hex: "#E94560").opacity(0.5) : Color.clear,
                                        lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(hex: "#0A0A12").opacity(0.85))
    }

    private func switchActiveRecord(_ record: SoulArchiveManager.UserGenerationRecord) {
        guard record.id != archiveManager.activeRecord?.id else { return }
        archiveManager.setActiveRecord(record)
        Task {
            let gpsLat = locationManager.userLocation?.latitude ?? 0
            let gpsLon = locationManager.userLocation?.longitude ?? 0
            if let coord = await matchingService.updateUserLocation(
                latitude: gpsLat, longitude: gpsLon
            ) {
                registeredCoord = coord
                focusCoordinate = coord          // 地图立即跳到新城市
                await matchingService.findMatchesWithExpansion(
                    center: coord,
                    minMatchScore: Int(matchThreshold)
                )
            }
        }
    }

    // MARK: - 搜索范围 Banner

    private var scopeBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: matchingService.currentSearchScope == .global ? "globe.fill" : "building.2.fill")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#A78BFA"))

            Text(matchingService.currentSearchScope == .global
                 ? "已扩展至全球 · 最匹配的命缘"
                 : "附近人数较少 · 已扩展至同城")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "#A78BFA"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(hex: "#A78BFA").opacity(0.12))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "#A78BFA").opacity(0.3), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - 首次进入星图引导浮层（T7）

    private var starMapGuideOverlay: some View {
        let steps: [(title: String, body: String, icon: String)] = [
            ("脉冲点", "彩色脉冲点代表与你命格共振的缘人\n颜色代表他们的五行属性", "dot.radiowaves.left.and.right"),
            ("命定星影", "星图上的星影是命定灵魂的数字化身\n点击可与 TA 的分身对话", "person.fill.questionmark"),
            ("操作按钮", "点击链接图标显示所有缘线\n点击定位图标回到你的位置", "location.fill")
        ]
        let step = steps[min(guideStep, steps.count - 1)]

        return ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    Image(systemName: step.icon)
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundColor(Color(hex: "#A78BFA"))

                    VStack(spacing: 8) {
                        Text(step.title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)

                        Text(step.body)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }

                    // 步骤指示点
                    HStack(spacing: 8) {
                        ForEach(0..<steps.count, id: \.self) { i in
                            Circle()
                                .fill(i == guideStep ? Color(hex: "#A78BFA") : Color.white.opacity(0.25))
                                .frame(width: 6, height: 6)
                        }
                    }

                    Button(action: {
                        if guideStep < steps.count - 1 {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                guideStep += 1
                            }
                        } else {
                            UserDefaults.standard.set(true, forKey: "hasSeenStarMapGuide")
                            withAnimation(.easeOut(duration: 0.3)) {
                                showStarMapGuide = false
                            }
                        }
                    }) {
                        Text(guideStep < steps.count - 1 ? "下一步" : "开始探索")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 12)
                            .background(Color(hex: "#A78BFA"))
                            .cornerRadius(20)
                    }
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(hex: "#1A1A2E").opacity(0.97))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color(hex: "#A78BFA").opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 120)
            }
        }
        .transition(.opacity)
        .zIndex(200)
    }

    // MARK: - 地图空状态浮层（T6）
    private var mapEmptyStateOverlay: some View {
        VStack(spacing: 24) {
            Spacer()

            // 星轨装饰
            ZStack {
                Circle()
                    .stroke(Color(hex: "#A78BFA").opacity(0.12), lineWidth: 1)
                    .frame(width: 140, height: 140)
                Circle()
                    .stroke(Color(hex: "#A78BFA").opacity(0.2), lineWidth: 1)
                    .frame(width: 110, height: 110)
                Circle()
                    .stroke(Color(hex: "#A78BFA").opacity(0.3), lineWidth: 1)
                    .frame(width: 80, height: 80)
                Image(systemName: "sparkles")
                    .font(.system(size: 36, weight: .ultraLight))
                    .foregroundColor(Color(hex: "#A78BFA").opacity(0.8))
            }

            VStack(spacing: 10) {
                Text("✦  你的命格之网正在编织中  ✦")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "#A78BFA"))

                Text("当前尚未有与你命格共振的缘人出现")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)

                Text("邀请好友加入，或等待命运的安排")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }

            // 操作按钮
            HStack(spacing: 12) {
                Button(action: {
                    Task {
                        let card = await ShareCardBuilder.buildFromLatestPortrait() ?? InviteCardBuilder.build()
                        starMapShareItem = IdentifiableImage(image: card)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13))
                        Text("邀请缘人加入")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#A78BFA"), Color(hex: "#1A1A2E")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                }
                .sheet(item: $starMapShareItem) { item in
                    ShareSheet(items: [item.image])
                }
            }
            .padding(.top, 4)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(hex: "#0A0A12").opacity(0.88))
        .transition(.opacity)
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


                // 罗盘返回按钮（从翻转容器进入时显示）
                if let onBackTap = onBackTap {
                    RotatingCompassButton(action: onBackTap)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // 命盘切换栏（多命盘时显示）
            if archiveManager.myRecords.count > 1 {
                recordSwitcherBar
            }

            // 搜索范围扩展 Banner
            if matchingService.currentSearchScope == .city || matchingService.currentSearchScope == .global {
                scopeBanner
            }

            // 地图
            ZStack(alignment: .bottom) {
                MapViewRepresentable(
                    userLocation: $registeredCoord,
                    matchedUsers: $matchingService.nearbyMatches,
                    selectedUser: $selectedUser,
                    shouldRecenter: $shouldRecenterMap,
                    focusCoordinate: $focusCoordinate,
                    showConnectionLines: $showConnectionLines,
                    shouldFitAllAnnotations: $shouldFitAllAnnotations,
                    highlightTarget: $highlightTarget,
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

                // 头像和匹配度（shadow 优先显示命定画像）
                ZStack {
                    Circle()
                        .fill(matchScoreColor(user.matchScore).opacity(user.isShadow ? 0.1 : 0.2))
                        .frame(width: 90, height: 90)

                    Circle()
                        .stroke(
                            user.isShadow ? Color(hex: "#A78BFA") : matchScoreColor(user.matchScore),
                            style: user.isShadow
                                ? StrokeStyle(lineWidth: 2, dash: [5, 4])
                                : StrokeStyle(lineWidth: 3)
                        )
                        .frame(width: 90, height: 90)

                    let displayUrl = user.portraitUrl ?? user.avatarUrl
                    if let urlStr = displayUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 84, height: 84)
                                    .clipShape(Circle())
                                    .opacity(user.isShadow ? 0.7 : 1.0)
                            default:
                                Image(systemName: user.isShadow ? "person.fill.questionmark" : "person.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(user.isShadow ? Color(hex: "#A78BFA") : matchScoreColor(user.matchScore))
                                    .opacity(user.isShadow ? 0.6 : 1.0)
                            }
                        }
                    } else {
                        Image(systemName: user.isShadow ? "person.fill.questionmark" : "person.fill")
                            .font(.system(size: 36))
                            .foregroundColor(user.isShadow ? Color(hex: "#A78BFA") : matchScoreColor(user.matchScore))
                            .opacity(user.isShadow ? 0.6 : 1.0)
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

                        // 星影标签
                        if user.isShadow {
                            Text("命定星影")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color(hex: "#A78BFA"))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#A78BFA").opacity(0.2))
                                .cornerRadius(4)
                        }
                    }

                    HStack(spacing: 16) {
                        // 匹配度（主角，字号稍大）
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 13))
                                .foregroundColor(matchScoreColor(user.matchScore))
                            Text("匹配度 \(user.matchScore)%")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                        }

                        // 城市或距离（全国模式显示城市）
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.5))
                            if matchingService.currentSearchScope == .global || user.isShadow {
                                Text(user.city ?? "未知城市")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.8))
                            } else {
                                Text(user.city ?? formatUserDistance(user.distance))
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.8))
                            }
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

                // 星影：性格概述
                if user.isShadow, let summary = user.analysisSummary {
                    let firstSentence = summary.components(separatedBy: CharacterSet(charactersIn: "。.")).first ?? summary
                    Text(firstSentence)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                }

                // 对话按钮（真实用户 vs 星影）
                if user.isShadow {
                    Button(action: {
                        startShadowConversation(with: user)
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "person.wave.2.fill")
                                .font(.system(size: 14))
                            Text("与TA的数字分身对话")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#A78BFA"), Color(hex: "#1A1A2E")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                    }
                    .padding(.top, 8)
                } else {
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
                                        if user.isShadow {
                                            Text("👻")
                                                .font(.system(size: 12))
                                        }
                                        Text(user.nickname)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(user.isShadow ? .white.opacity(0.7) : .white)
                                        if user.isTestUser {
                                            Text("测试")
                                                .font(.system(size: 9))
                                                .foregroundColor(.orange)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.orange.opacity(0.2))
                                                .cornerRadius(3)
                                        }
                                        if user.isShadow {
                                            Text("星影")
                                                .font(.system(size: 9))
                                                .foregroundColor(Color(hex: "#A78BFA"))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color(hex: "#A78BFA").opacity(0.2))
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

                                // 城市
                                Text(user.city ?? "附近")
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
        guard let coord = registeredCoord else { return }
        // 重置聚焦索引
        currentFocusIndex = 0
        Task {
            await matchingService.findMatchesWithExpansion(
                center: coord,
                minMatchScore: Int(matchThreshold)
            )
        }
    }

    // MARK: - 聊天相关方法

    /// 开始与用户对话（先播放连线动画）
    private func startConversation(with user: MatchingService.MatchedUser) {
        print("🔵 [ConnectionView] 开始对话，用户ID: \(user.id), 是否测试用户: \(user.isTestUser)")

        // 关闭用户卡片，设置高亮目标（地图 fit + 大圆弧线），播放连线动画
        withAnimation(.spring(response: 0.3)) {
            showUserCard = false
            highlightTarget = user.coordinate  // 触发地图 fit 并绘制高亮弧线
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

    /// 与星影的 AI 分身开始对话（在当前页面内直接 push）
    private func startShadowConversation(with user: MatchingService.MatchedUser) {
        withAnimation(.spring(response: 0.3)) {
            showUserCard = false
        }
        Task {
            do {
                let companion = try await AICompanionService.shared.createShadowCompanion(from: user)
                shadowCompanionId = companion.id
                shadowPortraitUrl = user.portraitUrl
                hideTabBar.wrappedValue = true
                showShadowChat = true
            } catch {
                print("❌ [ConnectionView] 创建星影分身失败: \(error)")
            }
        }
    }

    /// 格式化距离显示

    /// 格式化用户距离显示
    private func formatUserDistance(_ km: Double) -> String {
        if km < 1 {
            return "附近"
        } else if km < 100 {
            let rounded = (km * 2).rounded() / 2
            return String(format: "约 %.1f km", rounded)
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

    // MARK: - 开发者工具
    #if DEBUG
    private func seedTestUsers() async {
        typealias R = MatchingService.UserLocationRecord
        let rows: [R] = [
            R(id: nil, userId: "test-user-01", latitude: 39.9, longitude: 116.4, nickname: "晨曦若木", userElement: "木", soulmateElement: "水", personalityTraits: ["温柔","创意","细腻","坚韧"], soulmateTraits: ["稳重","理性","包容","幽默"], updatedAt: nil, avatarUrl: nil, city: "北京", isShadow: false, analysisSummary: nil, portraitUrl: nil),
            R(id: nil, userId: "test-user-02", latitude: 31.2, longitude: 121.5, nickname: "烈焰星痕", userElement: "火", soulmateElement: "木", personalityTraits: ["热情","勇敢","魅力","开朗"], soulmateTraits: ["温柔","细腻","聪明","善解人意"], updatedAt: nil, avatarUrl: nil, city: "上海", isShadow: false, analysisSummary: nil, portraitUrl: nil),
            R(id: nil, userId: "test-user-03", latitude: 30.7, longitude: 104.1, nickname: "厚土暖阳", userElement: "土", soulmateElement: "火", personalityTraits: ["稳重","踏实","温暖","包容"], soulmateTraits: ["活泼","创意","聪明","有趣"], updatedAt: nil, avatarUrl: nil, city: "成都", isShadow: false, analysisSummary: nil, portraitUrl: nil),
            R(id: nil, userId: "test-user-04", latitude: 23.1, longitude: 113.3, nickname: "霜月清金", userElement: "金", soulmateElement: "土", personalityTraits: ["理性","独立","果断","精准"], soulmateTraits: ["温柔","细腻","感性","包容"], updatedAt: nil, avatarUrl: nil, city: "广州", isShadow: false, analysisSummary: nil, portraitUrl: nil),
            R(id: nil, userId: "test-user-05", latitude: 30.2, longitude: 120.2, nickname: "碧波灵渊", userElement: "水", soulmateElement: "金", personalityTraits: ["聪明","灵动","善解人意","感性"], soulmateTraits: ["稳重","踏实","理性","专注"], updatedAt: nil, avatarUrl: nil, city: "杭州", isShadow: false, analysisSummary: nil, portraitUrl: nil),
            R(id: nil, userId: "test-user-06", latitude: 22.5, longitude: 114.1, nickname: "南木之息", userElement: "木", soulmateElement: "水", personalityTraits: ["温柔","艺术","直觉","细腻"], soulmateTraits: ["坚定","热情","包容","勇气"], updatedAt: nil, avatarUrl: nil, city: "深圳", isShadow: true, analysisSummary: "她温柔如春风，眼中有光，笑起来能令人忘却世间疲惫。内心丰盈而敏感，擅长用文字和画笔记录生活中的美好瞬间。", portraitUrl: nil),
            R(id: nil, userId: "test-user-07", latitude: 30.6, longitude: 114.3, nickname: "炽焰流年", userElement: "火", soulmateElement: "木", personalityTraits: ["热情","直率","魅力","果敢"], soulmateTraits: ["温柔","耐心","细腻","善解人意"], updatedAt: nil, avatarUrl: nil, city: "武汉", isShadow: true, analysisSummary: "她身上有一种令人着迷的生命力，笑声爽朗，行事果决，对喜欢的事情全情投入，对陌生人也总保持善意与热忱。", portraitUrl: nil),
            R(id: nil, userId: "test-user-08", latitude: 34.3, longitude: 108.9, nickname: "玉衡金曜", userElement: "金", soulmateElement: "木", personalityTraits: ["理性","专注","精致","自律"], soulmateTraits: ["浪漫","创意","温柔","感性"], updatedAt: nil, avatarUrl: nil, city: "西安", isShadow: false, analysisSummary: nil, portraitUrl: nil),
            R(id: nil, userId: "test-user-09", latitude: 32.1, longitude: 118.8, nickname: "流云涉水", userElement: "水", soulmateElement: "火", personalityTraits: ["智慧","灵气","洒脱","感性"], soulmateTraits: ["踏实","热情","包容","有担当"], updatedAt: nil, avatarUrl: nil, city: "南京", isShadow: false, analysisSummary: nil, portraitUrl: nil),
            R(id: nil, userId: "test-user-10", latitude: 29.6, longitude: 106.6, nickname: "山岳归尘", userElement: "土", soulmateElement: "金", personalityTraits: ["踏实","宽容","温暖","沉稳"], soulmateTraits: ["聪慧","活泼","灵动","有趣"], updatedAt: nil, avatarUrl: nil, city: "重庆", isShadow: true, analysisSummary: "她给人一种厚实的安全感，不张扬却令人信赖。喜欢安静的阅读角落，也享受朋友间的热闹聚会，懂得平衡生活的节奏。", portraitUrl: nil),
            R(id: nil, userId: "test-user-11", latitude: 30.3, longitude: 120.3, nickname: "林间清影", userElement: "木", soulmateElement: "金", personalityTraits: ["安静","内敛","有深度","独立"], soulmateTraits: ["开朗","活力","社交","外向"], updatedAt: nil, avatarUrl: nil, city: "杭州", isShadow: false, analysisSummary: nil, portraitUrl: nil),
            R(id: nil, userId: "test-user-12", latitude: 39.8, longitude: 116.5, nickname: "朱雀之光", userElement: "火", soulmateElement: "水", personalityTraits: ["热情","创意","魅力","勇敢","善解人意"], soulmateTraits: ["稳重","细腻","温柔","包容","理性"], updatedAt: nil, avatarUrl: nil, city: "北京", isShadow: false, analysisSummary: nil, portraitUrl: nil),
        ]
        do {
            try await supabase
                .from("user_locations")
                .upsert(rows, onConflict: "user_id")
                .execute()
            print("✅ [DEV] 测试数据种入成功")
            currentFocusIndex = 0

            // registeredCoord 已有值：直接重搜，跳过重新上传位置
            if let coord = registeredCoord {
                await matchingService.findMatchesWithExpansion(
                    center: coord,
                    minMatchScore: Int(matchThreshold)
                )
            } else {
                // updateUserLocation 因 RLS 失败时的后备路径：
                // 直接用 GPS/北京坐标作搜索中心，findMatchesWithExpansion 不要求当前用户行存在
                let gpsLat = locationManager.userLocation?.latitude ?? 39.9042
                let gpsLon = locationManager.userLocation?.longitude ?? 116.4074
                let fallbackCoord = CLLocationCoordinate2D(latitude: gpsLat, longitude: gpsLon)
                registeredCoord = fallbackCoord   // 设置后，threshold 滑动等也能正常工作
                await matchingService.findMatchesWithExpansion(
                    center: fallbackCoord,
                    minMatchScore: Int(matchThreshold)
                )
            }
        } catch {
            print("❌ [DEV] 种入失败: \(error)")
        }
    }

    private func deleteTestUsers() async {
        do {
            try await supabase
                .from("user_locations")
                .delete()
                .like("user_id", pattern: "test-user-%")
                .execute()
            print("✅ [DEV] 测试数据已清除")
            refreshMatches()
        } catch {
            print("❌ [DEV] 清除失败: \(error)")
        }
    }
    #endif
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
    @State private var navigateToFateRecords = false
    @State private var navigateToSettings = false

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
                            // 灵魂档案 - 可导航（与下面两项同级）
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
                            Button(action: { navigateToFateRecords = true }) {
                                profileMenuItemContent(icon: "heart.circle", title: "缘分记录", subtitle: "查看历史匹配")
                            }

                            // 设置
                            Button(action: { navigateToSettings = true }) {
                                profileMenuItemContent(icon: "gearshape", title: "设置", subtitle: "账号与偏好设置")
                            }

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
            .navigationDestination(isPresented: $navigateToFateRecords) {
                FateRecordsView()
            }
            .navigationDestination(isPresented: $navigateToSettings) {
                SettingsView()
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
                    fileName,
                    data: compressedData,
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
    func profileMenuItem(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
        Button(action: {}) {
            profileMenuItemContent(icon: icon, title: title, subtitle: subtitle)
        }
    }

    // 菜单项内容（可复用）
    func profileMenuItemContent(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey) -> some View {
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

// MARK: - 我的资料存储
private enum UserCenterStorage {
    static let profileKey = "user_center_profile_v1"

    static func loadProfile() -> UserProfileDraft {
        guard let data = UserDefaults.standard.data(forKey: profileKey),
              let value = try? JSONDecoder().decode(UserProfileDraft.self, from: data) else {
            return .default
        }
        return value
    }

    static func saveProfile(_ profile: UserProfileDraft) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: profileKey)
    }

}

private struct UserProfileDraft: Codable {
    var nickname: String
    var status: String
    var communication: String
    var hobbies: [String]
    var dislikes: [String]

    static let `default` = UserProfileDraft(
        nickname: "",
        status: "探索中",
        communication: "温柔一点",
        hobbies: [],
        dislikes: []
    )
}

// MARK: - 我的资料页
struct UserProfileSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var profile = UserCenterStorage.loadProfile()
    @State private var showSaved = false
    @State private var expandPreferences = false
    @State private var expandCommunication = false
    @State private var expandHobbies = false
    @State private var expandDislikes = false
    @State private var customCommunication = ""
    @State private var customHobby = ""
    @State private var customDislike = ""

    private let communicationOptions = ["直接一点", "温柔一点", "幽默一点"]
    private let hobbyOptions = ["旅行", "电影", "音乐", "阅读", "健身", "美食", "摄影", "游戏", "宠物", "手作"]
    private let dislikeOptions = ["说教", "冷暴力", "已读不回", "敷衍", "情绪失控", "过度控制"]

    var body: some View {
        ZStack {
            Color(hex: "#0A0A12").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("我的资料")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)
                    Text("只保留必要信息，灵犀会持续学习你的偏好")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.52))

                    baseInfoCard
                    preferencesCard
                }
                .padding(20)
                .padding(.bottom, 96)
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("返回") { dismiss() }
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Button(action: saveProfile) {
                    Text(showSaved ? "已保存并应用" : "保存并应用")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#E94560"), Color(hex: "#1A1A2E")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 10)
            }
            .background(Color(hex: "#0A0A12").opacity(0.96))
        }
    }

    private var baseInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("基础信息")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.92))

            VStack(alignment: .leading, spacing: 8) {
                Text("昵称")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.74))
                TextField("输入你的昵称", text: $profile.nickname)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .foregroundColor(.white)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandPreferences.toggle()
                }
            }) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("偏好设置")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white.opacity(0.92))
                        Text(preferencesSummary)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.52))
                    }
                    Spacer()
                    Image(systemName: expandPreferences ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.58))
                }
            }

            if expandPreferences {
                preferenceItem(
                    title: "沟通偏好",
                    value: profile.communication,
                    expanded: $expandCommunication
                ) {
                    chipGrid(options: mergedSingleOptions(base: communicationOptions, selected: profile.communication), selected: [profile.communication], maxSelect: 1) { value in
                        profile.communication = value
                    }
                    customInputRow(
                        placeholder: "自定义沟通偏好（如：多点陪伴）",
                        text: $customCommunication,
                        buttonTitle: "添加"
                    ) {
                        let value = normalizedCustomValue(customCommunication)
                        guard !value.isEmpty else { return }
                        profile.communication = value
                        customCommunication = ""
                    }
                }

                preferenceItem(
                    title: "兴趣标签",
                    value: profile.hobbies.isEmpty ? "未选择" : "\(profile.hobbies.count) 项",
                    expanded: $expandHobbies
                ) {
                    selectedChips(values: profile.hobbies) { value in
                        toggle(&profile.hobbies, value: value, max: 5)
                    }
                    chipGrid(options: mergedMultiOptions(base: hobbyOptions, selected: profile.hobbies), selected: profile.hobbies, maxSelect: 5) { value in
                        toggle(&profile.hobbies, value: value, max: 5)
                    }
                    customInputRow(
                        placeholder: "自定义兴趣（如：露营）",
                        text: $customHobby,
                        buttonTitle: "添加"
                    ) {
                        let value = normalizedCustomValue(customHobby)
                        guard !value.isEmpty else { return }
                        toggle(&profile.hobbies, value: value, max: 5)
                        customHobby = ""
                    }
                }

                preferenceItem(
                    title: "不喜欢",
                    value: profile.dislikes.isEmpty ? "未填写" : "\(profile.dislikes.count) 项",
                    expanded: $expandDislikes
                ) {
                    selectedChips(values: profile.dislikes) { value in
                        toggle(&profile.dislikes, value: value, max: 3)
                    }
                    chipGrid(options: mergedMultiOptions(base: dislikeOptions, selected: profile.dislikes), selected: profile.dislikes, maxSelect: 3) { value in
                        toggle(&profile.dislikes, value: value, max: 3)
                    }
                    customInputRow(
                        placeholder: "自定义不喜欢（如：临时放鸽子）",
                        text: $customDislike,
                        buttonTitle: "添加"
                    ) {
                        let value = normalizedCustomValue(customDislike)
                        guard !value.isEmpty else { return }
                        toggle(&profile.dislikes, value: value, max: 3)
                        customDislike = ""
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .cornerRadius(12)
    }

    private var preferencesSummary: String {
        let hobbyCount = profile.hobbies.count
        let dislikeCount = profile.dislikes.count
        return "沟通：\(profile.communication)  兴趣：\(hobbyCount)项  不喜欢：\(dislikeCount)项"
    }

    private func preferenceItem<Content: View>(
        title: String,
        value: String,
        expanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expanded.wrappedValue.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Text(value)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                    Image(systemName: expanded.wrappedValue ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.45))
                }
            }

            if expanded.wrappedValue {
                content()
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
    }

    @ViewBuilder
    private func selectedChips(values: [String], onRemove: @escaping (String) -> Void) -> some View {
        if !values.isEmpty {
            FlexibleChipLayout(data: values) { value in
                Button(action: { onRemove(value) }) {
                    HStack(spacing: 5) {
                        Text(value)
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.88))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color(hex: "#E94560").opacity(0.38))
                    .cornerRadius(14)
                }
            }
        }
    }

    private func chipGrid(options: [String], selected: [String], maxSelect: Int, onTap: @escaping (String) -> Void) -> some View {
        FlexibleChipLayout(data: options) { option in
            let isSelected = selected.contains(option)
            Button(action: { onTap(option) }) {
                Text(option)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color(hex: "#E94560").opacity(0.75) : Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(isSelected ? Color(hex: "#E94560") : Color.white.opacity(0.14), lineWidth: 1)
                    )
                    .cornerRadius(18)
            }
        }
    }

    private func customInputRow(placeholder: String, text: Binding<String>, buttonTitle: String, onSubmit: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .foregroundColor(.white.opacity(0.9))
                .background(Color.white.opacity(0.06))
                .cornerRadius(9)

            Button(action: onSubmit) {
                Text(buttonTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(hex: "#E94560").opacity(0.75))
                    .cornerRadius(9)
            }
        }
    }

    private func mergedSingleOptions(base: [String], selected: String) -> [String] {
        guard !selected.isEmpty, !base.contains(selected) else { return base }
        return [selected] + base
    }

    private func mergedMultiOptions(base: [String], selected: [String]) -> [String] {
        let customSelected = selected.filter { !base.contains($0) }
        return customSelected + base
    }

    private func normalizedCustomValue(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func toggle(_ array: inout [String], value: String, max: Int) {
        if let idx = array.firstIndex(of: value) {
            array.remove(at: idx)
        } else if array.count < max {
            array.append(value)
        }
    }

    private func saveProfile() {
        let trimmed = profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.nickname = trimmed
        UserCenterStorage.saveProfile(profile)
        withAnimation {
            showSaved = true
        }
    }
}

// MARK: - 自适应标签布局
struct FlexibleChipLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    private let data: Data
    private let content: (Data.Element) -> Content

    init(data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(Array(data), id: \.self) { item in
                content(item)
            }
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
    MainTabView()
}
