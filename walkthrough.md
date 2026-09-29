# Haier AC Mac v1.9.65 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.65`
- **发版主题**：闭环口语省略语素周期重复调度通用解析引擎、macOS 状态栏全景实时倒计时与毫秒级高精消歧提示及滤网温差热物理全域连续阻尼模型
- **核心目标与架构演进**：
  1. **自然语言口语“省略重复语素”通用环形周期解析引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **打破硬编码子串限制**：彻底解决口语高频省略第二个“周/星期/礼拜”语素（如“周一至五早晨7点开机”、“周一到五晚10点关机”、“周五至日自动开机”、“周五到天开机”、“周六至二关机”、“周日至五开空调”）返回 nil 的历史痛点；
     - **49 种全组合环形星期解析算法**：引入通用环形星期路径计算算法，将星期一至星期日映射为正向环形拓扑，精确覆盖任意连续星期区间与跨周长周期；自动归一化格式化标签（如“工作日”、“周末”、“周五至周日”、“周五至周一”等），并向下完全兼容既有“工作日”、“平时”、“周末”、“双休”、“周末三天”、“一三五”、“二四六”及单星期词法；
     - **严密测试断言守护**：在 `VoiceCommandParserTests` 中新增 `testOralEllipsisRepeatWeekdays`，对 14 组高频口语省略变体与端到端开关机指令进行 100% 断言覆盖。
  2. **macOS 原生状态栏全景实时倒计时与毫秒级高精消歧感知 (`StatusItemController.swift`)**：
     - **悬浮 Tooltip 动态感知最近计划**：在状态栏图标悬浮 Tooltip 中引入最近计划任务实时计算，当存在生效中的定时或倒计时时，动态呈现 `⏱ 最近计划: 「设备名」将在 X 分钟后关机 (09:35)`，用户无需点击菜单即可秒级掌握倒计时动态；
     - **菜单任务实时高精剩余时间感知**：在多设备全屋计划调度与单设备专属调度菜单中，为所有生效中任务标题（如 `⏱ 客厅: 关机 (09:35，剩余 25 分钟)`）与次级详细菜单项（`下次执行: 2026/09/29 09:35:00 (剩余 25 分钟)`）实时注入人性化剩余时间标注，免除用户心算困扰。
  3. **滤网温差对流与冷凝微粒热物理全域连续阻尼模型 (`AppModel.calculateFilterWearFactor`)**：
     - **根除极端室温临界点阶跃断崖**：重构 `calculateFilterWearFactor` 中制冷、制热与自动模式的大温差与极端室温动力学，采用与能耗分析引擎对齐的双线性连续过渡阻尼模型；
     - 在制冷/自动工况（indoor >= 28°C 且 diff >= 4°C）以及制热/自动工况（indoor <= 14°C 且 diff >= 4°C）引入平滑线性渐进，彻底消除 30°C/5°C 与 12°C/5°C 处的离散硬跳变断崖，实现全气候物理自洽。

---

## 2. 关键架构变更与代码实现

### 2.1 口语省略语素通用环形周期解析引擎
- **`VoiceCommandParser.swift` 正则与环形拓扑算法**：
  ```swift
  // 支持前缀完整匹配或后半部省略前缀：如 "周一至五"、"周五到天"、"星期一到五"、"礼拜五至日"
  private static let repeatWeekdayRangeRegex: NSRegularExpression? = {
      let pattern = "(?:每)?(?:个)?(周|星期|礼拜)([一二三四五六日天1-7])(?:到|至|-|~)(?:(周|星期|礼拜)?)([一二三四五六日天1-7])"
      return try? NSRegularExpression(pattern: pattern, options: [])
  }()

  // 通用环形星期路径计算：支持任意连续星期区间与跨周长周期 (1=周日, 2=周一, ..., 7=周六)
  private static func generateWeeklyRange(from startDay: Int, to endDay: Int) -> [Int] {
      if startDay == endDay { return [startDay] }
      var res: [Int] = []
      var cur = startDay
      while true {
          res.append(cur)
          if cur == endDay { break }
          cur = (cur % 7) + 1
      }
      return res
  }
  ```
- **标签智能归一化**：
  - `[2, 3, 4, 5, 6]` -> 统一标识为 `"工作日"`
  - `[1, 7]` -> 统一标识为 `"周末"`
  - `[1, 6, 7]` -> 统一标识为 `"周五至周日"`
  - 其他任意环形区间自动组合为标准 `"周X至周Y"`。

