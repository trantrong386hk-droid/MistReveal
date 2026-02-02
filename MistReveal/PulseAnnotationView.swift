import UIKit
import MapKit

/// 脉冲波纹标注视图 - 用于显示匹配用户的能量波动点
class PulseAnnotationView: MKAnnotationView {

    private var pulseColor: UIColor = .systemPink
    private var pulseLayers: [CAShapeLayer] = []
    private var centerLayer: CAShapeLayer?
    private var isAnimating = false

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }

    private func setupView() {
        backgroundColor = .clear
        frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        centerOffset = CGPoint(x: 0, y: 0)
    }

    /// 配置脉冲动画视图
    /// - Parameters:
    ///   - element: 五行元素（金木水火土）
    ///   - matchScore: 匹配度分数
    func configure(element: String, matchScore: Int) {
        // 设置五行颜色
        pulseColor = elementColor(element)
        setupPulseLayers()
        startPulseAnimation()
    }

    /// 根据五行获取对应颜色
    private func elementColor(_ element: String) -> UIColor {
        switch element {
        case "金": return UIColor(hex: "#FFD700")  // 金色
        case "木": return UIColor(hex: "#4CAF50")  // 绿色
        case "水": return UIColor(hex: "#2196F3")  // 蓝色
        case "火": return UIColor(hex: "#FF5722")  // 红橙色
        case "土": return UIColor(hex: "#8D6E63")  // 棕色
        default: return UIColor.white
        }
    }

    /// 设置脉冲图层
    private func setupPulseLayers() {
        // 移除旧的图层
        pulseLayers.forEach { $0.removeFromSuperlayer() }
        pulseLayers.removeAll()
        centerLayer?.removeFromSuperlayer()

        let viewCenter = CGPoint(x: bounds.midX, y: bounds.midY)

        // 中心实心圆 - 以 (0,0) 为中心绘制，通过 position 定位
        let centerSize: CGFloat = 16
        let centerLayer = CAShapeLayer()
        centerLayer.path = UIBezierPath(ovalIn: CGRect(
            x: -centerSize/2,
            y: -centerSize/2,
            width: centerSize,
            height: centerSize
        )).cgPath
        centerLayer.position = viewCenter
        centerLayer.fillColor = pulseColor.cgColor
        // 添加外发光效果
        centerLayer.shadowColor = pulseColor.cgColor
        centerLayer.shadowOffset = .zero
        centerLayer.shadowRadius = 8
        centerLayer.shadowOpacity = 0.8
        layer.addSublayer(centerLayer)
        self.centerLayer = centerLayer

        // 3层波纹 - 同样以 (0,0) 为中心绘制，通过 position 定位
        for _ in 0..<3 {
            let pulseLayer = CAShapeLayer()
            let pulseSize: CGFloat = 20
            pulseLayer.path = UIBezierPath(ovalIn: CGRect(
                x: -pulseSize/2,
                y: -pulseSize/2,
                width: pulseSize,
                height: pulseSize
            )).cgPath
            pulseLayer.position = viewCenter
            pulseLayer.fillColor = UIColor.clear.cgColor
            pulseLayer.strokeColor = pulseColor.cgColor
            pulseLayer.lineWidth = 2
            pulseLayer.opacity = 0
            layer.insertSublayer(pulseLayer, at: 0)
            pulseLayers.append(pulseLayer)
        }
    }

    /// 开始脉冲动画
    private func startPulseAnimation() {
        guard !isAnimating else { return }
        isAnimating = true

        for (index, pulseLayer) in pulseLayers.enumerated() {
            // 缩放动画
            let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
            scaleAnim.fromValue = 0.8
            scaleAnim.toValue = 2.5

            // 透明度动画
            let opacityAnim = CABasicAnimation(keyPath: "opacity")
            opacityAnim.fromValue = 0.8
            opacityAnim.toValue = 0

            // 组合动画
            let group = CAAnimationGroup()
            group.animations = [scaleAnim, opacityAnim]
            group.duration = 2.0
            group.repeatCount = .infinity
            group.beginTime = CACurrentMediaTime() + Double(index) * 0.6 // 错开启动
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)

            pulseLayer.add(group, forKey: "pulse_\(index)")
        }

        // 中心圆呼吸效果
        if let centerLayer = centerLayer {
            let breatheAnim = CABasicAnimation(keyPath: "transform.scale")
            breatheAnim.fromValue = 1.0
            breatheAnim.toValue = 1.15
            breatheAnim.duration = 1.0
            breatheAnim.autoreverses = true
            breatheAnim.repeatCount = .infinity
            breatheAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            centerLayer.add(breatheAnim, forKey: "breathe")

            // 光晕闪烁
            let glowAnim = CABasicAnimation(keyPath: "shadowRadius")
            glowAnim.fromValue = 6
            glowAnim.toValue = 12
            glowAnim.duration = 1.0
            glowAnim.autoreverses = true
            glowAnim.repeatCount = .infinity
            glowAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            centerLayer.add(glowAnim, forKey: "glow")
        }
    }

    /// 停止动画
    func stopPulseAnimation() {
        isAnimating = false
        pulseLayers.forEach { $0.removeAllAnimations() }
        centerLayer?.removeAllAnimations()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopPulseAnimation()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil && !isAnimating {
            startPulseAnimation()
        }
    }
}
