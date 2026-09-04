import XCTest
@testable import HaierACCore

final class DeviceAttributeTests: XCTestCase {
    // MARK: - 辅助构造

    private func makeAttribute(value: AttrValue?, valueRange: AttributeValueRange? = nil) -> DeviceAttribute {
        DeviceAttribute(
            name: "a",
            desc: "d",
            value: value,
            readable: true,
            writable: true,
            valueRange: valueRange
        )
    }

    // MARK: - STEP 范围

    /// minValue/maxValue 为字符串（服务器数字模型的常见形态）时正确转成 Double
    func testStepRangeFromStringNumbers() {
        let json: [String: Any] = [
            "name": "tempSet",
            "desc": "设定温度",
            "value": 26,
            "readable": true,
            "writable": true,
            "valueRange": [
                "type": "step",
                "dataStep": ["minValue": "16", "maxValue": "30", "step": "1"],
            ],
        ]
        let attr = DeviceAttribute(json: json)
        XCTAssertEqual(attr.name, "tempSet")
        XCTAssertEqual(attr.desc, "设定温度")
        XCTAssertEqual(attr.value, .int(26))
        XCTAssertEqual(attr.valueRange, Optional(.step(min: 16, max: 30, step: 1)))
    }

    /// 数值型 minValue/maxValue 同样支持；缺省 step 默认 1
    func testStepRangeFromNumbersAndDefaultStep() {
        let json: [String: Any] = [
            "name": "tempSet",
            "desc": "设定温度",
            "value": 26,
            "readable": true,
            "writable": true,
            "valueRange": ["type": "step", "dataStep": ["minValue": 16, "maxValue": 30]],
        ]
        let attr = DeviceAttribute(json: json)
        XCTAssertEqual(attr.valueRange, Optional(.step(min: 16, max: 30, step: 1)))
    }

    /// 小数步进与小数边界
    func testStepRangeWithFractionalValues() {
        let json: [String: Any] = [
            "name": "tempSet",
            "desc": "设定温度",
            "value": 26.5,
            "readable": true,
            "writable": true,
            "valueRange": ["type": "step", "dataStep": ["minValue": "16.5", "maxValue": "30.5", "step": "0.5"]],
        ]
        let attr = DeviceAttribute(json: json)
        XCTAssertEqual(attr.value, .double(26.5))
        XCTAssertEqual(attr.valueRange, Optional(.step(min: 16.5, max: 30.5, step: 0.5)))
    }

    /// minValue/maxValue 无法转 Double 时 valueRange 为 nil
    func testStepRangeInvalidMinMaxFallsBackToNil() {
        let json: [String: Any] = [
            "name": "bad",
            "desc": "bad",
            "value": NSNull(),
            "readable": false,
            "writable": false,
            "valueRange": ["type": "step", "dataStep": ["minValue": "abc", "maxValue": "30"]],
        ]
        XCTAssertNil(DeviceAttribute(json: json).valueRange)
    }

    // MARK: - LIST 范围

    func testListOptions() {
        let json: [String: Any] = [
            "name": "mode",
            "desc": "模式",
            "value": "cool",
            "readable": true,
            "writable": true,
            "valueRange": [
                "type": "list",
                "dataList": [
                    ["data": "cool", "desc": "制冷"],
                    ["data": "heat", "desc": "制热"],
                    ["data": "auto", "desc": "自动"],
                ],
            ],
        ]
        let attr = DeviceAttribute(json: json)
        guard case .list(let options)? = attr.valueRange else {
            return XCTFail("expected list valueRange")
        }
        XCTAssertEqual(options.count, 3)
        XCTAssertEqual(options[0].data, .string("cool"))
        XCTAssertEqual(options[0].desc, "制冷")
        XCTAssertEqual(options[1].data, .string("heat"))
        XCTAssertEqual(options[2].data, .string("auto"))
    }

    // MARK: - 二进制开关

    /// 字符串 "true"/"false" 两项列表 -> isBinarySwitch
    func testBinarySwitchWithStringValues() {
        let json: [String: Any] = [
            "name": "power",
            "desc": "电源",
            "value": "true",
            "readable": true,
            "writable": true,
            "valueRange": ["type": "list", "dataList": [["data": "true", "desc": "开"], ["data": "false", "desc": "关"]]],
        ]
        let attr = DeviceAttribute(json: json)
        XCTAssertTrue(attr.isBinarySwitch)
        XCTAssertEqual(attr.boolValue, true)
    }

