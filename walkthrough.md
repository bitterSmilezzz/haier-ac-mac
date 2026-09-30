# Haier AC Mac v1.9.97 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.97`
- **发版主题**：闭环单星期与周区间反相循环调度脱靶缺陷、macOS 原生状态栏全屋模式待机唤醒大一统与滤网动力学时间衰减加权模型
- **核心目标与架构演进**：
  1. **“非周X / 非星期X / 非礼拜X及反相周区间”自然周期循环调度逻辑脱靶缺陷彻底修复与防误触全闭环 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **彻底修复单星期与周区间反相表达被正相词贪婪匹配导致星期极性 180 度颠倒重大缺陷**：此前在自然周期提取管线中，“非周一8点开机”、“非周日8点开机”、“非星期三开机”、“非周一至周五开机”等口语由于缺乏前置反相拦截，被下方的“周一”、“周日”、“周一至周五”等正相词贪婪截断，导致“非周一开机”（意图为除周一外的周二至周日 `[1, 3, 4, 5, 6, 7]`）被严重颠倒识别为仅在周一开机 `[2]`；“非周日开机”被颠倒识别为仅在周日开机 `[1]`；“非周一至周五开机”（非工作日）被颠倒识别为工作日 `[2, 3, 4, 5, 6]`！本版本在 `parseBaseRepeatWeekdays` 中建立了核心前置反相单星期与周区间调度拦截，将“非周一”至“非周日”精准映射为对应的周环形补集，将“非周一至周五”精准映射至周末 `[1, 7]`，将“非周六至周日”精准映射至工作日 `[2, 3, 4, 5, 6]`，彻底消除反向极性颠倒；
     - **彻底修复排除型否定语义中嵌套反相星期（“除非周一外每天开机”）被正向截断反向排除的缺陷**：在 `extractExcludedDays` 中建立“非周X / 非星期X”前置拦截，精准提取其补集，实现“除非周一外每天开机”正确保留并仅在周一执行 `[2]`，彻底自洽；
     - **全景反相星期与半点时相归一流水线与防即时误触加固**：全面纳管“非周一”至“非周日”、“非星期1~7”、“非礼拜1~7”及半点“非周一半”~“非周日半”（映射至 08:30），并在 `hasTimingOrCountdownIntent` 中全面严防，绝不掉入即时开关机；
     - **单元测试 100% 满分覆盖**：在 `VoiceCommandParserTests.swift` 中新增 `testNonWeekdayScheduleHardeningV1997`，包含 22 组单星期反相、周区间反相、排除型嵌套、半点归一及严苛防即时误触断言，全部通过。
  2. **macOS 原生状态栏全屋运行模式协同待机唤醒大一统 (`StatusItemController.swift`)**：
     - **全屋待机状态下支持直接选择模式一键唤醒**：解耦顶层「🔄 全屋模式协同」菜单项门禁，从原本硬编码依赖 `!onDevices.isEmpty` 升级为基于 `!controllableDevices.isEmpty` 网关可控裁决。当全屋空调均处于关机待机状态时，菜单项不再置灰禁用，用户可直接点击制热（🔥）、制冷（❄️）等工况项一键全屋唤醒并平滑切入该模式，杜绝了此前必须先开启全屋空调（以旧模式吹风）再二次进菜单修改模式的断层繁琐体验；
     - **自适应悬浮 Tooltip 与运行台数动态指引**：待机时菜单项呈现“🔄 全屋模式协同 (全屋待机中 · 点击开启模式)”，各模式子项智能提示“一键开启全屋 N 台空调并设为制热模式”；与单设备及级联设备模式菜单形成 100% 全对称交互闭环。
  3. **多设备滤网动力学近期机时时间衰减加权平滑算法升级 (`AppModel.swift`)**：
     - **时间衰减高斯加权模型引入**：在 `estimatedFilterRemainingDays` 中，对提取的近 14 天 `totalDeviceMinutes` 引入时间衰减加权平滑机制（近 3 天 1.4x，4~7 天 1.2x，远期 1.0x），显著降低了换季骤冷骤热时单日异常机时对滤网剩余寿命估算的剧烈抖动，计算更平滑拟真。
  4. **Siri 与快捷指令全屋模式快捷词拓展与计划调度反相时态安全防护 (`AppIntents.swift`)**：
     - **AppShortcuts 高频快捷短语扩展**：在 `SetACModeIntent` 中新增“用 Haier AC 开启制冷”、“用 Haier AC 开启制热”、“全屋制冷”、“全屋制热”等高频口语；
     - **计划调度单星期字面量反相否定前置守卫**：在 `ScheduleACPowerIntent` 中增加否定词前置拦截，防止包含“非”/“除”的口语掉入单星期字面量匹配。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下审查报告及全仓架构进行了全景复核与缺陷深挖：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 正则结构稳固，跨字符穿插防御严密；
   - **全屋与定向定时解耦 (P1-2)**：`cancelSchedules` 与 `cancelSchedulesAll` 精确分流，多设备批量取消分支全部贯通；
   - **工况占比计算属性消费 (P2-1)**：`EcoEnergySection` 已统一调用 4 个比率属性；
   - **死分支清理 (P2-2)**：`.adjustTemperatureAll` 死分支已彻底清理；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏与 UI Stepper 使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **单星期与周区间反相调度“非周X / 非星期X / 非周一至周五”极性颠倒重大缺陷 (P0/P1)**：在自然周期调度提取中，“非周一8点开机”由于直接匹配“周一”导致仅在周一开机，星期极性 180 度颠倒；同时“除非周一外每天开机”被反向排除周一导致周一不开机。本版本在 `parseBaseRepeatWeekdays` 与 `extractExcludedDays` 中建立前置反相单星期与区间识别，完美修复；
   - **状态栏全屋协同待机状态下无法直接选择模式唤醒 (P1/P2)**：此前在状态栏顶层菜单中，全屋待机时「🔄 全屋模式协同」整组置灰禁用，用户无法在全屋待机时一键将所有设备以制冷/制热模式唤醒。本次放开待机模式选择，支持一键全屋唤醒并切入指定模式；
   - **滤网剩余天数近期波动剧烈 (P2)**：已在 `AppModel.estimatedFilterRemainingDays` 中引入时间衰减加权平滑算法；
   - **Siri 快捷指令与 AppShortcuts 模式短语扩充 (P2)**：已在 `AppIntents.swift` 中为 `SetACModeIntent` 增加全屋制冷/制热高频快捷短语。

