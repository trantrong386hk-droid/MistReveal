import Foundation

/// 图片生成服务 - 使用阿里云通义万相 API
class ImageGenerationService {

    static let shared = ImageGenerationService()

    private init() {}

    // MARK: - 配置 (使用 AppConfig 中的百炼 API Key)

    /// 通义万相 API 端点
    private let submitEndpoint = "https://dashscope.aliyuncs.com/api/v1/services/aigc/text2image/image-synthesis"
    private let taskEndpoint = "https://dashscope.aliyuncs.com/api/v1/tasks/"

    /// 模型名称
    private let model = "wanx-v1"  // 通义万相基础模型

    // MARK: - 数据模型

    /// 提交请求体
    private struct SubmitRequest: Encodable {
        let model: String
        let input: Input
        let parameters: Parameters

        struct Input: Encodable {
            let prompt: String
        }

        struct Parameters: Encodable {
            let size: String
            let n: Int
        }
    }

    /// 提交响应
    private struct SubmitResponse: Decodable {
        let request_id: String?
        let output: Output?
        let code: String?
        let message: String?

        struct Output: Decodable {
            let task_id: String?
            let task_status: String?
        }
    }

    /// 任务查询响应
    private struct TaskResponse: Decodable {
        let request_id: String?
        let output: Output?
        let code: String?
        let message: String?

        struct Output: Decodable {
            let task_id: String?
            let task_status: String?
            let results: [ImageResult]?
            let task_metrics: TaskMetrics?
        }

        struct ImageResult: Decodable {
            let url: String?
            let code: String?
            let message: String?
        }

        struct TaskMetrics: Decodable {
            let TOTAL: Int?
            let SUCCEEDED: Int?
            let FAILED: Int?
        }
    }

    // MARK: - 公开方法

    /// 根据提示词生成图片
    func generateImage(prompt: String) async throws -> Data {
        // 直接使用 AI 生成的优化提示词（已包含完整描述）
        let fullPrompt = prompt
        print("🔵 [ImageGeneration] 开始生成图片 (通义万相)")
        print("🔵 [ImageGeneration] Model: \(model)")
        print("🔵 [ImageGeneration] Prompt: \(fullPrompt.prefix(100))...")

        // 1. 提交任务
        let taskId = try await submitTask(prompt: fullPrompt)
        print("🔵 [ImageGeneration] 任务已提交，Task ID: \(taskId)")

        // 2. 轮询任务状态
        let imageUrl = try await pollTaskResult(taskId: taskId)
        print("🔵 [ImageGeneration] 图片生成完成，URL: \(imageUrl.prefix(80))...")

        // 3. 下载图片
        guard let url = URL(string: imageUrl) else {
            throw ImageGenerationError.invalidURL
        }
        let (imageData, _) = try await URLSession.shared.data(from: url)
        print("✅ [ImageGeneration] 图片下载成功，大小: \(imageData.count) bytes")

        return imageData
    }

    // MARK: - 私有方法

    /// 提交图片生成任务
    private func submitTask(prompt: String) async throws -> String {
        guard let url = URL(string: submitEndpoint) else {
            throw ImageGenerationError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(AppConfig.AliyunBailian.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("enable", forHTTPHeaderField: "X-DashScope-Async")
        request.timeoutInterval = 30

        let requestBody = SubmitRequest(
            model: model,
            input: .init(prompt: prompt),
            parameters: .init(size: "720*1280", n: 1)  // 竖版肖像 (9:16)
        )

        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageGenerationError.invalidResponse
        }

        // 调试日志
        if let responseText = String(data: data, encoding: .utf8) {
            print("🔵 [ImageGeneration] 提交响应: \(responseText.prefix(300))...")
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "未知错误"
            throw ImageGenerationError.apiError(statusCode: httpResponse.statusCode, message: errorText)
        }

        let submitResponse = try JSONDecoder().decode(SubmitResponse.self, from: data)

        // 检查错误
        if let code = submitResponse.code, code != "200" && !code.isEmpty {
            throw ImageGenerationError.apiError(
                statusCode: Int(code) ?? 0,
                message: submitResponse.message ?? "未知错误"
            )
        }

        guard let taskId = submitResponse.output?.task_id else {
            throw ImageGenerationError.noImageData
        }

        return taskId
    }

    /// 轮询任务结果
    private func pollTaskResult(taskId: String) async throws -> String {
        let maxAttempts = 60  // 最多等待 2 分钟
        let pollInterval: UInt64 = 2_000_000_000  // 2秒

        for attempt in 1...maxAttempts {
            print("🔵 [ImageGeneration] 查询任务状态... (第 \(attempt) 次)")

            let taskUrl = URL(string: taskEndpoint + taskId)!
            var request = URLRequest(url: taskUrl)
            request.httpMethod = "GET"
            request.setValue("Bearer \(AppConfig.AliyunBailian.apiKey)", forHTTPHeaderField: "Authorization")
            request.timeoutInterval = 15

            let (data, _) = try await URLSession.shared.data(for: request)

            let taskResponse = try JSONDecoder().decode(TaskResponse.self, from: data)

            // 检查错误
            if let code = taskResponse.code, code != "200" && !code.isEmpty {
                throw ImageGenerationError.apiError(
                    statusCode: Int(code) ?? 0,
                    message: taskResponse.message ?? "未知错误"
                )
            }

            let status = taskResponse.output?.task_status ?? ""
            print("🔵 [ImageGeneration] 任务状态: \(status)")

            switch status {
            case "SUCCEEDED":
                // 成功 - 返回图片 URL
                if let results = taskResponse.output?.results,
                   let firstResult = results.first,
                   let imageUrl = firstResult.url {
                    return imageUrl
                }
                throw ImageGenerationError.noImageData

            case "FAILED":
                // 失败
                let errorMsg = taskResponse.output?.results?.first?.message ?? "生成失败"
                throw ImageGenerationError.apiError(statusCode: 500, message: errorMsg)

            case "PENDING", "RUNNING":
                // 进行中 - 等待后继续轮询
                try await Task.sleep(nanoseconds: pollInterval)
                continue

            default:
                // 未知状态 - 等待后继续
                try await Task.sleep(nanoseconds: pollInterval)
                continue
            }
        }

        // 超时
        throw ImageGenerationError.timeout
    }

    // MARK: - API Key 验证

    /// 测试 API Key 是否有效
    func validateApiKey() async -> (isValid: Bool, message: String) {
        // 使用 models 接口验证
        guard let url = URL(string: "https://dashscope.aliyuncs.com/api/v1/models") else {
            return (false, "URL 无效")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(AppConfig.AliyunBailian.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, "响应无效")
            }

            if httpResponse.statusCode == 200 {
                return (true, "API Key 有效 (阿里云百炼)")
            } else {
                let errorText = String(data: data, encoding: .utf8) ?? "未知错误"
                return (false, "状态码 \(httpResponse.statusCode): \(errorText.prefix(100))")
            }
        } catch {
            return (false, "网络错误: \(error.localizedDescription)")
        }
    }

    // MARK: - 错误类型

    enum ImageGenerationError: LocalizedError {
        case invalidURL
        case invalidResponse
        case apiError(statusCode: Int, message: String)
        case noImageData
        case timeout

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "无效的 URL"
            case .invalidResponse:
                return "无效的响应"
            case .apiError(let statusCode, let message):
                return "API 错误 (\(statusCode)): \(message)"
            case .noImageData:
                return "未获取到图片数据"
            case .timeout:
                return "图片生成超时"
            }
        }
    }
}
