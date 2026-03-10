import SwiftUI
import Supabase

// MARK: - 画像信息（用于画廊展示）

struct PortraitInfo: Decodable, Identifiable {
    let id: UUID
    let imageUrl: String
    let hexagram: String

    enum CodingKeys: String, CodingKey {
        case id
        case imageUrl = "image_url"
        case hexagram
    }
}

// MARK: - 灵犀画廊视图

struct SoulmateGalleryView: View {
    @State private var companions: [AICompanion] = []
    @State private var portraits: [UUID: PortraitInfo] = [:]
    @State private var fallbackPortraits: [UUID: PortraitInfo] = [:]
    @State private var chatCounts: [UUID: Int] = [:]
    @State private var isLoading = true
    @State private var companionToDelete: AICompanion? = nil
    @State private var showDeleteAlert = false

    var body: some View {
        ZStack {
            Color(hex: "#0A0A12").ignoresSafeArea()

            // 星云装饰
            Circle()
                .fill(Color(hex: "#E94560").opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 120, y: -100)
                .ignoresSafeArea()

            if isLoading {
                loadingView
            } else if companions.isEmpty {
                emptyView
            } else {
                galleryContent
            }
        }
        .navigationTitle("灵犀")
        .navigationBarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            Task { await loadData() }
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) {
                if let c = companionToDelete {
                    Task { await performDelete(companion: c) }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定删除这位灵魂伴侣？所有聊天记录和亲密度将被永久清除，无法恢复。")
        }
    }

    // MARK: - 加载视图

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)
            Text("加载中...")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - 空状态视图

    private var emptyView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .stroke(Color(hex: "#E94560").opacity(0.25), lineWidth: 2)
                    .frame(width: 100, height: 100)
                Image(systemName: "heart.slash")
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "#E94560").opacity(0.5))
            }

            VStack(spacing: 10) {
                Text("还没有灵魂伴侣")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)

                Text("完成命理推演后\n你的灵魂伴侣将在这里等你")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button(action: {
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
            }) {
                HStack(spacing: 8) {
                    Text("开始命理推演")
                        .font(.system(size: 15, weight: .medium))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#E94560"), Color(hex: "#1A1A2E")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(25)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: - 画廊列表

    private var galleryContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(companions) { companion in
                    companionCard(companion: companion)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }

    // MARK: - 单个伴侣卡片

    private func companionCard(companion: AICompanion) -> some View {
        let portrait = companion.portraitId.flatMap { portraits[$0] } ?? fallbackPortraits[companion.id]
        let imageUrl = portrait?.imageUrl
        let hexagram = portrait?.hexagram ?? ""
        let name = companion.personaSettings.name ?? "灵犀"
        let element = companion.personaSettings.element

        return NavigationLink(destination: SoulmateAIChatView(
            companionId: companion.id,
            portraitImageUrl: imageUrl
        )) {
            HStack(spacing: 16) {
                // 画像缩略图
                portraitThumbnail(imageUrl: imageUrl)

                // 伴侣信息
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(name)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)

                        Text(element)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(elementColor(element))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(elementColor(element).opacity(0.15))
                            .cornerRadius(10)
                    }

                    if !hexagram.isEmpty {
                        Text(hexagram)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(2)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#E94560").opacity(0.7))
                        Text("亲密度 \(companion.intimacyLevel)")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    let chatCount = chatCounts[companion.id] ?? 0
                    if chatCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.35))
                            Text("\(chatCount) 条对话")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.45))
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.07), lineWidth: 0.8)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .contextMenu {
            Button(role: .destructive) {
                companionToDelete = companion
                showDeleteAlert = true
            } label: {
                Label("删除伴侣", systemImage: "trash")
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func portraitThumbnail(imageUrl: String?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#1A1A2E"))
                .frame(width: 70, height: 90)

            if let urlString = imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 70)
                            .frame(height: 90, alignment: .top)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure, .empty:
                        placeholderThumbnail
                    @unknown default:
                        placeholderThumbnail
                    }
                }
            } else {
                placeholderThumbnail
            }
        }
        .frame(width: 70, height: 90)
    }

    private var placeholderThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#16213E"))
                .frame(width: 70, height: 90)
            Image(systemName: "person.fill")
                .font(.system(size: 28))
                .foregroundColor(Color(hex: "#E94560").opacity(0.4))
        }
    }

    private func elementColor(_ element: String) -> Color {
        switch element {
        case "金": return Color(hex: "#C0C0C0")
        case "木": return Color(hex: "#4CAF50")
        case "水": return Color(hex: "#2196F3")
        case "火": return Color(hex: "#E94560")
        case "土": return Color(hex: "#8B6914")
        default: return Color(hex: "#E94560")
        }
    }

    // MARK: - 删除

    private func performDelete(companion: AICompanion) async {
        do {
            try await AICompanionService.shared.deleteCompanion(
                id: companion.id,
                shadowUserId: companion.personaSettings.shadowUserId
            )
            companions.removeAll { $0.id == companion.id }
        } catch {
            print("❌ [Gallery] 删除伴侣失败: \(error)")
        }
    }

    // MARK: - 数据加载

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        companions = await AICompanionService.shared.fetchAllCompanions()

        // 收集所有 portrait_id
        let portraitIds = companions.compactMap { $0.portraitId }
        guard !portraitIds.isEmpty else { return }

        // 批量获取画像信息
        do {
            let idStrings = portraitIds.map { $0.uuidString }
            let fetched: [PortraitInfo] = try await supabase
                .from("generated_portraits")
                .select("id,image_url,hexagram")
                .in("id", values: idStrings)
                .execute()
                .value

            var map: [UUID: PortraitInfo] = [:]
            for p in fetched { map[p.id] = p }
            portraits = map
        } catch {
            print("❌ [Gallery] 获取画像信息失败: \(error)")
        }

        // 兜底：为没有 portrait_id 的历史伴侣找最近画像
        let companionsWithNoPortrait = companions.filter { $0.portraitId == nil }
        if !companionsWithNoPortrait.isEmpty, let userId = supabase.auth.currentUser?.id {
            var fallback: [UUID: PortraitInfo] = [:]
            let formatter = ISO8601DateFormatter()
            for companion in companionsWithNoPortrait {
                let cutoff = formatter.string(from: companion.createdAt)
                if let fetched = try? await supabase
                    .from("generated_portraits")
                    .select("id,image_url,hexagram")
                    .eq("user_id", value: userId.uuidString)
                    .lte("created_at", value: cutoff)
                    .order("created_at", ascending: false)
                    .limit(1)
                    .execute()
                    .value as [PortraitInfo],
                   let first = fetched.first {
                    fallback[companion.id] = first
                }
            }
            fallbackPortraits = fallback
        }

        // 加载各伴侣聊天条数
        do {
            struct CompanionIdRow: Decodable {
                let companionId: UUID
                enum CodingKeys: String, CodingKey { case companionId = "companion_id" }
            }
            let companionIdStrings = companions.map { $0.id.uuidString }
            if !companionIdStrings.isEmpty {
                let rows: [CompanionIdRow] = try await supabase
                    .from("chat_history")
                    .select("companion_id")
                    .in("companion_id", values: companionIdStrings)
                    .execute()
                    .value
                var counts: [UUID: Int] = [:]
                for r in rows { counts[r.companionId, default: 0] += 1 }
                chatCounts = counts
            }
        } catch {
            print("❌ [Gallery] 获取聊天条数失败: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        SoulmateGalleryView()
    }
}
