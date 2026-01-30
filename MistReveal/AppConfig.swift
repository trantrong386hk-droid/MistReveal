import Foundation

/// App 配置 - 存放 API 密钥
/// ⚠️ 重要提示：请在发布前将密钥移至安全存储（如 Keychain 或服务端）
enum AppConfig {

    // MARK: - 阿里云百炼大模型

    enum AliyunBailian {
        /// API Key
        /// TODO: 请填入你的阿里云百炼 API Key
        static let apiKey = "YOUR_ALIYUN_BAILIAN_API_KEY"

        /// API 端点
        static let baseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1"

        /// 模型名称
        static let model = "qwen-plus"  // 可选: qwen-turbo, qwen-plus, qwen-max
    }

    // MARK: - 火山引擎即梦 (图片生成)

    enum VolcanoJimeng {
        /// Access Key ID
        /// TODO: 请填入你的火山引擎 Access Key ID
        static let accessKeyId = "YOUR_VOLCENGINE_ACCESS_KEY_ID"

        /// Secret Access Key
        /// TODO: 请填入你的火山引擎 Secret Access Key
        static let secretAccessKey = "YOUR_VOLCENGINE_SECRET_ACCESS_KEY"

        /// API 端点
        static let baseURL = "https://visual.volcengineapi.com"

        /// 服务名称
        static let serviceName = "cv"

        /// 区域
        static let region = "cn-north-1"
    }
}
