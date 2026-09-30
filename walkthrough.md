# Haier AC Mac v1.9.89 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.89`
- **发版主题**：闭环自然口语循环调度大一统引擎、防即时误触全景加固、滤网动力学与状态栏多设备监控全域对齐
- **核心目标与架构演进**：
  1. **“每天/工作日/周末/双休/单休”全时相循环调度大一统引擎与防即时误触全闭环 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **彻底解决无钟点循环定时口语被解析器拦截丢弃的重大缺陷**：此前用户说“工作日关空调”、“工作日开机”、“周末关空调”、“周末开机”、“双休关机”、“单休关空调”、“每天关空调”、“天天关机”、“每日开机”、“全屋工作日关空调”、“全屋每天关空调”等高频日常调度时，因未显式提及具体钟点，`parseScheduleTime` 无法识别，导致整个口令解析失败返回 `nil`，界面提示“未识别到有效的控制指令”；本版本在 `parseScheduleTime` 的 `hasTimePhase` 中纳管“每天/天天/每日/日日/工作日/平时/周末/双休/单休”及 `parseRepeatWeekdays(normalized) != nil`，在独立时相体系中将其默认时相基准对齐至 `08:00`，使所有独立循环调度自然口语无缝映射为 `.scheduleRepeatPower` 循环任务；
     - **高频循环口语半点时相归一流水线全量补齐 (`convertChineseNumbers`)**：新增“工作日半”(工作日8点30分)、“平时半”(平时8点30分)、“周末半”(周末8点30分)、“双休半”(双休8点30分)、“单休半”(单休8点30分)、“每天半”(每天8点30分)、“天天半”(天天8点30分)、“每日半”(每日8点30分)、“日日半”(日日8点30分) 标准化映射；
     - **全景防即时误触语义防线加固 (`hasTimingOrCountdownIntent`)**：补齐“单休”、“平时”、“日日”、“每天半”、“天天半”、“每日半”、“工作日半”、“周末半”、“双休半”、“单休半”等显式防线，杜绝任何循环调度指令掉入 `setPower(false/true)` 或 `turnOffAll/turnOnAll` 即时开关机；
     - **单元测试 100% 满分覆盖**：在 `VoiceCommandParserTests.swift` 中新增 `testRepeatSchedulePrecisionAndProtectionV1989`，包含 17 组单机与全屋循环调度、半点归一及严苛防即时误触断言，全部通过。
  2. **滤网动力学与状态栏多设备监控全域对齐 (`AppModel.swift` / `StatusItemController.swift`)**：
     - **消除状态栏滤网监控盲区**：在 `StatusItemController.setup()` 的 `Publishers.MergeMany` 中补齐 `model.$deviceFilterMinutes`，确保任何子设备或非主控设备的滤网机时累加、保养或重置时，状态栏悬浮 Tooltip 的低洁净度警报与全屋概览即时无感刷新；
     - **全局最低滤网清洁度对齐统一设备模型**：`AppModel.filterCleanlinessPercentage` 改用 `allUnifiedDevices.map(\.id)`，杜绝 `devices` 与 `manualDevices` 重复计算或不同步风险；
     - **原生硬件自动风速原语纳管**：在 `AppModel.normalizeWindSpeed` 与 `StatusItemController.formatDisplayWindSpeed` 中纳管 `gear0`、`gear_0`、`level0`、`level_0`、`speed0`、`speed_0` 原语映射至“自动/自动风”，消除特定机型在自动风速下的展示与识别回退偏差；
     - **macOS 状态栏右键菜单与 Tooltip 细节打磨**：全景对齐全屋调度任务展示看板与悬浮提示。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下最新的审查报告（`2026-09-24-1426.md`）及后续演进进行了全景走查与深度代码复核：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 正则模型稳定运行，允许 0~10 个任意字符穿插，彻底解决插字绕过缺陷；
   - **全屋与定向定时解耦 (P1-2)**：`cancelSchedules` 与 `cancelSchedulesAll` 精确分流，多设备批量取消分支全部贯通；
   - **工况占比计算属性消费 (P2-1)**：`EcoEnergySection` 已统一调用 4 个比率属性；
   - **死分支清理 (P2-2)**：`.adjustTemperatureAll` 死分支已彻底清理；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **无钟点日常循环口语被解析器拦截丢弃的重大缺陷 (P1)**：用户习惯说“工作日关空调”、“周末关机”、“每天关空调”、“全屋工作日关机”等高频口语。此前由于未说出具体钟点，`parseScheduleTime` 无法识别时间，导致直接丢弃返回 `nil`，界面报错“未识别到有效的控制指令”。本版本将所有循环词组纳入时相归一基准，默认映射至早 08:00，彻底打通口语循环调度闭环；
   - **循环时相半点归一流水线与即时误触穿透 (P1)**：口语“工作日半”、“周末半”、“每天半”等半点表达在 `convertChineseNumbers` 中补齐为 `08:30`，并在 `hasTimingOrCountdownIntent` 中加固防线，确保绝不误触发立即开关机；
   - **状态栏滤网更新感知盲区与设备列表不一致风险 (P2)**：状态栏监控只订阅了主设备或前台变化，缺少对 `deviceFilterMinutes` 字典的直接订阅；同时 `filterCleanlinessPercentage` 遍历分散的 `devices + manualDevices` 存在重复与状态脱节可能。本轮全部重构对齐至 `allUnifiedDevices` 并将 Combine 订阅贯通。

---

## 3. 关键架构变更与代码实现

