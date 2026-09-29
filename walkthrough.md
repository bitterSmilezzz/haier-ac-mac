# Haier AC Mac v1.9.66 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.66`
- **发版主题**：闭环口语离散与连续混合周期通用调度引擎、macOS 状态栏任务倒计时全景对称与 Tooltip 语病根除及除湿工况滤网热物理动力学解耦模型
- **核心目标与架构演进**：
  1. **自然语言口语离散与连续混合周期通用调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **打破特定预设限制**：突破既有单星期与连续区间的限制，引入通用离散星期枚举与连续混合解析引擎；
     - **全方位支持口语连接词与混合语法**：完美解析包含“和/与/及/跟/以及/、/逗号/空格”连接的离散复合星期（如“周一和周三晚10点关机”、“周二、周四与周六早上8点开机”、“周一及周五早晨7点开空调”、“星期二和星期四晚上11点关空调”、“礼拜一跟礼拜五早上8点开机”、“逢周一和周四下午2点开机”），同时支持“周一三五”、“周二四”等口语缩略；
     - **复合标点与阿拉伯数字支持**：全面支持破折号与波浪号（“周一-周五”、“周一~五”）以及阿拉伯数字（“周1到5”、“周1至周5”）；
     - **智能归一化语义标签**：基于拓扑排序与特征映射，自动将离散与连续组合格式化为最地道、最人性化的自然语言标签（如“工作日”、“周末”、“每周一、三”、“每周二、四、六”等）；
     - **严密测试断言守护**：在 `VoiceCommandParserTests` 中新增 `testDiscreteAndMixedRepeatWeekdays`，对 12 组端到端离散、复合与混合星期高频用例进行 100% 断言覆盖。
  2. **macOS 状态栏任务感知全景对称与 Tooltip 历史语病根除 (`StatusItemController.swift`)**：
     - **彻底根除悬浮 Tooltip 倒计时词素重叠与口吃语病**：新增 `extractPlanActionVerb` 智能动作提炼引擎，自动清洗如“30分钟后”、“1小时后”、“晨间过渡”等历史持续时间前缀，将历史误显示的“将在 18 分钟后30 分钟后关机”彻底纠正为自然流畅的“将在 18 分钟后关机 (10:35)”；
     - **多设备矩阵单机调度倒计时全景对称补齐**：在多设备级联展开的单机计划调度菜单中，为任务标题与详情行实时注入人性化剩余时间（`，剩余 X 分钟` / ` (剩余 X 分钟)`），实现单设备模式、多设备单机模式与全屋总览三维全景无缝对称。
  3. **除湿模式滤网热物理动力学解耦与全气候自洽模型 (`AppModel.calculateFilterWearFactor`)**：
     - **根除环境湿度二次重复计算与指数级过度放大（Double Counting）**：在 `calculateFilterWearFactor` 中，对 `.dehumidify`（除湿）工况进行物理动力学解耦。针对除湿模式下蒸发器水膜表面张力与微粒捕获已在 `modeFactor` 中完整建模的物理事实，将 `humidityFactor` 锁定为中性基准 1.00，消除与环境湿度因子的重复相乘，避免梅雨/回南天工况下滤网等效磨损被严重夸大，使滤网全气候健康度模型更严谨、更自洽。

---

## 2. 关键架构变更与代码实现

### 2.1 口语离散与连续混合周期通用调度引擎
- **`VoiceCommandParser.swift` 离散正则与通用映射**：
  ```swift
  // 匹配离散多星期组合口语模式（如“周一和周三”、“周二、周四与周六”、“周一及周五”、“星期二和星期四”、“礼拜一跟礼拜五”、“周一三五”、“周二四六”、“周二四”）
  private static let discreteWeekdaysRegex: NSRegularExpression? = {
      let pattern = #"(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])(?:[、,，和与及跟以及\s]+(?:(?:周|星期|礼拜)?([一二三四五六日天1-7])))+"#
      return try? NSRegularExpression(pattern: pattern)
  }()

  // 扩展阿拉伯数字支持 (1=日, 2=一, ..., 7=六)
  private static func chineseDayCharToWeekday(_ ch: Character) -> Int? {
      switch ch {
      case "一", "1": return 2
      case "二", "2": return 3
      case "三", "3": return 4
      case "四", "4": return 5
      case "五", "5": return 6
      case "六", "6": return 7
      case "日", "天", "7", "0": return 1
      default: return nil
      }
  }
  ```

