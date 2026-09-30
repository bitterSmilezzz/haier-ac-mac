# Haier AC Mac v1.9.94 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.94`
- **发版主题**：闭环自然口语「逢单休/单休日」循环调度脱靶缺陷、macOS 原生状态栏全屋模式协同大一统、静音 0 档动力学全仓对齐与 Siri 全屋电源控制贯通
- **核心目标与架构演进**：
  1. **“逢单休/单休日”自然周期循环调度逻辑脱靶缺陷修复与防误触全闭环 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **修复星期反向颠倒缺陷**：彻底修复上一版本在调度提取管线中遗漏具体分支，导致“逢单休开机”、“单休日关机”、“逢单休半开机”被通用“单休”贪婪拦截并错误映射为 `[2, 3, 4, 5, 6, 7]`（“周一至周六”）的严重语义颠倒缺陷；
     - **精确映射周日与周末基准**：在 `parseBaseRepeatWeekdays` 中建立核心前置拦截，将“逢单休/每逢单休/单休日”精准映射至周日（`[1]`），将“逢双休/每逢双休/双休日”精准映射至周末（`[1, 7]`），彻底达成用户休息日意图与代码执行的 100% 自洽；
     - **全景时态与防即时误触加固**：扩充“每逢单休开机”、“每逢单休关空调”、“单休日半关机”等全景时态，在 `hasTimingOrCountdownIntent` 中严密封锁，绝不穿透至即时开关机；
     - **单元测试 100% 满分覆盖**：在 `VoiceCommandParserTests.swift` 中新增 `testSingleWeekendAndMultiScheduleHardeningV1994`，包含 16 组全景调度与严苛防即时误触断言，验证全部通过。
  2. **macOS 原生状态栏全屋运行模式协同大一统 (`StatusItemController.swift`)**：
     - **全屋模式协同子菜单**：在状态栏右键系统菜单的全屋协同区域新增「🔄 全屋模式协同」独立子菜单，涵盖制冷（❄️）、制热（🔥）、除湿（💧）、送风（🍃）、自动（🔄）全量工况，直接调用底层 `AppModel.setModeAll(mode:)`；
     - **多设备工况一致性智能感知**：自动统计全屋运行中空调的模式状态，模式相同时动态呈现 `(N台运行中 · 当前制冷)` 并显示 `✓` 选中态，模式不同时动态呈现 `(N台运行中 · 模式不同)`，全屋待机时显示中性禁用与引导 Tooltip，与全屋调温、全屋风速协同达成极致对称。
  3. **静音 0 档原生硬件原语热动力学与气动力学全仓 100% 自洽 (`AppModel.swift` / `EnergyAnalyticsEngine.swift`)**：
     - **补齐汉字“零”原语**：在 `AppModel.filterAccumulationFactor` 与 `EnergyAnalyticsEngine.calculateTheoreticalPower` 中补全 `speed == "零"` 与 `wind == "零"`，使硬件上报为汉字“零”或“零档”时亦能 100% 命中 15W 微风维持态功率与 0.60 滤网低风阻负荷，消除微小偏差。
  4. **Siri 与快捷指令 (`AppIntents.swift`) 全屋电源控制与情景应用全域打通 (`AppIntents.swift`)**：
     - **`SetACPowerIntent` 全屋电源大一统**：支持识别 `deviceName` 中“全”/“所有”关键字，一键批量唤醒 `turnOnAllDevices()` 或关机 `turnOffAllDevices()`，并在单设备场景下输出带设备名称的精致对话反馈；
     - **`ApplyACSceneIntent` 全屋情景支持**：支持通过 `deviceName` 自动识别全屋应用意图，消除通过 Siri 应用全屋情景时的语义断层。

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
   - **逢单休/单休日自然周期调度逻辑脱靶缺陷 (P0/P1)**：`v1.9.93` 在文档中宣称支持逢单休映射至周日，但在 `parseBaseRepeatWeekdays` 中遗漏了独立判断，导致口令直接落入通用的 `if text.contains("单休")`，被反向映射为周一至周六运行（工作日执行、休息日不执行）。本版本补齐了 `逢单休`、`每逢单休`、`单休日` 的前置判定，精确映射至周日（`[1]`），彻底修复该逻辑颠倒缺陷；
   - **状态栏全屋控制矩阵模式协同缺失 (P1/P2)**：右键菜单全屋协同已有全屋升降温、全屋风速协同、全屋开关机，但缺少全屋模式协同。本次基于 `AppModel.setModeAll` 补齐了「🔄 全屋模式协同」子菜单及实时一致性感知；
   - **静音 0 档汉字“零”原语微漏 (P2)**：`EnergyAnalyticsEngine` 与 `AppModel` 滤网动力学中遗漏了 `== "零"` 判断，本次补全后实现全仓 100% 自洽；
   - **Siri / 快捷指令电源与情景控制全屋断层 (P1/P2)**：`SetACPowerIntent` 和 `ApplyACSceneIntent` 此前在设备名称为“全屋”时报错或仅控制单设备，本次全量打通全屋控制流。

