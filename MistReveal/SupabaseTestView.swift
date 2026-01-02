import SwiftUI
import Supabase

// Supabase 客户端初始化
let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://zbsqbarlzzqhhdcroxsp.supabase.co")!,
    supabaseKey: "sb_publishable_SC1cTCb7d4KpuIcx1EleDQ_pBi0hqnt"
)

struct SupabaseTestView: View {
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var debugLog: String = "点击按钮开始测试连接..."
    @State private var isLoading = false

    enum ConnectionStatus {
        case idle
        case success
        case failure
    }

    var body: some View {
        VStack(spacing: 24) {
            // 状态图标
            statusIcon

            // 调试日志
            debugLogView

            // 测试按钮
            testButton
        }
        .padding()
        .navigationTitle("Supabase 连接测试")
    }

    // MARK: - 状态图标
    var statusIcon: some View {
        Group {
            switch connectionStatus {
            case .idle:
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
            case .failure:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - 调试日志
    var debugLogView: some View {
        ScrollView {
            Text(debugLog)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .frame(height: 200)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - 测试按钮
    var testButton: some View {
        Button(action: {
            testConnection()
        }) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "wifi")
                }
                Text("测试连接")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isLoading ? Color.gray : Color.blue)
            .cornerRadius(12)
        }
        .disabled(isLoading)
    }

    // MARK: - 测试连接逻辑
    func testConnection() {
        isLoading = true
        connectionStatus = .idle
        debugLog = "[\(timestamp)] 开始测试连接...\n"
        debugLog += "[\(timestamp)] URL: https://zbsqbarlzzqhhdcroxsp.supabase.co\n"
        debugLog += "[\(timestamp)] 正在查询测试表...\n"

        Task {
            do {
                // 故意查询一个不存在的表来测试连接
                let _: [EmptyResponse] = try await supabase
                    .from("non_existent_table")
                    .select()
                    .execute()
                    .value

                // 如果没有抛出错误（不太可能），说明连接成功
                await MainActor.run {
                    debugLog += "[\(timestamp)] ✅ 连接成功！\n"
                    connectionStatus = .success
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    handleError(error)
                }
            }
        }
    }

    // MARK: - 错误处理
    func handleError(_ error: Error) {
        let errorString = String(describing: error)
        debugLog += "[\(timestamp)] 收到响应: \(errorString)\n\n"

        // 判断错误类型
        if errorString.contains("PGRST") ||
           errorString.contains("Could not find") ||
           errorString.contains("relation") && errorString.contains("does not exist") {
            // PostgreSQL REST API 错误，说明服务器已响应，连接成功
            debugLog += "[\(timestamp)] ✅ 连接成功（服务器已响应）\n"
            debugLog += "[\(timestamp)] 说明：收到数据库错误表示网络连接正常\n"
            connectionStatus = .success
        } else if errorString.contains("hostname") ||
                  errorString.contains("URL") ||
                  errorString.contains("NSURLErrorDomain") ||
                  errorString.contains("Could not connect") {
            // 网络错误
            debugLog += "[\(timestamp)] ❌ 连接失败：URL 错误或无网络\n"
            connectionStatus = .failure
        } else {
            // 其他错误
            debugLog += "[\(timestamp)] ⚠️ 未知错误：\(error.localizedDescription)\n"
            connectionStatus = .failure
        }

        isLoading = false
    }

    // MARK: - 时间戳
    var timestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
}

// 空响应结构体
struct EmptyResponse: Decodable {}

#Preview {
    NavigationStack {
        SupabaseTestView()
    }
}
