# Haier AC Mac v1.9.87 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.87`
- **发版主题**：闭环自然口语全景调度大一统反馈、次日顺延智能明示、除湿工况能耗 C^0 级平滑热阻尼与原生硬件风速原语感知
- **核心目标与架构演进**：
  1. **跨天自然口语大一统调度反馈与半点归一闭环 (`VoiceCommandParser.swift` / `VoiceCapsuleWindowController.swift` / `VoiceCommandParserTests.swift`)**：
     - **补全 `dayDesc` 跨天日期前缀缺失重大体验断层**：深度补齐 `"大后天"`、`"大后日"`、`"后天"`、`"后日"`、`"后儿个"`、`"明天"`、`"明早"`、`"明晚"`、`"明日"`、`"隔天"`、`"明儿个"`、`"今天"`、`"今日"`、`"今晚"`、`"今晨"`、`"今儿"`、`"今儿个"` 全量口语前缀，彻底根除此前口述“明日7点关空调”但胶囊弹窗与反馈文案仅显示“定时在 07:00 关机”遗漏跨天日期前缀的历史缺陷，现精准对齐为“定时在 明天 07:00 关机”、“定时在 后天 08:00 关机”等；
     - **高频口语半点时相归一流水线全量补全**：在 `convertChineseNumbers` 中新增“明天半”(08:30)、“后天半”(08:30)、“大后天半”(08:30)、“大后日半”(08:30)、“今天半”(08:30)、“今日半”(08:30)、“今儿个半”(08:30)、“后儿个半”(08:30) 标准化映射，彻底补齐全时相口语表达；
     - **全景防即时误触防线加固 (`hasTimingOrCountdownIntent` / `hasTimePhase` / `parseScheduleTime`)**：将“后儿个”、“今儿”、“今儿个”全量注入前置语义防护，彻底杜绝方言口语调度穿透至 `isPowerOff` / `isPowerOn` 造成立即误关机/开机的安全缺陷；
     - **跨天调度全链路与胶囊反馈对齐 (`VoiceCapsuleWindowController.swift`)**：在多设备、单设备、全屋三处 `schedulePower` 调度逻辑中，将 `isExplicitDayAfter` 覆盖“后儿个”，`isExplicitToday` 覆盖“今天”/“今日”/“今儿个”；并引入**次日顺延智能明示机制**，当设定的时间已在过去被系统顺延至次日时，`dayPrefix` 自动明示为“明天 ”，向用户清晰展示确切执行时点；
     - **单元测试 100% 满分覆盖**：在 `VoiceCommandParserTests.swift` 中新增 `testCrossDayAndColloquialTimingPrecisionV1987`，涵盖半点时相归一、dayDesc 日期前缀精准对齐及 10 组严苛防即时误触断言，全部通过。
  2. **变频压缩机除湿工况能耗动力学 $C^0$ 级平滑连续热阻尼重构 (`EnergyAnalyticsEngine.swift`)**：
     - **消除除湿工况湿度临界点阶跃断崖**：在 `estimateInstantaneousPower` 中，此前除湿模式在 55% RH 处功耗从 320W 跳跃至 380W (Δ=60W)，在 70% RH 处从 500W 跳跃至 520W (Δ=20W)，产生非物理瞬态阶跃断崖；
     - **双线性平滑动态阻尼插值模型引入**：重构除湿能耗动力学曲线，在 $< 50\%$ RH 维持 260~340W 线性过渡，在 $50\% \sim 70\%$ RH 引入动态热阻尼连续插值（$P = 340.0 + \frac{\text{rh} - 50.0}{20.0} \times 180.0$），在 $\ge 70\%$ RH 锚定 $520.0\text{W} + (\text{rh} - 70.0) \times 4.0$，达成左极限严格等于右极限的 $C^0$ 级全域平滑连续，与热力学潜热负荷完美自洽。
  3. **状态栏与应用模型原生硬件风速原语全量纳管 (`AppModel.swift` / `StatusItemController.swift`)**：
     - **全量纳管原生硬件风速枚举原语**：在 `AppModel.normalizeWindSpeed` 与 `StatusItemController.formatDisplayWindSpeed` 中，全面纳管 `level1~5`、`speed1~5`、`gear1~5` 以及全量大小写英文原语（low/mid/high/mute/turbo/quiet 等），彻底消除部分机型上报原生代码时展示为硬件原始字符串或回退失真的问题。

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
   - **跨天口语定时反馈日期前缀缺失体验断层 (P1)**：口述“明日7点关空调”或“后天8点关机”时，调度底层已计算为次日或后日，但反馈文案仅显示“定时在 07:00 关机”，未携带任何日期提示；且当用户设置过去的时间被系统顺延至次日时，反馈文案同样缺乏“明天”明示。本轮将全量跨天与日常日期词注入 `dayDesc`，并在自动顺延分支加入明示标签；
   - **口语半点时相归一覆盖盲区 (P1)**：“明天半”、“后天半”、“大后天半”、“今天半”、“今儿个半”等口语在数字转换层缺失映射，容易被拆解为字面量而丢失半点时相。本轮将全量跨天半点词群映射至 `08:30`；
   - **方言口语防误触穿透 (P1)**：“后儿个”、“今儿”、“今儿个”全量注入前置语义防护，彻底杜绝方言口语调度穿透至立即开关机；
   - **除湿工况能耗曲线阶跃断崖 (P2)**：此前在 55% RH 和 70% RH 存在 60W 和 20W 的跳跃断崖，本轮重构为双线性连续动态阻尼模型，达成严密 $C^0$ 级连续平滑；
   - **硬件风速原语兼容 (P2)**：纳管部分新老机型上报的 `level1~5`、`gear1~5`、`speed1~5` 等原生硬件枚举。

