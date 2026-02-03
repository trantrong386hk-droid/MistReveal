import Foundation
import CryptoKit

/// 图片生成服务 - 使用火山引擎即梦 V2.1 API
class ImageGenerationService {

    static let shared = ImageGenerationService()
    private init() {}

    // MARK: - 配置
    private let host = "open.volcengineapi.com"
    private let action = "JimengHighAESGeneralV21L"
    private let version = "2024-06-06"
    private let region = "cn-beijing"
    private let service = "cv"

    // MARK: - 五行冷暖判断

    /// 用户五行平衡类型
    enum WuXingVibe {
        case cold    // 金/水旺 → 冷色调
        case hot     // 火/土旺 → 暖色调
        case neutral // 平衡或木旺
    }

    /// 根据五行计数判断用户的冷暖倾向
    private func analyzeUserVibe(metalCount: Int, woodCount: Int, waterCount: Int, fireCount: Int, earthCount: Int) -> WuXingVibe {
        let coldScore = metalCount + waterCount  // 金 + 水 = 冷
        let hotScore = fireCount + earthCount    // 火 + 土 = 暖

        if coldScore >= hotScore + 2 {
            return .cold
        } else if hotScore >= coldScore + 2 {
            return .hot
        } else {
            return .neutral
        }
    }

    // MARK: - 提示词后处理

    /// 对 AI 返回的 image_prompt 进行真实感强化 + 五行互补色调处理
    private func enhancePrompt(_ rawPrompt: String, userVibe: WuXingVibe) -> String {
        var prompt = rawPrompt

        // 替换背景描述：去掉纯灰色/摄影棚背景
        let studioPatterns = ["纯灰色背景", "灰色背景", "摄影棚灯光", "柔和摄影棚灯光", "纯色背景"]
        for pattern in studioPatterns {
            prompt = prompt.replacingOccurrences(of: pattern, with: "")
        }

        // 替换"正面面向镜头"为更自然的姿态
        prompt = prompt.replacingOccurrences(of: "正面面向镜头", with: "微侧面，自然不经意的回眸")

        // 清理多余逗号和空格
        prompt = prompt.replacingOccurrences(of: "，，", with: "，")
        prompt = prompt.replacingOccurrences(of: ",,", with: ",")
        prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        // 根据用户五行冷暖，选择互补的伴侣色调
        let vibeSuffix: String
        switch userVibe {
        case .cold:
            // 用户偏冷（金/水旺）→ 伴侣偏暖：温暖麦色肤、金色暖光、大地色系
            vibeSuffix = """
            ，warm sun-kissed skin tone，golden hour lighting with 3000K color temperature，\
            wearing burnt orange or forest green or warm earth tones，\
            radiant and protective vibe，soft warm background with subtle orange glow
            """
        case .hot:
            // 用户偏热（火/土旺）→ 伴侣偏冷：冷白皮肤、清晨冷光、银蓝色系
            vibeSuffix = """
            ，cool-toned porcelain skin，cool daylight at dawn with 6500K color temperature，\
            wearing midnight blue or silver gray or icy white，\
            calm and refreshing vibe，cool misty background with subtle blue tint
            """
        case .neutral:
            // 平衡 → 中性自然光
            vibeSuffix = """
            ，natural healthy skin tone，soft natural daylight，\
            wearing neutral earth tones or soft pastels，\
            gentle and balanced vibe，minimalist moody gray background with subtle fog
            """
        }

        // 追加真实感后缀（通用）
        let realisticSuffix = """
        ，candid look，ordinary but charming face，\
        35mm lens，cinematic documentary style，realistic skin texture with pore details，\
        no beauty filter，no airbrushed skin，natural imperfections，\
        shot on Fujifilm X-T5，film grain
        """

        prompt += vibeSuffix + realisticSuffix

        return prompt
    }

    // MARK: - 生成图片