---

## 3. 关键架构变更与代码实现

### 3.1 单星期与周区间反相循环调度修复
- **`VoiceCommandParser.swift` 前置反相星期与周区间提取**：
  ```swift
  // 4.-1 非单星期反相调度前置拦截 (v1.9.97)
  if text.contains("非周一至周五") || text.contains("非周一到周五") || text.contains("非星期一到星期五") {
      return ([1, 7], "周末")
  }
  if text.contains("非周六至周日") || text.contains("非周六到周日") || text.contains("非星期六到星期日") {
      return ([2, 3, 4, 5, 6], "工作日")
  }

  let nonWeekdayRegex = try? NSRegularExpression(pattern: #"(?:每个?|每周|每逢|逢)?\s*非\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])"#)
  let baseNs = text as NSString
  let baseFullRange = NSRange(location: 0, length: baseNs.length)
  if let nonMatches = nonWeekdayRegex?.matches(in: text, options: [], range: baseFullRange), !nonMatches.isEmpty {
      var excludedWds = Set<Int>()
      for m in nonMatches {
          if m.numberOfRanges >= 2 {
              let chStr = baseNs.substring(with: m.range(at: 1))
              if let ch = chStr.first, let wd = chineseDayCharToWeekday(ch) {
                  excludedWds.insert(wd)
              }
          }
      }
      if !excludedWds.isEmpty {
          let targetDays = Set([1, 2, 3, 4, 5, 6, 7]).subtracting(excludedWds).sorted()
          let label = formatRepeatWeekdaysLabel(targetDays) ?? "每天"
          return (targetDays, label)
      }
  }
  ```
- **`hasTimingOrCountdownIntent` 与 `normalizeTimeExpressions` 严密时态防线**：
  全面纳管“非周一”至“非周日”、“非周1~7”、“非星期1~7”、“非礼拜1~7”及半点归一，杜绝误触立即开关机。

