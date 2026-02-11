import Foundation
import Supabase

/// 全局共享的 Supabase 客户端
/// 所有服务统一使用此实例，确保 auth session 一致
let supabase = SupabaseClient(
    supabaseURL: URL(string: AppConfig.Supabase.url)!,
    supabaseKey: AppConfig.Supabase.anonKey,
    options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
            autoRefreshToken: true,
            emitLocalSessionAsInitialSession: true
        )
    )
)
