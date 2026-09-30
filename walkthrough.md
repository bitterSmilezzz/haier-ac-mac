# Haier AC Mac v1.9.85 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.85`
- **发版主题**：闭环自然口语晨间与夜半全时相大一统引擎、防即时误触全景加固与变频动力学平滑连续阻尼重构
- **核心目标与架构演进**：
  1. **自然口语晨间与古雅夜半独立时相调度大一统引擎与防即时误触全景闭环 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **晨间与古雅夜半高频口语词群全景闭环**：深度纳管“今晨”、“明晨”、“每晨”、“次晨”、“翌晨”（自适应映射为晨间黄金时段 07:00）以及“夜半”（经典午夜映射为 00:00），支持“今晨关空调”、“明晨关空调”、“明晨开机”、“每晨关空调”、“次晨关空调”、“翌晨开机”、“夜半关空调”、“夜半开机”等自然日常调度；
     - **根除晨间与夜半口语防误触穿透与即时误关开机重大隐患 (`hasTimingOrCountdownIntent` / `hasTimePhase`)**：修复此前因卫语句遗漏“今晨”、“明晨”、“每晨”、“次晨”、“翌晨”、“夜半”，导致用户说“明晨关空调”或“夜半开机”时被判定为无定时意图，直接穿透至 `isPowerOff` / `isPowerOn` 造成立即误关机/开机的严重故障隐患；
     - **口语半点时相归一流水线全量补全**：在 `convertChineseNumbers` 中新增“今晨半”(07:30)、“明晨半”(07:30)、“每晨半”(07:30)、“次晨半”(07:30)、“翌晨半”(07:30)、“每早半”(07:30)、“每晚半”(21:30) 及“夜半半”(00:30) 标准化替换，彻底补齐全时相口语表达；
     - **夜半时钟消歧与时态校准**：将“夜半”纳入 `isNightMidnight`（“夜半12点”=00:00）与 `isNocturnal`（“夜半1点”=01:00、“夜半10点”=22:00），消除深宵时区计算错位；
     - **次日跨天调度全链路对齐 (`VoiceCapsuleWindowController.swift`)**：在单机、全屋与多机定时调度中，将 `isExplicitTomorrow` 全面扩展覆盖“明晨”、“次晨”、“翌晨”，杜绝白天口述“明晨关机”时因未标记次日而错误调度在当天的逻辑漏洞；
     - **单元测试 100% 满分覆盖**：在 `VoiceCommandParserTests.swift` 中新增涵盖今晨、明晨、每晨、次晨、翌晨、夜半单次调度、半点调度、周期重复调度及严苛防即时误触断言，全部通过。
  2. **变频压缩机恒温平衡区能耗动力学 $C^0$ 级平滑连续阻尼重构 (`EnergyAnalyticsEngine.swift`)**：
     - **彻底消除 $\Delta T = 1.0^\circ\text{C}$ 边界功率阶跃断崖**：在 `estimateInstantaneousPower` 中，此前当温差处于接近平衡区（$0 < \Delta T < 1.0^\circ\text{C}$）向重载区（$\Delta T \ge 1.0^\circ\text{C}$）跨越时，风机偏移权重（0.8）与潜热/显热湿度补偿权重（0.7）在 1.0 处发生跳跃（直接切为 1.0），导致最高 36W 以上的非物理瞬态阶跃断崖；
     - **双线性热阻尼连续动态插值模型**：重构制冷、制热与自动模式在 $0 < \Delta T < 1.0^\circ\text{C}$ 区间的动力学过渡公式，引入 `windFactor = 0.6 + delta * 0.4` 与 `humFactor = 0.4 + delta * 0.6` 连续插值，使极小温差（$\Delta T \to 0$）与重载温差（$\Delta T \to 1.0$）达成左极限严格等于右极限的 $C^0$ 级全域物理平滑连续性，数学与热工仿真验证无缝衔接。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下最新的审查报告（`2026-09-24-1426.md`）进行了基线核查与深度代码走查：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 正则模型稳定运行，允许 0~10 个任意字符穿插，彻底解决插字绕过缺陷；
   - **全屋与定向定时解耦 (P1-2)**：`cancelSchedules` 与 `cancelSchedulesAll` 精确分流，多设备批量取消分支全部贯通；
   - **工况占比计算属性消费 (P2-1)**：`EcoEnergySection` 已统一调用 4 个比率属性；
   - **死分支清理 (P2-2)**：`.adjustTemperatureAll` 死分支已彻底清理；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **晨间与夜半口语防误触穿透与即时误关机重大隐患 (P1)**：由于此前 `hasTimingOrCountdownIntent` 和 `hasTimePhase` 遗漏了“今晨”、“明晨”、“每晨”、“次晨”、“翌晨”、“夜半”，当用户口述“明晨关空调”或“夜半开机”时，由于无钟点未命中传统数字时间，直接跌落至即时开关机 `isPowerOff` / `isPowerOn`，造成空调被立即关闭或开启。本轮将晨间与夜半词群全量纳入调度意图防护，彻底根除该隐患；
   - **跨天次日调度同日覆盖缺陷 (P1)**：`VoiceCapsuleWindowController.swift` 中的 `isExplicitTomorrow` 未涵盖“明晨”、“次晨”、“翌晨”，当用户在清晨（如 06:00）或前一天白天口述“明晨7点关空调”时，因当天该钟点尚未过去且未被标记为次日，系统误将其设定为今天清晨 07:00 执行。本轮补齐跨天次日识别链，彻底消除该逻辑漏洞；
   - **能耗动力学过渡区边界阶跃断崖 (P2)**：此前变频压缩机恒温平衡区（$0 < \Delta T < 1.0^\circ\text{C}$）在临界点 $\Delta T = 1.0^\circ\text{C}$ 处存在风机与湿度补偿跳变，本轮重构为严格双线性平滑动态插值，达成 $C^0$ 级物理连续性。

