import XCTest
@testable import HaierACCore

final class VoiceCommandParserTests: XCTestCase {

    // MARK: - 开关机测试

    func testPowerControl() {
        // 开机
        let open1 = VoiceCommandParser.parse("打开空调")
        XCTAssertEqual(open1?.command, .setPower(true))

        let open2 = VoiceCommandParser.parse("开空调")
        XCTAssertEqual(open2?.command, .setPower(true))

        let open3 = VoiceCommandParser.parse("开机")
        XCTAssertEqual(open3?.command, .setPower(true))

        // 关机
        let close1 = VoiceCommandParser.parse("关闭空调")
        XCTAssertEqual(close1?.command, .setPower(false))

        let close2 = VoiceCommandParser.parse("关空调")
        XCTAssertEqual(close2?.command, .setPower(false))

        let close3 = VoiceCommandParser.parse("关掉空调")
        XCTAssertEqual(close3?.command, .setPower(false))

        let close4 = VoiceCommandParser.parse("关机")
        XCTAssertEqual(close4?.command, .setPower(false))

        let close5 = VoiceCommandParser.parse("别吹了")
        XCTAssertEqual(close5?.command, .setPower(false))
    }

    // MARK: - 绝对温度测试

    func testAbsoluteTemperature() {
        let t1 = VoiceCommandParser.parse("调到26度")
        XCTAssertEqual(t1?.command, .setTemperature(26.0))

        let t2 = VoiceCommandParser.parse("温度调到24度")
        XCTAssertEqual(t2?.command, .setTemperature(24.0))

        let t3 = VoiceCommandParser.parse("二十六度")
        XCTAssertEqual(t3?.command, .setTemperature(26.0))

        let t4 = VoiceCommandParser.parse("设为25.5度")
        XCTAssertEqual(t4?.command, .setTemperature(25.5))

        let t5 = VoiceCommandParser.parse("调到二十七度")
        XCTAssertEqual(t5?.command, .setTemperature(27.0))
    }

    // MARK: - 相对温度微调测试

    func testRelativeTemperature() {
        let hot = VoiceCommandParser.parse("太热了")
        XCTAssertEqual(hot?.command, .adjustTemperature(delta: -1.0))

        let cold = VoiceCommandParser.parse("太冷了")
        XCTAssertEqual(cold?.command, .adjustTemperature(delta: 1.0))

        let up1 = VoiceCommandParser.parse("调高一度")
        XCTAssertEqual(up1?.command, .adjustTemperature(delta: 1.0))

        let down2 = VoiceCommandParser.parse("降温两度")
        XCTAssertEqual(down2?.command, .adjustTemperature(delta: -2.0))

        let up2 = VoiceCommandParser.parse("升温2度")
        XCTAssertEqual(up2?.command, .adjustTemperature(delta: 2.0))
    }

    // MARK: - 模式切换测试

    func testModeSwitch() {
        let cool = VoiceCommandParser.parse("切换到制冷")
        XCTAssertEqual(cool?.command, .setMode("制冷"))

        let heat = VoiceCommandParser.parse("开暖气")
        XCTAssertEqual(heat?.command, .setMode("制热"))

        let fan = VoiceCommandParser.parse("吹风模式")
        XCTAssertEqual(fan?.command, .setMode("送风"))

        let dry = VoiceCommandParser.parse("除湿")
        XCTAssertEqual(dry?.command, .setMode("除湿"))

        let auto = VoiceCommandParser.parse("智能模式")
        XCTAssertEqual(auto?.command, .setMode("自动"))
    }

    // MARK: - 风速测试

    func testWindSpeed() {
        let high = VoiceCommandParser.parse("大风一点")
        XCTAssertEqual(high?.command, .setWindSpeed("强劲"))

        let low = VoiceCommandParser.parse("微风")
        XCTAssertEqual(low?.command, .setWindSpeed("微风"))

        let auto = VoiceCommandParser.parse("自动风")
        XCTAssertEqual(auto?.command, .setWindSpeed("自动"))
    }

    // MARK: - 状态查询测试

    func testQueryStatus() {
        let q1 = VoiceCommandParser.parse("现在多少度")
        XCTAssertEqual(q1?.command, .queryStatus)

        let q2 = VoiceCommandParser.parse("室内温度是多少")
        XCTAssertEqual(q2?.command, .queryStatus)

        let q3 = VoiceCommandParser.parse("当前温度")
        XCTAssertEqual(q3?.command, .queryStatus)
    }

    // MARK: - 情景模式测试

    func testScenes() {
        let s1 = VoiceCommandParser.parse("睡眠模式")
        XCTAssertEqual(s1?.command, .applyScene("睡眠"))

        let s2 = VoiceCommandParser.parse("离家模式")
        XCTAssertEqual(s2?.command, .applyScene("离家"))
    }

    // MARK: - 无效输入测试

    func testInvalidCommands() {
        XCTAssertNil(VoiceCommandParser.parse("今天天气怎么样"))
        XCTAssertNil(VoiceCommandParser.parse("播放音乐"))
        XCTAssertNil(VoiceCommandParser.parse(""))
    }
}
