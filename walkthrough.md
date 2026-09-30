# Haier AC Mac v1.9.92 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.92`
- **发版主题**：闭环自然口语下下周/后周/双休日大一统调度、防即时误触全景加固、静音0档原生硬件原语热动力学对齐与Siri/快捷指令设备路由收敛
- **核心目标与架构演进**：
  1. **跨周双向自然口语大一统调度与防即时误触加固 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **跨周多时态调度大一统纳管**：在 `parseBaseRepeatWeekdays` 中新增“下下周/下下个周/下下星期/下下个星期/下下礼拜/下下个礼拜/后周/后个周/后星期/后个星期/后礼拜/后个礼拜/双休日/逢双休/每逢双休”完整映射体系。将下下周、后周等映射为周一基准（`[2]`），将双休日/逢双休映射为周六周日循环基准（`[1, 7]`），结合默认时相 08:00 无缝构建 `.scheduleRepeatPower` 循环调度指令；
     - **口语半点时相归一流水线 (`convertChineseNumbers`)**：扩充 20+ 组自然半点映射（如“下下周半”->“下下周8点30分”，“后周半”->“后周8点30分”，“双休日半”->“双休日8点30分”，“逢双休半”->“逢双休8点30分”等），统一对齐 08:30 时相解析；
     - **全景防即时误触前置语义防护 (`hasTimingOrCountdownIntent`)**：将全部下下周、后周、双休日及其半点前缀全面纳管至一级前置语义防护网，彻底根除“下下周关空调”、“后周关机”、“双休日关空调”穿透到即时开关机的重大安全隐患；
     - **单元测试 100% 满分覆盖**：在 `VoiceCommandParserTests.swift` 中新增 `testAdvancedWeekAndWeekendRepeatScheduleAndProtectionV1992`，包含 28 组单机与全屋跨周调度、指定钟点复合调度、半点归一及严苛防即时误触断言，全部通过。
  2. **静音 0 档原生硬件原语热动力学与空气动力学精准对齐 (`EnergyAnalyticsEngine.swift` / `AppModel.swift`)**：
     - **能耗动力学瞬时功率估算精准对齐 (`estimateInstantaneousPower`)**：针对空调硬件原生静音档（0 档），全面纳管 `0档`、`零档`、`0`、`level0`、`level_0`、`speed0`、`speed_0`、`gear0`、`gear_0` 原语判定，精准匹配 15W 微风维持功率，杜绝因遗漏而掉入默认自动风速导致的大温差 120W 功耗虚标失真；
     - **空气动力学滤网磨损因数精准对齐 (`calculateFilterWearFactor`)**：在滤网负荷动力学计算中同步纳管上述原生静音档原语，匹配 0.60 极低风阻磨损因数，杜绝误掉入自动风速（1.30 因数）导致的滤网寿命加速损耗计算偏差。
  3. **Siri/快捷指令全屋调度修复与全仓设备路由模型彻底收敛 (`AppIntents.swift` / `StatusItemController.swift` / `ScheduleViews.swift` / `SleepCurveSection.swift` / `EcoEnergySection.swift` / `HaierACApp.swift`)**：
     - **彻底修复 Siri 全屋调度截流 Bug (`AppIntents.swift`)**：在 `SetACScheduleIntent` 中，修复当用户语音指令指明 `deviceName = "全屋"` 时，因优先读取 `menuBarDeviceId` 导致被截流篡改为单机调度的严重缺陷；明确确立 `isAllScope` 优先分流逻辑，并提供统一的 `primaryDeviceId` 兜底回退；
     - **全仓设备路由与名称解析统一收敛**：全面排查并消除散落在状态栏菜单构建（`StatusItemController`）、定时任务列表视图（`ScheduleViews`）、睡眠曲线面板（`SleepCurveSection`）、能耗面板（`EcoEnergySection`）以及应用主入口（`HaierACApp`）中 15+ 处 `allUnifiedDevices.first` 边缘调用，统一采用 `model.primaryDeviceId` 与 `model.deviceName(for:)`，达成局域网手动设备与多设备拓扑全仓 100% 统一自洽。

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
   - **跨周多时态调度口令误穿透至立即开关机隐患 (P0/P1)**：口语“下下周关空调”、“后周开机”、“双休日关机”等因缺少单星期数字导致前置防护脱靶，直接穿透至立即开关机。本版本建立大一统多时态识别与语义防御管线，杜绝任何误触；
   - **Siri 全屋定时调度被单机截流缺陷 (P1)**：`SetACScheduleIntent` 在 `isAllScope` 下优先绑定了 `menuBarDeviceId`，导致全屋调度被意外降级为单设备调度。本次修复确立了作用域优先原则；
   - **静音 0 档原生硬件原语热动力学失真 (P2)**：硬件下发的 `gear0`/`level0`/`0档` 未被纳管，导致功率与滤网算法掉入自动风速分支。本次全量对齐原生硬件原语；
   - **设备名称解析散落与回退偏差 (P2)**：全仓清理边缘 `allUnifiedDevices.first` 调用点，统一收敛至 `model.deviceName(for:)`。

---

## 3. 关键架构变更与代码实现

