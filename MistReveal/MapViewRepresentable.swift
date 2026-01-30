import SwiftUI
import MapKit

/// MKMapView 的 SwiftUI 包装器
struct MapViewRepresentable: UIViewRepresentable {

    @Binding var userLocation: CLLocationCoordinate2D?
    @Binding var matchedUsers: [MatchingService.MatchedUser]
    @Binding var selectedUser: MatchingService.MatchedUser?
    @Binding var shouldRecenter: Bool
    @Binding var focusCoordinate: CLLocationCoordinate2D?  // 跳转到指定坐标

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

        // 更新匹配用户标记
        updateAnnotations(mapView: mapView, context: context)
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

            // 匹配用户使用自定义标记
            if let matchAnnotation = annotation as? MatchAnnotation {
                let identifier = "MatchAnnotation"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: matchAnnotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = false
                } else {
                    annotationView?.annotation = matchAnnotation
                }

                // 根据匹配度设置颜色（5档分层）
                let score = matchAnnotation.user.matchScore
                if score >= 95 {
                    annotationView?.markerTintColor = UIColor(hex: "#FFD700") // 命中注定 - 金色
                    annotationView?.glyphImage = UIImage(systemName: "star.fill")
                } else if score >= 85 {
                    annotationView?.markerTintColor = UIColor(hex: "#E94560") // 高度契合 - 粉红
                    annotationView?.glyphImage = UIImage(systemName: "heart.fill")
                } else if score >= 75 {
                    annotationView?.markerTintColor = UIColor(hex: "#FF8C00") // 相当匹配 - 橙色
                    annotationView?.glyphImage = UIImage(systemName: "heart.fill")
                } else if score >= 65 {
                    annotationView?.markerTintColor = UIColor(hex: "#8B5CF6") // 值得关注 - 紫色
                    annotationView?.glyphImage = UIImage(systemName: "heart")
                } else {
                    annotationView?.markerTintColor = UIColor(hex: "#9CA3AF") // 一般匹配 - 灰色
                    annotationView?.glyphImage = UIImage(systemName: "heart")
                }

                annotationView?.displayPriority = .required

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
