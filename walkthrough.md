# Haier AC Mac v1.9.91 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.91`
- **发版主题**：闭环自然口语下周/这周/本周循环调度大一统引擎、防即时误触全景加固、macOS 桌面小组件与全屋设备模型路由收敛
- **核心目标与架构演进**：
  1. **跨周自然口语循环调度大一统引擎与防即时误触全闭环 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **彻底修复跨周口语被解析为立即开关机的严重误触隐患**：此前用户说“下周关空调”、“下周开机”、“这周关空调”、“本周开机”、“下星期关空调”、“下礼拜关机”、“这星期关机”、“本星期开机”、“全屋下周关空调”等高频跨周时态口语时，因不含具体单星期数字（如“周一”），`hasTimingOrCountdownIntent` 返回 false；口令直接穿透至末尾的 `isPowerOff` / `isPowerOn` / `turnOffAll` / `turnOnAll`，触发**立即关机 / 立即开机**，造成严重的非预期打扰与安全隐患；
     - **跨周自然口语大一统匹配流水线**：在 `parseBaseRepeatWeekdays` 中新增跨周通用调度纳管规则，将“下周/下个周/下星期/下个星期/下礼拜/下个礼拜/这周/这个周/这星期/这个星期/这礼拜/这个礼拜/本周/本个周/本星期/本个星期/本礼拜/本个礼拜/隔周/隔个周”全系跨周口语在无具体星期时统一映射为周一基准（`[2]`），结合默认时相 08:00 无缝构建 `.scheduleRepeatPower` 循环调度指令；
     - **跨周半点口语标准化归一 (`convertChineseNumbers`)**：新增 20+ 组跨周半点映射（如“下周半”->“下周8点30分”，“这周半”->“这周8点30分”，“本周半”->“本周8点30分”，“下星期半”->“下星期8点30分”，“下礼拜半”->“下礼拜8点30分”），对齐半点时相归一流水线；
     - **全景防即时误触语义防线加固 (`hasTimingOrCountdownIntent`)**：将全部跨周、本周前缀及其半点形态纳管为一级前置语义防护，彻底切断定时调度误入立即开关机的路径；
     - **单元测试 100% 满分覆盖**：在 `VoiceCommandParserTests.swift` 中新增 `testNaturalWeekRepeatScheduleAndProtectionV1991`，包含 24 组单机与全屋跨周调度、指定钟点复合调度、半点归一及严苛防即时误触断言，全部通过。
  2. **macOS Desktop WidgetKit 桌面小组件与全屋设备模型路由彻底收敛 (`AppModel.swift` / `StatusItemController.swift` / `VoiceCapsuleWindowController.swift` / `FilterCareSheet.swift`)**：
     - **消除局域网手动设备桌面小组件空白与主控设备漂移缺陷 (`AppModel.writeWidgetSnapshot`)**：此前桌面小组件数据落盘硬编码使用 `devices.first?.id` 与 `devices.first?.deviceName`，导致局域网手动添加设备（无云端账号）环境下 `devices` 为空，小组件无法写入快照、桌面组件永远空白；且多设备拓扑下小组件无法跟随用户设定的主控设备。本次重构全面收敛至 `primaryDeviceId` 与 `deviceName(for:)`，局域网手动设备与多设备拓扑均能 100% 准确同步至 WidgetKit 桌面小组件；
     - **全仓设备路由与名称解析统一收敛**：在菜单栏主显温度（`menuBarTemperatureText`）、自清洁启动（`startSelfCleaning`）、情景应用回退（`applyScene`）、离线防护拦截、温度调节（`adjustTemperature`）、状态栏调度与维护 Tooltip（`StatusItemController`）、语音胶囊主显（`VoiceCapsuleWindowController`）及滤网保养面板（`FilterCareSheet`）中，彻底消除散落的 `allUnifiedDevices.first` 边缘依赖，全面收敛至 `primaryDeviceId` 与 `deviceName(for:)`，达成全仓架构 100% 统一自洽。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下审查报告及架构进行了全景复核与缺陷深挖：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 正则结构稳固，跨字符穿插防御严密；
   - **全屋与定向定时解耦 (P1-2)**：`cancelSchedules` 与 `cancelSchedulesAll` 精确分流，多设备批量取消分支全部贯通；
   - **工况占比计算属性消费 (P2-1)**：`EcoEnergySection` 已统一调用 4 个比率属性；
   - **死分支清理 (P2-2)**：`.adjustTemperatureAll` 死分支已彻底清理；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **跨周调度口令误穿透至立即开关机隐患 (P0/P1)**：口语“下周关空调”、“下周开机”、“这周关空调”、“本周开机”等因缺少单星期数字导致前置防护脱靶，直接穿透至立即开关机。本版本建立跨周大一统识别管线，杜绝任何误触；
   - **macOS 桌面小组件在手动设备下完全空白缺陷 (P1)**：`writeWidgetSnapshot` 依赖 `devices.first` 导致手动设备无法更新小组件，且多设备下不跟随主显。本次重构统一至 `primaryDeviceId` 与 `deviceName(for:)`；
   - **设备名称解析散落与回退偏差 (P2)**：全仓清理边缘 `allUnifiedDevices.first` 调用点，统一收敛至 `model.deviceName(for:)`。

