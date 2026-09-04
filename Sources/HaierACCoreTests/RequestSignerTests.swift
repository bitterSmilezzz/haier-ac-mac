import XCTest
@testable import HaierACCore

final class RequestSignerTests: XCTestCase {
    /// 参考实现：sha256(urlPath + body去空白 + appId + appKey + timestamp) 的 hex 串。
    /// 期望值由 Python hashlib（与 banto6/haier 参考实现同算法）独立计算得出。
    func testSignKnownVectors() {
        let cases: [(path: String, body: String, timestamp: String, expected: String)] = [
            (
                "/dsm-appliance/v1/appliance/device/list",
                "{}",
                "1700000000000",
                "437e21719797cd8c0fbc0cab12179dfc61565b3b8dcbcdacb726c3d32da9d1b0"
            ),
            (
                "/dsm-appliance/v1/appliance/control",
                "{\n\t\"deviceId\": \"abc123\",\n\t\"power\": 1\n}\n",
                "1699999999999",
                "98aa0058388694ad1778c4fe45e62ed926173df7a438ccf7531292dd6982d1b4"
            ),
            (
                "/dsm-appliance/v1/appliance/attribute/digital-model",
                "{\"devices\":[{\"deviceId\":\"HD-A1-0001\",\"type\":\"airConditioner\"}]}",
                "1688888888888",
                "6b80837ff0d381362526fdfecd591bda9bc85a72964e03bf472756888d9c7dc2"
            ),
            (
                "/dsm-appliance/v1/appliance/control",
                "{\"list\":[1,2,3],\"nested\":{\"a\":true,\"b\":null,\"c\":\"x y\"}}",
                "1677777777777",
                "fbfa261a5937e138653133b2fa6f5dacff99fc6b6e496f2a45e5880905ba5841"
            ),
        ]
        for c in cases {
            let url = URL(string: "https://dsm.haier.net" + c.path)!
            XCTAssertEqual(
                RequestSigner.sign(url: url, body: c.body, timestamp: c.timestamp),
                c.expected,
                "path: \(c.path)"
            )
        }
    }

    /// 签名只取 url.path，忽略 query 参数
    func testSignIgnoresQueryString() {
        let body = "{\"power\":1}"
        let timestamp = "1700000000000"
        let withQuery = URL(string: "https://dsm.haier.net/dsm-appliance/v1/appliance/control?ver=2.0&lang=zh-CN")!
        let withoutQuery = URL(string: "https://dsm.haier.net/dsm-appliance/v1/appliance/control")!
        XCTAssertEqual(
            RequestSigner.sign(url: withQuery, body: body, timestamp: timestamp),
            RequestSigner.sign(url: withoutQuery, body: body, timestamp: timestamp)
        )
    }

    /// body 中的空白字符（空格/换行/制表符/回车）在签名前会被全部移除
    func testSignStripsAllWhitespaceFromBody() {
        let timestamp = "1699999999999"
        let url = URL(string: "https://dsm.haier.net/dsm-appliance/v1/appliance/control")!
        let messy = "{\n\t\"deviceId\": \"abc123\",\n\t\"power\": 1\n}\n"
        let compact = "{\"deviceId\":\"abc123\",\"power\":1}"
        XCTAssertEqual(
            RequestSigner.sign(url: url, body: messy, timestamp: timestamp),
            RequestSigner.sign(url: url, body: compact, timestamp: timestamp)
        )
    }

    /// 相同输入签名确定；timestamp 变化则签名变化
    func testSignDeterministicAndTimestampSensitive() {
        let url = URL(string: "https://dsm.haier.net/v1/appliance/device/list")!
        let body = "{}"
        XCTAssertEqual(
            RequestSigner.sign(url: url, body: body, timestamp: "1700000000000"),
            RequestSigner.sign(url: url, body: body, timestamp: "1700000000000")
        )
        XCTAssertNotEqual(
            RequestSigner.sign(url: url, body: body, timestamp: "1700000000000"),
            RequestSigner.sign(url: url, body: body, timestamp: "1700000000001")
        )
    }
}
