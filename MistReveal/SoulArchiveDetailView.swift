import SwiftUI

struct SoulArchiveDetailView: View {
    @Environment(\.dismiss) var dismiss
    let record: SoulArchiveManager.UserGenerationRecord

    @State private var currentSection = 0  // 0: 灵魂分析, 1: 命定推导, 2: 伴侣画像

    var body: some View {
        ZStack {
            // 背景
            Color(hex: "#0A0A12").ignoresSafeArea()

            VStack(spacing: 0) {
                // 自定义导航栏
                customNavBar

                // 分段选择器
                sectionPicker

                // 内容区域
                TabView(selection: $currentSection) {
                    soulAnalysisSection
                        .tag(0)

                    destinyDeductionSection
                        .tag(1)

                    soulmatePortraitSection
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - 导航栏

    var customNavBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(.white)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(record.isSelf ? "我的命定" : record.nickname)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)

                Text(formatBirthInfo())
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // 占位，保持居中
            Color.clear.frame(width: 24, height: 24)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - 分段选择器

    var sectionPicker: some View {
        HStack(spacing: 0) {
            sectionTab(title: "灵魂分析", index: 0)
            sectionTab(title: "命定推导", index: 1)
            sectionTab(title: "伴侣画像", index: 2)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    func sectionTab(title: String, index: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentSection = index
            }
        }) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: currentSection == index ? .medium : .regular))
                    .foregroundColor(currentSection == index ? .white : .white.opacity(0.4))

                Rectangle()
                    .fill(currentSection == index ? Color(hex: "#E94560") : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 灵魂分析部分

    var soulAnalysisSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // 核心性格描述
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(icon: "sparkles", title: "你的灵魂印记")

                    Text(record.analysisResult.personalityDescription)
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.9))
                        .lineSpacing(6)
                        .padding(16)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(16)
                }

                // 性格特质
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(icon: "tag.fill", title: "性格特质")

                    FlowLayout(spacing: 10) {
                        ForEach(record.analysisResult.personalityTraits, id: \.self) { trait in
                            traitTag(trait, color: Color(hex: "#E94560"))
                        }
                    }
                }

                // 感情中的表现
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(icon: "heart.text.square.fill", title: "感情中的你")

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(record.analysisResult.relationshipBehaviors, id: \.self) { behavior in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(Color(hex: "#E94560"))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)

                                Text(behavior)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineSpacing(4)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                }

                // 情感需求
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(icon: "heart.fill", title: "你的情感需求")

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(record.analysisResult.emotionalNeeds, id: \.self) { need in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(hex: "#E94560"))

                                Text(need)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                }

                Spacer(minLength: 50)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - 命定推导部分

    var destinyDeductionSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // 推导卡片
                VStack(spacing: 16) {
                    ForEach(Array(record.analysisResult.matchingDeductions.enumerated()), id: \.offset) { _, deduction in
                        deductionCard(deduction: deduction)
                    }
                }

                // 伴侣特质
                VStack(alignment: .leading, spacing: 12) {
                    sectionHeader(icon: "heart.fill", title: "Ta 的灵魂特质")

                    FlowLayout(spacing: 10) {
                        ForEach(record.analysisResult.soulmateTraits, id: \.self) { trait in
                            traitTag(trait, color: Color(hex: "#E94560"))
                        }
                    }
                }

                // 契合度和缘分类型
                HStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Text("契合度")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))

                        Text("\(record.analysisResult.compatibilityScore)%")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(Color(hex: "#E94560"))
                    }
                    .frame(maxWidth: .infinity)

                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 1, height: 60)

                    VStack(spacing: 8) {
                        Text("缘分类型")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))

                        Text(record.analysisResult.destinyType)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 24)
                .background(Color.white.opacity(0.08))
                .cornerRadius(20)

                Spacer(minLength: 50)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - 伴侣画像部分

    var soulmatePortraitSection: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // 生成的图片
                if let imageUrl = record.imageUrl, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(20)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.1))
                            .aspectRatio(3/4, contentMode: .fit)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#E94560")))
                            )
                    }
                    .padding(.horizontal, 20)
                } else {
                    // 未生成图片
                    VStack(spacing: 16) {
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.3))

                        Text("尚未生成画像")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                    .padding(.horizontal, 20)
                }

                // 文字描述
                VStack(alignment: .leading, spacing: 20) {
                    // 初见印象
                    VStack(alignment: .leading, spacing: 8) {
                        Text("伴侣综述")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#E94560").opacity(0.8))

                        Text(record.analysisResult.soulmateAnalysis)
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.9))
                            .lineSpacing(6)
                    }

                    Divider().background(Color.white.opacity(0.1))

                    // 肤色脸型
                    appearanceDetailRow(
                        icon: "face.smiling",
                        title: "肤色脸型",
                        content: "\(record.analysisResult.soulmateAppearance.skinTone)，\(record.analysisResult.soulmateAppearance.faceShape)"
                    )

                    // 五官特征
                    appearanceDetailRow(
                        icon: "eyes",
                        title: "五官特征",
                        content: "\(record.analysisResult.soulmateAppearance.eyes)，\(record.analysisResult.soulmateAppearance.otherFeatures)"
                    )

                    // 发型穿着
                    appearanceDetailRow(
                        icon: "tshirt",
                        title: "发型穿着",
                        content: "\(record.analysisResult.soulmateAppearance.hair)；\(record.analysisResult.soulmateAppearance.clothing)"
                    )
                }
                .padding(20)
                .background(Color.white.opacity(0.08))
                .cornerRadius(20)
                .padding(.horizontal, 20)

                Spacer(minLength: 50)
            }
        }
    }

    // MARK: - 辅助组件

    func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#E94560"))

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .tracking(1)
        }
    }

    func traitTag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color.opacity(0.15))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
    }

    func deductionCard(deduction: MatchingDeduction) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("因为你")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))

                Text("【\(deduction.userTrait)】")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
            }

            Image(systemName: "arrow.down")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#E94560").opacity(0.6))

            HStack {
                Text("需要")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))

                Text("【\(deduction.soulmateTrait)】")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "#E94560"))

                Text("的人")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }

            if let explanation = deduction.explanation, !explanation.isEmpty {
                Text(explanation)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#E94560").opacity(0.3), lineWidth: 1)
        )
    }

    func appearanceDetailRow(icon: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "#E94560").opacity(0.7))

                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }

            Text(content)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(5)
        }
    }

    // MARK: - 辅助方法

    func formatBirthInfo() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: record.birthDate)
        return "\(record.gender) · \(dateStr) · \(record.birthTime)"
    }
}

