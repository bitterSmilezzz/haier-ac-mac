# Haier AC Mac v1.9.68 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.68`
- **发版主题**：闭环自然语言排除型否定星期周期调度引擎、macOS 状态栏动作谓词多维智能清洗与同频多机防抖及冬季制热低湿静电吸附动力学
- **核心目标与架构演进**：
  1. **自然语言排除型否定星期周期调度通用引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **彻底根除反向语义逻辑颠倒缺陷**：针对“除了周末每天晚上10点关机”、“除周末外每天早8点开机”、“除了工作日每天晚上11点关空调”等高频生活口语，彻底修复旧版中因命中“周末/工作日”子串而直接短路并反向误设为“周末/工作日”的严重逻辑颠倒；
     - **全场景排除模式与全周智能补集计算**：引入 `exclusionRepeatRegex` 与 `parseExclusionRepeatWeekdays` 引擎，全量覆盖“除了周末” -> `[2, 3, 4, 5, 6]`（工作日）、“除了工作日” -> `[1, 7]`（周末）、“除了周日/除周日外” -> `[2, 3, 4, 5, 6, 7]`（周一至周六）、“除周一外” -> `[1, 3, 4, 5, 6, 7]`（周二至周日）、“除周六周日外” -> `[2, 3, 4, 5, 6]`（工作日）、“除了周一至周五” -> `[1, 7]`（周末）及“除周一和周三外”等复杂多星期组合；
     - **后置排除子句自适应解析**：完美支持后置排除语法（如“每天晚10点关机除了周末”、“晚10点关机除周日外”）；
     - **严密测试断言守护**：在 `VoiceCommandParserTests` 中新增 `testExclusionRepeatWeekdays`，包含 16 组端到端排除周期调度断言，100% 验证 PASS。
  2. **macOS 原生状态栏动作谓词多维智能去重清洗与同频多机防抖 (`StatusItemController.swift`)**：
     - **Tooltip 动作谓词多维度清洗与语病根除**：重构 `extractPlanActionVerb`，全面清洗天前缀（明天/后天/大后天/次日）、周期标签（工作日/周末/每天/周X）以及钟点时间前缀（`\d{1,2}:\d{2}`），彻底纠正历史遗留的“将在 30 分钟后22:00 关机 (22:00)”生硬口吃语病，自然输出“将在 30 分钟后关机 (22:00)”；
     - **设备计划菜单项钟点重复彻底消除**：在单设备计划调度二级菜单及多设备计划调度列表中，菜单条目标题统一接入 `extractPlanActionVerb`，彻底消除原“⏱ 22:00 关机 (22:00，剩余 15 分钟)”中双重时间重叠问题，优雅呈现为“⏱ 关机 (22:00，剩余 15 分钟)”与“⏱ 客厅: 关机 (22:00，剩余 15 分钟)”；
     - **同频多设备倒计时 Tooltip 防抖**：在多设备同频计划聚合时，严格遵照设备列表原始顺序过滤输出，彻底杜绝 `Set` 遍历无序导致的“「客厅」、「主卧」”与“「主卧」、「客厅」”随机视觉抖动。
  3. **冬季制热极低湿度静电吸附物理动力学模型 (`AppModel.calculateFilterWearFactor`)**：
     - **微粒物理吸附自洽**：针对冬季制热工况（`.heating`），换热器高温烘烤虽无凝结水膜，但在寒冬低湿干燥工况（RH < 35%）下，化纤滤网极易产生静电积聚（静电驻极效应），加速对细微干燥浮尘颗粒的吸附截留；
     - 引入连续平滑静电吸附阻尼插值（1.00 ~ 1.12），消除简单套用制冷减免带来的物理失真，达成全季节全气候微粒物理自洽。

---

## 2. 关键架构变更与代码实现