    /// 生成伴侣画像
    /// - Parameters:
    ///   - prompt: AI 生成的原始 image_prompt
    ///   - baziInfo: 用户的八字信息（用于五行互补计算），可选
    func generateImage(prompt: String, baziInfo: BaZiInfo? = nil) async throws -> Data {
        print("🔵 [ImageGen] ========== 开始生成图片 ==========")

        // 分析用户五行冷暖倾向
        let userVibe: WuXingVibe
        if let bazi = baziInfo {
            userVibe = analyzeUserVibe(
                metalCount: bazi.metalCount,
                woodCount: bazi.woodCount,
                waterCount: bazi.waterCount,
                fireCount: bazi.fireCount,
                earthCount: bazi.earthCount
            )
            print("🔵 [ImageGen] 用户五行: 金\(bazi.metalCount) 木\(bazi.woodCount) 水\(bazi.waterCount) 火\(bazi.fireCount) 土\(bazi.earthCount)")
            print("🔵 [ImageGen] 用户倾向: \(userVibe) → 伴侣采用互补色调")
        } else {
            userVibe = .neutral
            print("🔵 [ImageGen] 无八字信息，使用中性色调")
        }

        // 对 prompt 进行真实感强化 + 五行互补处理
        let enhancedPrompt = enhancePrompt(prompt, userVibe: userVibe)
        print("🔵 [ImageGen] 原始 Prompt: \(prompt.prefix(80))...")
        print("🔵 [ImageGen] 强化 Prompt: \(enhancedPrompt.suffix(150))...")

        // 1. 构建 Body 字典
        let bodyDict: [String: String] = [
            "req_key": "jimeng_high_aes_general_v21_L",
            "prompt": enhancedPrompt
        ]

        // 2. 直接序列化为 Data，不做任何 String 转换
        let bodyData = try JSONSerialization.data(withJSONObject: bodyDict, options: [])

        // 调试：打印 Body 的十六进制表示（前50字节）
        let bodyHex = bodyData.prefix(50).map { String(format: "%02x", $0) }.joined(separator: " ")
        print("🔵 [ImageGen] Body Hex (前50字节): \(bodyHex)")
        print("🔵 [ImageGen] Body 长度: \(bodyData.count) bytes")

        // 3. 构建签名请求
        let request = try await buildRequest(bodyData: bodyData)

        // 4. 发送请求
        let (data, response) = try await URLSession.shared.data(for: request)
        let httpResponse = response as! HTTPURLResponse

        print("🔵 [ImageGen] ========== 响应 ==========")
        print("🔵 [ImageGen] 状态码: \(httpResponse.statusCode)")
        if let text = String(data: data, encoding: .utf8) {
            print("🔵 [ImageGen] 响应内容: \(text)")
        }

        guard httpResponse.statusCode == 200 else {
            throw ImageError.api(String(data: data, encoding: .utf8) ?? "未知错误")
        }

        // 5. 解析响应获取图片
        // 结构: Result -> data -> binary_data_base64
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["Result"] as? [String: Any],
              let dataObj = result["data"] as? [String: Any],
              let base64Array = dataObj["binary_data_base64"] as? [String],
              let firstBase64 = base64Array.first else {
            print("❌ [ImageGen] 解析失败，完整响应: \(String(data: data, encoding: .utf8) ?? "")")
            throw ImageError.noImage
        }

        // Base64 转 Data
        guard let imageData = Data(base64Encoded: firstBase64) else {
            print("❌ [ImageGen] Base64 解码失败")
            throw ImageError.noImage
        }

        print("✅ [ImageGen] 图片解码成功: \(imageData.count) bytes")
        return imageData
    }

