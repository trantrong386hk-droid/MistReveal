import SwiftUI

struct CoordinatesInputView: View {
    @Environment(\.dismiss) var dismiss

    // 是否为朋友生成
    var forFriend: Bool = false
    var friendNickname: String = ""

    // 数据状态
    @State private var birthDate = Date()
    @State private var gender: String = "" // 男 / 女

    // 时间输入模式
    enum BirthTimeMode {
        case precise         // 精确 HH:mm
        case traditional     // 按时辰选择
        case unknown         // 不知道
    }

    @State private var birthTimeDate: Date = {
        // 默认 12:00
        var components = DateComponents()
        components.hour = 12
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()
    @State private var birthTimeMode: BirthTimeMode = .precise
    @State private var traditionalTime: String = "子时 (23:00-01:00)"

    // 省市选择
    @State private var selectedProvince: String = ""
    @State private var selectedCity: String = ""

    // 加载状态
    @State private var isAnalyzing = false
    @State private var loadingProgress: CGFloat = 0
    @State private var loadingText = "正在解读你的灵魂印记..."

    // SoulmateManager & ArchiveManager
    @ObservedObject private var soulmateManager = SoulmateManager.shared
    @ObservedObject private var archiveManager = SoulArchiveManager.shared

    // 导航
    @State private var navigateToReport = false

    // 时辰列表（回退模式用）
    let timeSlots = [
        "子时 (23:00-01:00)",
        "丑时 (01:00-03:00)",
        "寅时 (03:00-05:00)",
        "卯时 (05:00-07:00)",
        "辰时 (07:00-09:00)",
        "巳时 (09:00-11:00)",
        "午时 (11:00-13:00)",
        "未时 (13:00-15:00)",
        "申时 (15:00-17:00)",
        "酉时 (17:00-19:00)",
        "戌时 (19:00-21:00)",
        "亥时 (21:00-23:00)"
    ]

    /// 统一输出 birthTime 字符串（供下游使用）
    var birthTimeString: String {
        switch birthTimeMode {
        case .unknown:
            return "未知"
        case .traditional:
            return traditionalTime
        case .precise:
            let h = Calendar.current.component(.hour, from: birthTimeDate)
            let m = Calendar.current.component(.minute, from: birthTimeDate)
            return String(format: "%02d:%02d", h, m)
        }
    }

    /// 统一输出 location 字符串（供下游使用）
    var locationString: String {
        if !selectedCity.isEmpty {
            return selectedCity
        } else if !selectedProvince.isEmpty {
            return selectedProvince
        }
        return ""
    }

    /// 当前省份下的城市列表
    var availableCities: [ChinaCityData.City] {
        ChinaCityData.cities[selectedProvince] ?? []
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 纯色背景
                Color(hex: "#0A0A12").ignoresSafeArea()

                VStack(spacing: 0) {
                // 1. 模仿 Starla 的自定义导航栏
                customNavBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 30) {
                        // 标题引导
                        VStack(alignment: .leading, spacing: 12) {
                            Text("溯源初生")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .tracking(2)
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                            Text("录入你的时空坐标，打捞沉睡的灵魂")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                                .tracking(1)
                                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                        // 2. 输入区域 - 毛玻璃卡片组合
                        VStack(spacing: 20) {

                            // 性别选择 (男/女)
                            inputCard(title: "性灵属性") {
                                HStack(spacing: 20) {
                                    genderButton(title: "男", isSelected: gender == "男") { gender = "男" }
                                    genderButton(title: "女", isSelected: gender == "女") { gender = "女" }
                                }
                            }

                            // 生日选择
                            inputCard(title: "降临日期") {
                                DatePicker("", selection: $birthDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .environment(\.locale, Locale(identifier: "zh_CN"))
                                    .colorInvert() // 使其在深色背景下显示清晰
                                    .colorMultiply(.white)
                            }

                            // 出生时间
                            inputCard(title: "出生时间") {
                                VStack(alignment: .leading, spacing: 12) {
                                    if birthTimeMode == .traditional {
                                        // 时辰回退模式
                                        Picker("时辰", selection: $traditionalTime) {
                                            ForEach(timeSlots, id: \.self) { time in
                                                Text(time).tag(time)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .accentColor(.white)
                                    } else if birthTimeMode == .precise {
                                        // 精确 HH:mm 滚轮
                                        DatePicker("", selection: $birthTimeDate, displayedComponents: .hourAndMinute)
                                            .datePickerStyle(.wheel)
                                            .labelsHidden()
                                            .environment(\.locale, Locale(identifier: "zh_CN"))
                                            .frame(height: 120)
                                            .clipped()
                                            .colorInvert()
                                            .colorMultiply(.white)
                                    }
                                    // unknown 模式不显示任何时间选择器

                                    // 时辰回退开关
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            birthTimeMode = birthTimeMode == .traditional ? .precise : .traditional
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: birthTimeMode == .traditional ? "checkmark.square.fill" : "square")
                                                .font(.system(size: 14))
                                                .foregroundColor(birthTimeMode == .traditional ? Color(hex: "#E94560") : .white.opacity(0.5))
                                            Text("不确定具体时间，按时辰选择")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                    }

                                    // 完全不知道出生时间
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            birthTimeMode = birthTimeMode == .unknown ? .precise : .unknown
                                        }
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: birthTimeMode == .unknown ? "checkmark.square.fill" : "square")
                                                .font(.system(size: 14))
                                                .foregroundColor(birthTimeMode == .unknown ? Color(hex: "#E94560") : .white.opacity(0.5))
                                            Text("完全不知道出生时间")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                    }
                                }
                            }

                            // 出生坐标（省市联动）
                            inputCard(title: "现世坐标") {
                                VStack(alignment: .leading, spacing: 12) {
                                    // 省份选择
                                    HStack {
                                        Text("省份")
                                            .font(.system(size: 14))
                                            .foregroundColor(.white.opacity(0.6))
                                        Spacer()
                                        Picker("省份", selection: $selectedProvince) {
                                            Text("请选择").tag("")
                                            ForEach(ChinaCityData.provinces, id: \.self) { province in
                                                Text(province).tag(province)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .accentColor(.white)
                                    }

                                    // 城市选择（省份选定后显示）
                                    if !selectedProvince.isEmpty && availableCities.count > 1 {
                                        HStack {
                                            Text("城市")
                                                .font(.system(size: 14))
                                                .foregroundColor(.white.opacity(0.6))
                                            Spacer()
                                            Picker("城市", selection: $selectedCity) {
                                                Text("请选择").tag("")
                                                ForEach(availableCities, id: \.name) { city in
                                                    Text(city.name).tag(city.name)
                                                }
                                            }
                                            .pickerStyle(.menu)
                                            .accentColor(.white)
                                        }
                                    }
                                }
                            }
                            .onChange(of: selectedProvince) { _, _ in
                                // 省份变化时重置城市
                                let cities = ChinaCityData.cities[selectedProvince] ?? []
                                if cities.count == 1 {
                                    selectedCity = cities[0].name
                                } else {
                                    selectedCity = ""
                                }
                            }
                        }
                        .padding(.horizontal, 24)

                        // 3. 开启按钮
                        Button(action: {
                            startSoulAnalysis()
                        }) {
                            Text("开启灵魂推演")
                                .font(.system(size: 16, weight: .bold))
                                .tracking(4)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(
                                    LinearGradient(colors: [Color(hex: "#E94560"), Color(hex: "#1A1A2E")], startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(30)
                                .shadow(color: Color(hex: "#E94560").opacity(0.3), radius: 20, x: 0, y: 10)
                        }
                        .disabled(isAnalyzing)
                        .opacity(isAnalyzing ? 0.6 : 1)
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                        .padding(.bottom, 100)
                    }
                }
            }

                // 全屏加载动画覆盖层
                if isAnalyzing {
                    analysisLoadingOverlay
                }
            }
            .clipped()
        }
        .navigationBarHidden(true) // 隐藏原生导航栏
        .navigationDestination(isPresented: $navigateToReport) {
            ReportView(
                birthDate: birthDate,
                gender: gender,
                birthTime: birthTimeString,
                location: locationString
            )
        }
        .onChange(of: soulmateManager.soulAnalysis) { _, newValue in
            // 分析完成后跳转
            if let result = newValue, isAnalyzing {
                // 保存到数据库
                Task {
                    let nickname = forFriend ? friendNickname : "我自己"
                    let isSelf = !forFriend
                    _ = await archiveManager.saveAnalysisResult(
                        gender: gender,
                        birthDate: birthDate,
                        birthTime: birthTimeString,
                        location: locationString,
                        analysisResult: result,
                        nickname: nickname,
                        isSelf: isSelf
                    )
                }
                isAnalyzing = false
                navigateToReport = true
            }
        }
        .onChange(of: soulmateManager.state) { _, newState in
            // 处理失败状态
            if newState == .failed && isAnalyzing {
                isAnalyzing = false
            }
        }
    }

