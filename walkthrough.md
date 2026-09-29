# Haier AC Mac v1.9.83 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.83`
- **发版主题**：闭环 CR 变频多档风速语义与口语大一统对齐、深宵/通宵/夜深全时相防误触闭环与 macOS 状态栏风速协同交互重构
- **核心目标与架构演进**：
  1. **变频多档风速口语解析大一统与跨层物理语义对齐 (`VoiceCommandParser.swift`)**：
     - **根除 4 档/四档误判为自动风的历史缺陷**：在 `VoiceCommandParser.parseWindSpeed` 中，彻底清理此前将“四档”、“4档”、“第四档”、“风速4”错误归入自动风的历史遗留代码，严格与 `AppModel.normalizeWindSpeed`、`EnergyAnalyticsEngine.estimateInstantaneousPower`（4档=140W强风）及滤网动力学模型（4档=1.50x风阻通量）达成 100% 语义自洽；
     - **全量纳管 4档/5档/暴风/极速/超强风大档位口语**：扩展支持“五档”、“5档”、“暴风”、“超强”、“极速”、“风速5”、“风速五”等现代变频内机大档位口语，统一映射至“强劲”标准风速档位；同时将“自动”风速严格限定为“自动风/自动风速/智能风/自适应风速/自动档”，消除语义交叉混淆。
  2. **深宵 / 通宵 / 夜深 自然口语无钟点独立时相调度大一统引擎与防即时误触全闭环 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **深宵/通宵/夜深 词群全景闭环**：纳管“深宵”、“通宵”、“夜深”无钟点独立时相，自适应映射为夜间 23:00，支持“深宵关空调”、“深宵开机”、“通宵关机”、“通宵开空调”、“夜深关空调”、“夜深开机”等自然日常口语调度；
     - **口语半点时相归一流水线补全**：在 `convertChineseNumbers` 中新增“深宵半”(23:30)、“通宵半”(23:30)、“夜深半”(23:30) 标准化替换，彻底补齐深夜全时相口语表达；
     - **调度意图判定与防即时开关机穿透全防线 (`hasTimePhase` / `hasTimingOrCountdownIntent`)**：将“深宵”、“通宵”、“夜深”注入 `hasTimePhase` 与 `hasTimingOrCountdownIntent` 前置卫语句，彻底杜绝无显式钟点的深夜口语调度穿透至 `isPowerOff` / `isPowerOn` 造成立即误关机/开机的重大安全缺陷；
     - **单元测试 100% 满分覆盖**：在 `VoiceCommandParserTests.swift` 中新增涵盖深宵、通宵、夜深单次调度、半点调度、周期重复调度及严苛防即时误触断言（深宵关空调 != setPower(false)，全屋深宵关空调 != turnOffAll，通宵开机 != setPower(true) 等），全部通过。
  3. **macOS 原生状态栏全交互矩阵风速协同与待机感知重构 (`StatusItemController.swift`)**：
     - **消除风速协同菜单项的温度语义污染**：此前“全屋风速协同”菜单标题直接复用了带温度范围的 `runningCountDesc`，导致显示为 `🍃 全屋风速协同 (2台运行中 · 当前 24~26°C)...`；现重构为专用的 `windRunningDesc`，若全屋档位一致则显示当前风速（如 `🍃 全屋风速协同 (2台运行中 · 当前微风)...`），档位不同则显示 `(2台运行中 · 档位不同)`，全屋关机时显示 `(当前均未开机)`；
     - **全屋风速协同精准靶向与使能防护**：全屋风速子菜单项（微风/中风/强劲/自动）当全屋无开机空调时设为不可选（`isEnabled = model.gatewayConnected && !onDevices.isEmpty`），Toolip 提示“当前全屋无运行中的空调”；当有开机设备时附带受控空调清单；且 `setAllWindSpeedFromMenu` 仅向运行中空调下发风速，避免干扰待机设备；
     - **单设备与级联子菜单待机保护**：风速调节子菜单项设为 `isEnabled = isControllable && isPowerOn`，待机状态标题显示为 `🍃 调节风速 (待机中)`，Tooltip 提示“当前处于关机待机状态，请先开启电源再调节风速”，杜绝向待机设备盲目下发风速指令。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下最新的审查报告（`2026-09-24-1426.md`）进行了基线核查与深度代码走查：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 正则模型稳定运行，允许 0~10 个任意字符穿插，彻底解决插字绕过缺陷；
   - **全屋与定向定时解耦 (P1-2)**：`cancelSchedules` 与 `cancelSchedulesAll` 精确分流，多设备批量取消分支全部贯通；
   - **工况占比计算属性消费 (P2-1)**：`EcoEnergySection` 已统一调用 4 个比率属性；
   - **死分支清理 (P2-2)**：`.adjustTemperatureAll` 死分支已彻底清理；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏使能状态。
