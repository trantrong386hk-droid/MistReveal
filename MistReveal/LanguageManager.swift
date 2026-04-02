import Foundation
import SwiftUI

// MARK: - Bundle 运行时替换（让 NSLocalizedString / Text(LocalizedStringKey) 立即生效）

private var bundleAssocKey: UInt8 = 0

/// 替换 Bundle.main 的运行时类，拦截所有 localizedString 查询
final class LanguageBundle: Bundle, @unchecked Sendable {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        guard let path = objc_getAssociatedObject(self, &bundleAssocKey) as? String,
              let langBundle = Bundle(path: path) else {
            // 无自定义路径 → 跟随系统默认行为
            return super.localizedString(forKey: key, value: value, table: tableName)
        }
        return langBundle.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    /// 切换语言包。传 nil 表示跟随系统。
    static func setLanguage(_ code: String?) {
        // 无论是否有 code，都把 Bundle.main 的类换成 LanguageBundle（幂等操作）
        object_setClass(Bundle.main, LanguageBundle.self)

        guard let code else {
            // 系统模式：清除关联对象，localizedString 会 fallthrough 到 super（系统行为）
            objc_setAssociatedObject(Bundle.main, &bundleAssocKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return
        }

        // 找目标语言的 .lproj，找不到降级到 en
        let path = Bundle.main.path(forResource: code, ofType: "lproj")
            ?? Bundle.main.path(forResource: "en", ofType: "lproj")
            ?? ""
        objc_setAssociatedObject(Bundle.main, &bundleAssocKey, path, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

// MARK: - LanguageManager

class LanguageManager: ObservableObject {

    static let shared = LanguageManager()

    enum AppLanguage: String, CaseIterable {
        case system   = "system"
        case zhHans   = "zh-Hans"
        case english  = "en"

        var displayName: String {
            switch self {
            case .system:  return "跟随系统 / Follow System"
            case .zhHans:  return "简体中文"
            case .english: return "English"
            }
        }

        var icon: String {
            switch self {
            case .system:  return "globe"
            case .zhHans:  return "character.bubble"
            case .english: return "a.square"
            }
        }
    }

    /// 当前语言选择
    @Published private(set) var currentLanguage: AppLanguage

    /// 每次切换语言时更新，用于 .id(refreshID) 强制重建视图树
    @Published private(set) var refreshID: UUID = UUID()

    private let storageKey = "app_language"

    private init() {
        let saved = UserDefaults.standard.string(forKey: "app_language") ?? AppLanguage.system.rawValue
        let lang = AppLanguage(rawValue: saved) ?? .system
        currentLanguage = lang
        applyBundle(for: lang)
    }

    func setLanguage(_ language: AppLanguage) {
        guard language != currentLanguage else { return }
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: storageKey)
        applyBundle(for: language)
        // 触发 SwiftUI 根视图重建，所有 Text(LocalizedStringKey) 重新查询
        refreshID = UUID()
    }

    private func applyBundle(for language: AppLanguage) {
        switch language {
        case .system:
            Bundle.setLanguage(nil)
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .zhHans:
            Bundle.setLanguage("zh-Hans")
            UserDefaults.standard.set(["zh-Hans"], forKey: "AppleLanguages")
        case .english:
            Bundle.setLanguage("en")
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
    }
}
