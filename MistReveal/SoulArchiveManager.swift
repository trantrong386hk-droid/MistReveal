import Foundation
import Supabase

/// 灵魂档案管理器 - 处理分析结果的存储和读取
@MainActor
class SoulArchiveManager: ObservableObject {

    static let shared = SoulArchiveManager()

    // MARK: - 发布属性

    @Published var myRecord: UserGenerationRecord?      // 我自己的最新记录（向后兼容）
    @Published var myRecords: [UserGenerationRecord] = []   // 所有 is_self 记录
    @Published var friendRecords: [UserGenerationRecord] = []  // 帮朋友测的记录
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - 数据模型

    /// 数据库存储的分析记录
    struct SoulAnalysisDBRecord: Codable {
        let id: String?
        let userId: String?
        let birthKey: String
        let gender: String
        let birthDate: String
        let birthTime: String
        let location: String
        let analysisResult: SoulAnalysisResult
        let imageUrl: String?
        let createdAt: String?
        let updatedAt: String?

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case birthKey = "birth_key"
            case gender
            case birthDate = "birth_date"
            case birthTime = "birth_time"
            case location
            case analysisResult = "analysis_result"
            case imageUrl = "image_url"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    /// 用户生成历史记录
    struct UserGenerationDBRecord: Codable {
        let id: String?
        let userId: String
        let recordId: String
        let nickname: String
        let isSelf: Bool
        let createdAt: String?

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case recordId = "record_id"
            case nickname
            case isSelf = "is_self"
            case createdAt = "created_at"
        }
    }

    /// 用于展示的完整记录
    struct UserGenerationRecord: Identifiable {
        let id: String
        let nickname: String
        let isSelf: Bool
        let gender: String
        let birthDate: Date
        let birthTime: String
        let location: String
        let analysisResult: SoulAnalysisResult
        let imageUrl: String?
        let createdAt: Date
    }

    // MARK: - 初始化

    private init() {}

    // MARK: - 公开方法

