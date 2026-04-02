import SwiftUI

@main
struct MistRevealApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var languageManager = LanguageManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    // 已登录：显示主页面
                    MainTabView()
                } else if authManager.needsPasswordSetup {
                    // OTP已验证但需要设置密码：显示认证页面
                    AuthView()
                } else {
                    // 未登录：显示认证页面
                    AuthView()
                }
            }
            // 语言切换后强制重建整个视图树，让所有 Text(LocalizedStringKey) 重新查询 Bundle
            .id(languageManager.refreshID)
            .environmentObject(authManager)
            .environmentObject(languageManager)
            .onOpenURL { url in
                print("🔵 App 收到 URL 回调: \(url)")
                // 处理 Google 登录回调
                if authManager.handleGoogleSignInURL(url) {
                    print("✅ Google 回调处理成功")
                }
            }
        }
    }
}
