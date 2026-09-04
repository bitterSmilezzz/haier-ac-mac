import XCTest
@testable import HaierACCore

final class DigitalModelTests: XCTestCase {
    /// detailInfo[deviceId] 的 JSON 字符串包含 attributes 数组时正确拆包
    func testParsesDetailJsonString() throws {
        let json: [String: Any] = [
            "attributes": [
                [
                    "name": "power",
                    "desc": "电源",
                    "value": true,
                    "readable": true,
                    "writable": true,
                    "valueRange": [
                        "type": "list",
                        "dataList": [["data": true, "desc": "开"], ["data": false, "desc": "关"]],
                    ],
                ],
                [
                    "name": "tempSet",
                    "desc": "设定温度",
                    "value": 26,
                    "readable": true,
                    "writable": true,
                    "valueRange": ["type": "step", "dataStep": ["minValue": "16", "maxValue": "30", "step": "1"]],
                ],
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let detail = try XCTUnwrap(String(data: data, encoding: .utf8))

        let model = try XCTUnwrap(DigitalModel(detailJsonString: detail))
        XCTAssertEqual(model.attributes.count, 2)

        let power = model.attributes[0]
        XCTAssertEqual(power.name, "power")
        XCTAssertEqual(power.value, .bool(true))
        XCTAssertTrue(power.isBinarySwitch)
        XCTAssertEqual(power.boolValue, true)

        let temp = model.attributes[1]
        XCTAssertEqual(temp.name, "tempSet")
        XCTAssertEqual(temp.value, .int(26))
        XCTAssertEqual(temp.valueRange, Optional(.step(min: 16, max: 30, step: 1)))
    }

    /// 空 attributes / 复杂属性也不影响解析
    func testParsesEmptyAttributes() throws {
        let data = try JSONSerialization.data(withJSONObject: ["attributes": []])
        let detail = try XCTUnwrap(String(data: data, encoding: .utf8))
        let model = try XCTUnwrap(DigitalModel(detailJsonString: detail))
        XCTAssertTrue(model.attributes.isEmpty)
    }

    /// 非法 JSON、缺失 attributes、attributes 类型不对均返回 nil
    func testRejectsInvalidInput() {
        XCTAssertNil(DigitalModel(detailJsonString: "not json at all"))
        XCTAssertNil(DigitalModel(detailJsonString: ""))
        XCTAssertNil(DigitalModel(detailJsonString: "{\"foo\": 1}"))
        XCTAssertNil(DigitalModel(detailJsonString: "{\"attributes\": \"nope\"}"))
        XCTAssertNil(DigitalModel(detailJsonString: "{\"attributes\": {\"a\": 1}}"))
    }
}
