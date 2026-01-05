import Foundation
import UIKit
import Supabase
import GoogleSignIn

/// 认证管理器
/// 负责处理用户注册、登录、密码重置等认证流程
@MainActor
class AuthManager: ObservableObject {

    // MARK: - 发布属性

    /// 是否已完成认证（登录且完成所有必要流程）
    @Published var isAuthenticated = false

    /// 是否需要设置密码（OTP验证后，注册/重置密码流程中）
    @Published var needsPasswordSetup = false

    /// 当前登录用户
    @Published var currentUser: User?

    /// 是否正在加载
    @Published var isLoading = false

    /// 错误信息
    @Published var errorMessage: String?

    /// 验证码是否已发送
    @Published var otpSent = false

    /// 验证码是否已验证（等待设置密码）
    @Published var otpVerified = false

    // MARK: - 私有属性

    /// 当前流程类型（用于区分注册和重置密码）
    private var currentFlowType: FlowType = .none

    private enum FlowType {
        case none
        case register
        case resetPassword
    }

    // MARK: - 初始化

    init() {
        // 启动时检查现有会话
        Task {
            await checkSession()
        }
    }

    // MARK: - 注册流程

    /// 发送注册验证码
    /// - Parameter email: 用户邮箱
    func sendRegisterOTP(email: String) async {
        guard !email.isEmpty else {
            errorMessage = "请输入邮箱地址"
            return
        }

        isLoading = true
        errorMessage = nil
        currentFlowType = .register
        otpSent = false  // 重置状态，确保 onChange 能触发

        do {
            // 发送 OTP，shouldCreateUser: true 表示如果用户不存在则创建
            try await supabase.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true
            )

            otpSent = true
            print("✅ 注册验证码已发送至: \(email)")

        } catch {
            errorMessage = handleAuthError(error)
            print("❌ 发送注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证注册验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    func verifyRegisterOTP(email: String, code: String) async {
        guard !code.isEmpty else {
            errorMessage = "请输入验证码"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 验证 OTP，type 为 .email 用于注册流程
            let response = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            // 验证成功后用户已登录，但需要设置密码才能完成注册
            currentUser = response.user
            otpVerified = true
            needsPasswordSetup = true
            // 注意：isAuthenticated 保持 false，直到设置密码完成

            print("✅ 注册验证码验证成功，等待设置密码")

        } catch {
            errorMessage = handleAuthError(error)
            print("❌ 验证注册验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 完成注册（设置密码）
    /// - Parameter password: 用户密码
    func completeRegistration(password: String) async {
        guard !password.isEmpty else {
            errorMessage = "请输入密码"
            return
        }

        guard password.count >= 6 else {
            errorMessage = "密码至少需要6位"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            let user = try await supabase.auth.update(
                user: UserAttributes(password: password)
            )

            currentUser = user
            needsPasswordSetup = false
            isAuthenticated = true

            // 保存注册完成标记
            let userId = user.id.uuidString
            UserDefaults.standard.set(true, forKey: "registration_completed_\(userId)")

            // 重置流程状态
            resetFlowState()

            print("✅ 注册完成，密码设置成功")

        } catch {
            errorMessage = handleAuthError(error)
            print("❌ 设置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 登录方法

    /// 邮箱密码登录
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    func signIn(email: String, password: String) async {
        guard !email.isEmpty else {
            errorMessage = "请输入邮箱地址"
            return
        }

        guard !password.isEmpty else {
            errorMessage = "请输入密码"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let response = try await supabase.auth.signIn(
                email: email,
                password: password
            )

            currentUser = response.user
            isAuthenticated = true

            // 能用密码登录说明已完成注册，保存标记
            let userId = response.user.id.uuidString
            UserDefaults.standard.set(true, forKey: "registration_completed_\(userId)")

            print("✅ 登录成功: \(email)")

        } catch {
            errorMessage = handleAuthError(error)
            print("❌ 登录失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 找回密码流程

    /// 发送重置密码验证码
    /// - Parameter email: 用户邮箱
    func sendResetOTP(email: String) async {
        guard !email.isEmpty else {
            errorMessage = "请输入邮箱地址"
            return
        }

        isLoading = true
        errorMessage = nil
        currentFlowType = .resetPassword
        otpSent = false  // 重置状态，确保 onChange 能触发

        do {
            // 发送密码重置邮件（使用 Reset Password 邮件模板）
            try await supabase.auth.resetPasswordForEmail(email)

            otpSent = true
            print("✅ 重置密码验证码已发送至: \(email)")

        } catch {
            errorMessage = handleAuthError(error)
            print("❌ 发送重置密码验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 验证重置密码验证码
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - code: 验证码
    func verifyResetOTP(email: String, code: String) async {
        guard !code.isEmpty else {
            errorMessage = "请输入验证码"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 验证 OTP，type 为 .recovery 用于密码重置流程
            // ⚠️ 注意：这里使用 .recovery 而不是 .email
            let response = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .recovery
            )

            // 验证成功后用户已登录，需要设置新密码
            currentUser = response.user
            otpVerified = true
            needsPasswordSetup = true

            print("✅ 重置密码验证码验证成功，等待设置新密码")

        } catch {
            errorMessage = handleAuthError(error)
            print("❌ 验证重置密码验证码失败: \(error)")
        }

        isLoading = false
    }

    /// 重置密码（设置新密码）
    /// - Parameter newPassword: 新密码
    func resetPassword(newPassword: String) async {
        guard !newPassword.isEmpty else {
            errorMessage = "请输入新密码"
            return
        }

        guard newPassword.count >= 6 else {
            errorMessage = "密码至少需要6位"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 更新用户密码
            let user = try await supabase.auth.update(
                user: UserAttributes(password: newPassword)
            )

            // 保存注册完成标记
            let userId = user.id.uuidString
            UserDefaults.standard.set(true, forKey: "registration_completed_\(userId)")

            // 重置密码成功后，退出登录让用户重新登录
            try await supabase.auth.signOut()

            // 重置所有状态
            currentUser = nil
            needsPasswordSetup = false
            isAuthenticated = false
            resetFlowState()

            print("✅ 密码重置成功，请重新登录")

        } catch {
            errorMessage = handleAuthError(error)
            print("❌ 重置密码失败: \(error)")
        }

        isLoading = false
    }

    // MARK: - 第三方登录（预留）

    /// Apple 登录
    /// TODO: 实现 Apple Sign In
    func signInWithApple() async {
        // TODO: 实现 Apple 登录
        // 1. 使用 AuthenticationServices 获取 Apple 凭证
        // 2. 调用 supabase.auth.signInWithIdToken(credentials:)
        print("⚠️ Apple 登录功能待实现")
        errorMessage = "Apple 登录功能即将推出"
    }

    /// Google 登录
    func signInWithGoogle() async {
        print("🔵 开始 Google 登录流程")
        isLoading = true
        errorMessage = nil

        do {
            // 1. 获取当前的根视图控制器
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                print("❌ 无法获取根视图控制器")
                errorMessage = "无法启动 Google 登录"
                isLoading = false
                return
            }

            print("🔵 获取根视图控制器成功")

            // 2. 调用 Google Sign-In
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            print("🔵 Google 登录成功，用户: \(result.user.profile?.email ?? "未知")")

            // 3. 获取 ID Token
            guard let idToken = result.user.idToken?.tokenString else {
                print("❌ 无法获取 Google ID Token")
                errorMessage = "Google 登录失败：无法获取凭证"
                isLoading = false
                return
            }

            print("🔵 获取 Google ID Token 成功")

            // 4. 使用 ID Token 登录 Supabase
            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken
                )
            )

            print("✅ Supabase Google 登录成功")

            // 5. 更新状态
            currentUser = session.user
            isAuthenticated = true

            // 保存注册完成标记
            let userId = session.user.id.uuidString
            UserDefaults.standard.set(true, forKey: "registration_completed_\(userId)")

            print("✅ Google 登录完成，用户 ID: \(userId)")

        } catch let error as GIDSignInError {
            // Google Sign-In 错误处理
            switch error.code {
            case .canceled:
                print("⚠️ 用户取消了 Google 登录")
                // 用户取消不显示错误
            case .hasNoAuthInKeychain:
                print("❌ Google 登录：钥匙串中无认证信息")
                errorMessage = "请重新登录 Google 账号"
            default:
                print("❌ Google 登录错误: \(error.localizedDescription)")
                errorMessage = "Google 登录失败：\(error.localizedDescription)"
            }
        } catch {
            print("❌ Google 登录失败: \(error)")
            errorMessage = handleAuthError(error)
        }

        isLoading = false
    }

    /// 处理 Google 登录回调 URL
    func handleGoogleSignInURL(_ url: URL) -> Bool {
        print("🔵 处理 Google 回调 URL: \(url)")
        return GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - 其他方法

    /// 退出登录
    func signOut() async {
        isLoading = true
        errorMessage = nil

        do {
            try await supabase.auth.signOut()

            // 重置所有状态
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            resetFlowState()

            print("✅ 已退出登录")

        } catch {
            errorMessage = handleAuthError(error)
            print("❌ 退出登录失败: \(error)")
        }

        isLoading = false
    }

    /// 删除账户
    /// 调用边缘函数删除用户账户及所有相关数据
    func deleteAccount() async -> Bool {
        guard let user = currentUser else {
            errorMessage = "未登录"
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            // 获取当前会话的 access token
            let session = try await supabase.auth.session

            // 调用删除账户的边缘函数
            let data: Data = try await supabase.functions.invoke(
                "delete-account",
                options: FunctionInvokeOptions(
                    headers: ["Authorization": "Bearer \(session.accessToken)"]
                )
            )

            // 解析响应
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 删除账户响应: \(jsonString)")
            }

            // 检查是否成功
            struct DeleteResponse: Decodable {
                let success: Bool?
                let error: String?
                let message: String?
            }

            let deleteResponse = try JSONDecoder().decode(DeleteResponse.self, from: data)

            if let error = deleteResponse.error {
                errorMessage = error
                isLoading = false
                return false
            }

            // 清除本地存储的注册完成标记
            let userId = user.id.uuidString
            UserDefaults.standard.removeObject(forKey: "registration_completed_\(userId)")

            // 重置所有状态
            isAuthenticated = false
            needsPasswordSetup = false
            currentUser = nil
            resetFlowState()

            print("✅ 账户已成功删除")
            isLoading = false
            return true

        } catch {
            errorMessage = "删除账户失败: \(error.localizedDescription)"
            print("❌ 删除账户失败: \(error)")
            isLoading = false
            return false
        }
    }

    /// 检查现有会话
    func checkSession() async {
        isLoading = true

        do {
            let session = try await supabase.auth.session
            currentUser = session.user

            // 检查用户是否完成了完整的注册流程
            // 使用 UserDefaults 存储的标记来判断
            if currentUser != nil {
                let userId = session.user.id.uuidString
                let registrationCompleted = UserDefaults.standard.bool(forKey: "registration_completed_\(userId)")

                if registrationCompleted {
                    // 用户已完成注册（包括设置密码）
                    isAuthenticated = true
                    print("✅ 检测到有效会话，用户已登录")
                } else {
                    // 用户可能是 OTP 登录但未设置密码，需要完成注册
                    needsPasswordSetup = true
                    otpVerified = true
                    print("⚠️ 检测到会话，但用户需要完成注册")
                }
            }

        } catch {
            // 没有有效会话，保持未登录状态
            print("ℹ️ 无有效会话: \(error.localizedDescription)")
        }

        isLoading = false
    }

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }

    // MARK: - 私有方法

    /// 重置流程状态
    private func resetFlowState() {
        otpSent = false
        otpVerified = false
        currentFlowType = .none
    }

    /// 处理认证错误
    /// - Parameter error: 错误对象
    /// - Returns: 用户友好的错误信息
    private func handleAuthError(_ error: Error) -> String {
        let errorString = String(describing: error)

        // 根据错误类型返回友好提示
        if errorString.contains("Invalid login credentials") {
            return "邮箱或密码错误"
        } else if errorString.contains("Email not confirmed") {
            return "邮箱未验证，请先完成验证"
        } else if errorString.contains("User already registered") {
            return "该邮箱已注册，请直接登录"
        } else if errorString.contains("Invalid OTP") || errorString.contains("Token has expired") {
            return "验证码无效或已过期"
        } else if errorString.contains("Email rate limit exceeded") {
            return "发送频率过高，请稍后再试"
        } else if errorString.contains("Password should be at least") {
            return "密码强度不足，请使用更复杂的密码"
        } else if errorString.contains("network") || errorString.contains("connection") {
            return "网络连接失败，请检查网络"
        } else {
            return "操作失败，请稍后重试"
        }
    }
}
