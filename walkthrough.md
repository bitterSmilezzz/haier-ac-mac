# Haier AC Mac v1.9.93 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.93`
- **发版主题**：闭环自然口语大后周/逢双休/单休调度大一统引擎、防即时误触全景加固、静音0档微风原语状态栏与模型全域自洽、Siri全屋温控/模式/滤网看板全域贯通
- **核心目标与架构演进**：
  1. **远期跨周与休假周期循环调度大一统与防即时误触加固 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **大后周/大后个周自然周期调度纳管**：在 `parseBaseRepeatWeekdays` 中新增“大后周/大后个周/大后星期/大后个星期/大后礼拜/大后个礼拜”完整映射体系，映射为周一基准（`[2]`），默认 08:00，生成 `.scheduleRepeatPower` 循环调度指令；
     - **逢双休/逢单休/单休日口语大一统调度**：将“逢双休”映射至周末（`[1, 7]`），将“逢单休/单休日”精准映射至周日（`[1]`），彻底支持国内家庭常见的单休与轮休排班习惯；
     - **口语半点时相归一流水线 (`convertChineseNumbers`)**：扩充 15 组自然半点映射（如“大后周半”->“大后周8点30分”，“逢双休半”->“逢双休8点30分”，“逢单休半”->“逢单休8点30分”，“单休日半”->“单休日8点30分”等），统一对齐 08:30 时相解析；
     - **全景防即时误触前置语义防护 (`hasTimingOrCountdownIntent`)**：将大后周、逢双休、逢单休、单休日及其半点前缀全部纳管至一级前置拦截网，杜绝“大后周关空调”、“逢双休开机”、“单休日关空调”穿透至即时开关机；
     - **单元测试 100% 满分覆盖**：在 `VoiceCommandParserTests.swift` 中新增 `testFarFutureWeekAndQuietWindAndAllScopeV1993`，包含 17 组单机与全屋调度、半点归一、静音 0 档及严苛防即时误触断言，全部通过。
  2. **静音 0 档原生硬件原语状态栏与设备模型全域自洽 (`VoiceCommandParser.swift` / `AppModel.swift` / `StatusItemController.swift`)**：
     - **口语解析静音 0 档风速闭环 (`VoiceCommandParser.parseWindSpeed`)**：纳管“0档”、“零档”、“第0档”、“第零档”、“风速0”、“风速零”、“静音档”、“静音风”等原生口语，映射至“微风”档位；
     - **状态栏展示与设备模型风速归一消除撕裂 (`StatusItemController.formatDisplayWindSpeed` / `AppModel.normalizeWindSpeed`)**：修复历史遗留的将 0 档误映射为“自动风”的语义撕裂问题，统一将 `0档`、`零档`、`0`、`level0`、`gear0` 等对齐归一为“微风”，与 `EnergyAnalyticsEngine` 的 15W 微风维持功率和 0.60 滤网低风阻因数达成全仓 100% 自洽；
     - **自动风速收敛**：“自”/“auto”保留为真正的“自动风”，语义划分界限清晰严密。
  3. **Siri / 快捷指令全屋温控、运行模式与滤网健康度全景看板贯通 (`AppIntents.swift` / `AppModel.swift`)**：
     - **`SetACTemperatureIntent` 全屋贯通**：支持识别 `deviceName` 中“全”/“所有”关键字，一键调用 `AppModel.setTemperatureAll` 批量设定全屋在线空调温度；
     - **`SetACModeIntent` 全屋贯通与底层 API 补全**：`AppModel` 新增 `setMode(deviceIds:mode:)` 与 `setModeAll(mode:)` API；`SetACModeIntent` 识别“全”/“所有”时一键批量下发全屋运行模式，支持制冷、制热、除湿、送风、自动等全部工况；
     - **`GetACTemperatureIntent` 全屋室温看板汇总**：支持全屋查询，自动统计并汇报全屋平均室内温度以及各在线空调当前测得的室温明细分布；
     - **`GetFilterHealthIntent` 全屋滤网健康度全景看板**：当指定“全屋”或“所有”时，自动遍历全屋所有空调设备，汇总全屋平均洁净度、各设备机时与洁净百分比，并智能检测低于 20% 的重度污染滤网给出保养警示建议。

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
   - **远期跨周与单休调度误穿透至立即开关机隐患 (P0/P1)**：口语“大后周关空调”、“逢双休开机”、“单休关机”等因缺少单星期数字导致前置防护脱靶，直接穿透至立即开关机。本版本建立大一统多时态识别与语义防御管线，杜绝任何误触；
   - **静音 0 档原生硬件原语在状态栏与模型中的语义撕裂 (P1)**：`v1.9.92` 在能耗与滤网引擎中将 0 档归一为 15W 微风，但状态栏和模型风速归一却将其误展示为“自动风”。本次彻底对齐收敛至微风；
   - **Siri 快捷指令全屋温控/模式/滤网能力缺失 (P1/P2)**：此前 `SetACTemperatureIntent`、`SetACModeIntent`、`GetACTemperatureIntent` 与 `GetFilterHealthIntent` 仅支持单设备或未打通全屋批量控制与看板汇总。本次全量升级打通。

