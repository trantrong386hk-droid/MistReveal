import SwiftUI

/// 邀请好友页面（分享邀请卡图片）
struct InviteFriendsView: View {
    @Environment(\.dismiss) var dismiss

    @State private var showShareSheet = false
    @State private var inviteCardImage: UIImage?

    var body: some View {
        ZStack {
            Color(hex: "#0A0A12").ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [Color(hex: "#E94560").opacity(0.15), .clear]),
                center: .top,
                startRadius: 100,
                endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                customNavBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        Spacer(minLength: 40)

                        headerSection

                        VStack(spacing: 12) {
                            Text("邀请好友 一起探索命运")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)

                            Text("分享一张邀请卡给身边的人\n让他们也看看命中注定的那个人")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }

                        shareButton

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showShareSheet) {
            if let img = inviteCardImage {
                ShareSheet(items: [img])
            }
        }
    }

    // MARK: - 子组件

    var customNavBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white)
            }

            Spacer()

            Text("邀请好友")
                .font(.system(size: 12, weight: .light))
                .tracking(4)
                .foregroundColor(.white.opacity(0.9))

            Spacer()

            Color.clear.frame(width: 24)
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .frame(height: 50)
    }

    var headerSection: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#E94560").opacity(0.2))
                .frame(width: 160, height: 160)
                .blur(radius: 50)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "heart.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: "#E94560"))
                )
                .overlay(
                    Circle()
                        .stroke(Color(hex: "#E94560").opacity(0.3), lineWidth: 1)
                )
        }
    }

    var shareButton: some View {
        Button(action: shareInviteCard) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up")
                Text("立即分享")
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#E94560"), Color(hex: "#E94560").opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(25)
        }
    }

    // MARK: - 方法

    func shareInviteCard() {
        Task {
            if let card = await ShareCardBuilder.buildFromLatestPortrait() {
                inviteCardImage = card
            } else {
                inviteCardImage = InviteCardBuilder.build()
            }
            showShareSheet = true
        }
    }
}

// MARK: - 分享Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 统一分享卡片生成（三处共用）

enum ShareCardBuilder {

    /// 异步获取最新画像并合成分享卡片，无画像时返回 nil
    static func buildFromLatestPortrait() async -> UIImage? {
        guard let record = await SoulArchiveManager.shared.myRecords.first,
              let urlStr = record.imageUrl,
              let url = URL(string: urlStr),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let portrait = UIImage(data: data) else { return nil }
        let quote = record.analysisResult.shareQuote ?? "Ta 一直在等你"
        return build(portrait: portrait, quote: quote)
    }

