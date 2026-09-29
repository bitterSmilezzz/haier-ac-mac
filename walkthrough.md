# Haier AC Mac v1.9.71 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.71`
- **发版主题**：闭环自然语言单休与长周末排除型周期调度通用引擎、macOS 状态栏同频任务真实动作谓词裁决与预编译正则及调度器 I/O 深度优化
- **核心目标与架构演进**：
  1. **自然语言单休制与长周末排除型周期调度通用引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **单休与周末三天排除语义完备化**：在 `extractExcludedDays` 中全面纳管“单休”（周一至周六，`[2, 3, 4, 5, 6, 7]`）与“周末三天”（周五至周日，`[1, 6, 7]`），彻底修复以往“除单休外每天早8点开机”识别失败以及“除周末三天外每天早8点开机”被“周末”前缀短路遗漏周五的严重逻辑缺陷，精准分别结算为 `[1]`（“每周日”）与 `[2, 3, 4, 5]`（“周一至周四”）；
     - **长周末基准范围排除闭环**：完善以“周末三天”为限定基准集的排除演算（如“周末三天除了周五每天早8点开机” -> 精准提取为 `[1, 7]` “周末”；“周末三天除周日外每天早8点开机” -> 精准提取为 `[6, 7]` “周五至周六”）；
     - **复合星期口语语法扩展**：在 `keywordWithExtraDayRegex` 与 `extraDayWithKeywordRegex` 中全面纳入 `单休` 与 `周末三天`，支持“单休和周日每天早8点开机”、“周日和单休每天早8点开机”等自然语言组合，平滑收敛为全周 7 天（`[1, 2, 3, 4, 5, 6, 7]`）；
     - **单元测试 100% 覆盖**：在 `VoiceCommandParserTests` 中新增 7 组端到端测试用例，涵盖单休排除、周末三天排除、基准范围扣减及复合扩展，全部断言 100% PASS。
  2. **macOS 原生状态栏同频任务动作谓词真实裁决与预编译正则性能优化 (`StatusItemController.swift`)**：
     - **状态栏悬浮 Tooltip 最近计划同频协同任务严格动作对齐**：重构 `sameTimeActions` 过滤逻辑，在 5 秒同频时间阈值基础上强制追加动作属性（`attrName`）与动作值（`attrValue`）严格相等约束。彻底消除不同设备同时间分别执行“开机”与“关机”时被错误合并为单一动作（将关机设备错误宣称为开机）的严重语义缺陷；
     - **任务动作谓词清洗正则预编译与单休/长周末支持**：将 `extractPlanActionVerb` 中的前缀与后缀清洗正则全面提升为类级 `static let` 静态常量，根除高频刷新菜单与 Tooltip 时的反复动态编译开销；同时补充 `单休` 与 `周末三天` 清洗规则，避免菜单生成冗余重复语病。
  3. **调度器初始化磁盘 I/O 与反序列化去重优化 (`AppModel.swift`)**：
     - **阻断唤醒时的无谓反序列化竞争**：引入 `hasLoadedScheduledActions` 状态门禁，确保仅在首次调度启动时从 `UserDefaults` 读取历史任务；在后续任务增删改查高频触发 `wakeScheduler()` 时，直接复用内存中最新的数据模型，消除冗余磁盘读取与 JSON 反序列化 CPU 开销。

---

## 2. 关键架构变更与代码实现

### 2.1 单休与长周末排除型周期调度通用引擎
- **`VoiceCommandParser.swift` 排除项与复合关键词纳管**：
  ```swift
  /// 从排除文本中提取被排除的星期集合 (v1.9.68, v1.9.71 纳管周末三天与单休排除)
  private static func extractExcludedDays(from target: String) -> Set<Int>? {
      var excluded = Set<Int>()
      var remainingTarget = target
      if remainingTarget.contains("工作日") || remainingTarget.contains("平时") {
          excluded.formUnion([2, 3, 4, 5, 6])
          remainingTarget = remainingTarget.replacingOccurrences(of: "工作日", with: "").replacingOccurrences(of: "平时", with: "")
      }
      if remainingTarget.contains("周末三天") {
          excluded.formUnion([1, 6, 7])
          remainingTarget = remainingTarget.replacingOccurrences(of: "周末三天", with: "")
      }
      if remainingTarget.contains("周末") || remainingTarget.contains("双休") {
          excluded.formUnion([1, 7])
          remainingTarget = remainingTarget.replacingOccurrences(of: "周末", with: "").replacingOccurrences(of: "双休", with: "")
      }
      if remainingTarget.contains("单休") {
          excluded.formUnion([2, 3, 4, 5, 6, 7])
          remainingTarget = remainingTarget.replacingOccurrences(of: "单休", with: "")
      }
      // ...
  }
  ```