### 2.1 排除型否定星期周期调度通用引擎
- **`VoiceCommandParser.swift` 排除语法捕获与全周补集状态机**：
  ```swift
  /// 匹配排除型否定星期口语模式
  private static let exclusionRepeatRegex: NSRegularExpression? = {
      let pattern = #"(?:除了|除)\s*([^，,。！？\s]+?)\s*(?:(?:之|以)?外)?(?=[，,。！？\s]|每天|天天|每日|每晚|每早|每晨|每夜|日日|\d|早|晚|夜|中|上|下|凌晨|午|点|时|:|$|开|关|停)"#
      return try? NSRegularExpression(pattern: pattern)
  }()

  /// 解析排除型周期语义并计算全周补集
  private static func parseExclusionRepeatWeekdays(_ text: String) -> (weekdays: [Int], label: String)? {
      let ns = text as NSString
      guard let regex = exclusionRepeatRegex,
            let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)),
            match.numberOfRanges >= 2 else {
          return nil
      }
      let target = ns.substring(with: match.range(at: 1))
      guard let excluded = extractExcludedDays(from: target) else {
          return nil
      }
      let fullWeek: Set<Int> = [1, 2, 3, 4, 5, 6, 7]
      let remaining = fullWeek.subtracting(excluded)
      guard !remaining.isEmpty && remaining.count < 7 else {
          return nil
      }
      let sorted = Array(remaining).sorted()
      let label = formatWeekdayLabel(from: sorted)
      return (sorted, label)
  }
  ```

- **置顶于 `parseRepeatWeekdays` 第 0 步拦截**：
  ```swift
  // 0. 排除型否定星期周期优先解析（如“除了周末每天晚上10点关机”、“除周末外每天早8点开机”、“除了工作日每天晚上11点关空调”）
  if let exclusionResult = parseExclusionRepeatWeekdays(text) {
      return exclusionResult
  }
  ```

### 2.2 macOS 状态栏动作谓词多维度智能去重清洗与防抖
- **`StatusItemController.swift` 动作提炼引擎多维前缀清洗**：
  ```swift
  private static func extractPlanActionVerb(from action: ScheduledAction, devName: String) -> String {
      var name = action.name
      if !devName.isEmpty && name.hasPrefix("「\(devName)」") {
          name = String(name.dropFirst("「\(devName)」".count))
      } else if let match = name.range(of: #"^「.+?」"#, options: .regularExpression) {
          name.removeSubrange(match)
      }
      name = name.trimmingCharacters(in: .whitespacesAndNewlines)

      // 1. 如果是开关机属性，精准提炼为纯净动作谓词（彻底根除时间/周期前缀残留语病）
      if action.attrName == "onOffStatus" {
          if name.contains("关机") || name.contains("关空调") || name.contains("关闭") {
              return "关机"
          }
          if name.contains("开机") || name.contains("开空调") || name.contains("开启") || name.contains("打开") {
              return "开机"
          }
          return (action.attrValue == .bool(true)) ? "开机" : "关机"
      }

      // 2. 其他任务类型（自清洁/睡眠曲线/自定义调温等）：清洗前置时间与周期前缀
      if let prefixRegex = try? NSRegularExpression(pattern: #"^(?:(?:明天|后天|大后天|次日|工作日|平时|周末|双休|每天|周[一二三四五六日天0-7至到\-~、\s]+|每周[一二三四五六日天0-7、\s]+)\s*)*(?:\d{1,2}:\d{2}(?::\d{2})?\s*)*(?:\d+\s*(?:分钟|小时|钟头)后|晨间过渡(?:关机)?\s*)*"#) {
          let range = NSRange(name.startIndex..<name.endIndex, in: name)
          name = prefixRegex.stringByReplacingMatches(in: name, options: [], range: range, withTemplate: "")
      }
      name = name.trimmingCharacters(in: .whitespacesAndNewlines)
      return name.isEmpty ? "执行任务" : name
  }
  ```

- **Tooltip 设备列表保持确定性顺序**：
  ```swift
  let matchingDevices = allDevices.filter { devIds.contains($0.id) }
  targetDeviceDesc = matchingDevices.map { "「\($0.name)」" }.joined(separator: "、")
  ```

