import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @State private var isLanguageExpanded = false

    var body: some View {
        ZStack {
            Color(hex: "#0A0A12").ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {

                    // MARK: - 语言
                    sectionHeader(icon: "globe", title: "语言 / Language")

                    languagePickerCard

                    Text("切换语言后立即生效，无需重启 App\nLanguage change takes effect immediately")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.top, -16)

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
            }
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Language Picker Card（折叠式）

    private var languagePickerCard: some View {
        VStack(spacing: 0) {
            // 始终可见的当前语言行，点击展开/收起
            Button(action: {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isLanguageExpanded.toggle()
                }
            }) {
                HStack(spacing: 14) {
                    Image(systemName: languageManager.currentLanguage.icon)
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "#E94560"))
                        .frame(width: 28)

                    Text(languageManager.currentLanguage.displayName)
                        .font(.system(size: 16))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .rotationEffect(.degrees(isLanguageExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.22), value: isLanguageExpanded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // 展开后显示所有选项
            if isLanguageExpanded {
                Divider()
                    .background(Color.white.opacity(0.08))

                ForEach(Array(LanguageManager.AppLanguage.allCases.enumerated()), id: \.element) { index, lang in
                    languageRow(lang: lang, isLast: index == LanguageManager.AppLanguage.allCases.count - 1)
                }
            }
        }
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Section Header

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(hex: "#E94560"))
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
        }
    }

    // MARK: - Language Row

    private func languageRow(lang: LanguageManager.AppLanguage, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            Button(action: {
                languageManager.setLanguage(lang)
                withAnimation(.easeInOut(duration: 0.22)) {
                    isLanguageExpanded = false
                }
            }) {
                HStack(spacing: 14) {
                    Image(systemName: lang.icon)
                        .font(.system(size: 18))
                        .foregroundColor(languageManager.currentLanguage == lang ? Color(hex: "#E94560") : .white.opacity(0.5))
                        .frame(width: 28)

                    Text(lang.displayName)
                        .font(.system(size: 16))
                        .foregroundColor(.white)

                    Spacer()

                    if languageManager.currentLanguage == lang {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#E94560"))
                    } else {
                        Image(systemName: "circle")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.2))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isLast {
                Divider()
                    .background(Color.white.opacity(0.08))
                    .padding(.leading, 58)
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(LanguageManager.shared)
    }
}