---

## 3. 关键架构变更与代码实现

### 3.1 逢单休/单休日与双休循环调度大一统及防即时误触加固
- **`VoiceCommandParser.swift` 前置自然周期识别**：
  ```swift
  // 4.0 逢单休/单休日与逢双休口语调度（逢单休精准映射至周日 [1]，逢双休映射至周末 [1, 7]），前置拦截杜绝误入单休 (v1.9.94)
  if text.contains("逢单休") || text.contains("每逢单休") || text.contains("单休日") {
      return ([1], "周日")
  }
  if text.contains("逢双休") || text.contains("每逢双休") || text.contains("双休日") {
      return ([1, 7], "周末")
  }
  ```
- **`hasTimingOrCountdownIntent` 严密时态防线**：
  全面纳管“每逢单休”、“每逢双休”、“单休日半”等全量口语，杜绝误触立即开关机。

### 3.2 macOS 原生状态栏全屋运行模式协同大一统
- **`StatusItemController.swift` 全屋模式协同子菜单与感知**：
  ```swift
  // 全屋统一模式协同 (v1.9.94)
  let modeMenu = NSMenu()
  modeMenu.autoenablesItems = false
  let modeLevels: [(code: ACModeCode, title: String)] = [
      (.cooling, "❄️ 制冷模式"),
      (.heating, "🔥 制热模式"),
      (.dehumidify, "💧 除湿模式"),
      (.fan, "🍃 送风模式"),
      (.auto, "🔄 自动模式")
  ]
  // 智能感知模式一致性并动态勾选或提示不同
  ```

### 3.3 静音 0 档原生硬件原语全仓 100% 对齐
- **`AppModel.swift` 与 `EnergyAnalyticsEngine.swift`**：
  ```swift
  // 补齐 speed == "零" 与 wind == "零"
  if speed.contains("0档") || speed.contains("零档") || speed == "0" || speed == "零" || ... {
      windFactor = 0.60
  }
  ```

### 3.4 Siri/快捷指令全屋电源与情景应用打通
- **`AppIntents.swift`**：
  ```swift
  // SetACPowerIntent:
  let isAll = (deviceName?.contains("全") == true) || (deviceName?.contains("所有") == true)
  if isAll {
      if powerOn {
          let openedCount = model.turnOnAllDevices()
          return .result(dialog: "已开启全屋 \(openedCount) 台空调")
      } else {
          let closedCount = model.turnOffAllDevices()
          return .result(dialog: "已关闭全屋 \(closedCount) 台运行中的空调")
      }
  }
  ```

---

## 4. 验证与测试结果

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增并校验端到端单元测试用例（16 组断言 100% PASS）：
  - `"逢单休开机"` -> `08:00` 开机，周日循环 (`[1]`) (PASS)
  - `"单休日关机"` -> `08:00` 关机，周日循环 (`[1]`) (PASS)
  - `"每逢单休开机"` -> `08:00` 开机，周日循环 (`[1]`) (PASS)
  - `"每逢单休关空调"` -> `08:00` 关机，周日循环 (`[1]`) (PASS)
  - `"逢单休半开机"` -> `08:30` 开机，周日循环 (`[1]`) (PASS)
  - `"单休日半关机"` -> `08:30` 关机，周日循环 (`[1]`) (PASS)
  - `"每逢双休开机"` -> `08:00` 开机，周末循环 (`[1, 7]`) (PASS)
  - `"双休日关机"` -> `08:00` 关机，周末循环 (`[1, 7]`) (PASS)
  - 严苛防即时误触断言（针对“逢单休开机”、“单休日关机”、“每逢单休开机”、“每逢单休关空调”、“逢单休半开机”、“单休日半关机”、“每逢双休开机”、“双休日关机”，绝对禁止掉入 `setPower`、`turnOffAll` 或 `turnOnAll`，全部 PASS）。
- **编译与打包校验**：
  - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 警告 0 错误编译通过；
  - 运行 `./build_app.sh 1.9.94` 打包生成 `dist/HaierAC-v1.9.94-macOS.zip` (2.8MB)。

---

## 5. 发版信息与资产交付
- **版本号**：`v1.9.94`
- **Git Tag**：`v1.9.94`
- **Release 资产**：`dist/HaierAC-v1.9.94-macOS.zip`
- **SHA-256**：`1e2d32b4f8f2df8299872100c4d27ac56a14b65619b144f2b4b173f6bca7732d`
- **安全敏感数据检查**：经核验，源码与文档均无敏感个人信息、真实 Token 或凭证，符合安全脱敏规范。
