# Haier AC Mac v1.9.69 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.69`
- **发版主题**：闭环自然语言排除型否定星期限定基准集调度引擎、macOS 状态栏动作谓词真实布尔裁决与同频多机协同批处理及自动模式制热静电吸附动力学
- **核心目标与架构演进**：
  1. **自然语言限定基准集排除型星期周期调度通用引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **彻底解决限定基准集排除反向失真缺陷**：突破以往全集死板绑定为全周 7 天的限制，新增 `extractBaseScopeWeekdays` 引擎。针对“工作日除了周三每天早上8点开机”、“工作日除周五外每天晚10点关空调”、“周末除周日外早8点开机”、“周一到周五除了周二早8点开机”等生活高频复合场景，精准提取限定基准范围并求差集（如“工作日除周三” -> `[2, 3, 5, 6]` 周一、二、四、五；“周末除周日” -> `[7]` 周六；“工作日除周五” -> `[2, 3, 4, 5]` 周一至周四），彻底消除以往在周末非工作日或工作日误开空调的严重逻辑失真；
     - **语序与前瞻断言边界强化**：强化 `exclusionRepeatRegex` 前瞻断言，加入 `工作日|平时|周末|双休`，杜绝“除了周三工作日每天早8点开机”等前置语序将后续限定词错误吞噬；
     - **严密测试断言守护**：在 `VoiceCommandParserTests` 中扩充 7 组端到端限定基准集排除周期调度测试用例，100% 验证 PASS。
  2. **macOS 原生状态栏动作谓词真实布尔裁决与同频多机任务协同批处理 (`StatusItemController.swift` / `Models.swift`)**：
     - **开关机权威布尔负载优先裁决**：在 `AttrValue` 中补齐 `boolValue` 与 `doubleValue` 计算属性；在 `extractPlanActionVerb` 中优先以硬件真实下发的布尔值判断开机与关机，彻底根除“开关”、“开关机”中包含“关机”子串导致开机任务被反向显示为关机的严重倒置问题；
     - **高精温阶与模式动作提炼及双重括号语病清除**：支持 `targetTemperature` 精准输出“设定温度 26°C”、`operationMode` 输出“切换制冷”，并彻底清洗末尾自带的“（工作日）”等冗余后缀，杜绝菜单生成如“设定温度（工作日） (14:30) [工作日]”的双重重复语病；
     - **同频多机任务协同批量管理**：智能探测属于同一时间、同属性、同重复规则的同频兄弟任务（数量 > 1），在二级菜单中新增「⏸ 同步暂停此批任务 (N 台) / ▶️ 同步恢复此批任务 (N 台)」与「❌ 同步取消此批任务 (N 台)」，无需清空全屋所有定时即可一键管理整屋协同任务。
  3. **自动模式制热偏置冬季低湿静电吸附物理动力学相态统一 (`AppModel.calculateFilterWearFactor`)**：
     - **物理相态严密自洽**：提炼 `isHeatingPhysicalState`，将自动模式（`.auto`）下的制热升温偏置（`indoor < targetTemp` 或缺省时 `targetTemp > 25.0`）与冬季制热低湿静电驻极吸附模型（RH < 35% 时 1.00 ~ 1.12 阻尼插值）完全打通，根除原代码误将自动模式制热应用制冷干燥减免的物理相态不自洽缺陷。

---

## 2. 关键架构变更与代码实现

### 2.1 限定基准范围排除型周期调度通用引擎
- **`VoiceCommandParser.swift` 基准集提取与精确差集运算**：
  ```swift
  /// 从除外子句之外的文本中提取基准星期集合（Base Scope），若未指定则默认全周 7 天 (v1.9.69)
  private static func extractBaseScopeWeekdays(from text: String) -> Set<Int>? {
      let ns = text as NSString
      let fullRange = NSRange(location: 0, length: ns.length)
      if let regex = repeatWeekdayRangeRegex,
         let match = regex.firstMatch(in: text, options: [], range: fullRange),
         match.numberOfRanges >= 3 {
          let sStr = ns.substring(with: match.range(at: 1))
          let eStr = ns.substring(with: match.range(at: 2))
          if let sCh = sStr.first, let sWd = chineseDayCharToWeekday(sCh),
             let eCh = eStr.first, let eWd = chineseDayCharToWeekday(eCh) {
              return Set(generateWeeklyRange(start: sWd, end: eWd))
          }
      }
      if text.contains("工作日") || text.contains("平时") {
          return [2, 3, 4, 5, 6]
      }
      if text.contains("周末") || text.contains("双休") {
          return [1, 7]
      }
      return nil
  }

  /// 解析排除型周期语义并计算指定基准集合或全周的补集 (v1.9.68, v1.9.69 闭环限定基准范围约束)
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
      // 剥离排除子句，解析上下文中的限定基准集（如“工作日除了周三”的基准集为“工作日”，“周末除周日外”的基准集为“周末”）
      let remainingText = ns.replacingCharacters(in: match.range, with: " ")
      let baseScope = extractBaseScopeWeekdays(from: remainingText) ?? Set([1, 2, 3, 4, 5, 6, 7])
      let remaining = baseScope.subtracting(excluded)
      guard !remaining.isEmpty && remaining.count < baseScope.count else {
          return nil
      }
      let sorted = Array(remaining).sorted()
      let label = formatWeekdayLabel(from: sorted)
      return (sorted, label)
  }
  ```

