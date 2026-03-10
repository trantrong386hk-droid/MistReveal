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
    @Binding var highlightTarget: CLLocationCoordinate2D?  // 高亮连接目标（连线动画时使用）

    var onAnnotationSelected: ((MatchingService.MatchedUser) -> Void)?

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator

        // 极简地图配置（陌陌风格）
        mapView.showsUserLocation = false
        mapView.showsCompass = false  // 隐藏指南针（保持简洁）
        mapView.showsScale = false    // 隐藏比例尺

        // 深色 + 关掉所有 POI / 道路标签 / 交通，只保留省份/国家轮廓
        if #available(iOS 16.0, *) {
            let config = MKStandardMapConfiguration(elevationStyle: .flat)
            config.pointOfInterestFilter = .excludingAll   // 关闭所有兴趣点
            config.showsTraffic = false
            mapView.preferredConfiguration = config
        } else {
            mapView.mapType = .standard
            mapView.pointOfInterestFilter = .excludingAll
            mapView.showsTraffic = false
        }

        // 强制深色（极简暗色底图）
        mapView.overrideUserInterfaceStyle = .dark

        // 缩放锁定：相机离地最近 150km，此高度下道路线消失，只剩城市/省份名
        mapView.cameraZoomRange = MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: 150_000,
            maxCenterCoordinateDistance: 15_000_000
        )

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // 更新用户位置居中
        if let location = userLocation, !context.coordinator.hasInitialCentered {
            let region = MKCoordinateRegion(
                center: location,
                latitudinalMeters: 600_000,  // 省级范围 ~600km，与缩放下限匹配
                longitudinalMeters: 600_000
            )
            mapView.setRegion(region, animated: true)
            context.coordinator.hasInitialCentered = true
        }

        // 响应重新定位请求
        if shouldRecenter, let location = userLocation {
            let region = MKCoordinateRegion(
                center: location,
                latitudinalMeters: 300_000,
                longitudinalMeters: 300_000
            )
            mapView.setRegion(region, animated: true)
            context.coordinator.userHasManuallyInteracted = false
            DispatchQueue.main.async {
                self.shouldRecenter = false
            }
        }

        // 响应跳转到指定坐标请求
        if let coord = focusCoordinate {
            let region = MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 300_000,  // 地级市级范围
                longitudinalMeters: 300_000
            )
            mapView.setRegion(region, animated: true)
            context.coordinator.userHasManuallyInteracted = false

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

        // 更新匹配用户标记（含"我的位置"标注）
        updateAnnotations(mapView: mapView, context: context)

        // 更新普通连接线（虚线，连接所有匹配用户）
        updateConnectionLines(mapView: mapView)

        // 更新高亮连接线（实线，仅在连线动画时显示）
        updateHighlightLine(mapView: mapView, context: context)
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
            latitudeDelta: max((maxLat - minLat) * 1.5 + 0.01, 2.5),  // 最小 ~300km
            longitudeDelta: max((maxLon - minLon) * 1.5 + 0.01, 2.5)
        )

        let region = MKCoordinateRegion(center: center, span: span)
        mapView.setRegion(region, animated: true)
    }

    // MARK: - 高亮连接（我 → TA）

    private func updateHighlightLine(mapView: MKMapView, context: Context) {
        // 当 highlightTarget 首次出现或变化时，缩放地图以同时显示两点
        if highlightTarget != context.coordinator.lastHighlightTarget {
            context.coordinator.lastHighlightTarget = highlightTarget
            if let target = highlightTarget, let myLoc = userLocation,
               !context.coordinator.userHasManuallyInteracted {
                fitToHighlightCoordinates(mapView: mapView, from: myLoc, to: target)
            }
        }

        // 清空旧高亮线（已被 updateConnectionLines 一并移除，仅重置引用）
        context.coordinator.highlightPolyline = nil

        // 无目标则不绘制
        guard let target = highlightTarget, let myLoc = userLocation else { return }

        // 绘制大圆弧线（geodesic）
        var coords = [myLoc, target]
        let highlight = MKGeodesicPolyline(coordinates: &coords, count: 2)
        context.coordinator.highlightPolyline = highlight
        mapView.addOverlay(highlight, level: .aboveLabels)
    }

    /// 缩放地图以同时显示两个坐标点
    private func fitToHighlightCoordinates(
        mapView: MKMapView,
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) {
        let minLat = min(from.latitude, to.latitude)
        let maxLat = max(from.latitude, to.latitude)
        let minLon = min(from.longitude, to.longitude)
        let maxLon = max(from.longitude, to.longitude)

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.7 + 0.5, 3.0),
            longitudeDelta: max((maxLon - minLon) * 1.7 + 0.5, 3.0)
        )
        mapView.setRegion(MKCoordinateRegion(center: center, span: span), animated: true)
    }

    // MARK: - 普通连接线（所有匹配用户，虚线）

    private func updateConnectionLines(mapView: MKMapView) {
        // 移除所有 polyline 覆盖层（含高亮线，下方 updateHighlightLine 会重新添加）
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

    // MARK: - 更新标记（含"我的位置"）

    private func updateAnnotations(mapView: MKMapView, context: Context) {
        // 同步"我的位置"标注（坐标变化时自动更新，例如切换命盘）
        let existingMyLoc = mapView.annotations.first { $0 is MyLocationAnnotation } as? MyLocationAnnotation
        if let loc = userLocation {
            if let existing = existingMyLoc {
                // 坐标不同时更新（城市切换场景）
                if existing.coordinate.latitude != loc.latitude ||
                   existing.coordinate.longitude != loc.longitude {
                    mapView.removeAnnotation(existing)
                    mapView.addAnnotation(MyLocationAnnotation(coordinate: loc))
                }
                // 坐标相同则不动（避免闪烁重建）
            } else {
                // 首次添加
                mapView.addAnnotation(MyLocationAnnotation(coordinate: loc))
            }
        } else if let existing = existingMyLoc {
            mapView.removeAnnotation(existing)
        }

        // diff 更新匹配用户标记（仅移除消失的、添加新增的，避免全量重建闪烁）
        let existing = mapView.annotations.compactMap { $0 as? MatchAnnotation }
        let existingIds = Set(existing.map { $0.user.id })
        let newIds = Set(matchedUsers.map { $0.id })

        let toRemove = existing.filter { !newIds.contains($0.user.id) }
        mapView.removeAnnotations(toRemove)

        let toAdd = matchedUsers.filter { !existingIds.contains($0.id) }
        for user in toAdd { mapView.addAnnotation(MatchAnnotation(user: user)) }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewRepresentable
        var hasInitialCentered = false
        var lastHighlightTarget: CLLocationCoordinate2D? = nil
        var highlightPolyline: MKGeodesicPolyline? = nil
        var userHasManuallyInteracted = false
        private var isClampingZoom = false  // 防止 clamp 触发的回调误标记手势

        init(_ parent: MapViewRepresentable) {
            self.parent = parent
        }

        // 用户手势平移/缩放时 animated=false；程序调用 setRegion(animated:true) 时 animated=true
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // 只有用户手势（非 clamp、非程序调用）才标记
            if !animated && !isClampingZoom {
                userHasManuallyInteracted = true
            }

            // 兜底 clamp：与 cameraZoomRange 150km 对齐（latitudeDelta >= 1.35° ≈ 150km）
            let minDelta: CLLocationDegrees = 1.35
            if mapView.region.span.latitudeDelta < minDelta && !isClampingZoom {
                isClampingZoom = true
                DispatchQueue.main.async { [weak self, weak mapView] in
                    guard let self, let mapView else { return }
                    var clamped = mapView.region
                    clamped.span = MKCoordinateSpan(latitudeDelta: minDelta, longitudeDelta: minDelta)
                    mapView.setRegion(clamped, animated: false)
                    self.isClampingZoom = false
                }
            }
        }

        // 自定义标记视图
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // 用户位置使用默认蓝点
            if annotation is MKUserLocation {
                return nil
            }

            // "我的位置"使用蓝色脉冲标记
            if annotation is MyLocationAnnotation {
                let identifier = "MyLocationAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? PulseAnnotationView

                if annotationView == nil {
                    annotationView = PulseAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    annotationView?.frame = CGRect(x: 0, y: 0, width: 65, height: 65)
                    annotationView?.canShowCallout = false
                } else {
                    annotationView?.annotation = annotation
                }

                annotationView?.configureAsMyLocation()
                return annotationView
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

                // 配置五行颜色、动画和 shadow 样式
                annotationView?.configure(
                    element: matchAnnotation.user.userElement,
                    matchScore: matchAnnotation.user.matchScore,
                    isShadow: matchAnnotation.user.isShadow,
                    isRecentlyActive: matchAnnotation.user.isRecentlyActive
                )

                return annotationView
            }

            return nil
        }

        // 点击标记
        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            // 忽略"我的位置"标注的点击
            if annotation is MyLocationAnnotation {
                mapView.deselectAnnotation(annotation, animated: false)
                return
            }

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

                // 高亮线（我→TA）：金色实线
                if let hl = highlightPolyline, polyline === hl {
                    renderer.strokeColor = UIColor(hex: "#FFD700").withAlphaComponent(0.9)
                    renderer.lineWidth = 3
                } else {
                    // 普通连接线：红色虚线
                    renderer.strokeColor = UIColor(hex: "#E94560").withAlphaComponent(0.6)
                    renderer.lineWidth = 2
                    renderer.lineDashPattern = [6, 4]
                }
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// MARK: - "我的位置"标注

class MyLocationAnnotation: NSObject, MKAnnotation {
    var coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

// MARK: - 匹配用户标注

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
