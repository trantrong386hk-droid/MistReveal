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
        var friendAnalysesUsed: Int
        let createdAt: String?
        let updatedAt: String?

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case freeQuotaUsed = "free_quota_used"
            case referralQuota = "referral_quota"
            case friendAnalysesUsed = "friend_analyses_used"
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

        /// 是否可以帮朋友分析（限 2 次）
        var canAnalyzeFriend: Bool { friendAnalysesUsed < 2 }

        /// 帮朋友分析的剩余次数
        var friendAnalysesRemaining: Int { max(0, 2 - friendAnalysesUsed) }
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
                friendAnalysesUsed: 0,
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

    /// 消耗一次生成配额（原子 RPC，避免 TOCTOU 竞态）
    func consumeQuota() async -> Bool {
        do {
            let result: Bool = try await supabase
                .rpc("consume_quota")
                .execute()
                .value
            if result {
                await fetchQuota()  // 成功后刷新本地缓存
            }
            print(result
                ? "✅ [QuotaManager] 配额扣减成功"
                : "⚠️ [QuotaManager] 没有可用配额")
            return result
        } catch {
            print("❌ [QuotaManager] 配额扣减失败: \(error)")
            return false
        }
    }

    /// 消耗一次帮朋友分析的配额（原子 RPC，上限 2 次）
    func consumeFriendQuota() async -> Bool {
        do {
            let result: Bool = try await supabase
                .rpc("consume_friend_quota")
                .execute()
                .value
            if result {
                await fetchQuota()  // 成功后刷新本地缓存
            }
            print(result
                ? "✅ [QuotaManager] 朋友配额扣减成功"
                : "⚠️ [QuotaManager] 朋友配额已用完")
            return result
        } catch {
            print("❌ [QuotaManager] 朋友配额扣减失败: \(error)")
            return false
        }
    }

    /// 增加邀请配额（原子 RPC，避免并发覆盖）
    func addReferralQuota(forUserId userId: String) async -> Bool {
        do {
            let result: Bool = try await supabase
                .rpc("add_referral_quota", params: ["p_user_id": userId])
                .execute()
                .value
            if result {
                // 如果是当前用户，刷新本地缓存
                if userId == (await getCurrentUserId()) {
                    await fetchQuota()
                }
                print("✅ [QuotaManager] 为用户 \(userId) 增加邀请配额")
            } else {
                print("⚠️ [QuotaManager] 用户配额记录不存在: \(userId)")
            }
            return result
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