---

## 3. 关键架构变更与代码实现

### 3.1 晨间与夜半自然口语大一统调度与防误触全防线
- **`VoiceCommandParser.swift` 广义时相与时区大一统**：
  ```swift
  // hasTimePhase 与 hasTimingOrCountdownIntent 全防线加固
  text.contains("今晨") || text.contains("明晨") || text.contains("每晨") ||
  text.contains("次晨") || text.contains("翌晨") || text.contains("夜半")

  // 无钟点独立时相映射
  if normalized.contains("午夜") || normalized.contains("子夜") || normalized.contains("三更半夜") || normalized.contains("夜半") {
      hour = 0; minute = 0
  } else if normalized.contains("早上") || ... || normalized.contains("今晨") || normalized.contains("明晨") || normalized.contains("每晨") || normalized.contains("次晨") || normalized.contains("翌晨") {
      hour = 7; minute = 0
  }
  ```

### 3.2 口语半点时相归一流水线补齐
- **`VoiceCommandParser.swift` 中 `convertChineseNumbers` 拓展**：
  ```swift
  str = str.replacingOccurrences(of: "今晨半", with: "今晨7点30分")
  str = str.replacingOccurrences(of: "明晨半", with: "明晨7点30分")
  str = str.replacingOccurrences(of: "每晨半", with: "每晨7点30分")
  str = str.replacingOccurrences(of: "次晨半", with: "次晨7点30分")
  str = str.replacingOccurrences(of: "翌晨半", with: "翌晨7点30分")
  str = str.replacingOccurrences(of: "每早半", with: "每早7点30分")
  str = str.replacingOccurrences(of: "每晚半", with: "每晚9点30分")
  str = str.replacingOccurrences(of: "夜半半", with: "午夜0点30分")
  ```