2. **深度代码走查发现的问题与闭环解决**：
   - **深宵/通宵/夜深无钟点口语穿透即时误关机缺陷 (P1)**：`hasTimePhase` 与 `hasTimingOrCountdownIntent` 遗漏“深宵”、“通宵”、“夜深”，导致用户说“深宵关空调”时无法解析为定时调度，反而穿透执行为立即全屋/单机断电关机。本次全量纳管深宵/通宵/夜深时相与半点流水线，构筑绝对防误触防线；
   - **风速口语与变频大档位语义倒挂缺陷 (P1)**：`VoiceCommandParser.parseWindSpeed` 遗留将 4档/四档映射为“自动”的逻辑缺陷，且无法识别 5档/暴风。本次与 `AppModel.normalizeWindSpeed` 及能耗动力学全面对齐，将 4档/5档/暴风统一收敛至“强劲”，自动风严格独立；
   - **状态栏风速协同菜单温度语义污染与待机误下发 (P2)**：修复状态栏风速协同菜单项借用温度范围标题导致“当前 24~26°C”污染风速菜单的体验缺陷，重构状态栏各级风速菜单的待机使能与提示防护。

---

## 3. 关键架构变更与代码实现

### 3.1 变频多档风速口语解析大一统
- **`VoiceCommandParser.swift` 风速多档归一重构**：
  ```swift
  // 1. 自动风档位 (v1.9.83 严格限定智能/自动/自适应风速，杜绝将 4 档机械割裂误判为自动风)
  if text.contains("自动风") || text.contains("风速自动") || text.contains("自动风速") ||
     text.contains("智能风") || text.contains("自适应风") || text.contains("智能风速") ||
     text.contains("自适应风速") || text.contains("自动档") || text.contains("自动档位") {
      return ("自动", "自动风速")
  }
  // 2. 强劲 / 暴风 / 5档 / 4档 / 3档 / 高风 / 大风 (v1.9.47, v1.9.83 全量对齐变频大档位动力学，支持4档、5档与暴风极速)
  if text.contains("暴风") || text.contains("超强") || text.contains("极速") ||
     text.contains("五档") || text.contains("5档") || text.contains("第5档") || text.contains("第五档") ||
     text.contains("风速5") || text.contains("风速五") ||
     text.contains("四档") || text.contains("4档") || text.contains("第4档") || text.contains("第四档") ||
     text.contains("风速4") || text.contains("风速四") ||
     text.contains("大风") || text.contains("风大") || text.contains("强劲") || text.contains("高风") ||
     text.contains("最大风") || text.contains("最大") || text.contains("调大风") || text.contains("风速大") ||
     text.contains("高速风") || text.contains("开到最大") || text.contains("强风") ||
     text.contains("三档") || text.contains("3档") || text.contains("第3档") || text.contains("第三档") ||
     text.contains("风速3") || text.contains("风速三") || text.contains("高档") || text.contains("风速调大") ||
     text.contains("风开大") || text.contains("把风开大") || text.contains("风调大") || text.contains("风大点") ||
     text.contains("调大风速") || text.contains("开大风速") || text.contains("吹大风") ||
     text.contains("吹暴风") || text.contains("吹强风") {
      return ("强劲", "强劲风速")
  }
  ```

