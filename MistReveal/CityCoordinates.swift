import CoreLocation

/// 中国主要城市坐标字典 + 近似坐标生成
struct CityCoordinates {

    struct CityInfo {
        let name: String
        let coordinate: CLLocationCoordinate2D
    }

    static let cities: [CityInfo] = [
        // 直辖市
        CityInfo(name: "北京", coordinate: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)),
        CityInfo(name: "上海", coordinate: CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)),
        CityInfo(name: "天津", coordinate: CLLocationCoordinate2D(latitude: 39.0842, longitude: 117.2010)),
        CityInfo(name: "重庆", coordinate: CLLocationCoordinate2D(latitude: 29.5630, longitude: 106.5516)),
        // 广东
        CityInfo(name: "广州", coordinate: CLLocationCoordinate2D(latitude: 23.1291, longitude: 113.2644)),
        CityInfo(name: "深圳", coordinate: CLLocationCoordinate2D(latitude: 22.5431, longitude: 114.0579)),
        CityInfo(name: "东莞", coordinate: CLLocationCoordinate2D(latitude: 23.0207, longitude: 113.7518)),
        CityInfo(name: "佛山", coordinate: CLLocationCoordinate2D(latitude: 23.0218, longitude: 113.1219)),
        CityInfo(name: "珠海", coordinate: CLLocationCoordinate2D(latitude: 22.2710, longitude: 113.5767)),
        // 江苏
        CityInfo(name: "南京", coordinate: CLLocationCoordinate2D(latitude: 32.0603, longitude: 118.7969)),
        CityInfo(name: "苏州", coordinate: CLLocationCoordinate2D(latitude: 31.2989, longitude: 120.5853)),
        CityInfo(name: "无锡", coordinate: CLLocationCoordinate2D(latitude: 31.4912, longitude: 120.3119)),
        CityInfo(name: "南通", coordinate: CLLocationCoordinate2D(latitude: 31.9802, longitude: 120.8944)),
        // 浙江
        CityInfo(name: "杭州", coordinate: CLLocationCoordinate2D(latitude: 30.2741, longitude: 120.1551)),
        CityInfo(name: "宁波", coordinate: CLLocationCoordinate2D(latitude: 29.8683, longitude: 121.5440)),
        CityInfo(name: "温州", coordinate: CLLocationCoordinate2D(latitude: 28.0000, longitude: 120.6722)),
        // 四川
        CityInfo(name: "成都", coordinate: CLLocationCoordinate2D(latitude: 30.5728, longitude: 104.0668)),
        CityInfo(name: "绵阳", coordinate: CLLocationCoordinate2D(latitude: 31.4678, longitude: 104.6796)),
        // 湖北
        CityInfo(name: "武汉", coordinate: CLLocationCoordinate2D(latitude: 30.5928, longitude: 114.3055)),
        // 湖南
        CityInfo(name: "长沙", coordinate: CLLocationCoordinate2D(latitude: 28.2282, longitude: 112.9388)),
        // 陕西
        CityInfo(name: "西安", coordinate: CLLocationCoordinate2D(latitude: 34.3416, longitude: 108.9398)),
        // 福建
        CityInfo(name: "福州", coordinate: CLLocationCoordinate2D(latitude: 26.0745, longitude: 119.2965)),
        CityInfo(name: "厦门", coordinate: CLLocationCoordinate2D(latitude: 24.4798, longitude: 118.0894)),
        // 山东
        CityInfo(name: "济南", coordinate: CLLocationCoordinate2D(latitude: 36.6512, longitude: 117.1201)),
        CityInfo(name: "青岛", coordinate: CLLocationCoordinate2D(latitude: 36.0671, longitude: 120.3826)),
        // 河北
        CityInfo(name: "石家庄", coordinate: CLLocationCoordinate2D(latitude: 38.0428, longitude: 114.5149)),
        CityInfo(name: "唐山", coordinate: CLLocationCoordinate2D(latitude: 39.6305, longitude: 118.1800)),
        // 辽宁
        CityInfo(name: "沈阳", coordinate: CLLocationCoordinate2D(latitude: 41.8057, longitude: 123.4315)),
        CityInfo(name: "大连", coordinate: CLLocationCoordinate2D(latitude: 38.9140, longitude: 121.6147)),
        // 黑龙江
        CityInfo(name: "哈尔滨", coordinate: CLLocationCoordinate2D(latitude: 45.8038, longitude: 126.5349)),
        // 吉林
        CityInfo(name: "长春", coordinate: CLLocationCoordinate2D(latitude: 43.8171, longitude: 125.3235)),
        // 安徽
        CityInfo(name: "合肥", coordinate: CLLocationCoordinate2D(latitude: 31.8206, longitude: 117.2272)),
        // 江西
        CityInfo(name: "南昌", coordinate: CLLocationCoordinate2D(latitude: 28.6820, longitude: 115.8579)),
        // 河南
        CityInfo(name: "郑州", coordinate: CLLocationCoordinate2D(latitude: 34.7466, longitude: 113.6253)),
        // 山西
        CityInfo(name: "太原", coordinate: CLLocationCoordinate2D(latitude: 37.8706, longitude: 112.5489)),
        // 内蒙古
        CityInfo(name: "呼和浩特", coordinate: CLLocationCoordinate2D(latitude: 40.8415, longitude: 111.7519)),
        // 广西
        CityInfo(name: "南宁", coordinate: CLLocationCoordinate2D(latitude: 22.8170, longitude: 108.3665)),
        CityInfo(name: "桂林", coordinate: CLLocationCoordinate2D(latitude: 25.2736, longitude: 110.2907)),
        // 贵州
        CityInfo(name: "贵阳", coordinate: CLLocationCoordinate2D(latitude: 26.6470, longitude: 106.6302)),
        // 云南
        CityInfo(name: "昆明", coordinate: CLLocationCoordinate2D(latitude: 25.0461, longitude: 102.7096)),
        // 甘肃
        CityInfo(name: "兰州", coordinate: CLLocationCoordinate2D(latitude: 36.0611, longitude: 103.8343)),
        // 新疆
        CityInfo(name: "乌鲁木齐", coordinate: CLLocationCoordinate2D(latitude: 43.8256, longitude: 87.6168)),
        // 西藏
        CityInfo(name: "拉萨", coordinate: CLLocationCoordinate2D(latitude: 29.6500, longitude: 91.1000)),
        // 海南
        CityInfo(name: "海口", coordinate: CLLocationCoordinate2D(latitude: 20.0440, longitude: 110.1999)),
        CityInfo(name: "三亚", coordinate: CLLocationCoordinate2D(latitude: 18.2524, longitude: 109.5119)),
        // 宁夏
        CityInfo(name: "银川", coordinate: CLLocationCoordinate2D(latitude: 38.4872, longitude: 106.2309)),
        // 青海
        CityInfo(name: "西宁", coordinate: CLLocationCoordinate2D(latitude: 36.6171, longitude: 101.7782)),
        // 香港/澳门
        CityInfo(name: "香港", coordinate: CLLocationCoordinate2D(latitude: 22.3193, longitude: 114.1694)),
        CityInfo(name: "澳门", coordinate: CLLocationCoordinate2D(latitude: 22.1987, longitude: 113.5439)),
    ]

    /// 根据出生地字符串匹配城市，返回带确定性抖动的近似坐标
    /// - Parameters:
    ///   - location: 出生地字符串，如 "北京市海淀区"
    ///   - userId: 用于生成确定性抖动的用户ID
    /// - Returns: 近似坐标（±0.2°），未匹配到城市时返回 nil
    static func approximate(for location: String, userId: String) -> CLLocationCoordinate2D? {
        guard let city = findCity(for: location) else { return nil }

        // 确定性抖动（±0.2°），基于 userId hash
        let hash = abs(userId.hashValue)
        let latJitter = Double((hash % 400) - 200) / 1000.0        // ±0.2°
        let lonJitter = Double(((hash >> 8) % 400) - 200) / 1000.0

        return CLLocationCoordinate2D(
            latitude: city.coordinate.latitude + latJitter,
            longitude: city.coordinate.longitude + lonJitter
        )
    }

    /// 根据出生地字符串返回最匹配的城市名（用于 city 字段）
    static func matchedCityName(for location: String) -> String? {
        return findCity(for: location)?.name
    }

    // MARK: - Private

    private static func findCity(for location: String) -> CityInfo? {
        // 去掉常见后缀，方便匹配
        var normalized = location
            .replacingOccurrences(of: "市", with: "")
            .replacingOccurrences(of: "省", with: "")
            .replacingOccurrences(of: "区", with: "")
            .replacingOccurrences(of: "县", with: "")
            .trimmingCharacters(in: .whitespaces)

        // 优先精确前缀匹配（避免"长沙"匹配到"长春"）
        for city in cities {
            if normalized.hasPrefix(city.name) || city.name.hasPrefix(normalized) {
                return city
            }
        }

        // 次级：包含匹配
        for city in cities {
            if normalized.contains(city.name) || city.name.contains(normalized) {
                return city
            }
        }

        return nil
    }
}
