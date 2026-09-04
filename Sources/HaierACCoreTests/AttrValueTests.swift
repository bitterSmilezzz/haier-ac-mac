import XCTest
@testable import HaierACCore

final class AttrValueTests: XCTestCase {
    /// 各种 JSON 原生类型的初始化（JSONSerialization 解析产物 / 直接传值）
    func testInitFromJSONTypes() {
        let json: [String: Any] = [
            "s": "hello",
            "i": 42,
            "d": 3.5,
            "b": true,
            "n": NSNull(),
            "whole": 3.0,
            "big": 1e20,
            "negative": -7,
        ]
        XCTAssertEqual(AttrValue(json["s"] as Any), .string("hello"))
        XCTAssertEqual(AttrValue(json["i"] as Any), .int(42))
        XCTAssertEqual(AttrValue(json["d"] as Any), .double(3.5))
        XCTAssertEqual(AttrValue(json["b"] as Any), .bool(true))
        XCTAssertEqual(AttrValue(json["n"] as Any), .null)
        // 数值为整数的 Double 归一化为 Int
        XCTAssertEqual(AttrValue(json["whole"] as Any), .int(3))
        // 超大数值保持 Double（超出 Int 精度范围）
        XCTAssertEqual(AttrValue(json["big"] as Any), .double(1e20))
        XCTAssertEqual(AttrValue(json["negative"] as Any), .int(-7))
    }

    /// 直接以 Swift 值初始化
    func testInitFromSwiftValues() {
        XCTAssertEqual(AttrValue("abc"), .string("abc"))
        XCTAssertEqual(AttrValue(7), .int(7))
        XCTAssertEqual(AttrValue(2.5), .double(2.5))
        XCTAssertEqual(AttrValue(false), .bool(false))
        XCTAssertEqual(AttrValue(NSNull()), .null)
        XCTAssertEqual(AttrValue(NSNumber(value: 42)), .int(42))
        XCTAssertEqual(AttrValue(NSNumber(value: 3.5)), .double(3.5))
    }

    /// 无法识别的类型回退为 .null
    func testInitFromUnknownTypeFallsBackToNull() {
        XCTAssertEqual(AttrValue(NSArray()), .null)
        XCTAssertEqual(AttrValue(NSDictionary()), .null)
    }

    func testStringValue() {
        XCTAssertEqual(AttrValue.string("x").stringValue, "x")
        XCTAssertEqual(AttrValue.int(-12).stringValue, "-12")
        XCTAssertEqual(AttrValue.double(3.5).stringValue, "3.5")
        XCTAssertEqual(AttrValue.bool(true).stringValue, "true")
        XCTAssertEqual(AttrValue.bool(false).stringValue, "false")
        XCTAssertEqual(AttrValue.null.stringValue, "")
    }

    func testJsonValue() {
        XCTAssertEqual(AttrValue.string("a").jsonValue as? String, "a")
        XCTAssertEqual(AttrValue.int(5).jsonValue as? Int, 5)
        XCTAssertEqual(AttrValue.double(1.25).jsonValue as? Double, 1.25)
        XCTAssertEqual(AttrValue.bool(true).jsonValue as? Bool, true)
        XCTAssertTrue(AttrValue.null.jsonValue is NSNull)
    }

    /// JSON 序列化 -> AttrValue 解析 -> jsonValue 再序列化的往返一致性
    func testJsonRoundTrip() throws {
        let obj: [String: Any] = ["s": "hi", "i": 9, "d": 0.5, "b": false, "n": NSNull()]
        let data = try JSONSerialization.data(withJSONObject: obj)
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(AttrValue(parsed["s"] as Any), .string("hi"))
        XCTAssertEqual(AttrValue(parsed["i"] as Any), .int(9))
        XCTAssertEqual(AttrValue(parsed["d"] as Any), .double(0.5))
        XCTAssertEqual(AttrValue(parsed["b"] as Any), .bool(false))
        XCTAssertEqual(AttrValue(parsed["n"] as Any), .null)
    }
}
