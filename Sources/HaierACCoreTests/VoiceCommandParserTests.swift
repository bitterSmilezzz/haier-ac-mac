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

    // MARK: - 智能睡眠温阶测试

    func testSmartSleepCurve() {
        let sc1 = VoiceCommandParser.parse("开启智能睡眠")
        XCTAssertEqual(sc1?.command, .startSleepCurve(curveName: "标准舒适"))

        let sc2 = VoiceCommandParser.parse("启动睡眠曲线")
        XCTAssertEqual(sc2?.command, .startSleepCurve(curveName: "标准舒适"))

        let sc3 = VoiceCommandParser.parse("开启儿童睡眠")
        XCTAssertEqual(sc3?.command, .startSleepCurve(curveName: "轻柔呵护"))

        let sc4 = VoiceCommandParser.parse("开启省电睡眠模式")
        XCTAssertEqual(sc4?.command, .startSleepCurve(curveName: "清爽省电"))

        let sc5 = VoiceCommandParser.parse("关闭智能睡眠")
        XCTAssertEqual(sc5?.command, .stopSleepCurve)

        let sc6 = VoiceCommandParser.parse("停止睡眠曲线")
        XCTAssertEqual(sc6?.command, .stopSleepCurve)
    }

    // MARK: - 全屋协同与自清洁测试 (v1.9.30)

    func testAllDevicesAndSelfCleaningControl() {
        // 全屋关机
        let off1 = VoiceCommandParser.parse("关闭所有空调")
        XCTAssertEqual(off1?.command, .turnOffAll)

        let off2 = VoiceCommandParser.parse("关掉所有空调")
        XCTAssertEqual(off2?.command, .turnOffAll)

        let off3 = VoiceCommandParser.parse("全屋关机")
        XCTAssertEqual(off3?.command, .turnOffAll)

        let off4 = VoiceCommandParser.parse("关闭全屋空调")
        XCTAssertEqual(off4?.command, .turnOffAll)

        // 全屋开机
        let on1 = VoiceCommandParser.parse("打开所有空调")
        XCTAssertEqual(on1?.command, .turnOnAll)

        let on2 = VoiceCommandParser.parse("开启所有空调")
        XCTAssertEqual(on2?.command, .turnOnAll)

        let on3 = VoiceCommandParser.parse("全屋开机")
        XCTAssertEqual(on3?.command, .turnOnAll)

        // 56°C 蒸发器自清洁
        let clean1 = VoiceCommandParser.parse("开启自清洁")
        XCTAssertEqual(clean1?.command, .startSelfCleaning)

        let clean2 = VoiceCommandParser.parse("清洗蒸发器")
        XCTAssertEqual(clean2?.command, .startSelfCleaning)

        let clean3 = VoiceCommandParser.parse("启动蒸发器自清洁")
        XCTAssertEqual(clean3?.command, .startSelfCleaning)

        let clean4 = VoiceCommandParser.parse("停止自清洁")
        XCTAssertEqual(clean4?.command, .stopSelfCleaning)

        let clean5 = VoiceCommandParser.parse("取消自清洁")
        XCTAssertEqual(clean5?.command, .stopSelfCleaning)
    }

    // MARK: - 口语化与定向房间测试 (v1.9.32)

    func testSpokenAndRoomPhrases() {
        // 口语全屋关
        let off1 = VoiceCommandParser.parse("把所有的空调都关了")
        XCTAssertEqual(off1?.command, .turnOffAll)

        let off2 = VoiceCommandParser.parse("把空调全都关了")
        XCTAssertEqual(off2?.command, .turnOffAll)

        let off3 = VoiceCommandParser.parse("全部空调关掉")
        XCTAssertEqual(off3?.command, .turnOffAll)

        // 口语全屋开
        let on1 = VoiceCommandParser.parse("把所有的空调都打开")
        XCTAssertEqual(on1?.command, .turnOnAll)

        let on2 = VoiceCommandParser.parse("把全部空调打开")
        XCTAssertEqual(on2?.command, .turnOnAll)

        // 房间定向与把字句单控
        let roomOff1 = VoiceCommandParser.parse("把客厅空调关了")
        XCTAssertEqual(roomOff1?.command, .setPower(false))

        let roomOff2 = VoiceCommandParser.parse("次卧空调关一下")
        XCTAssertEqual(roomOff2?.command, .setPower(false))

        let roomOff3 = VoiceCommandParser.parse("关闭次卧")
        XCTAssertEqual(roomOff3?.command, .setPower(false))

        let roomOn1 = VoiceCommandParser.parse("打开客厅空调")
        XCTAssertEqual(roomOn1?.command, .setPower(true))

        let roomOn2 = VoiceCommandParser.parse("开启主卧")
        XCTAssertEqual(roomOn2?.command, .setPower(true))

        // 房间定向调温与模式
        let roomTemp1 = VoiceCommandParser.parse("客厅调到26度")
        XCTAssertEqual(roomTemp1?.command, .setTemperature(26.0))

        let roomTemp2 = VoiceCommandParser.parse("次卧太热了")
        XCTAssertEqual(roomTemp2?.command, .adjustTemperature(delta: -1.0))

        let roomMode = VoiceCommandParser.parse("主卧切换到制热模式")
        XCTAssertEqual(roomMode?.command, .setMode("制热"))
    }

    // MARK: - 无效输入测试

    func testInvalidCommands() {
        XCTAssertNil(VoiceCommandParser.parse("今天天气怎么样"))
        XCTAssertNil(VoiceCommandParser.parse("播放音乐"))
        XCTAssertNil(VoiceCommandParser.parse(""))
    }
}
