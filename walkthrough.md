# Haier AC Mac v1.9.84 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.84`
- **发版主题**：闭环自然口语深夜与隔夜全时相调度大一统引擎、防即时开关机误触穿透与状态栏多设备风速感知精细化
- **核心目标与架构演进**：
  1. **自然口语深夜与隔夜全时相独立调度大一统引擎与防即时开关机穿透全闭环 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **深宵夜间与次日词群全景闭环**：纳管“今夜”、“明夜”、“每夜”（映射为 21:00）、“整夜”、“彻夜”、“隔夜”（映射为 23:00）、“后夜”（映射为 02:00）、“隔日”、“翌日”（映射为 08:00），支持“今夜关空调”、“明夜关机”、“整夜开机”、“彻夜开空调”、“后夜关机”、“隔夜关机”、“隔日关机”、“翌日开机”等自然日常调度；
     - **根除夜间口语钟点倒挂与误判为白天上午的重大缺陷**：修复此前因 `isEveningStandard` 和 `isNocturnal` 遗漏“今夜”、“明夜”、“每夜”，导致“今夜十点关空调”、“每夜10点关空调”未累加 12 错误调度为上午 10:00，以及“今夜12点”未被 `isNightMidnight` 捕获误调度为正午 12:00 的严重时态错乱；
     - **口语半点时相归一流水线全量补全**：在 `convertChineseNumbers` 中新增“今夜半”(21:30)、“明夜半”(21:30)、“每夜半”(21:30)、“整夜半”(23:30)、“彻夜半”(23:30)、“隔夜半”(23:30)、“后夜半”(02:30)、“隔日半”(08:30)、“翌日半”(08:30) 标准化替换，彻底补齐夜间与次日全时相口语表达；
     - **防即时开关机穿透全防线加固 (`hasTimingOrCountdownIntent` / `hasTimePhase`)**：将“今夜”、“明夜”、“整夜”、“彻夜”、“隔夜”、“后夜”、“隔日”、“翌日”全量注入前置卫语句，彻底杜绝无显式钟点的口语调度穿透至 `isPowerOff` / `isPowerOn` 造成立即误关机/开机的安全缺陷；
     - **次日调度判定全链路对齐 (`VoiceCapsuleWindowController.swift`)**：在单机、全屋与多机定时调度中，将 `isExplicitTomorrow` 全面扩展覆盖“明午”、“明夜”、“隔日”、“翌日”，确保“明夜10点关空调”等跨天口语精准调度至明天夜间，消除同日误判；
     - **单元测试 100% 满分覆盖**：在 `VoiceCommandParserTests.swift` 中新增涵盖今夜、明夜、每夜、整夜、彻夜、隔夜、后夜、隔日、翌日单次调度、半点调度、周期重复调度及严苛防即时误触断言，全部通过。
  2. **macOS 原生状态栏单机与级联子菜单风速动态感知精细化 (`StatusItemController.swift`)**：
     - **消除设备风速子菜单原始代号显示缺陷**：修复状态栏单机菜单（`singleWindItem`）与设备级联子菜单（`devWindParentItem`）标题及 Tooltip 直接拼接原始硬件代号（导致上报“2”、“high”、“low”、“auto”等字符时显示为 `🍃 调节风速 (当前: 2)`）的显示粗糙问题；统一采用 `normCurWind` 规范化中文名称，呈现为 `🍃 调节风速 (当前: 中风)`、`🍃 调节风速 (当前: 强劲)`、`🍃 调节风速 (当前: 自动)` 等与菜单子项严格一致的优雅原生体验。

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
   - **夜间口语时态倒挂与上午错位重大缺陷 (P1)**：由于此前 `isEveningStandard` 和 `isNocturnal` 遗漏了“今夜”、“明夜”、“每夜”，用户口述“今夜十点关空调”或“每夜10点关空调”时，系统无法将其归入晚间时相，导致小时数未累加 12，而错误在每天/今晚的上午 10:00 执行关机；同理，“今夜12点”亦未能触发 `isNightMidnight`，导致被保留为正午 12:00。本轮将今夜/明夜/每夜/整夜/彻夜/隔夜/后夜全量纳入时区模型，彻底根除该缺陷；
   - **跨天次日调度同日覆盖缺陷 (P1)**：`VoiceCapsuleWindowController.swift` 中的 `isExplicitTomorrow` 未涵盖“明夜”、“明午”、“隔日”、“翌日”，当用户在白天（如上午 10 点）口述“明夜10点关空调”时，因当天该钟点尚未过去且未被标记为次日，系统误将其设定为今天夜间 22:00 执行。本轮全面补齐跨天次日识别链，彻底消除该逻辑漏洞；
   - **状态栏风速菜单硬件原始代号未脱敏显示粗糙 (P2)**：单设备与设备子菜单风速标题此前直接显示内机原生代号 `curWind`，导致出现 `🍃 调节风速 (当前: 2)` 或 `(当前: high)` 等非人性化文字，本轮统一规范为 `normCurWind` 中文标准档位展示。

---

