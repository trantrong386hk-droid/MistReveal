import Foundation
import Supabase

/// API 密钥管理器 - 从 Supabase 安全获取密钥
@MainActor
class SecretsManager: ObservableObject {

    static let shared = SecretsManager()

    // 缓存的密钥
    private var cachedSecrets: [String: String] = [:]
    private var isFetched = false

    private init() {}

    // MARK: - 密钥访问

    /// 火山引擎 Access Key ID
    var volcanoAccessKeyId: String? {
        cachedSecrets["VOLCANO_ACCESS_KEY_ID"]
    }

    /// 火山引擎 Secret Access Key
    var volcanoSecretAccessKey: String? {
        cachedSecrets["VOLCANO_SECRET_ACCESS_KEY"]
    }

    /// 阿里云百炼 API Key
    var aliyunBailianApiKey: String? {
        cachedSecrets["ALIYUN_BAILIAN_API_KEY"]
    }

    // MARK: - 获取密钥

    /// 从 Supabase 获取所有密钥
    func fetchSecrets() async {
        guard !isFetched else { return }

        do {
            let records: [SecretRecord] = try await supabase
                .from("app_secrets")
                .select("key_name, key_value")
                .execute()
                .value

            for record in records {
                cachedSecrets[record.keyName] = record.keyValue
            }

            isFetched = true
            print("✅ [SecretsManager] 成功获取 \(records.count) 个密钥")
        } catch {
            print("❌ [SecretsManager] 获取密钥失败: \(error)")
        }
    }

    /// 获取指定密钥
    func getSecret(_ keyName: String) async -> String? {
        if !isFetched {
            await fetchSecrets()
        }
        return cachedSecrets[keyName]
    }

    // MARK: - 数据模型

    private struct SecretRecord: Codable {
        let keyName: String
        let keyValue: String

        enum CodingKeys: String, CodingKey {
            case keyName = "key_name"
            case keyValue = "key_value"
        }
    }
}
