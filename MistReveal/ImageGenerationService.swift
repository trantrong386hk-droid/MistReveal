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

    // MARK: - 生成图片
    func generateImage(prompt: String) async throws -> Data {
        print("🔵 [ImageGen] ========== 开始生成图片 ==========")

        // 1. 构建 Body 字典
        let bodyDict: [String: String] = [
            "req_key": "jimeng_high_aes_general_v21_L",
            "prompt": prompt
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
        let hashedCanonicalRequest = sha256Hex(canonicalRequest.data(using: .utf8)!)

        let stringToSign = "\(algorithm)\n\(xDate)\n\(credentialScope)\n\(hashedCanonicalRequest)"

        print("🔵 [ImageGen] ========== StringToSign ==========")
        print(stringToSign)
        print("🔵 [ImageGen] ====================================")

        // ===== Step 3: 派生签名密钥 (全部使用 UTF-8 编码) =====
        let skData = sk.data(using: .utf8)!
        let dateStampData = dateStamp.data(using: .utf8)!
        let regionData = region.data(using: .utf8)!
        let serviceData = service.data(using: .utf8)!
        let requestData = "request".data(using: .utf8)!

        let kDate = hmacSHA256(key: skData, data: dateStampData)
        let kRegion = hmacSHA256(key: kDate, data: regionData)
        let kService = hmacSHA256(key: kRegion, data: serviceData)
        let kSigning = hmacSHA256(key: kService, data: requestData)

        // ===== Step 4: 计算签名 =====
        let stringToSignData = stringToSign.data(using: .utf8)!
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
