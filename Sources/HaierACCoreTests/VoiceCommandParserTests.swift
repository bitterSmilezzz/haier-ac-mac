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

        // “开”字前缀绝对调温（口语高频指令，闭环 v1.9.38 误判为单纯开机缺陷，v1.9.40 覆盖省略“度”字口语）
        let t6 = VoiceCommandParser.parse("开26度")
        XCTAssertEqual(t6?.command, .setTemperature(26.0))

        let t7 = VoiceCommandParser.parse("开到26度")
        XCTAssertEqual(t7?.command, .setTemperature(26.0))

        let t8 = VoiceCommandParser.parse("打开26度")
        XCTAssertEqual(t8?.command, .setTemperature(26.0))

        let t9 = VoiceCommandParser.parse("空调开26度")
        XCTAssertEqual(t9?.command, .setTemperature(26.0))

        let t10 = VoiceCommandParser.parse("开26")
        XCTAssertEqual(t10?.command, .setTemperature(26.0))

        let t11 = VoiceCommandParser.parse("打开25")
        XCTAssertEqual(t11?.command, .setTemperature(25.0))

        let t12 = VoiceCommandParser.parse("开24")
        XCTAssertEqual(t12?.command, .setTemperature(24.0))
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

        // “开”字前缀模式切换（口语高频指令，闭环 v1.9.38 误判为单纯开机缺陷）
        let dry3 = VoiceCommandParser.parse("开除湿")
        XCTAssertEqual(dry3?.command, .setMode("除湿"))

        let dry4 = VoiceCommandParser.parse("打开除湿")
        XCTAssertEqual(dry4?.command, .setMode("除湿"))

        let cool2 = VoiceCommandParser.parse("开制冷")
        XCTAssertEqual(cool2?.command, .setMode("制冷"))

        let heat2 = VoiceCommandParser.parse("开制热")
        XCTAssertEqual(heat2?.command, .setMode("制热"))

        let fan2 = VoiceCommandParser.parse("开送风")
        XCTAssertEqual(fan2?.command, .setMode("送风"))

        let auto2 = VoiceCommandParser.parse("开自动模式")
        XCTAssertEqual(auto2?.command, .setMode("自动"))

        let auto = VoiceCommandParser.parse("智能模式")
        XCTAssertEqual(auto?.command, .setMode("自动"))
    }

    // MARK: - 模式与温度复合指令测试 (v1.9.39 彻底解决复合口令模式丢失缺陷)

    func testModeAndTemperature() {
        // 单设备/定向设备复合模式与温度
        let c1 = VoiceCommandParser.parse("制冷26度")
        XCTAssertEqual(c1?.command, .setModeAndTemperature(mode: "制冷", temperature: 26.0))
        XCTAssertEqual(c1?.displayText, "清爽制冷 26°C")

        let c2 = VoiceCommandParser.parse("开制冷26度")
        XCTAssertEqual(c2?.command, .setModeAndTemperature(mode: "制冷", temperature: 26.0))

        let c3 = VoiceCommandParser.parse("开冷气25度")
        XCTAssertEqual(c3?.command, .setModeAndTemperature(mode: "制冷", temperature: 25.0))

        let h1 = VoiceCommandParser.parse("制热20度")
        XCTAssertEqual(h1?.command, .setModeAndTemperature(mode: "制热", temperature: 20.0))
        XCTAssertEqual(h1?.displayText, "舒适制热 20°C")

        let h2 = VoiceCommandParser.parse("开暖气22度")
        XCTAssertEqual(h2?.command, .setModeAndTemperature(mode: "制热", temperature: 22.0))

        let h3 = VoiceCommandParser.parse("开制热二十度")
        XCTAssertEqual(h3?.command, .setModeAndTemperature(mode: "制热", temperature: 20.0))

        let r1 = VoiceCommandParser.parse("客厅制冷26度")
        XCTAssertEqual(r1?.command, .setModeAndTemperature(mode: "制冷", temperature: 26.0))

        let r2 = VoiceCommandParser.parse("主卧开暖气21度")
        XCTAssertEqual(r2?.command, .setModeAndTemperature(mode: "制热", temperature: 21.0))

        let r3 = VoiceCommandParser.parse("客厅和主卧开制冷24度")
        XCTAssertEqual(r3?.command, .setModeAndTemperature(mode: "制冷", temperature: 24.0))

        let auto1 = VoiceCommandParser.parse("自动模式25度")
        XCTAssertEqual(auto1?.command, .setModeAndTemperature(mode: "自动", temperature: 25.0))

        // 否定保护：带模式与温度的否定句严禁误触发
        XCTAssertNil(VoiceCommandParser.parse("别开制冷26度"))
        XCTAssertNil(VoiceCommandParser.parse("不要开暖气22度"))
        XCTAssertNil(VoiceCommandParser.parse("千万别开制热20度"))
        XCTAssertNil(VoiceCommandParser.parse("不用制冷26度"))
        XCTAssertNil(VoiceCommandParser.parse("别调到26度"))
        XCTAssertNil(VoiceCommandParser.parse("不要调高两度"))
        XCTAssertNil(VoiceCommandParser.parse("千万别开大风"))
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

        // 开字前缀风速（v1.9.38）
        let w1 = VoiceCommandParser.parse("开大风")
        XCTAssertEqual(w1?.command, .setWindSpeed("强劲"))

        let w2 = VoiceCommandParser.parse("开微风")
        XCTAssertEqual(w2?.command, .setWindSpeed("微风"))

        // 全屋风速协同测试 (v1.9.41)
        let wall1 = VoiceCommandParser.parse("全屋开大风")
        XCTAssertEqual(wall1?.command, .setWindSpeedAll("强劲"))
        XCTAssertEqual(wall1?.displayText, "全屋切换至强劲风速")

        let wall2 = VoiceCommandParser.parse("所有空调开微风")
        XCTAssertEqual(wall2?.command, .setWindSpeedAll("微风"))
        XCTAssertEqual(wall2?.displayText, "全屋切换至微风模式")

        let wall3 = VoiceCommandParser.parse("全屋自动风")
        XCTAssertEqual(wall3?.command, .setWindSpeedAll("自动"))

        let wall4 = VoiceCommandParser.parse("把所有空调都调到中速风")
        XCTAssertEqual(wall4?.command, .setWindSpeedAll("中风"))

        // 变频 4档、5档与暴风测试 (v1.9.83)
        let w4_1 = VoiceCommandParser.parse("开四档风")
        XCTAssertEqual(w4_1?.command, .setWindSpeed("强劲"))

        let w4_2 = VoiceCommandParser.parse("风速4档")
        XCTAssertEqual(w4_2?.command, .setWindSpeed("强劲"))

        let w4_3 = VoiceCommandParser.parse("风速四")
        XCTAssertEqual(w4_3?.command, .setWindSpeed("强劲"))

        let w5_1 = VoiceCommandParser.parse("开五档风")
        XCTAssertEqual(w5_1?.command, .setWindSpeed("强劲"))

        let w5_2 = VoiceCommandParser.parse("风速5档")
        XCTAssertEqual(w5_2?.command, .setWindSpeed("强劲"))

        let wStorm = VoiceCommandParser.parse("吹暴风")
        XCTAssertEqual(wStorm?.command, .setWindSpeed("强劲"))

        let wallStorm = VoiceCommandParser.parse("全屋吹暴风")
        XCTAssertEqual(wallStorm?.command, .setWindSpeedAll("强劲"))

        let wall4Speed = VoiceCommandParser.parse("全屋风速4档")
        XCTAssertEqual(wall4Speed?.command, .setWindSpeedAll("强劲"))
    }

    // MARK: - 状态查询测试 (v1.9.38 扩展全屋/单机汇总)

    func testQueryStatus() {
        let q1 = VoiceCommandParser.parse("现在多少度")
        XCTAssertEqual(q1?.command, .queryStatus)

        let q2 = VoiceCommandParser.parse("室内温度是多少")
        XCTAssertEqual(q2?.command, .queryStatus)

        let q3 = VoiceCommandParser.parse("当前温度")
        XCTAssertEqual(q3?.command, .queryStatus)

        let qa1 = VoiceCommandParser.parse("全屋空调多少度")
        XCTAssertEqual(qa1?.command, .queryStatusAll)

        let qa2 = VoiceCommandParser.parse("所有空调运行状态")
        XCTAssertEqual(qa2?.command, .queryStatusAll)

        let qa3 = VoiceCommandParser.parse("全屋空调状态")
        XCTAssertEqual(qa3?.command, .queryStatusAll)
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

        // 全屋倒计时协同 (v1.9.40: 杜绝被全屋立即关机贪婪拦截)
        let c11 = VoiceCommandParser.parse("全屋30分钟后关机")
        XCTAssertEqual(c11?.command, .countdownPower(minutes: 30, power: false))
        XCTAssertEqual(c11?.displayText, "全屋设定 30 分钟后关机")

        let c12 = VoiceCommandParser.parse("全屋半小时后开机")
        XCTAssertEqual(c12?.command, .countdownPower(minutes: 30, power: true))
        XCTAssertEqual(c12?.displayText, "全屋设定 30 分钟后开机")

        let c13 = VoiceCommandParser.parse("所有空调1小时后关机")
        XCTAssertEqual(c13?.command, .countdownPower(minutes: 60, power: false))

        // 中文复合数十数字倒计时测试 (v1.9.42: 彻底解决四十五/四十分钟溢出为415/410分钟缺陷)
        let c14 = VoiceCommandParser.parse("四十分钟后关机")
        XCTAssertEqual(c14?.command, .countdownPower(minutes: 40, power: false))

        let c15 = VoiceCommandParser.parse("四十五分钟后关机")
        XCTAssertEqual(c15?.command, .countdownPower(minutes: 45, power: false))

        let c16 = VoiceCommandParser.parse("五十分钟后关机")
        XCTAssertEqual(c16?.command, .countdownPower(minutes: 50, power: false))

        let c17 = VoiceCommandParser.parse("六十分钟后关机")
        XCTAssertEqual(c17?.command, .countdownPower(minutes: 60, power: false))

        let c18 = VoiceCommandParser.parse("三十五分钟后关机")
        XCTAssertEqual(c18?.command, .countdownPower(minutes: 35, power: false))

        let c19 = VoiceCommandParser.parse("九十分钟后关机")
        XCTAssertEqual(c19?.command, .countdownPower(minutes: 90, power: false))

        let c20 = VoiceCommandParser.parse("全屋四十分钟后关机")
        XCTAssertEqual(c20?.command, .countdownPower(minutes: 40, power: false))

        let c21 = VoiceCommandParser.parse("全屋四十五分钟后开机")
        XCTAssertEqual(c21?.command, .countdownPower(minutes: 45, power: true))

        // 复合半小时倒计时折算测试 (v1.9.43: 彻底消除两个半小时被缩水解析为30分钟缺陷)
        let c22 = VoiceCommandParser.parse("两个半小时后关空调")
        XCTAssertEqual(c22?.command, .countdownPower(minutes: 150, power: false))

        let c23 = VoiceCommandParser.parse("2个半小时后关机")
        XCTAssertEqual(c23?.command, .countdownPower(minutes: 150, power: false))

        let c24 = VoiceCommandParser.parse("三个半小时后关机")
        XCTAssertEqual(c24?.command, .countdownPower(minutes: 210, power: false))

        let c25 = VoiceCommandParser.parse("两小时半后关机")
        XCTAssertEqual(c25?.command, .countdownPower(minutes: 150, power: false))
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

        // 全屋钟点定时 (v1.9.40)
        let s6 = VoiceCommandParser.parse("全屋晚上10点关空调")
        XCTAssertEqual(s6?.command, .schedulePower(hour: 22, minute: 0, power: false))
        XCTAssertEqual(s6?.displayText, "定时全屋在 22:00 关机")

        let s7 = VoiceCommandParser.parse("所有空调明早7点开机")
        XCTAssertEqual(s7?.command, .schedulePower(hour: 7, minute: 0, power: true))

        // 中午 PM 钟点识别测试 (v1.9.43: 解决“中午1点”被误判为凌晨1点缺陷)
        let s8 = VoiceCommandParser.parse("中午1点关机")
        XCTAssertEqual(s8?.command, .schedulePower(hour: 13, minute: 0, power: false))

        let s9 = VoiceCommandParser.parse("中午一点半关机")
        XCTAssertEqual(s9?.command, .schedulePower(hour: 13, minute: 30, power: false))

        let s10 = VoiceCommandParser.parse("中午2点开机")
        XCTAssertEqual(s10?.command, .schedulePower(hour: 14, minute: 0, power: true))

        let s11 = VoiceCommandParser.parse("中午12点关机")
        XCTAssertEqual(s11?.command, .schedulePower(hour: 12, minute: 0, power: false))
    }

    func testCancelSchedules() {
        // 定向/单设备取消定时
        let c1 = VoiceCommandParser.parse("取消定时")
        XCTAssertEqual(c1?.command, .cancelSchedules)
        XCTAssertEqual(c1?.displayText, "取消定时与倒计时")

        let c2 = VoiceCommandParser.parse("取消倒计时")
        XCTAssertEqual(c2?.command, .cancelSchedules)

        let c3 = VoiceCommandParser.parse("清除定时")
        XCTAssertEqual(c3?.command, .cancelSchedules)

        // 全屋所有设备取消定时 (v1.9.36 闭环 CR P1-2)
        let ca1 = VoiceCommandParser.parse("取消所有定时")
        XCTAssertEqual(ca1?.command, .cancelSchedulesAll)
        XCTAssertEqual(ca1?.displayText, "取消全屋所有定时与倒计时")

        let ca2 = VoiceCommandParser.parse("取消全部定时任务")
        XCTAssertEqual(ca2?.command, .cancelSchedulesAll)

        let ca3 = VoiceCommandParser.parse("取消全屋定时")
        XCTAssertEqual(ca3?.command, .cancelSchedulesAll)

        let ca4 = VoiceCommandParser.parse("全屋取消倒计时")
        XCTAssertEqual(ca4?.command, .cancelSchedulesAll)
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

        // 多房间定向协同带“都”字口语（v1.9.42: 严防误判为全屋一锅端关机/开机）
        let multiOff1 = VoiceCommandParser.parse("客厅和主卧都关了")
        XCTAssertEqual(multiOff1?.command, .setPower(false))

        let multiOff2 = VoiceCommandParser.parse("把客厅和主卧都关了")
        XCTAssertEqual(multiOff2?.command, .setPower(false))

        let multiOff3 = VoiceCommandParser.parse("客厅和主卧都关掉")
        XCTAssertEqual(multiOff3?.command, .setPower(false))

        let multiOn1 = VoiceCommandParser.parse("客厅和次卧都开了")
        XCTAssertEqual(multiOn1?.command, .setPower(true))

        let multiOn2 = VoiceCommandParser.parse("把客厅和主卧都打开")
        XCTAssertEqual(multiOn2?.command, .setPower(true))

        // 多房间定向协同带“全部/全都”字口语（v1.9.43: 严防误判为全屋一锅端关机）
        let multiOff4 = VoiceCommandParser.parse("把客厅和主卧全部关了")
        XCTAssertEqual(multiOff4?.command, .setPower(false))

        let multiOff5 = VoiceCommandParser.parse("客厅和主卧全都关了")
        XCTAssertEqual(multiOff5?.command, .setPower(false))

        let multiOff6 = VoiceCommandParser.parse("客厅和主卧全部关掉")
        XCTAssertEqual(multiOff6?.command, .setPower(false))

        let multiCancel1 = VoiceCommandParser.parse("取消客厅和主卧全部定时")
        XCTAssertEqual(multiCancel1?.command, .cancelSchedules)

        // 真实全屋命令对照验证
        let allOffCtrl = VoiceCommandParser.parse("全屋空调包括客厅全部关了")
        XCTAssertEqual(allOffCtrl?.command, .turnOffAll)

        let allCancelCtrl = VoiceCommandParser.parse("取消全屋所有定时")
        XCTAssertEqual(allCancelCtrl?.command, .cancelSchedulesAll)
    }

    // MARK: - 全屋模式与温控协同测试 (v1.9.33)

    func testWholeHousePresetAndTemperature() {
        // 全屋制冷（默认26°C）
        let cool1 = VoiceCommandParser.parse("全屋制冷")
        XCTAssertEqual(cool1?.command, .presetAll(mode: "制冷", temperature: 26.0))

        let cool2 = VoiceCommandParser.parse("所有空调开冷气")
        XCTAssertEqual(cool2?.command, .presetAll(mode: "制冷", temperature: 26.0))

        let cool3 = VoiceCommandParser.parse("全屋开冷气25度")
        XCTAssertEqual(cool3?.command, .presetAll(mode: "制冷", temperature: 25.0))

        // 全屋制热（默认20°C，防止误判为开机导致制冷26度倒置）
        let heat1 = VoiceCommandParser.parse("全屋制热")
        XCTAssertEqual(heat1?.command, .presetAll(mode: "制热", temperature: 20.0))

        let heat2 = VoiceCommandParser.parse("全屋开暖气")
        XCTAssertEqual(heat2?.command, .presetAll(mode: "制热", temperature: 20.0))

        let heat3 = VoiceCommandParser.parse("所有空调开暖气")
        XCTAssertEqual(heat3?.command, .presetAll(mode: "制热", temperature: 20.0))

        let heat4 = VoiceCommandParser.parse("全屋开制热22度")
        XCTAssertEqual(heat4?.command, .presetAll(mode: "制热", temperature: 22.0))

        // 全屋送风与除湿
        let fan1 = VoiceCommandParser.parse("全屋送风")
        XCTAssertEqual(fan1?.command, .presetAll(mode: "送风", temperature: nil))

        let dehum1 = VoiceCommandParser.parse("全屋除湿")
        XCTAssertEqual(dehum1?.command, .presetAll(mode: "除湿", temperature: nil))

        // 全屋统一调温
        let temp1 = VoiceCommandParser.parse("全屋调到24度")
        XCTAssertEqual(temp1?.command, .setTemperatureAll(24.0))

        let temp2 = VoiceCommandParser.parse("所有空调设为25度")
        XCTAssertEqual(temp2?.command, .setTemperatureAll(25.0))

        let temp3 = VoiceCommandParser.parse("把所有的空调都调到26度")
        XCTAssertEqual(temp3?.command, .setTemperatureAll(26.0))

        // 全屋开字前缀与省略“度”字调温（闭环 v1.9.41）
        let temp4 = VoiceCommandParser.parse("全屋开26度")
        XCTAssertEqual(temp4?.command, .setTemperatureAll(26.0))

        let temp5 = VoiceCommandParser.parse("所有空调开25")
        XCTAssertEqual(temp5?.command, .setTemperatureAll(25.0))

        let temp6 = VoiceCommandParser.parse("全屋开24")
        XCTAssertEqual(temp6?.command, .setTemperatureAll(24.0))

        // 全屋相对调温 (v1.9.35)
        let rel1 = VoiceCommandParser.parse("全屋调高两度")
        XCTAssertEqual(rel1?.command, .adjustTemperatureAll(delta: 2.0))

        let rel2 = VoiceCommandParser.parse("所有空调升温1度")
        XCTAssertEqual(rel2?.command, .adjustTemperatureAll(delta: 1.0))

        let rel3 = VoiceCommandParser.parse("把所有空调都降温两度")
        XCTAssertEqual(rel3?.command, .adjustTemperatureAll(delta: -2.0))

        let rel4 = VoiceCommandParser.parse("全部空调调低一度")
        XCTAssertEqual(rel4?.command, .adjustTemperatureAll(delta: -1.0))
    }

    // MARK: - 否定句与防误触测试 (v1.9.34, v1.9.36 闭环 CR P1-1)

    func testNegationProtection() {
        // 全屋与单机否定关机（紧邻与带插入字用例）
        XCTAssertNil(VoiceCommandParser.parse("全屋空调别关了"))
        XCTAssertNil(VoiceCommandParser.parse("所有空调先不要关"))
        XCTAssertNil(VoiceCommandParser.parse("客厅空调不要关"))
        XCTAssertNil(VoiceCommandParser.parse("千万别关空调"))
        XCTAssertNil(VoiceCommandParser.parse("先别关"))
        XCTAssertNil(VoiceCommandParser.parse("不用关空调"))
        // 关键插字用例 (v1.9.36, v1.9.40: 杜绝因各种插入字导致否定失效而误关全屋或误开机)
        XCTAssertNil(VoiceCommandParser.parse("全屋空调别都关了"))
        XCTAssertNil(VoiceCommandParser.parse("不要全部关掉"))
        XCTAssertNil(VoiceCommandParser.parse("先别急着关"))
        XCTAssertNil(VoiceCommandParser.parse("别马上关"))
        XCTAssertNil(VoiceCommandParser.parse("别把全屋空调都关了"))
        XCTAssertNil(VoiceCommandParser.parse("别把空调都关了"))
        XCTAssertNil(VoiceCommandParser.parse("别给我关了"))
        XCTAssertNil(VoiceCommandParser.parse("千万别现在关"))
        XCTAssertNil(VoiceCommandParser.parse("不用帮我关"))
        XCTAssertNil(VoiceCommandParser.parse("别太快关"))
        XCTAssertNil(VoiceCommandParser.parse("别乱调温度"))
        XCTAssertNil(VoiceCommandParser.parse("不要随便开"))
        XCTAssertNil(VoiceCommandParser.parse("千万别去开"))

        // 全屋与单机否定开机（紧邻与带插入字用例）
        XCTAssertNil(VoiceCommandParser.parse("别开空调"))
        XCTAssertNil(VoiceCommandParser.parse("先不要开空调"))
        XCTAssertNil(VoiceCommandParser.parse("所有空调先别开"))
        XCTAssertNil(VoiceCommandParser.parse("不用开"))
        XCTAssertNil(VoiceCommandParser.parse("千万不要全部打开"))
        XCTAssertNil(VoiceCommandParser.parse("空调不用全开"))
        XCTAssertNil(VoiceCommandParser.parse("所有空调别急着开"))

        // 模式与全屋预设否定保护 (v1.9.37)
        XCTAssertNil(VoiceCommandParser.parse("全屋空调别开冷气"))
        XCTAssertNil(VoiceCommandParser.parse("全屋不要开制热"))
        XCTAssertNil(VoiceCommandParser.parse("所有空调别吹风"))
        XCTAssertNil(VoiceCommandParser.parse("别开制冷"))
        XCTAssertNil(VoiceCommandParser.parse("不要开暖气"))
        XCTAssertNil(VoiceCommandParser.parse("千万别开除湿"))
        XCTAssertNil(VoiceCommandParser.parse("不用送风"))
        XCTAssertNil(VoiceCommandParser.parse("别开离家模式"))

        // 自清洁与睡眠温阶否定拦截（安全降级为停止或取消，防高温误烘烤） (v1.9.37)
        let sc1 = VoiceCommandParser.parse("不要自清洁")
        XCTAssertEqual(sc1?.command, .stopSelfCleaning)
        let sc2 = VoiceCommandParser.parse("别自清洁")
        XCTAssertEqual(sc2?.command, .stopSelfCleaning)
        let sc3 = VoiceCommandParser.parse("别开自清洁")
        XCTAssertEqual(sc3?.command, .stopSelfCleaning)
        let sc4 = VoiceCommandParser.parse("不要启动高温自清洁")
        XCTAssertEqual(sc4?.command, .stopSelfCleaning)

        let sl1 = VoiceCommandParser.parse("不要开启智能睡眠")
        XCTAssertEqual(sl1?.command, .stopSleepCurve)
        let sl2 = VoiceCommandParser.parse("别开睡眠曲线")
        XCTAssertEqual(sl2?.command, .stopSleepCurve)

        // 定时否定拦截映射为取消定时 (v1.9.37)
        let sched1 = VoiceCommandParser.parse("别定时")
        XCTAssertEqual(sched1?.command, .cancelSchedules)
        let sched2 = VoiceCommandParser.parse("不要定时")
        XCTAssertEqual(sched2?.command, .cancelSchedules)
    }

    // MARK: - 刻钟与钟头时间解析测试 (v1.9.44)

    func testQuarterHourAndHourCountdown() {
        // 刻钟倒计时
        let c1 = VoiceCommandParser.parse("一刻钟后关机")
        XCTAssertEqual(c1?.command, .countdownPower(minutes: 15, power: false))

        let c2 = VoiceCommandParser.parse("两刻钟后关机")
        XCTAssertEqual(c2?.command, .countdownPower(minutes: 30, power: false))

        let c3 = VoiceCommandParser.parse("三刻钟后关机")
        XCTAssertEqual(c3?.command, .countdownPower(minutes: 45, power: false))

        let c4 = VoiceCommandParser.parse("1刻钟后开机")
        XCTAssertEqual(c4?.command, .countdownPower(minutes: 15, power: true))

        let c5 = VoiceCommandParser.parse("3刻钟后开机")
        XCTAssertEqual(c5?.command, .countdownPower(minutes: 45, power: true))

        // 钟头与半钟头倒计时
        let h1 = VoiceCommandParser.parse("半个钟头后关机")
        XCTAssertEqual(h1?.command, .countdownPower(minutes: 30, power: false))

        let h2 = VoiceCommandParser.parse("半个钟头后开机")
        XCTAssertEqual(h2?.command, .countdownPower(minutes: 30, power: true))

        let h3 = VoiceCommandParser.parse("半钟头后关空调")
        XCTAssertEqual(h3?.command, .countdownPower(minutes: 30, power: false))

        let h4 = VoiceCommandParser.parse("两个半钟头后关机")
        XCTAssertEqual(h4?.command, .countdownPower(minutes: 150, power: false))

        let h5 = VoiceCommandParser.parse("2个半钟头后关机")
        XCTAssertEqual(h5?.command, .countdownPower(minutes: 150, power: false))

        let h6 = VoiceCommandParser.parse("一个半钟头后开机")
        XCTAssertEqual(h6?.command, .countdownPower(minutes: 90, power: true))

        let h7 = VoiceCommandParser.parse("1个半钟头后关机")
        XCTAssertEqual(h7?.command, .countdownPower(minutes: 90, power: false))

        // 钟点刻数定时 (闭环 10:01 / 10:03 误判缺陷, v1.9.46 闭环 10:02 两刻/二刻误判缺陷)
        let s1 = VoiceCommandParser.parse("十点一刻关机")
        XCTAssertEqual(s1?.command, .schedulePower(hour: 10, minute: 15, power: false))

        let s2 = VoiceCommandParser.parse("十点三刻开机")
        XCTAssertEqual(s2?.command, .schedulePower(hour: 10, minute: 45, power: true))

        let s3 = VoiceCommandParser.parse("晚上八点一刻关机")
        XCTAssertEqual(s3?.command, .schedulePower(hour: 20, minute: 15, power: false))

        let s4 = VoiceCommandParser.parse("明早七点三刻开机")
        XCTAssertEqual(s4?.command, .schedulePower(hour: 7, minute: 45, power: true))

        let s5 = VoiceCommandParser.parse("下午三点一刻关空调")
        XCTAssertEqual(s5?.command, .schedulePower(hour: 15, minute: 15, power: false))

        let s6 = VoiceCommandParser.parse("十点两刻关机")
        XCTAssertEqual(s6?.command, .schedulePower(hour: 10, minute: 30, power: false))

        let s7 = VoiceCommandParser.parse("十点二刻开机")
        XCTAssertEqual(s7?.command, .schedulePower(hour: 10, minute: 30, power: true))

        let s8 = VoiceCommandParser.parse("十点2刻关机")
        XCTAssertEqual(s8?.command, .schedulePower(hour: 10, minute: 30, power: false))

        // 小时与半小时口语测试 (v1.9.46 根除包含“个”字口语失效盲区)
        let cd1 = VoiceCommandParser.parse("半个小时后关机")
        XCTAssertEqual(cd1?.command, .countdownPower(minutes: 30, power: false))

        let cd2 = VoiceCommandParser.parse("半个小时后开机")
        XCTAssertEqual(cd2?.command, .countdownPower(minutes: 30, power: true))

        let cd3 = VoiceCommandParser.parse("一个小时后关机")
        XCTAssertEqual(cd3?.command, .countdownPower(minutes: 60, power: false))

        let cd4 = VoiceCommandParser.parse("1个小时后关机")
        XCTAssertEqual(cd4?.command, .countdownPower(minutes: 60, power: false))

        let cd5 = VoiceCommandParser.parse("两个小时后关机")
        XCTAssertEqual(cd5?.command, .countdownPower(minutes: 120, power: false))

        let cd6 = VoiceCommandParser.parse("2个小时后关机")
        XCTAssertEqual(cd6?.command, .countdownPower(minutes: 120, power: false))

        let cd7 = VoiceCommandParser.parse("三个小时后关机")
        XCTAssertEqual(cd7?.command, .countdownPower(minutes: 180, power: false))

        let cd8 = VoiceCommandParser.parse("3个小时后关机")
        XCTAssertEqual(cd8?.command, .countdownPower(minutes: 180, power: false))

        let cd9 = VoiceCommandParser.parse("二刻钟后关机")
        XCTAssertEqual(cd9?.command, .countdownPower(minutes: 30, power: false))

        let cd10 = VoiceCommandParser.parse("一刻后关机")
        XCTAssertEqual(cd10?.command, .countdownPower(minutes: 15, power: false))

        let cd11 = VoiceCommandParser.parse("两刻后关机")
        XCTAssertEqual(cd11?.command, .countdownPower(minutes: 30, power: false))

        let cd12 = VoiceCommandParser.parse("二刻后关机")
        XCTAssertEqual(cd12?.command, .countdownPower(minutes: 30, power: false))

        let cd13 = VoiceCommandParser.parse("三刻后关机")
        XCTAssertEqual(cd13?.command, .countdownPower(minutes: 45, power: false))

        // 全关 / 全开 扩展测试 (v1.9.46)
        let po1 = VoiceCommandParser.parse("全关")
        XCTAssertEqual(po1?.command, .turnOffAll)

        let po2 = VoiceCommandParser.parse("全开")
        XCTAssertEqual(po2?.command, .turnOnAll)

        let po3 = VoiceCommandParser.parse("全部关")
        XCTAssertEqual(po3?.command, .turnOffAll)

        let po4 = VoiceCommandParser.parse("全部开")
        XCTAssertEqual(po4?.command, .turnOnAll)
    }

    // MARK: - 滤网健康度查询测试 (v1.9.44)

    func testFilterHealthQuery() {
        let f1 = VoiceCommandParser.parse("查询滤网")
        XCTAssertEqual(f1?.command, .queryFilterHealth)

        let f2 = VoiceCommandParser.parse("滤网状态")
        XCTAssertEqual(f2?.command, .queryFilterHealth)

        let f3 = VoiceCommandParser.parse("滤网洁净度")
        XCTAssertEqual(f3?.command, .queryFilterHealth)

        let f4 = VoiceCommandParser.parse("滤网健康度")
        XCTAssertEqual(f4?.command, .queryFilterHealth)

        let f5 = VoiceCommandParser.parse("滤网要洗吗")
        XCTAssertEqual(f5?.command, .queryFilterHealth)

        let f6 = VoiceCommandParser.parse("空调滤网脏不脏")
        XCTAssertEqual(f6?.command, .queryFilterHealth)

        let f7 = VoiceCommandParser.parse("查看过滤网寿命")
        XCTAssertEqual(f7?.command, .queryFilterHealth)

        // 全屋作用域
        let fa1 = VoiceCommandParser.parse("全屋滤网状态")
        XCTAssertEqual(fa1?.command, .queryFilterHealthAll)

        let fa2 = VoiceCommandParser.parse("查询所有空调滤网")
        XCTAssertEqual(fa2?.command, .queryFilterHealthAll)

        let fa3 = VoiceCommandParser.parse("全部空调滤网洁净度")
        XCTAssertEqual(fa3?.command, .queryFilterHealthAll)
    }

    // MARK: - 滤网保养重置与复位测试 (v1.9.45)

    func testFilterMaintenanceReset() {
        // 单机/定向口令
        let r1 = VoiceCommandParser.parse("重置滤网")
        XCTAssertEqual(r1?.command, .resetFilterMaintenance)

        let r2 = VoiceCommandParser.parse("复位滤网")
        XCTAssertEqual(r2?.command, .resetFilterMaintenance)

        let r3 = VoiceCommandParser.parse("滤网已清洗")
        XCTAssertEqual(r3?.command, .resetFilterMaintenance)

        let r4 = VoiceCommandParser.parse("滤网洗好了")
        XCTAssertEqual(r4?.command, .resetFilterMaintenance)

        let r5 = VoiceCommandParser.parse("洗完滤网了")
        XCTAssertEqual(r5?.command, .resetFilterMaintenance)

        let r6 = VoiceCommandParser.parse("洗过滤网了")
        XCTAssertEqual(r6?.command, .resetFilterMaintenance)

        let r7 = VoiceCommandParser.parse("重置滤网计时")
        XCTAssertEqual(r7?.command, .resetFilterMaintenance)

        let r8 = VoiceCommandParser.parse("滤网换好了")
        XCTAssertEqual(r8?.command, .resetFilterMaintenance)

        let r9 = VoiceCommandParser.parse("更换滤网完成")
        XCTAssertEqual(r9?.command, .resetFilterMaintenance)

        let r10 = VoiceCommandParser.parse("过滤网已清洗")
        XCTAssertEqual(r10?.command, .resetFilterMaintenance)

        // 全屋作用域
        let ra1 = VoiceCommandParser.parse("全屋滤网已清洗")
        XCTAssertEqual(ra1?.command, .resetFilterMaintenanceAll)

        let ra2 = VoiceCommandParser.parse("重置全屋滤网")
        XCTAssertEqual(ra2?.command, .resetFilterMaintenanceAll)

        let ra3 = VoiceCommandParser.parse("所有空调滤网洗好了")
        XCTAssertEqual(ra3?.command, .resetFilterMaintenanceAll)

        let ra4 = VoiceCommandParser.parse("全部滤网复位")
        XCTAssertEqual(ra4?.command, .resetFilterMaintenanceAll)

        // 否定防御与语义隔离测试（确保“滤网要洗吗”依然走查询，“别重置滤网”安全拦截）
        XCTAssertNil(VoiceCommandParser.parse("别重置滤网"))
        XCTAssertNil(VoiceCommandParser.parse("不要重置滤网"))
        XCTAssertNil(VoiceCommandParser.parse("千万不要重置滤网"))

        let q1 = VoiceCommandParser.parse("滤网要洗吗")
        XCTAssertEqual(q1?.command, .queryFilterHealth)

        let q2 = VoiceCommandParser.parse("滤网脏不脏")
        XCTAssertEqual(q2?.command, .queryFilterHealth)
    }

    // MARK: - v1.9.47: 钟点时间“点五”防误降级为倒计时与动词间隔/档位风速测试

    func testScheduleTimePointFiveProtection() {
        // 彻底杜绝“十点五分/八点五分/十点五十分”被“点五”无上下文粗暴替换误判为 5 分钟倒计时 (v1.9.47)
        let s1 = VoiceCommandParser.parse("十点五分关机")
        XCTAssertEqual(s1?.command, .schedulePower(hour: 10, minute: 5, power: false))

        let s2 = VoiceCommandParser.parse("10点5分关机")
        XCTAssertEqual(s2?.command, .schedulePower(hour: 10, minute: 5, power: false))

        let s3 = VoiceCommandParser.parse("十点零五分开机")
        XCTAssertEqual(s3?.command, .schedulePower(hour: 10, minute: 5, power: true))

        let s4 = VoiceCommandParser.parse("晚上8点5分关机")
        XCTAssertEqual(s4?.command, .schedulePower(hour: 20, minute: 5, power: false))

        let s5 = VoiceCommandParser.parse("十点五十分关机")
        XCTAssertEqual(s5?.command, .schedulePower(hour: 10, minute: 50, power: false))

        let s6 = VoiceCommandParser.parse("全屋晚上8点5分关空调")
        XCTAssertEqual(s6?.command, .schedulePower(hour: 20, minute: 5, power: false))

        // 保持温度与小时小数转换不受影响
        let t1 = VoiceCommandParser.parse("二十六点五度")
        XCTAssertEqual(t1?.command, .setTemperature(26.5))

        let cd1 = VoiceCommandParser.parse("1点5小时后关机")
        XCTAssertEqual(cd1?.command, .countdownPower(minutes: 90, power: false))
    }

    func testVerbSpacedAndGearWindSpeed() {
        // 动词间隔风速口语测试 (v1.9.47)
        let w1 = VoiceCommandParser.parse("把风开大点")
        XCTAssertEqual(w1?.command, .setWindSpeed("强劲"))

        let w2 = VoiceCommandParser.parse("风调大点")
        XCTAssertEqual(w2?.command, .setWindSpeed("强劲"))

        let w3 = VoiceCommandParser.parse("调大风速")
        XCTAssertEqual(w3?.command, .setWindSpeed("强劲"))

        let w4 = VoiceCommandParser.parse("把风开小点")
        XCTAssertEqual(w4?.command, .setWindSpeed("微风"))

        let w5 = VoiceCommandParser.parse("风开小")
        XCTAssertEqual(w5?.command, .setWindSpeed("微风"))

        let w6 = VoiceCommandParser.parse("风调小点")
        XCTAssertEqual(w6?.command, .setWindSpeed("微风"))

        // 档位口语测试 (v1.9.47)
        let g1 = VoiceCommandParser.parse("一档风")
        XCTAssertEqual(g1?.command, .setWindSpeed("微风"))

        let g2 = VoiceCommandParser.parse("风速2档")
        XCTAssertEqual(g2?.command, .setWindSpeed("中风"))

        let g3 = VoiceCommandParser.parse("开三档风")
        XCTAssertEqual(g3?.command, .setWindSpeed("强劲"))

        let g4 = VoiceCommandParser.parse("风速调到四档")
        XCTAssertEqual(g4?.command, .setWindSpeed("自动"))

        // 全屋档位与动词间隔协同 (v1.9.47)
        let gw1 = VoiceCommandParser.parse("全屋把风开大")
        XCTAssertEqual(gw1?.command, .setWindSpeedAll("强劲"))

        let gw2 = VoiceCommandParser.parse("所有空调三档风")
        XCTAssertEqual(gw2?.command, .setWindSpeedAll("强劲"))

        let gw3 = VoiceCommandParser.parse("全屋一档风")
        XCTAssertEqual(gw3?.command, .setWindSpeedAll("微风"))
    }

    // MARK: - 午夜/正午及差刻逆序时间解析测试 (v1.9.48)

    func testScheduleTimeMidnightAndNoonAccuracy() {
        // 彻底根除午夜/零点被误映射为正午 12:00 的严重时序缺陷 (v1.9.48)
        let m1 = VoiceCommandParser.parse("晚上12点关机")
        XCTAssertEqual(m1?.command, .schedulePower(hour: 0, minute: 0, power: false))

        let m2 = VoiceCommandParser.parse("今晚12点关空调")
        XCTAssertEqual(m2?.command, .schedulePower(hour: 0, minute: 0, power: false))

        let m3 = VoiceCommandParser.parse("半夜12点关机")
        XCTAssertEqual(m3?.command, .schedulePower(hour: 0, minute: 0, power: false))

        let m4 = VoiceCommandParser.parse("午夜12点关机")
        XCTAssertEqual(m4?.command, .schedulePower(hour: 0, minute: 0, power: false))

        let m5 = VoiceCommandParser.parse("凌晨12点关机")
        XCTAssertEqual(m5?.command, .schedulePower(hour: 0, minute: 0, power: false))

        let m6 = VoiceCommandParser.parse("今晚零点关机")
        XCTAssertEqual(m6?.command, .schedulePower(hour: 0, minute: 0, power: false))

        let m7 = VoiceCommandParser.parse("晚上0点关机")
        XCTAssertEqual(m7?.command, .schedulePower(hour: 0, minute: 0, power: false))

        let m8 = VoiceCommandParser.parse("半夜零点开空调")
        XCTAssertEqual(m8?.command, .schedulePower(hour: 0, minute: 0, power: true))

        // 保持中午 11 点与 12 点日间时序正确性
        let n1 = VoiceCommandParser.parse("中午12点关机")
        XCTAssertEqual(n1?.command, .schedulePower(hour: 12, minute: 0, power: false))

        let n2 = VoiceCommandParser.parse("中午12点半关机")
        XCTAssertEqual(n2?.command, .schedulePower(hour: 12, minute: 30, power: false))

        let n3 = VoiceCommandParser.parse("中午11点关机")
        XCTAssertEqual(n3?.command, .schedulePower(hour: 11, minute: 0, power: false))

        let n4 = VoiceCommandParser.parse("中午1点关机")
        XCTAssertEqual(n4?.command, .schedulePower(hour: 13, minute: 0, power: false))

        let n5 = VoiceCommandParser.parse("中午一点半关机")
        XCTAssertEqual(n5?.command, .schedulePower(hour: 13, minute: 30, power: false))
    }

    func testScheduleTimePastAndDifferentialMinutes() {
        // “点过”分钟与刻度口语解析 (v1.9.48 彻底杜绝分钟丢失降级为整点)
        let p1 = VoiceCommandParser.parse("十点过五分关机")
        XCTAssertEqual(p1?.command, .schedulePower(hour: 10, minute: 5, power: false))

        let p2 = VoiceCommandParser.parse("十点过十分关机")
        XCTAssertEqual(p2?.command, .schedulePower(hour: 10, minute: 10, power: false))

        let p3 = VoiceCommandParser.parse("8点过10分关机")
        XCTAssertEqual(p3?.command, .schedulePower(hour: 8, minute: 10, power: false))

        let p4 = VoiceCommandParser.parse("十点过一刻关机")
        XCTAssertEqual(p4?.command, .schedulePower(hour: 10, minute: 15, power: false))

        let p5 = VoiceCommandParser.parse("十点过半关机")
        XCTAssertEqual(p5?.command, .schedulePower(hour: 10, minute: 30, power: false))

        let p6 = VoiceCommandParser.parse("十点过三刻关机")
        XCTAssertEqual(p6?.command, .schedulePower(hour: 10, minute: 45, power: false))

        // “差分”与“差刻”逆序倒算时间解析 (v1.9.48)
        let d1 = VoiceCommandParser.parse("十点差五分关机")
        XCTAssertEqual(d1?.command, .schedulePower(hour: 9, minute: 55, power: false))

        let d2 = VoiceCommandParser.parse("差五分十点关机")
        XCTAssertEqual(d2?.command, .schedulePower(hour: 9, minute: 55, power: false))

        let d3 = VoiceCommandParser.parse("十点差一刻关机")
        XCTAssertEqual(d3?.command, .schedulePower(hour: 9, minute: 45, power: false))

        let d4 = VoiceCommandParser.parse("差一刻十点关机")
        XCTAssertEqual(d4?.command, .schedulePower(hour: 9, minute: 45, power: false))

        let d5 = VoiceCommandParser.parse("8点差十分关空调")
        XCTAssertEqual(d5?.command, .schedulePower(hour: 7, minute: 50, power: false))

        let d6 = VoiceCommandParser.parse("差十分8点关机")
        XCTAssertEqual(d6?.command, .schedulePower(hour: 7, minute: 50, power: false))

        let d7 = VoiceCommandParser.parse("晚上10点差五分关机")
        XCTAssertEqual(d7?.command, .schedulePower(hour: 21, minute: 55, power: false))

        let d8 = VoiceCommandParser.parse("明早8点差一刻开机")
        XCTAssertEqual(d8?.command, .schedulePower(hour: 7, minute: 45, power: true))

        // “定时在具体时间”防误判为倒计时防护 (v1.9.48)
        let sc1 = VoiceCommandParser.parse("定时在十点五分关机")
        XCTAssertEqual(sc1?.command, .schedulePower(hour: 10, minute: 5, power: false))

        let sc2 = VoiceCommandParser.parse("定时在10点5分关机")
        XCTAssertEqual(sc2?.command, .schedulePower(hour: 10, minute: 5, power: false))

        let sc3 = VoiceCommandParser.parse("定时在十点关机")
        XCTAssertEqual(sc3?.command, .schedulePower(hour: 10, minute: 0, power: false))

        let sc4 = VoiceCommandParser.parse("定时10点半关机")
        XCTAssertEqual(sc4?.command, .schedulePower(hour: 10, minute: 30, power: false))
    }

    // MARK: - 半度温度微调与差分“分钟”逆序时间测试 (v1.9.49)

    func testTemperatureHalfDegreeParsing() {
        // “X度半”绝对温度解析 (v1.9.49 彻底杜绝丢失“半度”降级为整数)
        let t1 = VoiceCommandParser.parse("二十六度半")
        XCTAssertEqual(t1?.command, .setTemperature(26.5))

        let t2 = VoiceCommandParser.parse("26度半")
        XCTAssertEqual(t2?.command, .setTemperature(26.5))

        let t3 = VoiceCommandParser.parse("调到二十六度半")
        XCTAssertEqual(t3?.command, .setTemperature(26.5))

        let t4 = VoiceCommandParser.parse("开到25度半")
        XCTAssertEqual(t4?.command, .setTemperature(25.5))

        let t5 = VoiceCommandParser.parse("制冷二十六度半")
        XCTAssertEqual(t5?.command, .setModeAndTemperature(mode: "制冷", temperature: 26.5))

        let t6 = VoiceCommandParser.parse("全屋二十六度半")
        XCTAssertEqual(t6?.command, .setTemperatureAll(26.5))

        let t7 = VoiceCommandParser.parse("全部空调调到26度半")
        XCTAssertEqual(t7?.command, .setTemperatureAll(26.5))

        // “半度”与复合“X度半”相对升降温步进 (v1.9.49 解决半度被误判为1度缺陷)
        let r1 = VoiceCommandParser.parse("升温半度")
        XCTAssertEqual(r1?.command, .adjustTemperature(delta: 0.5))

        let r2 = VoiceCommandParser.parse("调高半度")
        XCTAssertEqual(r2?.command, .adjustTemperature(delta: 0.5))

        let r3 = VoiceCommandParser.parse("升高半度")
        XCTAssertEqual(r3?.command, .adjustTemperature(delta: 0.5))

        let r4 = VoiceCommandParser.parse("降半度")
        XCTAssertEqual(r4?.command, .adjustTemperature(delta: -0.5))

        let r5 = VoiceCommandParser.parse("降温半度")
        XCTAssertEqual(r5?.command, .adjustTemperature(delta: -0.5))

        let r6 = VoiceCommandParser.parse("调低半度")
        XCTAssertEqual(r6?.command, .adjustTemperature(delta: -0.5))

        let r7 = VoiceCommandParser.parse("全屋升高半度")
        XCTAssertEqual(r7?.command, .adjustTemperatureAll(delta: 0.5))

        let r8 = VoiceCommandParser.parse("全屋降半度")
        XCTAssertEqual(r8?.command, .adjustTemperatureAll(delta: -0.5))

        let r9 = VoiceCommandParser.parse("调高一度半")
        XCTAssertEqual(r9?.command, .adjustTemperature(delta: 1.5))

        let r10 = VoiceCommandParser.parse("降温两度半")
        XCTAssertEqual(r10?.command, .adjustTemperature(delta: -2.5))
    }

    func testScheduleTimeMinuteAndQuarterVariations() {
        // “差分/差刻”倒算支持“分钟”与半小时 (v1.9.49)
        let d1 = VoiceCommandParser.parse("十点差五分钟关机")
        XCTAssertEqual(d1?.command, .schedulePower(hour: 9, minute: 55, power: false))

        let d2 = VoiceCommandParser.parse("差五分钟十点关机")
        XCTAssertEqual(d2?.command, .schedulePower(hour: 9, minute: 55, power: false))

        let d3 = VoiceCommandParser.parse("差5分钟10点关机")
        XCTAssertEqual(d3?.command, .schedulePower(hour: 9, minute: 55, power: false))

        let d4 = VoiceCommandParser.parse("10点差5分钟关机")
        XCTAssertEqual(d4?.command, .schedulePower(hour: 9, minute: 55, power: false))

        let d5 = VoiceCommandParser.parse("差一刻钟十点关机")
        XCTAssertEqual(d5?.command, .schedulePower(hour: 9, minute: 45, power: false))

        let d6 = VoiceCommandParser.parse("十点差一刻钟关机")
        XCTAssertEqual(d6?.command, .schedulePower(hour: 9, minute: 45, power: false))

        let d7 = VoiceCommandParser.parse("差三刻钟十点关机")
        XCTAssertEqual(d7?.command, .schedulePower(hour: 9, minute: 15, power: false))

        let d8 = VoiceCommandParser.parse("差半小时八点关机")
        XCTAssertEqual(d8?.command, .schedulePower(hour: 7, minute: 30, power: false))

        let d9 = VoiceCommandParser.parse("八点差半小时关机")
        XCTAssertEqual(d9?.command, .schedulePower(hour: 7, minute: 30, power: false))
    }

    // MARK: - 延迟倒计时与直接时长防误关机测试 (v1.9.50)

    func testCountdownDelayAndDirectDurationVariations() {
        // 前置延迟助词（过/等/延迟/延后/稍后）与直接时长
        let c1 = VoiceCommandParser.parse("过半小时关机")
        XCTAssertEqual(c1?.command, .countdownPower(minutes: 30, power: false))
        XCTAssertEqual(c1?.displayText, "设定 30 分钟后关机")

        let c2 = VoiceCommandParser.parse("30分钟关机")
        XCTAssertEqual(c2?.command, .countdownPower(minutes: 30, power: false))
        XCTAssertEqual(c2?.displayText, "设定 30 分钟后关机")

        let c3 = VoiceCommandParser.parse("延迟半小时关机")
        XCTAssertEqual(c3?.command, .countdownPower(minutes: 30, power: false))

        let c4 = VoiceCommandParser.parse("等一个小时关机")
        XCTAssertEqual(c4?.command, .countdownPower(minutes: 60, power: false))
        XCTAssertEqual(c4?.displayText, "设定 1 小时后关机")

        let c5 = VoiceCommandParser.parse("稍后30分钟开机")
        XCTAssertEqual(c5?.command, .countdownPower(minutes: 30, power: true))
        XCTAssertEqual(c5?.displayText, "设定 30 分钟后开机")

        let c6 = VoiceCommandParser.parse("全屋过半小时关机")
        XCTAssertEqual(c6?.command, .countdownPower(minutes: 30, power: false))
        XCTAssertEqual(c6?.displayText, "全屋设定 30 分钟后关机")

        let c7 = VoiceCommandParser.parse("全屋30分钟关机")
        XCTAssertEqual(c7?.command, .countdownPower(minutes: 30, power: false))
        XCTAssertEqual(c7?.displayText, "全屋设定 30 分钟后关机")

        let c8 = VoiceCommandParser.parse("1点5小时后关机")
        XCTAssertEqual(c8?.command, .countdownPower(minutes: 90, power: false))

        // 确保“差半小时八点关机”依然准确解析为钟点定时，不被倒计时抢占
        let s1 = VoiceCommandParser.parse("差半小时八点关机")
        XCTAssertEqual(s1?.command, .schedulePower(hour: 7, minute: 30, power: false))
    }

    // MARK: - 口语化冷暖体感与相对调温测试 (v1.9.50)

    func testColloquialRelativeTemperatureVariations() {
        let t1 = VoiceCommandParser.parse("暖和点")
        XCTAssertEqual(t1?.command, .adjustTemperature(delta: 1.0))
        XCTAssertEqual(t1?.displayText, "升温 1°C")

        let t2 = VoiceCommandParser.parse("暖一点")
        XCTAssertEqual(t2?.command, .adjustTemperature(delta: 1.0))

        let t3 = VoiceCommandParser.parse("更热一点")
        XCTAssertEqual(t3?.command, .adjustTemperature(delta: 1.0))

        let t4 = VoiceCommandParser.parse("凉快一点")
        XCTAssertEqual(t4?.command, .adjustTemperature(delta: -1.0))
        XCTAssertEqual(t4?.displayText, "降温 1°C")

        let t5 = VoiceCommandParser.parse("凉快点")
        XCTAssertEqual(t5?.command, .adjustTemperature(delta: -1.0))

        let t6 = VoiceCommandParser.parse("更冷一点")
        XCTAssertEqual(t6?.command, .adjustTemperature(delta: -1.0))

        let t7 = VoiceCommandParser.parse("太冻了")
        XCTAssertEqual(t7?.command, .adjustTemperature(delta: 1.0))

        let t8 = VoiceCommandParser.parse("冻死了")
        XCTAssertEqual(t8?.command, .adjustTemperature(delta: 1.0))

        let t9 = VoiceCommandParser.parse("热死了")
        XCTAssertEqual(t9?.command, .adjustTemperature(delta: -1.0))

        // 全屋相对调温联动
        let all1 = VoiceCommandParser.parse("全屋暖和点")
        XCTAssertEqual(all1?.command, .adjustTemperatureAll(delta: 1.0))
        XCTAssertEqual(all1?.displayText, "全屋升温 1°C")

        let all2 = VoiceCommandParser.parse("全屋凉快一点")
        XCTAssertEqual(all2?.command, .adjustTemperatureAll(delta: -1.0))
        XCTAssertEqual(all2?.displayText, "全屋降温 1°C")
    }

    // MARK: - 滤网重置与风量口令防误开机测试 (v1.9.50)

    func testFilterResetAndWindGuards() {
        let f1 = VoiceCommandParser.parse("洗过滤网了")
        XCTAssertEqual(f1?.command, .resetFilterMaintenance)

        let f2 = VoiceCommandParser.parse("更换滤网完成")
        XCTAssertEqual(f2?.command, .resetFilterMaintenance)

        let f3 = VoiceCommandParser.parse("滤网换过了")
        XCTAssertEqual(f3?.command, .resetFilterMaintenance)

        // “开到最大”或“开三档风”应解析为风速调节而非开启电源
        let w1 = VoiceCommandParser.parse("开到最大")
        XCTAssertEqual(w1?.command, .setWindSpeed("turbo"))

        let w2 = VoiceCommandParser.parse("开三档风")
        XCTAssertEqual(w2?.command, .setWindSpeed("high"))

        // 动作否定包含送风/除湿
        XCTAssertNil(VoiceCommandParser.parse("不要开送风"))
        XCTAssertNil(VoiceCommandParser.parse("别抽湿"))

        // 特例放行：“别吹了”等同关机
        let off = VoiceCommandParser.parse("别吹了")
        XCTAssertEqual(off?.command, .setPower(false))
    }

    // MARK: - 口语“X度五/X度5”精确解析、停止关机与温湿度工况查询测试 (v1.9.51)

    func testOralDegreeFiveAndStoppingAndStatusQueries() {
        // 1. “X度五”与“X度5”绝对温度解析
        let t1 = VoiceCommandParser.parse("二十六度五")
        XCTAssertEqual(t1?.command, .setTemperature(26.5))
        XCTAssertEqual(t1?.displayText, "设置温度为 26.5°C")

        let t2 = VoiceCommandParser.parse("26度5")
        XCTAssertEqual(t2?.command, .setTemperature(26.5))

        let t3 = VoiceCommandParser.parse("开到25度5")
        XCTAssertEqual(t3?.command, .setTemperature(25.5))

        let t4 = VoiceCommandParser.parse("制冷二十六度五")
        XCTAssertEqual(t4?.command, .setModeAndTemperature(mode: "制冷", temperature: 26.5))

        let t5 = VoiceCommandParser.parse("制冷26度5")
        XCTAssertEqual(t5?.command, .setModeAndTemperature(mode: "制冷", temperature: 26.5))

        let t6 = VoiceCommandParser.parse("全屋二十六度五")
        XCTAssertEqual(t6?.command, .setTemperatureAll(26.5))

        let t7 = VoiceCommandParser.parse("全屋开到26度5")
        XCTAssertEqual(t7?.command, .setTemperatureAll(26.5))

        // 2. 口语“一度五/1度5”相对调温微调
        let r1 = VoiceCommandParser.parse("调高一度五")
        XCTAssertEqual(r1?.command, .adjustTemperature(delta: 1.5))
        XCTAssertEqual(r1?.displayText, "升温 1.5°C")

        let r2 = VoiceCommandParser.parse("升温1度5")
        XCTAssertEqual(r2?.command, .adjustTemperature(delta: 1.5))

        let r3 = VoiceCommandParser.parse("降温一度五")
        XCTAssertEqual(r3?.command, .adjustTemperature(delta: -1.5))
        XCTAssertEqual(r3?.displayText, "降温 1.5°C")

        let r4 = VoiceCommandParser.parse("调低1度5")
        XCTAssertEqual(r4?.command, .adjustTemperature(delta: -1.5))

        let r5 = VoiceCommandParser.parse("全屋升温一度五")
        XCTAssertEqual(r5?.command, .adjustTemperatureAll(delta: 1.5))

        let r6 = VoiceCommandParser.parse("全屋降温1度5")
        XCTAssertEqual(r6?.command, .adjustTemperatureAll(delta: -1.5))

        // 3. 停止运行关机意图
        let off1 = VoiceCommandParser.parse("把空调停了")
        XCTAssertEqual(off1?.command, .setPower(false))

        let off2 = VoiceCommandParser.parse("停止运行")
        XCTAssertEqual(off2?.command, .setPower(false))

        let off3 = VoiceCommandParser.parse("全屋空调停止运行")
        XCTAssertEqual(off3?.command, .turnOffAll)

        let off4 = VoiceCommandParser.parse("所有空调停止运行")
        XCTAssertEqual(off4?.command, .turnOffAll)

        // 4. 状态与温湿度口语查询
        let q1 = VoiceCommandParser.parse("查询状态")
        XCTAssertEqual(q1?.command, .queryStatus)

        let q2 = VoiceCommandParser.parse("空调开着吗")
        XCTAssertEqual(q2?.command, .queryStatus)

        let q3 = VoiceCommandParser.parse("室内湿度多少")
        XCTAssertEqual(q3?.command, .queryStatus)

        let q4 = VoiceCommandParser.parse("全屋空调开着吗")
        XCTAssertEqual(q4?.command, .queryStatusAll)

        // 5. 否定安全防线
        XCTAssertNil(VoiceCommandParser.parse("千万别把空调停了"))
        XCTAssertNil(VoiceCommandParser.parse("不要停止运行"))
        XCTAssertNil(VoiceCommandParser.parse("别停空调"))
        XCTAssertNil(VoiceCommandParser.parse("先不要停"))
    }

    // MARK: - 零点五与省略“度”字小数高精调温测试 (v1.9.52)

    func testDecimalAndPointFiveTemperatureParsing() {
        // 1. 口语“零点五度 / 0点5度”与相对微调
        let r1 = VoiceCommandParser.parse("升温零点五度")
        XCTAssertEqual(r1?.command, .adjustTemperature(delta: 0.5))
        XCTAssertEqual(r1?.displayText, "升温 0.5°C")

        let r2 = VoiceCommandParser.parse("降温零点五度")
        XCTAssertEqual(r2?.command, .adjustTemperature(delta: -0.5))
        XCTAssertEqual(r2?.displayText, "降温 0.5°C")

        let r3 = VoiceCommandParser.parse("全屋升温零点五度")
        XCTAssertEqual(r3?.command, .adjustTemperatureAll(delta: 0.5))
        XCTAssertEqual(r3?.displayText, "全屋升温 0.5°C")

        let r4 = VoiceCommandParser.parse("全屋降温0点5度")
        XCTAssertEqual(r4?.command, .adjustTemperatureAll(delta: -0.5))

        let r5 = VoiceCommandParser.parse("调高0点5度")
        XCTAssertEqual(r5?.command, .adjustTemperature(delta: 0.5))

        let r6 = VoiceCommandParser.parse("降温0点5度")
        XCTAssertEqual(r6?.command, .adjustTemperature(delta: -0.5))

        let r7 = VoiceCommandParser.parse("升温0点5")
        XCTAssertEqual(r7?.command, .adjustTemperature(delta: 0.5))

        let r8 = VoiceCommandParser.parse("降温0点5")
        XCTAssertEqual(r8?.command, .adjustTemperature(delta: -0.5))

        // 2. 省略“度”字小数绝对温度及开机联动（彻底杜绝误判为 00:05 定时开关机缺陷）
        let t1 = VoiceCommandParser.parse("开到26点5")
        XCTAssertEqual(t1?.command, .setTemperature(26.5))
        XCTAssertEqual(t1?.displayText, "设置温度为 26.5°C")

        let t2 = VoiceCommandParser.parse("开26点5")
        XCTAssertEqual(t2?.command, .setTemperature(26.5))

        let t3 = VoiceCommandParser.parse("打开26点5")
        XCTAssertEqual(t3?.command, .setTemperature(26.5))

        let t4 = VoiceCommandParser.parse("全屋开到26点5")
        XCTAssertEqual(t4?.command, .setTemperatureAll(26.5))
        XCTAssertEqual(t4?.displayText, "全屋温度调至 26.5°C")

        let t5 = VoiceCommandParser.parse("全屋开26点5")
        XCTAssertEqual(t5?.command, .setTemperatureAll(26.5))

        let t6 = VoiceCommandParser.parse("空调开到26点5")
        XCTAssertEqual(t6?.command, .setTemperature(26.5))

        let t7 = VoiceCommandParser.parse("制冷开到26点5")
        XCTAssertEqual(t7?.command, .setModeAndTemperature(mode: "制冷", temperature: 26.5))

        let t8 = VoiceCommandParser.parse("二十六点五")
        XCTAssertEqual(t8?.command, .setTemperature(26.5))

        let t9 = VoiceCommandParser.parse("调到26点5")
        XCTAssertEqual(t9?.command, .setTemperature(26.5))

        // 3. 钟点时间解析未受影响防线回归
        let s1 = VoiceCommandParser.parse("十点五分关机")
        XCTAssertEqual(s1?.command, .schedulePower(hour: 10, minute: 5, power: false))

        let s2 = VoiceCommandParser.parse("晚上10点5分开机")
        XCTAssertEqual(s2?.command, .schedulePower(hour: 22, minute: 5, power: true))
    }

    // MARK: - 中文数十复合数字与小数温度解析测试 (v1.9.53)

    func testChineseCompoundDecimalTemperatureParsing() {
        // 1. 中文复合数字小数温度（彻底杜绝误判为 20:05/18:05 等钟点定时开机重大缺陷）
        let c1 = VoiceCommandParser.parse("开到二十点五")
        XCTAssertEqual(c1?.command, .setTemperature(20.5))
        XCTAssertEqual(c1?.displayText, "设置温度为 20.5°C")

        let c2 = VoiceCommandParser.parse("开二十点五")
        XCTAssertEqual(c2?.command, .setTemperature(20.5))

        let c3 = VoiceCommandParser.parse("打开二十点五")
        XCTAssertEqual(c3?.command, .setTemperature(20.5))

        let c4 = VoiceCommandParser.parse("全屋开到二十点五")
        XCTAssertEqual(c4?.command, .setTemperatureAll(20.5))
        XCTAssertEqual(c4?.displayText, "全屋温度调至 20.5°C")

        let c5 = VoiceCommandParser.parse("全屋开二十点五")
        XCTAssertEqual(c5?.command, .setTemperatureAll(20.5))

        let c6 = VoiceCommandParser.parse("空调开到二十点五")
        XCTAssertEqual(c6?.command, .setTemperature(20.5))

        let c7 = VoiceCommandParser.parse("二十点五")
        XCTAssertEqual(c7?.command, .setTemperature(20.5))

        let c8 = VoiceCommandParser.parse("二十点五度")
        XCTAssertEqual(c8?.command, .setTemperature(20.5))

        let c9 = VoiceCommandParser.parse("开到十八点五")
        XCTAssertEqual(c9?.command, .setTemperature(18.5))

        let c10 = VoiceCommandParser.parse("开到十九点五")
        XCTAssertEqual(c10?.command, .setTemperature(19.5))

        let c11 = VoiceCommandParser.parse("开到二十一点五")
        XCTAssertEqual(c11?.command, .setTemperature(21.5))

        let c12 = VoiceCommandParser.parse("开到二十二点五")
        XCTAssertEqual(c12?.command, .setTemperature(22.5))

        let c13 = VoiceCommandParser.parse("开到二十三点五")
        XCTAssertEqual(c13?.command, .setTemperature(23.5))

        let c14 = VoiceCommandParser.parse("制冷开到二十点五")
        XCTAssertEqual(c14?.command, .setModeAndTemperature(mode: "制冷", temperature: 20.5))

        let c15 = VoiceCommandParser.parse("二十度半")
        XCTAssertEqual(c15?.command, .setTemperature(20.5))

        let c16 = VoiceCommandParser.parse("二十度五")
        XCTAssertEqual(c16?.command, .setTemperature(20.5))
    }

    // MARK: - 上调与下调自然语言相对调温测试 (v1.9.54)

    func testUpDownRelativeTemperatureParsing() {
        // 1. 上调单机相对调温
        let u1 = VoiceCommandParser.parse("上调一度")
        XCTAssertEqual(u1?.command, .adjustTemperature(delta: 1.0))
        XCTAssertEqual(u1?.displayText, "升温 1°C")

        let u2 = VoiceCommandParser.parse("上调1度")
        XCTAssertEqual(u2?.command, .adjustTemperature(delta: 1.0))

        let u3 = VoiceCommandParser.parse("上调两度")
        XCTAssertEqual(u3?.command, .adjustTemperature(delta: 2.0))
        XCTAssertEqual(u3?.displayText, "升温 2°C")

        let u4 = VoiceCommandParser.parse("上调2度")
        XCTAssertEqual(u4?.command, .adjustTemperature(delta: 2.0))

        let u5 = VoiceCommandParser.parse("上调半度")
        XCTAssertEqual(u5?.command, .adjustTemperature(delta: 0.5))
        XCTAssertEqual(u5?.displayText, "升温 0.5°C")

        let u6 = VoiceCommandParser.parse("上调0.5度")
        XCTAssertEqual(u6?.command, .adjustTemperature(delta: 0.5))

        let u7 = VoiceCommandParser.parse("上调零点五度")
        XCTAssertEqual(u7?.command, .adjustTemperature(delta: 0.5))

        let u8 = VoiceCommandParser.parse("往上调1度")
        XCTAssertEqual(u8?.command, .adjustTemperature(delta: 1.0))

        let u9 = VoiceCommandParser.parse("往上调半度")
        XCTAssertEqual(u9?.command, .adjustTemperature(delta: 0.5))

        let u10 = VoiceCommandParser.parse("向上调一度")
        XCTAssertEqual(u10?.command, .adjustTemperature(delta: 1.0))

        let u11 = VoiceCommandParser.parse("向上调0.5度")
        XCTAssertEqual(u11?.command, .adjustTemperature(delta: 0.5))

        let u12 = VoiceCommandParser.parse("温度上调1度")
        XCTAssertEqual(u12?.command, .adjustTemperature(delta: 1.0))

        // 2. 下调单机相对调温
        let d1 = VoiceCommandParser.parse("下调一度")
        XCTAssertEqual(d1?.command, .adjustTemperature(delta: -1.0))
        XCTAssertEqual(d1?.displayText, "降温 1°C")

        let d2 = VoiceCommandParser.parse("下调1度")
        XCTAssertEqual(d2?.command, .adjustTemperature(delta: -1.0))

        let d3 = VoiceCommandParser.parse("下调两度")
        XCTAssertEqual(d3?.command, .adjustTemperature(delta: -2.0))
        XCTAssertEqual(d3?.displayText, "降温 2°C")

        let d4 = VoiceCommandParser.parse("下调2度")
        XCTAssertEqual(d4?.command, .adjustTemperature(delta: -2.0))

        let d5 = VoiceCommandParser.parse("下调半度")
        XCTAssertEqual(d5?.command, .adjustTemperature(delta: -0.5))
        XCTAssertEqual(d5?.displayText, "降温 0.5°C")

        let d6 = VoiceCommandParser.parse("下调0.5度")
        XCTAssertEqual(d6?.command, .adjustTemperature(delta: -0.5))

        let d7 = VoiceCommandParser.parse("下调零点五度")
        XCTAssertEqual(d7?.command, .adjustTemperature(delta: -0.5))

        let d8 = VoiceCommandParser.parse("往下调1度")
        XCTAssertEqual(d8?.command, .adjustTemperature(delta: -1.0))

        let d9 = VoiceCommandParser.parse("往下调半度")
        XCTAssertEqual(d9?.command, .adjustTemperature(delta: -0.5))

        let d10 = VoiceCommandParser.parse("向下调一度")
        XCTAssertEqual(d10?.command, .adjustTemperature(delta: -1.0))

        let d11 = VoiceCommandParser.parse("向下调0.5度")
        XCTAssertEqual(d11?.command, .adjustTemperature(delta: -0.5))

        let d12 = VoiceCommandParser.parse("温度下调1度")
        XCTAssertEqual(d12?.command, .adjustTemperature(delta: -1.0))

        // 3. 全屋协同上调与下调
        let au1 = VoiceCommandParser.parse("全屋上调一度")
        XCTAssertEqual(au1?.command, .adjustTemperatureAll(delta: 1.0))
        XCTAssertEqual(au1?.displayText, "全屋升温 1°C")

        let au2 = VoiceCommandParser.parse("全屋上调半度")
        XCTAssertEqual(au2?.command, .adjustTemperatureAll(delta: 0.5))
        XCTAssertEqual(au2?.displayText, "全屋升温 0.5°C")

        let ad1 = VoiceCommandParser.parse("全屋下调一度")
        XCTAssertEqual(ad1?.command, .adjustTemperatureAll(delta: -1.0))
        XCTAssertEqual(ad1?.displayText, "全屋降温 1°C")

        let ad2 = VoiceCommandParser.parse("全屋下调半度")
        XCTAssertEqual(ad2?.command, .adjustTemperatureAll(delta: -0.5))
        XCTAssertEqual(ad2?.displayText, "全屋降温 0.5°C")

        // 4. 否定意图安全防护
        XCTAssertNil(VoiceCommandParser.parse("不要上调"))
        XCTAssertNil(VoiceCommandParser.parse("别下调"))
        XCTAssertNil(VoiceCommandParser.parse("千万别往上调"))
    }

    // MARK: - 跨日定时与深宵钟点解析测试 (v1.9.55)

    func testCrossDayAndMidnightScheduleParsing() {
        // 1. 跨日钟点定时与显式日期感知
        let t1 = VoiceCommandParser.parse("明天晚上10点关机")
        XCTAssertEqual(t1?.command, .schedulePower(hour: 22, minute: 0, power: false))
        XCTAssertEqual(t1?.displayText, "定时在 明天 22:00 关机")

        let t2 = VoiceCommandParser.parse("明早7点开空调")
        XCTAssertEqual(t2?.command, .schedulePower(hour: 7, minute: 0, power: true))
        XCTAssertEqual(t2?.displayText, "定时在 明天 07:00 开机")

        let t3 = VoiceCommandParser.parse("明晚8点开机")
        XCTAssertEqual(t3?.command, .schedulePower(hour: 20, minute: 0, power: true))
        XCTAssertEqual(t3?.displayText, "定时在 明天 20:00 开机")

        let t4 = VoiceCommandParser.parse("全屋明天早上8点开机")
        XCTAssertEqual(t4?.command, .schedulePower(hour: 8, minute: 0, power: true))
        XCTAssertEqual(t4?.displayText, "定时全屋在 明天 08:00 开机")

        let t5 = VoiceCommandParser.parse("后天晚上9点关机")
        XCTAssertEqual(t5?.command, .schedulePower(hour: 21, minute: 0, power: false))
        XCTAssertEqual(t5?.displayText, "定时在 后天 21:00 关机")

        // 2. 深宵 9~11 点时区精准规整与凌晨时段保持
        let m1 = VoiceCommandParser.parse("半夜10点关机")
        XCTAssertEqual(m1?.command, .schedulePower(hour: 22, minute: 0, power: false))
        XCTAssertEqual(m1?.displayText, "定时在 22:00 关机")

        let m2 = VoiceCommandParser.parse("半夜11点关空调")
        XCTAssertEqual(m2?.command, .schedulePower(hour: 23, minute: 0, power: false))
        XCTAssertEqual(m2?.displayText, "定时在 23:00 关机")

        let m3 = VoiceCommandParser.parse("午夜11点关机")
        XCTAssertEqual(m3?.command, .schedulePower(hour: 23, minute: 0, power: false))
        XCTAssertEqual(m3?.displayText, "定时在 23:00 关机")

        let m4 = VoiceCommandParser.parse("半夜1点关机")
        XCTAssertEqual(m4?.command, .schedulePower(hour: 1, minute: 0, power: false))
        XCTAssertEqual(m4?.displayText, "定时在 01:00 关机")

        let m5 = VoiceCommandParser.parse("半夜2点开机")
        XCTAssertEqual(m5?.command, .schedulePower(hour: 2, minute: 0, power: true))
        XCTAssertEqual(m5?.displayText, "定时在 02:00 开机")

        // 2.1 夜里与深夜深宵及后半夜消歧用例 (v1.9.76 彻底纠正“夜里1点”误判为下午 13:00 与“深夜10点”丢失晚间时态缺陷)
        let n1 = VoiceCommandParser.parse("夜里1点开机")
        XCTAssertEqual(n1?.command, .schedulePower(hour: 1, minute: 0, power: true))
        XCTAssertEqual(n1?.displayText, "定时在 01:00 开机")

        let n2 = VoiceCommandParser.parse("夜里2点关空调")
        XCTAssertEqual(n2?.command, .schedulePower(hour: 2, minute: 0, power: false))
        XCTAssertEqual(n2?.displayText, "定时在 02:00 关机")

        let n3 = VoiceCommandParser.parse("夜里3点关机")
        XCTAssertEqual(n3?.command, .schedulePower(hour: 3, minute: 0, power: false))
        XCTAssertEqual(n3?.displayText, "定时在 03:00 关机")

        let n4 = VoiceCommandParser.parse("夜里10点关空调")
        XCTAssertEqual(n4?.command, .schedulePower(hour: 22, minute: 0, power: false))
        XCTAssertEqual(n4?.displayText, "定时在 22:00 关机")

        let n5 = VoiceCommandParser.parse("深夜10点关机")
        XCTAssertEqual(n5?.command, .schedulePower(hour: 22, minute: 0, power: false))
        XCTAssertEqual(n5?.displayText, "定时在 22:00 关机")

        let n6 = VoiceCommandParser.parse("深夜11点关空调")
        XCTAssertEqual(n6?.command, .schedulePower(hour: 23, minute: 0, power: false))
        XCTAssertEqual(n6?.displayText, "定时在 23:00 关机")

        let n7 = VoiceCommandParser.parse("深夜3点关机")
        XCTAssertEqual(n7?.command, .schedulePower(hour: 3, minute: 0, power: false))
        XCTAssertEqual(n7?.displayText, "定时在 03:00 关机")

        let n8 = VoiceCommandParser.parse("晚上1点关空调")
        XCTAssertEqual(n8?.command, .schedulePower(hour: 1, minute: 0, power: false))
        XCTAssertEqual(n8?.displayText, "定时在 01:00 关机")

        let n9 = VoiceCommandParser.parse("晚上2点开机")
        XCTAssertEqual(n9?.command, .schedulePower(hour: 2, minute: 0, power: true))
        XCTAssertEqual(n9?.displayText, "定时在 02:00 开机")

        // 2.2 深宵、子夜、通宵与独立时相全时域调度解析用例 (v1.9.77 闭环深宵/子夜/通宵精准消歧与午夜/子夜/正午无钟点独立时相调度)
        let z1 = VoiceCommandParser.parse("子夜12点关机")
        XCTAssertEqual(z1?.command, .schedulePower(hour: 0, minute: 0, power: false))
        XCTAssertEqual(z1?.displayText, "定时在 00:00 关机")

        let z2 = VoiceCommandParser.parse("子夜1点关空调")
        XCTAssertEqual(z2?.command, .schedulePower(hour: 1, minute: 0, power: false))
        XCTAssertEqual(z2?.displayText, "定时在 01:00 关机")

        let z3 = VoiceCommandParser.parse("子夜11点关空调")
        XCTAssertEqual(z3?.command, .schedulePower(hour: 23, minute: 0, power: false))
        XCTAssertEqual(z3?.displayText, "定时在 23:00 关机")

        let z4 = VoiceCommandParser.parse("深宵12点关机")
        XCTAssertEqual(z4?.command, .schedulePower(hour: 0, minute: 0, power: false))
        XCTAssertEqual(z4?.displayText, "定时在 00:00 关机")

        let z5 = VoiceCommandParser.parse("深宵1点关空调")
        XCTAssertEqual(z5?.command, .schedulePower(hour: 1, minute: 0, power: false))
        XCTAssertEqual(z5?.displayText, "定时在 01:00 关机")

        let z6 = VoiceCommandParser.parse("深宵10点开空调")
        XCTAssertEqual(z6?.command, .schedulePower(hour: 22, minute: 0, power: true))
        XCTAssertEqual(z6?.displayText, "定时在 22:00 开机")

        let z7 = VoiceCommandParser.parse("通宵1点开机")
        XCTAssertEqual(z7?.command, .schedulePower(hour: 1, minute: 0, power: true))
        XCTAssertEqual(z7?.displayText, "定时在 01:00 开机")

        let z8 = VoiceCommandParser.parse("午夜关机")
        XCTAssertEqual(z8?.command, .schedulePower(hour: 0, minute: 0, power: false))
        XCTAssertEqual(z8?.displayText, "定时在 00:00 关机")

        let z9 = VoiceCommandParser.parse("午夜关空调")
        XCTAssertEqual(z9?.command, .schedulePower(hour: 0, minute: 0, power: false))
        XCTAssertEqual(z9?.displayText, "定时在 00:00 关机")

        let z10 = VoiceCommandParser.parse("子夜关空调")
        XCTAssertEqual(z10?.command, .schedulePower(hour: 0, minute: 0, power: false))
        XCTAssertEqual(z10?.displayText, "定时在 00:00 关机")

        let z11 = VoiceCommandParser.parse("子夜开机")
        XCTAssertEqual(z11?.command, .schedulePower(hour: 0, minute: 0, power: true))
        XCTAssertEqual(z11?.displayText, "定时在 00:00 开机")

        let z12 = VoiceCommandParser.parse("正午关空调")
        XCTAssertEqual(z12?.command, .schedulePower(hour: 12, minute: 0, power: false))
        XCTAssertEqual(z12?.displayText, "定时在 12:00 关机")

        let z13 = VoiceCommandParser.parse("正午开空调")
        XCTAssertEqual(z13?.command, .schedulePower(hour: 12, minute: 0, power: true))
        XCTAssertEqual(z13?.displayText, "定时在 12:00 开机")

        let z14 = VoiceCommandParser.parse("明天午夜关机")
        XCTAssertEqual(z14?.command, .schedulePower(hour: 0, minute: 0, power: false))
        XCTAssertEqual(z14?.displayText, "定时在 明天 00:00 关机")

        let z15 = VoiceCommandParser.parse("每周五午夜关机")
        XCTAssertEqual(z15?.command, .scheduleRepeatPower(hour: 0, minute: 0, power: false, repeatWeekdays: [6], repeatLabel: "每周五"))
        XCTAssertEqual(z15?.displayText, "定时在 每周五 00:00 关机")

        let z16 = VoiceCommandParser.parse("全屋子夜关空调")
        XCTAssertEqual(z16?.command, .schedulePower(hour: 0, minute: 0, power: false))
        XCTAssertEqual(z16?.displayText, "定时全屋在 00:00 关机")

        // 2.3 广义自然口语独立时相（中午/傍晚/黄昏/清晨/早晨/黎明/拂晓/破晓）全时域调度与启动谓词消歧 (v1.9.78)
        let s23_1 = VoiceCommandParser.parse("中午关机")
        XCTAssertEqual(s23_1?.command, .schedulePower(hour: 12, minute: 0, power: false))
        XCTAssertEqual(s23_1?.displayText, "定时在 12:00 关机")

        let s23_2 = VoiceCommandParser.parse("中午开机")
        XCTAssertEqual(s23_2?.command, .schedulePower(hour: 12, minute: 0, power: true))
        XCTAssertEqual(s23_2?.displayText, "定时在 12:00 开机")

        let s23_3 = VoiceCommandParser.parse("中午关空调")
        XCTAssertEqual(s23_3?.command, .schedulePower(hour: 12, minute: 0, power: false))
        XCTAssertEqual(s23_3?.displayText, "定时在 12:00 关机")

        let s23_4 = VoiceCommandParser.parse("明天中午关机")
        XCTAssertEqual(s23_4?.command, .schedulePower(hour: 12, minute: 0, power: false))
        XCTAssertEqual(s23_4?.displayText, "定时在 明天 12:00 关机")

        let s23_5 = VoiceCommandParser.parse("每天中午开空调")
        XCTAssertEqual(s23_5?.command, .scheduleRepeatPower(hour: 12, minute: 0, power: true, repeatWeekdays: [], repeatLabel: "每天"))
        XCTAssertEqual(s23_5?.displayText, "定时在 每天 12:00 开机")

        let s23_6 = VoiceCommandParser.parse("全屋中午开机")
        XCTAssertEqual(s23_6?.command, .schedulePower(hour: 12, minute: 0, power: true))
        XCTAssertEqual(s23_6?.displayText, "定时全屋在 12:00 开机")

        let s23_7 = VoiceCommandParser.parse("傍晚开机")
        XCTAssertEqual(s23_7?.command, .schedulePower(hour: 18, minute: 0, power: true))
        XCTAssertEqual(s23_7?.displayText, "定时在 18:00 开机")

        let s23_8 = VoiceCommandParser.parse("傍晚关空调")
        XCTAssertEqual(s23_8?.command, .schedulePower(hour: 18, minute: 0, power: false))
        XCTAssertEqual(s23_8?.displayText, "定时在 18:00 关机")

        let s23_9 = VoiceCommandParser.parse("黄昏关空调")
        XCTAssertEqual(s23_9?.command, .schedulePower(hour: 18, minute: 0, power: false))
        XCTAssertEqual(s23_9?.displayText, "定时在 18:00 关机")

        let s23_10 = VoiceCommandParser.parse("明天傍晚开机")
        XCTAssertEqual(s23_10?.command, .schedulePower(hour: 18, minute: 0, power: true))
        XCTAssertEqual(s23_10?.displayText, "定时在 明天 18:00 开机")

        let s23_11 = VoiceCommandParser.parse("每天傍晚开空调")
        XCTAssertEqual(s23_11?.command, .scheduleRepeatPower(hour: 18, minute: 0, power: true, repeatWeekdays: [], repeatLabel: "每天"))
        XCTAssertEqual(s23_11?.displayText, "定时在 每天 18:00 开机")

        let s23_12 = VoiceCommandParser.parse("清晨开空调")
        XCTAssertEqual(s23_12?.command, .schedulePower(hour: 6, minute: 0, power: true))
        XCTAssertEqual(s23_12?.displayText, "定时在 06:00 开机")

        let s23_13 = VoiceCommandParser.parse("黎明开机")
        XCTAssertEqual(s23_13?.command, .schedulePower(hour: 6, minute: 0, power: true))
        XCTAssertEqual(s23_13?.displayText, "定时在 06:00 开机")

        let s23_14 = VoiceCommandParser.parse("早晨关空调")
        XCTAssertEqual(s23_14?.command, .schedulePower(hour: 6, minute: 0, power: false))
        XCTAssertEqual(s23_14?.displayText, "定时在 06:00 关机")

        let s23_15 = VoiceCommandParser.parse("拂晓开机")
        XCTAssertEqual(s23_15?.command, .schedulePower(hour: 6, minute: 0, power: true))
        XCTAssertEqual(s23_15?.displayText, "定时在 06:00 开机")

        let s23_16 = VoiceCommandParser.parse("破晓关机")
        XCTAssertEqual(s23_16?.command, .schedulePower(hour: 6, minute: 0, power: false))
        XCTAssertEqual(s23_16?.displayText, "定时在 06:00 关机")

        let s23_17 = VoiceCommandParser.parse("中午半关机")
        XCTAssertEqual(s23_17?.command, .schedulePower(hour: 12, minute: 30, power: false))
        XCTAssertEqual(s23_17?.displayText, "定时在 12:30 关机")

        let s23_18 = VoiceCommandParser.parse("正午半开机")
        XCTAssertEqual(s23_18?.command, .schedulePower(hour: 12, minute: 30, power: true))
        XCTAssertEqual(s23_18?.displayText, "定时在 12:30 开机")

        let s23_19 = VoiceCommandParser.parse("傍晚半关机")
        XCTAssertEqual(s23_19?.command, .schedulePower(hour: 18, minute: 30, power: false))
        XCTAssertEqual(s23_19?.displayText, "定时在 18:30 关机")

        let s23_20 = VoiceCommandParser.parse("定时明早8点启动空调")
        XCTAssertEqual(s23_20?.command, .schedulePower(hour: 8, minute: 0, power: true))
        XCTAssertEqual(s23_20?.displayText, "定时在 明天 08:00 开机")

        let s23_21 = VoiceCommandParser.parse("晚上10点启动")
        XCTAssertEqual(s23_21?.command, .schedulePower(hour: 22, minute: 0, power: true))
        XCTAssertEqual(s23_21?.displayText, "定时在 22:00 开机")

        let s23_22 = VoiceCommandParser.parse("倒计时半小时启动")
        XCTAssertEqual(s23_22?.command, .countdownPower(minutes: 30, power: true))
        XCTAssertEqual(s23_22?.displayText, "设定 30 分钟后开机")

        let s23_23 = VoiceCommandParser.parse("全屋倒计时1小时启动")
        XCTAssertEqual(s23_23?.command, .countdownPower(minutes: 60, power: true))
        XCTAssertEqual(s23_23?.displayText, "全屋设定 1 小时后开机")

        let s23_24 = VoiceCommandParser.parse("定时启动")
        XCTAssertEqual(s23_24?.command, .countdownPower(minutes: 60, power: true))
        XCTAssertEqual(s23_24?.displayText, "设定 1 小时后开机")

        // 3. 定时开关机 60 分钟默认对称性
        let c1 = VoiceCommandParser.parse("定时关机")
        XCTAssertEqual(c1?.command, .countdownPower(minutes: 60, power: false))
        XCTAssertEqual(c1?.displayText, "设定 1 小时后关机")

        let c2 = VoiceCommandParser.parse("倒计时关机")
        XCTAssertEqual(c2?.command, .countdownPower(minutes: 60, power: false))

        let c3 = VoiceCommandParser.parse("定时开机")
        XCTAssertEqual(c3?.command, .countdownPower(minutes: 60, power: true))
        XCTAssertEqual(c3?.displayText, "设定 1 小时后开机")

        let c4 = VoiceCommandParser.parse("倒计时开机")
        XCTAssertEqual(c4?.command, .countdownPower(minutes: 60, power: true))
        XCTAssertEqual(c4?.displayText, "设定 1 小时后开机")

        let c5 = VoiceCommandParser.parse("全屋定时开机")
        XCTAssertEqual(c5?.command, .countdownPower(minutes: 60, power: true))
        XCTAssertEqual(c5?.displayText, "全屋设定 1 小时后开机")

        // 4. 否定意图防误触
        XCTAssertNil(VoiceCommandParser.parse("千万别定时开机"))
        XCTAssertNil(VoiceCommandParser.parse("不要定时关机"))
    }

    // MARK: - 循环周期定时调度测试 (v1.9.56)

    func testRepeatingScheduleParsing() {
        // 1. 每天/天天周期重复定时
        let r1 = VoiceCommandParser.parse("每天晚上10点关机")
        XCTAssertEqual(r1?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [], repeatLabel: "每天"))
        XCTAssertEqual(r1?.displayText, "定时在 每天 22:00 关机")

        let r2 = VoiceCommandParser.parse("天天早上8点开空调")
        XCTAssertEqual(r2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [], repeatLabel: "每天"))
        XCTAssertEqual(r2?.displayText, "定时在 每天 08:00 开机")

        let r3 = VoiceCommandParser.parse("每晚11点关空调")
        XCTAssertEqual(r3?.command, .scheduleRepeatPower(hour: 23, minute: 0, power: false, repeatWeekdays: [], repeatLabel: "每天"))
        XCTAssertEqual(r3?.displayText, "定时在 每天 23:00 关机")

        // 2. 工作日/平时/周一到周五周期定时
        let w1 = VoiceCommandParser.parse("工作日早上7点开机")
        XCTAssertEqual(w1?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))
        XCTAssertEqual(w1?.displayText, "定时在 工作日 07:00 开机")

        let w2 = VoiceCommandParser.parse("平时早上7点开空调")
        XCTAssertEqual(w2?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))
        XCTAssertEqual(w2?.displayText, "定时在 工作日 07:00 开机")

        let w3 = VoiceCommandParser.parse("周一到周五早上7点开机")
        XCTAssertEqual(w3?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))
        XCTAssertEqual(w3?.displayText, "定时在 工作日 07:00 开机")

        // 3. 周末/双休/周六周日周期定时
        let e1 = VoiceCommandParser.parse("周末上午9点开空调")
        XCTAssertEqual(e1?.command, .scheduleRepeatPower(hour: 9, minute: 0, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertEqual(e1?.displayText, "定时在 周末 09:00 开机")

        let e2 = VoiceCommandParser.parse("双休早上9点开机")
        XCTAssertEqual(e2?.command, .scheduleRepeatPower(hour: 9, minute: 0, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertEqual(e2?.displayText, "定时在 周末 09:00 开机")

        let e3 = VoiceCommandParser.parse("周六周日晚上11点关空调")
        XCTAssertEqual(e3?.command, .scheduleRepeatPower(hour: 23, minute: 0, power: false, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertEqual(e3?.displayText, "定时在 周末 23:00 关机")

        // 4. 全屋作用域周期定时
        let a1 = VoiceCommandParser.parse("全屋每天晚上10点关机")
        XCTAssertEqual(a1?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [], repeatLabel: "每天"))
        XCTAssertEqual(a1?.displayText, "定时全屋在 每天 22:00 关机")

        let a2 = VoiceCommandParser.parse("全屋工作日早上7点开机")
        XCTAssertEqual(a2?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))
        XCTAssertEqual(a2?.displayText, "定时全屋在 工作日 07:00 开机")

        // 5. 否定意图防误触
        XCTAssertNil(VoiceCommandParser.parse("千万别每天定时开机"))
        XCTAssertNil(VoiceCommandParser.parse("不要工作日定时关机"))
        XCTAssertNil(VoiceCommandParser.parse("别天天定时开"))
    }

    // MARK: - 单星期与扩展周期重复定时调度测试 (v1.9.57)

    func testSingleWeekdayAndExtendedRepeatingScheduleParsing() {
        // 1. 每周一 ~ 每周日 单星期周期定时
        let m1 = VoiceCommandParser.parse("每周一早上8点开空调")
        XCTAssertEqual(m1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertEqual(m1?.displayText, "定时在 每周一 08:00 开机")

        let m2 = VoiceCommandParser.parse("每周二下午3点关机")
        XCTAssertEqual(m2?.command, .scheduleRepeatPower(hour: 15, minute: 0, power: false, repeatWeekdays: [3], repeatLabel: "每周二"))
        XCTAssertEqual(m2?.displayText, "定时在 每周二 15:00 关机")

        let m3 = VoiceCommandParser.parse("每周三上午10点开机")
        XCTAssertEqual(m3?.command, .scheduleRepeatPower(hour: 10, minute: 0, power: true, repeatWeekdays: [4], repeatLabel: "每周三"))
        XCTAssertEqual(m3?.displayText, "定时在 每周三 10:00 开机")

        let m4 = VoiceCommandParser.parse("每周四下午4点关空调")
        XCTAssertEqual(m4?.command, .scheduleRepeatPower(hour: 16, minute: 0, power: false, repeatWeekdays: [5], repeatLabel: "每周四"))
        XCTAssertEqual(m4?.displayText, "定时在 每周四 16:00 关机")

        let m5 = VoiceCommandParser.parse("每周五晚上10点关机")
        XCTAssertEqual(m5?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [6], repeatLabel: "每周五"))
        XCTAssertEqual(m5?.displayText, "定时在 每周五 22:00 关机")

        let m6 = VoiceCommandParser.parse("每周六上午9点开机")
        XCTAssertEqual(m6?.command, .scheduleRepeatPower(hour: 9, minute: 0, power: true, repeatWeekdays: [7], repeatLabel: "每周六"))
        XCTAssertEqual(m6?.displayText, "定时在 每周六 09:00 开机")

        let m7 = VoiceCommandParser.parse("每周日晚上11点关空调")
        XCTAssertEqual(m7?.command, .scheduleRepeatPower(hour: 23, minute: 0, power: false, repeatWeekdays: [1], repeatLabel: "每周日"))
        XCTAssertEqual(m7?.displayText, "定时在 每周日 23:00 关机")

        // 2. 口语别名（每个星期一/逢周一/周一至周六）
        let a1 = VoiceCommandParser.parse("每个星期一早上7点开空调")
        XCTAssertEqual(a1?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertEqual(a1?.displayText, "定时在 每周一 07:00 开机")

        let a2 = VoiceCommandParser.parse("逢周一早上8点开机")
        XCTAssertEqual(a2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertEqual(a2?.displayText, "定时在 每周一 08:00 开机")

        let s1 = VoiceCommandParser.parse("周一到周六早上7点开机")
        XCTAssertEqual(s1?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))
        XCTAssertEqual(s1?.displayText, "定时在 周一至周六 07:00 开机")

        // 3. 全屋作用域扩展周期定时
        let all1 = VoiceCommandParser.parse("全屋每周一早上8点开空调")
        XCTAssertEqual(all1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertEqual(all1?.displayText, "定时全屋在 每周一 08:00 开机")

        let all2 = VoiceCommandParser.parse("全屋周一至周六早上7点开机")
        XCTAssertEqual(all2?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))
        XCTAssertEqual(all2?.displayText, "定时全屋在 周一至周六 07:00 开机")

        // 4. 否定意图防误触
        XCTAssertNil(VoiceCommandParser.parse("千万别每周一开机"))
        XCTAssertNil(VoiceCommandParser.parse("不要每个星期五开空调"))
        XCTAssertNil(VoiceCommandParser.parse("别周一到周六定时开机"))
    }

    // MARK: - 礼拜周期与多日复合星期定时调度测试 (v1.9.58)

    func testLibaiAndMultiWeekdayRepeatingScheduleParsing() {
        // 1. 礼拜周期（每个礼拜一 ~ 每个礼拜天/日）
        let lb1 = VoiceCommandParser.parse("每个礼拜一早上8点开空调")
        XCTAssertEqual(lb1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertEqual(lb1?.displayText, "定时在 每周一 08:00 开机")

        let lb2 = VoiceCommandParser.parse("每周礼拜二下午3点关机")
        XCTAssertEqual(lb2?.command, .scheduleRepeatPower(hour: 15, minute: 0, power: false, repeatWeekdays: [3], repeatLabel: "每周二"))
        XCTAssertEqual(lb2?.displayText, "定时在 每周二 15:00 关机")

        let lb3 = VoiceCommandParser.parse("逢礼拜三上午10点开机")
        XCTAssertEqual(lb3?.command, .scheduleRepeatPower(hour: 10, minute: 0, power: true, repeatWeekdays: [4], repeatLabel: "每周三"))
        XCTAssertEqual(lb3?.displayText, "定时在 每周三 10:00 开机")

        let lb4 = VoiceCommandParser.parse("每个礼拜四下午4点关空调")
        XCTAssertEqual(lb4?.command, .scheduleRepeatPower(hour: 16, minute: 0, power: false, repeatWeekdays: [5], repeatLabel: "每周四"))
        XCTAssertEqual(lb4?.displayText, "定时在 每周四 16:00 关机")

        let lb5 = VoiceCommandParser.parse("每个礼拜五晚上10点关机")
        XCTAssertEqual(lb5?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [6], repeatLabel: "每周五"))
        XCTAssertEqual(lb5?.displayText, "定时在 每周五 22:00 关机")

        let lb6 = VoiceCommandParser.parse("每个礼拜六上午9点开机")
        XCTAssertEqual(lb6?.command, .scheduleRepeatPower(hour: 9, minute: 0, power: true, repeatWeekdays: [7], repeatLabel: "每周六"))
        XCTAssertEqual(lb6?.displayText, "定时在 每周六 09:00 开机")

        let lb7 = VoiceCommandParser.parse("每个礼拜天晚上11点关空调")
        XCTAssertEqual(lb7?.command, .scheduleRepeatPower(hour: 23, minute: 0, power: false, repeatWeekdays: [1], repeatLabel: "每周日"))
        XCTAssertEqual(lb7?.displayText, "定时在 每周日 23:00 关机")

        let lb8 = VoiceCommandParser.parse("每个礼拜日晚上11点关空调")
        XCTAssertEqual(lb8?.command, .scheduleRepeatPower(hour: 23, minute: 0, power: false, repeatWeekdays: [1], repeatLabel: "每周日"))
        XCTAssertEqual(lb8?.displayText, "定时在 每周日 23:00 关机")

        // 2. 礼拜扩展周期（工作日/周一至周六/周末）
        let wrk = VoiceCommandParser.parse("礼拜一到礼拜五早上8点开空调")
        XCTAssertEqual(wrk?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))
        XCTAssertEqual(wrk?.displayText, "定时在 工作日 08:00 开机")

        let wrk6 = VoiceCommandParser.parse("礼拜一至礼拜六早上7点开空调")
        XCTAssertEqual(wrk6?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))
        XCTAssertEqual(wrk6?.displayText, "定时在 周一至周六 07:00 开机")

        let wke = VoiceCommandParser.parse("礼拜六礼拜天早上9点开空调")
        XCTAssertEqual(wke?.command, .scheduleRepeatPower(hour: 9, minute: 0, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertEqual(wke?.displayText, "定时在 周末 09:00 开机")

        // 3. 多日复合星期调度（一三五/二四六/二四/周一至周四）
        let c135 = VoiceCommandParser.parse("每周一三五早上7点开空调")
        XCTAssertEqual(c135?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [2, 4, 6], repeatLabel: "每周一、三、五"))
        XCTAssertEqual(c135?.displayText, "定时在 每周一、三、五 07:00 开机")

        let c246 = VoiceCommandParser.parse("每周二四六晚上10点关机")
        XCTAssertEqual(c246?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [3, 5, 7], repeatLabel: "每周二、四、六"))
        XCTAssertEqual(c246?.displayText, "定时在 每周二、四、六 22:00 关机")

        let c24 = VoiceCommandParser.parse("每周二四晚上10点关机")
        XCTAssertEqual(c24?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [3, 5], repeatLabel: "每周二、四"))
        XCTAssertEqual(c24?.displayText, "定时在 每周二、四 22:00 关机")

        let c14 = VoiceCommandParser.parse("周一到周四早上8点开机")
        XCTAssertEqual(c14?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5], repeatLabel: "周一至周四"))
        XCTAssertEqual(c14?.displayText, "定时在 周一至周四 08:00 开机")

        // 4. 全屋作用域多日复合与礼拜调度
        let allLb = VoiceCommandParser.parse("全屋每个礼拜一早上8点开机")
        XCTAssertEqual(allLb?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertEqual(allLb?.displayText, "定时全屋在 每周一 08:00 开机")

        let all135 = VoiceCommandParser.parse("全屋每周一三五早上7点开机")
        XCTAssertEqual(all135?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [2, 4, 6], repeatLabel: "每周一、三、五"))
        XCTAssertEqual(all135?.displayText, "定时全屋在 每周一、三、五 07:00 开机")

        // 5. 否定意图防误触
        XCTAssertNil(VoiceCommandParser.parse("千万别每个礼拜一开机"))
        XCTAssertNil(VoiceCommandParser.parse("别每周一三五开空调"))
        XCTAssertNil(VoiceCommandParser.parse("不要礼拜一到礼拜五开机"))
        XCTAssertNil(VoiceCommandParser.parse("别周一至周四定时开机"))
    }

    // MARK: - 扩展复合星期周期定时调度测试 (v1.9.59)

    func testExtendedMultiWeekdayScheduleParsing() {
        // 1. 周一至周三（[2, 3, 4]）
        let m13_1 = VoiceCommandParser.parse("周一到周三早上8点开机")
        XCTAssertEqual(m13_1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4], repeatLabel: "周一至周三"))
        XCTAssertEqual(m13_1?.displayText, "定时在 周一至周三 08:00 开机")

        let m13_2 = VoiceCommandParser.parse("礼拜一至礼拜三晚上11点关空调")
        XCTAssertEqual(m13_2?.command, .scheduleRepeatPower(hour: 23, minute: 0, power: false, repeatWeekdays: [2, 3, 4], repeatLabel: "周一至周三"))
        XCTAssertEqual(m13_2?.displayText, "定时在 周一至周三 23:00 关机")

        // 2. 周二至周五（[3, 4, 5, 6]）
        let m25_1 = VoiceCommandParser.parse("周二到周五早上7点开空调")
        XCTAssertEqual(m25_1?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [3, 4, 5, 6], repeatLabel: "周二至周五"))
        XCTAssertEqual(m25_1?.displayText, "定时在 周二至周五 07:00 开机")

        let m25_2 = VoiceCommandParser.parse("星期二至星期五下午5点关机")
        XCTAssertEqual(m25_2?.command, .scheduleRepeatPower(hour: 17, minute: 0, power: false, repeatWeekdays: [3, 4, 5, 6], repeatLabel: "周二至周五"))
        XCTAssertEqual(m25_2?.displayText, "定时在 周二至周五 17:00 关机")

        // 3. 周五至周日（[1, 6, 7]）
        let m57_1 = VoiceCommandParser.parse("周五到周日晚上10点关空调")
        XCTAssertEqual(m57_1?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [1, 6, 7], repeatLabel: "周五至周日"))
        XCTAssertEqual(m57_1?.displayText, "定时在 周五至周日 22:00 关机")

        let m57_2 = VoiceCommandParser.parse("周末三天早上9点开机")
        XCTAssertEqual(m57_2?.command, .scheduleRepeatPower(hour: 9, minute: 0, power: true, repeatWeekdays: [1, 6, 7], repeatLabel: "周五至周日"))
        XCTAssertEqual(m57_2?.displayText, "定时在 周五至周日 09:00 开机")

        // 4. 全屋作用域
        let all57 = VoiceCommandParser.parse("全屋周五至周日晚上10点关空调")
        XCTAssertEqual(all57?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [1, 6, 7], repeatLabel: "周五至周日"))
        XCTAssertEqual(all57?.displayText, "定时全屋在 周五至周日 22:00 关机")

        // 5. 否定防误触
        XCTAssertNil(VoiceCommandParser.parse("千万别周五到周日开机"))
        XCTAssertNil(VoiceCommandParser.parse("不要周一至周三关空调"))
        XCTAssertNil(VoiceCommandParser.parse("别周二到周五定时开机"))
    }

    // MARK: - 计划任务暂停与恢复测试 (v1.9.60)

    func testPauseAndResumeSchedules() {
        // 1. 定向 / 当前设备暂停与恢复
        let p1 = VoiceCommandParser.parse("暂停定时")
        XCTAssertEqual(p1?.command, .pauseSchedules)
        XCTAssertEqual(p1?.displayText, "临时暂停定时任务")

        let p2 = VoiceCommandParser.parse("暂停倒计时")
        XCTAssertEqual(p2?.command, .pauseSchedules)
        XCTAssertEqual(p2?.displayText, "临时暂停定时任务")

        let p3 = VoiceCommandParser.parse("暂停调度计划")
        XCTAssertEqual(p3?.command, .pauseSchedules)

        let r1 = VoiceCommandParser.parse("恢复定时")
        XCTAssertEqual(r1?.command, .resumeSchedules)
        XCTAssertEqual(r1?.displayText, "恢复定时任务生效")

        let r2 = VoiceCommandParser.parse("恢复倒计时")
        XCTAssertEqual(r2?.command, .resumeSchedules)
        XCTAssertEqual(r2?.displayText, "恢复定时任务生效")

        let r3 = VoiceCommandParser.parse("继续定时任务")
        XCTAssertEqual(r3?.command, .resumeSchedules)

        // 2. 全屋批量暂停与恢复
        let pAll1 = VoiceCommandParser.parse("暂停所有定时任务")
        XCTAssertEqual(pAll1?.command, .pauseSchedulesAll)
        XCTAssertEqual(pAll1?.displayText, "临时暂停全屋所有定时任务")

        let pAll2 = VoiceCommandParser.parse("暂停全屋定时")
        XCTAssertEqual(pAll2?.command, .pauseSchedulesAll)
        XCTAssertEqual(pAll2?.displayText, "临时暂停全屋所有定时任务")

        let pAll3 = VoiceCommandParser.parse("暂停全部倒计时")
        XCTAssertEqual(pAll3?.command, .pauseSchedulesAll)

        let rAll1 = VoiceCommandParser.parse("恢复所有定时任务")
        XCTAssertEqual(rAll1?.command, .resumeSchedulesAll)
        XCTAssertEqual(rAll1?.displayText, "恢复全屋所有定时任务")

        let rAll2 = VoiceCommandParser.parse("恢复全屋定时")
        XCTAssertEqual(rAll2?.command, .resumeSchedulesAll)
        XCTAssertEqual(rAll2?.displayText, "恢复全屋所有定时任务")

        let rAll3 = VoiceCommandParser.parse("恢复全部定时任务")
        XCTAssertEqual(rAll3?.command, .resumeSchedulesAll)

        // 3. 动作否定安全拦截（杜绝误触发，包括紧邻与带插入字场景） (v1.9.60, v1.9.61)
        XCTAssertNil(VoiceCommandParser.parse("千万别暂停定时"))
        XCTAssertNil(VoiceCommandParser.parse("不要暂停定时"))
        XCTAssertNil(VoiceCommandParser.parse("不用暂停全屋定时"))
        XCTAssertNil(VoiceCommandParser.parse("千万别恢复定时"))
        XCTAssertNil(VoiceCommandParser.parse("不要恢复定时任务"))
        XCTAssertNil(VoiceCommandParser.parse("别给我暂停定时"))
        XCTAssertNil(VoiceCommandParser.parse("千万不要暂停定时"))
        XCTAssertNil(VoiceCommandParser.parse("先别急着暂停定时"))
        XCTAssertNil(VoiceCommandParser.parse("千万别恢复全屋定时"))
        XCTAssertNil(VoiceCommandParser.parse("不要给我恢复定时"))
    }

    // MARK: - 计划调度取消与删除否定安全拦截测试 (v1.9.61 闭环重大否定穿透漏洞)

    func testCancelScheduleNegationProtection() {
        // 正常取消
        let c1 = VoiceCommandParser.parse("取消定时")
        XCTAssertEqual(c1?.command, .cancelSchedules)

        let cAll = VoiceCommandParser.parse("取消所有定时任务")
        XCTAssertEqual(cAll?.command, .cancelSchedulesAll)

        // 动作否定严格保护：杜绝误删任务
        XCTAssertNil(VoiceCommandParser.parse("千万别取消定时"))
        XCTAssertNil(VoiceCommandParser.parse("不要取消定时"))
        XCTAssertNil(VoiceCommandParser.parse("别给我取消定时任务"))
        XCTAssertNil(VoiceCommandParser.parse("先别急着取消定时"))
        XCTAssertNil(VoiceCommandParser.parse("千万不要删除全屋定时"))
        XCTAssertNil(VoiceCommandParser.parse("不要清除定时"))
        XCTAssertNil(VoiceCommandParser.parse("别撤销定时任务"))
    }

    // MARK: - 复合星期周期扩展与即时防误触发测试 (v1.9.60, v1.9.61)

    func testCompoundWeekdayScheduleRanges() {
        // 1. 周三至周五（[4, 5, 6]）
        let m35_1 = VoiceCommandParser.parse("周三至周五早上8点开机")
        XCTAssertEqual(m35_1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [4, 5, 6], repeatLabel: "周三至周五"))
        XCTAssertEqual(m35_1?.displayText, "定时在 周三至周五 08:00 开机")

        let m35_2 = VoiceCommandParser.parse("星期三到星期五晚上10点关空调")
        XCTAssertEqual(m35_2?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [4, 5, 6], repeatLabel: "周三至周五"))

        // 2. 周一至周二（[2, 3]）
        let m12_1 = VoiceCommandParser.parse("周一到周二晚上10点关空调")
        XCTAssertEqual(m12_1?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [2, 3], repeatLabel: "周一至周二"))

        // 3. 周二至周四（[3, 4, 5]）
        let m24_1 = VoiceCommandParser.parse("周二至周四早上7点开空调")
        XCTAssertEqual(m24_1?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [3, 4, 5], repeatLabel: "周二至周四"))

        // 4. 周六到周日 / 星期六至星期天（[1, 7]）
        let m67_1 = VoiceCommandParser.parse("周六到周日晚上10点关空调")
        XCTAssertEqual(m67_1?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [1, 7], repeatLabel: "周末"))

        let m67_2 = VoiceCommandParser.parse("星期六至星期天早上9点开空调")
        XCTAssertEqual(m67_2?.command, .scheduleRepeatPower(hour: 9, minute: 0, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))

        // 5. 新增复合星期周期范围 (v1.9.61)
        let m46 = VoiceCommandParser.parse("周四至周六晚上10点关空调")
        XCTAssertEqual(m46?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [5, 6, 7], repeatLabel: "周四至周六"))

        let m56 = VoiceCommandParser.parse("周五到周六早上8点开机")
        XCTAssertEqual(m56?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [6, 7], repeatLabel: "周五至周六"))

        let m37 = VoiceCommandParser.parse("周三至周日早上7点开空调")
        XCTAssertEqual(m37?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [1, 4, 5, 6, 7], repeatLabel: "周三至周日"))

        let m27 = VoiceCommandParser.parse("周二到周日晚上11点关机")
        XCTAssertEqual(m27?.command, .scheduleRepeatPower(hour: 23, minute: 0, power: false, repeatWeekdays: [1, 3, 4, 5, 6, 7], repeatLabel: "周二至周日"))

        // 6. 即时误开机安全拦截校验（省略“定时”二字时严禁触发立即全屋开机）
        let check1 = VoiceCommandParser.parse("全屋周三至周五开机")
        XCTAssertNotEqual(check1?.command, .turnOnAll)

        let check2 = VoiceCommandParser.parse("全屋周六到周日开机")
        XCTAssertNotEqual(check2?.command, .turnOnAll)

        let check3 = VoiceCommandParser.parse("全屋周一到周二开机")
        XCTAssertNotEqual(check3?.command, .turnOnAll)

        let check4 = VoiceCommandParser.parse("全屋周四至周六开机")
        XCTAssertNotEqual(check4?.command, .turnOnAll)

        let check5 = VoiceCommandParser.parse("全屋周五到周六开机")
        XCTAssertNotEqual(check5?.command, .turnOnAll)
    }

    // MARK: - 周期重复大一统解析引擎测试 (v1.9.62)

    func testUnifiedRepeatWeekdayEngine() {
        // 1. 周一至周日全周解析（[1, 2, 3, 4, 5, 6, 7]）
        let allDays1 = VoiceCommandParser.parse("周一至周日晚上10点关空调")
        XCTAssertEqual(allDays1?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [1, 2, 3, 4, 5, 6, 7], repeatLabel: "周一至周日"))

        let allDays2 = VoiceCommandParser.parse("星期一到星期天早上8点开空调")
        XCTAssertEqual(allDays2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 5, 6, 7], repeatLabel: "周一至周日"))

        let allDays3 = VoiceCommandParser.parse("礼拜一到礼拜天晚上11点关机")
        XCTAssertEqual(allDays3?.command, .scheduleRepeatPower(hour: 23, minute: 0, power: false, repeatWeekdays: [1, 2, 3, 4, 5, 6, 7], repeatLabel: "周一至周日"))

        // 2. 短周期连续星期范围
        // 周二至周三（[3, 4]）
        let m23 = VoiceCommandParser.parse("周二到周三晚上10点关机")
        XCTAssertEqual(m23?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [3, 4], repeatLabel: "周二至周三"))

        // 周三至周四（[4, 5]）
        let m34 = VoiceCommandParser.parse("周三至周四早上7点开空调")
        XCTAssertEqual(m34?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [4, 5], repeatLabel: "周三至周四"))

        // 周四至周五（[5, 6]）
        let m45 = VoiceCommandParser.parse("周四到周五早上8点开机")
        XCTAssertEqual(m45?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [5, 6], repeatLabel: "周四至周五"))

        // 周日至周一（[1, 2]）
        let m12 = VoiceCommandParser.parse("周日到周一晚上11点关空调")
        XCTAssertEqual(m12?.command, .scheduleRepeatPower(hour: 23, minute: 0, power: false, repeatWeekdays: [1, 2], repeatLabel: "周日至周一"))

        // 周六至周一（[1, 2, 7]）
        let m71 = VoiceCommandParser.parse("周六到周一早上9点开空调")
        XCTAssertEqual(m71?.command, .scheduleRepeatPower(hour: 9, minute: 0, power: true, repeatWeekdays: [1, 2, 7], repeatLabel: "周六至周一"))

        // 3. parseRepeatWeekdays 公共解析器单体测试
        let pAll = VoiceCommandParser.parseRepeatWeekdays("周一至周日")
        XCTAssertEqual(pAll?.weekdays, [1, 2, 3, 4, 5, 6, 7])
        XCTAssertEqual(pAll?.label, "周一至周日")

        let pWork = VoiceCommandParser.parseRepeatWeekdays("工作日")
        XCTAssertEqual(pWork?.weekdays, [2, 3, 4, 5, 6])
        XCTAssertEqual(pWork?.label, "工作日")

        let pWeekend = VoiceCommandParser.parseRepeatWeekdays("周末")
        XCTAssertEqual(pWeekend?.weekdays, [1, 7])
        XCTAssertEqual(pWeekend?.label, "周末")

        // 4. 即时开机防线拦截验证（省略“定时”二字时严禁触发即刻开机）
        let prevent1 = VoiceCommandParser.parse("全屋周一至周日开机")
        XCTAssertNotEqual(prevent1?.command, .turnOnAll)

        let prevent2 = VoiceCommandParser.parse("全屋周二到周三开空调")
        XCTAssertNotEqual(prevent2?.command, .turnOnAll)

        let prevent3 = VoiceCommandParser.parse("全屋周日至周一开机")
        XCTAssertNotEqual(prevent3?.command, .turnOnAll)
    }

    // MARK: - 跨周与全任务调度语义泛化测试 (v1.9.63)

    func testExtendedRepeatWeekdaysAndCancelTaskGeneralization() {
        // 1. 周五至周一跨周末周期（[1, 2, 6, 7]）
        let m51 = VoiceCommandParser.parse("周五至周一晚上10点关空调")
        XCTAssertEqual(m51?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [1, 2, 6, 7], repeatLabel: "周五至周一"))

        let m51_colloquial = VoiceCommandParser.parse("礼拜五到礼拜一早上8点开机")
        XCTAssertEqual(m51_colloquial?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 6, 7], repeatLabel: "周五至周一"))

        // 2. 周六至周二跨周末周期（[1, 2, 3, 7]）
        let m62 = VoiceCommandParser.parse("周六到周二早上9点开空调")
        XCTAssertEqual(m62?.command, .scheduleRepeatPower(hour: 9, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 7], repeatLabel: "周六至周二"))

        // 3. 周日至各工作日周期
        let m16 = VoiceCommandParser.parse("周日至周五晚上11点关空调")
        XCTAssertEqual(m16?.command, .scheduleRepeatPower(hour: 23, minute: 0, power: false, repeatWeekdays: [1, 2, 3, 4, 5, 6], repeatLabel: "周日至周五"))

        let m15 = VoiceCommandParser.parse("周日到周四晚上10点关空调")
        XCTAssertEqual(m15?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [1, 2, 3, 4, 5], repeatLabel: "周日至周四"))

        let m14 = VoiceCommandParser.parse("周日至周三早上7点开空调")
        XCTAssertEqual(m14?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4], repeatLabel: "周日至周三"))

        let m13 = VoiceCommandParser.parse("周日到周二早上8点开机")
        XCTAssertEqual(m13?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3], repeatLabel: "周日至周二"))

        // 4. 周末口语变体（周六日、周六天）
        let satSun1 = VoiceCommandParser.parse("周六日早上9点开机")
        XCTAssertEqual(satSun1?.command, .scheduleRepeatPower(hour: 9, minute: 0, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))

        let satSun2 = VoiceCommandParser.parse("星期六天晚上10点关空调")
        XCTAssertEqual(satSun2?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [1, 7], repeatLabel: "周末"))

        // 5. 调度取消/清空与“任务”语义
        let cancelTask1 = VoiceCommandParser.parse("取消所有任务")
        XCTAssertEqual(cancelTask1?.command, .cancelSchedulesAll)

        let cancelTask2 = VoiceCommandParser.parse("清空定时")
        XCTAssertEqual(cancelTask2?.command, .cancelSchedules)

        let cancelTask3 = VoiceCommandParser.parse("清空所有定时任务")
        XCTAssertEqual(cancelTask3?.command, .cancelSchedulesAll)

        let pauseTask1 = VoiceCommandParser.parse("暂停所有任务")
        XCTAssertEqual(pauseTask1?.command, .pauseSchedulesAll)

        let resumeTask1 = VoiceCommandParser.parse("恢复所有任务")
        XCTAssertEqual(resumeTask1?.command, .resumeSchedulesAll)

        // 6. 否定防线拦截清空指令
        let negative1 = VoiceCommandParser.parse("千万别清空定时")
        XCTAssertNil(negative1)

        let negative2 = VoiceCommandParser.parse("不要取消所有任务")
        XCTAssertNil(negative2)
    }

    // MARK: - 跨周长周期与撤销任务语义完备化测试 (v1.9.64)

    func testExtendedCrossWeekendCyclesAndRevokeSchedules() {
        // 1. 周五至周三、周五至周二跨周末长周期
        let friWed = VoiceCommandParser.parse("周五至周三晚上10点关空调")
        XCTAssertEqual(friWed?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [1, 2, 3, 4, 6, 7], repeatLabel: "周五至周三"))

        let friTue = VoiceCommandParser.parse("星期五到星期二早上8点开机")
        XCTAssertEqual(friTue?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 6, 7], repeatLabel: "周五至周二"))

        // 2. 周六至周四、周六至周三跨周末长周期
        let satThu = VoiceCommandParser.parse("周六至周四晚上11点关空调")
        XCTAssertEqual(satThu?.command, .scheduleRepeatPower(hour: 23, minute: 0, power: false, repeatWeekdays: [1, 2, 3, 4, 5, 7], repeatLabel: "周六至周四"))

        let satWed = VoiceCommandParser.parse("礼拜六到礼拜三早上9点开空调")
        XCTAssertEqual(satWed?.command, .scheduleRepeatPower(hour: 9, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 7], repeatLabel: "周六至周三"))

        // 3. 周四至周二、周四至周一、周三至周一跨周长周期
        let thuTue = VoiceCommandParser.parse("周四到周二早上7点开机")
        XCTAssertEqual(thuTue?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 5, 6, 7], repeatLabel: "周四至周二"))

        let thuMon = VoiceCommandParser.parse("星期四至星期一晚上10点关空调")
        XCTAssertEqual(thuMon?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [1, 2, 5, 6, 7], repeatLabel: "周四至周一"))

        let wedMon = VoiceCommandParser.parse("礼拜三到礼拜一早上8点开机")
        XCTAssertEqual(wedMon?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 4, 5, 6, 7], repeatLabel: "周三至周一"))

        // 4. 撤销定时与任务全语义覆盖
        let revoke1 = VoiceCommandParser.parse("撤销定时")
        XCTAssertEqual(revoke1?.command, .cancelSchedules)

        let revoke2 = VoiceCommandParser.parse("撤销所有定时")
        XCTAssertEqual(revoke2?.command, .cancelSchedulesAll)

        let revoke3 = VoiceCommandParser.parse("撤销所有任务")
        XCTAssertEqual(revoke3?.command, .cancelSchedulesAll)

        let revoke4 = VoiceCommandParser.parse("撤销倒计时")
        XCTAssertEqual(revoke4?.command, .cancelSchedules)

        // 5. 否定防线拦截撤销指令
        let negativeRevoke1 = VoiceCommandParser.parse("千万别撤销定时")
        XCTAssertNil(negativeRevoke1)

        let negativeRevoke2 = VoiceCommandParser.parse("不要撤销所有任务")
        XCTAssertNil(negativeRevoke2)
    }

    // MARK: - 口语省略语素周期重复调度通用解析测试 (v1.9.65)

    func testOralEllipsisRepeatWeekdays() {
        // 1. 口语省略第二个“周/星期/礼拜”语素解析验证（工作日与整周）
        let work1 = VoiceCommandParser.parse("周一至五早晨7点开机")
        XCTAssertEqual(work1?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))

        let work2 = VoiceCommandParser.parse("周一到五晚10点关机")
        XCTAssertEqual(work2?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))

        let work3 = VoiceCommandParser.parse("星期一到五早上8点开机")
        XCTAssertEqual(work3?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))

        let work4 = VoiceCommandParser.parse("礼拜一至五晚上11点关空调")
        XCTAssertEqual(work4?.command, .scheduleRepeatPower(hour: 23, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))

        // 2. 跨周末与跨周口语省略语素解析验证
        let friSun1 = VoiceCommandParser.parse("周五至日晚上10点关空调")
        XCTAssertEqual(friSun1?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [1, 6, 7], repeatLabel: "周五至周日"))

        let friSun2 = VoiceCommandParser.parse("周五到天早上9点开机")
        XCTAssertEqual(friSun2?.command, .scheduleRepeatPower(hour: 9, minute: 0, power: true, repeatWeekdays: [1, 6, 7], repeatLabel: "周五至周日"))

        let friMon = VoiceCommandParser.parse("周五至一早上8点开空调")
        XCTAssertEqual(friMon?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 6, 7], repeatLabel: "周五至周一"))

        let satTue = VoiceCommandParser.parse("周六至二晚上10点关机")
        XCTAssertEqual(satTue?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [1, 2, 3, 7], repeatLabel: "周六至周二"))

        let satThu = VoiceCommandParser.parse("周六到四早上8点开机")
        XCTAssertEqual(satThu?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 5, 7], repeatLabel: "周六至周四"))

        let sunFri = VoiceCommandParser.parse("周日至五早上7点开空调")
        XCTAssertEqual(sunFri?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 5, 6], repeatLabel: "周日至周五"))

        // 3. 扩展复合连续范围
        let monSat = VoiceCommandParser.parse("周一至六晚10点关机")
        XCTAssertEqual(monSat?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))

        let monSun = VoiceCommandParser.parse("周一至天晚10点关机")
        XCTAssertEqual(monSun?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [1, 2, 3, 4, 5, 6, 7], repeatLabel: "周一至周日"))

        let tueFri = VoiceCommandParser.parse("周二到五早上8点开机")
        XCTAssertEqual(tueFri?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [3, 4, 5, 6], repeatLabel: "周二至周五"))

        let wedMon = VoiceCommandParser.parse("周三至一早上8点开机")
        XCTAssertEqual(wedMon?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 4, 5, 6, 7], repeatLabel: "周三至周一"))
    }

    func testDiscreteAndMixedRepeatWeekdays() {
        // 1. 口语离散多星期复合解析测试 (v1.9.66)
        let monWed = VoiceCommandParser.parse("周一和周三晚10点关机")
        XCTAssertEqual(monWed?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [2, 4], repeatLabel: "每周一、三"))

        let tueThuSat = VoiceCommandParser.parse("周二、周四与周六早上8点开机")
        XCTAssertEqual(tueThuSat?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [3, 5, 7], repeatLabel: "每周二、四、六"))

        let monFri = VoiceCommandParser.parse("周一及周五早晨7点开空调")
        XCTAssertEqual(monFri?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [2, 6], repeatLabel: "每周一、五"))

        let tueThu = VoiceCommandParser.parse("星期二和星期四晚上11点关空调")
        XCTAssertEqual(tueThu?.command, .scheduleRepeatPower(hour: 23, minute: 0, power: false, repeatWeekdays: [3, 5], repeatLabel: "每周二、四"))

        let friWed = VoiceCommandParser.parse("礼拜一跟礼拜五早上8点开机")
        XCTAssertEqual(friWed?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 6], repeatLabel: "每周一、五"))

        let fengMonThu = VoiceCommandParser.parse("逢周一和周四下午2点开机")
        XCTAssertEqual(fengMonThu?.command, .scheduleRepeatPower(hour: 14, minute: 0, power: true, repeatWeekdays: [2, 5], repeatLabel: "每周一、四"))

        let monWedFriCompact = VoiceCommandParser.parse("周一三五早上7点开空调")
        XCTAssertEqual(monWedFriCompact?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [2, 4, 6], repeatLabel: "每周一、三、五"))

        let tueThuCompact = VoiceCommandParser.parse("周二四晚10点关机")
        XCTAssertEqual(tueThuCompact?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [3, 5], repeatLabel: "每周二、四"))

        // 2. 破折号、波浪号与阿拉伯数字复合语法测试
        let hyphenWork = VoiceCommandParser.parse("周一-周五早上8点开机")
        XCTAssertEqual(hyphenWork?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))

        let tildeWork = VoiceCommandParser.parse("周一~五晚10点关机")
        XCTAssertEqual(tildeWork?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))

        let numWork1 = VoiceCommandParser.parse("周1到5早8点开机")
        XCTAssertEqual(numWork1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))

        let numWork2 = VoiceCommandParser.parse("周1至周5晚上10点关机")
        XCTAssertEqual(numWork2?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))
    }

    func testCompoundRangeAndDiscreteRepeatWeekdays() {
        // 1. 核心关键词与离散星期复合解析测试 (v1.9.67)
        let workSat = VoiceCommandParser.parse("工作日和周六早晨8点开机")
        XCTAssertEqual(workSat?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))

        let workSun = VoiceCommandParser.parse("工作日以及周日晚上10点关空调")
        XCTAssertEqual(workSun?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [1, 2, 3, 4, 5, 6], repeatLabel: "周日至周五"))

        let satWork = VoiceCommandParser.parse("周六和工作日早上7点开空调")
        XCTAssertEqual(satWork?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))

        let workWeekend = VoiceCommandParser.parse("工作日加周末晚上11点关空调")
        XCTAssertEqual(workWeekend?.command, .scheduleRepeatPower(hour: 23, minute: 0, power: false, repeatWeekdays: [1, 2, 3, 4, 5, 6, 7], repeatLabel: "周一至周日"))

        let weekendMon = VoiceCommandParser.parse("周末和周一早8点开空调")
        XCTAssertEqual(weekendMon?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 7], repeatLabel: "周六至周一"))

        let weekendFri = VoiceCommandParser.parse("周末以及周五晚上10点关机")
        XCTAssertEqual(weekendFri?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [1, 6, 7], repeatLabel: "周五至周日"))

        // 2. 连续区间与离散星期复合解析测试 (v1.9.67)
        let rangeExtra1 = VoiceCommandParser.parse("周一至周三以及周五早8点开机")
        XCTAssertEqual(rangeExtra1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 6], repeatLabel: "每周一、二、三、五"))

        let rangeExtra2 = VoiceCommandParser.parse("周一到周四还有周六早晨7点开机")
        XCTAssertEqual(rangeExtra2?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 7], repeatLabel: "每周一、二、三、四、六"))

        let rangeExtra3 = VoiceCommandParser.parse("周一至五和周日晚上10点关机")
        XCTAssertEqual(rangeExtra3?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [1, 2, 3, 4, 5, 6], repeatLabel: "周日至周五"))

        // 3. 扩展连接词（或者/或/还有/加）与多“每”前缀解析测试 (v1.9.67)
        let everyEvery1 = VoiceCommandParser.parse("每周一和每周三晚上10点关机")
        XCTAssertEqual(everyEvery1?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [2, 4], repeatLabel: "每周一、三"))

        let everyEvery2 = VoiceCommandParser.parse("每个周二与每个周四晚上11点关空调")
        XCTAssertEqual(everyEvery2?.command, .scheduleRepeatPower(hour: 23, minute: 0, power: false, repeatWeekdays: [3, 5], repeatLabel: "每周二、四"))

        let orDays = VoiceCommandParser.parse("周一或者周四晚10点关机")
        XCTAssertEqual(orDays?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [2, 5], repeatLabel: "每周一、四"))

        let alsoDays = VoiceCommandParser.parse("周一还有周五早8点开机")
        XCTAssertEqual(alsoDays?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 6], repeatLabel: "每周一、五"))

        let plusDays = VoiceCommandParser.parse("周一加周三早上8点开机")
        XCTAssertEqual(plusDays?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 4], repeatLabel: "每周一、三"))
    }

    func testExclusionRepeatWeekdays() {
        // 1. 核心关键词排除（如“除了周末”、“除周末外”、“除了工作日”、“除工作日外”） (v1.9.68 彻底根除反向语义倒置缺陷)
        let exWeekend1 = VoiceCommandParser.parse("除了周末每天晚上10点关机")
        XCTAssertEqual(exWeekend1?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))

        let exWeekend2 = VoiceCommandParser.parse("除周末外每天早8点开机")
        XCTAssertEqual(exWeekend2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))

        let exWeekend3 = VoiceCommandParser.parse("除周末以外早8点开机")
        XCTAssertEqual(exWeekend3?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))

        let exWorkdays1 = VoiceCommandParser.parse("除了工作日每天晚上11点关空调")
        XCTAssertEqual(exWorkdays1?.command, .scheduleRepeatPower(hour: 23, minute: 0, power: false, repeatWeekdays: [1, 7], repeatLabel: "周末"))

        let exWorkdays2 = VoiceCommandParser.parse("除工作日外每天晚上11点关空调")
        XCTAssertEqual(exWorkdays2?.command, .scheduleRepeatPower(hour: 23, minute: 0, power: false, repeatWeekdays: [1, 7], repeatLabel: "周末"))

        // 2. 单星期与离散多星期排除（如“除了周日”、“除周日外”、“除周六和周日外”、“除周一和周三外”）
        let exSun1 = VoiceCommandParser.parse("除了周日每天早8点开机")
        XCTAssertEqual(exSun1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))

        let exSun2 = VoiceCommandParser.parse("除周日外每天早8点开机")
        XCTAssertEqual(exSun2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))

        let exSun3 = VoiceCommandParser.parse("除周日以外每天晚上10点关机")
        XCTAssertEqual(exSun3?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))

        let exSatSun = VoiceCommandParser.parse("除了周六周日每天早7点开机")
        XCTAssertEqual(exSatSun?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))

        let exSatAndSun = VoiceCommandParser.parse("除周六和周日外每天早7点开机")
        XCTAssertEqual(exSatAndSun?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))

        let exRange = VoiceCommandParser.parse("除了周一至周五每天晚10点关机")
        XCTAssertEqual(exRange?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [1, 7], repeatLabel: "周末"))

        let exMonWed = VoiceCommandParser.parse("除周一和周三外每天晚10点关机")
        XCTAssertEqual(exMonWed?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [1, 3, 5, 6, 7], repeatLabel: "每周日、二、四、五、六"))

        let exMon = VoiceCommandParser.parse("除周一外每天晚10点关机")
        XCTAssertEqual(exMon?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [1, 3, 4, 5, 6, 7], repeatLabel: "周二至周日"))

        let exMonEvery = VoiceCommandParser.parse("除了周一每天晚上10点关机")
        XCTAssertEqual(exMonEvery?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [1, 3, 4, 5, 6, 7], repeatLabel: "周二至周日"))

        // 3. 后置排除子句（如“每天晚10点关机除了周末”、“晚10点关机除周日外”）
        let postWeekend = VoiceCommandParser.parse("每天晚10点关机除了周末")
        XCTAssertEqual(postWeekend?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))

        let postSun = VoiceCommandParser.parse("晚10点关机除周日外")
        XCTAssertEqual(postSun?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))

        // 4. 限定基准范围排除（如“工作日除了周三”、“工作日除周五外”、“周末除周日外”、“周一至周五除了周二”） (v1.9.69 彻底闭环基准范围排除语义防线)
        let exWorkWed = VoiceCommandParser.parse("工作日除了周三每天早上8点开机")
        XCTAssertEqual(exWorkWed?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 5, 6], repeatLabel: "每周一、二、四、五"))

        let exWorkFri = VoiceCommandParser.parse("工作日除周五外每天晚10点关空调")
        XCTAssertEqual(exWorkFri?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5], repeatLabel: "周一至周四"))

        let exWeekendSun = VoiceCommandParser.parse("周末除周日外早8点开机")
        XCTAssertEqual(exWeekendSun?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [7], repeatLabel: "每周六"))

        let exRangeTue = VoiceCommandParser.parse("周一到周五除了周二早8点开机")
        XCTAssertEqual(exRangeTue?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 4, 5, 6], repeatLabel: "每周一、三、四、五"))

        let exPreWorkWed = VoiceCommandParser.parse("除了周三工作日每天早8点开机")
        XCTAssertEqual(exPreWorkWed?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 5, 6], repeatLabel: "每周一、二、四、五"))

        let exWorkPostFri = VoiceCommandParser.parse("工作日每天晚10点关空调除周五外")
        XCTAssertEqual(exWorkPostFri?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5], repeatLabel: "周一至周四"))

        let exWorkTwoDays = VoiceCommandParser.parse("工作日除周二和周四外每天早8点开机")
        XCTAssertEqual(exWorkTwoDays?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 4, 6], repeatLabel: "每周一、三、五"))

        // 5. 离散星期/复合区间/单休工作制大一统基准范围排除 (v1.9.70 彻底消除全周回退失真与单休支持)
        let exDiscrete1 = VoiceCommandParser.parse("一三五除了周三每天早8点开机")
        XCTAssertEqual(exDiscrete1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 6], repeatLabel: "每周一、五"))

        let exDiscrete2 = VoiceCommandParser.parse("二四六除周四外每天早8点开机")
        XCTAssertEqual(exDiscrete2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [3, 7], repeatLabel: "每周二、六"))

        let exCompound = VoiceCommandParser.parse("工作日和周六除了周三每天早8点开机")
        XCTAssertEqual(exCompound?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 5, 6, 7], repeatLabel: "每周一、二、四、五、六"))

        let exSingleRest1 = VoiceCommandParser.parse("单休每天早8点开机")
        XCTAssertEqual(exSingleRest1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))

        let exSingleRest2 = VoiceCommandParser.parse("单休除周三外每天早8点开机")
        XCTAssertEqual(exSingleRest2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 5, 6, 7], repeatLabel: "每周一、二、四、五、六"))

        let exDiscretePrefix = VoiceCommandParser.parse("除周三外一三五每天早8点开机")
        XCTAssertEqual(exDiscretePrefix?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 6], repeatLabel: "每周一、五"))

        let exDiscreteSuffix = VoiceCommandParser.parse("一三五每天早8点开机除周三外")
        XCTAssertEqual(exDiscreteSuffix?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 6], repeatLabel: "每周一、五"))

        // 6. 单休与周末三天排除型周期与复合口语纳管 (v1.9.71)
        let exExceptSingleRest1 = VoiceCommandParser.parse("除单休外每天早8点开机")
        XCTAssertEqual(exExceptSingleRest1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1], repeatLabel: "每周日"))

        let exExceptSingleRest2 = VoiceCommandParser.parse("除了单休每天早8点开机")
        XCTAssertEqual(exExceptSingleRest2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1], repeatLabel: "每周日"))

        let exExceptWeekend3Days = VoiceCommandParser.parse("除周末三天外每天早8点开机")
        XCTAssertEqual(exExceptWeekend3Days?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5], repeatLabel: "周一至周四"))

        let exWeekend3DaysFri = VoiceCommandParser.parse("周末三天除了周五每天早8点开机")
        XCTAssertEqual(exWeekend3DaysFri?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))

        let exWeekend3DaysSun = VoiceCommandParser.parse("周末三天除周日外每天早8点开机")
        XCTAssertEqual(exWeekend3DaysSun?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [6, 7], repeatLabel: "周五至周六"))

        let exCompoundSingleRestSun1 = VoiceCommandParser.parse("单休和周日每天早8点开机")
        XCTAssertEqual(exCompoundSingleRestSun1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 5, 6, 7], repeatLabel: "周一至周日"))

        let exCompoundSingleRestSun2 = VoiceCommandParser.parse("周日和单休每天早8点开机")
        XCTAssertEqual(exCompoundSingleRestSun2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 5, 6, 7], repeatLabel: "周一至周日"))

        // 7. 双连续区间、区间+关键词、关键词+区间、区间+多离散星期复合调度 (v1.9.72)
        let exDualRange1 = VoiceCommandParser.parse("周一至周三和周五至周日每天早8点开机")
        XCTAssertEqual(exDualRange1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 6, 7], repeatLabel: "周五至周三"))

        let exDualRange2 = VoiceCommandParser.parse("周一到周三以及周五到天每天早8点开机")
        XCTAssertEqual(exDualRange2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 6, 7], repeatLabel: "周五至周三"))

        let exRangeKeyword1 = VoiceCommandParser.parse("周一至周五和周末每天早8点开机")
        XCTAssertEqual(exRangeKeyword1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 5, 6, 7], repeatLabel: "周一至周日"))

        let exRangeKeyword2 = VoiceCommandParser.parse("周一到周四加单休每天早8点开机")
        XCTAssertEqual(exRangeKeyword2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))

        let exRangeKeyword3 = VoiceCommandParser.parse("周一至五加双休每天早8点开机")
        XCTAssertEqual(exRangeKeyword3?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 5, 6, 7], repeatLabel: "周一至周日"))

        let exRangeKeyword4 = VoiceCommandParser.parse("周一到周三加周末三天每天早8点开机")
        XCTAssertEqual(exRangeKeyword4?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 7], repeatLabel: "周六至周三"))

        let exKeywordRange1 = VoiceCommandParser.parse("周末和周一至周三每天早8点开机")
        XCTAssertEqual(exKeywordRange1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 7], repeatLabel: "周六至周三"))

        let exKeywordRange2 = VoiceCommandParser.parse("工作日加周六至周日每天早8点开机")
        XCTAssertEqual(exKeywordRange2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 5, 6, 7], repeatLabel: "周一至周日"))

        let exRangeMultiDays1 = VoiceCommandParser.parse("周一至周三和周五周六每天早8点开机")
        XCTAssertEqual(exRangeMultiDays1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 6, 7], repeatLabel: "周五至周三"))

        let exRangeMultiDays2 = VoiceCommandParser.parse("周一到周三以及周五、周日每天早8点开机")
        XCTAssertEqual(exRangeMultiDays2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 6], repeatLabel: "每周日、一、二、三、五"))

        let exCompositeExclusion1 = VoiceCommandParser.parse("周一至周五和周末除了周三每天早8点开机")
        XCTAssertEqual(exCompositeExclusion1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 5, 6, 7], repeatLabel: "周四至周二"))

        let exCompositeExclusion2 = VoiceCommandParser.parse("除周一至周二和周五至周六外每天早8点开机")
        XCTAssertEqual(exCompositeExclusion2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 4, 5], repeatLabel: "每周日、三、四"))

        // 8. 离散星期在前+连续区间在后、双连续区间+多离散星期、多离散星期+核心关键词大一统调度 (v1.9.73)
        let exPreDiscreteRange1 = VoiceCommandParser.parse("周五和周一至周三每天早8点开机")
        XCTAssertEqual(exPreDiscreteRange1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 6], repeatLabel: "每周一、二、三、五"))

        let exPreDiscreteRange2 = VoiceCommandParser.parse("周五周日和周一至周三每天早8点开机")
        XCTAssertEqual(exPreDiscreteRange2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 6], repeatLabel: "每周日、一、二、三、五"))

        let exPreDiscreteRange3 = VoiceCommandParser.parse("周五、周六和周一至周三每天早8点开机")
        XCTAssertEqual(exPreDiscreteRange3?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 6, 7], repeatLabel: "每周一、二、三、五、六"))

        let exPreDiscreteRange4 = VoiceCommandParser.parse("周日以及周一至周四每天早8点开机")
        XCTAssertEqual(exPreDiscreteRange4?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 5], repeatLabel: "周日至周四"))

        let exPreDiscreteRange5 = VoiceCommandParser.parse("周一和周五至周日每天早8点开机")
        XCTAssertEqual(exPreDiscreteRange5?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 6, 7], repeatLabel: "周五至周一"))

        let exDualRangeMultiDays1 = VoiceCommandParser.parse("周一至周三、周五至周六和周日每天早8点开机")
        XCTAssertEqual(exDualRangeMultiDays1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 6, 7], repeatLabel: "周五至周三"))

        let exDualRangeMultiDays2 = VoiceCommandParser.parse("周一到周二和周四到周五以及周日每天早8点开机")
        XCTAssertEqual(exDualRangeMultiDays2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 5, 6], repeatLabel: "每周日、一、二、四、五"))

        let exMultiDaysDualRange1 = VoiceCommandParser.parse("周日和周一至周三以及周五至周六每天早8点开机")
        XCTAssertEqual(exMultiDaysDualRange1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 6, 7], repeatLabel: "周五至周三"))

        let exMultiDaysDualRange2 = VoiceCommandParser.parse("周日加周一至周二加周四至周五每天早8点开机")
        XCTAssertEqual(exMultiDaysDualRange2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 5, 6], repeatLabel: "每周日、一、二、四、五"))

        let exMultiDaysKeyword1 = VoiceCommandParser.parse("周六周日和工作日每天早8点开机")
        XCTAssertEqual(exMultiDaysKeyword1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 5, 6, 7], repeatLabel: "周一至周日"))

        let exKeywordMultiDays1 = VoiceCommandParser.parse("工作日和周六周日每天早8点开机")
        XCTAssertEqual(exKeywordMultiDays1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 5, 6, 7], repeatLabel: "周一至周日"))

        let exKeywordMultiDays2 = VoiceCommandParser.parse("周末和周二周四每天早8点开机")
        XCTAssertEqual(exKeywordMultiDays2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 3, 5, 7], repeatLabel: "每周日、二、四、六"))

        let exMultiDaysKeyword2 = VoiceCommandParser.parse("周二周四和周末每天早8点开机")
        XCTAssertEqual(exMultiDaysKeyword2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 3, 5, 7], repeatLabel: "每周日、二、四、六"))

        let exMultiDaysKeyword3 = VoiceCommandParser.parse("周五和周日加工作日每天早8点开机")
        XCTAssertEqual(exMultiDaysKeyword3?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 5, 6], repeatLabel: "周日至周五"))

        // 9. 三连续区间、夹心连续区间+离散星期+连续区间、紧凑无分隔离散多星期大一统调度 (v1.9.74)
        let exTriRange1 = VoiceCommandParser.parse("周一至周二、周四至周五和周六至周日每天早8点开机")
        XCTAssertEqual(exTriRange1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 5, 6, 7], repeatLabel: "周四至周二"))

        let exTriRange2 = VoiceCommandParser.parse("周一到周二、周三到周四以及周五到周六每天早8点开机")
        XCTAssertEqual(exTriRange2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))

        let exSandwichRange1 = VoiceCommandParser.parse("周一至周三、周五以及周六至周日每天早8点开机")
        XCTAssertEqual(exSandwichRange1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 6, 7], repeatLabel: "周五至周三"))

        let exSandwichRange2 = VoiceCommandParser.parse("周一到周二、周四和周六到周日每天早8点开机")
        XCTAssertEqual(exSandwichRange2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 5, 7], repeatLabel: "每周日、一、二、四、六"))

        let exSandwichRange3 = VoiceCommandParser.parse("周一至周三和周五加周六至周日每天早8点开机")
        XCTAssertEqual(exSandwichRange3?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 6, 7], repeatLabel: "周五至周三"))

        let exCompactDiscrete1 = VoiceCommandParser.parse("周一周三和周五周日每天早8点开机")
        XCTAssertEqual(exCompactDiscrete1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 4, 6], repeatLabel: "每周日、一、三、五"))

        let exCompactDiscrete2 = VoiceCommandParser.parse("周一周三周五每天早8点开机")
        XCTAssertEqual(exCompactDiscrete2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 4, 6], repeatLabel: "每周一、三、五"))

        let exCompactDiscrete3 = VoiceCommandParser.parse("周二周四周六每天早8点开机")
        XCTAssertEqual(exCompactDiscrete3?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [3, 5, 7], repeatLabel: "每周二、四、六"))

        let exCompactDiscrete4 = VoiceCommandParser.parse("周一周二和周四周五每天早8点开机")
        XCTAssertEqual(exCompactDiscrete4?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 5, 6], repeatLabel: "每周一、二、四、五"))

        let exCompactDiscrete5 = VoiceCommandParser.parse("周一周三、周五和周日每天早8点开机")
        XCTAssertEqual(exCompactDiscrete5?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 4, 6], repeatLabel: "每周日、一、三、五"))

        // 10. 反向夹心（离散在先、连续居中、离散在后）与三区间多离散大一统调度 (v1.9.75)
        let exRevSandwich1 = VoiceCommandParser.parse("周一、周三至周五以及周日每天早8点开机")
        XCTAssertEqual(exRevSandwich1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 4, 5, 6], repeatLabel: "每周日、一、三、四、五"))

        let exRevSandwich2 = VoiceCommandParser.parse("周日和周二至周四以及周六每天早8点开机")
        XCTAssertEqual(exRevSandwich2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 3, 4, 5, 7], repeatLabel: "每周日、二、三、四、六"))

        let exRevSandwich3 = VoiceCommandParser.parse("周二和周四到周五加周日每天早8点开机")
        XCTAssertEqual(exRevSandwich3?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 3, 5, 6], repeatLabel: "每周日、二、四、五"))

        let exRevSandwich4 = VoiceCommandParser.parse("周一、周二和周四至周五还有周六周日每天早8点开机")
        XCTAssertEqual(exRevSandwich4?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 5, 6, 7], repeatLabel: "周四至周二"))

        let exTriRangeMulti1 = VoiceCommandParser.parse("周一至周二、周四至周五、周六至周日和周三每天早8点开机")
        XCTAssertEqual(exTriRangeMulti1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 5, 6, 7], repeatLabel: "周一至周日"))

        let exMultiTriRange1 = VoiceCommandParser.parse("周日和周一至周二、周四至周五以及周六至周日每天早8点开机")
        XCTAssertEqual(exMultiTriRange1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 5, 6, 7], repeatLabel: "周四至周二"))
    }

    // MARK: - 自然口语全时相调度大一统与防即时开关机误触测试 (v1.9.79)

    func testNaturalTimePhaseScheduleAndProtection() {
        // 1. 独立口语时相单次调度
        let pMorning1 = VoiceCommandParser.parse("早上关机")
        XCTAssertEqual(pMorning1?.command, .schedulePower(hour: 7, minute: 0, power: false))

        let pMorning2 = VoiceCommandParser.parse("早上开机")
        XCTAssertEqual(pMorning2?.command, .schedulePower(hour: 7, minute: 0, power: true))

        let pTomorrowMorning1 = VoiceCommandParser.parse("明早关空调")
        XCTAssertEqual(pTomorrowMorning1?.command, .schedulePower(hour: 7, minute: 0, power: false))

        let pTomorrowMorningAll = VoiceCommandParser.parse("全屋明早关空调")
        XCTAssertEqual(pTomorrowMorningAll?.command, .schedulePower(hour: 7, minute: 0, power: false))
        XCTAssertEqual(pTomorrowMorningAll?.displayText, "定时全屋在 明天 07:00 关机")

        let pTodayMorning = VoiceCommandParser.parse("今早开机")
        XCTAssertEqual(pTodayMorning?.command, .schedulePower(hour: 7, minute: 0, power: true))

        let pForenoon = VoiceCommandParser.parse("上午开机")
        XCTAssertEqual(pForenoon?.command, .schedulePower(hour: 9, minute: 0, power: true))

        let pAfternoon = VoiceCommandParser.parse("下午关空调")
        XCTAssertEqual(pAfternoon?.command, .schedulePower(hour: 14, minute: 0, power: false))

        let pAfternoonPost = VoiceCommandParser.parse("午后开机")
        XCTAssertEqual(pAfternoonPost?.command, .schedulePower(hour: 14, minute: 0, power: true))

        let pTomorrowNoon = VoiceCommandParser.parse("明午关机")
        XCTAssertEqual(pTomorrowNoon?.command, .schedulePower(hour: 14, minute: 0, power: false))

        let pEvening = VoiceCommandParser.parse("晚上开机")
        XCTAssertEqual(pEvening?.command, .schedulePower(hour: 21, minute: 0, power: true))

        let pTonight = VoiceCommandParser.parse("今晚关机")
        XCTAssertEqual(pTonight?.command, .schedulePower(hour: 21, minute: 0, power: false))

        let pTomorrowNight = VoiceCommandParser.parse("明晚关机")
        XCTAssertEqual(pTomorrowNight?.command, .schedulePower(hour: 21, minute: 0, power: false))

        let pLateNight1 = VoiceCommandParser.parse("深夜关机")
        XCTAssertEqual(pLateNight1?.command, .schedulePower(hour: 23, minute: 0, power: false))

        let pLateNight2 = VoiceCommandParser.parse("半夜关机")
        XCTAssertEqual(pLateNight2?.command, .schedulePower(hour: 23, minute: 0, power: false))

        let pWeeHours = VoiceCommandParser.parse("凌晨开机")
        XCTAssertEqual(pWeeHours?.command, .schedulePower(hour: 5, minute: 0, power: true))

        let pTomorrow = VoiceCommandParser.parse("明天关机")
        XCTAssertEqual(pTomorrow?.command, .schedulePower(hour: 8, minute: 0, power: false))

        let pAfterTomorrow = VoiceCommandParser.parse("后天开机")
        XCTAssertEqual(pAfterTomorrow?.command, .schedulePower(hour: 8, minute: 0, power: true))

        // v1.9.80 广义口语全时相扩展：白天/日间/大清早/大半夜/大晚上/天亮/天黑/天明
        let pDaytimeOff = VoiceCommandParser.parse("白天关空调")
        XCTAssertEqual(pDaytimeOff?.command, .schedulePower(hour: 8, minute: 0, power: false))

        let pDaytimeOn = VoiceCommandParser.parse("白天开机")
        XCTAssertEqual(pDaytimeOn?.command, .schedulePower(hour: 8, minute: 0, power: true))

        let pDaytimeAll = VoiceCommandParser.parse("全屋白天关空调")
        XCTAssertEqual(pDaytimeAll?.command, .schedulePower(hour: 8, minute: 0, power: false))
        XCTAssertEqual(pDaytimeAll?.displayText, "定时全屋在 08:00 关机")

        let pEarlyMorning = VoiceCommandParser.parse("大清早开机")
        XCTAssertEqual(pEarlyMorning?.command, .schedulePower(hour: 6, minute: 0, power: true))

        let pLateEvening = VoiceCommandParser.parse("大晚上开机")
        XCTAssertEqual(pLateEvening?.command, .schedulePower(hour: 21, minute: 0, power: true))

        let pMidnightDeep = VoiceCommandParser.parse("大半夜关机")
        XCTAssertEqual(pMidnightDeep?.command, .schedulePower(hour: 23, minute: 0, power: false))

        let pDawnOn = VoiceCommandParser.parse("天亮开机")
        XCTAssertEqual(pDawnOn?.command, .schedulePower(hour: 6, minute: 0, power: true))

        let pDawnOff = VoiceCommandParser.parse("天亮关空调")
        XCTAssertEqual(pDawnOff?.command, .schedulePower(hour: 6, minute: 0, power: false))

        let pDuskOn = VoiceCommandParser.parse("天黑开空调")
        XCTAssertEqual(pDuskOn?.command, .schedulePower(hour: 18, minute: 0, power: true))

        let pDuskOff = VoiceCommandParser.parse("天黑关空调")
        XCTAssertEqual(pDuskOff?.command, .schedulePower(hour: 18, minute: 0, power: false))

        let pDaybreak = VoiceCommandParser.parse("天明开机")
        XCTAssertEqual(pDaybreak?.command, .schedulePower(hour: 6, minute: 0, power: true))

        // 2. 口语半点时相调度
        let pHalf1 = VoiceCommandParser.parse("明早半开机")
        XCTAssertEqual(pHalf1?.command, .schedulePower(hour: 7, minute: 30, power: true))

        let pHalf2 = VoiceCommandParser.parse("早上半关机")
        XCTAssertEqual(pHalf2?.command, .schedulePower(hour: 7, minute: 30, power: false))

        let pHalf3 = VoiceCommandParser.parse("下午半关机")
        XCTAssertEqual(pHalf3?.command, .schedulePower(hour: 14, minute: 30, power: false))

        let pHalf4 = VoiceCommandParser.parse("晚上半关机")
        XCTAssertEqual(pHalf4?.command, .schedulePower(hour: 21, minute: 30, power: false))

        let pHalf5 = VoiceCommandParser.parse("今晚半开机")
        XCTAssertEqual(pHalf5?.command, .schedulePower(hour: 21, minute: 30, power: true))

        let pHalf6 = VoiceCommandParser.parse("明晚半关机")
        XCTAssertEqual(pHalf6?.command, .schedulePower(hour: 21, minute: 30, power: false))

        let pHalf7 = VoiceCommandParser.parse("深夜半关机")
        XCTAssertEqual(pHalf7?.command, .schedulePower(hour: 23, minute: 30, power: false))

        let pHalf8 = VoiceCommandParser.parse("半夜半关机")
        XCTAssertEqual(pHalf8?.command, .schedulePower(hour: 23, minute: 30, power: false))

        let pHalf9 = VoiceCommandParser.parse("凌晨半开机")
        XCTAssertEqual(pHalf9?.command, .schedulePower(hour: 5, minute: 30, power: true))

        let pHalfDaytime = VoiceCommandParser.parse("白天半关机")
        XCTAssertEqual(pHalfDaytime?.command, .schedulePower(hour: 8, minute: 30, power: false))

        let pHalfEarlyMorning = VoiceCommandParser.parse("大清早半开机")
        XCTAssertEqual(pHalfEarlyMorning?.command, .schedulePower(hour: 6, minute: 30, power: true))

        let pHalfLateEvening = VoiceCommandParser.parse("大晚上半开机")
        XCTAssertEqual(pHalfLateEvening?.command, .schedulePower(hour: 21, minute: 30, power: true))

        let pHalfMidnightDeep = VoiceCommandParser.parse("大半夜半关机")
        XCTAssertEqual(pHalfMidnightDeep?.command, .schedulePower(hour: 23, minute: 30, power: false))

        let pHalfDawn = VoiceCommandParser.parse("天亮半开机")
        XCTAssertEqual(pHalfDawn?.command, .schedulePower(hour: 6, minute: 30, power: true))

        let pHalfDusk = VoiceCommandParser.parse("天黑半关机")
        XCTAssertEqual(pHalfDusk?.command, .schedulePower(hour: 18, minute: 30, power: false))

        let pNoon = VoiceCommandParser.parse("晌午关空调")
        XCTAssertEqual(pNoon?.command, .schedulePower(hour: 12, minute: 0, power: false))

        let pNoonOpen = VoiceCommandParser.parse("晌午开机")
        XCTAssertEqual(pNoonOpen?.command, .schedulePower(hour: 12, minute: 0, power: true))

        let pNoonHalf = VoiceCommandParser.parse("晌午半关空调")
        XCTAssertEqual(pNoonHalf?.command, .schedulePower(hour: 12, minute: 30, power: false))

        let pLateNight = VoiceCommandParser.parse("后半夜关空调")
        XCTAssertEqual(pLateNight?.command, .schedulePower(hour: 2, minute: 0, power: false))

        let pLateNightPoint = VoiceCommandParser.parse("后半夜两点开机")
        XCTAssertEqual(pLateNightPoint?.command, .schedulePower(hour: 2, minute: 0, power: true))

        let pLateNightHalf = VoiceCommandParser.parse("后半夜半关机")
        XCTAssertEqual(pLateNightHalf?.command, .schedulePower(hour: 2, minute: 30, power: false))

        let pMidnightDeep3 = VoiceCommandParser.parse("三更半夜关机")
        XCTAssertEqual(pMidnightDeep3?.command, .schedulePower(hour: 0, minute: 0, power: false))

        let pMidnightDeep3Open = VoiceCommandParser.parse("三更半夜开机")
        XCTAssertEqual(pMidnightDeep3Open?.command, .schedulePower(hour: 0, minute: 0, power: true))

        let pDawnGlimmer = VoiceCommandParser.parse("天蒙蒙亮关机")
        XCTAssertEqual(pDawnGlimmer?.command, .schedulePower(hour: 6, minute: 0, power: false))

        let pDawnGlimmerHalf = VoiceCommandParser.parse("天蒙蒙亮半开机")
        XCTAssertEqual(pDawnGlimmerHalf?.command, .schedulePower(hour: 6, minute: 30, power: true))

        let pEarlyNight = VoiceCommandParser.parse("前半夜关空调")
        XCTAssertEqual(pEarlyNight?.command, .schedulePower(hour: 22, minute: 0, power: false))

        let pEarlyNightOpen = VoiceCommandParser.parse("前半夜开机")
        XCTAssertEqual(pEarlyNightOpen?.command, .schedulePower(hour: 22, minute: 0, power: true))

        let pEarlyNightHalf = VoiceCommandParser.parse("前半夜半关空调")
        XCTAssertEqual(pEarlyNightHalf?.command, .schedulePower(hour: 22, minute: 30, power: false))

        let pEarlyNightPoint = VoiceCommandParser.parse("前半夜十点开机")
        XCTAssertEqual(pEarlyNightPoint?.command, .schedulePower(hour: 22, minute: 0, power: true))

        let pMidnightDeepHalf = VoiceCommandParser.parse("三更半夜半关机")
        XCTAssertEqual(pMidnightDeepHalf?.command, .schedulePower(hour: 0, minute: 30, power: false))

        // 3. 重复口语时相调度
        let pRepEveryDayMorning = VoiceCommandParser.parse("每天早上关空调")
        XCTAssertEqual(pRepEveryDayMorning?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: false, repeatWeekdays: [], repeatLabel: "每天"))

        let pRepEveryDayNoon = VoiceCommandParser.parse("每天晌午关空调")
        XCTAssertEqual(pRepEveryDayNoon?.command, .scheduleRepeatPower(hour: 12, minute: 0, power: false, repeatWeekdays: [], repeatLabel: "每天"))

        let pRepEveryDayEarlyNight = VoiceCommandParser.parse("每天前半夜关空调")
        XCTAssertEqual(pRepEveryDayEarlyNight?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [], repeatLabel: "每天"))

        let pRepEveryDayDaytime = VoiceCommandParser.parse("每天白天关空调")
        XCTAssertEqual(pRepEveryDayDaytime?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [], repeatLabel: "每天"))

        let pRepWorkdayLateNight = VoiceCommandParser.parse("工作日后半夜关空调")
        XCTAssertEqual(pRepWorkdayLateNight?.command, .scheduleRepeatPower(hour: 2, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))

        let pRepWorkdayEarlyNight = VoiceCommandParser.parse("工作日前半夜关机")
        XCTAssertEqual(pRepWorkdayEarlyNight?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))

        let pRepWorkdayDaytime = VoiceCommandParser.parse("工作日白天关空调")
        XCTAssertEqual(pRepWorkdayDaytime?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))

        let pRepWorkdayNight = VoiceCommandParser.parse("工作日晚上关空调")
        XCTAssertEqual(pRepWorkdayNight?.command, .scheduleRepeatPower(hour: 21, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))

        let pRepWeekendMorning = VoiceCommandParser.parse("周末早上开机")
        XCTAssertEqual(pRepWeekendMorning?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))

        let pRepEveryDayDeepNight = VoiceCommandParser.parse("每天深宵关机")
        XCTAssertEqual(pRepEveryDayDeepNight?.command, .scheduleRepeatPower(hour: 23, minute: 0, power: false, repeatWeekdays: [], repeatLabel: "每天"))

        let pRepWorkdayAllNight = VoiceCommandParser.parse("工作日通宵关空调")
        XCTAssertEqual(pRepWorkdayAllNight?.command, .scheduleRepeatPower(hour: 23, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))

        let pRepWeekendDeepNight = VoiceCommandParser.parse("周末夜深开机")
        XCTAssertEqual(pRepWeekendDeepNight?.command, .scheduleRepeatPower(hour: 23, minute: 0, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))

        // 深宵/通宵/夜深独立时相与半点口语 (v1.9.83)
        let pDeepNightOff = VoiceCommandParser.parse("深宵关空调")
        XCTAssertEqual(pDeepNightOff?.command, .schedulePower(hour: 23, minute: 0, power: false))

        let pDeepNightOn = VoiceCommandParser.parse("深宵开机")
        XCTAssertEqual(pDeepNightOn?.command, .schedulePower(hour: 23, minute: 0, power: true))

        let pDeepNightHalf = VoiceCommandParser.parse("深宵半关机")
        XCTAssertEqual(pDeepNightHalf?.command, .schedulePower(hour: 23, minute: 30, power: false))

        let pAllNightOff = VoiceCommandParser.parse("通宵关机")
        XCTAssertEqual(pAllNightOff?.command, .schedulePower(hour: 23, minute: 0, power: false))

        let pAllNightOn = VoiceCommandParser.parse("通宵开空调")
        XCTAssertEqual(pAllNightOn?.command, .schedulePower(hour: 23, minute: 0, power: true))

        let pAllNightHalf = VoiceCommandParser.parse("通宵半关空调")
        XCTAssertEqual(pAllNightHalf?.command, .schedulePower(hour: 23, minute: 30, power: false))

        let pNightDeepOff = VoiceCommandParser.parse("夜深关空调")
        XCTAssertEqual(pNightDeepOff?.command, .schedulePower(hour: 23, minute: 0, power: false))

        let pNightDeepOn = VoiceCommandParser.parse("夜深开机")
        XCTAssertEqual(pNightDeepOn?.command, .schedulePower(hour: 23, minute: 0, power: true))

        let pNightDeepHalf = VoiceCommandParser.parse("夜深半关机")
        XCTAssertEqual(pNightDeepHalf?.command, .schedulePower(hour: 23, minute: 30, power: false))

        // 今夜/明夜/每夜/整夜/彻夜/隔夜/后夜/隔日/翌日独立时相与半点口语 (v1.9.84)
        let pTonightOff = VoiceCommandParser.parse("今夜关空调")
        XCTAssertEqual(pTonightOff?.command, .schedulePower(hour: 21, minute: 0, power: false))

        let pTonightOn = VoiceCommandParser.parse("今夜开机")
        XCTAssertEqual(pTonightOn?.command, .schedulePower(hour: 21, minute: 0, power: true))

        let pTonightHalf = VoiceCommandParser.parse("今夜半关机")
        XCTAssertEqual(pTonightHalf?.command, .schedulePower(hour: 21, minute: 30, power: false))

        let pTomorrowNightOff = VoiceCommandParser.parse("明夜关空调")
        XCTAssertEqual(pTomorrowNightOff?.command, .schedulePower(hour: 21, minute: 0, power: false))

        let pTomorrowNightOn = VoiceCommandParser.parse("明夜开机")
        XCTAssertEqual(pTomorrowNightOn?.command, .schedulePower(hour: 21, minute: 0, power: true))

        let pTomorrowNightHalf = VoiceCommandParser.parse("明夜半关空调")
        XCTAssertEqual(pTomorrowNightHalf?.command, .schedulePower(hour: 21, minute: 30, power: false))

        let pEveryNight10 = VoiceCommandParser.parse("每夜十点关空调")
        XCTAssertEqual(pEveryNight10?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [], repeatLabel: "每天"))

        let pTonight10 = VoiceCommandParser.parse("今夜十点关空调")
        XCTAssertEqual(pTonight10?.command, .schedulePower(hour: 22, minute: 0, power: false))

        let pTomorrowNight10 = VoiceCommandParser.parse("明夜十点关空调")
        XCTAssertEqual(pTomorrowNight10?.command, .schedulePower(hour: 22, minute: 0, power: false))

        let pAllNight = VoiceCommandParser.parse("整夜开空调")
        XCTAssertEqual(pAllNight?.command, .schedulePower(hour: 23, minute: 0, power: true))

        let pThroughNight = VoiceCommandParser.parse("彻夜开空调")
        XCTAssertEqual(pThroughNight?.command, .schedulePower(hour: 23, minute: 0, power: true))

        let pOvernightOff = VoiceCommandParser.parse("隔夜关机")
        XCTAssertEqual(pOvernightOff?.command, .schedulePower(hour: 23, minute: 0, power: false))

        let pLateNightOff = VoiceCommandParser.parse("后夜关机")
        XCTAssertEqual(pLateNightOff?.command, .schedulePower(hour: 2, minute: 0, power: false))

        let pLateNightHalf = VoiceCommandParser.parse("后夜半关机")
        XCTAssertEqual(pLateNightHalf?.command, .schedulePower(hour: 2, minute: 30, power: false))

        let pNextDayOff = VoiceCommandParser.parse("隔日关空调")
        XCTAssertEqual(pNextDayOff?.command, .schedulePower(hour: 8, minute: 0, power: false))

        let pTomorrowDayOn = VoiceCommandParser.parse("翌日开机")
        XCTAssertEqual(pTomorrowDayOn?.command, .schedulePower(hour: 8, minute: 0, power: true))

        let pAllTomorrowNight = VoiceCommandParser.parse("全屋明夜关空调")
        XCTAssertEqual(pAllTomorrowNight?.command, .schedulePower(hour: 21, minute: 0, power: false))

        // 今晨/明晨/每晨/次晨/翌晨/夜半独立时相与半点口语 (v1.9.85)
        let pThisMorningOff = VoiceCommandParser.parse("今晨关空调")
        XCTAssertEqual(pThisMorningOff?.command, .schedulePower(hour: 7, minute: 0, power: false))

        let pThisMorningOn = VoiceCommandParser.parse("今晨开机")
        XCTAssertEqual(pThisMorningOn?.command, .schedulePower(hour: 7, minute: 0, power: true))

        let pThisMorningHalf = VoiceCommandParser.parse("今晨半关机")
        XCTAssertEqual(pThisMorningHalf?.command, .schedulePower(hour: 7, minute: 30, power: false))

        let pTomorrowMorningOff = VoiceCommandParser.parse("明晨关空调")
        XCTAssertEqual(pTomorrowMorningOff?.command, .schedulePower(hour: 7, minute: 0, power: false))

        let pTomorrowMorningOn = VoiceCommandParser.parse("明晨开机")
        XCTAssertEqual(pTomorrowMorningOn?.command, .schedulePower(hour: 7, minute: 0, power: true))

        let pTomorrowMorningHalf = VoiceCommandParser.parse("明晨半关空调")
        XCTAssertEqual(pTomorrowMorningHalf?.command, .schedulePower(hour: 7, minute: 30, power: false))

        let pEveryMorningOff = VoiceCommandParser.parse("每晨关空调")
        XCTAssertEqual(pEveryMorningOff?.command, .scheduleRepeatPower(hour: 7, minute: 0, power: false, repeatWeekdays: [], repeatLabel: "每天"))

        let pEveryMorningHalf = VoiceCommandParser.parse("每晨半关空调")
        XCTAssertEqual(pEveryMorningHalf?.command, .scheduleRepeatPower(hour: 7, minute: 30, power: false, repeatWeekdays: [], repeatLabel: "每天"))

        let pNextMorningOff = VoiceCommandParser.parse("次晨关空调")
        XCTAssertEqual(pNextMorningOff?.command, .schedulePower(hour: 7, minute: 0, power: false))

        let pNextMorningHalf = VoiceCommandParser.parse("次晨半关机")
        XCTAssertEqual(pNextMorningHalf?.command, .schedulePower(hour: 7, minute: 30, power: false))

        let pYesterMorningOn = VoiceCommandParser.parse("翌晨开机")
        XCTAssertEqual(pYesterMorningOn?.command, .schedulePower(hour: 7, minute: 0, power: true))

        let pYesterMorningHalf = VoiceCommandParser.parse("翌晨半开机")
        XCTAssertEqual(pYesterMorningHalf?.command, .schedulePower(hour: 7, minute: 30, power: true))

        let pEarlyMorningHalf = VoiceCommandParser.parse("清晨半关机")
        XCTAssertEqual(pEarlyMorningHalf?.command, .schedulePower(hour: 6, minute: 30, power: false))

        let pDawnMorningHalf = VoiceCommandParser.parse("早晨半关机")
        XCTAssertEqual(pDawnMorningHalf?.command, .schedulePower(hour: 6, minute: 30, power: false))

        let pSunriseMorningHalf = VoiceCommandParser.parse("黎明半开机")
        XCTAssertEqual(pSunriseMorningHalf?.command, .schedulePower(hour: 6, minute: 30, power: true))

        let pEveryEarlyHalf = VoiceCommandParser.parse("每早半关机")
        XCTAssertEqual(pEveryEarlyHalf?.command, .scheduleRepeatPower(hour: 7, minute: 30, power: false, repeatWeekdays: [], repeatLabel: "每天"))

        let pEveryEveningHalf = VoiceCommandParser.parse("每晚半关机")
        XCTAssertEqual(pEveryEveningHalf?.command, .scheduleRepeatPower(hour: 21, minute: 30, power: false, repeatWeekdays: [], repeatLabel: "每天"))

        let pMidnightNightOff = VoiceCommandParser.parse("夜半关空调")
        XCTAssertEqual(pMidnightNightOff?.command, .schedulePower(hour: 0, minute: 0, power: false))

        let pMidnightNightOn = VoiceCommandParser.parse("夜半开机")
        XCTAssertEqual(pMidnightNightOn?.command, .schedulePower(hour: 0, minute: 0, power: true))

        let pMidnightNightHalf = VoiceCommandParser.parse("夜半半关机")
        XCTAssertEqual(pMidnightNightHalf?.command, .schedulePower(hour: 0, minute: 30, power: false))

        let pMidnight12Off = VoiceCommandParser.parse("夜半12点关空调")
        XCTAssertEqual(pMidnight12Off?.command, .schedulePower(hour: 0, minute: 0, power: false))

        let pMidnight1Off = VoiceCommandParser.parse("夜半1点关机")
        XCTAssertEqual(pMidnight1Off?.command, .schedulePower(hour: 1, minute: 0, power: false))

        let pMidnight10Off = VoiceCommandParser.parse("夜半10点关机")
        XCTAssertEqual(pMidnight10Off?.command, .schedulePower(hour: 22, minute: 0, power: false))

        let pAllMorningOff = VoiceCommandParser.parse("全屋明晨关空调")
        XCTAssertEqual(pAllMorningOff?.command, .schedulePower(hour: 7, minute: 0, power: false))

        let pAllMidnightOff = VoiceCommandParser.parse("全屋夜半关空调")
        XCTAssertEqual(pAllMidnightOff?.command, .schedulePower(hour: 0, minute: 0, power: false))

        // v1.9.86 跨天口语词群大一统纳管 (明日/隔天/后日/大后日/明儿个)
        let pTomorrowDayOff = VoiceCommandParser.parse("明日关空调")
        XCTAssertEqual(pTomorrowDayOff?.command, .schedulePower(hour: 8, minute: 0, power: false))

        let pTomorrowDayOn = VoiceCommandParser.parse("明日开机")
        XCTAssertEqual(pTomorrowDayOn?.command, .schedulePower(hour: 8, minute: 0, power: true))

        let pTomorrowDayHalf = VoiceCommandParser.parse("明日半关机")
        XCTAssertEqual(pTomorrowDayHalf?.command, .schedulePower(hour: 8, minute: 30, power: false))

        let pTomorrowDay7Off = VoiceCommandParser.parse("明日7点关空调")
        XCTAssertEqual(pTomorrowDay7Off?.command, .schedulePower(hour: 7, minute: 0, power: false))

        let pNextDayOff = VoiceCommandParser.parse("隔天关空调")
        XCTAssertEqual(pNextDayOff?.command, .schedulePower(hour: 8, minute: 0, power: false))

        let pNextDayOn = VoiceCommandParser.parse("隔天开机")
        XCTAssertEqual(pNextDayOn?.command, .schedulePower(hour: 8, minute: 0, power: true))

        let pNextDayHalf = VoiceCommandParser.parse("隔天半开机")
        XCTAssertEqual(pNextDayHalf?.command, .schedulePower(hour: 8, minute: 30, power: true))

        let pDayAfterOff = VoiceCommandParser.parse("后日关空调")
        XCTAssertEqual(pDayAfterOff?.command, .schedulePower(hour: 8, minute: 0, power: false))

        let pDayAfterOn = VoiceCommandParser.parse("后日开机")
        XCTAssertEqual(pDayAfterOn?.command, .schedulePower(hour: 8, minute: 0, power: true))

        let pDayAfterHalf = VoiceCommandParser.parse("后日半关机")
        XCTAssertEqual(pDayAfterHalf?.command, .schedulePower(hour: 8, minute: 30, power: false))

        let pGreatDayAfterOff = VoiceCommandParser.parse("大后日关机")
        XCTAssertEqual(pGreatDayAfterOff?.command, .schedulePower(hour: 8, minute: 0, power: false))

        let pMingErGeOff = VoiceCommandParser.parse("明儿个关机")
        XCTAssertEqual(pMingErGeOff?.command, .schedulePower(hour: 8, minute: 0, power: false))

        let pMingErGeHalf = VoiceCommandParser.parse("明儿个半开机")
        XCTAssertEqual(pMingErGeHalf?.command, .schedulePower(hour: 8, minute: 30, power: true))

        let pAllTomorrowDayOff = VoiceCommandParser.parse("全屋明日关空调")
        XCTAssertEqual(pAllTomorrowDayOff?.command, .schedulePower(hour: 8, minute: 0, power: false))

        let pAllNextDayOff = VoiceCommandParser.parse("全屋隔天关空调")
        XCTAssertEqual(pAllNextDayOff?.command, .schedulePower(hour: 8, minute: 0, power: false))

        let pAllDayAfterOff = VoiceCommandParser.parse("全屋后日关空调")
        XCTAssertEqual(pAllDayAfterOff?.command, .schedulePower(hour: 8, minute: 0, power: false))

        // 4. 严苛防即时开关机误触验证（绝对禁止被误判为 setPower / turnOffAll / turnOnAll）
        XCTAssertNotEqual(VoiceCommandParser.parse("明早关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("明早关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋明早关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("明晚关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("今晚关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("早上开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("白天关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("白天关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋白天关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("大清早开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("大清早开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("大晚上开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("大半夜关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("前半夜关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("前半夜关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋前半夜关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("前半夜开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("后半夜关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("后半夜关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋后半夜关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("后半夜开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("深宵关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("深宵关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋深宵关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("深宵开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("通宵关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("通宵关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋通宵关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("通宵开空调")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("夜深关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("夜深关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋夜深关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("夜深开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("今夜关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("今夜关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋今夜关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("今夜开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("明夜关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("明夜关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋明夜关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("明夜开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("每夜关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("每夜关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("整夜开空调")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("彻夜开空调")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("后夜关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("隔夜关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("隔日关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("翌日开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("今晨关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("今晨关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋今晨关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("明晨关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("明晨关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋明晨关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("次晨关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("次晨关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("翌晨开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("翌晨开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("每晨关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("每晨关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("夜半关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("夜半关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋夜半关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("夜半开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("夜半开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("晌午关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("晌午关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("三更半夜关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("天蒙蒙亮开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("天亮开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("天黑关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("天黑关空调")?.command, .turnOffAll)

        // v1.9.86 跨天口语词群严苛防即时误触断言
        XCTAssertNotEqual(VoiceCommandParser.parse("明日关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("明日关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋明日关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("明日开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("明日开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("隔天关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("隔天关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋隔天关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("隔天开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("后日关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("后日关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋后日关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("后日开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("大后日关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("大后日关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("明儿个关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("明儿个关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("后儿个关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("后儿个关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("后儿个开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("今儿个关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("今儿个关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("明天半关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("今天半开机")?.command, .setPower(true))
    }

    // MARK: - v1.9.87 跨天口语半点时相归一、dayDesc 文本反馈与顺延明示测试

    func testCrossDayAndColloquialTimingPrecisionV1987() {
        // 1. 口语半点时相归一化精准映射
        let r1 = VoiceCommandParser.parse("明天半关空调")
        XCTAssertEqual(r1?.command, .schedulePower(hour: 8, minute: 30, power: false))
        XCTAssertTrue(r1?.displayText.contains("明天 08:30 关机") == true)

        let r2 = VoiceCommandParser.parse("后天半开机")
        XCTAssertEqual(r2?.command, .schedulePower(hour: 8, minute: 30, power: true))
        XCTAssertTrue(r2?.displayText.contains("后天 08:30 开机") == true)

        let r3 = VoiceCommandParser.parse("大后天半关机")
        XCTAssertEqual(r3?.command, .schedulePower(hour: 8, minute: 30, power: false))
        XCTAssertTrue(r3?.displayText.contains("大后天 08:30 关机") == true)

        let r4 = VoiceCommandParser.parse("大后日半关空调")
        XCTAssertEqual(r4?.command, .schedulePower(hour: 8, minute: 30, power: false))
        XCTAssertTrue(r4?.displayText.contains("大后天 08:30 关机") == true)

        let r5 = VoiceCommandParser.parse("今天半开机")
        XCTAssertEqual(r5?.command, .schedulePower(hour: 8, minute: 30, power: true))
        XCTAssertTrue(r5?.displayText.contains("今天 08:30 开机") == true)

        let r6 = VoiceCommandParser.parse("今日半关机")
        XCTAssertEqual(r6?.command, .schedulePower(hour: 8, minute: 30, power: false))
        XCTAssertTrue(r6?.displayText.contains("今天 08:30 关机") == true)

        let r7 = VoiceCommandParser.parse("后儿个关空调")
        XCTAssertEqual(r7?.command, .schedulePower(hour: 8, minute: 0, power: false))
        XCTAssertTrue(r7?.displayText.contains("后天 08:00 关机") == true)

        let r8 = VoiceCommandParser.parse("后儿个半开机")
        XCTAssertEqual(r8?.command, .schedulePower(hour: 8, minute: 30, power: true))
        XCTAssertTrue(r8?.displayText.contains("后天 08:30 开机") == true)

        // 2. dayDesc 跨天与当日词群文本反馈精准对齐
        let d1 = VoiceCommandParser.parse("明日7点关空调")
        XCTAssertEqual(d1?.command, .schedulePower(hour: 7, minute: 0, power: false))
        XCTAssertTrue(d1?.displayText.contains("明天 07:00 关机") == true)

        let d2 = VoiceCommandParser.parse("后日8点关机")
        XCTAssertEqual(d2?.command, .schedulePower(hour: 8, minute: 0, power: false))
        XCTAssertTrue(d2?.displayText.contains("后天 08:00 关机") == true)

        let d3 = VoiceCommandParser.parse("大后日8点关机")
        XCTAssertEqual(d3?.command, .schedulePower(hour: 8, minute: 0, power: false))
        XCTAssertTrue(d3?.displayText.contains("大后天 08:00 关机") == true)

        let d4 = VoiceCommandParser.parse("大后天8点关机")
        XCTAssertEqual(d4?.command, .schedulePower(hour: 8, minute: 0, power: false))
        XCTAssertTrue(d4?.displayText.contains("大后天 08:00 关机") == true)

        let d5 = VoiceCommandParser.parse("全屋明日关空调")
        XCTAssertEqual(d5?.command, .schedulePower(hour: 8, minute: 0, power: false))
        XCTAssertTrue(d5?.displayText.contains("全屋在 明天 08:00 关机") == true)

        let d6 = VoiceCommandParser.parse("全屋后日关空调")
        XCTAssertEqual(d6?.command, .schedulePower(hour: 8, minute: 0, power: false))
        XCTAssertTrue(d6?.displayText.contains("全屋在 后天 08:00 关机") == true)

        let d7 = VoiceCommandParser.parse("今天晚上10点关空调")
        XCTAssertEqual(d7?.command, .schedulePower(hour: 22, minute: 0, power: false))
        XCTAssertTrue(d7?.displayText.contains("今天 22:00 关机") == true)

        let d8 = VoiceCommandParser.parse("今晚10点关空调")
        XCTAssertEqual(d8?.command, .schedulePower(hour: 22, minute: 0, power: false))
        XCTAssertTrue(d8?.displayText.contains("今天 22:00 关机") == true)
    }

    // MARK: - v1.9.88 当日与跨天自然口语全时相归一、dayDesc 反馈与严苛防即时误触测试

    func testCrossDayAndColloquialTimingPrecisionV1988() {
        // 1. 口语两字形态与复合时相半点归一
        let r1 = VoiceCommandParser.parse("明儿半开机")
        XCTAssertEqual(r1?.command, .schedulePower(hour: 8, minute: 30, power: true))
        XCTAssertTrue(r1?.displayText.contains("明天 08:30 开机") == true)

        let r2 = VoiceCommandParser.parse("今儿半关机")
        XCTAssertEqual(r2?.command, .schedulePower(hour: 8, minute: 30, power: false))
        XCTAssertTrue(r2?.displayText.contains("今天 08:30 关机") == true)

        let r3 = VoiceCommandParser.parse("后儿半开机")
        XCTAssertEqual(r3?.command, .schedulePower(hour: 8, minute: 30, power: true))
        XCTAssertTrue(r3?.displayText.contains("后天 08:30 开机") == true)

        let r4 = VoiceCommandParser.parse("大后儿半关机")
        XCTAssertEqual(r4?.command, .schedulePower(hour: 8, minute: 30, power: false))
        XCTAssertTrue(r4?.displayText.contains("大后天 08:30 关机") == true)

        let r5 = VoiceCommandParser.parse("大后儿个半开机")
        XCTAssertEqual(r5?.command, .schedulePower(hour: 8, minute: 30, power: true))
        XCTAssertTrue(r5?.displayText.contains("大后天 08:30 开机") == true)

        // 2. 独立口语时相调度纳管（后儿、大后儿、今天、今日等）
        let s1 = VoiceCommandParser.parse("后儿关机")
        XCTAssertEqual(s1?.command, .schedulePower(hour: 8, minute: 0, power: false))
        XCTAssertTrue(s1?.displayText.contains("后天 08:00 关机") == true)

        let s2 = VoiceCommandParser.parse("大后儿个开机")
        XCTAssertEqual(s2?.command, .schedulePower(hour: 8, minute: 0, power: true))
        XCTAssertTrue(s2?.displayText.contains("大后天 08:00 开机") == true)

        let s3 = VoiceCommandParser.parse("今天关空调")
        XCTAssertEqual(s3?.command, .schedulePower(hour: 8, minute: 0, power: false))
        XCTAssertTrue(s3?.displayText.contains("今天 08:00 关机") == true)

        let s4 = VoiceCommandParser.parse("今日开机")
        XCTAssertEqual(s4?.command, .schedulePower(hour: 8, minute: 0, power: true))
        XCTAssertTrue(s4?.displayText.contains("今天 08:00 开机") == true)

        let s5 = VoiceCommandParser.parse("全屋今天关空调")
        XCTAssertEqual(s5?.command, .schedulePower(hour: 8, minute: 0, power: false))
        XCTAssertTrue(s5?.displayText.contains("全屋在 今天 08:00 关机") == true)

        let s6 = VoiceCommandParser.parse("全屋今日开机")
        XCTAssertEqual(s6?.command, .schedulePower(hour: 8, minute: 0, power: true))
        XCTAssertTrue(s6?.displayText.contains("全屋在 今天 08:00 开机") == true)

        // 3. 严苛防即时误触全景加固断言
        XCTAssertNotEqual(VoiceCommandParser.parse("今天关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("今天关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("今日关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("今日关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋今天关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋今日关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("后儿关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("后儿关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("大后儿个关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("大后儿个关机")?.command, .turnOffAll)
    }

    // MARK: - v1.9.89 循环周期全时相大一统、半点归一与严苛防即时误触加固测试

    func testRepeatSchedulePrecisionAndProtectionV1989() {
        // 1. 无钟点独立循环周期调度识别（工作日、周末、双休、单休、每天、天天、每日等默认映射 08:00）
        let r1 = VoiceCommandParser.parse("工作日关空调")
        XCTAssertEqual(r1?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))
        XCTAssertTrue(r1?.displayText.contains("工作日 08:00 关机") == true)

        let r2 = VoiceCommandParser.parse("工作日开机")
        XCTAssertEqual(r2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))
        XCTAssertTrue(r2?.displayText.contains("工作日 08:00 开机") == true)

        let r3 = VoiceCommandParser.parse("周末关空调")
        XCTAssertEqual(r3?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(r3?.displayText.contains("周末 08:00 关机") == true)

        let r4 = VoiceCommandParser.parse("周末开机")
        XCTAssertEqual(r4?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(r4?.displayText.contains("周末 08:00 开机") == true)

        let r5 = VoiceCommandParser.parse("双休关机")
        XCTAssertEqual(r5?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(r5?.displayText.contains("周末 08:00 关机") == true)

        let r6 = VoiceCommandParser.parse("单休关空调")
        XCTAssertEqual(r6?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))
        XCTAssertTrue(r6?.displayText.contains("周一至周六 08:00 关机") == true)

        let r7 = VoiceCommandParser.parse("每天关空调")
        XCTAssertEqual(r7?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [], repeatLabel: "每天"))
        XCTAssertTrue(r7?.displayText.contains("每天 08:00 关机") == true)

        let r8 = VoiceCommandParser.parse("天天关机")
        XCTAssertEqual(r8?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [], repeatLabel: "每天"))
        XCTAssertTrue(r8?.displayText.contains("每天 08:00 关机") == true)

        let r9 = VoiceCommandParser.parse("每日开机")
        XCTAssertEqual(r9?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [], repeatLabel: "每天"))
        XCTAssertTrue(r9?.displayText.contains("每天 08:00 开机") == true)

        let r10 = VoiceCommandParser.parse("全屋工作日关空调")
        XCTAssertEqual(r10?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))
        XCTAssertTrue(r10?.displayText.contains("全屋在 工作日 08:00 关机") == true)

        let r11 = VoiceCommandParser.parse("全屋每天关空调")
        XCTAssertEqual(r11?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [], repeatLabel: "每天"))
        XCTAssertTrue(r11?.displayText.contains("全屋在 每天 08:00 关机") == true)

        // 2. 循环周期半点归一流水线测试（映射至 08:30）
        let h1 = VoiceCommandParser.parse("工作日半关机")
        XCTAssertEqual(h1?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: false, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))
        XCTAssertTrue(h1?.displayText.contains("工作日 08:30 关机") == true)

        let h2 = VoiceCommandParser.parse("周末半开机")
        XCTAssertEqual(h2?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(h2?.displayText.contains("周末 08:30 开机") == true)

        let h3 = VoiceCommandParser.parse("每天半关空调")
        XCTAssertEqual(h3?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: false, repeatWeekdays: [], repeatLabel: "每天"))
        XCTAssertTrue(h3?.displayText.contains("每天 08:30 关机") == true)

        let h4 = VoiceCommandParser.parse("天天半关机")
        XCTAssertEqual(h4?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: false, repeatWeekdays: [], repeatLabel: "每天"))
        XCTAssertTrue(h4?.displayText.contains("每天 08:30 关机") == true)

        let h5 = VoiceCommandParser.parse("双休半关机")
        XCTAssertEqual(h5?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: false, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(h5?.displayText.contains("周末 08:30 关机") == true)

        let h6 = VoiceCommandParser.parse("单休半开机")
        XCTAssertEqual(h6?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: true, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))
        XCTAssertTrue(h6?.displayText.contains("周一至周六 08:30 开机") == true)

        // 3. 严苛防即时误触全景加固断言（杜绝掉入 setPower / turnOffAll / turnOnAll）
        XCTAssertNotEqual(VoiceCommandParser.parse("工作日关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("工作日关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("工作日开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("工作日开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("周末关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("周末关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("每天关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("每天关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("天天关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("天天关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("双休关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("双休关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("单休关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("单休关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋工作日关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋每天关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋天天开机")?.command, .turnOnAll)
    }

    // MARK: - v1.9.90 单星期与全周日循环时相大一统、半点归一与严苛防即时误触加固测试

    func testSingleWeekdayRepeatSchedulePrecisionAndProtectionV1990() {
        // 1. 无钟点单星期自然口语大一统调度（映射至默认基准 08:00）
        let monOff = VoiceCommandParser.parse("周一关空调")
        XCTAssertEqual(monOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(monOff?.displayText.contains("每周一 08:00 关机") == true)

        let friOn = VoiceCommandParser.parse("周五开空调")
        XCTAssertEqual(friOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [6], repeatLabel: "每周五"))
        XCTAssertTrue(friOn?.displayText.contains("每周五 08:00 开机") == true)

        let wedOff = VoiceCommandParser.parse("星期三关机")
        XCTAssertEqual(wedOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [4], repeatLabel: "每周三"))
        XCTAssertTrue(wedOff?.displayText.contains("每周三 08:00 关机") == true)

        let sunOn = VoiceCommandParser.parse("星期天开机")
        XCTAssertEqual(sunOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1], repeatLabel: "每周日"))
        XCTAssertTrue(sunOn?.displayText.contains("每周日 08:00 开机") == true)

        let satOff = VoiceCommandParser.parse("礼拜六关机")
        XCTAssertEqual(satOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [7], repeatLabel: "每周六"))
        XCTAssertTrue(satOff?.displayText.contains("每周六 08:00 关机") == true)

        let numMon = VoiceCommandParser.parse("周1关空调")
        XCTAssertEqual(numMon?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [2], repeatLabel: "每周一"))

        let allMonOff = VoiceCommandParser.parse("全屋周一关空调")
        XCTAssertEqual(allMonOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(allMonOff?.displayText.contains("全屋在 每周一 08:00 关机") == true)

        let allFriOn = VoiceCommandParser.parse("全屋周五开机")
        XCTAssertEqual(allFriOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [6], repeatLabel: "每周五"))
        XCTAssertTrue(allFriOn?.displayText.contains("全屋在 每周五 08:00 开机") == true)

        // 2. 带具体钟点的单星期自然语言调度
        let monMorning = VoiceCommandParser.parse("周一早上8点开机")
        XCTAssertEqual(monMorning?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(monMorning?.displayText.contains("每周一 08:00 开机") == true)

        let friNight = VoiceCommandParser.parse("周五晚上10点关空调")
        XCTAssertEqual(friNight?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [6], repeatLabel: "每周五"))
        XCTAssertTrue(friNight?.displayText.contains("每周五 22:00 关机") == true)

        let tueAfternoon = VoiceCommandParser.parse("星期二下午3点关空调")
        XCTAssertEqual(tueAfternoon?.command, .scheduleRepeatPower(hour: 15, minute: 0, power: false, repeatWeekdays: [3], repeatLabel: "每周二"))
        XCTAssertTrue(tueAfternoon?.displayText.contains("每周二 15:00 关机") == true)

        let thuMorning = VoiceCommandParser.parse("礼拜四上午10点30分开机")
        XCTAssertEqual(thuMorning?.command, .scheduleRepeatPower(hour: 10, minute: 30, power: true, repeatWeekdays: [5], repeatLabel: "每周四"))
        XCTAssertTrue(thuMorning?.displayText.contains("每周四 10:30 开机") == true)

        let allSunNight = VoiceCommandParser.parse("全屋周日晚9点关机")
        XCTAssertEqual(allSunNight?.command, .scheduleRepeatPower(hour: 21, minute: 0, power: false, repeatWeekdays: [1], repeatLabel: "每周日"))
        XCTAssertTrue(allSunNight?.displayText.contains("全屋在 每周日 21:00 关机") == true)

        // 3. 口语单星期半点归一测试（映射至 08:30）
        let friHalf = VoiceCommandParser.parse("周五半关机")
        XCTAssertEqual(friHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: false, repeatWeekdays: [6], repeatLabel: "每周五"))
        XCTAssertTrue(friHalf?.displayText.contains("每周五 08:30 关机") == true)

        let monHalf = VoiceCommandParser.parse("周一半开机")
        XCTAssertEqual(monHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: true, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(monHalf?.displayText.contains("每周一 08:30 开机") == true)

        let sunHalf = VoiceCommandParser.parse("星期天半关机")
        XCTAssertEqual(sunHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: false, repeatWeekdays: [1], repeatLabel: "每周日"))
        XCTAssertTrue(sunHalf?.displayText.contains("每周日 08:30 关机") == true)

        let satHalf = VoiceCommandParser.parse("礼拜六半开机")
        XCTAssertEqual(satHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: true, repeatWeekdays: [7], repeatLabel: "每周六"))
        XCTAssertTrue(satHalf?.displayText.contains("每周六 08:30 开机") == true)

        // 4. 严苛防即时误触全景加固断言（杜绝掉入 setPower / turnOffAll / turnOnAll）
        XCTAssertNotEqual(VoiceCommandParser.parse("周一关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("周一关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("周一开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("周一开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("周五关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("周五关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("周五开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("周五开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("星期三关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("星期三关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("星期天开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("星期天开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("礼拜六关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("礼拜六关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋周一关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋周五开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋星期天关空调")?.command, .turnOffAll)
    }

    // MARK: - v1.9.91 自然口语下周/这周/本周/下星期/下礼拜循环调度大一统、半点归一与严苛防即时误触加固测试

    func testNaturalWeekRepeatScheduleAndProtectionV1991() {
        // 1. 无钟点跨周/本周口语大一统调度（映射至默认基准周一 08:00）
        let nextWeekOff = VoiceCommandParser.parse("下周关空调")
        XCTAssertEqual(nextWeekOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(nextWeekOff?.displayText.contains("每周一 08:00 关机") == true)

        let nextWeekOn = VoiceCommandParser.parse("下周开机")
        XCTAssertEqual(nextWeekOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(nextWeekOn?.displayText.contains("每周一 08:00 开机") == true)

        let thisWeekOff = VoiceCommandParser.parse("这周关空调")
        XCTAssertEqual(thisWeekOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(thisWeekOff?.displayText.contains("每周一 08:00 关机") == true)

        let currentWeekOn = VoiceCommandParser.parse("本周开机")
        XCTAssertEqual(currentWeekOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(currentWeekOn?.displayText.contains("每周一 08:00 开机") == true)

        let nextXingqiOff = VoiceCommandParser.parse("下星期关空调")
        XCTAssertEqual(nextXingqiOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(nextXingqiOff?.displayText.contains("每周一 08:00 关机") == true)

        let nextLibaiOff = VoiceCommandParser.parse("下礼拜关机")
        XCTAssertEqual(nextLibaiOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(nextLibaiOff?.displayText.contains("每周一 08:00 关机") == true)

        let allNextWeekOff = VoiceCommandParser.parse("全屋下周关空调")
        XCTAssertEqual(allNextWeekOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(allNextWeekOff?.displayText.contains("全屋在 每周一 08:00 关机") == true)

        let allThisWeekOn = VoiceCommandParser.parse("全屋这周开机")
        XCTAssertEqual(allThisWeekOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(allThisWeekOn?.displayText.contains("全屋在 每周一 08:00 开机") == true)

        // 2. 带具体钟点的复合口语调度
        let nextWeekMorning = VoiceCommandParser.parse("下周早上8点开机")
        XCTAssertEqual(nextWeekMorning?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(nextWeekMorning?.displayText.contains("每周一 08:00 开机") == true)

        let nextWeekNight = VoiceCommandParser.parse("下周晚上10点关空调")
        XCTAssertEqual(nextWeekNight?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(nextWeekNight?.displayText.contains("每周一 22:00 关机") == true)

        let thisFriNight = VoiceCommandParser.parse("本周五晚上9点关空调")
        XCTAssertEqual(thisFriNight?.command, .scheduleRepeatPower(hour: 21, minute: 0, power: false, repeatWeekdays: [6], repeatLabel: "每周五"))
        XCTAssertTrue(thisFriNight?.displayText.contains("每周五 21:00 关机") == true)

        let nextWedAfternoon = VoiceCommandParser.parse("下周三下午3点关空调")
        XCTAssertEqual(nextWedAfternoon?.command, .scheduleRepeatPower(hour: 15, minute: 0, power: false, repeatWeekdays: [4], repeatLabel: "每周三"))
        XCTAssertTrue(nextWedAfternoon?.displayText.contains("每周三 15:00 关机") == true)

        // 3. 口语半点归一测试（映射至 08:30）
        let nextWeekHalf = VoiceCommandParser.parse("下周半关机")
        XCTAssertEqual(nextWeekHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: false, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(nextWeekHalf?.displayText.contains("每周一 08:30 关机") == true)

        let thisWeekHalf = VoiceCommandParser.parse("这周半开机")
        XCTAssertEqual(thisWeekHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: true, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(thisWeekHalf?.displayText.contains("每周一 08:30 开机") == true)

        let currentWeekHalf = VoiceCommandParser.parse("本周半关机")
        XCTAssertEqual(currentWeekHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: false, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(currentWeekHalf?.displayText.contains("每周一 08:30 关机") == true)

        let nextXingqiHalf = VoiceCommandParser.parse("下星期半关空调")
        XCTAssertEqual(nextXingqiHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: false, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(nextXingqiHalf?.displayText.contains("每周一 08:30 关机") == true)

        let nextLibaiHalf = VoiceCommandParser.parse("下礼拜半关机")
        XCTAssertEqual(nextLibaiHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: false, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(nextLibaiHalf?.displayText.contains("每周一 08:30 关机") == true)

        // 4. 严苛防即时误触全景加固断言（杜绝掉入 setPower / turnOffAll / turnOnAll）
        XCTAssertNotEqual(VoiceCommandParser.parse("下周关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("下周关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("下周开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("下周开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("这周关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("这周关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("这周开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("这周开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("本周关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("本周关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("本周开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("本周开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("下星期关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("下星期关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("下星期开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("下星期开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("下礼拜关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("下礼拜关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("下礼拜开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("下礼拜开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋下周关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋下周开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋这周关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋本周开机")?.command, .turnOnAll)
    }

    // MARK: - v1.9.92 自然口语下下周/后周/双休日循环调度大一统、半点归一与严苛防即时误触加固测试

    func testAdvancedWeekAndWeekendRepeatScheduleAndProtectionV1992() {
        // 1. 无钟点下下周/后周/双休日口语大一统调度
        let nextNextWeekOff = VoiceCommandParser.parse("下下周关空调")
        XCTAssertEqual(nextNextWeekOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(nextNextWeekOff?.displayText.contains("每周一 08:00 关机") == true)

        let nextNextWeekOn = VoiceCommandParser.parse("下下周开机")
        XCTAssertEqual(nextNextWeekOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(nextNextWeekOn?.displayText.contains("每周一 08:00 开机") == true)

        let afterWeekOff = VoiceCommandParser.parse("后周关空调")
        XCTAssertEqual(afterWeekOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(afterWeekOff?.displayText.contains("每周一 08:00 关机") == true)

        let afterWeekOn = VoiceCommandParser.parse("后周开机")
        XCTAssertEqual(afterWeekOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(afterWeekOn?.displayText.contains("每周一 08:00 开机") == true)

        let weekendDaysOff = VoiceCommandParser.parse("双休日关空调")
        XCTAssertEqual(weekendDaysOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(weekendDaysOff?.displayText.contains("周末 08:00 关机") == true)

        let weekendDaysOn = VoiceCommandParser.parse("双休日开机")
        XCTAssertEqual(weekendDaysOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(weekendDaysOn?.displayText.contains("周末 08:00 开机") == true)

        let everyShuangxiuOn = VoiceCommandParser.parse("每逢双休开空调")
        XCTAssertEqual(everyShuangxiuOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))

        let allNextNextWeekOff = VoiceCommandParser.parse("全屋下下周关空调")
        XCTAssertEqual(allNextNextWeekOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(allNextNextWeekOff?.displayText.contains("全屋在 每周一 08:00 关机") == true)

        // 2. 带具体钟点的复合口语调度
        let nextNextWeekNight = VoiceCommandParser.parse("下下周晚上10点关空调")
        XCTAssertEqual(nextNextWeekNight?.command, .scheduleRepeatPower(hour: 22, minute: 0, power: false, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(nextNextWeekNight?.displayText.contains("每周一 22:00 关机") == true)

        let nextNextTueNight = VoiceCommandParser.parse("下下周二晚上9点关空调")
        XCTAssertEqual(nextNextTueNight?.command, .scheduleRepeatPower(hour: 21, minute: 0, power: false, repeatWeekdays: [3], repeatLabel: "每周二"))
        XCTAssertTrue(nextNextTueNight?.displayText.contains("每周二 21:00 关机") == true)

        let afterWeekThu = VoiceCommandParser.parse("后星期四下午3点关空调")
        XCTAssertEqual(afterWeekThu?.command, .scheduleRepeatPower(hour: 15, minute: 0, power: false, repeatWeekdays: [5], repeatLabel: "每周四"))
        XCTAssertTrue(afterWeekThu?.displayText.contains("每周四 15:00 关机") == true)

        let weekendDaysMorning = VoiceCommandParser.parse("双休日早上8点开机")
        XCTAssertEqual(weekendDaysMorning?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(weekendDaysMorning?.displayText.contains("周末 08:00 开机") == true)

        // 3. 口语半点归一测试（映射至 08:30）
        let nextNextWeekHalf = VoiceCommandParser.parse("下下周半关机")
        XCTAssertEqual(nextNextWeekHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: false, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(nextNextWeekHalf?.displayText.contains("每周一 08:30 关机") == true)

        let afterWeekHalf = VoiceCommandParser.parse("后周半开机")
        XCTAssertEqual(afterWeekHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: true, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(afterWeekHalf?.displayText.contains("每周一 08:30 开机") == true)

        let weekendDaysHalf = VoiceCommandParser.parse("双休日半关空调")
        XCTAssertEqual(weekendDaysHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: false, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(weekendDaysHalf?.displayText.contains("周末 08:30 关机") == true)

        // 4. 严苛防即时误触全景加固断言
        XCTAssertNotEqual(VoiceCommandParser.parse("下下周关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("下下周关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("下下周开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("下下周开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("后周关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("后周关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("后周开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("后周开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("双休日关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("双休日关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("双休日开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("双休日开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("双休日半关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("双休日半关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋下下周关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋后周开机")?.command, .turnOnAll)
    }

    // MARK: - v1.9.93 自然口语大后周/逢双休/单休调度闭环、静音0档风速与全域防误触深度测试

    func testFarFutureWeekAndQuietWindAndAllScopeV1993() {
        // 1. 大后周/大后个周自然周期调度闭环
        let farFutureWeekOff = VoiceCommandParser.parse("大后周关空调")
        XCTAssertEqual(farFutureWeekOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(farFutureWeekOff?.displayText.contains("每周一 08:00 关机") == true)

        let farFutureWeekOn = VoiceCommandParser.parse("大后个周开机")
        XCTAssertEqual(farFutureWeekOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(farFutureWeekOn?.displayText.contains("每周一 08:00 开机") == true)

        // 2. 逢双休/逢单休/单休日自然周期调度闭环
        let everyWeekendOff = VoiceCommandParser.parse("逢双休关空调")
        XCTAssertEqual(everyWeekendOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(everyWeekendOff?.displayText.contains("周末 08:00 关机") == true)

        let everySingleOffOn = VoiceCommandParser.parse("逢单休开机")
        XCTAssertEqual(everySingleOffOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1], repeatLabel: "周日"))
        XCTAssertTrue(everySingleOffOn?.displayText.contains("周日 08:00 开机") == true)

        let singleOffDay = VoiceCommandParser.parse("单休日关机")
        XCTAssertEqual(singleOffDay?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [1], repeatLabel: "周日"))
        XCTAssertTrue(singleOffDay?.displayText.contains("周日 08:00 关机") == true)

        // 3. 半点语义对齐（映射至 08:30）
        let farFutureHalfOff = VoiceCommandParser.parse("大后周半关空调")
        XCTAssertEqual(farFutureHalfOff?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: false, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(farFutureHalfOff?.displayText.contains("每周一 08:30 关机") == true)

        let everyWeekendHalfOn = VoiceCommandParser.parse("逢双休半开机")
        XCTAssertEqual(everyWeekendHalfOn?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(everyWeekendHalfOn?.displayText.contains("周末 08:30 开机") == true)

        let everySingleHalfOn = VoiceCommandParser.parse("逢单休半开机")
        XCTAssertEqual(everySingleHalfOn?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: true, repeatWeekdays: [1], repeatLabel: "周日"))
        XCTAssertTrue(everySingleHalfOn?.displayText.contains("周日 08:30 开机") == true)

        // 4. 静音 0 档风速口语解析闭环（映射至微风）
        let gear0 = VoiceCommandParser.parse("开0档")
        XCTAssertEqual(gear0?.command, .setWindSpeed(speed: "微风"))
        XCTAssertTrue(gear0?.displayText.contains("微风") == true)

        let speed0 = VoiceCommandParser.parse("风速0")
        XCTAssertEqual(speed0?.command, .setWindSpeed(speed: "微风"))

        let zeroGear = VoiceCommandParser.parse("调到零档")
        XCTAssertEqual(zeroGear?.command, .setWindSpeed(speed: "微风"))

        let quietOn = VoiceCommandParser.parse("静音档开机")
        XCTAssertEqual(quietOn?.command, .setWindSpeed(speed: "微风"))

        let quietWind = VoiceCommandParser.parse("静音风")
        XCTAssertEqual(quietWind?.command, .setWindSpeed(speed: "微风"))

        // 5. 严格防即时误触断言
        XCTAssertNotEqual(VoiceCommandParser.parse("大后周关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("大后周关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("大后个周开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("大后个周开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("逢双休关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("逢双休关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("逢单休开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("逢单休开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("单休日关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("单休日关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("逢双休半开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("逢双休半开机")?.command, .turnOnAll)
    }

    // MARK: - v1.9.94 逢单休/单休日与双休循环调度大一统及防误触全景加固

    func testSingleWeekendAndMultiScheduleHardeningV1994() {
        // 1. 逢单休/每逢单休/单休日精确映射至周日（[1]）调度闭环
        let singleOffOn = VoiceCommandParser.parse("逢单休开机")
        XCTAssertEqual(singleOffOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1], repeatLabel: "周日"))
        XCTAssertTrue(singleOffOn?.displayText.contains("周日 08:00 开机") == true)

        let singleOffDayOff = VoiceCommandParser.parse("单休日关机")
        XCTAssertEqual(singleOffDayOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [1], repeatLabel: "周日"))
        XCTAssertTrue(singleOffDayOff?.displayText.contains("周日 08:00 关机") == true)

        let everySingleOffOn = VoiceCommandParser.parse("每逢单休开机")
        XCTAssertEqual(everySingleOffOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1], repeatLabel: "周日"))
        XCTAssertTrue(everySingleOffOn?.displayText.contains("周日 08:00 开机") == true)

        let everySingleOffAcOff = VoiceCommandParser.parse("每逢单休关空调")
        XCTAssertEqual(everySingleOffAcOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [1], repeatLabel: "周日"))
        XCTAssertTrue(everySingleOffAcOff?.displayText.contains("周日 08:00 关机") == true)

        // 2. 半点口语归一化（映射至 08:30）
        let singleOffHalf = VoiceCommandParser.parse("逢单休半开机")
        XCTAssertEqual(singleOffHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: true, repeatWeekdays: [1], repeatLabel: "周日"))
        XCTAssertTrue(singleOffHalf?.displayText.contains("周日 08:30 开机") == true)

        let singleOffDayHalf = VoiceCommandParser.parse("单休日半关机")
        XCTAssertEqual(singleOffDayHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: false, repeatWeekdays: [1], repeatLabel: "周日"))
        XCTAssertTrue(singleOffDayHalf?.displayText.contains("周日 08:30 关机") == true)

        // 3. 逢双休与双休日调度闭环
        let everyDoubleOffOn = VoiceCommandParser.parse("每逢双休开机")
        XCTAssertEqual(everyDoubleOffOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(everyDoubleOffOn?.displayText.contains("周末 08:00 开机") == true)

        let doubleOffDayOff = VoiceCommandParser.parse("双休日关机")
        XCTAssertEqual(doubleOffDayOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(doubleOffDayOff?.displayText.contains("周末 08:00 关机") == true)

        // 4. 严苛防即时误触断言（杜绝穿透至即时 setPower/turnOnAll/turnOffAll）
        XCTAssertNotEqual(VoiceCommandParser.parse("逢单休开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("逢单休开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("单休日关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("单休日关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("每逢单休开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("每逢单休开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("每逢单休关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("每逢单休关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("逢单休半开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("逢单休半开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("单休日半关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("单休日半关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("每逢双休开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("每逢双休开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("双休日关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("双休日关机")?.command, .turnOffAll)
    }

    // MARK: - v1.9.95 自然口语反相调度脱靶修复与休息日全时相防误触加固

    func testInvertedWeekAndRestDayScheduleHardeningV1995() {
        // 1. 非工作日/非平日精确反相映射至周末（[1, 7]）调度闭环
        let nonWorkdayOn = VoiceCommandParser.parse("非工作日开机")
        XCTAssertEqual(nonWorkdayOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(nonWorkdayOn?.displayText.contains("周末 08:00 开机") == true)

        let nonWorkdayOff = VoiceCommandParser.parse("非平日关机")
        XCTAssertEqual(nonWorkdayOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(nonWorkdayOff?.displayText.contains("周末 08:00 关机") == true)

        // 2. 非周末/非双休/非双休日/非休息日反相映射至工作日（[2, 3, 4, 5, 6]）调度闭环
        let nonWeekendOn = VoiceCommandParser.parse("非周末开机")
        XCTAssertEqual(nonWeekendOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))
        XCTAssertTrue(nonWeekendOn?.displayText.contains("工作日 08:00 开机") == true)

        let nonDoubleOff = VoiceCommandParser.parse("非双休关机")
        XCTAssertEqual(nonDoubleOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))
        XCTAssertTrue(nonDoubleOff?.displayText.contains("工作日 08:00 关机") == true)

        let nonRestDayOn = VoiceCommandParser.parse("非休息日开机")
        XCTAssertEqual(nonRestDayOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))
        XCTAssertTrue(nonRestDayOn?.displayText.contains("工作日 08:00 开机") == true)

        // 3. 休息日/公休日/休假日/放假日/节假日与平日独立时相调度闭环
        let restDayOn = VoiceCommandParser.parse("休息日开机")
        XCTAssertEqual(restDayOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(restDayOn?.displayText.contains("周末 08:00 开机") == true)

        let publicHolidayOff = VoiceCommandParser.parse("公休日关空调")
        XCTAssertEqual(publicHolidayOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(publicHolidayOff?.displayText.contains("周末 08:00 关机") == true)

        let weekdayOn = VoiceCommandParser.parse("平日开机")
        XCTAssertEqual(weekdayOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))
        XCTAssertTrue(weekdayOn?.displayText.contains("工作日 08:00 开机") == true)

        let allRestDayOff = VoiceCommandParser.parse("全屋休息日关空调")
        XCTAssertEqual(allRestDayOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(allRestDayOff?.displayText.contains("定时全屋在 周末 08:00 关机") == true)

        // 4. 自然半点时相归一化（映射至 08:30）
        let nonWorkdayHalf = VoiceCommandParser.parse("非工作日半开机")
        XCTAssertEqual(nonWorkdayHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(nonWorkdayHalf?.displayText.contains("周末 08:30 开机") == true)

        let nonWeekendHalf = VoiceCommandParser.parse("非周末半关机")
        XCTAssertEqual(nonWeekendHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: false, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))
        XCTAssertTrue(nonWeekendHalf?.displayText.contains("工作日 08:30 关机") == true)

        let restDayHalf = VoiceCommandParser.parse("休息日半开机")
        XCTAssertEqual(restDayHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(restDayHalf?.displayText.contains("周末 08:30 开机") == true)

        let weekdayHalf = VoiceCommandParser.parse("平日半关空调")
        XCTAssertEqual(weekdayHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: false, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))
        XCTAssertTrue(weekdayHalf?.displayText.contains("工作日 08:30 关机") == true)

        // 5. 严苛防即时误触断言（杜绝穿透至即时 setPower/turnOnAll/turnOffAll）
        XCTAssertNotEqual(VoiceCommandParser.parse("非工作日开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("非工作日开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("非平日开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("非平日开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("非周末开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("非周末开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("非双休关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("非双休关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("休息日开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("休息日开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("休息日关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("休息日关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("公休日开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("公休日开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("公休日关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("公休日关空调")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("平日开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("平日开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("平日关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("平日关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("休息日半开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("休息日半开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋休息日关空调")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("全屋休息日关空调")?.command, .turnOffAll)
    }

    // MARK: - v1.9.96 排除型否定周期调度与非单休/非单休日调度脱靶缺陷闭环

    func testExclusionAndNonSingleRestScheduleHardeningV1996() {
        // 1. 单休日与逢单休在排除型语义中精准排除周日（[1]），保留周一至周六（[2, 3, 4, 5, 6, 7]）
        let exceptSingleRestOn = VoiceCommandParser.parse("除单休日外每天开机")
        XCTAssertEqual(exceptSingleRestOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))
        XCTAssertTrue(exceptSingleRestOn?.displayText.contains("周一至周六 08:00 开机") == true)

        let exceptSingleRestOn2 = VoiceCommandParser.parse("除了单休日每天开机")
        XCTAssertEqual(exceptSingleRestOn2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))

        let exceptSingleRestOff = VoiceCommandParser.parse("除单休日外每天关机")
        XCTAssertEqual(exceptSingleRestOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))
        XCTAssertTrue(exceptSingleRestOff?.displayText.contains("周一至周六 08:00 关机") == true)

        // 2. 非单休日精准映射至周一至周六（[2, 3, 4, 5, 6, 7]）调度闭环
        let nonSingleRestDayOn = VoiceCommandParser.parse("非单休日开机")
        XCTAssertEqual(nonSingleRestDayOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))
        XCTAssertTrue(nonSingleRestDayOn?.displayText.contains("周一至周六 08:00 开机") == true)

        let nonSingleRestDayOff = VoiceCommandParser.parse("非单休日关机")
        XCTAssertEqual(nonSingleRestDayOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))
        XCTAssertTrue(nonSingleRestDayOff?.displayText.contains("周一至周六 08:00 关机") == true)

        // 3. 非单休精准映射至双休周末（[1, 7]）调度闭环
        let nonSingleRestOn = VoiceCommandParser.parse("非单休开机")
        XCTAssertEqual(nonSingleRestOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(nonSingleRestOn?.displayText.contains("周末 08:00 开机") == true)

        let nonSingleRestOff = VoiceCommandParser.parse("非单休关机")
        XCTAssertEqual(nonSingleRestOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(nonSingleRestOff?.displayText.contains("周末 08:00 关机") == true)

        // 4. 前置反相时态在排除型语义中精准计算补集闭环
        let exceptNonWorkdayOn = VoiceCommandParser.parse("除非工作日外每天开机")
        XCTAssertEqual(exceptNonWorkdayOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))
        XCTAssertTrue(exceptNonWorkdayOn?.displayText.contains("工作日 08:00 开机") == true)

        let exceptNonWorkdayOn2 = VoiceCommandParser.parse("除了非工作日每天开机")
        XCTAssertEqual(exceptNonWorkdayOn2?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))

        let exceptNonWeekdayOn = VoiceCommandParser.parse("除非平日外每天开机")
        XCTAssertEqual(exceptNonWeekdayOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))

        let exceptNonWeekendOn = VoiceCommandParser.parse("除非周末外每天开机")
        XCTAssertEqual(exceptNonWeekendOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(exceptNonWeekendOn?.displayText.contains("周末 08:00 开机") == true)

        let exceptNonDoubleOn = VoiceCommandParser.parse("除非双休外每天开机")
        XCTAssertEqual(exceptNonDoubleOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))

        let exceptNonDoubleDayOn = VoiceCommandParser.parse("除非双休日外每天开机")
        XCTAssertEqual(exceptNonDoubleDayOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))

        // 5. 自然半点时相归一化（映射至 08:30）
        let nonSingleRestHalf = VoiceCommandParser.parse("非单休半开机")
        XCTAssertEqual(nonSingleRestHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))
        XCTAssertTrue(nonSingleRestHalf?.displayText.contains("周末 08:30 开机") == true)

        let nonSingleRestDayHalf = VoiceCommandParser.parse("非单休日半关机")
        XCTAssertEqual(nonSingleRestDayHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: false, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))
        XCTAssertTrue(nonSingleRestDayHalf?.displayText.contains("周一至周六 08:30 关机") == true)

        // 6. 严苛防即时误触断言（针对上述所有口语，严格禁止掉入 setPower/turnOffAll/turnOnAll 即时开关机）
        XCTAssertNotEqual(VoiceCommandParser.parse("除单休日外每天开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("除单休日外每天开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("除单休日外每天关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("除单休日外每天关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("非单休日开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("非单休日开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("非单休日关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("非单休日关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("非单休开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("非单休开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("非单休关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("非单休关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("除非工作日外每天开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("除非工作日外每天开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("除非周末外每天开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("除非周末外每天开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("非单休半开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("非单休半开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("非单休日半关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("非单休日半关机")?.command, .turnOffAll)
    }

    // MARK: - 单星期与周区间反相循环调度与防即时误触加固测试 (v1.9.97)

    func testNonWeekdayScheduleHardeningV1997() {
        // 1. 非单星期反相调度解析闭环（非周X映射至除去周X的所有天）
        // “非周一”应映射为周二至周日 [1, 3, 4, 5, 6, 7]
        let nonMonOn = VoiceCommandParser.parse("非周一8点开机")
        XCTAssertEqual(nonMonOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 3, 4, 5, 6, 7], repeatLabel: "周二至周日"))
        XCTAssertTrue(nonMonOn?.displayText.contains("周二至周日 08:00 开机") == true)

        let nonMonOff = VoiceCommandParser.parse("非周一8点关机")
        XCTAssertEqual(nonMonOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [1, 3, 4, 5, 6, 7], repeatLabel: "周二至周日"))

        // “非周日”映射为周一至周六 [2, 3, 4, 5, 6, 7]
        let nonSunOn = VoiceCommandParser.parse("非周日8点开机")
        XCTAssertEqual(nonSunOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))
        XCTAssertTrue(nonSunOn?.displayText.contains("周一至周六 08:00 开机") == true)

        let nonSunOff = VoiceCommandParser.parse("非周天8点关机")
        XCTAssertEqual(nonSunOff?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: false, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))

        // “非周六”映射为周日至周五 [1, 2, 3, 4, 5, 6]
        let nonSatOn = VoiceCommandParser.parse("非周六8点开机")
        XCTAssertEqual(nonSatOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 5, 6], repeatLabel: "周日至周五"))

        // 星期/礼拜口语同义词覆盖
        let nonWedOn = VoiceCommandParser.parse("非星期三8点开机")
        XCTAssertEqual(nonWedOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 5, 6, 7], repeatLabel: "周四至周二"))

        let nonFriOn = VoiceCommandParser.parse("非礼拜五8点开机")
        XCTAssertEqual(nonFriOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 2, 3, 4, 5, 7], repeatLabel: "周六至周四"))

        // 2. 反相周区间调度闭环
        let nonWorkRangeOn = VoiceCommandParser.parse("非周一至周五8点开机")
        XCTAssertEqual(nonWorkRangeOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1, 7], repeatLabel: "周末"))

        let nonWeekendRangeOn = VoiceCommandParser.parse("非周六至周日8点开机")
        XCTAssertEqual(nonWeekendRangeOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2, 3, 4, 5, 6], repeatLabel: "工作日"))

        // 3. 排除型语义中嵌套反相星期的闭环计算（“除非周一外” -> 仅在周一执行）
        let exceptNonMonOn = VoiceCommandParser.parse("除非周一外每天开机")
        XCTAssertEqual(exceptNonMonOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [2], repeatLabel: "每周一"))
        XCTAssertTrue(exceptNonMonOn?.displayText.contains("每周一 08:00 开机") == true)

        let exceptNonSunOn = VoiceCommandParser.parse("除非周日外每天开机")
        XCTAssertEqual(exceptNonSunOn?.command, .scheduleRepeatPower(hour: 8, minute: 0, power: true, repeatWeekdays: [1], repeatLabel: "每周日"))

        // 4. 自然口语半点时相归一（08:30）
        let nonMonHalf = VoiceCommandParser.parse("非周一半开机")
        XCTAssertEqual(nonMonHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: true, repeatWeekdays: [1, 3, 4, 5, 6, 7], repeatLabel: "周二至周日"))
        XCTAssertTrue(nonMonHalf?.displayText.contains("周二至周日 08:30 开机") == true)

        let nonSunHalf = VoiceCommandParser.parse("非周日半关机")
        XCTAssertEqual(nonSunHalf?.command, .scheduleRepeatPower(hour: 8, minute: 30, power: false, repeatWeekdays: [2, 3, 4, 5, 6, 7], repeatLabel: "周一至周六"))

        // 5. 严苛防即时误触断言（针对上述所有口语，严格禁止掉入 setPower/turnOffAll/turnOnAll 即时开关机）
        XCTAssertNotEqual(VoiceCommandParser.parse("非周一8点开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("非周一8点开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("非周一8点关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("非周一8点关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("非周日8点开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("非周日8点开机")?.command, .turnOnAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("非周天8点关机")?.command, .setPower(false))
        XCTAssertNotEqual(VoiceCommandParser.parse("非周天8点关机")?.command, .turnOffAll)
        XCTAssertNotEqual(VoiceCommandParser.parse("非周六8点开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("非星期三8点开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("非礼拜五8点开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("除非周一外每天开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("除非周日外每天开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("非周一半开机")?.command, .setPower(true))
        XCTAssertNotEqual(VoiceCommandParser.parse("非周日半关机")?.command, .setPower(false))
    }

    // MARK: - 无效输入测试

    func testInvalidCommands() {
        XCTAssertNil(VoiceCommandParser.parse("今天天气怎么样"))
        XCTAssertNil(VoiceCommandParser.parse("播放音乐"))
        XCTAssertNil(VoiceCommandParser.parse(""))
    }
}
