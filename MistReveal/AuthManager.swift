import Foundation
import UIKit
import Supabase
import GoogleSignIn
import AuthenticationServices
import CryptoKit

extension Notification.Name {
    static let authSessionExpired = Notification.Name("authSessionExpired")
}

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
        // 监听 session 过期通知（由各 service 在 sessionMissing 时发送）
        NotificationCenter.default.addObserver(
            forName: .authSessionExpired,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.signOut()
            }
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
            print("🔵 检查邮箱是否已注册: \(email)")

            // 先检查邮箱是否已注册
            let emailExists = await checkEmailExists(email: email)
            if emailExists {
                print("❌ 邮箱已被注册: \(email)")
                errorMessage = "该邮箱已注册，请直接登录"
                isLoading = false
                return
            }

            print("🔵 发送注册验证码: \(email)")

            // 使用 Supabase Auth 内置邮件服务发送验证码
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
    /// - Returns: 验证是否成功
    func verifyRegisterOTP(email: String, code: String) async -> Bool {
        guard !code.isEmpty else {
            errorMessage = "请输入验证码"
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            print("🔵 验证注册验证码: \(email)")

            // 验证 OTP
            let response = try await supabase.auth.verifyOTP(
                email: email,
                token: code,
                type: .email
            )

            currentUser = response.user
            otpVerified = true
            print("✅ 注册验证码验证成功")
            isLoading = false
            return true

        } catch {
            errorMessage = handleAuthError(error)
            print("❌ 验证注册验证码失败: \(error)")
            isLoading = false
            return false
        }
    }

    /// 完成注册（设置密码）
    /// - Parameters:
    ///   - email: 用户邮箱
    ///   - password: 用户密码
    /// - Returns: 是否注册成功
    func completeRegistration(email: String, password: String) async -> Bool {
        guard !password.isEmpty else {
            errorMessage = "请输入密码"
            return false
        }

        guard password.count >= 6 else {
            errorMessage = "密码至少需要6位"
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            print("🔵 设置用户密码")

            // 更新用户密码
            let user = try await supabase.auth.update(
                user: UserAttributes(password: password)
            )

            print("✅ 密码设置成功，用户ID: \(user.id.uuidString)")

            // 保存注册完成标记
            let userId = user.id.uuidString
            UserDefaults.standard.set(true, forKey: "registration_completed_\(userId)")

            // 退出登录，让用户重新登录
            try await supabase.auth.signOut()
            print("🔵 已退出登录，等待用户重新登录")

            // 重置所有状态
            currentUser = nil
            needsPasswordSetup = false
            isAuthenticated = false
            otpVerified = false
            otpSent = false
            resetFlowState()

            print("✅ 注册完成，请用户登录")
            isLoading = false
            return true

        } catch {
            errorMessage = handleAuthError(error)
            print("❌ 设置密码失败: \(error)")
            isLoading = false
            return false
        }
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
            print("🔵 尝试登录: \(email)")
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
            // 如果走到这里，说明账号存在但密码错误
            print("❌ 密码错误: \(error)")
            errorMessage = "密码错误"
        }

        isLoading = false
    }

    /// 检查邮箱是否存在
    /// - Parameter email: 邮箱地址
    /// - Returns: 是否存在
    private func checkEmailExists(email: String) async -> Bool {
        struct CheckEmailRequest: Encodable {
            let email: String
        }

        struct CheckEmailResponse: Decodable {
            let exists: Bool
            let error: String?
        }

        do {
            let response: CheckEmailResponse = try await supabase.functions.invoke(
                "check-email-exists",
                options: FunctionInvokeOptions(
                    method: .post,
                    body: CheckEmailRequest(email: email)
                )
            )
            print("🔵 邮箱检查结果: exists = \(response.exists)")
            return response.exists
        } catch {
            print("❌ 检查邮箱失败（EF错误），默认允许继续注册: \(error)")
            return false
        }
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

    // MARK: - Apple 登录

    func signInWithApple() async {
        print("🍎 开始 Apple 登录流程")
        isLoading = true
        errorMessage = nil

        do {
            let (idToken, nonce) = try await requestAppleCredential()

            let session = try await supabase.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )

            currentUser = session.user
            isAuthenticated = true

            let userId = session.user.id.uuidString
            UserDefaults.standard.set(true, forKey: "registration_completed_\(userId)")

            print("✅ Apple 登录完成，用户 ID: \(userId)")

        } catch let error as ASAuthorizationError where error.code == .canceled {
            print("⚠️ 用户取消了 Apple 登录")
            // 取消不显示错误提示
        } catch {
            print("❌ Apple 登录失败: \(error)")
            errorMessage = handleAuthError(error)
        }

        isLoading = false
    }

    // 发起 Apple 凭证请求，返回 idToken 和原始 nonce
    private func requestAppleCredential() async throws -> (idToken: String, nonce: String) {
        let rawNonce = randomNonceString()
        let hashedNonce = sha256(rawNonce)

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce

        return try await withCheckedThrowingContinuation { continuation in
            let coordinator = AppleSignInCoordinator(nonce: rawNonce, continuation: continuation)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = coordinator
            controller.presentationContextProvider = coordinator
            controller.performRequests()
            // 用关联对象保活 coordinator，直到回调完成
            objc_setAssociatedObject(controller, &AppleSignInCoordinator.associatedKey,
                                     coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
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
        } catch {
            print("❌ 退出登录失败: \(error)")
        }

        // 无论 signOut 是否成功都重置本地状态
        isAuthenticated = false
        needsPasswordSetup = false
        currentUser = nil
        resetFlowState()
        isLoading = false
        print("✅ 已退出登录")

        isLoading = false
    }

    /// 删除账户
    /// 调用边缘函数删除用户账户及所有相关数据
    func deleteAccount() async -> Bool {
        print("🗑️ 开始删除账户流程")

        guard let user = currentUser else {
            print("❌ 删除失败：用户未登录")
            errorMessage = "未登录"
            return false
        }

        print("🔵 当前用户 ID: \(user.id.uuidString)")
        isLoading = true
        errorMessage = nil

        // 定义响应结构
        struct DeleteResponse: Decodable {
            let success: Bool?
            let error: String?
            let message: String?
        }

        do {
            // 获取当前会话的 access token
            print("🔵 获取会话 token...")
            let session = try await supabase.auth.session
            print("🔵 Token 获取成功，长度: \(session.accessToken.count)")

            // 调用删除账户的边缘函数
            print("🔵 调用边缘函数 delete-account...")
            print("🔵 使用的 Token: \(session.accessToken.prefix(30))...")

            let deleteResponse: DeleteResponse = try await supabase.functions.invoke(
                "delete-account",
                options: FunctionInvokeOptions(
                    method: .post,
                    headers: ["Authorization": "Bearer \(session.accessToken)"]
                )
            )

            print("📦 删除账户响应: success=\(deleteResponse.success ?? false), error=\(deleteResponse.error ?? "无"), message=\(deleteResponse.message ?? "无")")

            if let error = deleteResponse.error {
                print("❌ 边缘函数返回错误: \(error)")
                errorMessage = error
                isLoading = false
                return false
            }

            if deleteResponse.success == true {
                print("✅ 边缘函数确认删除成功")
            } else {
                print("❌ 删除未成功，success 不为 true")
                errorMessage = "删除账户失败"
                isLoading = false
                return false
            }

            // 清除本地存储的注册完成标记
            let userId = user.id.uuidString
            UserDefaults.standard.removeObject(forKey: "registration_completed_\(userId)")
            print("🔵 已清除本地注册标记")

            // 退出 Supabase 会话
            try await supabase.auth.signOut()
            print("🔵 已退出 Supabase 会话")

            // 重置所有状态，触发页面跳转
            print("🔵 重置认证状态...")
            isLoading = false
            currentUser = nil
            needsPasswordSetup = false
            resetFlowState()
            isAuthenticated = false  // 最后设置，触发 App 切换到登录页面

            print("✅ 账户删除完成，isAuthenticated = \(isAuthenticated)")
            return true

        } catch {
            print("❌ 删除账户异常: \(error)")
            print("❌ 错误类型: \(type(of: error))")
            errorMessage = "删除账户失败: \(error.localizedDescription)"
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

// MARK: - Apple 登录协调器

private class AppleSignInCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    static var associatedKey: UInt8 = 0

    private let nonce: String
    private let continuation: CheckedContinuation<(idToken: String, nonce: String), Error>

    init(nonce: String, continuation: CheckedContinuation<(idToken: String, nonce: String), Error>) {
        self.nonce = nonce
        self.continuation = continuation
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }

    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithAuthorization authorization: ASAuthorization) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            continuation.resume(throwing: ASAuthorizationError(.failed))
            return
        }
        continuation.resume(returning: (idToken: idToken, nonce: nonce))
    }

    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithError error: Error) {
        continuation.resume(throwing: error)
    }
}
