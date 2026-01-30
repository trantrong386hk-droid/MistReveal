import SwiftUI

struct SoulArchiveView: View {
    @ObservedObject private var archiveManager = SoulArchiveManager.shared
    @State private var showAddFriendSheet = false
    @State private var friendNickname = ""
    @State private var navigateToInput = false
    @State private var selectedRecord: SoulArchiveManager.UserGenerationRecord?

    var body: some View {
        ZStack {
            // 背景
            Color(hex: "#0A0A12").ignoresSafeArea()

            if archiveManager.isLoading {
                loadingView
            } else if archiveManager.myRecord == nil && archiveManager.friendRecords.isEmpty {
                emptyStateView
            } else {
                contentView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("我的灵魂档案")
        .navigationDestination(isPresented: $navigateToInput) {
            CoordinatesInputView(forFriend: true, friendNickname: friendNickname)
        }
        .navigationDestination(item: $selectedRecord) { record in
            SoulArchiveDetailView(record: record)
        }
        .sheet(isPresented: $showAddFriendSheet) {
            addFriendSheet
        }
        .onAppear {
            Task {
                await archiveManager.fetchUserRecords()
            }
        }
    }

    // MARK: - 加载视图

    var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#E94560")))
                .scaleEffect(1.2)

            Text("加载中...")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - 空状态视图

    var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#E94560").opacity(0.6))

            VStack(spacing: 12) {
                Text("还没有灵魂档案")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)

                Text("去探索你的命定之人吧")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }

            Button(action: {
                // 跳转到首页
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToHomeTab"), object: nil)
            }) {
                Text("开始探索命定")
                    .font(.system(size: 15, weight: .medium))
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
    }

    // MARK: - 内容视图

    var contentView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // 我的命定
                if let myRecord = archiveManager.myRecord {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#E94560"))
                            Text("我的命定")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }

                        myRecordCard(record: myRecord)
                    }
                }

                // 帮朋友测过的
                if !archiveManager.friendRecords.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#E94560"))
                            Text("帮朋友测过的")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }

                        ForEach(archiveManager.friendRecords) { record in
                            friendRecordCard(record: record)
                        }
                    }
                }

                // 添加朋友按钮
                Button(action: {
                    showAddFriendSheet = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16))
                        Text("帮朋友测一测")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#E94560"))
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(Color(hex: "#E94560").opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(hex: "#E94560").opacity(0.3), lineWidth: 1)
                    )
                }

                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }

    // MARK: - 我的记录卡片

    func myRecordCard(record: SoulArchiveManager.UserGenerationRecord) -> some View {
        Button(action: {
            selectedRecord = record
        }) {
            HStack(spacing: 16) {
                // 左侧图片或占位
                if let imageUrl = record.imageUrl, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        portraitPlaceholder
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    portraitPlaceholder
                        .frame(width: 80, height: 80)
                }

                // 右侧信息
                VStack(alignment: .leading, spacing: 8) {
                    Text(formatBirthInfo(record: record))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))

                    Text("灵魂伴侣：\(record.analysisResult.destinyType)")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)

                    HStack(spacing: 4) {
                        Text("契合度")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                        Text("\(record.analysisResult.compatibilityScore)%")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(hex: "#E94560"))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(16)
            .background(Color.white.opacity(0.08))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(hex: "#E94560").opacity(0.4), lineWidth: 1)
            )
        }
    }

    // MARK: - 朋友记录卡片

    func friendRecordCard(record: SoulArchiveManager.UserGenerationRecord) -> some View {
        Button(action: {
            selectedRecord = record
        }) {
            HStack(spacing: 16) {
                // 头像占位
                ZStack {
                    Circle()
                        .fill(Color(hex: "#E94560").opacity(0.2))
                    Text(String(record.nickname.prefix(1)))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#E94560"))
                }
                .frame(width: 48, height: 48)

                // 信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.nickname)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)

                    Text(formatBirthInfo(record: record))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(record.analysisResult.destinyType)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#E94560"))

                    Text("\(record.analysisResult.compatibilityScore)%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
    }

    // MARK: - 头像占位符

    var portraitPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
            Image(systemName: "person.fill")
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.3))
        }
    }

    // MARK: - 添加朋友弹窗

    var addFriendSheet: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0A0A12").ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("为朋友测一测")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 20)

                    Text("输入朋友的昵称，帮 Ta 探索命定之人")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)

                    TextField("", text: $friendNickname, prompt: Text("朋友昵称").foregroundColor(.white.opacity(0.3)))
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)

                    Button(action: {
                        if !friendNickname.trimmingCharacters(in: .whitespaces).isEmpty {
                            showAddFriendSheet = false
                            navigateToInput = true
                        }
                    }) {
                        Text("开始测算")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Group {
                                    if friendNickname.trimmingCharacters(in: .whitespaces).isEmpty {
                                        Color.gray.opacity(0.3)
                                    } else {
                                        LinearGradient(
                                            colors: [Color(hex: "#E94560"), Color(hex: "#1A1A2E")],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    }
                                }
                            )
                            .cornerRadius(25)
                    }
                    .disabled(friendNickname.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        showAddFriendSheet = false
                    }
                    .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - 辅助方法

    func formatBirthInfo(record: SoulArchiveManager.UserGenerationRecord) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: record.birthDate)
        return "\(dateStr) · \(record.birthTime) · \(record.location)"
    }
}

// MARK: - Hashable 支持

extension SoulArchiveManager.UserGenerationRecord: Hashable {
    static func == (lhs: SoulArchiveManager.UserGenerationRecord, rhs: SoulArchiveManager.UserGenerationRecord) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    SoulArchiveView()
}
