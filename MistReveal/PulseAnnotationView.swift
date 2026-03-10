import UIKit
import MapKit

/// 脉冲波纹标注视图 - 用于显示匹配用户的能量波动点
class PulseAnnotationView: MKAnnotationView {

    private var pulseColor: UIColor = .systemPink
    private var pulseLayers: [CAShapeLayer] = []
    private var centerLayer: CAShapeLayer?
    private var dashedRingLayer: CAShapeLayer?
    private var scoreLabel: UILabel?
    private var shadowLabel: UILabel?
    private var ghostIconView: UIImageView?
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

    /// 配置"我的位置"标注（蓝色脉冲，无文字标签）
    func configureAsMyLocation() {
        configure(element: "水", matchScore: 100)  // 蓝色 #2196F3，最大尺寸
        // 移除分数标签，蓝色光点只显示脉冲动画
        scoreLabel?.removeFromSuperview()
        scoreLabel = nil
    }

    /// 配置脉冲动画视图
    /// - Parameters:
    ///   - element: 五行元素（金木水火土）
    ///   - matchScore: 匹配度分数
    ///   - isShadow: 是否为数字残影
    ///   - isRecentlyActive: 是否为 24h 内活跃的真实用户
    func configure(element: String, matchScore: Int, isShadow: Bool = false, isRecentlyActive: Bool = false) {
        pulseColor = elementColor(element)

        if isShadow {
            configureShadow(element: element)
        } else {
            configureReal(matchScore: matchScore, isRecentlyActive: isRecentlyActive)
        }
    }

    // MARK: - 真实用户配置

    private func configureReal(matchScore: Int, isRecentlyActive: Bool) {
        // 清理 shadow 专用元素
        clearShadowLayers()

        // 计算匹配度驱动尺寸（40–65 pt）
        let sizeFactor = CGFloat(40.0 + Double(max(matchScore - 40, 0)) * 0.5)
        let clampedSize = max(40, min(65, sizeFactor))
        frame = CGRect(x: 0, y: 0, width: clampedSize, height: clampedSize)

        // 匹配度驱动中心透明度（0.51–0.75）
        let alphaCentre = Float(0.35 + Double(matchScore) * 0.004)

        alpha = 1.0
        setupPulseLayers(alphaCentre: alphaCentre)
        startPulseAnimation()
        setupScoreLabel(score: matchScore, containerSize: clampedSize)

        // 在线状态白点（右上角）
        if isRecentlyActive {
            let activeDot = CAShapeLayer()
            activeDot.path = UIBezierPath(ovalIn: CGRect(
                x: bounds.maxX - 8, y: bounds.minY + 2, width: 6, height: 6
            )).cgPath
            activeDot.fillColor = UIColor.white.cgColor
            activeDot.shadowColor = UIColor.white.cgColor
            activeDot.shadowRadius = 2
            activeDot.shadowOpacity = 0.8
            activeDot.shadowOffset = .zero
            layer.addSublayer(activeDot)
        }
    }

    // MARK: - Shadow 用户配置

    private func configureShadow(element: String) {
        // 清理真实用户专用元素
        pulseLayers.forEach { $0.removeFromSuperlayer() }
        pulseLayers.removeAll()
        centerLayer?.removeFromSuperlayer()
        centerLayer = nil
        scoreLabel?.removeFromSuperview()
        scoreLabel = nil
        isAnimating = false

        // 清理 shadow 旧图层（重用时）
        clearShadowLayers()

        frame = CGRect(x: 0, y: 0, width: 56, height: 56)
        alpha = 0.9

        setupDashedRing()
        setupGhostIcon()
        setupShadowLabel()
    }

    // MARK: - 虚线外环（shadow 专用，静态）

