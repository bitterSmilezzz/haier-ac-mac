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

    // MARK: - 无效输入测试

    func testInvalidCommands() {
        XCTAssertNil(VoiceCommandParser.parse("今天天气怎么样"))
        XCTAssertNil(VoiceCommandParser.parse("播放音乐"))
        XCTAssertNil(VoiceCommandParser.parse(""))
    }
}
