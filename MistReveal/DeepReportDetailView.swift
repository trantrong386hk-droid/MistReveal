import SwiftUI

/// 深度命盘报告页（从 Gallery 入口进入，读取 persona_settings.deep_report）
struct DeepReportDetailView: View {
    let companion: AICompanion

    @ObservedObject private var purchaseManager = PurchaseManager.shared
    @State private var showPaywall = false
    @Environment(\.dismiss) private var dismiss

    private var report: DeepReport? { companion.personaSettings.deepReport }
    private var name: String { companion.personaSettings.character?.name ?? companion.personaSettings.name ?? "灵犀" }

    var body: some View {
        ZStack {
            Color(hex: "#0A0A12").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    // 标题
                    VStack(spacing: 8) {
                        Text("命 盘 报 告")
                            .font(.system(size: 24, weight: .bold))
                            .tracking(6)
                            .foregroundColor(.white)
                        Text("关于你与 \(name) 之间的一切")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .padding(.top, 24)

                    if let report {
                        // 契合度 + 缘分类型（始终可见，作为钩子）
                        compatibilityHeader(report: report)

                        // 付费墙区域
                        ZStack {
                            VStack(spacing: 20) {
                                if let traits = report.soulmateTraits, !traits.isEmpty {
                                    traitsSection(traits: traits)
                                }
                                if let analysis = report.compatibilityAnalysis, !analysis.isEmpty {
                                    textBlock(icon: "sparkles", title: "契合度深度解析", content: analysis, color: Color(hex: "#E94560"))
                                }
                                if let wound = report.loveWound, !wound.isEmpty {
                                    textBlock(icon: "heart.slash", title: "你的感情伤口", content: wound, color: Color(hex: "#E94560"))
                                }
                                if let shadow = report.shadowTrait, !shadow.isEmpty {
                                    textBlock(icon: "moon.fill", title: "你不说的那一面", content: shadow, color: Color(hex: "#8B7FD4"))
                                }
                                if let timing = report.meetingTiming, !timing.isEmpty {
                                    textBlock(icon: "clock", title: "Ta 会在什么时候出现", content: timing, color: Color(hex: "#E94560"))
                                }
                                if let msg = report.messageToSoulmate, !msg.isEmpty {
                                    messageCard(msg)
                                }
                            }
                            .blur(radius: purchaseManager.hasDeepReport ? 0 : 8)
                            .allowsHitTesting(purchaseManager.hasDeepReport)

                            if !purchaseManager.hasDeepReport {
                                lockOverlay
                            }
                        }
                    } else {
                        // 旧数据没有深度报告（生成时间早于此功能上线）
                        noReportView
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 20)
            }

            // 关闭按钮
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(.white)
                            .padding(12)
                    }
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.horizontal, 8)
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showPaywall) {
            DeepReportPaywallView(purchaseManager: purchaseManager)
        }
    }

    // MARK: - 子组件

    private func compatibilityHeader(report: DeepReport) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("契合度")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                Text("\(report.compatibilityScore ?? 0)%")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(Color(hex: "#E94560"))
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1, height: 60)

            VStack(spacing: 6) {
                Text("缘分类型")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                Text(report.destinyType ?? "灵魂共鸣")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 24)
        .background(Color.white.opacity(0.08))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private func traitsSection(traits: [String]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "#E94560"))
                Text("Ta 的灵魂特质")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .tracking(1)
            }
            FlowLayout(spacing: 10) {
                ForEach(traits, id: \.self) { trait in
                    Text(trait)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#E94560"))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#E94560").opacity(0.15))
                        .cornerRadius(20)
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "#E94560").opacity(0.4), lineWidth: 1))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .cornerRadius(20)
    }

    private func textBlock(icon: String, title: String, content: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
                    .tracking(1)
            }
            Text(content)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.82))
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(color.opacity(0.2), lineWidth: 1))
    }

    private func messageCard(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("如果你已经在某个地方")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.35))
                .tracking(2)
            Text("\u{201C}" + message + "\u{201D}")
                .font(.system(size: 17, weight: .light))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .italic()
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: "#E94560").opacity(0.12), Color(hex: "#8B7FD4").opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "#E94560").opacity(0.25), lineWidth: 1))
    }

    private var lockOverlay: some View {
        Button(action: { showPaywall = true }) {
            VStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white.opacity(0.7))
                Text("解锁完整命盘")
                    .font(.system(size: 14, weight: .medium))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.85))
                Text("¥8 · 一次解锁永久查看")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.vertical, 28)
            .padding(.horizontal, 40)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
    }

    private var noReportView: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36))
                .foregroundColor(Color(hex: "#E94560").opacity(0.4))
            Text("该伴侣生成于功能上线前\n暂无深度报告数据")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .lineSpacing(5)
        }
        .padding(.top, 40)
    }
}
