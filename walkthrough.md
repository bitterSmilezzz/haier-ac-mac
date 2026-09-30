# Haier AC Mac v1.9.95 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.95`
- **发版主题**：闭环自然口语非工作日/非平日/非周末/休息日反相循环调度脱靶缺陷、macOS 原生状态栏单机与矩阵模式协同大一统与 Siri 全屋湿度看板
- **核心目标与架构演进**：
  1. **“非工作日/非平日/非周末/休息日/公休日”反相自然周期循环调度逻辑脱靶缺陷彻底修复与防误触全闭环 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **彻底修复非工作日与非平日被“工作日”贪婪匹配导致星期极性颠倒的反向执行重大缺陷**：此前在自然周期提取管线中，“非工作日开机”、“非平日关机”等口语由于缺乏前置反相拦截，被下方的“工作日”前缀贪婪截断，错误映射为周一至周五（`[2, 3, 4, 5, 6]`），导致在原本应当休息的周末不执行而在工作日误启动的极性颠倒缺陷；同理，“非周末开机”、“非双休关机”被“周末”贪婪映射为周末（`[1, 7]`）；本版本在 `parseBaseRepeatWeekdays` 中建立了核心前置反相调度拦截，将“非工作日/非平日”精准映射至周末（`[1, 7]`），将“非周末/非双休/非双休日/非休息日/非公休日”精准映射至工作日（`[2, 3, 4, 5, 6]`），将“休息日/公休日/休假日/放假日/节假日”精准映射至周末（`[1, 7]`），将“平日”精准映射至工作日（`[2, 3, 4, 5, 6]`），彻底自洽；
     - **杜绝休息日与反相时态口语穿透为即时开关机造成误关开机的严重隐患**：此前“休息日开机”、“公休日关空调”、“非平日关空调”、“全屋休息日关机”等口语在 `hasTimingOrCountdownIntent` 中未列入前缀判定，返回 false，直接穿透至 `turnOffAll` / `turnOnAll` 即时开关机造成全屋误动作；本版本在 `hasTimingOrCountdownIntent` 中全面筑牢反相与休息日全景前置防线；
     - **反相与休息日半点时相标准化归一流水线 (`convertChineseNumbers`)**：新增“非工作日半”、“非平日半”、“非周末半”、“非双休半”、“非双休日半”、“休息日半”、“公休日半”、“休假日半”、“平日半”等 18 组口语半点时相标准化映射至 08:30；
     - **单元测试 100% 满分覆盖**：在 `VoiceCommandParserTests.swift` 中新增 `testInvertedWeekAndRestDayScheduleHardeningV1995`，包含 24 组反相映射、离散星期组合、半点归一及严苛防即时误触断言，全部通过。
  2. **macOS 原生状态栏单机与矩阵模式协同大一统 (`StatusItemController.swift` / `AppModel.swift`)**：
     - **单设备与矩阵设备专属运行模式切换子菜单**：在多设备矩阵右键子菜单（`devSubmenu`）与单设备主菜单中，新增独立的「🔄 运行模式 (当前: 制冷)」动态交互子菜单，涵盖制冷（❄️）、制热（🔥）、除湿（💧）、送风（🍃）、自动（🔄）全工况，并带有当前状态 `✓` 选中态指示与智能 Tooltip 引导；
     - **维持温度设定的纯模式切换与单机通知优化**：区别于重置目标温度的“一键制冷 26°C”快捷项，新子菜单通过 `AppModel.setMode(deviceIds:mode:)` 在保持当前目标温度不变的前提下平滑切换模式，并优化了单机操作时的悬浮通知文本（`已将「客厅空调」模式设为「制冷」`）。
  3. **Siri 与快捷指令 (`AppIntents.swift`) 室内相对湿度看板与设备控制闭环 (`AppIntents.swift`)**：
     - **新增 `GetACHumidityIntent` 相对湿度查询看板**：支持语音或快捷指令查询单机当前室内相对湿度（如“客厅空调当前室内相对湿度 52%”），并支持全屋查询自动计算全屋平均相对湿度及呈现各设备湿度分布；
     - **AppShortcuts 系统无缝索引**：注册“用 Haier AC 查询湿度”、“Haier AC 室内湿度”快捷短语；
     - **单机调温与模式控制收敛至安全模型**：重构 `SetACTemperatureIntent` 与 `SetACModeIntent`，单机控制时经由 `AppModel.setTemperature` 与 `AppModel.setMode`，全面支持待机自动唤醒与温度上下限防护。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下审查报告及全仓架构进行了全景复核与缺陷深挖：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 正则结构稳固，跨字符穿插防御严密；
   - **全屋与定向定时解耦 (P1-2)**：`cancelSchedules` 与 `cancelSchedulesAll` 精确分流，多设备批量取消分支全部贯通；
   - **工况占比计算属性消费 (P2-1)**：`EcoEnergySection` 已统一调用 4 个比率属性；
   - **死分支清理 (P2-2)**：`.adjustTemperatureAll` 死分支已彻底清理；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **非工作日/非平日/非周末自然周期调度反相脱靶缺陷 (P0/P1)**：在此前的自然口语提取逻辑中，“非工作日开机”、“非平日关空调”等由于缺乏前置否定/反相词拦截，直接落入 `if text.contains("工作日")`，被反向映射为工作日 `[2, 3, 4, 5, 6]`；“非周末开机”被落入 `if text.contains("周末")` 映射为 `[1, 7]`，产生与用户初衷 180 度相反的反向执行缺陷。本版本建立前置反相拦截，完美反转映射，彻底消除此重大安全缺陷；
   - **休息日口语穿透即时开关机缺陷 (P1)**：“休息日开机”、“公休日关空调”、“非平日关空调”等指令由于缺少前置时态声明，被误判为没有定时意图，直接穿透至即时开关机，造成全屋或单机立即误关/误开。本版本在 `hasTimingOrCountdownIntent` 中全面筑牢防线；
   - **状态栏多设备与单设备缺少运行模式切换子菜单 (P1/P2)**：此前状态栏有风速切换子菜单（带 `✓`）与全屋模式协同子菜单，但单个设备在多设备矩阵与单设备主菜单中仅有快捷按钮（如“一键制冷 26°C”会覆盖用户温度），缺少纯净的模式切换与状态感知。本次补全了「🔄 运行模式」交互子菜单；
   - **Siri / 快捷指令缺少湿度查询看板与单机控制未走安全模型 (P2)**：空调已支持室内湿度感知，但此前缺少对应的 Siri 查询 Intent；且单机模式与温度控制直接写属性，未走安全限制与待机唤醒模型。本次新增 `GetACHumidityIntent` 并收敛控制调用。