### 3.1 跨周与双休日自然调度大一统与防即时误触加固
- **`VoiceCommandParser.swift` 跨周识别**：
  ```swift
  // 自然语言口语“下下周/后周/后星期/后礼拜”大一统调度（映射至周一基准 [2]） (v1.9.92)
  if text.contains("下下周") || text.contains("下下个周") || text.contains("下下星期") || text.contains("下下个星期") ||
     text.contains("下下礼拜") || text.contains("下下个礼拜") || text.contains("后周") || text.contains("后个周") ||
     text.contains("后星期") || text.contains("后个星期") || text.contains("后礼拜") || text.contains("后个礼拜") {
      return ([2], "每周一")
  }

  // 自然语言口语“双休日/逢双休/每逢双休”调度（映射至周六、周日 [1, 7]） (v1.9.92)
  if text.contains("双休日") || text.contains("逢双休") || text.contains("每逢双休") {
      return ([1, 7], "每周六、周日")
  }
  ```
- **`hasTimingOrCountdownIntent` 前置语义拦截**：
  全面纳管“下下周”、“后周”、“双休日”、“逢双休”等及其半点时相口语，杜绝误触立即开关机。

### 3.2 静音 0 档原生硬件原语热动力学与空气动力学精准对齐
- **`EnergyAnalyticsEngine.swift`**：
  ```swift
  // 瞬时功率估算：静音档 / 0 档微风支持
  if speed.contains("静音") || speed.contains("微风") || speed.contains("0档") || speed.contains("零档") ||
     speed == "0" || speed == "level0" || speed == "level_0" || speed == "speed0" || speed == "speed_0" ||
     speed == "gear0" || speed == "gear_0" {
      fanPower = 15.0
  }
  // 滤网负荷因子：匹配 0.60 极低风阻
  if speed.contains("静音") || speed.contains("微风") || speed.contains("0档") || speed.contains("零档") ||
     speed == "0" || speed == "level0" || speed == "level_0" || speed == "speed0" || speed == "speed_0" ||
     speed == "gear0" || speed == "gear_0" {
      return 0.60
  }
  ```

### 3.3 Siri/快捷指令设备路由与全仓模型收敛
- **`AppIntents.swift` 作用域优先分流**：
  ```swift
  let targetDeviceId: String?
  if isAllScope {
      targetDeviceId = nil
  } else if let name = deviceName, !name.isEmpty {
      targetDeviceId = model.allUnifiedDevices.first(where: { $0.deviceName.localizedCaseInsensitiveContains(name) })?.id
  } else {
      targetDeviceId = model.menuBarDeviceId ?? model.primaryDeviceId
  }
  ```
- **全仓边缘调用点收敛**：
  `StatusItemController`、`ScheduleViews`、`SleepCurveSection`、`EcoEnergySection`、`HaierACApp` 均收敛至 `model.primaryDeviceId` 与 `model.deviceName(for:)`。

---

## 4. 验证与测试结果

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增并校验端到端单元测试用例（28 组断言 100% PASS）：
  - `"下下周关空调"` -> `08:00` 关机，周一循环 (PASS)
  - `"下下周开机"` -> `08:00` 开机，周一循环 (PASS)
  - `"后周关机"` -> `08:00` 关机，周一循环 (PASS)
  - `"后星期开空调"` -> `08:00` 开机，周一循环 (PASS)
  - `"后礼拜关空调"` -> `08:00` 关机，周一循环 (PASS)
  - `"双休日关空调"` -> `08:00` 关机，周六周日循环 (PASS)
  - `"逢双休开空调"` -> `08:00` 开机，周六周日循环 (PASS)
  - `"每逢双休关机"` -> `08:00` 关机，周六周日循环 (PASS)
  - `"全屋下下周关空调"` -> `08:00` 全屋关机，周一循环 (PASS)
  - `"全屋双休日开空调"` -> `08:00` 全屋开机，周六周日循环 (PASS)
  - `"下下周半关机"` -> `08:30` 关机，周一循环 (PASS)
  - `"后周半开机"` -> `08:30` 开机，周一循环 (PASS)
  - `"双休日半关空调"` -> `08:30` 关机，周六周日循环 (PASS)
  - 严苛防即时误触断言（针对“下下周关空调”、“下下周开机”、“后周关空调”、“后周开机”、“双休日关空调”、“双休日开机”、“逢双休关空调”、“逢双休开机”、“每逢双休关空调”、“每逢双休开机”、“全屋下下周关机”、“全屋双休日开空调”，绝对禁止掉入 `setPower`、`turnOffAll` 或 `turnOnAll`，全部 PASS）。
- **编译与打包校验**：
  - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 警告 0 错误编译通过；
  - 运行 `./build_app.sh 1.9.92` 打包生成 `dist/HaierAC-v1.9.92-macOS.zip` (2.8MB)。

---

## 5. 发版信息与资产交付
- **版本号**：`v1.9.92`
- **Git Tag**：`v1.9.92`
- **Release 资产**：`dist/HaierAC-v1.9.92-macOS.zip`
- **SHA-256**：`ea71af15597214e4c2b006608093e556e8c96fe69ac48a4f8abc0881fadcbe5f`
- **安全敏感数据检查**：经核验，源码与文档均无敏感个人信息、真实 Token 或凭证，符合安全脱敏规范。
