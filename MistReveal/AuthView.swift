import SwiftUI

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager

    // 页面状态
    @State private var selectedTab = 0 // 0: 登录, 1: 注册
    @State private var showForgotPassword = false
    @State private var showToast = false
    @State private var toastMessage = ""

    // 登录表单
    @State private var loginEmail = ""
    @State private var loginPassword = ""

    // 注册表单
    @State private var registerEmail = ""
    @State private var registerCode = ""
    @State private var registerPassword = ""
    @State private var registerConfirmPassword = ""
    @State private var registerStep = 1 // 1: 邮箱, 2: 验证码, 3: 密码

    // 找回密码表单
    @State private var resetEmail = ""
    @State private var resetCode = ""
    @State private var resetPassword = ""
    @State private var resetConfirmPassword = ""
    @State private var resetStep = 1

    // 倒计时
    @State private var countdown = 0
    @State private var resetCountdown = 0
    @State private var timer: Timer?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景渐变
                backgroundGradient

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // 顶部 Logo
                        headerView
                            .padding(.top, 60)

                        // Tab 切换
                        tabSelector
                            .padding(.top, 40)

                        // 内容区域
                        if selectedTab == 0 {
                            loginView
                        } else {
                            registerView
                        }

                        // 底部第三方登录
                        socialLoginSection
                            .padding(.top, 40)
                            .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 24)
                }

                // 错误提示
                if let error = authManager.errorMessage {
                    errorBanner(message: error)
                }

                // Toast 提示
                if showToast {
                    toastView
                }

                // 加载遮罩
                if authManager.isLoading {
                    loadingOverlay
                }
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            forgotPasswordSheet
        }
        .onChange(of: authManager.otpVerified) { _, verified in
            // OTP 验证成功后的处理（步骤切换已在按钮点击时处理）
            if verified {
                print("🔵 OTP 验证状态变更: \(verified)")
            }
        }
        .onChange(of: authManager.otpSent) { _, sent in
            // OTP 发送成功后，自动切换到第二步并开始倒计时
            if sent {
                if selectedTab == 1 && registerStep == 1 {
                    registerStep = 2
                    startCountdown()
                } else if showForgotPassword && resetStep == 1 {
                    resetStep = 2
                    startResetCountdown()
                }
            }
        }
    }

    // MARK: - 背景渐变

    var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(hex: "#0A0A12"),
                Color(hex: "#16213E"),
                Color(hex: "#0A0A12")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - 顶部 Logo

    var headerView: some View {
        VStack(spacing: 16) {
            // Logo 圆环
            ZStack {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [Color(hex: "#E94560").opacity(0.6), Color(hex: "#16213E"), Color(hex: "#E94560").opacity(0.6)],
                            center: .center
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 80, height: 80)

                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    .frame(width: 60, height: 60)

                Image(systemName: "sparkles")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#E94560"))
            }

            // 标题
            Text("缘 起")
                .font(.system(size: 32, weight: .bold))
                .tracking(8)
                .foregroundColor(.white)
        }
    }

    // MARK: - Tab 选择器

    var tabSelector: some View {
        HStack(spacing: 0) {
            tabButton(title: "登录", index: 0)
            tabButton(title: "注册", index: 1)
        }
        .background(Color.white.opacity(0.1))
        .cornerRadius(25)
        .padding(.horizontal, 40)
    }

    func tabButton(title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
                authManager.clearError()
            }
        }) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(selectedTab == index ? .white : .white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    selectedTab == index ?
                    Color(hex: "#E94560").opacity(0.8) : Color.clear
                )
                .cornerRadius(22)
        }
    }

    // MARK: - 登录视图

    var loginView: some View {
        VStack(spacing: 20) {
            // 邮箱输入
            inputField(
                icon: "envelope",
                placeholder: "邮箱地址",
                text: $loginEmail,
                keyboardType: .emailAddress
            )

            // 密码输入
            secureInputField(
                icon: "lock",
                placeholder: "密码",
                text: $loginPassword
            )

            // 登录按钮
            primaryButton(title: "登录") {
                Task {
                    await authManager.signIn(email: loginEmail, password: loginPassword)
                }
            }
            .padding(.top, 10)

            // 忘记密码
            Button(action: {
                showForgotPassword = true
                resetStep = 1
                resetEmail = ""
                resetCode = ""
                resetPassword = ""
                resetConfirmPassword = ""
            }) {
                Text("忘记密码？")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#E94560"))
            }
        }
        .padding(.top, 30)
    }

    // MARK: - 注册视图

    var registerView: some View {
        VStack(spacing: 20) {
            // 步骤指示器
            stepIndicator(currentStep: registerStep, totalSteps: 3)
                .padding(.bottom, 10)

            switch registerStep {
            case 1:
                registerStep1View
            case 2:
                registerStep2View
            case 3:
                registerStep3View
            default:
                EmptyView()
            }
        }
        .padding(.top, 30)
    }

    // 注册第一步：邮箱 + 密码
    var registerStep1View: some View {
        VStack(spacing: 20) {
            Text("创建你的账号")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))

            inputField(
                icon: "envelope",
                placeholder: "邮箱地址",
                text: $registerEmail,
                keyboardType: .emailAddress
            )

            secureInputField(
                icon: "lock",
                placeholder: "设置密码（至少6位）",
                text: $registerPassword
            )

            secureInputField(
                icon: "lock.fill",
                placeholder: "确认密码",
                text: $registerConfirmPassword
            )

            if !registerPassword.isEmpty && !registerConfirmPassword.isEmpty && registerPassword != registerConfirmPassword {
                Text("两次输入的密码不一致")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#E94560"))
            }

            primaryButton(title: "发送验证码") {
                // 验证密码
                if registerPassword.count < 6 {
                    authManager.errorMessage = "密码至少需要6位"
                    return
                }
                if registerPassword != registerConfirmPassword {
                    authManager.errorMessage = "两次输入的密码不一致"
                    return
                }
                Task {
                    await authManager.sendRegisterOTP(email: registerEmail)
                }
            }
        }
    }

    // 注册第二步：验证码
    var registerStep2View: some View {
        VStack(spacing: 20) {
            Text("输入验证码")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))

            Text("验证码已发送至 \(registerEmail)")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))

            // 验证码输入
            codeInputField(code: $registerCode)

            primaryButton(title: "验证") {
                Task {
                    let success = await authManager.verifyRegisterOTP(email: registerEmail, code: registerCode)
                    if success {
                        registerStep = 3  // 验证成功，进入下一步
                    }
                }
            }

            // 重发按钮
            if countdown > 0 {
                Text("\(countdown)秒后可重新发送")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            } else {
                Button(action: {
                    Task {
                        await authManager.sendRegisterOTP(email: registerEmail)
                        startCountdown()
                    }
                }) {
                    Text("重新发送验证码")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#E94560"))
                }
            }

            // 返回修改邮箱按钮
            Button(action: {
                registerStep = 1
                registerCode = ""
                authManager.otpSent = false
            }) {
                Text("返回修改邮箱")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.top, 10)
        }
    }

    // 注册第三步：完成注册
    var registerStep3View: some View {
        VStack(spacing: 24) {
            // 成功图标
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(Color(hex: "#4CAF50"))

            Text("邮箱验证成功")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text("点击下方按钮完成注册")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))

            primaryButton(title: "完成注册") {
                Task {
                    let success = await authManager.completeRegistration(email: registerEmail, password: registerPassword)
                    if success {
                        // 注册成功，重置表单并切换到登录页
                        registerEmail = ""
                        registerPassword = ""
                        registerConfirmPassword = ""
                        registerCode = ""
                        registerStep = 1
                        selectedTab = 0  // 切换到登录 Tab
                        showToastMessage("注册成功，请登录")
                    }
                }
            }
            .padding(.top, 10)
        }
    }

    // MARK: - 忘记密码弹窗

    var forgotPasswordSheet: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0A0A12").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 步骤指示器
                        stepIndicator(currentStep: resetStep, totalSteps: 3)
                            .padding(.top, 20)
                            .padding(.bottom, 10)

                        switch resetStep {
                        case 1:
                            resetStep1View
                        case 2:
                            resetStep2View
                        case 3:
                            resetStep3View
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 24)
                }

                if authManager.isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle("找回密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        showForgotPassword = false
                    }
                    .foregroundColor(Color(hex: "#E94560"))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // 重置密码第一步
    var resetStep1View: some View {
        VStack(spacing: 20) {
            Text("输入注册邮箱")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))

            inputField(
                icon: "envelope",
                placeholder: "邮箱地址",
                text: $resetEmail,
                keyboardType: .emailAddress
            )

            primaryButton(title: "发送验证码") {
                Task {
                    await authManager.sendResetOTP(email: resetEmail)
                }
            }
        }
    }

    // 重置密码第二步
    var resetStep2View: some View {
        VStack(spacing: 20) {
            Text("输入验证码")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))

            Text("验证码已发送至 \(resetEmail)")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.5))

            codeInputField(code: $resetCode)

            primaryButton(title: "验证") {
                Task {
                    await authManager.verifyResetOTP(email: resetEmail, code: resetCode)
                    if authManager.otpVerified {
                        resetStep = 3
                    }
                }
            }

            // 重发按钮
            if resetCountdown > 0 {
                Text("\(resetCountdown)秒后可重新发送")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            } else {
                Button(action: {
                    Task {
                        await authManager.sendResetOTP(email: resetEmail)
                        startResetCountdown()
                    }
                }) {
                    Text("重新发送验证码")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "#E94560"))
                }
            }
        }
    }

    // 重置密码第三步
    var resetStep3View: some View {
        VStack(spacing: 20) {
            Text("设置新密码")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.8))

            secureInputField(
                icon: "lock",
                placeholder: "新密码",
                text: $resetPassword
            )

            secureInputField(
                icon: "lock.fill",
                placeholder: "确认新密码",
                text: $resetConfirmPassword
            )

            if !resetPassword.isEmpty && !resetConfirmPassword.isEmpty && resetPassword != resetConfirmPassword {
                Text("两次输入的密码不一致")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#E94560"))
            }

            primaryButton(title: "重置密码") {
                if resetPassword != resetConfirmPassword {
                    authManager.errorMessage = "两次输入的密码不一致"
                    return
                }
                Task {
                    await authManager.resetPassword(newPassword: resetPassword)
                    // 重置成功后关闭弹窗，显示提示
                    if authManager.errorMessage == nil {
                        showForgotPassword = false
                        showToastMessage("密码重置成功，请重新登录")
                    }
                }
            }
        }
    }

    // MARK: - 第三方登录

    var socialLoginSection: some View {
        VStack(spacing: 20) {
            // 分隔线
            HStack {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)

                Text("或者使用以下方式登录")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .fixedSize()

                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)
            }

            // 第三方登录按钮
            VStack(spacing: 12) {
                // Apple 登录
                Button(action: {
                    Task {
                        await authManager.signInWithApple()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 18))
                        Text("通过 Apple 登录")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.black)
                    .cornerRadius(25)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                }

                // Google 登录
                Button(action: {
                    Task {
                        await authManager.signInWithGoogle()
                    }
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 18))
                        Text("通过 Google 登录")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white)
                    .cornerRadius(25)
                }
            }
        }
    }

    // MARK: - 通用组件

    // 输入框
    func inputField(icon: String, placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 24)

            TextField(placeholder, text: text)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .autocorrectionDisabled()
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    // 密码输入框
    func secureInputField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 24)

            SecureField(placeholder, text: text)
                .font(.system(size: 16))
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    // 验证码输入框
    func codeInputField(code: Binding<String>) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { index in
                let codeArray = Array(code.wrappedValue)
                let char = index < codeArray.count ? String(codeArray[index]) : ""

                Text(char)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 45, height: 55)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                index < codeArray.count ? Color(hex: "#E94560") : Color.white.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            }
        }
        .overlay(
            TextField("", text: code)
                .keyboardType(.numberPad)
                .foregroundColor(.clear)
                .accentColor(.clear)
                .onChange(of: code.wrappedValue) { _, newValue in
                    // 限制为6位数字
                    let filtered = newValue.filter { $0.isNumber }
                    if filtered.count <= 6 {
                        code.wrappedValue = filtered
                    } else {
                        code.wrappedValue = String(filtered.prefix(6))
                    }
                }
        )
    }

    // 主要按钮
    func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
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
                .shadow(color: Color(hex: "#E94560").opacity(0.3), radius: 10, x: 0, y: 5)
        }
    }

    // 步骤指示器
    func stepIndicator(currentStep: Int, totalSteps: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(1...totalSteps, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Color(hex: "#E94560") : Color.white.opacity(0.3))
                    .frame(width: 8, height: 8)

                if step < totalSteps {
                    Rectangle()
                        .fill(step < currentStep ? Color(hex: "#E94560") : Color.white.opacity(0.3))
                        .frame(width: 30, height: 2)
                }
            }
        }
    }

    // 错误横幅
    func errorBanner(message: String) -> some View {
        VStack {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.white)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    authManager.clearError()
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(Color.red.opacity(0.9))
            .cornerRadius(12)
            .padding(.horizontal, 24)
            .padding(.top, 60)

            Spacer()
        }
        .transition(.move(edge: .top))
        .animation(.easeInOut, value: authManager.errorMessage)
    }

    // Toast 视图
    var toastView: some View {
        VStack {
            Spacer()

            Text(toastMessage)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))
                .cornerRadius(20)
                .padding(.bottom, 100)
        }
        .transition(.opacity)
        .animation(.easeInOut, value: showToast)
    }

    // 加载遮罩
    var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)

                Text("请稍候...")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            .padding(30)
            .background(Color(hex: "#1A1A2E"))
            .cornerRadius(16)
        }
    }

    // MARK: - 辅助方法

    func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showToast = false
        }
    }

    func startCountdown() {
        countdown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer?.invalidate()
            }
        }
    }

    func startResetCountdown() {
        resetCountdown = 60
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if resetCountdown > 0 {
                resetCountdown -= 1
            } else {
                timer?.invalidate()
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(AuthManager())
}
