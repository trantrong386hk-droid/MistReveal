import Foundation

/// App 配置 - 存放非敏感配置信息
/// API 密钥已迁移至 Supabase app_secrets 表，通过 SecretsManager 获取
enum AppConfig {

    // MARK: - Supabase

    enum Supabase {
        /// Supabase URL
        static let url = "https://zbsqbarlzzqhhdcroxsp.supabase.co"

        /// Supabase Anon Key (公开的匿名密钥，可以安全提交到代码库)
        static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpic3FiYXJsenpxaGhkY3JveHNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjczNDkxMjAsImV4cCI6MjA4MjkyNTEyMH0.7NbknaHqgs-6W0xOCgb5rtGHBRcSy51dKOSSt5SboSc"
    }

    // MARK: - 阿里云百炼大模型

    enum AliyunBailian {
        /// API 端点
        static let baseURL = "https://dashscope.aliyuncs.com/compatible-mode/v1"

        /// 模型名称
        static let model = "qwen-plus"  // 可选: qwen-turbo, qwen-plus, qwen-max
    }

    // MARK: - 火山引擎即梦 (图片生成)

    enum VolcanoJimeng {
        /// API 端点
        static let baseURL = "https://open.volcengineapi.com"

        /// 区域
        static let region = "cn-north-1"

        /// 服务名
        static let service = "cv"
    }
}
