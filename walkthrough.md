# Haier AC Mac v1.9.67 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.67`
- **发版主题**：闭环复合连续区间与离散混合周期调度大一统通用引擎、macOS 状态栏多机同频倒计时消歧与长周期智能格式化及送风工况干性过滤空气动力学热解耦模型
- **核心目标与架构演进**：
  1. **自然语言复合连续区间与离散混合周期重复调度大一统通用引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift` / `AppModel.swift`)**：
     - **打破关键词排他与短路限制**：重构 `parseRepeatWeekdays` 状态机，解决传统逻辑中一旦匹配“工作日/平时/周末”便直接截断 return 的痛点，全方位支持“核心关键词 + 附加星期”复合语法（如“工作日和周六”、“工作日及周日”、“平时还有周六”、“周末和周一”）；
     - **全方位打通连续区间与离散混合语法**：深度支持“连续区间 + 离散星期”组合（如“周一至周三以及周五”、“周一到周四还有周六”、“周二至周四和周六”、“周日至周四以及周六”）；
     - **升级离散正则与口语修饰语识别**：升级 `discreteWeekdaysRegex`，不仅覆盖“或者/或/还有/加”等口语转折与并列连词，还支持每个分项前的“每/每个/逢/每逢”修饰语（如“每周一和每周三”、“每个周二与每个周四”）；
     - **根除晚间时间口语缩略历史隐蔽缺陷**：针对“晚10点关机”、“晚8点开机”等高频生活口语，在 `parseScheduleTime` 中引入 `晚\s*\d+` 结构化正则，彻底修复了未匹配“晚上”全词时被误解析为 10:00/08:00（上午）的历史隐患，精准对齐 24 小时制（22:00/20:00）；
     - **自然语言环形星期标签智能归一化与全仓冗余消除**：环形拓扑智能归一化标签（如“工作日”、“周末”、“周一至周六”、“周六至周一”等），并将 `AppModel.formatRepeatWeekdaysLabel` 中的 50 余行冗余逻辑完全委托给 `VoiceCommandParser.formatRepeatWeekdaysLabel`，实现跨模块标签格式化完全统一；
     - **严密测试断言守护**：新增 `testCompoundRangeAndDiscreteRepeatWeekdays` 测试函数，覆盖 14 组端到端复合语法用例，100% 断言 PASS。
  2. **macOS 原生状态栏多机同频倒计时消歧与长周期智能格式化 (`StatusItemController.swift`)**：
     - **多设备同频倒计时智能聚合**：当多台设备在同一时间（5 秒阈值内）执行定时任务时，状态栏悬浮 Tooltip 自动聚合为“全屋 N 台空调将在 X 分钟后关机”或“「客厅」、「主卧」将在 X 分钟后关机”，彻底消除仅显示单台设备给用户带来的“其余设备漏执行”心理歧义；
     - **长周期倒计时人性化智能格式化**：新增 `formatRemainingTimeSpan`，针对跨天或长周期计划（>24小时），人性化自适应呈现为 `X 天 Y 小时`，彻底杜绝“将在 120 小时后关机”等机器生硬感；
     - **前缀清洗正则增强**：在 `extractPlanActionVerb` 中引入 `^「.+?」` 正则清洗，杜绝多机动作拼接时残留设备方括号前缀，动作提示自然流畅。
  3. **送风工况干性过滤空气动力学热解耦模型 (`AppModel.calculateFilterWearFactor`)**：
     - **根除无相变送风工况的湿度二次乘积虚高**：在 `calculateFilterWearFactor` 中，对 `.fan`（送风）模式的环境湿度因子严格解耦：当为 `.fan` 工况时，蒸发器表面无制冷制热相变温差凝结，气流仅起物理干性过滤作用，`humidityFactor` 锁定为中性基准 1.00，消除梅雨/高湿天气下对无相变送风滤网磨损的虚高计算，实现全工况热物理自洽。

---

## 2. 关键架构变更与代码实现

### 2.1 复合连续区间与离散混合周期调度大一统通用引擎
- **`VoiceCommandParser.swift` 复合模式与附加星期状态机**：
  ```swift
  // 检查是否包含附加星期（如“工作日和周六”、“工作日及周日”、“平时还有周六”、“周末和周一”）
  let hasAdditional = normalized.contains("和") || normalized.contains("与") || normalized.contains("及") ||
                      normalized.contains("跟") || normalized.contains("以及") || normalized.contains("还有") ||
                      normalized.contains("加") || normalized.contains("、")

  if hasAdditional {
      var daysSet = Set<Int>()
      var foundAny = false

      if normalized.contains("工作日") || normalized.contains("平时") {
          daysSet.formUnion([2, 3, 4, 5, 6])
          foundAny = true
      }
      if normalized.contains("周末") || normalized.contains("双休") {
          daysSet.formUnion([1, 7])
          foundAny = true
      }
      // 提取附加的离散单星期（如“周六”、“周日”、“周一”等）
      if let discreteMatches = extractDiscreteWeekdays(from: normalized) {
          daysSet.formUnion(discreteMatches)
          foundAny = true
      }
      // 提取连续区间并合并
      if let rangeMatches = extractRangeWeekdays(from: normalized) {
          daysSet.formUnion(rangeMatches)
          foundAny = true
      }
      if foundAny && !daysSet.isEmpty {
          let sorted = Array(daysSet).sorted()
          return (sorted, formatWeekdayLabel(from: sorted))
      }
  }
  ```

- **晚间口语时间缩写修复 (`parseScheduleTime`)**：
  ```swift
  // 口语缩写如“晚10点”、“晚8点半”
  let hasEveningAbbr = (try? NSRegularExpression(pattern: #"晚\s*\d+"#))?
      .firstMatch(in: normalized, range: NSRange(normalized.startIndex..., in: normalized)) != nil

  let isEvening = normalized.contains("晚上") || normalized.contains("今晚") ||
                  normalized.contains("明晚") || normalized.contains("傍晚") ||
                  normalized.contains("夜间") || normalized.contains("半夜") ||
                  normalized.contains("深夜") || hasEveningAbbr
  ```

- **跨模块死代码消除 (`AppModel.formatRepeatWeekdaysLabel`)**：
  ```swift
  static func formatRepeatWeekdaysLabel(_ repeatWeekdays: [Int]?) -> String {
      VoiceCommandParser.formatRepeatWeekdaysLabel(repeatWeekdays)
  }
  ```

### 2.2 macOS 状态栏多机同频倒计时消歧与长周期智能格式化
- **`StatusItemController.swift` 同频多机计划智能聚合**：
  ```swift
  // 找出最近执行的计划任务（容差 5 秒内视为同批次多机同频执行）
  let targetTimestamp = firstAction.fireDate.timeIntervalSince1970
  let coExecutingActions = enabledActions.filter {
      abs($0.action.fireDate.timeIntervalSince1970 - targetTimestamp) <= 5.0
  }

  let formattedSpan = formatRemainingTimeSpan(targetDate: firstAction.fireDate)
  let timeStr = formatScheduleTime(firstAction.fireDate)

  let titlePrefix: String
  let allDevicesCount = appModel.allDevices.count
  if coExecutingActions.count > 1 && coExecutingActions.count >= allDevicesCount && allDevicesCount > 1 {
      titlePrefix = "全屋 \(coExecutingActions.count) 台空调将在 \(formattedSpan)"
  } else if coExecutingActions.count > 1 {
      let devNames = coExecutingActions.map { "「\($0.deviceName)」" }.joined(separator: "、")
      titlePrefix = "\(devNames)将在 \(formattedSpan)"
  } else {
      titlePrefix = "「\(firstAction.deviceName)」将在 \(formattedSpan)"
  }
  ```

- **长周期时间人性化格式化 (`formatRemainingTimeSpan`)**：
  ```swift
  private static func formatRemainingTimeSpan(targetDate: Date) -> String {
      let interval = targetDate.timeIntervalSinceNow
      if interval <= 0 { return "即将" }
      let totalMinutes = Int(ceil(interval / 60.0))
      if totalMinutes < 60 {
          return "\(max(1, totalMinutes)) 分钟后"
      } else if totalMinutes < 1440 {
          let hours = totalMinutes / 60
          let mins = totalMinutes % 60
          return mins > 0 ? "\(hours) 小时 \(mins) 分钟后" : "\(hours) 小时后"
      } else {
          let days = totalMinutes / 1440
          let hours = (totalMinutes % 1440) / 60
          return hours > 0 ? "\(days) 天 \(hours) 小时后" : "\(days) 天后"
      }
  }
  ```

### 2.3 送风工况干性过滤空气动力学热解耦模型
- **`AppModel.swift` 送风与湿度解耦**：
  ```swift
  let isDehumidifyMode = (matchedMode == .dehumidify)
  let isFanMode = (matchedMode == .fan)

  if isDehumidifyMode {
      // 在 .dehumidify 工况下，蒸发器表面冷凝水膜厚度与粉尘黏结效应已在 modeFactor 中以高精连续阻尼插值完成自洽建模；
      // 此处 humidityFactor 保持中性基准 1.00，消除对环境湿度的二次重复计算与指数级过度放大。
      humidityFactor = 1.00
  } else if isFanMode {
      // 在 .fan（送风）工况下，压缩机不运转且蒸发器无相变温差凝结，气流仅起物理干性过滤作用；
      // 此时环境湿度对滤网纤维附着微粒的影响极弱，因此将 humidityFactor 锁定为中性基准 1.00，消除非相变工况下的虚高磨损。
      humidityFactor = 1.00
  } else if let hum = indoorHumidity {
      // 正常制冷/制热/自动工况连续插值
      ...
  }
  ```

---

## 3. 验证与测试闭环
- **单元测试断言覆盖**：
  - 在 `VoiceCommandParserTests.swift` 中新增 `testCompoundRangeAndDiscreteRepeatWeekdays`，14 组断言 100% PASS：
    1. “工作日和周六晚10点关机” -> `[2, 3, 4, 5, 6, 7]`、周一至周六 ✅
    2. “工作日及周日早上8点开机” -> `[1, 2, 3, 4, 5, 6]`、周日至周五 ✅
    3. “周末和周一早晨7点开空调” -> `[1, 2, 7]`、周六至周一 ✅
    4. “平时还有周六下午2点开机” -> `[2, 3, 4, 5, 6, 7]`、周一至周六 ✅
    5. “周一至周三以及周五晚10点关机” -> `[2, 3, 4, 6]`、每周一、二、三、五 ✅
    6. “周一到周四还有周六早上9点开机” -> `[2, 3, 4, 5, 7]`、每周一、二、三、四、六 ✅
    7. “周二至周四和周六上午10点开机” -> `[3, 4, 5, 7]`、每周二、三、四、六 ✅
    8. “周日至周四以及周六晚上11点关空调” -> `[1, 2, 3, 4, 5, 7]`、每周日、一、二、三、四、六 ✅
    9. “每周一和每周三晚10点关机” -> `[2, 4]`、每周一、三 ✅
    10. “每个周二与每个周四早上8点开机” -> `[3, 5]`、每周二、四 ✅
    11. “周一或者周四晚9点关机” -> `[2, 5]`、每周一、四 ✅
    12. “晚10点关机” -> 22:00:00 ✅
    13. “晚8点开机” -> 20:00:00 ✅
    14. “晚8点半开机” -> 20:30:00 ✅
- **本地编译与打包校验**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` 0 警告 0 错误编译通过；
  - `./build_app.sh 1.9.67` 构建成功：
    - `dist/HaierAC.app` (含 `HaierACWidget.appex` 小组件扩展)
    - `dist/HaierAC-v1.9.67-macOS.zip` (大小: 2.7M)
    - SHA256 校验和：`b13537ddd164c0736d0b9837110cdadb32b4cfd3f7dd2bcee9b42acf4f13ee30`