#Preview {
    let mockResult = SoulAnalysisResult(
        hexagram: "震卦",
        userElement: "木",
        soulmateElement: "水",
        personalityDescription: "你是那种在聚会上看起来随和，其实内心早就想回家的人。",
        personalityTraits: ["外冷内热", "口嫌体正直", "表面佛系"],
        relationshipBehaviors: ["不会主动表达，但会默默记住对方说过的每一句话"],
        emotionalNeeds: ["被理解而不是被改变"],
        matchingDeductions: [
            MatchingDeduction(userTrait: "外冷内热", soulmateTrait: "温暖主动", explanation: "木命配水命，水生木滋养")
        ],
        soulmateTraits: ["温暖主动", "包容豁达"],
        compatibilityScore: 92,
        destinyType: "灵魂伴侣",
        soulmateAppearance: SoulmateAppearance(
            skinTone: "细腻水润，白皙透亮有光泽",
            faceShape: "圆润饱满的鹅蛋脸，线条柔和",
            eyes: "眼睛灵动明亮，眼波流转，睫毛浓密纤长",
            otherFeatures: "鼻梁挺直，嘴唇饱满红润，笑起来有浅浅酒窝",
            hair: "黑色中长发，自然微卷，发质柔顺有光泽",
            clothing: "浅蓝色真丝衬衫，质感轻盈飘逸"
        ),
        soulmateAnalysis: "你的灵魂伴侣是一个温暖的人，有着水命特有的灵动气质",
        promptToken: ""
    )

    let mockRecord = SoulArchiveManager.UserGenerationRecord(
        id: "1",
        soulAnalysisRecordId: "1",
        nickname: "我自己",
        isSelf: true,
        gender: "男",
        birthDate: Date(),
        birthTime: "卯时",
        location: "北京",
        analysisResult: mockResult,
        imageUrl: nil,
        createdAt: Date()
    )

    
    NavigationStack {
        SoulArchiveDetailView(record: mockRecord)
    }
}
