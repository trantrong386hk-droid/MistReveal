import SwiftUI

/// 邀请好友页面
struct InviteFriendsView: View {
    @Environment(\.dismiss) var dismiss

    // 服务
    @ObservedObject private var inviteService = InviteService.shared
    @ObservedObject private var quotaManager = QuotaManager.shared

    // 状态
    @State private var showShareSheet = false
    @State private var inviteLink: String = ""
    @State private var inviteCode: String = ""
    @State private var showCopiedToast = false
    @State private var isGeneratingLink = false

    var body: some View {
        ZStack {
            // 背景
            Color(hex: "#0A0A12").ignoresSafeArea()

            // 装饰性背景
            RadialGradient(
                gradient: Gradient(colors: [Color(hex: "#E94560").opacity(0.15), .clear]),
                center: .top,
                startRadius: 100,
                endRadius: 400
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // 导航栏
                customNavBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        Spacer(minLength: 40)

                        // 顶部图标
                        headerSection

                        // 说明文案
                        VStack(spacing: 12) {
                            Text("邀请好友 一起探索命运")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)

                            Text("每邀请 1 位好友完成测试\n你和 Ta 都能获得 1 次生成机会")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }

                        // 当前配额显示
                        quotaStatusCard

                        // 邀请卡片
                        inviteCard

                        // 邀请码区域
                        if !inviteCode.isEmpty {
                            inviteCodeSection
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 24)
                }
            }

            // 复制成功提示
            if showCopiedToast {
                VStack {
                    Spacer()
                    Text("已复制到剪贴板")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#E94560"))
                        .cornerRadius(25)
                        .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [inviteLink])
        }
        .onAppear {
            loadInviteCode()
            Task {
                await quotaManager.fetchQuota()
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

    // 顶部图标
    var headerSection: some View {
        ZStack {
            // 光晕
            Circle()
                .fill(Color(hex: "#E94560").opacity(0.2))
                .frame(width: 160, height: 160)
                .blur(radius: 50)

            // 图标容器
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "gift.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: "#E94560"))
                )
                .overlay(
                    Circle()
                        .stroke(Color(hex: "#E94560").opacity(0.3), lineWidth: 1)
                )
        }
    }

    // 当前配额状态卡片
    var quotaStatusCard: some View {
        HStack(spacing: 20) {
            // 剩余次数
            VStack(spacing: 4) {
                Text("\(quotaManager.quota?.totalRemaining ?? 0)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(Color(hex: "#E94560"))
                Text("剩余次数")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 1, height: 40)

            // 邀请获得
            VStack(spacing: 4) {
                Text("\(quotaManager.quota?.referralQuota ?? 0)")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("邀请获得")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.08))
        .cornerRadius(20)
    }

    // 邀请卡片
    var inviteCard: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "#E94560"))

                Text("分享给好友")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }

            // 邀请按钮
            Button(action: shareInviteLink) {
                HStack(spacing: 10) {
                    if isGeneratingLink {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
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
            .disabled(isGeneratingLink)
        }
        .padding(24)
        .background(Color.white.opacity(0.08))
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color(hex: "#E94560").opacity(0.3), lineWidth: 1)
        )
    }

    // 邀请码区域
    var inviteCodeSection: some View {
        VStack(spacing: 12) {
            Text("或让好友输入邀请码")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))

            HStack(spacing: 16) {
                // 邀请码显示
                Text(inviteCode)
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(4)

                // 复制按钮
                Button(action: copyInviteCode) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#E94560"))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Color.white.opacity(0.08))
            .cornerRadius(16)
        }
    }

    // MARK: - 方法

    func loadInviteCode() {
        Task {
            if let code = await inviteService.getOrCreateInviteCode() {
                inviteCode = code
            }
        }
    }

    func shareInviteLink() {
        isGeneratingLink = true
        Task {
            if let link = await inviteService.generateInviteLink() {
                inviteLink = link
                isGeneratingLink = false
                showShareSheet = true
            } else {
                isGeneratingLink = false
            }
        }
    }

    func copyInviteCode() {
        UIPasteboard.general.string = inviteCode
        withAnimation {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopiedToast = false
            }
        }

        // 触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
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

#Preview {
    InviteFriendsView()
}
