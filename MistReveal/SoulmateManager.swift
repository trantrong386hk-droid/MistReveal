import Foundation
import SwiftUI

/// 灵魂伴侣生成管理器 - 中控类
/// 负责协调文本生成和图片生成的完整流水线
@MainActor
class SoulmateManager: ObservableObject {

    static let shared = SoulmateManager()

    // MARK: - 发布属性

    /// 当前状态
    @Published var state: GenerationState = .idle

    /// 生成结果
    @Published var result: SoulmateResult?

    /// 灵魂分析结果（新增）
    @Published var soulAnalysis: SoulAnalysisResult?

    /// 错误信息
    @Published var errorMessage: String?

    /// 进度文案
    @Published var progressText: String = ""

    // MARK: - 数据模型

    /// 生成状态
    enum GenerationState {
        case idle               // 空闲
        case analyzingSelf      // 新增：分析用户
        case analyzing          // 正在分析卦象（保留兼容）
        case analyzingSoulmate  // 分析伴侣
        case generating         // 正在生成画像
        case completed          // 完成
        case failed             // 失败
    }

    /// 灵魂伴侣结果
    struct SoulmateResult {
        let hexagram: String      // 卦象名称
        let analysis: String      // 性格外貌描述
        let imagePrompt: String   // 生图提示词
        let imageData: Data       // 图片数据
        let birthDate: String     // 输入的生辰
    }

    // MARK: - 初始化

    private init() {}

    // MARK: - 公开方法

    /// 生成灵魂伴侣
    /// - Parameters:
    ///   - birthDate: 出生日期，格式如 "1990年5月15日"
    ///   - gender: 性灵属性（乾/坤）
    ///   - birthTime: 出生时辰
    ///   - location: 出生地点
    func generateSoulmate(
        birthDate: String,
        gender: String,
        birthTime: String,
        location: String
    ) async {
        print("🔮 [SoulmateManager] 开始生成灵魂伴侣流程")
        print("🔮 [SoulmateManager] 输入信息:")
        print("   - 生辰: \(birthDate)")
        print("   - 性别: \(gender)")
        print("   - 时辰: \(birthTime)")
        print("   - 地点: \(location)")

        // 重置状态
        state = .analyzing
        result = nil
        errorMessage = nil
        progressText = "连山易推演中..."

        do {
            // 第一步：调用阿里云百炼，获取分析文字和生图提示词
            print("🔮 [SoulmateManager] 第一步：调用文本生成服务...")
            progressText = "推算艮卦山势..."

            let soulmateData = try await TextGenerationService.shared.fetchSoulmateData(
                birthDate: birthDate,
                gender: gender,
                birthTime: birthTime,
                location: location
            )

            print("🔮 [SoulmateManager] 文本生成完成")
            print("   - 卦象: \(soulmateData.hexagram)")
            print("   - 分析文字: \(soulmateData.analysis.prefix(50))...")
            print("   - 生图提示词: \(soulmateData.imagePrompt.prefix(50))...")

            // 第二步：调用火山引擎即梦，生成图片
            print("🔮 [SoulmateManager] 第二步：调用图片生成服务...")
            state = .generating
            progressText = "凝聚灵力，化形中..."

            let imageData = try await ImageGenerationService.shared.generateImage(prompt: soulmateData.imagePrompt)

            print("🔮 [SoulmateManager] 图片生成完成，大小: \(imageData.count) bytes")

            // 组合结果
            let finalResult = SoulmateResult(
                hexagram: soulmateData.hexagram,
                analysis: soulmateData.analysis,
                imagePrompt: soulmateData.imagePrompt,
                imageData: imageData,
                birthDate: birthDate
            )

            // 更新状态
            result = finalResult
            state = .completed
            progressText = ""

            print("✅ [SoulmateManager] 灵魂伴侣生成完成！")

        } catch {
            print("❌ [SoulmateManager] 生成失败: \(error)")
            state = .failed
            errorMessage = "天机模糊，请稍后再试"
            progressText = ""
        }
    }

    /// 重置状态
    func reset() {
        state = .idle
        result = nil
        soulAnalysis = nil
        errorMessage = nil
        progressText = ""
    }

    // MARK: - 灵魂分析流程（新版）

    /// 开始灵魂分析（第一阶段：分析用户）
    /// - Parameters:
    ///   - birthDate: 出生日期，格式如 "1990年5月15日"
    ///   - gender: 性别（男/女）
    ///   - birthTime: 出生时辰
    ///   - location: 出生地点
    func startSoulAnalysis(
        birthDate: String,
        gender: String,
        birthTime: String,
        location: String
    ) async {
        print("🔮 [SoulmateManager] 开始灵魂分析流程")
        print("🔮 [SoulmateManager] 输入信息:")
        print("   - 生辰: \(birthDate)")
        print("   - 性别: \(gender)")
        print("   - 时辰: \(birthTime)")
        print("   - 地点: \(location)")

        // 重置状态
        state = .analyzingSelf
        soulAnalysis = nil
        result = nil
        errorMessage = nil
        progressText = "正在解读你的灵魂印记..."

        do {
            // 调用阿里云百炼，获取完整的灵魂分析
            print("🔮 [SoulmateManager] 调用灵魂分析服务...")

            let analysis = try await TextGenerationService.shared.fetchSoulAnalysis(
                birthDate: birthDate,
                gender: gender,
                birthTime: birthTime,
                location: location
            )

            print("🔮 [SoulmateManager] 灵魂分析完成")
            print("   - 性格特质: \(analysis.personalityTraits)")
            print("   - 契合度: \(analysis.compatibilityScore)%")

            // 保存分析结果
            soulAnalysis = analysis
            state = .idle
            progressText = ""

            print("✅ [SoulmateManager] 灵魂分析阶段完成！")

        } catch {
            print("❌ [SoulmateManager] 灵魂分析失败: \(error)")
            state = .failed
            errorMessage = "分析失败，请稍后再试"
            progressText = ""
        }
    }

    /// 继续生成画像（第二阶段：基于已有的灵魂分析生成图片）
    func continueWithImageGeneration(birthDate: String) async {
        guard let analysis = soulAnalysis else {
            print("❌ [SoulmateManager] 没有灵魂分析结果，无法生成画像")
            return
        }

        print("🔮 [SoulmateManager] 开始生成画像...")
        state = .generating
        progressText = "凝聚灵力，化形中..."

        do {
            let imageData = try await ImageGenerationService.shared.generateImage(prompt: analysis.imagePrompt)

            print("🔮 [SoulmateManager] 图片生成完成，大小: \(imageData.count) bytes")

            // 组合结果
            let finalResult = SoulmateResult(
                hexagram: analysis.hexagram,
                analysis: analysis.soulmateAnalysis,
                imagePrompt: analysis.imagePrompt,
                imageData: imageData,
                birthDate: birthDate
            )

            // 更新状态
            result = finalResult
            state = .completed
            progressText = ""

            print("✅ [SoulmateManager] 画像生成完成！")

        } catch {
            print("❌ [SoulmateManager] 画像生成失败: \(error)")
            state = .failed
            errorMessage = "画像生成失败，请稍后再试"
            progressText = ""
        }
    }
}
