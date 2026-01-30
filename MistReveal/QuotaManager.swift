import Foundation
import Supabase

/// 用户生成配额管理器
@MainActor
class QuotaManager: ObservableObject {

    static let shared = QuotaManager()

    // MARK: - 发布属性

    @Published var quota: UserQuota?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - 数据模型

    struct UserQuota: Codable {
        let userId: String
        var freeQuotaUsed: Bool
        var referralQuota: Int
        let createdAt: String?
        let updatedAt: String?

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case freeQuotaUsed = "free_quota_used"
            case referralQuota = "referral_quota"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }

        /// 是否可以生成
        var canGenerate: Bool {
            return !freeQuotaUsed || referralQuota > 0
        }

        /// 剩余总次数
        var totalRemaining: Int {
            let freeCount = freeQuotaUsed ? 0 : 1
            return freeCount + referralQuota
        }
    }

    /// 更新免费配额的结构体
    private struct FreeQuotaUpdate: Encodable {
        let freeQuotaUsed: Bool
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case freeQuotaUsed = "free_quota_used"
            case updatedAt = "updated_at"
        }
    }

    /// 更新邀请配额的结构体
    private struct ReferralQuotaUpdate: Encodable {
        let referralQuota: Int
        let updatedAt: String

        enum CodingKeys: String, CodingKey {
            case referralQuota = "referral_quota"
            case updatedAt = "updated_at"
        }
    }

    // MARK: - Supabase 客户端

    private var supabase: SupabaseClient {
        SupabaseClient(
            supabaseURL: URL(string: "https://zbsqbarlzzqhhdcroxsp.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpic3FiYXJsenpxaGhkY3JveHNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjczNDkxMjAsImV4cCI6MjA4MjkyNTEyMH0.7NbknaHqgs-6W0xOCgb5rtGHBRcSy51dKOSSt5SboSc"
        )
    }

    // MARK: - 初始化

    private init() {}

    // MARK: - 公开方法

    /// 获取当前用户的配额
    func fetchQuota() async {
        guard let userId = await getCurrentUserId() else {
            print("⚠️ [QuotaManager] 用户未登录")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 尝试获取现有配额
            let response: [UserQuota] = try await supabase
                .from("user_quota")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            if let existingQuota = response.first {
                quota = existingQuota
                print("✅ [QuotaManager] 获取配额成功: \(existingQuota)")
            } else {
                // 新用户，创建配额记录
                let newQuota = await createQuotaForNewUser(userId: userId)
                quota = newQuota
            }
        } catch {
            print("❌ [QuotaManager] 获取配额失败: \(error)")
            errorMessage = "获取配额失败"
        }

        isLoading = false
    }

    /// 为新用户创建配额记录
    private func createQuotaForNewUser(userId: String) async -> UserQuota? {
        do {
            let newQuota = UserQuota(
                userId: userId,
                freeQuotaUsed: false,
                referralQuota: 0,
                createdAt: nil,
                updatedAt: nil
            )

            try await supabase
                .from("user_quota")
                .insert(newQuota)
                .execute()

            print("✅ [QuotaManager] 为新用户创建配额成功")
            return newQuota
        } catch {
            print("❌ [QuotaManager] 创建配额失败: \(error)")
            return nil
        }
    }

    /// 检查是否可以生成
    func canGenerate() -> Bool {
        return quota?.canGenerate ?? false
    }

    /// 消耗一次生成配额
    func consumeQuota() async -> Bool {
        guard let userId = await getCurrentUserId() else {
            print("⚠️ [QuotaManager] 用户未登录")
            return false
        }

        guard var currentQuota = quota, currentQuota.canGenerate else {
            print("⚠️ [QuotaManager] 没有可用配额")
            return false
        }

        do {
            let now = ISO8601DateFormatter().string(from: Date())

            // 优先使用免费配额
            if !currentQuota.freeQuotaUsed {
                currentQuota.freeQuotaUsed = true
                let update = FreeQuotaUpdate(freeQuotaUsed: true, updatedAt: now)
                try await supabase
                    .from("user_quota")
                    .update(update)
                    .eq("user_id", value: userId)
                    .execute()
                print("✅ [QuotaManager] 消耗免费配额")
            } else if currentQuota.referralQuota > 0 {
                // 使用邀请配额
                currentQuota.referralQuota -= 1
                let update = ReferralQuotaUpdate(referralQuota: currentQuota.referralQuota, updatedAt: now)
                try await supabase
                    .from("user_quota")
                    .update(update)
                    .eq("user_id", value: userId)
                    .execute()
                print("✅ [QuotaManager] 消耗邀请配额，剩余: \(currentQuota.referralQuota)")
            }

            quota = currentQuota
            return true
        } catch {
            print("❌ [QuotaManager] 消耗配额失败: \(error)")
            return false
        }
    }

    /// 增加邀请配额（当被邀请人完成首次生成后调用）
    func addReferralQuota(forUserId userId: String) async -> Bool {
        do {
            // 先获取当前配额
            let response: [UserQuota] = try await supabase
                .from("user_quota")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value

            guard let existingQuota = response.first else {
                print("⚠️ [QuotaManager] 用户配额不存在")
                return false
            }

            let newReferralQuota = existingQuota.referralQuota + 1
            let now = ISO8601DateFormatter().string(from: Date())
            let update = ReferralQuotaUpdate(referralQuota: newReferralQuota, updatedAt: now)

            try await supabase
                .from("user_quota")
                .update(update)
                .eq("user_id", value: userId)
                .execute()

            print("✅ [QuotaManager] 为用户 \(userId) 增加邀请配额，当前: \(newReferralQuota)")

            // 如果是当前用户，更新本地状态
            if userId == (await getCurrentUserId()) {
                var updatedQuota = existingQuota
                updatedQuota.referralQuota = newReferralQuota
                quota = updatedQuota
            }

            return true
        } catch {
            print("❌ [QuotaManager] 增加配额失败: \(error)")
            return false
        }
    }

    // MARK: - 辅助方法

    private func getCurrentUserId() async -> String? {
        do {
            let session = try await supabase.auth.session
            return session.user.id.uuidString
        } catch {
            return nil
        }
    }
}
