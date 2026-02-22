import Foundation
import Supabase

/// Supabase 数据保存服务
/// 负责保存灵魂档案和生成记录到数据库
@MainActor
class SupabaseSaveService {

    static let shared = SupabaseSaveService()

    private init() {}

    // MARK: - 数据模型

    /// 灵魂档案数据结构
    private struct SoulProfileData: Codable {
        let userId: UUID
        let gender: String
        let birthDate: String
        let birthTime: String
        let birthLocation: String

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case gender
            case birthDate = "birth_date"
            case birthTime = "birth_time"
            case birthLocation = "birth_location"
        }
    }

    /// 画像记录数据结构（prompt 列已停止写入，安全策略：prompt 仅在服务端流转）
    private struct PortraitRecordData: Codable {
        let userId: UUID
        let hexagram: String
        let analysis: String
        let imageUrl: String
        let birthDate: String
        let gender: String
        let birthTime: String
        let birthLocation: String

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case hexagram
            case analysis
            case imageUrl = "image_url"
            case birthDate = "birth_date"
            case gender
            case birthTime = "birth_time"
            case birthLocation = "birth_location"
        }
    }

    // MARK: - 公开方法

    /// 保存完整的推演结果
    /// - Parameters:
    ///   - result: SoulmateManager.SoulmateResult
    ///   - gender: 性别
    ///   - birthTime: 时辰
    ///   - location: 地点
    /// - Returns: (imageUrl, portraitId)
    @discardableResult
    func saveGenerationResult(
        result: SoulmateManager.SoulmateResult,
        gender: String,
        birthTime: String,
        location: String
    ) async throws -> (imageUrl: String, portraitId: UUID) {
        guard let userId = supabase.auth.currentUser?.id else {
            print("❌ [SupabaseSave] 用户未登录")
            throw SaveError.notAuthenticated
        }

        print("💾 [SupabaseSave] 开始保存推演结果")
        print("   - 用户 ID: \(userId)")

        do {
            // 步骤 1: 保存/更新灵魂档案
            try await saveSoulProfile(
                userId: userId,
                gender: gender,
                birthDate: result.birthDate,
                birthTime: birthTime,
                location: location
            )

            // 步骤 2: 上传图片到 Storage
            let imageUrl = try await uploadImageToStorage(
                userId: userId,
                imageData: result.imageData
            )

            // 步骤 3: 保存画像记录，拿到插入后的 ID
            let portraitId = try await savePortraitRecord(
                userId: userId,
                hexagram: result.hexagram,
                analysis: result.analysis,
                imageUrl: imageUrl,
                birthDate: result.birthDate,
                gender: gender,
                birthTime: birthTime,
                location: location
            )

            // 步骤 4：异步写入数字残影位置（不阻塞主流程）
            let capturedUserId = userId
            let capturedLocation = location
            let capturedImageUrl = imageUrl
            Task {
                await upsertShadowLocation(userId: capturedUserId, location: capturedLocation, imageUrl: capturedImageUrl)
            }

            print("✅ [SupabaseSave] 推演结果保存成功")
            return (imageUrl: imageUrl, portraitId: portraitId)

        } catch {
            print("❌ [SupabaseSave] 保存失败: \(error)")
            throw error
        }
    }

    // MARK: - 私有方法

    /// 保存/更新灵魂档案
    private func saveSoulProfile(
        userId: UUID,
        gender: String,
        birthDate: String,
        birthTime: String,
        location: String
    ) async throws {
        print("💾 [SupabaseSave] 保存灵魂档案...")

        // 将 "1990年5月15日" 格式转换为 "1990-05-15"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年M月d日"
        dateFormatter.locale = Locale(identifier: "zh_CN")

        var formattedBirthDate = birthDate
        if let date = dateFormatter.date(from: birthDate) {
            dateFormatter.dateFormat = "yyyy-MM-dd"
            formattedBirthDate = dateFormatter.string(from: date)
        }

        let profileData = SoulProfileData(
            userId: userId,
            gender: gender,
            birthDate: formattedBirthDate,
            birthTime: birthTime,
            birthLocation: location
        )

        // 使用 upsert 操作（如果存在则更新，不存在则插入）
        try await supabase
            .from("soul_profiles")
            .upsert(profileData, onConflict: "user_id")
            .execute()

        print("✅ [SupabaseSave] 灵魂档案保存成功")
    }

    /// 上传图片到 Supabase Storage
    private func uploadImageToStorage(
        userId: UUID,
        imageData: Data
    ) async throws -> String {
        print("💾 [SupabaseSave] 上传图片到 Storage...")

        // 生成唯一文件名
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestampString = formatter.string(from: timestamp)
        let fileName = "\(timestampString).jpg"
        let filePath = "\(userId)/\(fileName)"

        // 上传到 portraits bucket
        try await supabase.storage
            .from("portraits")
            .upload(
                filePath,
                data: imageData,
                options: FileOptions(
                    contentType: "image/jpeg"
                )
            )

        // 获取公开访问 URL
        let publicURL = try supabase.storage
            .from("portraits")
            .getPublicURL(path: filePath)

        print("✅ [SupabaseSave] 图片上传成功")
        print("   - 路径: \(filePath)")
        print("   - URL: \(publicURL)")

        return publicURL.absoluteString
    }

    /// 保存画像记录，返回插入后的 UUID
    private func savePortraitRecord(
        userId: UUID,
        hexagram: String,
        analysis: String,
        imageUrl: String,
        birthDate: String,
        gender: String,
        birthTime: String,
        location: String
    ) async throws -> UUID {
        print("💾 [SupabaseSave] 保存画像记录...")

        // 将 "1990年5月15日" 格式转换为 "1990-05-15"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy年M月d日"
        dateFormatter.locale = Locale(identifier: "zh_CN")

        var formattedBirthDate = birthDate
        if let date = dateFormatter.date(from: birthDate) {
            dateFormatter.dateFormat = "yyyy-MM-dd"
            formattedBirthDate = dateFormatter.string(from: date)
        }

        let recordData = PortraitRecordData(
            userId: userId,
            hexagram: hexagram,
            analysis: analysis,
            imageUrl: imageUrl,
            birthDate: formattedBirthDate,
            gender: gender,
            birthTime: birthTime,
            birthLocation: location
        )

        struct InsertedId: Decodable { let id: UUID }
        let inserted: InsertedId = try await supabase
            .from("generated_portraits")
            .insert(recordData)
            .select("id")
            .single()
            .execute()
            .value

        print("✅ [SupabaseSave] 画像记录保存成功: \(inserted.id)")
        return inserted.id
    }

    // MARK: - 数字残影位置

    /// 生成完成后写入影子位置（如用户尚无真实位置记录）
    private func upsertShadowLocation(userId: UUID, location: String, imageUrl: String) async {
        // 检查是否已有真实位置记录（is_shadow = false）
        struct CheckRecord: Decodable {
            let userId: String
            enum CodingKeys: String, CodingKey { case userId = "user_id" }
        }

        do {
            let existing: [CheckRecord] = try await supabase
                .from("user_locations")
                .select("user_id")
                .eq("user_id", value: userId.uuidString)
                .eq("is_shadow", value: false)
                .execute()
                .value

            if !existing.isEmpty {
                print("ℹ️ [Shadow] 已有真实位置记录，跳过 shadow 写入")
                return
            }
        } catch {
            // 查询失败时继续尝试写入
            print("⚠️ [Shadow] 检查真实位置失败，继续 shadow 写入: \(error)")
        }

        // 使用城市坐标库获取近似坐标
        guard let coord = CityCoordinates.approximate(for: location, userId: userId.uuidString) else {
            print("⚠️ [Shadow] 无法为位置 '\(location)' 找到近似坐标，跳过 shadow 写入")
            return
        }

        // 从灵魂档案获取分析数据
        let archiveManager = SoulArchiveManager.shared
        let myRecord = archiveManager.myRecord
        let analysisSummary: String?
        if let desc = myRecord?.analysisResult.personalityDescription {
            analysisSummary = String(desc.prefix(200))
        } else {
            analysisSummary = nil
        }

        let cityName = CityCoordinates.matchedCityName(for: location)

        let record = MatchingService.UserLocationRecord(
            id: nil,
            userId: userId.uuidString,
            latitude: coord.latitude,
            longitude: coord.longitude,
            nickname: myRecord?.nickname ?? "神秘旅人",
            userElement: myRecord?.analysisResult.userElement,
            soulmateElement: myRecord?.analysisResult.soulmateElement,
            personalityTraits: myRecord?.analysisResult.personalityTraits,
            soulmateTraits: myRecord?.analysisResult.soulmateTraits,
            updatedAt: nil,
            avatarUrl: nil,
            city: cityName,
            isShadow: true,
            analysisSummary: analysisSummary,
            portraitUrl: imageUrl
        )

        do {
            try await supabase
                .from("user_locations")
                .upsert(record, onConflict: "user_id")
                .execute()
            print("✅ [Shadow] 写入影子位置记录成功: \(location) → \(cityName ?? "未知城市")")
        } catch {
            print("❌ [Shadow] 写入影子位置记录失败: \(error)")
        }
    }

    // MARK: - 错误类型

    enum SaveError: LocalizedError {
        case notAuthenticated
        case uploadFailed
        case saveFailed

        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "用户未登录"
            case .uploadFailed:
                return "图片上传失败"
            case .saveFailed:
                return "数据保存失败"
            }
        }
    }
}