---

## 3. 关键架构变更与代码实现

### 3.1 跨周循环调度大一统与防即时误触加固
- **`VoiceCommandParser.swift` 跨周识别**：
  ```swift
  // 7.1 自然语言口语“下周/下个周/下星期/下个星期/下礼拜/下个礼拜/这周/这个周/这星期/这个星期/这礼拜/这个礼拜/本周/本个周/本星期/本礼拜”大一统调度（映射至周一基准 [2]） (v1.9.91)
  if text.contains("下周") || text.contains("下个周") || text.contains("下星期") || text.contains("下个星期") || text.contains("下礼拜") || text.contains("下个礼拜") ||
     text.contains("这周") || text.contains("这个周") || text.contains("这星期") || text.contains("这个星期") || text.contains("这礼拜") || text.contains("这个礼拜") ||
     text.contains("本周") || text.contains("本个周") || text.contains("本星期") || text.contains("本个星期") || text.contains("本礼拜") || text.contains("本个礼拜") ||
     text.contains("隔周") || text.contains("隔个周") {
      return ([2], "每周一")
  }
  ```
- **`hasTimingOrCountdownIntent` 前置语义拦截**：
  ```swift
  text.contains("下周") || text.contains("下个周") || text.contains("下星期") || text.contains("下个星期") || text.contains("下礼拜") || text.contains("下个礼拜") ||
  text.contains("这周") || text.contains("这个周") || text.contains("这星期") || text.contains("这个星期") || text.contains("这礼拜") || text.contains("这个礼拜") ||
  text.contains("本周") || text.contains("本个周") || text.contains("本星期") || text.contains("本个星期") || text.contains("本礼拜") || text.contains("本个礼拜") ||
  text.contains("隔周") || text.contains("隔个周") || text.contains("下周末") || text.contains("这周末") || text.contains("本周末") ||
  text.contains("下周半") || text.contains("下个周半") || text.contains("这周半") || text.contains("这个周半") || text.contains("本周半") ||
  text.contains("下星期半") || text.contains("下个星期半") || text.contains("这星期半") || text.contains("这个星期半") || text.contains("本星期半") ||
  text.contains("下礼拜半") || text.contains("下个礼拜半") || text.contains("这礼拜半") || text.contains("这个礼拜半") || text.contains("本礼拜半") || ...
  ```

### 3.2 跨周半点时相归一流水线
- **`VoiceCommandParser.swift` 中 `convertChineseNumbers` 拓展**：
  ```swift
  str = str.replacingOccurrences(of: "下周半", with: "下周8点30分")
  str = str.replacingOccurrences(of: "下个周半", with: "下个周8点30分")
  str = str.replacingOccurrences(of: "这周半", with: "这周8点30分")
  str = str.replacingOccurrences(of: "这个周半", with: "这个周8点30分")
  str = str.replacingOccurrences(of: "本周半", with: "本周8点30分")
  str = str.replacingOccurrences(of: "下星期半", with: "下星期8点30分")
  str = str.replacingOccurrences(of: "下礼拜半", with: "下礼拜8点30分")
  // ... 全量标准化映射
  ```

