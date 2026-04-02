import Foundation
import SwiftUI

// MARK: - LanguageManager
// 通过 SwiftUI Environment(\.locale) 实现进程内即时语言切换
// iOS 17+ 的 Text(LocalizedStringKey) 走 CF 层，ObjC Bundle swizzle 已失效
// 正确方案：.environment(\.locale, currentLocale) + .id(refreshID) 强制重建视图树

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

        var locale: Locale {
            switch self {
            case .system:  return Locale.current
            case .zhHans:  return Locale(identifier: "zh-Hans")
            case .english: return Locale(identifier: "en")
            }
        }
    }

    /// 当前语言选择
    @Published private(set) var currentLanguage: AppLanguage

    /// 每次切换语言时更新，用于 .id(refreshID) 强制重建视图树
    @Published private(set) var refreshID: UUID = UUID()

    /// 当前对应的 Locale，注入到 Environment(\.locale)
    var currentLocale: Locale {
        currentLanguage.locale
    }

    private let storageKey = "app_language"

    private init() {
        let saved = UserDefaults.standard.string(forKey: storageKey) ?? AppLanguage.system.rawValue
        currentLanguage = AppLanguage(rawValue: saved) ?? .system
    }

    func setLanguage(_ language: AppLanguage) {
        guard language != currentLanguage else { return }
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: storageKey)
        refreshID = UUID()
    }
}
