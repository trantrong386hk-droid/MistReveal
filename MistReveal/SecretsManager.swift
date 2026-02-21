import Foundation

/// Backward-compat placeholder for legacy project references.
/// Secret values are handled by Supabase Edge Functions, not in-app.
enum SecretsManager {
    static func get(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key]
    }
}