    /// JSON 布尔 true/false 两项列表 -> isBinarySwitch
    func testBinarySwitchWithBoolValues() {
        let json: [String: Any] = [
            "name": "power",
            "desc": "电源",
            "value": false,
            "readable": true,
            "writable": true,
            "valueRange": ["type": "list", "dataList": [["data": true, "desc": "开"], ["data": false, "desc": "关"]]],
        ]
        let attr = DeviceAttribute(json: json)
        XCTAssertTrue(attr.isBinarySwitch)
        XCTAssertEqual(attr.boolValue, false)
    }

    /// 非 true/false 的两项列表（如 0/1）不是二进制开关
    func testIntPairIsNotBinarySwitch() {
        let json: [String: Any] = [
            "name": "power",
            "desc": "电源",
            "value": 1,
            "readable": true,
            "writable": true,
            "valueRange": ["type": "list", "dataList": [["data": 0, "desc": "关"], ["data": 1, "desc": "开"]]],
        ]
        let attr = DeviceAttribute(json: json)
        XCTAssertFalse(attr.isBinarySwitch)
        XCTAssertEqual(attr.boolValue, true) // int 1 -> true
    }

    /// 三项列表不是二进制开关
    func testThreeOptionsIsNotBinarySwitch() {
        let json: [String: Any] = [
            "name": "mode",
            "desc": "模式",
            "value": "cool",
            "readable": true,
            "writable": true,
            "valueRange": ["type": "list", "dataList": [["data": "cool", "desc": "制冷"], ["data": "heat", "desc": "制热"], ["data": "auto", "desc": "自动"]]],
        ]
        XCTAssertFalse(DeviceAttribute(json: json).isBinarySwitch)
    }

    /// 无 valueRange 的属性不是二进制开关
    func testNoRangeIsNotBinarySwitch() {
        XCTAssertFalse(makeAttribute(value: .bool(true)).isBinarySwitch)
    }

    // MARK: - boolValue / doubleValue

    func testBoolValueVariants() {
        XCTAssertEqual(makeAttribute(value: .bool(true)).boolValue, true)
        XCTAssertEqual(makeAttribute(value: .string("TRUE")).boolValue, true)
        XCTAssertEqual(makeAttribute(value: .string("false")).boolValue, false)
        XCTAssertEqual(makeAttribute(value: .int(1)).boolValue, true)
        XCTAssertEqual(makeAttribute(value: .int(0)).boolValue, false)
        // Double 与 null 不参与 bool 语义
        XCTAssertNil(makeAttribute(value: .double(1.0)).boolValue)
        XCTAssertNil(makeAttribute(value: nil).boolValue)
    }

    func testDoubleValueVariants() {
        XCTAssertEqual(makeAttribute(value: .double(22.5)).doubleValue, 22.5)
        XCTAssertEqual(makeAttribute(value: .int(26)).doubleValue, 26)
        XCTAssertEqual(makeAttribute(value: .string("16.5")).doubleValue, 16.5)
        XCTAssertNil(makeAttribute(value: .string("abc")).doubleValue)
        XCTAssertNil(makeAttribute(value: .bool(true)).doubleValue)
        XCTAssertNil(makeAttribute(value: nil).doubleValue)
    }

    // MARK: - 其他

    /// updating(value:) 返回带新值的副本，其余字段不变
    func testUpdatingValue() {
        let attr = DeviceAttribute(
            name: "power", desc: "电源", value: .bool(false),
            readable: true, writable: true, valueRange: nil
        )
        let updated = attr.updating(value: .bool(true))
        XCTAssertEqual(updated.value, .bool(true))
        XCTAssertEqual(updated.name, "power")
        XCTAssertEqual(updated.desc, "电源")
        XCTAssertEqual(updated.readable, true)
        XCTAssertEqual(updated.writable, true)
        XCTAssertEqual(attr.value, .bool(false)) // 原对象不受影响
    }

    func testMissingValueRangeParsesNil() {
        let json: [String: Any] = ["name": "plain", "desc": "普通属性", "value": "ok", "readable": true, "writable": false]
        let attr = DeviceAttribute(json: json)
        XCTAssertNil(attr.valueRange)
        XCTAssertEqual(attr.value, .string("ok"))
    }
}
