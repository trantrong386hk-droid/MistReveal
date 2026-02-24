import SwiftUI

struct FateRecordsView: View {
    @State private var records: [ChatService.FateRecord] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedRecord: ChatService.FateRecord?
    @State private var recordToDelete: ChatService.FateRecord? = nil
    @State private var showDeleteAlert = false

    var body: some View {
        ZStack {
            Color(hex: "#0A0A12").ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(.white)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Text(error)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                    Button("重试") {
                        Task { await loadRecords() }
                    }
                    .foregroundColor(Color(hex: "#E94560"))
                }
                .padding(.horizontal, 40)
            } else if records.isEmpty {
                emptyStateView
            } else {
                recordsList
            }
        }
        .navigationTitle("缘分记录")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(false)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("缘分记录")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .navigationDestination(item: $selectedRecord) { record in
            let user = MatchingService.MatchedUser(
                id: record.partnerId,
                nickname: record.partnerNickname,
                latitude: 0,
                longitude: 0,
                matchScore: 0,
                userElement: record.partnerElement,
                personalityTraits: record.partnerPersonalityTraits,
                distance: 0,
                avatarUrl: record.partnerAvatarUrl,
                city: record.partnerCity,
                isShadow: false,
                analysisSummary: nil,
                portraitUrl: record.partnerPortraitUrl
            )
            ChatView(user: user, conversationId: record.id, initialMessage: nil)
        }
        .task {
            await loadRecords()
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) {
                if let r = recordToDelete {
                    Task { await performDelete(record: r) }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定删除这条缘分记录？相关聊天记录将被永久清除，无法恢复。")
        }
    }

    // MARK: - 子视图

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Text("✦")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "#E94560").opacity(0.6))

            Text("还没有缘分记录")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)

            Text("去星图探索与你有缘的灵魂")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))

            Button(action: {
                NotificationCenter.default.post(
                    name: NSNotification.Name("SwitchToStarMapTab"),
                    object: nil
                )
            }) {
                Text("去星图探索")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#E94560"))
                    .cornerRadius(20)
            }
        }
    }

    private var recordsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(records) { record in
                    Button(action: { selectedRecord = record }) {
                        recordCard(record)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            recordToDelete = record
                            showDeleteAlert = true
                        } label: {
                            Label("删除记录", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
    }

    private func recordCard(_ record: ChatService.FateRecord) -> some View {
        HStack(spacing: 14) {
            // 左侧头像/元素图标
            avatarView(record)

            // 中间信息
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(record.partnerNickname)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    elementTag(record.partnerElement)
                }

                if let city = record.partnerCity {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.4))
                        Text(city)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }

            Spacer()

            // 右侧时间 + chevron
            VStack(alignment: .trailing, spacing: 4) {
                Text(relativeTime(record.lastMessageAt))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func avatarView(_ record: ChatService.FateRecord) -> some View {
        let imageUrl = record.partnerAvatarUrl ?? record.partnerPortraitUrl
        if let urlString = imageUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    elementIconView(record.partnerElement)
                }
            }
            .frame(width: 50, height: 50)
            .clipShape(Circle())
        } else {
            elementIconView(record.partnerElement)
                .frame(width: 50, height: 50)
        }
    }

    private func elementIconView(_ element: String) -> some View {
        ZStack {
            Circle()
                .fill(elementColor(element).opacity(0.15))
            Text(elementSymbol(element))
                .font(.system(size: 20))
        }
    }

    private func elementTag(_ element: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: elementIcon(element))
                .font(.system(size: 10))
            Text("\(element)命")
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(elementColor(element))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(elementColor(element).opacity(0.15))
        .cornerRadius(8)
    }

    // MARK: - 删除

    private func performDelete(record: ChatService.FateRecord) async {
        do {
            try await ChatService.shared.deleteConversation(id: record.id)
            records.removeAll { $0.id == record.id }
        } catch {
            print("❌ [FateRecordsView] 删除缘分记录失败: \(error)")
        }
    }

    // MARK: - 辅助方法

    private func loadRecords() async {
        isLoading = true
        errorMessage = nil
        do {
            records = try await ChatService.shared.fetchFateRecords()
        } catch {
            errorMessage = "加载失败，请重试"
            print("❌ [FateRecordsView] 加载缘分记录失败: \(error)")
        }
        isLoading = false
    }

    private func relativeTime(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let diff = Date().timeIntervalSince(date)
        if diff < 60 { return "刚刚" }
        if diff < 3600 { return "\(Int(diff / 60))分钟前" }
        if diff < 86400 { return "今天" }
        let days = Int(diff / 86400)
        if days == 1 { return "昨天" }
        if days < 7 { return "\(days)天前" }
        if days < 30 { return "\(days / 7)周前" }
        return "\(days / 30)个月前"
    }

    private func elementSymbol(_ element: String) -> String {
        switch element {
        case "金": return "✦"
        case "木": return "🌿"
        case "水": return "💧"
        case "火": return "🔥"
        case "土": return "🪨"
        default: return "✦"
        }
    }

    private func elementIcon(_ element: String) -> String {
        switch element {
        case "金": return "sparkle"
        case "木": return "leaf.fill"
        case "水": return "drop.fill"
        case "火": return "flame.fill"
        case "土": return "mountain.2.fill"
        default: return "sparkles"
        }
    }

    private func elementColor(_ element: String) -> Color {
        switch element {
        case "金": return Color(hex: "#FFD700")
        case "木": return Color(hex: "#4CAF50")
        case "水": return Color(hex: "#2196F3")
        case "火": return Color(hex: "#FF5722")
        case "土": return Color(hex: "#8D6E63")
        default: return Color.white
        }
    }
}