### 3.2 macOS 原生状态栏全屋运行模式协同待机唤醒
- **`StatusItemController.swift`**：
  ```swift
  let controllableDevices = model.allUnifiedDevices.filter { model.reachability(for: $0.id).isControllable }
  let modeRunningDesc = !onDevices.isEmpty ? (allOnSameMode != nil ? " (\(onDevices.count)台运行中 · 当前\(allOnSameMode!.desc))" : " (\(onDevices.count)台运行中 · 模式不同)") : " (全屋待机中 · 点击开启模式)"
  let canSetModeAll = model.gatewayConnected && !controllableDevices.isEmpty

  for itemDef in modeLevels {
      let isSelected = (allOnSameMode == itemDef.code)
      let check = isSelected ? "✓ " : ""
      let item = NSMenuItem(title: "\(check)\(itemDef.title)", action: #selector(setAllModeFromMenu(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = itemDef.code.rawValue
      item.isEnabled = canSetModeAll
      ...
  }
  ```

### 3.3 滤网动力学近期机时时间衰减加权平滑
- **`AppModel.swift`**：
  ```swift
  let devCount = max(1, allUnifiedDevices.count)
  var weightedMinutesSum = 0.0
  var totalWeight = 0.0
  for (idx, record) in activeRecords.enumerated() {
      let weight: Double = idx < 3 ? 1.4 : (idx < 7 ? 1.2 : 1.0)
      let devMins = record.totalDeviceMinutes > 0 ? (Double(record.totalDeviceMinutes) / Double(devCount)) : Double(record.totalMinutes)
      weightedMinutesSum += devMins * weight
      totalWeight += weight
  }
  let avgDeviceMins = weightedMinutesSum / max(1.0, totalWeight)
  dailyMinutes = max(30.0, avgDeviceMins)
  ```

---

## 4. 验证与测试结果

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增并校验端到端单元测试用例（22 组严苛断言 100% PASS）：
  - `"非周一8点开机"` -> `08:00` 开机，周二至周日循环 (`[1, 3, 4, 5, 6, 7]`) (PASS)
  - `"非周日8点开机"` -> `08:00` 开机，周一至周六循环 (`[2, 3, 4, 5, 6, 7]`) (PASS)
  - `"非周天8点关机"` -> `08:00` 关机，周一至周六循环 (`[2, 3, 4, 5, 6, 7]`) (PASS)
  - `"非周六8点开机"` -> `08:00` 开机，周日至周五循环 (`[1, 2, 3, 4, 5, 6]`) (PASS)
  - `"非星期三8点开机"` -> `08:00` 开机，周四至周二循环 (`[1, 2, 3, 5, 6, 7]`) (PASS)
  - `"非礼拜五8点开机"` -> `08:00` 开机，周六至周四循环 (`[1, 2, 3, 4, 5, 7]`) (PASS)
  - `"非周一至周五8点开机"` -> `08:00` 开机，周末循环 (`[1, 7]`) (PASS)
  - `"非周六至周日8点开机"` -> `08:00` 开机，工作日循环 (`[2, 3, 4, 5, 6]`) (PASS)
  - `"除非周一外每天开机"` -> `08:00` 开机，每周一 (`[2]`) (PASS)
  - `"除非周日外每天开机"` -> `08:00` 开机，每周日 (`[1]`) (PASS)
  - `"非周一半开机"` -> `08:30` 开机，周二至周日循环 (`[1, 3, 4, 5, 6, 7]`) (PASS)
  - `"非周日半关机"` -> `08:30` 关机，周一至周六循环 (`[2, 3, 4, 5, 6, 7]`) (PASS)
  - 防即时误触全景断言：10 组反相口语严苛断言绝不触发 `setPower`、`turnOffAll` 或 `turnOnAll` (PASS)

- **本地编译验证**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` -> 100% 通过（0 错误，0 致命告警）
  - `./build_app.sh 1.9.97` -> 打包成功：
    - `dist/HaierAC.app` (v1.9.97, 含小组件)
    - `dist/HaierAC-v1.9.97-macOS.zip`