### 3.2 深宵/通宵/夜深口语时相调度与防即时开关机穿透
- **`VoiceCommandParser.swift` 深宵词群纳管与半点流水线**：
  ```swift
  // 时相感知与意图识别
  str = str.replacingOccurrences(of: "深宵半", with: "深宵11点30分")
  str = str.replacingOccurrences(of: "通宵半", with: "通宵11点30分")
  str = str.replacingOccurrences(of: "夜深半", with: "夜深11点30分")

  // hasTimePhase 与 hasTimingOrCountdownIntent 全防线加固
  text.contains("深宵") || text.contains("通宵") || text.contains("夜深")
  ```

### 3.3 macOS 状态栏风速协同交互重构
- **`StatusItemController.swift` 精准风速感知与待机防护**：
  ```swift
  let windRunningDesc = !onDevices.isEmpty ? (allOnSameSpeed != nil ? " (\(onDevices.count)台运行中 · 当前\(allOnSameSpeed!))" : " (\(onDevices.count)台运行中 · 档位不同)") : " (当前均未开机)"
  let canSetWindAll = model.gatewayConnected && !onDevices.isEmpty
  // 菜单项仅在有运行中空调时使能，待机时显示精准指引
  item.isEnabled = canSetWindAll
  ```

---

## 4. 自动化测试与验证

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增并校验端到端单元测试用例：
  - `"深宵关空调"` -> `23:00` 关机 (PASS)
  - `"深宵开机"` -> `23:00` 开机 (PASS)
  - `"深宵半关机"` -> `23:30` 关机 (PASS)
  - `"通宵关机"` -> `23:00` 关机 (PASS)
  - `"通宵开空调"` -> `23:00` 开机 (PASS)
  - `"通宵半关空调"` -> `23:30` 关机 (PASS)
  - `"夜深关空调"` -> `23:00` 关机 (PASS)
  - `"夜深开机"` -> `23:00` 开机 (PASS)
  - `"夜深半关机"` -> `23:30` 关机 (PASS)
  - `"每天深宵关机"` -> 每天 `23:00` 关机 (PASS)
  - `"工作日通宵关空调"` -> 工作日 `23:00` 关机 (PASS)
  - `"周末夜深开机"` -> 周末 `23:00` 开机 (PASS)
  - `"开四档风"` -> `.setWindSpeed("强劲")` (PASS)
  - `"风速4档"` -> `.setWindSpeed("强劲")` (PASS)
  - `"风速四"` -> `.setWindSpeed("强劲")` (PASS)
  - `"开五档风"` -> `.setWindSpeed("强劲")` (PASS)
  - `"风速5档"` -> `.setWindSpeed("强劲")` (PASS)
  - `"吹暴风"` -> `.setWindSpeed("强劲")` (PASS)
  - `"全屋吹暴风"` -> `.setWindSpeedAll("强劲")` (PASS)
  - `"全屋风速4档"` -> `.setWindSpeedAll("强劲")` (PASS)
  - 防误触断言（深宵关空调 != setPower(false)，全屋深宵关空调 != turnOffAll，通宵开机 != setPower(true)，夜深关空调 != setPower(false)）全部 PASS。
- **本地编译验证**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` -> 100% 成功，0 错误；
  - 运行 `./build_app.sh 1.9.83` 打包生成 `dist/HaierAC-v1.9.83-macOS.zip` (2.8MB)。

---

## 5. 发版信息与交付产物
- **Git Tag**：`v1.9.83`
- **Release 资产**：`dist/HaierAC-v1.9.83-macOS.zip`
- **SHA-256**：`a7725b5c87d62c66d24ec9937c031f8f1a2c40c7a2f583643f86e44e7fa2fada`
- **安全敏感数据检查**：经核验，源码与文档均无敏感个人信息、真实 Token 或凭证，符合安全脱敏规范。