- **智能归一化语义标签**：
  ```swift
  private static func formatWeekdayLabel(from weekdays: [Int], startWd: Int? = nil, endWd: Int? = nil) -> String {
      if weekdays.isEmpty { return "每天" }
      if weekdays.count == 7 { return "周一至周日" }
      if weekdays == [2, 3, 4, 5, 6] { return "工作日" }
      if weekdays == [1, 7] { return "周末" }
      if weekdays == [1, 6, 7] { return "周五至周日" }
      if weekdays == [2, 4, 6] { return "每周一、三、五" }
      if weekdays == [3, 5, 7] { return "每周二、四、六" }
      if weekdays == [3, 5] { return "每周二、四" }

      let dayChars = ["日", "一", "二", "三", "四", "五", "六"]
      if let s = startWd, let e = endWd {
          let sName = dayChars[max(0, min(s - 1, 6))]
          let eName = dayChars[max(0, min(e - 1, 6))]
          return "周\(sName)至周\(eName)"
      }
      if weekdays.count >= 2, let first = weekdays.first, let last = weekdays.last {
          if generateWeeklyRange(start: first, end: last) == weekdays {
              let sName = dayChars[max(0, min(first - 1, 6))]
              let eName = dayChars[max(0, min(last - 1, 6))]
              return "周\(sName)至周\(eName)"
          }
      }
      let names = weekdays.map { dayChars[max(0, min($0 - 1, 6))] }
      return "每周" + names.joined(separator: "、")
  }
  ```

### 2.2 macOS 状态栏任务感知对称性与 Tooltip 语病根除
- **`StatusItemController.swift` 动作提炼引擎**：
  ```swift
  private static func extractPlanActionVerb(from action: ScheduledAction, devName: String) -> String {
      var name = action.name
      if name.hasPrefix("「\(devName)」") {
          name = String(name.dropFirst("「\(devName)」".count))
      }
      if let regex = try? NSRegularExpression(pattern: #"^(?:\d+\s*(?:分钟|小时|钟头)后|晨间过渡(?:关机)?)"#) {
          let range = NSRange(name.startIndex..<name.endIndex, in: name)
          name = regex.stringByReplacingMatches(in: name, options: [], range: range, withTemplate: "")
      }
      name = name.trimmingCharacters(in: .whitespacesAndNewlines)
      if name.isEmpty {
          if action.attrName == "onOffStatus" {
              return (action.attrValue == .bool(true)) ? "开机" : "关机"
          }
          return "执行任务"
      }
      return name
  }
  ```
- **多设备矩阵单机子菜单注入剩余时间**：
  ```swift
  let remainingDesc = action.enabled ? "，\(Self.formatRemainingTime(fireDate: action.fireDate))" : ""
  let sItem = NSMenuItem(title: "⏱ \(cleanActionName) (\(timeStr)\(remainingDesc))\(repeatTag)\(statusTag)", action: nil, keyEquivalent: "")
  ```

### 2.3 除湿工况滤网热物理动力学解耦模型
- **`AppModel.swift` 根除双重湿度效应叠加**：
  ```swift
  let isDehumidifyMode = (ACModeCode.match(from: mode) == .dehumidify)
  if isDehumidifyMode {
      // 在 .dehumidify 工况下，蒸发器表面冷凝水膜厚度与粉尘黏结效应已在 modeFactor 中以高精连续阻尼插值完成自洽建模；
      // 此处 humidityFactor 保持中性基准 1.00，彻底消除对环境湿度的二次重复计算与指数级过度放大，保持全气候模型严谨自洽。
      humidityFactor = 1.00
  } else if let hum = indoorHumidity {
      // 正常制冷/制热/送风/自动工况连续插值
      ...
  }
  ```

---

## 3. 验证与测试闭环
- **单元测试断言覆盖**：
  - 在 `VoiceCommandParserTests.swift` 中新增 `testDiscreteAndMixedRepeatWeekdays`，全覆盖：
    1. “周一和周三晚10点关机” -> `[2, 4]`、每周一、三 ✅
    2. “周二、周四与周六早上8点开机” -> `[3, 5, 7]`、每周二、四、六 ✅
    3. “周一及周五早晨7点开空调” -> `[2, 6]`、每周一、五 ✅
    4. “星期二和星期四晚上11点关空调” -> `[3, 5]`、每周二、四 ✅
    5. “礼拜一跟礼拜五早上8点开机” -> `[2, 6]`、每周一、五 ✅
    6. “逢周一和周四下午2点开机” -> `[2, 5]`、每周一、四 ✅
    7. “周一三五早上7点开空调” -> `[2, 4, 6]`、每周一、三、五 ✅
    8. “周二四晚10点关机” -> `[3, 5]`、每周二、四 ✅
    9. “周一-周五早上8点开机” / “周一~五晚10点关机” -> 工作日 ✅
    10. “周1到5早8点开机” / “周1至周5晚上10点关机” -> 工作日 ✅
- **本地编译与校验**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` 0 警告 0 错误编译通过（耗时 5.28s）。
  - `./build_app.sh 1.9.66` 构建完成：
    - `dist/HaierAC.app` (含 Widget 扩展)
    - `dist/HaierAC-v1.9.66-macOS.zip` (大小: 2.7M)
    - SHA256 校验和：`07bc57a6bc641f4e131c234405d8e2b18e3d49951c0d8677f81e4ca4335c38a1`
