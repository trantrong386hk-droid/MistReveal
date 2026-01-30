import Foundation
import CoreLocation
import Supabase

/// 缘分匹配服务
@MainActor
class MatchingService: ObservableObject {

    static let shared = MatchingService()

    // MARK: - 发布属性

    @Published var nearbyMatches: [MatchedUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - 数据模型

    /// 匹配到的用户
    struct MatchedUser: Identifiable {
        let id: String
        let nickname: String
        let latitude: Double
        let longitude: Double
        let matchScore: Int          // 匹配度 0-100
        let userElement: String      // 对方的五行
        let personalityTraits: [String]
        let distance: Double         // 距离（公里）

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        /// 判断是否为测试用户
        var isTestUser: Bool {
            id.hasPrefix("test-user-")
        }
    }

    /// 数据库中的用户位置记录
    struct UserLocationRecord: Codable {
        let id: String?
        let userId: String
        let latitude: Double
        let longitude: Double
        let nickname: String
        let userElement: String?
        let soulmateElement: String?
        let personalityTraits: [String]?
        let soulmateTraits: [String]?
        let updatedAt: String?

        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case latitude
            case longitude
            case nickname
            case userElement = "user_element"
            case soulmateElement = "soulmate_element"
            case personalityTraits = "personality_traits"
            case soulmateTraits = "soulmate_traits"
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

    /// 更新用户位置到数据库
    func updateUserLocation(latitude: Double, longitude: Double) async -> Bool {
        guard let userId = await getCurrentUserId() else {
            print("⚠️ [MatchingService] 用户未登录")
            return false
        }

        // 获取用户的灵魂分析结果
        let archiveManager = SoulArchiveManager.shared
        let myRecord = archiveManager.myRecord

        do {
            let record = UserLocationRecord(
                id: nil,
                userId: userId,
                latitude: latitude,
                longitude: longitude,
                nickname: myRecord?.nickname ?? "神秘旅人",
                userElement: myRecord?.analysisResult.userElement,
                soulmateElement: myRecord?.analysisResult.soulmateElement,
                personalityTraits: myRecord?.analysisResult.personalityTraits,
                soulmateTraits: myRecord?.analysisResult.soulmateTraits,
                updatedAt: nil
            )

            // 使用 upsert：如果存在则更新，不存在则插入
            try await supabase
                .from("user_locations")
                .upsert(record, onConflict: "user_id")
                .execute()

            print("✅ [MatchingService] 位置更新成功")
            return true
        } catch {
            print("❌ [MatchingService] 位置更新失败: \(error)")
            return false
        }
    }

    /// 查找附近的匹配用户
    /// - Parameters:
    ///   - center: 中心位置
    ///   - radiusKm: 搜索半径（公里）
    ///   - minMatchScore: 最低匹配度
    func findNearbyMatches(
        center: CLLocationCoordinate2D,
        radiusKm: Double = 50,
        minMatchScore: Int = 60
    ) async {
        guard let userId = await getCurrentUserId() else {
            print("⚠️ [MatchingService] 用户未登录")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            // 计算经纬度范围（粗略筛选）
            let latDelta = radiusKm / 111.0  // 1度纬度约111公里
            let lonDelta = radiusKm / (111.0 * cos(center.latitude * .pi / 180))

            let minLat = center.latitude - latDelta
            let maxLat = center.latitude + latDelta
            let minLon = center.longitude - lonDelta
            let maxLon = center.longitude + lonDelta

            // 查询附近用户（排除自己）
            let records: [UserLocationRecord] = try await supabase
                .from("user_locations")
                .select()
                .neq("user_id", value: userId)
                .gte("latitude", value: minLat)
                .lte("latitude", value: maxLat)
                .gte("longitude", value: minLon)
                .lte("longitude", value: maxLon)
                .execute()
                .value

            print("📍 [MatchingService] 找到 \(records.count) 个附近用户")

            // 获取我的灵魂分析结果
            let archiveManager = SoulArchiveManager.shared
            guard let myRecord = archiveManager.myRecord else {
                print("⚠️ [MatchingService] 没有灵魂分析结果，无法匹配")
                nearbyMatches = []
                isLoading = false
                return
            }

            // 计算匹配度并筛选
            var matches: [MatchedUser] = []

            for record in records {
                // 计算距离
                let distance = calculateDistance(
                    from: center,
                    to: CLLocationCoordinate2D(latitude: record.latitude, longitude: record.longitude)
                )

                // 只保留在半径内的用户
                guard distance <= radiusKm else { continue }

                // 计算匹配度
                let score = calculateMatchScore(
                    myAnalysis: myRecord.analysisResult,
                    otherRecord: record
                )

                // 只保留达到最低匹配度的用户
                guard score >= minMatchScore else { continue }

                let matchedUser = MatchedUser(
                    id: record.userId,
                    nickname: record.nickname,
                    latitude: record.latitude,
                    longitude: record.longitude,
                    matchScore: score,
                    userElement: record.userElement ?? "未知",
                    personalityTraits: record.personalityTraits ?? [],
                    distance: distance
                )

                matches.append(matchedUser)
            }

            // 按匹配度排序
            matches.sort { $0.matchScore > $1.matchScore }

            // 限制返回数量（最多50个），优先显示高匹配度用户
            let limitedMatches = Array(matches.prefix(50))

            nearbyMatches = limitedMatches
            print("💕 [MatchingService] 匹配到 \(matches.count) 个用户，显示 \(limitedMatches.count) 个")

        } catch {
            print("❌ [MatchingService] 查询失败: \(error)")
            errorMessage = "查询附近用户失败"
        }

        isLoading = false
    }

    // MARK: - 匹配算法

    /// 计算匹配度
    private func calculateMatchScore(myAnalysis: SoulAnalysisResult, otherRecord: UserLocationRecord) -> Int {
        var score = 0

        // 1. 五行匹配（30分）
        // 对方的 userElement 是否等于我的 soulmateElement
        if let otherElement = otherRecord.userElement,
           otherElement == myAnalysis.soulmateElement {
            score += 30
            print("   五行匹配: +30 (对方\(otherElement) = 我需要的\(myAnalysis.soulmateElement))")
        } else if let otherElement = otherRecord.userElement {
            // 部分匹配（相生关系）
            if isElementCompatible(myAnalysis.soulmateElement, otherElement) {
                score += 15
            }
        }

        // 2. 性格特质匹配（40分）
        // 对方的 personalityTraits 与我的 soulmateTraits 的重合度
        if let otherTraits = otherRecord.personalityTraits {
            let myWantedTraits = Set(myAnalysis.soulmateTraits)
            let otherTraitsSet = Set(otherTraits)
            let intersection = myWantedTraits.intersection(otherTraitsSet)

            if !myWantedTraits.isEmpty {
                let traitScore = Int(Double(intersection.count) / Double(myWantedTraits.count) * 40)
                score += traitScore
                print("   性格匹配: +\(traitScore) (重合\(intersection.count)个特质)")
            }
        }

        // 3. 互补匹配（20分）
        // 对方的 soulmateElement 是否等于我的 userElement（说明我们互相需要）
        if let otherSoulmateElement = otherRecord.soulmateElement,
           otherSoulmateElement == myAnalysis.userElement {
            score += 20
            print("   互补匹配: +20 (对方也需要\(myAnalysis.userElement)命的人)")
        }

        // 4. 基础分（10分）
        // 只要有完整的分析数据就给基础分
        if otherRecord.userElement != nil && otherRecord.personalityTraits != nil {
            score += 10
        }

        return min(score, 100) // 最高100分
    }

    /// 判断五行是否相容（相生关系）
    private func isElementCompatible(_ element1: String, _ element2: String) -> Bool {
        let compatiblePairs: Set<Set<String>> = [
            ["木", "水"], ["木", "火"],
            ["火", "木"], ["火", "土"],
            ["土", "火"], ["土", "金"],
            ["金", "土"], ["金", "水"],
            ["水", "金"], ["水", "木"]
        ]
        return compatiblePairs.contains([element1, element2])
    }

    /// 计算两点距离（公里）
    private func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation) / 1000.0
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