## 3. 关键架构变更与代码实现

### 3.1 深宵夜间与次日自然口语大一统时区校准
- **`VoiceCommandParser.swift` 广义时相与时区大一统**：
  ```swift
  // hasTimePhase 与 hasTimingOrCountdownIntent 全防线加固
  normalized.contains("今夜") || normalized.contains("明夜") || normalized.contains("每夜") ||
  normalized.contains("整夜") || normalized.contains("彻夜") || normalized.contains("隔夜") ||
  normalized.contains("后夜") || normalized.contains("隔日") || normalized.contains("翌日") ||
  normalized.contains("明儿")

  // 钟点晚间加 12 与午夜 00:00 精准校准
  let isNocturnal = ... || normalized.contains("整夜") || normalized.contains("彻夜") || normalized.contains("隔夜") || normalized.contains("后夜")
  let isEveningStandard = ... || normalized.contains("今夜") || normalized.contains("明夜") || normalized.contains("每夜")
  ```

### 3.2 口语半点时相归一流水线补齐
- **`VoiceCommandParser.swift` 中 `convertChineseNumbers` 拓展**：
  ```swift
  str = str.replacingOccurrences(of: "今夜半", with: "今夜9点30分")
  str = str.replacingOccurrences(of: "明夜半", with: "明夜9点30分")
  str = str.replacingOccurrences(of: "每夜半", with: "每夜9点30分")
  str = str.replacingOccurrences(of: "整夜半", with: "整夜11点30分")
  str = str.replacingOccurrences(of: "彻夜半", with: "彻夜11点30分")
  str = str.replacingOccurrences(of: "隔夜半", with: "隔夜11点30分")
  str = str.replacingOccurrences(of: "后夜半", with: "后夜2点30分")
  str = str.replacingOccurrences(of: "隔日半", with: "隔日8点30分")
  str = str.replacingOccurrences(of: "翌日半", with: "翌日8点30分")
  ```

### 3.3 次日跨天调度全链路对齐
- **`VoiceCapsuleWindowController.swift` 全场景次日判定增强**：
  ```swift
  let isExplicitTomorrow = spokenText.contains("明天") || spokenText.contains("明早") || spokenText.contains("明晚") || spokenText.contains("明午") || spokenText.contains("明夜") || spokenText.contains("次日") || spokenText.contains("明儿") || spokenText.contains("隔日") || spokenText.contains("翌日")
  ```

### 3.4 状态栏设备风速菜单原生体验精细化
- **`StatusItemController.swift` 规范化档位展示**：
  ```swift
  let windTitle = isPowerOn ? "🍃 调节风速 (当前: \(normCurWind))" : "🍃 调节风速 (待机中)"
  let devWindParentItem = NSMenuItem(title: windTitle, action: nil, keyEquivalent: "")
  devWindParentItem.toolTip = isPowerOn ? "调节「\(dev.name)」出风风速（当前: \(normCurWind)）" : "「\(dev.name)」当前处于关机待机状态"
  ```

---

## 4. 自动化测试与验证

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增并校验端到端单元测试用例：
  - `"今夜关空调"` -> `21:00` 关机 (PASS)
  - `"今夜开机"` -> `21:00` 开机 (PASS)
  - `"今夜半关机"` -> `21:30` 关机 (PASS)
  - `"明夜关空调"` -> `21:00` 关机 (PASS)
  - `"明夜开机"` -> `21:00` 开机 (PASS)
  - `"明夜半关空调"` -> `21:30` 关机 (PASS)
  - `"每夜十点关空调"` -> 每天 `22:00` 重复关机 (PASS)
  - `"今夜十点关空调"` -> 今天 `22:00` 关机 (PASS)
  - `"明夜十点关空调"` -> 明天 `22:00` 关机 (PASS)
  - `"整夜开空调"` -> `23:00` 开机 (PASS)
  - `"彻夜开空调"` -> `23:00` 开机 (PASS)
  - `"隔夜关机"` -> `23:00` 关机 (PASS)
  - `"后夜关机"` -> `02:00` 关机 (PASS)
  - `"后夜半关机"` -> `02:30` 关机 (PASS)
  - `"隔日关空调"` -> `08:00` 关机 (PASS)
  - `"翌日开机"` -> `08:00` 开机 (PASS)
  - `"全屋明夜关空调"` -> `21:00` 关机 (PASS)
  - 严苛防即时误触断言（16 组全覆盖，绝对禁止掉入 `setPower`、`turnOffAll` 或 `turnOnAll`，全部 PASS）。
- **编译与打包校验**：
  - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 错误编译通过；
  - 运行 `./build_app.sh 1.9.84` 打包生成 `dist/HaierAC-v1.9.84-macOS.zip` (2.8MB)。

---

## 5. 发版信息与资产交付
- **版本号**：`v1.9.84`
- **Git Tag**：`v1.9.84`
- **Release 资产**：`dist/HaierAC-v1.9.84-macOS.zip`
- **SHA-256**：`87ed6d0326bd6208192729ca92af5e4924aa979a3328ddd73b991d37566edcd5`