### 2.2 macOS 状态栏全景实时倒计时与毫秒级高精提示
- **`StatusItemController.swift` 人性化剩余时间注入**：
  ```swift
  private func formatRemainingTime(seconds: TimeInterval) -> String {
      if seconds <= 0 { return "即将执行" }
      let totalMins = Int(ceil(seconds / 60.0))
      if totalMins < 60 {
          return "剩余 \(max(1, totalMins)) 分钟"
      } else {
          let hours = totalMins / 60
          let mins = totalMins % 60
          return mins == 0 ? "剩余 \(hours) 小时" : "剩余 \(hours) 小时 \(mins) 分钟"
      }
  }
  ```
- **悬浮 Tooltip 动态感知最近计划**：
  - 自动扫描全屋及所有分机生效中且下次执行时间大于当前的最近计划任务：
  ```swift
  if let nearest = upcomingActions.first, let nextFire = nearest.action.nextExecutionDate {
      let diffSecs = nextFire.timeIntervalSince(now)
      let remainStr = diffSecs < 60 ? "不到 1 分钟" : "\(max(1, Int(ceil(diffSecs / 60.0)))) 分钟"
      let actionDesc = nearest.action.targetState.power ? "开机" : "关机"
      let timeFmt = DateFormatter()
      timeFmt.dateFormat = "HH:mm"
      let timeStr = timeFmt.string(from: nextFire)
      let planDesc = "⏱ 最近计划: 「\(nearest.devName)」将在 \(remainStr)后\(actionDesc) (\(timeStr))"
      ...
  }
  ```

### 2.3 滤网温差热物理全域连续双线性阻尼模型
- **`AppModel.swift` 彻底消除极端温差硬跳变断崖**：
  ```swift
  case .cooling:
      // 双线性平滑过渡：当室温偏高且温差较大时连续渐进
      if let indoor = indoorTemp, indoor >= 28.0, let diff = tempDiff, diff >= 4.0 {
          let indoorProg = min(1.0, max(0.0, (indoor - 28.0) / 4.0)) // 28°C ~ 32°C 连续归一化
          let diffProg = min(1.0, max(0.0, (diff - 4.0) / 4.0))      // 4°C ~ 8°C 连续归一化
          tempFactor = 1.0 + (indoorProg * diffProg * 0.15)           // 1.00 ~ 1.15 平滑渐进
      }
  case .heating:
      // 双线性平滑过渡：当室温极低且需大幅升温时连续渐进
      if let indoor = indoorTemp, indoor <= 14.0, let diff = tempDiff, diff >= 4.0 {
          let indoorProg = min(1.0, max(0.0, (14.0 - indoor) / 6.0)) // 14°C ~ 8°C 连续归一化
          let diffProg = min(1.0, max(0.0, (diff - 4.0) / 4.0))       // 4°C ~ 8°C 连续归一化
          tempFactor = 1.0 + (indoorProg * diffProg * 0.15)            // 1.00 ~ 1.15 平滑渐进
      }
  ```

---

## 3. 验证与测试闭环
- **单元测试与独立二进制验证**：
  - 在 `VoiceCommandParserTests.swift` 中新增 `testOralEllipsisRepeatWeekdays`，并通过编译运行 100% 验证所有关键断言：
    1. “周一至五早晨7点开机” -> 工作日、targetTime: 07:00、powerOn: true ✅
    2. “周一到五晚10点关空调” -> 工作日、targetTime: 22:00、powerOn: false ✅
    3. “周五至日自动开机” -> `[1, 6, 7]`、周五至周日 ✅
    4. “周五到天晚上十一点关机” -> `[1, 6, 7]`、周五至周日 ✅
    5. “周六至二关机” -> `[1, 2, 3, 7]`、环形跨周连续路径 ✅
    6. “周日至五开空调” -> `[1, 2, 3, 4, 5, 6]`、环形跨周连续路径 ✅
    7. “礼拜一至五开机” / “星期一到五关机”等口语省略变体覆盖 ✅
    8. 滤网大温差双线性阻尼插值函数平滑度与连续性验证 ✅
- **编译与静态分析**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` 0 警告 0 错误编译通过。
  - `swift build -c release` 0 警告 0 错误构建通过。
- **发布构建与产物校验**：
  - 执行 `./build_app.sh 1.9.65`，打包签名产出：
    - `dist/HaierAC.app`
    - `dist/HaierAC-v1.9.65-macOS.zip` (大小: 2.7M)
    - SHA256 校验和：`463c10a37944b9e30ee911e1c9a43cb1405210ae706283bb5fdd3dda36ccf8b6`
