import SwiftUI

struct CoordinatesInputView: View {
    @Environment(\.dismiss) var dismiss

    // 数据状态
    @State private var birthDate = Date()
    @State private var gender: String = "" // 乾 (男) / 坤 (女)
    @State private var location: String = ""
    @State private var birthTime: String = "子时"

    // 导航
    @State private var navigateToReport = false

    let timeSlots = [
        "子时 (23:00-01:00)",
        "丑时 (01:00-03:00)",
        "寅时 (03:00-05:00)",
        "卯时 (05:00-07:00)",
        "辰时 (07:00-09:00)",
        "巳时 (09:00-11:00)",
        "午时 (11:00-13:00)",
        "未时 (13:00-15:00)",
        "申时 (15:00-17:00)",
        "酉时 (17:00-19:00)",
        "戌时 (19:00-21:00)",
        "亥时 (21:00-23:00)"
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景保持一致：深邃星空
                Color(hex: "#0A0A12").ignoresSafeArea()

                // 装饰星云 - 使用相对尺寸
                Circle()
                    .fill(Color(hex: "#16213E").opacity(0.6))
                    .frame(width: min(geometry.size.width, 350), height: min(geometry.size.width, 350))
                    .blur(radius: 80)
                    .offset(x: -geometry.size.width * 0.35, y: -geometry.size.height * 0.25)

                VStack(spacing: 0) {
                // 1. 模仿 Starla 的自定义导航栏
                customNavBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 30) {
                        // 标题引导
                        VStack(alignment: .leading, spacing: 12) {
                            Text("溯源初生")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .tracking(2)
                            Text("录入你的时空坐标，打捞沉睡的灵魂")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                        // 2. 输入区域 - 毛玻璃卡片组合
                        VStack(spacing: 20) {

                            // 性别选择 (男/女)
                            inputCard(title: "性灵属性") {
                                HStack(spacing: 20) {
                                    genderButton(title: "男", isSelected: gender == "男") { gender = "男" }
                                    genderButton(title: "女", isSelected: gender == "女") { gender = "女" }
                                }
                            }

                            // 生日选择
                            inputCard(title: "降临日期") {
                                DatePicker("", selection: $birthDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .environment(\.locale, Locale(identifier: "zh_CN"))
                                    .colorInvert() // 使其在深色背景下显示清晰
                                    .colorMultiply(.white)
                            }

                            // 时辰选择
                            inputCard(title: "出生时辰") {
                                Picker("时辰", selection: $birthTime) {
                                    ForEach(timeSlots, id: \.self) { time in
                                        Text(time).tag(time)
                                    }
                                }
                                .pickerStyle(.menu)
                                .accentColor(.white)
                            }

                            // 地点输入
                            inputCard(title: "现世坐标") {
                                TextField("输入出生城市", text: $location)
                                    .foregroundColor(.white)
                                    .font(.system(size: 16))
                                    .tint(Color(hex: "#E94560"))
                            }
                        }
                        .padding(.horizontal, 24)

                        // 3. 开启按钮
                        Button(action: {
                            navigateToReport = true
                        }) {
                            Text("开启灵魂推演")
                                .font(.system(size: 16, weight: .bold))
                                .tracking(4)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(
                                    LinearGradient(colors: [Color(hex: "#E94560"), Color(hex: "#1A1A2E")], startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(30)
                                .shadow(color: Color(hex: "#E94560").opacity(0.3), radius: 20, x: 0, y: 10)
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
            }
            .clipped()
        }
        .navigationBarHidden(true) // 隐藏原生导航栏
        .navigationDestination(isPresented: $navigateToReport) {
            ReportView(
                birthDate: birthDate,
                gender: gender,
                birthTime: birthTime,
                location: location
            )
        }
    }

    // --- 子组件 ---

    // 模仿 Starla 极简导航栏
    var customNavBar: some View {
        HStack {
            // 起始页无返回按钮，用空白占位
            Color.clear.frame(width: 24, height: 24)

            Spacer()

            Text("时空坐标")
                .font(.system(size: 12, weight: .light))
                .tracking(4)
                .foregroundColor(.white.opacity(0.6))

            Spacer()

            // 进度小点 - 第一步
            HStack(spacing: 4) {
                Circle().fill(Color.white).frame(width: 4, height: 4)
                Circle().fill(Color.white.opacity(0.3)).frame(width: 4, height: 4)
                Circle().fill(Color.white.opacity(0.3)).frame(width: 4, height: 4)
                Circle().fill(Color.white.opacity(0.3)).frame(width: 4, height: 4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 10)
        .frame(height: 50)
    }

    // 通用输入卡片
    func inputCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.4))
                .tracking(1)

            HStack {
                content()
                Spacer()
            }
            .padding()
            .background(.white.opacity(0.05))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    // 性别按钮
    func genderButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .white : .white.opacity(0.4))
                .frame(width: 80, height: 40)
                .background(isSelected ? Color(hex: "#E94560").opacity(0.4) : Color.white.opacity(0.05))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color(hex: "#E94560") : Color.clear, lineWidth: 1)
                )
        }
    }
}

#Preview {
    CoordinatesInputView()
}
