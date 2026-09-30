# Haier AC Mac v1.9.99 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.99`
- **发版主题**：闭环大小周与大休小休/节假日反相循环调度、macOS 原生状态栏全屋与单机温度步进待机唤醒大一统与 Siri 调温上限纠正
- **核心目标与架构演进**：
  1. **“大小周/大休/小休与节假日反相时态”自然周期循环调度大一统引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **全景覆盖大小周/大休/小休与节假日正向与反相自然调度**：
       - 正向调度：涵盖“逢大休/大周/双休/节假日/休假日/放假日”精准映射至周末双休 `[1, 7]`；“逢小休/小周/单休日”精准映射至周日单休 `[1]`；
       - 反相调度：新增“非大休/非大周/非节假日/非休假日/非放假日”精准映射至工作日 `[2, 3, 4, 5, 6]`；“非小休/非小周/非小休日”精准映射至周一至周六 `[2, 3, 4, 5, 6, 7]`；彻底消除将“非大休”或“非小休”掉入字面量贪婪截断导致的极性颠倒；
     - **彻底修复排除型否定嵌套大小周与节假日补集自洽**：在 `extractExcludedDays` 中建立“大休/大周/小休/小周”及对应反相前置拦截引擎，实现“除大休外每天”（保留工作日 `[2, 3, 4, 5, 6]`）、“除小休外每天”（保留周一至周六 `[2, 3, 4, 5, 6, 7]`）、“除非大休外每天”（保留周末 `[1, 7]`）、“除非小休外每天”（保留周日 `[1]`）、“除节假日外每天”补集运算自洽；
     - **大小周与节假日半点时相归一及防即时误触加固**：全面纳管“大休半”、“小休半”、“非大休半”、“非小休半”、“节假日半”、“非节假日半”等映射至 08:30，并在 `hasTimingOrCountdownIntent` 中严密守护，绝不穿透至即时开关机；
     - **单元测试 100% 满分覆盖**：在 `VoiceCommandParserTests.swift` 中新增 `testBigSmallWeekendScheduleV1999`，包含 28 组严苛正反向、嵌套排除、半点归一及防即时误触断言，全部通过。
  2. **macOS 原生状态栏全屋与单机温度步进待机唤醒大一统 (`StatusItemController.swift`)**：
     - **全屋升降温 1°C / 0.5°C 支持待机一键直接唤醒**：解耦顶层「🌡️ 全屋升降温」及「微调 0.5°C」菜单项门禁，从原本硬编码依赖 `!onDevices.isEmpty` 升级为基于网关可控裁决 `!controllableDevices.isEmpty`。当全屋空调均处于关机待机状态时，菜单项不再置灰禁用，用户可直接点击升温或降温一键全屋唤醒并设定目标温度，并在待机时提示“`🌡️ 全屋升温 1°C (全屋待机中 · 点击唤醒调温)`”；
     - **单机与级联温度步进菜单待机直接唤醒**：解耦单设备主菜单及专属子菜单中的升温降温 1°C / 0.5°C 门禁，待机状态下点击温度步进自动唤醒开机并调整温度；
     - **与模式、风速协同形成 100% 全对称交互大一统**：状态栏全屋协同的「模式协同」、「风速协同」、「温度步进」三大核心控制域全部实现关机待机下一键自适应唤醒。
  3. **AppModel 调温 API 待机唤醒全链路贯通 (`AppModel.swift`)**：
     - **全套调温函数底层支持 `autoPowerOn: Bool = false`**：在 `adjustDeviceTemperature`、`adjustTemperature`、`adjustTemperatureAll`、`setTemperature`、`setTemperatureAll` 中引入关机待机智能感知。当 `autoPowerOn: true` 且设备处于关机状态时，自动触发开机并调节温度，提供“已为您开启「客厅」并设置温度为 26°C”等清晰自洽的通知与反馈。
  4. **Siri 与快捷指令 `AdjustACTemperatureIntent` 待机唤醒与虚假上限纠正 (`AppIntents.swift`)**：
     - **彻底修复关机待机时 Siri 调温误报“已达最高温度 30°C 上限”的严重反直觉缺陷**：此前在关机状态下执行调温意图时，由于 `onDevices.isEmpty` 导致内部 `count == 0`，逻辑盲目进入 `if delta > 0 { throw ... 30°C 上限 }` 报错；本次升级重构为使用 `autoPowerOn: true` 唤醒可控设备并调温，反馈“已为您开启「全屋/客厅」并调整温度至 26°C”；
     - **AppShortcuts 快捷短语全景扩充**：新增“全屋升温”、“全屋降温”、“全屋微升温”、“全屋微降温”、“调高空调温度”、“调低空调温度”等口语控制短语。

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
   - **大小周/大休/小休与节假日反相循环调度脱靶缺陷 (P1)**：在自然语言排班中，“非大休”（意为小休周及工作日）与“非小休”（除单休日外的六天）、“非节假日”（工作日）缺乏反向提取，且容易被大休/双休等词贪婪截断导致 180 度极性颠倒；在嵌套排除语义“除大休外每天”中也存在解析断层。本次重构确立了大小周/大休小休正反向及嵌套补集完整算法；
   - **macOS 原生状态栏全屋与单机温度步进待机置灰禁用 (P1/P2)**：此前当所有空调处于待机状态时，温度微调（升温/降温 1°C / 0.5°C）全部置灰禁用，用户必须先通过开关机或模式菜单开机后才能调温；本次全面升级为支持一键待机唤醒调温，实现全屋协同（模式、风速、调温）交互 100% 全对称大一统；
   - **Siri 调温待机时误报 30°C 上限严重反直觉体验 (P1)**：关机状态下向 Siri 说“调高空调温度”，因开机设备数为 0 触发误判逻辑，Siri 会谎报“当前已是最高温度 30°C，无法继续调高”；本次升级为自动开机唤醒调温，并丰富了快捷指令短语体系。