    private func setupDashedRing() {
        dashedRingLayer?.removeFromSuperlayer()

        let ringLayer = CAShapeLayer()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius: CGFloat = 22
        ringLayer.path = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true).cgPath
        ringLayer.fillColor = UIColor.clear.cgColor
        ringLayer.strokeColor = pulseColor.withAlphaComponent(0.6).cgColor
        ringLayer.lineWidth = 1.5
        ringLayer.lineDashPattern = [5, 4]
        layer.addSublayer(ringLayer)
        dashedRingLayer = ringLayer
    }

    // MARK: - 幽灵图标（shadow 专用）

    private func setupGhostIcon() {
        ghostIconView?.removeFromSuperview()

        let iconSize: CGFloat = 22
        let iconView = UIImageView(frame: CGRect(
            x: bounds.midX - iconSize / 2,
            y: bounds.midY - iconSize / 2 - 2,
            width: iconSize,
            height: iconSize
        ))
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
        iconView.image = UIImage(systemName: "person.fill.questionmark", withConfiguration: config)
        iconView.tintColor = pulseColor.withAlphaComponent(0.75)
        iconView.contentMode = .scaleAspectFit
        addSubview(iconView)
        ghostIconView = iconView
    }

    // MARK: - "星影"文字标签（shadow 专用）

    private func setupShadowLabel() {
        shadowLabel?.removeFromSuperview()

        let label = UILabel()
        label.text = "星影"
        label.font = UIFont.systemFont(ofSize: 10, weight: .regular)
        label.textColor = pulseColor.withAlphaComponent(0.8)
        label.textAlignment = .center
        label.sizeToFit()
        label.frame = CGRect(
            x: (bounds.width - label.bounds.width) / 2,
            y: bounds.height - label.bounds.height - 1,
            width: label.bounds.width,
            height: label.bounds.height
        )
        addSubview(label)
        shadowLabel = label
    }

    // MARK: - 清理 shadow 专用图层

    private func clearShadowLayers() {
        dashedRingLayer?.removeFromSuperlayer()
        dashedRingLayer = nil
        centerLayer?.removeFromSuperlayer()
        centerLayer = nil
        ghostIconView?.removeFromSuperview()
        ghostIconView = nil
        shadowLabel?.removeFromSuperview()
        shadowLabel = nil
    }

    // MARK: - 分数标签

    private func setupScoreLabel(score: Int, containerSize: CGFloat) {
        scoreLabel?.removeFromSuperview()

        let label = UILabel()
        label.text = "\(score)%"
        label.font = UIFont.systemFont(ofSize: 9, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.75)
        label.textAlignment = .center
        label.sizeToFit()
        label.frame = CGRect(
            x: (containerSize - label.bounds.width) / 2,
            y: containerSize - label.bounds.height - 2,
            width: label.bounds.width,
            height: label.bounds.height
        )
        addSubview(label)
        scoreLabel = label
    }

    // MARK: - 脉冲图层（真实用户）

    private func setupPulseLayers(alphaCentre: Float = 0.7) {
        pulseLayers.forEach { $0.removeFromSuperlayer() }
        pulseLayers.removeAll()
        centerLayer?.removeFromSuperlayer()

        let viewCenter = CGPoint(x: bounds.midX, y: bounds.midY)

        // 中心实心圆
        let centerSize: CGFloat = 14
        let cLayer = CAShapeLayer()
        cLayer.path = UIBezierPath(ovalIn: CGRect(
            x: -centerSize/2, y: -centerSize/2, width: centerSize, height: centerSize
        )).cgPath
        cLayer.position = viewCenter
        cLayer.fillColor = pulseColor.cgColor
        cLayer.shadowColor = pulseColor.cgColor
        cLayer.shadowOffset = .zero
        cLayer.shadowRadius = 6
        cLayer.shadowOpacity = alphaCentre
        layer.addSublayer(cLayer)
        centerLayer = cLayer

        // 3层波纹
        for _ in 0..<3 {
            let pulseLayer = CAShapeLayer()
            let pulseSize: CGFloat = 18
            pulseLayer.path = UIBezierPath(ovalIn: CGRect(
                x: -pulseSize/2, y: -pulseSize/2, width: pulseSize, height: pulseSize
            )).cgPath
            pulseLayer.position = viewCenter
            pulseLayer.fillColor = UIColor.clear.cgColor
            pulseLayer.strokeColor = pulseColor.cgColor
            pulseLayer.lineWidth = 1.5
            pulseLayer.opacity = 0
            layer.insertSublayer(pulseLayer, at: 0)
            pulseLayers.append(pulseLayer)
        }
    }

    // MARK: - 脉冲动画

    private func startPulseAnimation() {
        guard !isAnimating else { return }
        isAnimating = true

        for (index, pulseLayer) in pulseLayers.enumerated() {
            let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
            scaleAnim.fromValue = 0.8
            scaleAnim.toValue = 2.5

            let opacityAnim = CABasicAnimation(keyPath: "opacity")
            opacityAnim.fromValue = 0.8
            opacityAnim.toValue = 0

            let group = CAAnimationGroup()
            group.animations = [scaleAnim, opacityAnim]
            group.duration = 2.0
            group.repeatCount = .infinity
            group.beginTime = CACurrentMediaTime() + Double(index) * 0.6
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)

            pulseLayer.add(group, forKey: "pulse_\(index)")
        }

        if let cLayer = centerLayer {
            let breatheAnim = CABasicAnimation(keyPath: "transform.scale")
            breatheAnim.fromValue = 1.0
            breatheAnim.toValue = 1.15
            breatheAnim.duration = 1.0
            breatheAnim.autoreverses = true
            breatheAnim.repeatCount = .infinity
            breatheAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            cLayer.add(breatheAnim, forKey: "breathe")

            let glowAnim = CABasicAnimation(keyPath: "shadowRadius")
            glowAnim.fromValue = 4
            glowAnim.toValue = 10
            glowAnim.duration = 1.0
            glowAnim.autoreverses = true
            glowAnim.repeatCount = .infinity
            glowAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            cLayer.add(glowAnim, forKey: "glow")
        }
    }

    /// 停止动画
    func stopPulseAnimation() {
        isAnimating = false
        pulseLayers.forEach { $0.removeAllAnimations() }
        centerLayer?.removeAllAnimations()
    }

    /// 根据五行获取对应颜色
    private func elementColor(_ element: String) -> UIColor {
        switch element {
        case "金": return UIColor(hex: "#FFD700")
        case "木": return UIColor(hex: "#4CAF50")
        case "水": return UIColor(hex: "#2196F3")
        case "火": return UIColor(hex: "#FF5722")
        case "土": return UIColor(hex: "#8D6E63")
        default:   return UIColor.white
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopPulseAnimation()
        pulseLayers.forEach { $0.removeFromSuperlayer() }
        pulseLayers.removeAll()
        centerLayer?.removeFromSuperlayer()
        centerLayer = nil
        clearShadowLayers()
        scoreLabel?.removeFromSuperview()
        scoreLabel = nil
        // 清理在线状态白点（匿名 CAShapeLayer）
        layer.sublayers?.filter { $0 is CAShapeLayer && $0 !== dashedRingLayer && $0 !== centerLayer }.forEach { $0.removeFromSuperlayer() }
        alpha = 1.0
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview != nil && !isAnimating && !pulseLayers.isEmpty {
            startPulseAnimation()
        }
    }
}
