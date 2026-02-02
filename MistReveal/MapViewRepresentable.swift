import SwiftUI
import MapKit

/// MKMapView 的 SwiftUI 包装器
struct MapViewRepresentable: UIViewRepresentable {

    @Binding var userLocation: CLLocationCoordinate2D?
    @Binding var matchedUsers: [MatchingService.MatchedUser]
    @Binding var selectedUser: MatchingService.MatchedUser?
    @Binding var shouldRecenter: Bool
    @Binding var focusCoordinate: CLLocationCoordinate2D?  // 跳转到指定坐标
    @Binding var showConnectionLines: Bool  // 是否显示连接线
    @Binding var shouldFitAllAnnotations: Bool  // 是否缩放显示全部

    var onAnnotationSelected: ((MatchingService.MatchedUser) -> Void)?

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        // 地图样式配置
        mapView.mapType = .standard
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsScale = true

        // iOS 16+ 深色地图样式
        if #available(iOS 16.0, *) {
            mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat)
        }

        // 设置深色外观
        mapView.overrideUserInterfaceStyle = .dark

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新用户位置居中
        if let location = userLocation, !context.coordinator.hasInitialCentered {
            let region = MKCoordinateRegion(
                center: location,
                latitudinalMeters: 10000,  // 10公里范围
                longitudinalMeters: 10000
            )
            mapView.setRegion(region, animated: true)
            context.coordinator.hasInitialCentered = true
        }

        // 响应重新定位请求
        if shouldRecenter, let location = userLocation {
            let region = MKCoordinateRegion(
                center: location,
                latitudinalMeters: 10000,
                longitudinalMeters: 10000
            )
            mapView.setRegion(region, animated: true)
            DispatchQueue.main.async {
                self.shouldRecenter = false
            }
        }

        // 响应跳转到指定坐标请求
        if let coord = focusCoordinate {
            let region = MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 5000,  // 5km 范围，能看清标记
                longitudinalMeters: 5000
            )
            mapView.setRegion(region, animated: true)

            // 选中该位置的标记
            for annotation in mapView.annotations {
                if let matchAnnotation = annotation as? MatchAnnotation,
                   matchAnnotation.coordinate.latitude == coord.latitude,
                   matchAnnotation.coordinate.longitude == coord.longitude {
                    mapView.selectAnnotation(annotation, animated: true)
                    break
                }
            }

            DispatchQueue.main.async {
                self.focusCoordinate = nil
            }
        }

        // 响应缩放显示全部请求
        if shouldFitAllAnnotations {
            fitAllAnnotations(mapView: mapView)
            DispatchQueue.main.async {
                self.shouldFitAllAnnotations = false
            }
        }

        // 更新匹配用户标记
        updateAnnotations(mapView: mapView, context: context)

        // 更新连接线
        updateConnectionLines(mapView: mapView)
    }

    // MARK: - 缩放显示全部标记

    private func fitAllAnnotations(mapView: MKMapView) {
        let annotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        guard !annotations.isEmpty, let userLoc = userLocation else { return }

        var coordinates = annotations.map { $0.coordinate }
        coordinates.append(userLoc)

        // 计算包含所有坐标的区域
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.5 + 0.01,  // 添加边距
            longitudeDelta: (maxLon - minLon) * 1.5 + 0.01
        )

        let region = MKCoordinateRegion(center: center, span: span)
        mapView.setRegion(region, animated: true)
    }

    // MARK: - 连接线

    private func updateConnectionLines(mapView: MKMapView) {
        // 移除旧的覆盖层
        let overlays = mapView.overlays.filter { $0 is MKPolyline }
        mapView.removeOverlays(overlays)

        guard showConnectionLines, let userLoc = userLocation else { return }

        // 为每个匹配用户绘制连接线（使用大圆航线）
        for user in matchedUsers {
            let coordinates = [userLoc, user.coordinate]
            let polyline = MKGeodesicPolyline(coordinates: coordinates, count: 2)
            mapView.addOverlay(polyline)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - 更新标记

    private func updateAnnotations(mapView: MKMapView, context: Context) {
        // 移除旧的自定义标记（保留用户位置蓝点）
        let existingAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(existingAnnotations)

        // 添加匹配用户标记
        for user in matchedUsers {
            let annotation = MatchAnnotation(user: user)
            mapView.addAnnotation(annotation)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        var hasInitialCentered = false

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // 自定义标记视图
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 用户位置使用默认蓝点
            if annotation is MKUserLocation {
                return nil
            }

            // 匹配用户使用脉冲波纹标记
            if let matchAnnotation = annotation as? MatchAnnotation {
                let identifier = "PulseAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? PulseAnnotationView

                if annotationView == nil {
                    annotationView = PulseAnnotationView(annotation: matchAnnotation, reuseIdentifier: identifier)
                    annotationView?.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
                    annotationView?.canShowCallout = false
                } else {
                    annotationView?.annotation = matchAnnotation
                }

                // 配置五行颜色和动画
                annotationView?.configure(
                    element: matchAnnotation.user.userElement,
                    matchScore: matchAnnotation.user.matchScore
                )

                return annotationView
            }

            return nil
        }

        // 点击标记
        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            if let matchAnnotation = annotation as? MatchAnnotation {
                parent.selectedUser = matchAnnotation.user
                parent.onAnnotationSelected?(matchAnnotation.user)

                // 取消选中状态（允许重复点击）
                mapView.deselectAnnotation(annotation, animated: false)
            }
        }

        // 连接线渲染器
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(hex: "#E94560").withAlphaComponent(0.6)
                renderer.lineWidth = 2
                renderer.lineDashPattern = [6, 4]  // 虚线效果
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - 自定义标记

class MatchAnnotation: NSObject, MKAnnotation {
    let user: MatchingService.MatchedUser

    var coordinate: CLLocationCoordinate2D {
        user.coordinate
    }

    var title: String? {
        user.nickname
    }

    var subtitle: String? {
        "匹配度 \(user.matchScore)%"
    }

    init(user: MatchingService.MatchedUser) {
        self.user = user
    }
}

// MARK: - UIColor 扩展

extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
