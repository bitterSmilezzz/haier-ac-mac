# Haier AC Mac v1.9.86 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.86`
- **发版主题**：闭环自然口语跨天全时相调度大一统引擎、防即时误触全景加固、未识别工况能耗连续热阻尼与状态栏 Tooltip 100% 盲区清零
- **核心目标与架构演进**：
  1. **跨天高频自然口语调度大一统引擎与防即时误触全景闭环 (`VoiceCommandParser.swift` / `VoiceCapsuleWindowController.swift` / `VoiceCommandParserTests.swift`)**：
     - **跨天高频口语词群全景闭环**：深度纳管“明日”、“隔天”、“后日”、“大后日”、“明儿个”无钟点独立时相（自适应映射为晨间黄金时段 08:00），支持“明日关空调”、“明日开机”、“隔天关空调”、“隔天开机”、“后日关机”、“大后日关机”、“明儿个关空调”等自然跨天调度；
     - **根除跨天口语防误触穿透与即时误关开机重大隐患 (`hasTimingOrCountdownIntent` / `hasTimePhase`)**：修复此前因前置卫语句遗漏“明日”、“隔天”、“后日”、“大后日”、“明儿个”，导致用户口述“明日关空调”或“隔天开机”时被判定为无定时意图，直接穿透至 `isPowerOff` / `isPowerOn` 造成立即误关机/开机的严重故障隐患；
     - **口语半点时相归一流水线全量补全**：在 `convertChineseNumbers` 中新增“明日半”(08:30)、“隔天半”(08:30)、“后日半”(08:30)、“明儿个半”(08:30) 标准化替换，彻底补齐全时相口语表达；
     - **次日/隔日跨天调度全链路对齐 (`VoiceCapsuleWindowController.swift`)**：在单机、全屋与多机定时调度中，将 `isExplicitTomorrow` 全面扩展覆盖“明日”、“隔天”、“明儿个”，将 `isExplicitDayAfter` 扩展覆盖“后日”、“大后日”，杜绝白天口述“明日7点关机”时因未标记次日而错误调度在当天的逻辑漏洞；
     - **单元测试 100% 满分覆盖**：在 `VoiceCommandParserTests.swift` 中新增涵盖明日、隔天、后日、大后日、明儿个单次调度、半点调度、全屋协同调度及 17 组严苛防即时误触断言，全部通过。
  2. **变频压缩机未识别工况恒温平衡区能耗动力学 $C^0$ 级平滑连续热阻尼重构 (`EnergyAnalyticsEngine.swift`)**：
     - **彻底消除 $|ΔT| < 1.0^\circ\text{C}$ 恒温平衡区能耗倒挂与虚标**：此前未识别模式采用冷热均值估算公式 $465.0 + (|ΔT| \times 102.5) + windOffset$，当温差为 0 时估算高达 465W+，不仅远超变频空调恒温低频维持态基准（220W~300W，无偏均值 260W），甚至比温度传感器缺失基准（350W）高出 115W，造成严重的物理失真与能耗倒挂；
     - **双向无偏平滑热阻尼模型引入**：重构未识别模式估算逻辑，在 $|ΔT| \le 0^\circ\text{C}$ 恒温维持区锚定 $260.0\text{W} + windOffset \times 0.6$；在 $0 < |ΔT| < 1.0^\circ\text{C}$ 引入双线性连续动态插值（$windFactor = 0.6 + |ΔT| \times 0.4, P = 260.0 + |ΔT| \times 205.0 + windOffset \times windFactor$），在 $|ΔT| = 1.0$ 处极限严格等于 $465.0\text{W} + windOffset$，达成严密 $C^0$ 级连续平滑，彻底消除虚标。
  3. **macOS 原生状态栏全景控制矩阵 Tooltip 悬浮看板 100% 盲区清零 (`StatusItemController.swift`)**：
     - **全菜单叶子与分支节点 Tooltip 零盲区**：全面补全“打开滤网保养与自清洁面板...”、“当前无生效中的计划任务”（单机与全屋双形态）、“空调设备: xxx”、“下次执行: xxx”、“周期重复: xxx”、“👥 协同设备: xxx”的原生 Tooltip 悬浮说明；
     - 提供丰富的上下文设备归属、精准倒计时与协同调度清单感知，打造极致细腻原生 macOS 交互体验。

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
   - **跨天高频口语防误触穿透与即时误关机重大隐患 (P1)**：由于此前 `hasTimingOrCountdownIntent` 和 `hasTimePhase` 遗漏了“明日”、“隔天”、“后日”、“大后日”、“明儿个”，当用户口述“明日关空调”或“隔天开机”时，由于无钟点未命中传统数字时间，直接跌落至即时开关机 `isPowerOff` / `isPowerOn`，造成空调被立即关闭或开启。本轮将跨天词群全量纳入调度意图防护，彻底根除该隐患；
   - **次日/隔日跨天调度同日覆盖缺陷 (P1)**：`VoiceCapsuleWindowController.swift` 中的 `isExplicitTomorrow` 未涵盖“明日”、“隔天”、“明儿个”，`isExplicitDayAfter` 未涵盖“后日”、“大后日”。当用户在清晨（如 06:00）或前一天白天口述“明日7点关机”时，因当天该钟点尚未过去且未被标记为次日，系统误将其设定为今天清晨 07:00 执行。本轮补齐跨天次日/后日识别链，彻底消除该逻辑漏洞；
   - **未识别工况能耗倒挂与恒温平衡区平滑连续性 (P2)**：此前未识别模式估算缺乏恒温维持区阻尼，导致在温差极小时功耗高达 465W，形成能耗倒挂。本轮重构双线性热阻尼插值模型，达成 $C^0$ 级平滑连续与客观无偏；
   - **状态栏上下文菜单 Tooltip 盲区清零 (P2)**：补齐滤网保养面板入口、空计划任务占位项及单任务调度详细信息项的原生 Tooltip 悬浮说明，实现 100% 盲区清零。