    // MARK: - 构建签名请求
    private func buildRequest(bodyData: Data) async throws -> URLRequest {
        // ===== 从 SecretsManager 获取凭证 =====
        guard let ak = await SecretsManager.shared.getSecret("VOLCANO_ACCESS_KEY_ID") else {
            throw ImageError.api("无法获取 Access Key ID")
        }
        guard let sk = await SecretsManager.shared.getSecret("VOLCANO_SECRET_ACCESS_KEY") else {
            throw ImageError.api("无法获取 Secret Access Key")
        }

        print("🔵 [ImageGen] AK: \(ak)")
        print("🔵 [ImageGen] SK长度: \(sk.count)")

        // ===== 时间 (UTC) =====
        let now = Date()
        let fmt = DateFormatter()
        fmt.timeZone = TimeZone(identifier: "UTC")
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let xDate = fmt.string(from: now)
        fmt.dateFormat = "yyyyMMdd"
        let dateStamp = fmt.string(from: now)

        print("🔵 [ImageGen] X-Date: \(xDate)")
        print("🔵 [ImageGen] DateStamp: \(dateStamp)")

        // ===== URL =====
        let urlString = "https://\(host)/?Action=\(action)&Version=\(version)"
        guard let url = URL(string: urlString) else {
            throw ImageError.invalidURL
        }
        print("🔵 [ImageGen] URL: \(urlString)")

        // ===== Body Hash (直接对 bodyData 计算) =====
        let bodyHash = sha256Hex(bodyData)
        print("🔵 [ImageGen] Body SHA256: \(bodyHash)")

        // ===== Step 1: Canonical Request =====
        let httpMethod = "POST"
        let canonicalUri = "/"
        let canonicalQueryString = "Action=\(action)&Version=\(version)"
        let contentType = "application/json"

        // 构建 Canonical Headers (每行一个，按字母顺序，最后有换行)
        let canonicalHeaders = "content-type:\(contentType)\nhost:\(host)\nx-content-sha256:\(bodyHash)\nx-date:\(xDate)\n"
        let signedHeaders = "content-type;host;x-content-sha256;x-date"

        // 拼接 Canonical Request
        let canonicalRequest = "\(httpMethod)\n\(canonicalUri)\n\(canonicalQueryString)\n\(canonicalHeaders)\n\(signedHeaders)\n\(bodyHash)"

        print("🔵 [ImageGen] ========== CanonicalRequest ==========")
        print(canonicalRequest)
        print("🔵 [ImageGen] ========================================")

        // ===== Step 2: String to Sign =====
        let algorithm = "HMAC-SHA256"
        let credentialScope = "\(dateStamp)/\(region)/\(service)/request"
        let hashedCanonicalRequest = sha256Hex(canonicalRequest.data(using: String.Encoding.utf8)!)

        let stringToSign = "\(algorithm)\n\(xDate)\n\(credentialScope)\n\(hashedCanonicalRequest)"

        print("🔵 [ImageGen] ========== StringToSign ==========")
        print(stringToSign)
        print("🔵 [ImageGen] ====================================")

        // ===== Step 3: 派生签名密钥 (全部使用 UTF-8 编码) =====
        let skData: Data = sk.data(using: String.Encoding.utf8)!
        let dateStampData: Data = dateStamp.data(using: String.Encoding.utf8)!
        let regionData: Data = region.data(using: String.Encoding.utf8)!
        let serviceData: Data = service.data(using: String.Encoding.utf8)!
        let requestData: Data = "request".data(using: String.Encoding.utf8)!

        let kDate = hmacSHA256(key: skData, data: dateStampData)
        let kRegion = hmacSHA256(key: kDate, data: regionData)
        let kService = hmacSHA256(key: kRegion, data: serviceData)
        let kSigning = hmacSHA256(key: kService, data: requestData)

        // ===== Step 4: 计算签名 =====
        let stringToSignData: Data = stringToSign.data(using: String.Encoding.utf8)!
        let signatureData = hmacSHA256(key: kSigning, data: stringToSignData)
        let signature = signatureData.map { String(format: "%02x", $0) }.joined()

        print("🔵 [ImageGen] Signature: \(signature)")

        // ===== Step 5: Authorization Header =====
        let authorization = "\(algorithm) Credential=\(ak)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"

        print("🔵 [ImageGen] Authorization: \(authorization)")

        // ===== 构建 URLRequest =====
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.httpBody = bodyData  // 直接使用同一份 bodyData
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(host, forHTTPHeaderField: "Host")
        request.setValue(xDate, forHTTPHeaderField: "X-Date")
        request.setValue(bodyHash, forHTTPHeaderField: "X-Content-Sha256")
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 120

        return request
    }

    // MARK: - SHA256 (返回小写十六进制)
    private func sha256Hex(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - HMAC-SHA256 (返回 Data)
    private func hmacSHA256(key: Data, data: Data) -> Data {
        let symmetricKey = SymmetricKey(data: key)
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: symmetricKey)
        return Data(mac)
    }

    // MARK: - 错误
    enum ImageError: LocalizedError {
        case invalidURL, noImage, api(String)
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "无效URL"
            case .noImage: return "无图片数据"
            case .api(let msg): return msg
            }
        }
    }
}
