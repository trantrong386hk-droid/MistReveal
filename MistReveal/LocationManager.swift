import Foundation
import CoreLocation
import MapKit

/// GPS 定位管理器
@MainActor
class LocationManager: NSObject, ObservableObject {

    static let shared = LocationManager()

    // MARK: - 发布属性

    @Published var userLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    @Published var isUpdatingLocation = false

    // MARK: - 私有属性

    private let locationManager = CLLocationManager()
    private var hasRequestedAuthorization = false

    // MARK: - 初始化

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters // 百米精度足够
        locationManager.distanceFilter = 100 // 移动100米才更新
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - 公开方法

    /// 请求定位权限
    func requestAuthorization() {
        guard !hasRequestedAuthorization else { return }
        hasRequestedAuthorization = true

        switch authorizationStatus {
        case .notDetermined:
            print("📍 [LocationManager] 请求定位权限...")
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            print("📍 [LocationManager] 已有定位权限，开始定位")
            startUpdatingLocation()
        case .denied, .restricted:
            print("📍 [LocationManager] 定位权限被拒绝")
            locationError = "请在设置中开启定位权限"
        @unknown default:
            break
        }
    }

    /// 开始更新位置
    func startUpdatingLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            print("📍 [LocationManager] 无定位权限，无法开始定位")
            return
        }

        isUpdatingLocation = true
        locationError = nil
        locationManager.startUpdatingLocation()
        print("📍 [LocationManager] 开始更新位置")
    }

    /// 停止更新位置
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        isUpdatingLocation = false
        print("📍 [LocationManager] 停止更新位置")
    }

    /// 获取一次位置后停止
    func requestSingleLocation() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestAuthorization()
            return
        }
        locationManager.requestLocation()
    }

    /// 计算两点之间的距离（公里）
    func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation) / 1000.0 // 转换为公里
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            print("📍 [LocationManager] 授权状态变更: \(authorizationStatus.rawValue)")

            switch authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                startUpdatingLocation()
            case .denied, .restricted:
                locationError = "请在设置中开启定位权限"
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        Task { @MainActor in
            userLocation = location.coordinate
            print("📍 [LocationManager] 位置更新: \(location.coordinate.latitude), \(location.coordinate.longitude)")

            // 获取到位置后停止持续更新，节省电量
            stopUpdatingLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            print("📍 [LocationManager] 定位失败: \(error.localizedDescription)")

            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    locationError = "定位权限被拒绝"
                case .locationUnknown:
                    locationError = "无法获取位置"
                default:
                    locationError = "定位失败"
                }
            } else {
                locationError = "定位失败: \(error.localizedDescription)"
            }

            isUpdatingLocation = false
        }
    }
}
