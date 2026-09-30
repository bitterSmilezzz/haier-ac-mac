# Haier AC Mac v1.9.88 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.88`
- **发版主题**：闭环自然口语全时相调度大一统引擎、防即时误触全景加固、滤网与能耗动力学原生硬件风速原语 100% 深度对齐
- **核心目标与架构演进**：
  1. **当日与跨天口语全时相大一统引擎与防即时误触全闭环 (`VoiceCommandParser.swift` / `VoiceCapsuleWindowController.swift` / `VoiceCommandParserTests.swift`)**：
     - **根除“今天/今日/后儿/大后儿”防误触穿透与即时误关开机重大隐患 (`hasTimingOrCountdownIntent`)**：此前前置防护中虽涵盖明日、隔天、后日等，却唯独遗漏最常用的“今天”、“今日”以及口语两字形态“后儿”、“大后儿”，导致用户说“今天关空调”或“今日关机”时被判定为无定时意图，直接穿透至 `isPowerOff` / `turnOffAll` 造成全屋立即误关机；本版本完成严密补齐，坚固防线；
     - **独立无钟点时相口语表达全域纳管 (`hasTimePhase` / `parseScheduleTime`)**：将“今天”、“今日”、“今儿”、“今儿个”、“后儿”、“大后儿”、“大后儿个”纳入独立时相体系（自适应映射至 08:00），支持“今天关空调”、“今日开机”、“后儿关机”、“大后儿个开机”等丰富口语；
     - **口语两字形态半点归一流水线补全 (`convertChineseNumbers`)**：新增“明儿半”(08:30)、“今儿半”(08:30)、“后儿半”(08:30)、“大后儿半”(08:30)、“大后儿个半”(08:30) 等口语标准化映射；
     - **跨天调度全链路与胶囊反馈闭环 (`VoiceCapsuleWindowController.swift`)**：在单机、多机与全屋调度中，将 `isExplicitDayAfter` 全面扩展覆盖“后儿”、“大后儿”、“大后儿个”，胶囊反馈文案与顺延前缀精准对齐；
     - **单元测试 100% 满分覆盖**：在 `VoiceCommandParserTests.swift` 中新增 `testCrossDayAndColloquialTimingPrecisionV1988`，包含 19 组覆盖半点归一、独立时相调度与严苛防即时误触断言，全部通过。
  2. **滤网动力学、瞬时能耗与状态栏原生硬件风速原语 100% 全域深度对齐 (`AppModel.swift` / `EnergyAnalyticsEngine.swift` / `StatusItemController.swift`)**：
     - **闭环 `gear1~5` 与 `gear_1~gear_5` 硬件风速原语**：此前虽在部分注释中声明支持，但底层判断中遗漏 gear 原语，导致海尔/卡萨帝机型上报 gear 格式风速时，在 `AppModel.normalizeWindSpeed` 中无法准确匹配；现完成 `gear1~5`、`gear_1~gear_5` 全量映射；
     - **能耗动力学风机电动力学校准对齐 (`EnergyAnalyticsEngine.swift`)**：在 `estimateInstantaneousPower` 中，将 `windOffset` 全面纳管 `level_1~5`、`level1~5`、`speed_1~5`、`speed1~5`、`gear_1~5`、`gear1~5`，确保硬件原语下精准输出 15W~180W 阶梯功率，杜绝回退至自动风速模型的虚标偏差；
     - **滤网空气动力学负荷系数对齐 (`AppModel.swift`)**：在 `calculateFilterWearFactor` 中，将 `windFactor` 全面纳管 `level`、`speed`、`gear` 原语，保证滤网磨损衰减估算准确自洽；
     - **macOS 状态栏风速感知盲区消除 (`StatusItemController.swift`)**：在 `formatDisplayWindSpeed` 中补全 gear 原语，确保顶层概览与二级菜单准确显示“微风”、“低风”、“中风”、“高风”、“强劲风”、“暴风”。

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
   - **“今天/今日/后儿/大后儿”防误触穿透与即时误关开机重大隐患 (P1)**：前置防护卫语句此前虽然覆盖了明日、隔天、后日等，却遗漏了书面与日常最高频的“今天”、“今日”以及口语两字形态“后儿”、“大后儿”，导致用户说“今天关空调”或“今日关机”时因未识别到定时意图，直接掉入 `isPowerOff` / `turnOffAll` 即时关机分支造成全屋误关机。本轮全面加固该防线，彻底消除漏洞；
   - **原生硬件风速原语 `gear` 与动力学对齐缺失 (P1)**：海尔智能家居生态中，部分高端卡萨帝机型上报风速为 `gear1`~`gear5` 或 `gear_1`~`gear_5`。此前在 `AppModel.normalizeWindSpeed`、`calculateFilterWearFactor`、`EnergyAnalyticsEngine.estimateInstantaneousPower` 以及 `StatusItemController.formatDisplayWindSpeed` 中未全域纳管，导致风速识别与展示回退至自动风速、瞬时电功率和滤网负荷因偏差失真。本轮实现 100% 全域对齐；
   - **口语两字形态半点归一流水线补全 (P2)**：“明儿半”、“今儿半”、“后儿半”、“大后儿半”、“大后儿个半”在自然语言归一中缺失，本轮补齐映射为 `08:30`；
   - **跨天调度上下文胶囊反馈对齐 (P2)**：多设备、单设备、全屋三处 `schedulePower` 全面支持“后儿”、“大后儿”、“大后儿个”跨天判定与 `dayDesc` 前缀展示。

---

## 3. 关键架构变更与代码实现