### 3.1 循环口语独立时相纳管与默认基准
- **`VoiceCommandParser.swift` 时相判定与提取**：
  ```swift
  let hasTimePhase = ... || normalized.contains("每天") || normalized.contains("天天") ||
                     normalized.contains("每日") || normalized.contains("日日") ||
                     normalized.contains("工作日") || normalized.contains("平时") ||
                     normalized.contains("周末") || normalized.contains("双休") ||
                     normalized.contains("单休") || parseRepeatWeekdays(normalized) != nil
  ```
  在独立时相分支中对齐基准：
  ```swift
  } else if ... || normalized.contains("每天") || normalized.contains("天天") ||
             normalized.contains("每日") || normalized.contains("日日") ||
             normalized.contains("工作日") || normalized.contains("平时") ||
             normalized.contains("周末") || normalized.contains("双休") ||
             normalized.contains("单休") || parseRepeatWeekdays(normalized) != nil {
      hour = 8
      minute = 0
  }
  ```

### 3.2 循环半点时相归一流水线
- **`VoiceCommandParser.swift` 中 `convertChineseNumbers` 拓展**：
  ```swift
  str = str.replacingOccurrences(of: "工作日半", with: "工作日8点30分")
  str = str.replacingOccurrences(of: "平时半", with: "平时8点30分")
  str = str.replacingOccurrences(of: "周末半", with: "周末8点30分")
  str = str.replacingOccurrences(of: "双休半", with: "双休8点30分")
  str = str.replacingOccurrences(of: "单休半", with: "单休8点30分")
  str = str.replacingOccurrences(of: "每天半", with: "每天8点30分")
  str = str.replacingOccurrences(of: "天天半", with: "天天8点30分")
  str = str.replacingOccurrences(of: "每日半", with: "每日8点30分")
  str = str.replacingOccurrences(of: "日日半", with: "日日8点30分")
  ```

### 3.3 全景防即时误触语义加固
- **`VoiceCommandParser.swift` 前置语义防线**：
  ```swift
  text.contains("单休") || text.contains("平时") || text.contains("日日") ||
  text.contains("每天半") || text.contains("天天半") || text.contains("每日半") ||
  text.contains("工作日半") || text.contains("周末半") || text.contains("双休半") || text.contains("单休半")
  ```

### 3.4 滤网动力学与状态栏多设备监控全域对齐
- **`AppModel.swift` 统一设备清洁度计算**：
  ```swift
  var filterCleanlinessPercentage: Double {
      let allIds = allUnifiedDevices.map(\.id)
      if allIds.isEmpty { return 1.0 }
      let minPct = allIds.map { filterCleanlinessPercentage(for: $0) }.min() ?? 1.0
      return minPct
  }
  ```
- **`StatusItemController.swift` Combine 状态订阅与风速原语**：
  ```swift
  Publishers.MergeMany(
      ...
      model.$deviceFilterMinutes.map { _ in () }.eraseToAnyPublisher()
  )
  ```
  在 `formatDisplayWindSpeed` 与 `AppModel.normalizeWindSpeed` 中纳管 `gear0`、`gear_0`、`level0`、`level_0`、`speed0`、`speed_0` 为“自动”。

---

## 4. 验证与测试结果

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增并校验端到端单元测试用例（17 组断言 100% PASS）：
  - `"工作日关空调"` -> `08:00` 关机，周一至周五循环 (PASS)
  - `"工作日开机"` -> `08:00` 开机，周一至周五循环 (PASS)
  - `"工作日半关空调"` -> `08:30` 关机，周一至周五循环 (PASS)
  - `"平时半开机"` -> `08:30` 开机，周一至周五循环 (PASS)
  - `"周末关机"` -> `08:00` 关机，周六周日循环 (PASS)
  - `"周末半开空调"` -> `08:30` 开机，周六周日循环 (PASS)
  - `"双休关空调"` -> `08:00` 关机，周六周日循环 (PASS)
  - `"双休半开机"` -> `08:30` 开机，周六周日循环 (PASS)
  - `"单休关空调"` -> `08:00` 关机，周日循环 (PASS)
  - `"单休半开机"` -> `08:30` 开机，周日循环 (PASS)
  - `"每天关空调"` -> `08:00` 关机，每天循环 (PASS)
  - `"天天开机"` -> `08:00` 开机，每天循环 (PASS)
  - `"每天半关空调"` -> `08:30` 关机，每天循环 (PASS)
  - `"全屋工作日关空调"` -> `08:00` 全屋关机，周一至周五循环 (PASS)
  - `"全屋每天关空调"` -> `08:00` 全屋关机，每天循环 (PASS)
  - 严苛防即时误触断言（针对“工作日关空调”与“每天关空调”，绝对禁止掉入 `setPower`、`turnOffAll` 或 `turnOnAll`，全部 PASS）。
- **编译与打包校验**：
  - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 错误编译通过；
  - 运行 `./build_app.sh 1.9.89` 打包生成 `dist/HaierAC-v1.9.89-macOS.zip` (2.8MB)。

---

## 5. 发版信息与资产交付
- **版本号**：`v1.9.89`
- **Git Tag**：`v1.9.89`
- **Release 资产**：`dist/HaierAC-v1.9.89-macOS.zip`
- **SHA-256**：`fd609a43e51aef7f2967dcbb1c501dd7d32074ace50c4054b4f9185c3198854f`
- **安全敏感数据检查**：经核验，源码与文档均无敏感个人信息、真实 Token 或凭证，符合安全脱敏规范。