---

## 3. 关键架构变更与代码实现

### 3.1 大小周与大休/小休/节假日反相时态自然调度大一统
- **`VoiceCommandParser.swift` 前置大小周反相与正相拦截**：
  ```swift
  // 4.-3 大小周与节假日反相/正相调度拦截 (v1.9.99)
  let nonBigSmallHolidayPattern = #"(?:每个?|每周|每逢|逢)?\s*非\s*(?:大休|大周|节假日|休假日|放假日)"#
  if let r = nonBigSmallHolidayPattern.range(of: text, options: .regularExpression) {
      let days = [2, 3, 4, 5, 6] // 工作日
      return (days, formatRepeatWeekdaysLabel(days) ?? "工作日")
  }

  let nonSmallRestPattern = #"(?:每个?|每周|每逢|逢)?\s*非\s*(?:小休|小周|小休日)"#
  if let r = nonSmallRestPattern.range(of: text, options: .regularExpression) {
      let days = [2, 3, 4, 5, 6, 7] // 周一至周六
      return (days, formatRepeatWeekdaysLabel(days) ?? "周一至周六")
  }
  ```
- **`extractExcludedDays` 排除型嵌套语义大小周与节假日补集自洽**：
  ```swift
  if t.contains("非大休") || t.contains("非大周") || t.contains("非节假日") {
      return [2, 3, 4, 5, 6]
  }
  if t.contains("非小休") || t.contains("非小周") || t.contains("非小休日") {
      return [2, 3, 4, 5, 6, 7]
  }
  if t.contains("大休") || t.contains("大周") || t.contains("节假日") {
      return [1, 7]
  }
  if t.contains("小休") || t.contains("小周") || t.contains("小休日") {
      return [1]
  }
  ```

### 3.2 macOS 原生状态栏全屋与单机温度步进待机唤醒
- **`StatusItemController.swift`**：
  ```swift
  let canAdjustTempAll = model.gatewayConnected && !controllableDevices.isEmpty
  let tempStandbyHint = onDevices.isEmpty ? " (全屋待机中 · 点击唤醒调温)" : ""

  let upItem = NSMenuItem(title: "🌡️ 全屋升温 1°C\(tempStandbyHint)", action: #selector(adjustAllTempFromMenu(_:)), keyEquivalent: "")
  upItem.representedObject = Double(1.0)
  upItem.isEnabled = canAdjustTempAll && (allAtMaxTemp == false)
  ...
  ```
  通过 `autoPowerOn: true` 将调温动作平滑透传到底层 `AppModel`，待机设备直接唤醒开机并调整温度。

