import Foundation
import CryptoKit

/// 海尔智家云请求签名器（与 banto6/haier 的 Python 实现一致）
public struct RequestSigner {
    public static let appId = "MB-UZHSH-0001"
    public static let appKey = "REPLACE_WITH_YOUR_APP_KEY"

    /// sign = sha256(urlPath + body去空白 + appId + appKey + timestamp)
    public static func sign(url: URL, body: String, timestamp: String) -> String {
        let cleanedBody = body
            .replacingOccurrences(of: "\t", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: " ", with: "")
        let content = url.path + cleanedBody + appId + appKey + timestamp
        return SHA256.hash(data: Data(content.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    /// 生成通用请求头
    public static func headers(url: URL, body: String, token: String, clientId: String) -> [String: String] {
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        let seqFormatter = DateFormatter()
        seqFormatter.dateFormat = "yyyyMMddHHmmss"
        let sequenceId = seqFormatter.string(from: Date()) + String(format: "%06d", Int.random(in: 100000...999999))

        return [
            "accessToken": token,
            "appId": appId,
            "appKey": appKey,
            "clientId": clientId,
            "sequenceId": sequenceId,
            "sign": sign(url: url, body: body, timestamp: timestamp),
            "timestamp": timestamp,
            "timezone": "+8",
            "language": "zh-CN",
            "Content-Type": "application/json",
        ]
    }
}