    // MARK: - 加载动画覆盖层

    var analysisLoadingOverlay: some View {
        ZStack {
            // 半透明背景
            Color(hex: "#0A0A12").opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // 加载动画圆环
                ZStack {
                    // 外层光环
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color(hex: "#E94560").opacity(0.3 - Double(i) * 0.1), lineWidth: 1)
                            .frame(width: 160 + CGFloat(i) * 40, height: 160 + CGFloat(i) * 40)
                    }

                    // 旋转的进度环
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            AngularGradient(
                                colors: [Color(hex: "#E94560"), Color(hex: "#E94560").opacity(0.3)],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(loadingProgress))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: loadingProgress)

                    // 中心图标
                    Image(systemName: "sparkles")
                        .font(.system(size: 36))
                        .foregroundColor(Color(hex: "#E94560").opacity(0.8))
                }

                // 加载文案
                VStack(spacing: 12) {
                    Text("灵魂解析中")
                        .font(.system(size: 24, weight: .bold))
                        .tracking(4)
                        .foregroundColor(.white)

                    Text(soulmateManager.progressText.isEmpty ? loadingText : soulmateManager.progressText)
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .animation(.easeInOut, value: soulmateManager.progressText)
                }

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            loadingProgress = 360
        }
    }

    // MARK: - 开始灵魂分析

    func startSoulAnalysis() {
        // 格式化生日
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        let birthDateString = formatter.string(from: birthDate)

        let currentBirthTime = birthTimeString
        let currentLocation = locationString

        // 显示加载动画
        isAnalyzing = true
        loadingProgress = 0

        Task {
            // 先检查数据库是否已有记录
            if let existingResult = await archiveManager.checkExistingRecord(
                gender: gender,
                birthDate: birthDate,
                birthTime: currentBirthTime,
                location: currentLocation
            ) {
                print("✅ [CoordinatesInputView] 找到已有分析结果，开始校验...")
                // 始终计算八字（用于校验 + 补充）
                var resultWithBaZi = existingResult
                let recalculated = TextGenerationService.shared.calculateBaZi(birthDate: birthDateString, birthTime: currentBirthTime, location: currentLocation, gender: gender)

                if resultWithBaZi.baziInfo == nil || resultWithBaZi.baziInfo?.targetAge == nil || resultWithBaZi.baziInfo?.isValid != true {
                    resultWithBaZi.baziInfo = recalculated
                    print("🔵 [CoordinatesInputView] 补充八字信息: targetAge=\(recalculated?.targetAge ?? -1)")
                }

                // ★ 校验：缓存版本/伴侣五行 vs 系统计算的喜用神
                let cachedPromptVersion = resultWithBaZi.promptVersion ?? "unknown"
                if cachedPromptVersion != TextGenerationService.soulAnalysisPromptVersion {
                    print("⚠️ [Cache] 缓存提示词版本「\(cachedPromptVersion)」≠ 当前版本「\(TextGenerationService.soulAnalysisPromptVersion)」→ 强制重新生成")
                    await soulmateManager.startSoulAnalysis(
                        birthDate: birthDateString,
                        gender: gender,
                        birthTime: currentBirthTime,
                        location: currentLocation
                    )
                    return
                }
                if let bazi = recalculated, resultWithBaZi.soulmateElement != bazi.xiYongShen {
                    print("⚠️ [Cache] 缓存伴侣五行「\(resultWithBaZi.soulmateElement)」≠ 喜用神「\(bazi.xiYongShen)」→ 强制重新生成")
                    await soulmateManager.startSoulAnalysis(
                        birthDate: birthDateString,
                        gender: gender,
                        birthTime: currentBirthTime,
                        location: currentLocation
                    )
                } else {
                    print("✅ [Cache] 缓存校验通过，使用已有结果")
                    soulmateManager.soulAnalysis = resultWithBaZi
                    soulmateManager.state = .analyzingSoulmate

                    // 添加到用户历史（不消耗配额）
                    let nickname = forFriend ? friendNickname : "我自己"
                    let isSelf = !forFriend
                    _ = await archiveManager.saveAnalysisResult(
                        gender: gender,
                        birthDate: birthDate,
                        birthTime: currentBirthTime,
                        location: currentLocation,
                        analysisResult: existingResult,
                        nickname: nickname,
                        isSelf: isSelf
                    )

                    isAnalyzing = false
                    navigateToReport = true
                }
            } else {
                // 调用 SoulmateManager 开始分析
                await soulmateManager.startSoulAnalysis(
                    birthDate: birthDateString,
                    gender: gender,
                    birthTime: currentBirthTime,
                    location: currentLocation
                )
            }
        }
    }

    // --- 子组件 ---

    // 模仿 Starla 极简导航栏
    var customNavBar: some View {
        HStack {
            // 帮朋友生成时显示返回按钮
            if forFriend {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(.white)
                }
            } else {
                Color.clear.frame(width: 24, height: 24)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(forFriend ? "为 \(friendNickname) 测算" : "时空坐标")
                    .font(.system(size: 12, weight: .light))
                    .tracking(4)
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer()

            // 进度小点 - 第一步 (1/5)
            HStack(spacing: 4) {
                Circle().fill(Color.white).frame(width: 4, height: 4)
                Circle().fill(Color.white.opacity(0.3)).frame(width: 4, height: 4)
                Circle().fill(Color.white.opacity(0.3)).frame(width: 4, height: 4)
                Circle().fill(Color.white.opacity(0.3)).frame(width: 4, height: 4)
                Circle().fill(Color.white.opacity(0.3)).frame(width: 4, height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .frame(height: 50)
    }

    // 通用输入卡片
    func inputCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.85))
                .tracking(1)

            HStack {
                content()
                Spacer()
            }
            .padding()
            .background(.white.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }

    // 性别按钮
    func genderButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                .frame(width: 80, height: 40)
                .background(isSelected ? Color(hex: "#E94560").opacity(0.5) : Color.white.opacity(0.15))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color(hex: "#E94560") : Color.white.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

#Preview {
    CoordinatesInputView()
}