---

## 3. 关键架构变更与代码实现

### 3.1 跨天日期前缀与全场景口语反馈大一统
- **`VoiceCommandParser.swift` 跨天日期前缀解析**：
  ```swift
  var dayDesc = ""
  if lower.contains("大后天") || lower.contains("大后日") {
      dayDesc = "大后天 "
  } else if lower.contains("后天") || lower.contains("后日") || lower.contains("后儿个") {
      dayDesc = "后天 "
  } else if lower.contains("明天") || lower.contains("明早") || lower.contains("明晚") || lower.contains("明日") || lower.contains("隔天") || lower.contains("明儿个") {
      dayDesc = "明天 "
  } else if lower.contains("今天") || lower.contains("今日") || lower.contains("今晚") || lower.contains("今晨") || lower.contains("今儿") || lower.contains("今儿个") {
      dayDesc = "今天 "
  }
  ```

### 3.2 跨天半点时相归一流水线全量补全
- **`VoiceCommandParser.swift` 中 `convertChineseNumbers` 拓展**：
  ```swift
  str = str.replacingOccurrences(of: "明天半", with: "明天8点30分")
  str = str.replacingOccurrences(of: "后天半", with: "后天8点30分")
  str = str.replacingOccurrences(of: "大后天半", with: "大后天8点30分")
  str = str.replacingOccurrences(of: "大后日半", with: "大后日8点30分")
  str = str.replacingOccurrences(of: "今天半", with: "今天8点30分")
  str = str.replacingOccurrences(of: "今日半", with: "今日8点30分")
  str = str.replacingOccurrences(of: "今儿个半", with: "今儿个8点30分")
  str = str.replacingOccurrences(of: "后儿个半", with: "后儿个8点30分")
  ```

### 3.3 次日顺延智能明示与跨天识别
- **`VoiceCapsuleWindowController.swift` 全场景跨天判定与文案生成**：
  ```swift
  if fireDate <= now && isExplicitToday {
      // 显式指定今天但时间已过
  } else if fireDate <= now {
      fireDate = calendar.date(byAdding: .day, value: 1, to: fireDate) ?? fireDate
      if dayPrefix.isEmpty {
          dayPrefix = "明天 "
      }
  }
  ```

### 3.4 除湿工况能耗动力学 $C^0$ 级平滑连续热阻尼重构
- **`EnergyAnalyticsEngine.swift` 双线性连续动态插值**：
  ```swift
  case .dehumidify:
      let rh = Double(humidity ?? 60)
      let baseDehum: Double
      if rh < 50.0 {
          let factor = max(0.0, rh / 50.0)
          baseDehum = 260.0 + (factor * 80.0)
      } else if rh <= 70.0 {
          let ratio = (rh - 50.0) / 20.0
          baseDehum = 340.0 + (ratio * 180.0)
      } else {
          baseDehum = 520.0 + ((rh - 70.0) * 4.0)
      }
      return min(max(baseDehum + (windOffset * 0.5), 180.0), 950.0)
  ```

### 3.5 原生硬件风速原语全量纳管
- **`AppModel.swift` & `StatusItemController.swift` 映射增强**：
  ```swift
  if lower == "level1" || lower == "gear1" || lower == "speed1" { return "微风" }
  if lower == "level2" || lower == "gear2" || lower == "speed2" { return "中风" }
  if lower == "level3" || lower == "gear3" || lower == "speed3" || lower == "level4" || lower == "gear4" || lower == "speed4" || lower == "level5" || lower == "gear5" || lower == "speed5" { return "强劲" }
  ```

---

## 4. 自动化测试与验证

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增并校验端到端单元测试用例：
  - `"明天半关空调"` -> `08:30` 关机，前缀 `"明天 "` (PASS)
  - `"后天半关机"` -> `08:30` 关机，前缀 `"后天 "` (PASS)
  - `"大后天半关空调"` -> `08:30` 关机，前缀 `"大后天 "` (PASS)
  - `"今天半关空调"` -> `08:30` 关机，前缀 `"今天 "` (PASS)
  - `"今儿个半关空调"` -> `08:30` 关机，前缀 `"今天 "` (PASS)
  - `"后儿个关机"` -> `08:00` 关机，前缀 `"后天 "` (PASS)
  - `"明日7点关空调"` -> `07:00` 关机，前缀 `"明天 "` (PASS)
  - 严苛防即时误触断言（10 组全覆盖，绝对禁止掉入 `setPower`、`turnOffAll` 或 `turnOnAll`，全部 PASS）。
- **编译与打包校验**：
  - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 错误编译通过；
  - 运行 `./build_app.sh 1.9.87` 打包生成 `dist/HaierAC-v1.9.87-macOS.zip` (2.8MB)。

---

## 5. 发版信息与资产交付
- **版本号**：`v1.9.87`
- **Git Tag**：`v1.9.87`
- **Release 资产**：`dist/HaierAC-v1.9.87-macOS.zip`
- **SHA-256**：`0788f9c2f70d3a4b703581bd1c9f5025fdd611d3ccc8d390c997aa03e60332f4`
- **安全敏感数据检查**：经核验，源码与文档均无敏感个人信息、真实 Token 或凭证，符合安全脱敏规范。
