import SwiftUI
import AVFoundation

// MARK: - 吹气检测管理器
class BlowDetectionManager: ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?

    @Published var isBlowing = false
    @Published var blowIntensity: CGFloat = 0 // 0-1 范围

    // 检测阈值（可根据实际调整）
    private let blowThreshold: Float = -20.0  // 分贝阈值，越大越敏感
    private let peakThreshold: Float = -10.0  // 峰值阈值

    var onBlowDetected: ((CGFloat) -> Void)?

    init() {
        setupAudioSession()
        setupRecorder()
    }

    private func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .defaultToSpeaker)
            try audioSession.setActive(true)
        } catch {
            print("音频会话设置失败: \(error)")
        }
    }

    private func setupRecorder() {
        let url = URL(fileURLWithPath: "/dev/null") // 不实际录音，只监测音量

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleLossless),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
        } catch {
            print("录音器设置失败: \(error)")
        }
    }

    func startDetection() {
        // 请求麦克风权限
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.beginMonitoring()
                } else {
                    print("麦克风权限被拒绝")
                }
            }
        }
    }

    private func beginMonitoring() {
        audioRecorder?.record()

        // 每 0.05 秒检测一次音量
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.checkAudioLevels()
        }
    }

    private func checkAudioLevels() {
        guard let recorder = audioRecorder else { return }

        recorder.updateMeters()

        let averagePower = recorder.averagePower(forChannel: 0)
        let peakPower = recorder.peakPower(forChannel: 0)

        // 吹气特征：持续的中高音量 + 相对稳定的峰值
        // 吹气声通常是低频噪音，平均功率较高
        let isCurrentlyBlowing = averagePower > blowThreshold && peakPower > peakThreshold

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if isCurrentlyBlowing {
                // 计算吹气强度 (0-1)
                let normalizedPower = (averagePower - self.blowThreshold) / (-self.blowThreshold)
                self.blowIntensity = min(max(CGFloat(normalizedPower), 0), 1)
                self.isBlowing = true
                self.onBlowDetected?(self.blowIntensity)
            } else {
                self.isBlowing = false
                self.blowIntensity = 0
            }
        }
    }

    func stopDetection() {
        timer?.invalidate()
        timer = nil
        audioRecorder?.stop()
    }

    deinit {
        stopDetection()
    }
}

// MARK: - 主视图
struct MistRevealView: View {
    @Environment(\.dismiss) var dismiss

    // 从上一页传递的数据
    var birthDate: Date
    var gender: String
    var birthTime: String
    var location: String

    // 状态控制：模糊度（模拟吹气后减小）
    @State private var blurRadius: CGFloat = 40
    @State private var isRevealed = false
    @State private var pulseAmount: CGFloat = 1.0

    // 吹气检测
    @StateObject private var blowDetector = BlowDetectionManager()
    @State private var showPermissionAlert = false

    // 视觉反馈
    @State private var breathRingScale: CGFloat = 1.0
    @State private var breathRingOpacity: Double = 0

    // 导航
    @State private var navigateToPortrait = false

