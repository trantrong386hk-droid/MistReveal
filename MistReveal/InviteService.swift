import Foundation
import Supabase

/// 邀请服务 - 处理邀请码/链接的生成和验证
@MainActor
class InviteService: ObservableObject {

    static let shared = InviteService()

    // MARK: - 发布属性

    @Published var myInviteCode: String?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - 数据模型

    struct ReferralRecord: Codable {
        let id: String?
        let referrerId: String
        let inviteeId: String?
        let inviteCode: String
        var rewarded: Bool
        let createdAt: String?

        enum CodingKeys: String, CodingKey {
            case id
            case referrerId = "referrer_id"
            case inviteeId = "invitee_id"
            case inviteCode = "invite_code"
            case rewarded
            case createdAt = "created_at"
        }
    }

    // MARK: - 初始化

    private init() {}

    // MARK: - 邀请码管理

    /// 获取或生成当前用户的邀请码
    func getOrCreateInviteCode() async -> String? {
        guard let userId = await getCurrentUserId() else {
            print("⚠️ [InviteService] 用户未登录")
            return nil
        }

        isLoading = true
        errorMessage = nil

        do {
            // 检查是否已有邀请码
            let response: [ReferralRecord] = try await supabase
                .from("referral_records")
                .select()
                .eq("referrer_id", value: userId)
                .is("invitee_id", value: nil)  // 尚未被使用的邀请记录
                .execute()
                .value

            if let existingRecord = response.first {
                myInviteCode = existingRecord.inviteCode
                isLoading = false
                return existingRecord.inviteCode
            }

            // 生成新的邀请码
            let newCode = generateInviteCode()
            let newRecord = ReferralRecord(
                id: nil,
                referrerId: userId,
                inviteeId: nil,
                inviteCode: newCode,
                rewarded: false,
                createdAt: nil
            )

            try await supabase
                .from("referral_records")
                .insert(newRecord)
                .execute()

            myInviteCode = newCode
            isLoading = false
            print("✅ [InviteService] 生成新邀请码: \(newCode)")
            return newCode

        } catch {
            print("❌ [InviteService] 获取/生成邀请码失败: \(error)")
            errorMessage = "生成邀请码失败"
            isLoading = false
            return nil
        }
    }

    /// 生成6位邀请码
    private func generateInviteCode() -> String {
        let characters = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"  // 去掉容易混淆的字符
        return String((0..<6).map { _ in characters.randomElement()! })
    }

    /// 生成邀请链接
    func generateInviteLink() async -> String? {
        guard let code = await getOrCreateInviteCode() else {
            return nil
        }
        // TODO: 替换为你的 Universal Link 域名
        return "https://mistreveal.app/invite?code=\(code)"
    }

    // MARK: - 验证邀请码

    /// 验证并使用邀请码（被邀请人注册时调用）
    func redeemInviteCode(_ code: String) async -> RedeemResult {
        guard let inviteeId = await getCurrentUserId() else {
            return .error("用户未登录")
        }

        do {
            // 查找邀请记录
            let response: [ReferralRecord] = try await supabase
                .from("referral_records")
                .select()
                .eq("invite_code", value: code.uppercased())
                .is("invitee_id", value: nil)  // 尚未被使用
                .execute()
                .value

            guard let record = response.first else {
                return .error("邀请码无效或已被使用")
            }

            // 不能使用自己的邀请码
            if record.referrerId == inviteeId {
                return .error("不能使用自己的邀请码")
            }

            // 更新邀请记录，绑定被邀请人
            try await supabase
                .from("referral_records")
                .update(["invitee_id": inviteeId])
                .eq("id", value: record.id ?? "")
                .execute()

            // 为被邀请人立即增加配额（注册时给）
            _ = await QuotaManager.shared.addReferralQuota(forUserId: inviteeId)

            print("✅ [InviteService] 邀请码兑换成功，邀请人: \(record.referrerId)")
            return .success(referrerId: record.referrerId)

        } catch {
            print("❌ [InviteService] 兑换邀请码失败: \(error)")
            return .error("兑换失败，请重试")
        }
    }

    /// 触发邀请人奖励（被邀请人完成首次生成后调用）
    func triggerReferrerReward(forInviteeId inviteeId: String) async {
        do {
            // 查找该被邀请人对应的邀请记录
            let response: [ReferralRecord] = try await supabase
                .from("referral_records")
                .select()
                .eq("invitee_id", value: inviteeId)
                .eq("rewarded", value: false)
                .execute()
                .value

            guard let record = response.first else {
                print("ℹ️ [InviteService] 没有找到待奖励的邀请记录")
                return
            }

            // 为邀请人增加配额
            let success = await QuotaManager.shared.addReferralQuota(forUserId: record.referrerId)

            if success {
                // 标记为已奖励
                try await supabase
                    .from("referral_records")
                    .update(["rewarded": true])
                    .eq("id", value: record.id ?? "")
                    .execute()

                print("✅ [InviteService] 邀请人 \(record.referrerId) 获得奖励")
            }

        } catch {
            print("❌ [InviteService] 触发邀请人奖励失败: \(error)")
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

    // MARK: - 结果类型

    enum RedeemResult {
        case success(referrerId: String)
        case error(String)
    }
}