    /// 生成 birth_key
    static func generateBirthKey(gender: String, birthDate: Date, birthTime: String, location: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: birthDate)
        let normalizedLocation = location.trimmingCharacters(in: .whitespaces).lowercased()
        return "\(gender)_\(dateStr)_\(birthTime)_\(normalizedLocation)"
    }

    /// 查询是否已有分析记录
    func checkExistingRecord(gender: String, birthDate: Date, birthTime: String, location: String) async -> SoulAnalysisResult? {
        guard let userId = await getCurrentUserId() else { return nil }
        let birthKey = Self.generateBirthKey(gender: gender, birthDate: birthDate, birthTime: birthTime, location: location)

        do {
            let response: [SoulAnalysisDBRecord] = try await supabase
                .from("soul_analysis_records")
                .select()
                .eq("user_id", value: userId)
                .eq("birth_key", value: birthKey)
                .execute()
                .value

            if let record = response.first {
                print("✅ [SoulArchiveManager] 找到已有记录: \(birthKey)")
                return record.analysisResult
            }
            return nil
        } catch {
            print("❌ [SoulArchiveManager] 查询记录失败: \(error)")
            return nil
        }
    }

    /// 保存分析结果到数据库
    func saveAnalysisResult(
        gender: String,
        birthDate: Date,
        birthTime: String,
        location: String,
        analysisResult: SoulAnalysisResult,
        nickname: String = "我自己",
        isSelf: Bool = true
    ) async -> Bool {
        guard let userId = await getCurrentUserId() else {
            print("⚠️ [SoulArchiveManager] 用户未登录")
            return false
        }

        let birthKey = Self.generateBirthKey(gender: gender, birthDate: birthDate, birthTime: birthTime, location: location)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: birthDate)

        do {

            // 1. 先尝试插入或获取 soul_analysis_records
            var recordId: String

            // 检查是否已存在
            let existingRecords: [SoulAnalysisDBRecord] = try await supabase
                .from("soul_analysis_records")
                .select()
                .eq("user_id", value: userId)
                .eq("birth_key", value: birthKey)
                .execute()
                .value

            if let existing = existingRecords.first, let id = existing.id {
                recordId = id
                // 更新分析结果（用户重新分析可能得到新结果）
                struct AnalysisUpdate: Codable {
                    let analysisResult: SoulAnalysisResult
                    let updatedAt: String
                    enum CodingKeys: String, CodingKey {
                        case analysisResult = "analysis_result"
                        case updatedAt = "updated_at"
                    }
                }
                try await supabase
                    .from("soul_analysis_records")
                    .update(AnalysisUpdate(
                        analysisResult: analysisResult,
                        updatedAt: ISO8601DateFormatter().string(from: Date())
                    ))
                    .eq("id", value: id)
                    .execute()
                print("✅ [SoulArchiveManager] 更新已有记录: \(recordId)")
            } else {
                // 插入新记录
                let newRecord = SoulAnalysisDBRecord(
                    id: nil,
                    userId: userId,
                    birthKey: birthKey,
                    gender: gender,
                    birthDate: dateStr,
                    birthTime: birthTime,
                    location: location,
                    analysisResult: analysisResult,
                    imageUrl: nil,
                    createdAt: nil,
                    updatedAt: nil
                )

                let insertedRecords: [SoulAnalysisDBRecord] = try await supabase
                    .from("soul_analysis_records")
                    .insert(newRecord)
                    .select()
                    .execute()
                    .value

                guard let inserted = insertedRecords.first, let id = inserted.id else {
                    print("❌ [SoulArchiveManager] 插入记录失败")
                    return false
                }
                recordId = id
                print("✅ [SoulArchiveManager] 创建新记录: \(recordId)")
            }

            // 2. 插入用户生成历史
            let userGeneration = UserGenerationDBRecord(
                id: nil,
                userId: userId,
                recordId: recordId,
                nickname: nickname,
                isSelf: isSelf,
                createdAt: nil
            )

            try await supabase
                .from("user_generations")
                .insert(userGeneration)
                .execute()

            print("✅ [SoulArchiveManager] 添加用户历史记录")

            // 刷新本地数据
            await fetchUserRecords()
            return true

        } catch {
            print("❌ [SoulArchiveManager] 保存失败: \(error)")
            return false
        }
    }

    /// 更新图片URL
    func updateImageUrl(gender: String, birthDate: Date, birthTime: String, location: String, imageUrl: String) async {
        guard let userId = await getCurrentUserId() else { return }
        let birthKey = Self.generateBirthKey(gender: gender, birthDate: birthDate, birthTime: birthTime, location: location)

        do {
            try await supabase
                .from("soul_analysis_records")
                .update(["image_url": imageUrl, "updated_at": ISO8601DateFormatter().string(from: Date())])
                .eq("user_id", value: userId)
                .eq("birth_key", value: birthKey)
                .execute()

            print("✅ [SoulArchiveManager] 更新图片URL成功")
            await fetchUserRecords()
        } catch {
            print("❌ [SoulArchiveManager] 更新图片URL失败: \(error)")
        }
    }

    /// 获取用户的所有生成记录
    func fetchUserRecords() async {
        guard let userId = await getCurrentUserId() else {
            print("⚠️ [SoulArchiveManager] 用户未登录")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 先加载该用户的所有 generated_portraits（作为 image_url 备援）
            struct GeneratedPortraitRow: Decodable {
                let imageUrl: String
                let birthDate: String
                let gender: String
                let birthTime: String
                let birthLocation: String
                enum CodingKeys: String, CodingKey {
                    case imageUrl = "image_url"
                    case birthDate = "birth_date"
                    case gender
                    case birthTime = "birth_time"
                    case birthLocation = "birth_location"
                }
            }
            let portraits: [GeneratedPortraitRow] = try await supabase
                .from("generated_portraits")
                .select("image_url,birth_date,gender,birth_time,birth_location")
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            // key format mirrors generateBirthKey: "gender_yyyy-MM-dd_birthTime_location"
            let portraitUrlByKey: [String: String] = Dictionary(
                portraits.compactMap { p -> (String, String)? in
                    let key = "\(p.gender)_\(p.birthDate)_\(p.birthTime)_\(p.birthLocation.trimmingCharacters(in: .whitespaces).lowercased())"
                    return (key, p.imageUrl)
                },
                uniquingKeysWith: { first, _ in first }  // 取最新（已按 created_at desc 排序）
            )

            // 获取用户的生成历史
            let generations: [UserGenerationDBRecord] = try await supabase
                .from("user_generations")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value

            // 同时拉取该用户所有 soul_analysis_records（用于后续缺漏补偿）
            let allSoulRecords: [SoulAnalysisDBRecord] = try await supabase
                .from("soul_analysis_records")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            let soulRecordsById: [String: SoulAnalysisDBRecord] = Dictionary(
                allSoulRecords.compactMap { r in r.id.map { ($0, r) } },
                uniquingKeysWith: { first, _ in first }
            )

            var myRecordTemp: UserGenerationRecord?
            var myRecordsTemp: [UserGenerationRecord] = []
            var friendRecordsTemp: [UserGenerationRecord] = []
            var coveredRecordIds = Set<String>()

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let createdAtFormatter = ISO8601DateFormatter()

            for generation in generations {
                coveredRecordIds.insert(generation.recordId)

                guard let record = soulRecordsById[generation.recordId] else { continue }

                let birthDate = dateFormatter.date(from: record.birthDate) ?? Date()
                let createdAt = createdAtFormatter.date(from: generation.createdAt ?? "") ?? Date()

                let fallbackKey = "\(record.gender)_\(record.birthDate)_\(record.birthTime)_\(record.location.trimmingCharacters(in: .whitespaces).lowercased())"
                let resolvedImageUrl = record.imageUrl ?? portraitUrlByKey[fallbackKey]

                let userRecord = UserGenerationRecord(
                    id: generation.id ?? UUID().uuidString,
                    nickname: generation.nickname,
                    isSelf: generation.isSelf,
                    gender: record.gender,
                    birthDate: birthDate,
                    birthTime: record.birthTime,
                    location: record.location,
                    analysisResult: record.analysisResult,
                    imageUrl: resolvedImageUrl,
                    createdAt: createdAt
                )

                if generation.isSelf {
                    if myRecordTemp == nil { myRecordTemp = userRecord }  // 最新一条（向后兼容）
                    myRecordsTemp.append(userRecord)
                } else {
                    friendRecordsTemp.append(userRecord)
                }
            }

            // 补偿：soul_analysis_records 存在但 user_generations 写入失败的自我记录
            // 条件：有对应的 generated_portraits（即确实生成过画像），才补入档案
            for record in allSoulRecords {
                guard let recordId = record.id, !coveredRecordIds.contains(recordId) else { continue }
                let fallbackKey = "\(record.gender)_\(record.birthDate)_\(record.birthTime)_\(record.location.trimmingCharacters(in: .whitespaces).lowercased())"
                guard let imageUrl = record.imageUrl ?? portraitUrlByKey[fallbackKey] else { continue }

                let birthDate = dateFormatter.date(from: record.birthDate) ?? Date()
                let createdAt = createdAtFormatter.date(from: record.createdAt ?? "") ?? Date()

                let userRecord = UserGenerationRecord(
                    id: recordId,
                    nickname: "我自己",
                    isSelf: true,
                    gender: record.gender,
                    birthDate: birthDate,
                    birthTime: record.birthTime,
                    location: record.location,
                    analysisResult: record.analysisResult,
                    imageUrl: imageUrl,
                    createdAt: createdAt
                )
                if myRecordTemp == nil { myRecordTemp = userRecord }
                myRecordsTemp.append(userRecord)
                print("🔧 [SoulArchiveManager] 补偿缺漏记录: \(fallbackKey)")
            }

            // 按 createdAt 倒序排列
            myRecordsTemp.sort { $0.createdAt > $1.createdAt }

            myRecord = myRecordTemp ?? myRecordsTemp.first
            myRecords = myRecordsTemp
            friendRecords = friendRecordsTemp

            print("✅ [SoulArchiveManager] 获取记录成功: 我的=\(myRecords.count)条, 朋友=\(friendRecords.count)条")

        } catch {
            print("❌ [SoulArchiveManager] 获取记录失败: \(error)")
            errorMessage = "获取档案失败"
        }

        isLoading = false
    }

    /// 更新记录昵称
    func updateNickname(recordId: String, newNickname: String) async -> Bool {
        do {
            try await supabase
                .from("user_generations")
                .update(["nickname": newNickname])
                .eq("id", value: recordId)
                .execute()

            await fetchUserRecords()
            return true
        } catch {
            print("❌ [SoulArchiveManager] 更新昵称失败: \(error)")
            return false
        }
    }

    /// 删除记录
    func deleteRecord(recordId: String) async -> Bool {
        do {
            try await supabase
                .from("user_generations")
                .delete()
                .eq("id", value: recordId)
                .execute()

            await fetchUserRecords()
            return true
        } catch {
            print("❌ [SoulArchiveManager] 删除记录失败: \(error)")
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