### 3.3 次日跨天调度全链路对齐
- **`VoiceCapsuleWindowController.swift` 全场景次日判定增强**：
  ```swift
  let isExplicitTomorrow = spokenText.contains("明天") || spokenText.contains("明早") || spokenText.contains("明晚") || spokenText.contains("明午") || spokenText.contains("明夜") || spokenText.contains("明晨") || spokenText.contains("次日") || spokenText.contains("次晨") || spokenText.contains("明儿") || spokenText.contains("隔日") || spokenText.contains("翌日") || spokenText.contains("翌晨")
  ```

### 3.4 变频恒温平衡区平滑连续热阻尼动力学重构
- **`EnergyAnalyticsEngine.swift` 双线性连续动态插值**：
  ```swift
  // 接近目标温差 (0 < ΔT < 1.0°C)：平滑过渡至稳态低频 (v1.9.85 消除 1.0°C 阶跃断崖)
  let windFactor = 0.6 + (delta * 0.4)
  let humFactor = 0.4 + (delta * 0.6)
  power = baseLow + (delta * slope) + (windOffset * windFactor) + (humOffset * humFactor)
  ```

---

## 4. 自动化测试与验证

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增并校验端到端单元测试用例：
  - `"今晨关空调"` -> `07:00` 关机 (PASS)
  - `"今晨开机"` -> `07:00` 开机 (PASS)
  - `"今晨半关机"` -> `07:30` 关机 (PASS)
  - `"明晨关空调"` -> `07:00` 关机 (PASS)
  - `"明晨开机"` -> `07:00` 开机 (PASS)
  - `"明晨半关空调"` -> `07:30` 关机 (PASS)
  - `"每晨关空调"` -> 每天 `07:00` 重复关机 (PASS)
  - `"每晨半关空调"` -> 每天 `07:30` 重复关机 (PASS)
  - `"次晨关空调"` -> `07:00` 关机 (PASS)
  - `"次晨半关机"` -> `07:30` 关机 (PASS)
  - `"翌晨开机"` -> `07:00` 开机 (PASS)
  - `"翌晨半开机"` -> `07:30` 开机 (PASS)
  - `"清晨半关机"` -> `06:30` 关机 (PASS)
  - `"早晨半关机"` -> `06:30` 关机 (PASS)
  - `"黎明半开机"` -> `06:30` 开机 (PASS)
  - `"每早半关机"` -> 每天 `07:30` 关机 (PASS)
  - `"每晚半关机"` -> 每天 `21:30` 关机 (PASS)
  - `"夜半关空调"` -> `00:00` 关机 (PASS)
  - `"夜半开机"` -> `00:00` 开机 (PASS)
  - `"夜半半关机"` -> `00:30` 关机 (PASS)
  - `"夜半12点关空调"` -> `00:00` 关机 (PASS)
  - `"夜半1点关机"` -> `01:00` 关机 (PASS)
  - `"夜半10点关机"` -> `22:00` 关机 (PASS)
  - `"全屋明晨关空调"` -> `07:00` 关机 (PASS)
  - `"全屋夜半关空调"` -> `00:00` 关机 (PASS)
  - 严苛防即时误触断言（16 组全覆盖，绝对禁止掉入 `setPower`、`turnOffAll` 或 `turnOnAll`，全部 PASS）。
- **编译与打包校验**：
  - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 错误编译通过；
  - 运行 `./build_app.sh 1.9.85` 打包生成 `dist/HaierAC-v1.9.85-macOS.zip` (2.8MB)。

---

## 5. 发版信息与资产交付
- **版本号**：`v1.9.85`
- **Git Tag**：`v1.9.85`
- **Release 资产**：`dist/HaierAC-v1.9.85-macOS.zip`
- **SHA-256**：`275771ad42693fd554c424cce6299ee3a335f493e608c3ac727ce1684d30944c`
- **安全敏感数据检查**：经核验，源码与文档均无敏感个人信息、真实 Token 或凭证，符合安全脱敏规范。