---

## 3. 关键架构变更与代码实现

### 3.1 远期跨周与休假自然调度大一统与防即时误触加固
- **`VoiceCommandParser.swift` 远期周与单休识别**：
  ```swift
  // 自然语言口语“大后周/大后个周/大后星期/大后礼拜”调度（映射至周一基准 [2]） (v1.9.93)
  if text.contains("大后周") || text.contains("大后个周") || text.contains("大后星期") || text.contains("大后个星期") ||
     text.contains("大后礼拜") || text.contains("大后个礼拜") {
      return ([2], "每周一")
  }

  // 自然语言口语“逢双休/单休/单休日”调度 (v1.9.93)
  if text.contains("双休日") || text.contains("逢双休") || text.contains("每逢双休") {
      return ([1, 7], "周末")
  }
  if text.contains("逢单休") || text.contains("每逢单休") || text.contains("单休日") {
      return ([1], "周日")
  }
  ```
- **`hasTimingOrCountdownIntent` 前置语义拦截**：
  全面纳管“大后周”、“逢双休”、“逢单休”、“单休日”等及其半点时相口语，杜绝误触立即开关机。

### 3.2 静音 0 档原生硬件原语状态栏与设备模型全域自洽
- **`StatusItemController.swift` 与 `AppModel.swift`**：
  ```swift
  // 状态栏风速格式化与模型归一
  if speed.contains("0") || speed.contains("零") || speed.contains("微") || speed.contains("静音") {
      return "微风"
  }
  ```

### 3.3 Siri/快捷指令全屋控制与看板贯通
- **`AppIntents.swift` 全屋分流与看板**：
  ```swift
  // SetACTemperatureIntent:
  if isAll {
      let count = model.setTemperatureAll(temperature: temperature)
      return .result(dialog: "已将全屋 \(count) 台空调温度统一设为 \(tempStr) 度")
  }

  // SetACModeIntent:
  if isAll {
      let count = model.setModeAll(mode: targetMode)
      return .result(dialog: "已将全屋 \(count) 台空调统一切换为「\(modeName)」模式")
  }

  // GetFilterHealthIntent:
  if isAll {
      let devices = model.allUnifiedDevices
      // 汇总全屋平均洁净度与各设备明细
      return .result(dialog: "全屋 \(devices.count) 台空调平均滤网洁净度 \(avgPct)%（\(summaries)），\(advice)")
  }
  ```

---

## 4. 验证与测试结果

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增并校验端到端单元测试用例（17 组断言 100% PASS）：
  - `"大后周关空调"` -> `08:00` 关机，周一循环 (PASS)
  - `"大后个周开机"` -> `08:00` 开机，周一循环 (PASS)
  - `"逢双休关空调"` -> `08:00` 关机，周末循环 (PASS)
  - `"逢单休开机"` -> `08:00` 开机，周日循环 (PASS)
  - `"单休日关机"` -> `08:00` 关机，周日循环 (PASS)
  - `"大后周半关空调"` -> `08:30` 关机，周一循环 (PASS)
  - `"逢双休半开机"` -> `08:30` 开机，周末循环 (PASS)
  - `"逢单休半开机"` -> `08:30` 开机，周日循环 (PASS)
  - 静音 0 档风速口语解析（`"开0档"`, `"风速0"`, `"调到零档"`, `"静音档开机"`, `"静音风"` -> `"微风"`）(PASS)
  - 严苛防即时误触断言（针对“大后周关空调”、“大后个周开机”、“逢双休关空调”、“逢单休开机”、“单休日关机”、“逢双休半开机”，绝对禁止掉入 `setPower`、`turnOffAll` 或 `turnOnAll`，全部 PASS）。
- **编译与打包校验**：
  - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 警告 0 错误编译通过；
  - 运行 `./build_app.sh 1.9.93` 打包生成 `dist/HaierAC-v1.9.93-macOS.zip` (2.8MB)。

---

## 5. 发版信息与资产交付
- **版本号**：`v1.9.93`
- **Git Tag**：`v1.9.93`
- **Release 资产**：`dist/HaierAC-v1.9.93-macOS.zip`
- **SHA-256**：`c5ad899430678ad5db0d27732f0fbbf52a482db64a255bdd0741e25b4b4c23d9`
- **安全敏感数据检查**：经核验，源码与文档均无敏感个人信息、真实 Token 或凭证，符合安全脱敏规范。
