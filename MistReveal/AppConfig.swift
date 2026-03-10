import Foundation

/// App 配置 - 存放非敏感配置信息
/// API 密钥存储于 Supabase Edge Function Secrets（Deno 环境变量），通过代理 EF 调用外部 API
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

    // MARK: - MiniMax 大模型（灵犀对话）

    enum MiniMax {
        /// 模型名称
        /// 可选: M2-her, abab6.5s-chat（快速）, abab6.5-chat（标准）
        static let model = "M2-her"

        /// Edge Function 名称
        static let edgeFunction = "minimax-proxy"
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