    /// 用画像 + 金句合成分享卡片（与生成图片页效果一致）
    static func build(portrait: UIImage, quote: String) -> UIImage {
        let cardW: CGFloat = 750
        let portraitH: CGFloat = 920
        let bottomH: CGFloat = 220
        let cardH = portraitH + bottomH
        let bg = UIColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cardW, height: cardH))
        return renderer.image { ctx in
            let cgCtx = ctx.cgContext

            bg.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: cardW, height: cardH))

            // 画像
            let imageRect = CGRect(x: 0, y: 0, width: cardW, height: portraitH)
            let scaleX = cardW / portrait.size.width
            let scaleY = portraitH / portrait.size.height
            let scale = max(scaleX, scaleY)
            let drawW = portrait.size.width * scale
            let drawH = portrait.size.height * scale
            let drawX = (cardW - drawW) / 2
            let drawY = (portraitH - drawH) / 2
            cgCtx.saveGState()
            cgCtx.clip(to: imageRect)
            portrait.draw(in: CGRect(x: drawX, y: drawY, width: drawW, height: drawH))
            cgCtx.restoreGState()

            // 底部渐变遮罩
            let gradColors = [UIColor.clear.cgColor,
                              UIColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 0.75).cgColor,
                              bg.cgColor] as CFArray
            let gradLocs: [CGFloat] = [0, 0.5, 1.0]
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: gradColors, locations: gradLocs) {
                cgCtx.drawLinearGradient(grad,
                    start: CGPoint(x: 0, y: portraitH * 0.52),
                    end: CGPoint(x: 0, y: portraitH), options: [])
            }

            // 装饰线
            UIColor.white.withAlphaComponent(0.2).setStroke()
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: cardW * 0.28, y: portraitH * 0.68))
            linePath.addLine(to: CGPoint(x: cardW * 0.72, y: portraitH * 0.68))
            linePath.lineWidth = 0.8
            linePath.stroke()

            // 金句
            let centerPara = NSMutableParagraphStyle()
            centerPara.alignment = .center
            centerPara.lineSpacing = 10
            NSAttributedString(string: quote, attributes: [
                .font: UIFont.systemFont(ofSize: 30, weight: .medium),
                .foregroundColor: UIColor.white,
                .paragraphStyle: centerPara
            ]).draw(in: CGRect(x: 48, y: portraitH * 0.70, width: cardW - 96, height: 180))

            // 底部文案
            let leftPara = NSMutableParagraphStyle()
            leftPara.alignment = .left
            leftPara.lineSpacing = 6

            NSAttributedString(string: "「我的灵魂伴侣长这样」", attributes: [
                .font: UIFont.systemFont(ofSize: 34, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.92),
                .paragraphStyle: leftPara
            ]).draw(in: CGRect(x: 52, y: portraitH + 30, width: 440, height: 48))

            NSAttributedString(string: "你的呢？扫码免费测一测", attributes: [
                .font: UIFont.systemFont(ofSize: 26, weight: .light),
                .foregroundColor: UIColor.white.withAlphaComponent(0.5),
                .paragraphStyle: leftPara
            ]).draw(in: CGRect(x: 52, y: portraitH + 86, width: 440, height: 38))

            NSAttributedString(string: "缘起 YuanQi", attributes: [
                .font: UIFont.systemFont(ofSize: 20, weight: .ultraLight),
                .foregroundColor: UIColor.white.withAlphaComponent(0.25),
                .paragraphStyle: leftPara
            ]).draw(in: CGRect(x: 52, y: portraitH + bottomH - 48, width: 300, height: 32))

            // 二维码
            let qrSize: CGFloat = 148
            let qrX = cardW - 52 - qrSize
            let qrY = portraitH + (bottomH - qrSize) / 2
            if let qr = generateQRCode(from: "https://mistreveal.app", size: qrSize) {
                UIColor.white.withAlphaComponent(0.93).setFill()
                UIBezierPath(roundedRect: CGRect(x: qrX - 8, y: qrY - 8,
                                                 width: qrSize + 16, height: qrSize + 16),
                             cornerRadius: 12).fill()
                qr.draw(in: CGRect(x: qrX, y: qrY, width: qrSize, height: qrSize))
            }
        }
    }

    static func generateQRCode(from string: String, size: CGFloat) -> UIImage? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scale = size / output.extent.size.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - 邀请卡生成（无画像时降级用）

enum InviteCardBuilder {

