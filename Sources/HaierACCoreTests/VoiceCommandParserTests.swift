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

    // MARK: - 无效输入测试

    func testInvalidCommands() {
        XCTAssertNil(VoiceCommandParser.parse("今天天气怎么样"))
        XCTAssertNil(VoiceCommandParser.parse("播放音乐"))
        XCTAssertNil(VoiceCommandParser.parse(""))
    }
}
