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

        let tooColdUp2 = VoiceCommandParser.parse("太冷了调高两度")
        XCTAssertEqual(tooColdUp2?.command, .adjustTemperature(delta: 2.0))
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

        let dry2 = VoiceCommandParser.parse("开启抽湿")
        XCTAssertEqual(dry2?.command, .setMode("除湿"))

        let auto = VoiceCommandParser.parse("智能模式")
        XCTAssertEqual(auto?.command, .setMode("自动"))
    }

    // MARK: - 风速测试

    func testWindSpeed() {
        let high = VoiceCommandParser.parse("大风一点")
        XCTAssertEqual(high?.command, .setWindSpeed("强劲"))

        let maxWind = VoiceCommandParser.parse("开到最大")
        XCTAssertEqual(maxWind?.command, .setWindSpeed("强劲"))

        let low = VoiceCommandParser.parse("微风")
        XCTAssertEqual(low?.command, .setWindSpeed("微风"))

        let quiet = VoiceCommandParser.parse("静音风")
        XCTAssertEqual(quiet?.command, .setWindSpeed("微风"))

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

    // MARK: - 定时与倒计时测试

    func testCountdown() {
        let c1 = VoiceCommandParser.parse("30分钟后关空调")
        XCTAssertEqual(c1?.command, .countdownPower(minutes: 30, power: false))

        let c2 = VoiceCommandParser.parse("半小时后关机")
        XCTAssertEqual(c2?.command, .countdownPower(minutes: 30, power: false))

        let c3 = VoiceCommandParser.parse("1小时后关机")
        XCTAssertEqual(c3?.command, .countdownPower(minutes: 60, power: false))

        let c4 = VoiceCommandParser.parse("一个半小时后关空调")
        XCTAssertEqual(c4?.command, .countdownPower(minutes: 90, power: false))

        let c5 = VoiceCommandParser.parse("两小时后关机")
        XCTAssertEqual(c5?.command, .countdownPower(minutes: 120, power: false))

        let c6 = VoiceCommandParser.parse("定时半小时关机")
        XCTAssertEqual(c6?.command, .countdownPower(minutes: 30, power: false))

        let c7 = VoiceCommandParser.parse("定时1小时关空调")
        XCTAssertEqual(c7?.command, .countdownPower(minutes: 60, power: false))

        let c8 = VoiceCommandParser.parse("倒计时45分钟关机")
        XCTAssertEqual(c8?.command, .countdownPower(minutes: 45, power: false))

        let c9 = VoiceCommandParser.parse("定时关机")
        XCTAssertEqual(c9?.command, .countdownPower(minutes: 60, power: false))

        let c10 = VoiceCommandParser.parse("10分钟后开空调")
        XCTAssertEqual(c10?.command, .countdownPower(minutes: 10, power: true))
    }

    func testScheduleTime() {
        let s1 = VoiceCommandParser.parse("晚上10点关空调")
        XCTAssertEqual(s1?.command, .schedulePower(hour: 22, minute: 0, power: false))

        let s2 = VoiceCommandParser.parse("今晚11点半关机")
        XCTAssertEqual(s2?.command, .schedulePower(hour: 23, minute: 30, power: false))

        let s3 = VoiceCommandParser.parse("明早7点开空调")
        XCTAssertEqual(s3?.command, .schedulePower(hour: 7, minute: 0, power: true))

        let s4 = VoiceCommandParser.parse("下午2点15分开机")
        XCTAssertEqual(s4?.command, .schedulePower(hour: 14, minute: 15, power: true))

        let s5 = VoiceCommandParser.parse("22:30关机")
        XCTAssertEqual(s5?.command, .schedulePower(hour: 22, minute: 30, power: false))
    }

    func testCancelSchedules() {
        let c1 = VoiceCommandParser.parse("取消定时")
        XCTAssertEqual(c1?.command, .cancelSchedules)

        let c2 = VoiceCommandParser.parse("取消倒计时")
        XCTAssertEqual(c2?.command, .cancelSchedules)

        let c3 = VoiceCommandParser.parse("清除定时")
        XCTAssertEqual(c3?.command, .cancelSchedules)
    }

    // MARK: - 无效输入测试

    func testInvalidCommands() {
        XCTAssertNil(VoiceCommandParser.parse("今天天气怎么样"))
        XCTAssertNil(VoiceCommandParser.parse("播放音乐"))
        XCTAssertNil(VoiceCommandParser.parse(""))
    }
}