---

## 3. 关键架构变更与代码实现

### 3.1 反相与休息日循环调度大一统及防即时误触加固
- **`VoiceCommandParser.swift` 前置反相自然周期识别**：
  ```swift
  // 4.-1 非工作日/非平日与非周末/非双休反相调度，前置拦截杜绝误入正相工作日/周末 (v1.9.95)
  if text.contains("非工作日") || text.contains("非平日") {
      return ([1, 7], "周末")
  }
  if text.contains("非周末") || text.contains("非双休") || text.contains("非双休日") || text.contains("非休息日") || text.contains("非公休日") {
      return ([2, 3, 4, 5, 6], "工作日")
  }

  // 4.01 休息日/公休日/平日自然口语映射 (v1.9.95)
  if text.contains("休息日") || text.contains("公休日") || text.contains("休假日") || text.contains("放假日") || text.contains("节假日") {
      return ([1, 7], "周末")
  }
  if text.contains("平日") {
      return ([2, 3, 4, 5, 6], "工作日")
  }
  ```
- **`hasTimingOrCountdownIntent` 严密时态防线**：
  全面纳管“非工作日”、“非平日”、“非周末”、“非双休”、“非双休日”、“非休息日”、“非公休日”、“休息日”、“公休日”、“休假日”、“平日”等全量口语，杜绝误触立即开关机。