### 2.2 macOS 状态栏动作谓词真实布尔裁决与同频多机协同批处理
- **`StatusItemController.swift` 动作提炼引擎硬件布尔裁决与精准动作映射**：
  ```swift
  // 1. 如果是开关机属性，以实际动作布尔负载为首要权威判定（彻底杜绝包含“开关”等词导致开机被反向识别为关机）
  if action.attrName == "onOffStatus" {
      if let boolVal = action.attrValue?.boolValue {
          return boolVal ? "开机" : "关机"
      }
      if name.contains("关机") || name.contains("关空调") || name.contains("关闭") {
          return "关机"
      }
      if name.contains("开机") || name.contains("开空调") || name.contains("开启") || name.contains("打开") {
          return "开机"
      }
      return (action.attrValue == .bool(true)) ? "开机" : "关机"
  }

  // 2. 目标温度属性：提炼精准目标温阶（如“设定温度 26°C”）
  if action.attrName == "targetTemperature" {
      if let d = action.attrValue?.doubleValue {
          let tempStr = (d.truncatingRemainder(dividingBy: 1.0) == 0) ? "\(Int(d))°C" : String(format: "%.1f°C", d)
          return "设定温度 \(tempStr)"
      }
  }

  // 3. 运行模式属性：提炼具体模式切换
  if action.attrName == "operationMode" {
      if let raw = action.attrValue?.stringValue, let code = ACModeCode.match(from: raw) {
          return "切换\(code.desc)"
      }
  }
  ```

- **同频兄弟任务智能探测与批量管理**：
  ```swift
  let siblingActions = model.scheduledActions.filter {
      abs($0.fireDate.timeIntervalSince(action.fireDate)) <= 2.0 &&
      $0.attrName == action.attrName &&
      $0.attrValueJSON == action.attrValueJSON &&
      $0.repeatsDaily == action.repeatsDaily &&
      $0.repeatWeekdays == action.repeatWeekdays
  }
  if siblingActions.count > 1 {
      singleMenu.addItem(.separator())
      let anySiblingEnabled = siblingActions.contains(where: \.enabled)
      let syncToggleTitle = anySiblingEnabled ? "⏸ 同步暂停此批任务 (\(siblingActions.count) 台)" : "▶️ 同步恢复此批任务 (\(siblingActions.count) 台)"
      let syncToggleItem = NSMenuItem(title: syncToggleTitle, action: #selector(toggleSiblingSchedulesFromMenu(_:)), keyEquivalent: "")
      syncToggleItem.target = self
      syncToggleItem.representedObject = siblingActions.map(\.id.uuidString)
      singleMenu.addItem(syncToggleItem)

      let syncCancelItem = NSMenuItem(title: "❌ 同步取消此批任务 (\(siblingActions.count) 台)", action: #selector(cancelSiblingSchedulesFromMenu(_:)), keyEquivalent: "")
      syncCancelItem.target = self
      syncCancelItem.representedObject = siblingActions.map(\.id.uuidString)
      singleMenu.addItem(syncCancelItem)
  }
  ```

### 2.3 自动模式制热偏置冬季低湿静电吸附物理动力学相态统一
- **`AppModel.swift` 制热静电模型与自动模式热力学相态对齐**：
  ```swift
  } else if hum < 45.0 {
      let isHeatingPhysicalState: Bool = {
          if modeCode == .heating { return true }
          if modeCode == .auto {
              if let indoor = indoorTemp {
                  return indoor < targetTemp
              } else {
                  return targetTemp > 25.0
              }
          }
          return false
      }()
      if isHeatingPhysicalState {
          // 制热工况（含自动模式制热偏置）：换热器高温无凝结水膜；但在冬季低湿干燥环境（RH < 35%）下，化纤滤网极易产生静电积聚（静电驻极效应），加速对细微干燥扬尘与浮尘的静电吸附截留；
          // 采用连续平滑静电吸附阻尼插值 (1.00 ~ 1.12)，消除简单套用制冷减免带来的物理失真 (v1.9.68, v1.9.69 补全自动模式制热偏置相态统一)
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
  - 在 `VoiceCommandParserTests.swift` 中运行测试，所有断言 100% PASS：
    1. “工作日除了周三每天早上8点开机” -> `[2, 3, 5, 6]`、每周一、二、四、五 08:00:00 ✅
    2. “工作日除周五外每天晚10点关空调” -> `[2, 3, 4, 5]`、周一至周四 22:00:00 ✅
    3. “周末除周日外早8点开机” -> `[7]`、每周六 08:00:00 ✅
    4. “周一到周五除了周二早8点开机” -> `[2, 4, 5, 6]`、每周一、三、四、五 08:00:00 ✅
    5. “除了周三工作日每天早8点开机” -> `[2, 3, 5, 6]`、每周一、二、四、五 08:00:00 ✅
    6. “工作日每天晚10点关空调除周五外” -> `[2, 3, 4, 5]`、周一至周四 22:00:00 ✅
    7. “工作日除周二和周四外每天早8点开机” -> `[2, 4, 6]`、每周一、三、五 08:00:00 ✅
    8. 原有 16 组全周排除断言（如“除了周末”、“除周日外”、“每天晚10点关机除了周末”）全部 100% 保持兼容通过 ✅
    9. `AttrValue.boolValue` 与 `AttrValue.doubleValue` 编解码及类型映射测试全部通过 ✅
- **本地编译与打包校验**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` 0 警告 0 错误编译通过；
  - `./build_app.sh 1.9.69` 构建成功：
    - `dist/HaierAC.app` (含 `HaierACWidget.appex` 小组件扩展)
    - `dist/HaierAC-v1.9.69-macOS.zip` (大小: 2.8M)
    - SHA256 校验和：`3e28b44f3b783a5242291da1169ed5b3221d4fba472408aee2c0581c8bbbc93c`
- **安全敏感数据审查**：
  - 严密审查无任何个人手机号、真实密码、私有 API Key 或敏感隐私数据外泄。