- **复合星期口语语法扩展**：
  ```swift
  private static let keywordWithExtraDayRegex: NSRegularExpression? = {
      let pattern = #"(工作日|平时|周末|双休|单休|周末三天)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?!(?:每天|天天|每日|每晚|每早|每晨|每夜|日日))(?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7]|工作日|平时|周末|双休|单休|周末三天))"#
      return try? NSRegularExpression(pattern: pattern)
  }()
  ```

### 2.2 macOS 状态栏同频任务真实动作谓词裁决与预编译正则
- **`StatusItemController.swift` 同频任务严格动作属性对齐**：
  ```swift
  if let firstAction = upcomingSchedules.first {
      let threshold = firstAction.fireDate.addingTimeInterval(5.0)
      let sameTimeActions = upcomingSchedules.filter {
          $0.fireDate <= threshold &&
          $0.attrName == firstAction.attrName &&
          $0.attrValue == firstAction.attrValue
      }
      // ...
  }
  ```

- **预编译清洗正则与长周期/单休语素清洗**：
  ```swift
  private static let schedulePrefixRegex: NSRegularExpression? = {
      let pattern = #"^(?:(?:定时|预约)?(?:全屋)?(?:在)?\s*)*(?:(?:明天|后天|大后天|次日|工作日|平时|周末三天|周末|双休|单休|每天|周[一二三四五六日天0-7至到\-~、\s]+|每周[一二三四五六日天0-7、\s]+)\s*)*(?:\d{1,2}:\d{2}(?::\d{2})?\s*)*(?:\d+\s*(?:分钟|小时|钟头)后|晨间过渡(?:关机)?\s*)*"#
      return try? NSRegularExpression(pattern: pattern)
  }()

  private static let scheduleSuffixRegex: NSRegularExpression? = {
      let pattern = #"\s*[(（](?:每天|工作日|平时|周末三天|周末|双休|单休|周[一二三四五六日天至到\-~、\s]+)[)）]\s*$"#
      return try? NSRegularExpression(pattern: pattern)
  }()
  ```

### 2.3 调度器初始化磁盘 I/O 与反序列化去重
- **`AppModel.swift` 防重复反序列化机制**：
  ```swift
  func startScheduler() {
      guard schedulerTask == nil else { return }
      if !hasLoadedScheduledActions {
          hasLoadedScheduledActions = true
          if let data = UserDefaults.standard.data(forKey: "scheduledActions"),
             let saved = try? JSONDecoder().decode([ScheduledAction].self, from: data) {
              scheduledActions = saved
          }
      }
      schedulerTask = Task { [weak self] in
          // ...
      }
  }
  ```

---

## 3. 验证与测试闭环
- **单元测试断言覆盖**：
  - 在 `VoiceCommandParserTests.swift` 中新增 7 组端到端用例，全部断言 100% PASS：
    1. “除单休外每天早8点开机” -> `[1]`、每周日 08:00:00 开机 ✅
    2. “除了单休每天早8点开机” -> `[1]`、每周日 08:00:00 开机 ✅
    3. “除周末三天外每天早8点开机” -> `[2, 3, 4, 5]`、周一至周四 08:00:00 开机 ✅
    4. “周末三天除了周五每天早8点开机” -> `[1, 7]`、周末 08:00:00 开机 ✅
    5. “周末三天除周日外每天早8点开机” -> `[6, 7]`、周五至周六 08:00:00 开机 ✅
    6. “单休和周日每天早8点开机” -> `[1, 2, 3, 4, 5, 6, 7]`、周一至周日 08:00:00 开机 ✅
    7. “周日和单休每天早8点开机” -> `[1, 2, 3, 4, 5, 6, 7]`、周一至周日 08:00:00 开机 ✅
    8. 原有全量测试用例（否定句保护、离散星期、单休制、半度调温等）全部保持 100% 兼容通过 ✅
- **本地编译与打包校验**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` 0 警告 0 错误编译通过；
  - `./build_app.sh 1.9.71` 构建成功：
    - `dist/HaierAC.app` (含 `HaierACWidget.appex` 小组件扩展)
    - `dist/HaierAC-v1.9.71-macOS.zip` (大小: 2.8M)
    - SHA256 校验和：`2408038e02f85c0a35e6eb832a561d80fd5579deaf8e41f1d3e10bffb53986f7`
- **安全敏感数据审查**：
  - 严密审查无任何个人手机号、真实密码、私有 API Key 或敏感隐私数据外泄。
