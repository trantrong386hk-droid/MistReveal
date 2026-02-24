import Foundation
import CoreLocation
import Supabase

/// 搜索范围枚举
enum SearchScope {
    case nearby       // 附近 100 km
    case city         // 同城扩展
    case nationwide   // 全国扩展
}

/// 缘分匹配服务
@MainActor
class MatchingService: ObservableObject {

    static let shared = MatchingService()

    // MARK: - 发布属性

    @Published var nearbyMatches: [MatchedUser] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentSearchScope: SearchScope = .nearby
    @Published var myCity: String?

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
        let avatarUrl: String?       // 头像URL
        let city: String?            // 城市名（城市级隐私保护）
        let isShadow: Bool           // 是否为数字残影
        let analysisSummary: String? // 性格描述前 200 字（仅 shadow）
        let portraitUrl: String?     // 命定画像 URL（仅 shadow）

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
        let avatarUrl: String?
        let city: String?
        let isShadow: Bool
        let analysisSummary: String?
        let portraitUrl: String?

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
            case avatarUrl = "avatar_url"
            case city
            case isShadow = "is_shadow"
            case analysisSummary = "analysis_summary"
            case portraitUrl = "portrait_url"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try? c.decodeIfPresent(String.self, forKey: .id)
            userId = try c.decode(String.self, forKey: .userId)
            latitude = try c.decode(Double.self, forKey: .latitude)
            longitude = try c.decode(Double.self, forKey: .longitude)
            nickname = (try? c.decode(String.self, forKey: .nickname)) ?? "神秘旅人"
            userElement = try? c.decodeIfPresent(String.self, forKey: .userElement)
            soulmateElement = try? c.decodeIfPresent(String.self, forKey: .soulmateElement)
            personalityTraits = try? c.decodeIfPresent([String].self, forKey: .personalityTraits)
            soulmateTraits = try? c.decodeIfPresent([String].self, forKey: .soulmateTraits)
            updatedAt = try? c.decodeIfPresent(String.self, forKey: .updatedAt)
            avatarUrl = try? c.decodeIfPresent(String.self, forKey: .avatarUrl)
            city = try? c.decodeIfPresent(String.self, forKey: .city)
            isShadow = (try? c.decode(Bool.self, forKey: .isShadow)) ?? false
            analysisSummary = try? c.decodeIfPresent(String.self, forKey: .analysisSummary)
            portraitUrl = try? c.decodeIfPresent(String.self, forKey: .portraitUrl)
        }

        // Memberwise initializer for construction
        init(id: String?, userId: String, latitude: Double, longitude: Double,
             nickname: String, userElement: String?, soulmateElement: String?,
             personalityTraits: [String]?, soulmateTraits: [String]?,
             updatedAt: String?, avatarUrl: String?, city: String?,
             isShadow: Bool = false, analysisSummary: String? = nil, portraitUrl: String? = nil) {
            self.id = id
            self.userId = userId
            self.latitude = latitude
            self.longitude = longitude
            self.nickname = nickname
            self.userElement = userElement
            self.soulmateElement = soulmateElement
            self.personalityTraits = personalityTraits
            self.soulmateTraits = soulmateTraits
            self.updatedAt = updatedAt
            self.avatarUrl = avatarUrl
            self.city = city
            self.isShadow = isShadow
            self.analysisSummary = analysisSummary
            self.portraitUrl = portraitUrl
        }
    }

    // MARK: - 初始化

    private init() {}

    // MARK: - 公开方法

    /// 更新用户位置到数据库
    /// 优先使用注册城市坐标（确定性抖动），fallback 到 GPS 模糊化
    /// - Returns: 实际写入的坐标（供后续搜索使用），失败返回 nil
    func updateUserLocation(latitude: Double, longitude: Double) async -> CLLocationCoordinate2D? {
        guard let userId = await getCurrentUserId() else {
            print("⚠️ [MatchingService] 用户未登录")
            return nil
        }

        // 获取用户的灵魂分析结果
        let archiveManager = SoulArchiveManager.shared
        let myRecord = archiveManager.activeRecord ?? archiveManager.myRecord

        // ── 坐标计算（不依赖 DB，不会因 RLS 失败）────────────────────────
        let finalLat: Double
        let finalLon: Double
        var cityName: String?

        if let location = myRecord?.location, !location.isEmpty,
           let cityCoord = CityCoordinates.approximate(for: location, userId: userId) {
            // 注册城市路径：确定性坐标 + 直接取城市名（跳过 CLGeocoder）
            finalLat = cityCoord.latitude
            finalLon = cityCoord.longitude
            cityName = CityCoordinates.matchedCityName(for: location)
            print("📍 [MatchingService] 使用注册城市坐标: \(location) → (\(finalLat), \(finalLon))")
        } else {
            // Fallback：GPS 模糊化到 ~11 km 网格 + 反地理编码
            finalLat = (latitude * 10).rounded() / 10
            finalLon = (longitude * 10).rounded() / 10
            let geocoder = CLGeocoder()
            let clLocation = CLLocation(latitude: latitude, longitude: longitude)
            if let placemarks = try? await geocoder.reverseGeocodeLocation(clLocation),
               let placemark = placemarks.first {
                cityName = placemark.locality ?? placemark.administrativeArea
            }
            print("📍 [MatchingService] 注册城市未匹配，使用 GPS fallback: (\(finalLat), \(finalLon))")
        }

        // 保存城市名供后续扩展搜索使用
        myCity = cityName

        // ── DB 写入（失败只打 warning，不影响坐标返回）────────────────────
        let record = UserLocationRecord(
            id: nil,
            userId: userId,
            latitude: finalLat,
            longitude: finalLon,
            nickname: myRecord?.nickname ?? "神秘旅人",
            userElement: myRecord?.analysisResult.userElement,
            soulmateElement: myRecord?.analysisResult.soulmateElement,
            personalityTraits: myRecord?.analysisResult.personalityTraits,
            soulmateTraits: myRecord?.analysisResult.soulmateTraits,
            updatedAt: nil,
            avatarUrl: nil,
            city: cityName,
            isShadow: false,
            analysisSummary: nil,
            portraitUrl: nil
        )
        do {
            // 使用 upsert：如果存在则更新，不存在则插入（is_shadow=false 会将影子记录晋升为真实用户）
            try await supabase
                .from("user_locations")
                .upsert(record, onConflict: "user_id")
                .execute()
            print("✅ [MatchingService] 位置更新成功，城市: \(cityName ?? "未知")")
        } catch {
            print("⚠️ [MatchingService] 位置上传失败（不影响本地搜索）: \(error)")
        }

        return CLLocationCoordinate2D(latitude: finalLat, longitude: finalLon)
    }

    /// 动态半径扩展搜索：near → city → nationwide
    /// 取代 ConnectionView 中固定 500 km 的 findNearbyMatches 调用
    func findMatchesWithExpansion(center: CLLocationCoordinate2D, minMatchScore: Int = 60) async {
        guard let userId = await getCurrentUserId() else {
            print("⚠️ [MatchingService] 用户未登录")
            return
        }

        isLoading = true
        errorMessage = nil

        let archiveManager = SoulArchiveManager.shared
        guard let myRecord = archiveManager.activeRecord ?? archiveManager.myRecord else {
            print("⚠️ [MatchingService] 没有灵魂分析结果，无法匹配")
            nearbyMatches = []
            isLoading = false
            return
        }

        do {
            // 阶段 1：100 km 附近
            let stage1Records = try await queryByRadius(center: center, radiusKm: 100, userId: userId)
            let stage1Matches = buildMatchedUsers(
                from: stage1Records, center: center,
                myAnalysis: myRecord.analysisResult, minMatchScore: minMatchScore, radiusKm: 100
            )
            print("📍 [MatchingService] 阶段1(附近): \(stage1Records.count) 条记录 → \(stage1Matches.count) 个匹配")
            if stage1Matches.count >= 5 {
                currentSearchScope = .nearby
                nearbyMatches = stage1Matches
                isLoading = false
                return
            }

            // 阶段 2：同城
            if let city = myCity, !city.isEmpty {
                let stage2Records = try await queryByCity(city: city, userId: userId)
                let stage2Matches = buildMatchedUsers(
                    from: stage2Records, center: center,
                    myAnalysis: myRecord.analysisResult, minMatchScore: minMatchScore
                )
                print("📍 [MatchingService] 阶段2(同城 \(city)): \(stage2Records.count) 条记录 → \(stage2Matches.count) 个匹配")
                if stage2Matches.count >= 5 {
                    currentSearchScope = .city
                    nearbyMatches = stage2Matches
                    isLoading = false
                    return
                }
            }

            // 阶段 3：全国
            let stage3Records = try await queryNationwide(userId: userId)
            let stage3Matches = buildMatchedUsers(
                from: stage3Records, center: center,
                myAnalysis: myRecord.analysisResult, minMatchScore: minMatchScore
            )
            print("📍 [MatchingService] 阶段3(全国): \(stage3Records.count) 条记录 → \(stage3Matches.count) 个匹配")
            currentSearchScope = .nationwide
            nearbyMatches = stage3Matches

        } catch {
            print("❌ [MatchingService] findMatchesWithExpansion 失败: \(error)")
            errorMessage = "查询附近用户失败"
        }

        isLoading = false
    }

    /// 查找附近的匹配用户（旧接口，保留兼容）
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
            let records = try await queryByRadius(center: center, radiusKm: radiusKm, userId: userId)
            print("📍 [MatchingService] 找到 \(records.count) 个附近用户")

            let archiveManager = SoulArchiveManager.shared
            guard let myRecord = archiveManager.myRecord else {
                print("⚠️ [MatchingService] 没有灵魂分析结果，无法匹配")
                nearbyMatches = []
                isLoading = false
                return
            }

            let matches = buildMatchedUsers(
                from: records, center: center,
                myAnalysis: myRecord.analysisResult, minMatchScore: minMatchScore, radiusKm: radiusKm
            )
            nearbyMatches = matches
            print("💕 [MatchingService] 匹配到 \(matches.count) 个用户")

        } catch {
            print("❌ [MatchingService] 查询失败: \(error)")
            errorMessage = "查询附近用户失败"
        }

        isLoading = false
    }

    // MARK: - 私有查询方法

    private func queryByRadius(center: CLLocationCoordinate2D, radiusKm: Double, userId: String) async throws -> [UserLocationRecord] {
        let latDelta = radiusKm / 111.0
        let lonDelta = radiusKm / (111.0 * cos(center.latitude * .pi / 180))

        return try await supabase
            .from("user_locations")
            .select()
            .neq("user_id", value: userId)
            .gte("latitude", value: center.latitude - latDelta)
            .lte("latitude", value: center.latitude + latDelta)
            .gte("longitude", value: center.longitude - lonDelta)
            .lte("longitude", value: center.longitude + lonDelta)
            .execute()
            .value
    }

    private func queryByCity(city: String, userId: String) async throws -> [UserLocationRecord] {
        return try await supabase
            .from("user_locations")
            .select()
            .neq("user_id", value: userId)
            .eq("city", value: city)
            .execute()
            .value
    }

    private func queryNationwide(userId: String) async throws -> [UserLocationRecord] {
        return try await supabase
            .from("user_locations")
            .select()
            .neq("user_id", value: userId)
            .execute()
            .value
    }

    /// 将数据库记录转换为 MatchedUser 列表并按匹配度排序
    private func buildMatchedUsers(
        from records: [UserLocationRecord],
        center: CLLocationCoordinate2D,
        myAnalysis: SoulAnalysisResult,
        minMatchScore: Int,
        radiusKm: Double? = nil
    ) -> [MatchedUser] {
        var matches: [MatchedUser] = []

        for record in records {
            let distance = calculateDistance(
                from: center,
                to: CLLocationCoordinate2D(latitude: record.latitude, longitude: record.longitude)
            )

            // 仅限半径内（阶段1使用精确距离过滤）
            if let r = radiusKm, distance > r { continue }

            let score = calculateMatchScore(myAnalysis: myAnalysis, otherRecord: record)
            guard score >= minMatchScore else { continue }

            let matchedUser = MatchedUser(
                id: record.userId,
                nickname: record.nickname,
                latitude: record.latitude,
                longitude: record.longitude,
                matchScore: score,
                userElement: record.userElement ?? "未知",
                personalityTraits: record.personalityTraits ?? [],
                distance: distance,
                avatarUrl: record.avatarUrl,
                city: record.city,
                isShadow: record.isShadow,
                analysisSummary: record.analysisSummary,
                portraitUrl: record.portraitUrl
            )
            matches.append(matchedUser)
        }

        matches.sort { $0.matchScore > $1.matchScore }
        return Array(matches.prefix(50))
    }

    // MARK: - 匹配算法

    /// 计算匹配度
    private func calculateMatchScore(myAnalysis: SoulAnalysisResult, otherRecord: UserLocationRecord) -> Int {
        var score = 0

        // 1. 五行匹配（30分）
        if let otherElement = otherRecord.userElement,
           otherElement == myAnalysis.soulmateElement {
            score += 30
        } else if let otherElement = otherRecord.userElement {
            if isElementCompatible(myAnalysis.soulmateElement, otherElement) {
                score += 15
            }
        }

        // 2. 性格特质匹配（40分）
        if let otherTraits = otherRecord.personalityTraits {
            let myWantedTraits = Set(myAnalysis.soulmateTraits)
            let otherTraitsSet = Set(otherTraits)
            let intersection = myWantedTraits.intersection(otherTraitsSet)

            if !myWantedTraits.isEmpty {
                let traitScore = Int(Double(intersection.count) / Double(myWantedTraits.count) * 40)
                score += traitScore
            }
        }

        // 3. 互补匹配（20分）
        if let otherSoulmateElement = otherRecord.soulmateElement,
           otherSoulmateElement == myAnalysis.userElement {
            score += 20
        }

        // 4. 基础分（10分）
        if otherRecord.userElement != nil && otherRecord.personalityTraits != nil {
            score += 10
        }

        return min(score, 100)
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