---

## 3. 关键架构变更与代码实现

### 3.1 跨天自然口语大一统调度与防误触全防线
- **`VoiceCommandParser.swift` 广义时相与时区大一统**：
  ```swift
  // hasTimePhase 与 hasTimingOrCountdownIntent 全防线加固
  text.contains("明日") || text.contains("隔天") || text.contains("后日") || text.contains("大后日") || text.contains("明儿个")

  // 无钟点独立时相映射
  } else if normalized.contains("明天") || ... || normalized.contains("明日") || normalized.contains("隔天") ||
             normalized.contains("后日") || normalized.contains("大后日") || normalized.contains("明儿个") {
      hour = 8; minute = 0
  }
  ```

### 3.2 口语半点时相归一流水线补齐
- **`VoiceCommandParser.swift` 中 `convertChineseNumbers` 拓展**：
  ```swift
  str = str.replacingOccurrences(of: "明日半", with: "明日8点30分")
  str = str.replacingOccurrences(of: "隔天半", with: "隔天8点30分")
  str = str.replacingOccurrences(of: "后日半", with: "后日8点30分")
  str = str.replacingOccurrences(of: "明儿个半", with: "明儿个8点30分")
  ```

### 3.3 次日与后日跨天调度全链路对齐
- **`VoiceCapsuleWindowController.swift` 全场景跨天判定增强**：
  ```swift
  let isExplicitTomorrow = spokenText.contains("明天") || ... || spokenText.contains("明日") || spokenText.contains("隔天") || spokenText.contains("明儿个")
  let isExplicitDayAfter = (spokenText.contains("大后天") || spokenText.contains("大后日")) ? 3 : ((spokenText.contains("后天") || spokenText.contains("后日")) ? 2 : 0)
  ```

### 3.4 未识别工况恒温平衡区平滑连续热阻尼动力学重构
- **`EnergyAnalyticsEngine.swift` 双线性连续动态插值**：
  ```swift
  guard let mode = ACModeCode.match(from: modeCode) else {
      if let indoor = indoorTemp, let target = targetTemp {
          let delta = abs(indoor - target)
          let neutralPower: Double
          if delta <= 0.0 {
              neutralPower = 260.0 + (windOffset * 0.6)
          } else if delta < 1.0 {
              let windFactor = 0.6 + (delta * 0.4)
              neutralPower = 260.0 + (delta * 205.0) + (windOffset * windFactor)
          } else {
              neutralPower = 465.0 + ((delta - 1.0) * 102.5) + windOffset
          }
          return min(max(neutralPower, 200.0), 1550.0)
      } else {
          let neutralPower = 350.0 + windOffset
          return min(max(neutralPower, 180.0), 600.0)
      }
  }
  ```

### 3.5 macOS 原生状态栏全景控制矩阵 Tooltip 深度感知
- **`StatusItemController.swift` 盲区清零**：
  - `openCareItem.toolTip = "打开空调滤网健康监测与 56°C 蒸发器高温除菌自清洁保养管理面板"`；
  - `emptyItem.toolTip = "「\(dev.name)」名下当前暂无正在生效或暂停的计划调度任务"`；
  - `noScheduleInfo.toolTip = "当前全屋各空调均无正在生效或暂停的计划调度与倒计时任务"`；
  - `devInfoItem` / `timeInfo` / `repInfo` / `infoItem` 全量补齐 Tooltip 悬浮看板。

---

## 4. 自动化测试与验证

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增并校验端到端单元测试用例：
  - `"明日关空调"` -> `08:00` 关机 (PASS)
  - `"明日开机"` -> `08:00` 开机 (PASS)
  - `"明日半关机"` -> `08:30` 关机 (PASS)
  - `"明日7点关空调"` -> `07:00` 关机 (PASS)
  - `"隔天关空调"` -> `08:00` 关机 (PASS)
  - `"隔天开机"` -> `08:00` 开机 (PASS)
  - `"隔天半开机"` -> `08:30` 开机 (PASS)
  - `"后日关空调"` -> `08:00` 关机 (PASS)
  - `"后日开机"` -> `08:00` 开机 (PASS)
  - `"后日半关机"` -> `08:30` 关机 (PASS)
  - `"大后日关机"` -> `08:00` 关机 (PASS)
  - `"明儿个关机"` -> `08:00` 关机 (PASS)
  - `"明儿个半开机"` -> `08:30` 开机 (PASS)
  - `"全屋明日关空调"` -> `08:00` 关机 (PASS)
  - `"全屋隔天关空调"` -> `08:00` 关机 (PASS)
  - `"全屋后日关空调"` -> `08:00` 关机 (PASS)
  - 严苛防即时误触断言（17 组全覆盖，绝对禁止掉入 `setPower`、`turnOffAll` 或 `turnOnAll`，全部 PASS）。
- **编译与打包校验**：
  - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 错误编译通过；
  - 运行 `./build_app.sh 1.9.86` 打包生成 `dist/HaierAC-v1.9.86-macOS.zip` (2.8MB)。

---

## 5. 发版信息与资产交付
- **版本号**：`v1.9.86`
- **Git Tag**：`v1.9.86`
- **Release 资产**：`dist/HaierAC-v1.9.86-macOS.zip`
- **SHA-256**：`bbd5ffe7024468f1919f551cb1841e41961232fc4901164390accde72edfc1ee`
- **安全敏感数据检查**：经核验，源码与文档均无敏感个人信息、真实 Token 或凭证，符合安全脱敏规范。