### 3.1 自然口语防即时误触与独立时相大一统
- **`VoiceCommandParser.swift` 前置语义防线全景加固**：
  ```swift
  text.contains("后儿个") || text.contains("后儿") || text.contains("大后儿") || text.contains("大后儿个") ||
  text.contains("后日半") || text.contains("大后日半") ||
  text.contains("今天") || text.contains("今日") || text.contains("今儿") || text.contains("今儿个")
  ```
- **独立无钟点时相口语表达全域纳管**：
  ```swift
  } else if normalized.contains("明天") || normalized.contains("后天") || normalized.contains("大后天") ||
             normalized.contains("次日") || normalized.contains("隔日") || normalized.contains("翌日") ||
             normalized.contains("明儿") || normalized.contains("明日") || normalized.contains("隔天") ||
             normalized.contains("后日") || normalized.contains("大后日") || normalized.contains("明儿个") ||
             normalized.contains("后儿个") || normalized.contains("后儿") ||
             normalized.contains("大后儿") || normalized.contains("大后儿个") ||
             normalized.contains("今天") || normalized.contains("今日") ||
             normalized.contains("今儿") || normalized.contains("今儿个") {
      hour = 8
      minute = 0
  }
  ```

### 3.2 口语两字形态半点时相归一流水线补齐
- **`VoiceCommandParser.swift` 中 `convertChineseNumbers` 拓展**：
  ```swift
  str = str.replacingOccurrences(of: "后儿个半", with: "后儿个8点30分")
  str = str.replacingOccurrences(of: "后儿半", with: "后儿8点30分")
  str = str.replacingOccurrences(of: "明儿个半", with: "明儿个8点30分")
  str = str.replacingOccurrences(of: "明儿半", with: "明儿8点30分")
  str = str.replacingOccurrences(of: "今儿半", with: "今儿8点30分")
  str = str.replacingOccurrences(of: "大后儿半", with: "大后儿8点30分")
  str = str.replacingOccurrences(of: "大后儿个半", with: "大后儿个8点30分")
  ```

### 3.3 跨天判定与胶囊反馈闭环
- **`VoiceCapsuleWindowController.swift` 全场景跨天判定**：
  ```swift
  let isExplicitDayAfter = (spokenText.contains("大后天") || spokenText.contains("大后日") || spokenText.contains("大后儿") || spokenText.contains("大后儿个")) ? 3 : ((spokenText.contains("后天") || spokenText.contains("后日") || spokenText.contains("后儿") || spokenText.contains("后儿个")) ? 2 : 0)
  ```

### 3.4 原生硬件风速原语 `gear/level/speed` 100% 全域纳管
- **`AppModel.swift` 滤网空气动力学负荷系数与风速归一化**：
  ```swift
  if speed.contains("暴") || ... || speed.contains("gear5") || speed.contains("gear_5") { windFactor = 1.85 }
  else if speed.contains("强") || ... || speed.contains("gear4") || speed.contains("gear_4") { windFactor = 1.50 }
  else if speed.contains("高") || ... || speed.contains("gear3") || speed.contains("gear_3") { windFactor = 1.35 }
  else if speed.contains("中") || ... || speed.contains("gear2") || speed.contains("gear_2") { windFactor = 1.00 }
  else if speed.contains("低") || ... || speed.contains("gear1") || speed.contains("gear_1") { windFactor = 0.80 }
  ```
- **`EnergyAnalyticsEngine.swift` 风机电动力学瞬时功率阶梯校准**：
  全面对齐 `gear_1~5` 与 `gear1~5`，阶梯输出 15W~180W 功耗。
- **`StatusItemController.swift` 状态栏风速映射**：
  在 `formatDisplayWindSpeed` 中纳管 `gear_1~5` 与 `gear1~5`。

---

## 4. 验证与测试结果

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增并校验端到端单元测试用例（19 组断言 100% PASS）：
  - `"明儿半开机"` -> `08:30` 开机，前缀 `"明天 "` (PASS)
  - `"今儿半关机"` -> `08:30` 关机，前缀 `"今天 "` (PASS)
  - `"后儿半开机"` -> `08:30` 开机，前缀 `"后天 "` (PASS)
  - `"大后儿半关机"` -> `08:30` 关机，前缀 `"大后天 "` (PASS)
  - `"大后儿个半开机"` -> `08:30` 开机，前缀 `"大后天 "` (PASS)
  - `"后儿关机"` -> `08:00` 关机，前缀 `"后天 "` (PASS)
  - `"大后儿个开机"` -> `08:00` 开机，前缀 `"大后天 "` (PASS)
  - `"今天关空调"` -> `08:00` 关机，前缀 `"今天 "` (PASS)
  - `"今日开机"` -> `08:00` 开机，前缀 `"今天 "` (PASS)
  - `"全屋今天关空调"` -> `08:00` 关机，前缀 `"今天 "` (PASS)
  - `"全屋今日开机"` -> `08:00` 开机，前缀 `"今天 "` (PASS)
  - 严苛防即时误触断言（10 组全覆盖，绝对禁止掉入 `setPower`、`turnOffAll` 或 `turnOnAll`，全部 PASS）。
- **编译与打包校验**：
  - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 错误编译通过；
  - 运行 `./build_app.sh 1.9.88` 打包生成 `dist/HaierAC-v1.9.88-macOS.zip` (2.9MB)。

---

## 5. 发版信息与资产交付
- **版本号**：`v1.9.88`
- **Git Tag**：`v1.9.88`
- **Release 资产**：`dist/HaierAC-v1.9.88-macOS.zip`
- **SHA-256**：`11527029308ec203054ca83856f317aa6868b2b9827b3cb24cd0454da8df8ed6`
- **安全敏感数据检查**：经核验，源码与文档均无敏感个人信息、真实 Token 或凭证，符合安全脱敏规范。