### 3.3 AppModel 调温 API 待机唤醒全链路贯通
- **`AppModel.swift`**：
  ```swift
  func adjustDeviceTemperature(deviceId: String, delta: Double, autoPowerOn: Bool = false) async -> Bool {
      guard let dev = devices.first(where: { $0.id == deviceId }) else { return false }
      if !dev.isPowerOn && autoPowerOn {
          _ = await setPower(deviceId: deviceId, power: true)
      }
      ...
  }
  ```

### 3.4 Siri 调温上限误报纠正与待机自动唤醒
- **`AppIntents.swift`**：
  ```swift
  let targetDevices = onDevices.isEmpty ? controllableDevices : onDevices
  guard !targetDevices.isEmpty else {
      throw $appError("未找到可控制的空调设备")
  }
  let needAutoPower = onDevices.isEmpty
  for dev in targetDevices {
      _ = await model.adjustDeviceTemperature(deviceId: dev.id, delta: delta, autoPowerOn: needAutoPower)
  }
  ```

---

## 4. 验证与测试结果

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增 `testBigSmallWeekendScheduleV1999`（28 组严苛断言 100% PASS）：
  - `"逢大休8点开机"` -> `08:00` 开机，周末双休循环 (`[1, 7]`) (PASS)
  - `"大周8点开机"` -> `08:00` 开机，周末双休循环 (`[1, 7]`) (PASS)
  - `"节假日8点开机"` -> `08:00` 开机，周末双休循环 (`[1, 7]`) (PASS)
  - `"逢小休8点开机"` -> `08:00` 开机，周日循环 (`[1]`) (PASS)
  - `"小周8点开机"` -> `08:00` 开机，周日循环 (`[1]`) (PASS)
  - `"非大休8点开机"` -> `08:00` 开机，工作日循环 (`[2, 3, 4, 5, 6]`) (PASS)
  - `"非大周8点开机"` -> `08:00` 开机，工作日循环 (`[2, 3, 4, 5, 6]`) (PASS)
  - `"非节假日8点开机"` -> `08:00` 开机，工作日循环 (`[2, 3, 4, 5, 6]`) (PASS)
  - `"非小休8点开机"` -> `08:00` 开机，周一至周六循环 (`[2, 3, 4, 5, 6, 7]`) (PASS)
  - `"非小周8点开机"` -> `08:00` 开机，周一至周六循环 (`[2, 3, 4, 5, 6, 7]`) (PASS)
  - `"除大休外每天8点开机"` -> `08:00` 开机，工作日循环 (`[2, 3, 4, 5, 6]`) (PASS)
  - `"除小休外每天8点开机"` -> `08:00` 开机，周一至周六循环 (`[2, 3, 4, 5, 6, 7]`) (PASS)
  - `"除非大休外每天8点开机"` -> `08:00` 开机，周末双休循环 (`[1, 7]`) (PASS)
  - `"除非小休外每天8点开机"` -> `08:00` 开机，周日循环 (`[1]`) (PASS)
  - `"除节假日外每天8点开机"` -> `08:00` 开机，工作日循环 (`[2, 3, 4, 5, 6]`) (PASS)
  - 时相归一断言：`"大休半"`, `"小休半"`, `"非大休半"`, `"非小休半"` 精准映射至 `08:30` (PASS)
  - 防即时误触断言：8 组大小周与节假日口语断言绝不穿透至即时开关机 (PASS)

- **本地编译验证**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` -> 100% 通过（0 错误，0 致命告警）
  - `./build_app.sh 1.9.99` -> 打包成功：
    - `dist/HaierAC.app` (v1.9.99, 含小组件)
    - `dist/HaierAC-v1.9.99-macOS.zip` (SHA256 完整，已归档)

---

## 5. 发版交付总结

- **Git Commit**：包含大小周与节假日反相循环调度引擎、macOS 原生状态栏全屋/单机温度步进待机唤醒、AppModel 调温 API 待机唤醒及 Siri 调温误报纠正。
- **Git Tag**：`v1.9.99`
- **GitHub Release**：附带产物压缩包与完整更新日志。