### 3.2 macOS 原生状态栏单机与矩阵模式协同
- **`StatusItemController.swift` 模式切换子菜单与交互处理**：
  ```swift
  // 运行模式协同切换 (v1.9.95)
  let devModeMenu = NSMenu()
  devModeMenu.autoenablesItems = false
  for itemDef in Self.modeLevels {
      let isSelected = (modeCode == itemDef.code)
      let check = isSelected ? "✓ " : ""
      let item = NSMenuItem(title: "\(check)\(itemDef.title)", action: #selector(setDeviceModeFromMenu(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = ["deviceId": devId, "mode": itemDef.code.rawValue]
      item.isEnabled = isControllable && isPowerOn
      ...
  }
  ```

### 3.3 Siri / 快捷指令相对湿度看板与安全路由
- **`AppIntents.swift`**：
  ```swift
  struct GetACHumidityIntent: AppIntent {
      static var title: LocalizedStringResource = "查询空调湿度"
      static var description = IntentDescription("查询空调当前室内相对湿度", categoryName: "空调控制")

      @Parameter(title: "设备名称", description: "可选；留空使用主设备，填“全屋”或“全部”查询全屋平均湿度")
      var deviceName: String?

      @MainActor
      func perform() async throws -> some IntentResult & ProvidesDialog {
          ...
      }
  }
  ```

---

## 4. 验证与测试结果

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增并校验端到端单元测试用例（24 组断言 100% PASS）：
  - `"非工作日开机"` -> `08:00` 开机，周末循环 (`[1, 7]`) (PASS)
  - `"非工作日关机"` -> `08:00` 关机，周末循环 (`[1, 7]`) (PASS)
  - `"非平日开机"` -> `08:00` 开机，周末循环 (`[1, 7]`) (PASS)
  - `"非周末开机"` -> `08:00` 开机，工作日循环 (`[2, 3, 4, 5, 6]`) (PASS)
  - `"非双休开机"` -> `08:00` 开机，工作日循环 (`[2, 3, 4, 5, 6]`) (PASS)
  - `"休息日开机"` -> `08:00` 开机，周末循环 (`[1, 7]`) (PASS)
  - `"公休日关空调"` -> `08:00` 关机，周末循环 (`[1, 7]`) (PASS)
  - `"平日开机"` -> `08:00` 开机，工作日循环 (`[2, 3, 4, 5, 6]`) (PASS)
  - `"非工作日半开机"` -> `08:30` 开机，周末循环 (`[1, 7]`) (PASS)
  - `"非平日半关机"` -> `08:30` 关机，周末循环 (`[1, 7]`) (PASS)
  - `"休息日半开机"` -> `08:30` 开机，周末循环 (`[1, 7]`) (PASS)
  - `"平日半关机"` -> `08:30` 关机，工作日循环 (`[2, 3, 4, 5, 6]`) (PASS)
  - 严苛防即时误触断言（针对上述所有口语，严格禁止掉入 `setPower`、`turnOffAll` 或 `turnOnAll` 即时开关机，全部 PASS）。
- **编译与打包校验**：
  - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 警告 0 错误编译通过；
  - 运行 `./build_app.sh 1.9.95` 打包生成 `dist/HaierAC-v1.9.95-macOS.zip` (2.8MB)。

---

## 5. 发版信息与资产交付
- **版本号**：`v1.9.95`
- **Git Tag**：`v1.9.95`
- **Release 资产**：`dist/HaierAC-v1.9.95-macOS.zip`
- **SHA-256**：`5bcbe24ec6a93e9ffa5ff37f2277558129b3531693e63f5e655a5bb36e719d9b`
- **安全敏感数据检查**：经核验，源码与文档均无敏感个人信息、真实 Token 或凭证，符合安全脱敏规范。