    static func build() -> UIImage {
        let cardW: CGFloat = 750
        let cardH: CGFloat = 1000
        let bg = UIColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: cardW, height: cardH))
        return renderer.image { ctx in
            let cgCtx = ctx.cgContext

            bg.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: cardW, height: cardH))

            // 顶部光晕
            let glowColors = [UIColor(red: 0.91, green: 0.27, blue: 0.38, alpha: 0.35).cgColor,
                              UIColor.clear.cgColor] as CFArray
            let glowLocs: [CGFloat] = [0, 1]
            if let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: glowColors, locations: glowLocs) {
                cgCtx.drawRadialGradient(glow,
                    startCenter: CGPoint(x: cardW / 2, y: 0), startRadius: 0,
                    endCenter: CGPoint(x: cardW / 2, y: 0), endRadius: cardH * 0.7,
                    options: [])
            }

            drawStars(in: cgCtx, cardW: cardW, cardH: cardH)

            // 中心光圈
            UIColor(red: 0.91, green: 0.27, blue: 0.38, alpha: 0.12).setFill()
            UIBezierPath(ovalIn: CGRect(x: cardW/2 - 160, y: cardH * 0.12, width: 320, height: 320)).fill()

            UIColor(red: 0.91, green: 0.27, blue: 0.38, alpha: 0.25).setStroke()
            let ring = UIBezierPath(ovalIn: CGRect(x: cardW/2 - 80, y: cardH * 0.12 + 80, width: 160, height: 160))
            ring.lineWidth = 1
            ring.stroke()

            let centerPara = NSMutableParagraphStyle()
            centerPara.alignment = .center

            // 星号装饰
            let starAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .ultraLight),
                .foregroundColor: UIColor(red: 0.91, green: 0.27, blue: 0.38, alpha: 0.7),
                .paragraphStyle: centerPara
            ]
            NSAttributedString(string: "✦    ✦    ✦", attributes: starAttrs)
                .draw(in: CGRect(x: 0, y: cardH * 0.52, width: cardW, height: 36))

            // 主文案
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 36, weight: .semibold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: centerPara,
                .kern: 2.0
            ]
            NSAttributedString(string: "「我的灵魂伴侣长这样」", attributes: titleAttrs)
                .draw(in: CGRect(x: 40, y: cardH * 0.58, width: cardW - 80, height: 56))

            // 副文案
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .light),
                .foregroundColor: UIColor.white.withAlphaComponent(0.55),
                .paragraphStyle: centerPara
            ]
            NSAttributedString(string: "你的呢？扫码免费测一测", attributes: subAttrs)
                .draw(in: CGRect(x: 40, y: cardH * 0.68, width: cardW - 80, height: 40))

            // 分隔线
            UIColor.white.withAlphaComponent(0.1).setStroke()
            let sep = UIBezierPath()
            sep.move(to: CGPoint(x: 48, y: cardH * 0.82))
            sep.addLine(to: CGPoint(x: cardW - 48, y: cardH * 0.82))
            sep.lineWidth = 0.8
            sep.stroke()

            let leftPara = NSMutableParagraphStyle()
            leftPara.alignment = .left

            // 品牌
            let brandTitleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 26, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.88),
                .paragraphStyle: leftPara
            ]
            NSAttributedString(string: "缘起", attributes: brandTitleAttrs)
                .draw(in: CGRect(x: 56, y: cardH * 0.85, width: 300, height: 40))

            let brandSubAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .ultraLight),
                .foregroundColor: UIColor.white.withAlphaComponent(0.3),
                .paragraphStyle: leftPara
            ]
            NSAttributedString(string: "YuanQi · 灵魂伴侣测算", attributes: brandSubAttrs)
                .draw(in: CGRect(x: 56, y: cardH * 0.85 + 42, width: 380, height: 30))

            // 二维码
            let qrSize: CGFloat = 130
            let qrX = cardW - 56 - qrSize
            let qrY = cardH * 0.84
            if let qr = generateQRCode(from: "https://mistreveal.app", size: qrSize) {
                UIColor.white.withAlphaComponent(0.92).setFill()
                UIBezierPath(roundedRect: CGRect(x: qrX - 8, y: qrY - 8, width: qrSize + 16, height: qrSize + 16),
                             cornerRadius: 10).fill()
                qr.draw(in: CGRect(x: qrX, y: qrY, width: qrSize, height: qrSize))
            }
        }
    }

    private static func drawStars(in ctx: CGContext, cardW: CGFloat, cardH: CGFloat) {
        let positions: [(CGFloat, CGFloat, CGFloat)] = [
            (0.12, 0.08, 2.5), (0.88, 0.06, 2.0), (0.25, 0.18, 1.5),
            (0.75, 0.22, 1.8), (0.05, 0.35, 1.2), (0.95, 0.30, 1.4),
            (0.40, 0.05, 1.6), (0.60, 0.10, 2.2), (0.15, 0.45, 1.0),
            (0.85, 0.40, 1.3), (0.50, 0.02, 1.8), (0.30, 0.28, 1.1)
        ]
        for (xRatio, yRatio, radius) in positions {
            UIColor.white.withAlphaComponent(CGFloat.random(in: 0.3...0.7)).setFill()
            UIBezierPath(ovalIn: CGRect(x: cardW * xRatio - radius, y: cardH * yRatio - radius,
                                        width: radius * 2, height: radius * 2)).fill()
        }
    }

    private static func generateQRCode(from string: String, size: CGFloat) -> UIImage? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scale = size / output.extent.size.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    InviteFriendsView()
}