    var body: some View {
        ZStack {
            // 1. 背景层：深邃星空渐变
            Color(hex: "#0A0A12").ignoresSafeArea()

            // 动态星云感（模拟 Starla 的 Mesh Gradient）
            RadialGradient(gradient: Gradient(colors: [Color(hex: "#16213E"), .clear]), center: .topLeading, startRadius: 100, endRadius: 600)
                .ignoresSafeArea()
            RadialGradient(gradient: Gradient(colors: [Color(hex: "#E94560").opacity(0.15), .clear]), center: .bottomTrailing, startRadius: 100, endRadius: 500)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 自定义导航栏
                customNavBar

                VStack(spacing: 40) {
                    // 2. 顶部标题：极其疏离的排版
                    VStack(spacing: 8) {
                        Text("命 定 之 缘")
                            .font(.system(size: 14, weight: .light))
                            .tracking(8) // 字间距大幅拉开
                            .foregroundColor(.white.opacity(0.6))

                        Text("破 雾 见 影")
                            .font(.system(size: 24, weight: .semibold))
                            .tracking(4)
                            .foregroundColor(.white)
                    }
                    .padding(.top, 20)

                Spacer()

                // 3. 核心交互区：被迷雾遮盖的画像
                ZStack {
                    // 模拟生成的伴侣画像（2D）
                    Image(systemName: "person.fill") // 实际开发时换成 AI 生成的图片
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 280, height: 380)
                        .foregroundColor(.white.opacity(0.2))
                        .background(
                            RoundedRectangle(cornerRadius: 40)
                                .fill(LinearGradient(colors: [Color.white.opacity(0.1), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                        // 核心模糊效果
                        .blur(radius: blurRadius)

                    // 吹气时的涟漪反馈
                    if blowDetector.isBlowing && !isRevealed {
                        Circle()
                            .stroke(Color(hex: "#E94560").opacity(0.6), lineWidth: 2)
                            .frame(width: 300, height: 300)
                            .scaleEffect(breathRingScale)
                            .opacity(breathRingOpacity)
                    }

                    // 覆盖一层闪烁的粒子感（用 Overlay 代替）
                    if !isRevealed {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            .frame(width: 320, height: 320)
                            .scaleEffect(pulseAmount)
                            .opacity(Double(2 - pulseAmount))
                            .onAppear {
                                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                                    pulseAmount = 1.5
                                }
                            }
                    }
                }
                .onTapGesture {
                    // 备用：点击也可以减少模糊度（用于测试或无麦克风情况）
                    withAnimation(.spring()) {
                        reduceBlur(by: 10)
                    }
                }

                Spacer()

                // 4. 底部提示：毛玻璃按钮
                VStack(spacing: 20) {
                    if !isRevealed {
                        // 吹气强度指示器
                        if blowDetector.isBlowing {
                            HStack(spacing: 4) {
                                ForEach(0..<5) { i in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color(hex: "#E94560").opacity(blowDetector.blowIntensity > CGFloat(i) * 0.2 ? 1 : 0.3))
                                        .frame(width: 8, height: 16 + CGFloat(i) * 4)
                                }
                            }
                            .transition(.opacity)
                        }

                        Text(blowDetector.isBlowing ? "感受到你的气息..." : "向麦克风轻轻吹气，拨开云雾")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(blowDetector.isBlowing ? 0.8 : 0.4))
                            .animation(.easeInOut, value: blowDetector.isBlowing)
                    } else {
                        Button(action: {
                            navigateToPortrait = true
                        }) {
                            Text("凝聚灵力，化为实体")
                                .font(.system(size: 16, weight: .medium))
                                .tracking(2)
                                .foregroundColor(.white)
                                .frame(width: 260, height: 56)
                                .background(.ultraThinMaterial) // 系统级毛玻璃
                                .cornerRadius(28)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                                )
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    }
                    .padding(.bottom, 120)
                }
            }
        }
        .navigationDestination(isPresented: $navigateToPortrait) {
            GeneratedPortraitView(
                birthDate: birthDate,
                gender: gender,
                birthTime: birthTime,
                location: location
            )
        }
        .navigationBarHidden(true)
        .onAppear {
            setupBlowDetection()
        }
        .onDisappear {
            blowDetector.stopDetection()
        }
        .alert("需要麦克风权限", isPresented: $showPermissionAlert) {
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请在设置中允许使用麦克风，以启用吹气互动功能")
        }
    }

    // MARK: - 自定义导航栏
    var customNavBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white)
            }

            Spacer()

            Text("破雾见影")
                .font(.system(size: 12, weight: .light))
                .tracking(4)
                .foregroundColor(.white.opacity(0.6))

            Spacer()

            // 进度小点 - 第三步
            HStack(spacing: 4) {
                Circle().fill(Color.white).frame(width: 4, height: 4)
                Circle().fill(Color.white).frame(width: 4, height: 4)
                Circle().fill(Color.white).frame(width: 4, height: 4)
                Circle().fill(Color.white.opacity(0.3)).frame(width: 4, height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .frame(height: 50)
    }

    // MARK: - 吹气检测设置
    private func setupBlowDetection() {
        blowDetector.onBlowDetected = { intensity in
            // 根据吹气强度减少模糊
            let blurReduction = intensity * 1.5 // 每次检测最多减少 1.5

            withAnimation(.easeOut(duration: 0.1)) {
                reduceBlur(by: blurReduction)
            }

            // 吹气涟漪动画
            triggerBreathRipple()
        }

        blowDetector.startDetection()
    }

    private func reduceBlur(by amount: CGFloat) {
        if blurRadius > 0 {
            blurRadius = max(0, blurRadius - amount)

            // 完全清晰后触发揭示
            if blurRadius == 0 && !isRevealed {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isRevealed = true
                }
                // 停止检测
                blowDetector.stopDetection()

                // 触觉反馈
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
        }
    }

    private func triggerBreathRipple() {
        breathRingScale = 1.0
        breathRingOpacity = 0.8

        withAnimation(.easeOut(duration: 0.5)) {
            breathRingScale = 1.3
            breathRingOpacity = 0
        }
    }
}

// MARK: - 辅助：16进制颜色转换
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - 预览
#Preview {
    NavigationStack {
        MistRevealView(
            birthDate: Date(),
            gender: "乾",
            birthTime: "子时",
            location: "北京"
        )
    }
}