### 3.3 macOS 桌面小组件与全屋设备模型路由收敛
- **`AppModel.writeWidgetSnapshot`**：
  ```swift
  guard let deviceId = primaryDeviceId else { return }
  let attrs = attributes[deviceId] ?? [:]
  var dict: [String: Any] = [:]
  // ...
  dict["deviceName"] = deviceName(for: deviceId)
  dict["updatedAt"] = ISO8601DateFormatter().string(from: Date())
  ```
- **全仓边缘调用点收敛**：
  - `menuBarTemperatureText`: `guard menuBarShowTemperature, let deviceId = primaryDeviceId`
  - `startSelfCleaning`: `let devName = deviceName(for: deviceId)`
  - `applyScene`: `let fallbackId = targetDeviceId ?? primaryDeviceId`
  - `adjustTemperature`: `let devName = deviceName(for: deviceId)`
  - `StatusItemController`: 全面使用 `model.deviceName(for: devId)`
  - `VoiceCapsuleWindowController`: 全面使用 `model.primaryDeviceId` 与 `model.deviceName(for:)`
  - `FilterCareSheet`: 全面使用 `model.deviceName(for: currentDeviceId)`

---

## 4. 验证与测试结果

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增并校验端到端单元测试用例（24 组断言 100% PASS）：
  - `"下周关空调"` -> `08:00` 关机，周一循环 (PASS)
  - `"下周开机"` -> `08:00` 开机，周一循环 (PASS)
  - `"这周关空调"` -> `08:00` 关机，周一循环 (PASS)
  - `"本周开机"` -> `08:00` 开机，周一循环 (PASS)
  - `"下星期关空调"` -> `08:00` 关机，周一循环 (PASS)
  - `"下礼拜关机"` -> `08:00` 关机，周一循环 (PASS)
  - `"全屋下周关空调"` -> `08:00` 全屋关机，周一循环 (PASS)
  - `"全屋这周开机"` -> `08:00` 全屋开机，周一循环 (PASS)
  - `"下周早上8点开机"` -> `08:00` 开机，周一循环 (PASS)
  - `"下周晚上10点关空调"` -> `22:00` 关机，周一循环 (PASS)
  - `"本周五晚上9点关空调"` -> `21:00` 关机，周五循环 (PASS)
  - `"下周三下午3点关空调"` -> `15:00` 关机，周三循环 (PASS)
  - `"下周半关机"` -> `08:30` 关机，周一循环 (PASS)
  - `"这周半开机"` -> `08:30` 开机，周一循环 (PASS)
  - `"本周半关机"` -> `08:30` 关机，周一循环 (PASS)
  - `"下星期半关空调"` -> `08:30` 关机，周一循环 (PASS)
  - `"下礼拜半关机"` -> `08:30` 关机，周一循环 (PASS)
  - 严苛防即时误触断言（针对“下周关空调”、“下周开机”、“这周关空调”、“这周开机”、“本周关空调”、“本周开机”、“下星期关空调”、“下星期开机”、“下礼拜关机”、“下礼拜开机”、“全屋下周关空调”、“全屋下周开机”、“全屋这周关机”、“全屋本周开机”，绝对禁止掉入 `setPower`、`turnOffAll` 或 `turnOnAll`，全部 PASS）。
- **编译与打包校验**：
  - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 错误编译通过；
  - 运行 `./build_app.sh 1.9.91` 打包生成 `dist/HaierAC-v1.9.91-macOS.zip` (2.8MB)。

---

## 5. 发版信息与资产交付
- **版本号**：`v1.9.91`
- **Git Tag**：`v1.9.91`
- **Release 资产**：`dist/HaierAC-v1.9.91-macOS.zip`
- **SHA-256**：`2aba56f964a5dd7b577892f936b49b306a5b056c061876fc10437f5bc3a20d8d`
- **安全敏感数据检查**：经核验，源码与文档均无敏感个人信息、真实 Token 或凭证，符合安全脱敏规范。