### 2.3 冬季制热低湿静电吸附物理动力学模型
- **`AppModel.swift` 制热静电模型引入**：
  ```swift
  } else if hum < 45.0 {
      if modeCode == .heating {
          // 制热工况：换热器高温无凝结水膜；但在冬季低湿干燥环境（RH < 35%）下，化纤滤网极易产生静电积聚（静电驻极效应），加速对细微干燥扬尘与浮尘的静电吸附截留；
          // 采用连续平滑静电吸附阻尼插值 (1.00 ~ 1.12)，消除简单套用制冷减免带来的物理失真 (v1.9.68)
          if hum < 35.0 {
              let progress = max(0.0, (35.0 - hum) / 20.0)
              humidityFactor = 1.00 + (min(1.0, progress) * 0.12)
          } else {
              humidityFactor = 1.00
          }
      } else {
          let progress = max(0.0, (hum - 25.0) / 20.0)
          humidityFactor = 0.90 + (min(1.0, progress) * 0.10) // 0.90 ~ 1.00 干燥平滑插值
      }
  }
  ```

---

## 3. 验证与测试闭环
- **单元测试断言覆盖**：
  - 在 `VoiceCommandParserTests.swift` 中新增 `testExclusionRepeatWeekdays`，16 组断言 100% PASS：
    1. “除了周末每天晚上10点关机” -> `[2, 3, 4, 5, 6]`、工作日 22:00:00 ✅
    2. “除周末外每天早8点开机” -> `[2, 3, 4, 5, 6]`、工作日 08:00:00 ✅
    3. “除周末以外早8点开机” -> `[2, 3, 4, 5, 6]`、工作日 08:00:00 ✅
    4. “除了工作日每天晚上11点关空调” -> `[1, 7]`、周末 23:00:00 ✅
    5. “除工作日外每天晚上11点关空调” -> `[1, 7]`、周末 23:00:00 ✅
    6. “除了周日每天早8点开机” -> `[2, 3, 4, 5, 6, 7]`、周一至周六 08:00:00 ✅
    7. “除周日外每天早8点开机” -> `[2, 3, 4, 5, 6, 7]`、周一至周六 08:00:00 ✅
    8. “除周日以外每天晚上10点关机” -> `[2, 3, 4, 5, 6, 7]`、周一至周六 22:00:00 ✅
    9. “除了周六周日每天早7点开机” -> `[2, 3, 4, 5, 6]`、工作日 07:00:00 ✅
    10. “除周六和周日外每天早7点开机” -> `[2, 3, 4, 5, 6]`、工作日 07:00:00 ✅
    11. “除了周一至周五每天晚10点关机” -> `[1, 7]`、周末 22:00:00 ✅
    12. “除周一和周三外每天晚10点关机” -> `[1, 3, 5, 6, 7]`、每周日、二、四、五、六 22:00:00 ✅
    13. “除周一外每天晚10点关机” -> `[1, 3, 4, 5, 6, 7]`、周二至周日 22:00:00 ✅
    14. “除了周一每天晚上10点关机” -> `[1, 3, 4, 5, 6, 7]`、周二至周日 22:00:00 ✅
    15. “每天晚10点关机除了周末” -> `[2, 3, 4, 5, 6]`、工作日 22:00:00 ✅
    16. “晚10点关机除周日外” -> `[2, 3, 4, 5, 6, 7]`、周一至周六 22:00:00 ✅
- **本地编译与打包校验**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` 0 警告 0 错误编译通过；
  - `./build_app.sh 1.9.68` 构建成功：
    - `dist/HaierAC.app` (含 `HaierACWidget.appex` 小组件扩展)
    - `dist/HaierAC-v1.9.68-macOS.zip` (大小: 2.8M)
    - SHA256 校验和：`16cffa0a680ddf37d1052fed2a3d32031de2c2e63f77aca66f6af89414060b21`
- **安全敏感数据审查**：
  - 严密审查无任何个人手机号、真实密码、私有 API Key 或敏感隐私数据外泄。
