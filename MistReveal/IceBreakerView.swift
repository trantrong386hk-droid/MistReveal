import SwiftUI

/// 破冰话题选择界面
struct IceBreakerView: View {
    let user: MatchingService.MatchedUser
    let myRecord: SoulArchiveManager.UserGenerationRecord
    let onStartChat: (String) -> Void  // 选择话题后的回调
    let onDismiss: () -> Void

    @StateObject private var chatService = ChatService.shared
    @State private var topics: [String] = []
    @State private var isLoading = true
    @State private var customMessage = ""
    @State private var showCustomInput = false

    var body: some View {
        ZStack {
            // 背景
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // 内容卡片
            VStack(spacing: 0) {
                // 头部
                headerSection
                    .padding(.bottom, 20)

                // 双方信息
                userInfoSection
                    .padding(.bottom, 24)

                // 分割线
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                    .padding(.horizontal, 20)

                // 话题区域
                if isLoading {
                    loadingSection
                } else {
                    topicsSection
                }

                // 自定义输入
                if showCustomInput {
                    customInputSection
                }
            }
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(hex: "#1A1A2E"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "#E94560").opacity(0.5), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .padding(.horizontal, 24)
        }
        .onAppear {
            generateTopics()
        }
    }

    // MARK: - 头部

    private var headerSection: some View {
        VStack(spacing: 8) {
            // 关闭按钮
            HStack {
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)

            // 标题
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#E94560"))

                Text("灵魂共振")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#E94560"))
            }
        }
    }

    // MARK: - 用户信息

    private var userInfoSection: some View {
        HStack(spacing: 24) {
            // 我
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(elementColor(myRecord.analysisResult.userElement).opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: "person.fill")
                        .font(.system(size: 24))
                        .foregroundColor(elementColor(myRecord.analysisResult.userElement))
                }

                Text("我")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))

                Text("\(myRecord.analysisResult.userElement)命")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(elementColor(myRecord.analysisResult.userElement))
            }

            // 连接线和匹配度
            VStack(spacing: 4) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#E94560").opacity(0.3), Color(hex: "#E94560")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 30, height: 2)

                    ZStack {
                        Circle()
                            .fill(Color(hex: "#E94560").opacity(0.2))
                            .frame(width: 44, height: 44)

                        Circle()
                            .stroke(Color(hex: "#E94560"), lineWidth: 2)
                            .frame(width: 44, height: 44)

                        Text("\(user.matchScore)%")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#E94560"))
                    }

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#E94560"), Color(hex: "#E94560").opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 30, height: 2)
                }

                Text("匹配度")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }

            // 对方
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(elementColor(user.userElement).opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: "person.fill")
                        .font(.system(size: 24))
                        .foregroundColor(elementColor(user.userElement))
                }

                Text(user.nickname)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)

                Text("\(user.userElement)命")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(elementColor(user.userElement))
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 加载中

    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color(hex: "#E94560"))

            Text("AI 正在为你们生成话题...")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.vertical, 40)
    }

    // MARK: - 话题列表

    private var topicsSection: some View {
        VStack(spacing: 12) {
            Text("选择一个话题开始聊天")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 20)

            ForEach(Array(topics.enumerated()), id: \.offset) { index, topic in
                Button(action: {
                    onStartChat(topic)
                }) {
                    HStack {
                        Text(topicEmoji(index))
                            .font(.system(size: 18))

                        Text(topic)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "#E94560").opacity(0.6))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(.horizontal, 20)

            // 自定义按钮
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    showCustomInput.toggle()
                }
            }) {
                HStack {
                    Image(systemName: showCustomInput ? "chevron.up" : "pencil")
                        .font(.system(size: 14))

                    Text(showCustomInput ? "收起" : "或者，自己写一句开场白...")
                        .font(.system(size: 13))
                }
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 8)
            }
        }
    }

    // MARK: - 自定义输入

    private var customInputSection: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("写下你想说的话...", text: $customMessage)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )

                Button(action: {
                    if !customMessage.trimmingCharacters(in: .whitespaces).isEmpty {
                        onStartChat(customMessage)
                    }
                }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#E94560"), Color(hex: "#1A1A2E")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(12)
                }
                .disabled(customMessage.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(customMessage.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - 辅助方法

    private func generateTopics() {
        Task {
            let myTraits = myRecord.analysisResult.personalityTraits
            let theirTraits = user.personalityTraits

            topics = await chatService.generateIceBreakers(
                myElement: myRecord.analysisResult.userElement,
                myTraits: myTraits,
                theirElement: user.userElement,
                theirTraits: theirTraits,
                matchScore: user.matchScore
            )

            withAnimation {
                isLoading = false
            }
        }
    }

    private func topicEmoji(_ index: Int) -> String {
        let emojis = ["💬", "✨", "🌟"]
        return emojis[index % emojis.count]
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
