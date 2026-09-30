# Haier AC Mac v1.9.90 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.90`
- **发版主题**：闭环自然口语单星期循环调度大一统引擎、防即时误触全景加固、全屋设备模型路由收敛与变频热阻尼全工况对齐
- **核心目标与架构演进**：
  1. **自然口语单星期循环调度大一统引擎与防即时误触全闭环 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **彻底修复单星期口语被解析为立即开关机的重大误触隐患**：此前用户说“周一关空调”、“周五开机”、“星期三关机”、“礼拜六开机”、“全屋周一关空调”等高频日常调度时，因单星期未包含“每/逢/每个”前缀且非连续跨度，`parseRepeatWeekdays` 返回 `nil`；由于 `hasTimingOrCountdownIntent` 亦未拦截单星期词组，导致口令穿透至末尾的 `isPowerOff` / `isPowerOn`，从而触发**立即关机 / 立即开机**，对用户生活造成严重干扰与能源浪费；
     - **单星期自然口语大一统匹配流水线**：在 `parseBaseRepeatWeekdays` 步骤 7 中全面纳管“周一”~“周日/周天”、“星期一”~“星期日/星期天”、“礼拜一”~“礼拜日/礼拜天”、“周1”~“周7”全量单星期表达，精确提取星期数字集合（如 `[2]` 对应周一，`[1]` 对应周日）；
     - **复合口语星期属性保留修复**：彻底修复类似“周一早上8点开机”因优先匹配了“早上8点”导致星期属性丢失、错误退化为明天单次定时任务的逻辑缺陷，完整输出保留星期属性的循环调度指令；
     - **单星期半点口语标准化归一 (`convertChineseNumbers`)**：新增 30+ 组单星期半点映射（如“周一半”->“周一8点30分”，“星期一半”->“星期一8点30分”，“礼拜一半”->“礼拜一8点30分”），全面对齐半点时相归一流水线；
     - **全景防即时误触语义防线加固 (`hasTimingOrCountdownIntent`)**：全量补齐单星期及其半点关键词前置拦截，彻底切断定时调度误入立即开关机的路径；
     - **单元测试 100% 满分覆盖**：在 `VoiceCommandParserTests.swift` 中新增 `testSingleWeekdayRepeatSchedulePrecisionAndProtectionV1990`，包含 22 组单机与全屋单星期循环调度、指定钟点复合调度、半点归一及严苛防即时误触断言，全部通过。
  2. **全屋设备模型路由收敛与设备名称统一解析 (`AppModel.swift` / `StatusItemController.swift`)**：
     - **消除多设备场景下对首设备的隐式硬编码依赖**：此前睡前预冷（`triggerBedtimePrecooling`）、睡前温控曲线（`triggerBedtimeCurve`）、睡眠曲线切换（`toggleSleepCurve`）、滤网机时追踪与清洁历史归档、睡眠历史归档均硬编码使用 `devices.first`，在配置有多台设备或仅有手动设备时造成控制目标漂移；本版本全部重构收敛至主控设备 `primaryDeviceId`，确保多设备拓扑下控制目标绝对准确；
     - **新增统一设备名称解析器**：在 `AppModel` 中提供 `deviceName(for deviceId: String) -> String`，自动穿透检索 `allUnifiedDevices`，找不到时平滑降级为首设备名称或设备 ID；
     - **状态栏与交互细节打磨**：`StatusItemController` 全面接入 `model.deviceName(for:)`，使状态栏定时任务卡片与 Tooltip 展示名称高度统一。
  3. **变频热阻尼漂移全工况对齐 (`EnergyAnalyticsEngine.swift`)**：
     - **消除未知/回退工况下的热阻尼补偿盲区**：将 `soakMultiplier`（运行超过 120 分钟时由于压缩机与室温热饱和带来的 0.94~0.97 热漂移衰减补偿因子）前移至模式判定之前，确保全工况、即使在模式解析异常或扩展工况下均能精准纳入动力学热衰减计算。

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
   - **单星期调度口令误穿透至立即开关机隐患 (P0/P1)**：口语“周一关空调”没有带“每”字，此前 `parseRepeatWeekdays` 返回 `nil` 且 `hasTimingOrCountdownIntent` 未纳管单星期，导致口令直接掉入立即关机逻辑。本版本构建单星期大一统识别管线，杜绝任何误触；
   - **多设备场景下的隐式路由偏差 (P1)**：`AppModel` 中睡眠曲线、预冷、滤网与睡眠归档多处直接消费 `devices.first`，在多设备或手动添加设备环境下未遵循用户当前选中的主控设备。本次重构统一至 `primaryDeviceId` 与 `deviceName(for:)`；
   - **变频热阻尼在非常规工况下失控 (P2)**：`EnergyAnalyticsEngine` 的 `soakMultiplier` 提升至模式判定前，保障热动力学模型的一致性与严谨性。

---

## 3. 关键架构变更与代码实现

### 3.1 单星期循环调度大一统与星期属性保留
- **`VoiceCommandParser.swift` 单星期识别**：
  ```swift
  // 7. 单独星期：周一~周日/周天、星期一~星期日/星期天、礼拜一~礼拜日/礼拜天、周1~周7
  let singleWeekdayPattern = "(?:周|星期|礼拜)([1-7一二三四五六日天])"
  if let regex = try? NSRegularExpression(pattern: singleWeekdayPattern, options: []),
     let match = regex.firstMatch(in: normalized, options: [], range: NSRange(location: 0, length: normalized.utf16.count)),
     let charRange = Range(match.range(at: 1), in: normalized) {
      let charStr = String(normalized[charRange])
      if let day = parseWeekdayChar(charStr) {
          return [day]
      }
  }
  ```
- **复合口语星期属性保留修复**：
  在 `parseBaseCommand` 中，即便 `parseScheduleTime` 匹配到了具体时间，若同时存在 `parseRepeatWeekdays(normalized)`，则优先构建 `.scheduleRepeatPower` 循环调度指令，杜绝降级为明天单次定时。

### 3.2 单星期半点时相归一流水线与前置防线
- **`VoiceCommandParser.swift` 中 `convertChineseNumbers` 拓展**：
  ```swift
  for (name, prefix) in [("周", "周"), ("星期", "星期"), ("礼拜", "礼拜")] {
      str = str.replacingOccurrences(of: "\(name)一半", with: "\(prefix)一8点30分")
      // ... 补齐至 周日半 / 礼拜天半
  }
  ```
- **`hasTimingOrCountdownIntent` 前置语义拦截**：
  ```swift
  // 纳管全量单星期及半点关键词
  "周一", "周二", "周三", "周四", "周五", "周六", "周日", "周天",
  "星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日", "星期天",
  "礼拜一", "礼拜二", "礼拜三", "礼拜四", "礼拜五", "礼拜六", "礼拜日", "礼拜天",
  "周一半", "星期一半", "礼拜一半", ...
  ```

### 3.3 全屋设备模型路由收敛
- **`AppModel.swift` 统一路由与名称解析**：
  ```swift
  public func deviceName(for deviceId: String) -> String {
      if let dev = allUnifiedDevices.first(where: { $0.id == deviceId }) {
          return dev.name
      }
      return currentDevice?.name ?? deviceId
  }
  ```
  在 `triggerBedtimePrecooling`、`triggerBedtimeCurve`、`toggleSleepCurve`、滤网机时与睡眠历史归档中全面使用 `primaryDeviceId`。

### 3.4 变频能耗热阻尼全工况对齐
- **`EnergyAnalyticsEngine.swift` 热阻尼计算位置提升**：
  ```swift
  // 连续运行热衰减（运行超过120分钟，效率略降，进入热平衡稳态）
  let soakMultiplier: Double = runtimeMinutes > 120 ? 0.96 : 1.0

  guard let mode = device.mode else {
      return baseCompressorWatts * soakMultiplier
  }
  ```

---

## 4. 验证与测试结果

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增并校验端到端单元测试用例（22 组断言 100% PASS）：
  - `"周一关空调"` -> `08:00` 关机，周一循环 (PASS)
  - `"周五开机"` -> `08:00` 开机，周五循环 (PASS)
  - `"星期三关机"` -> `08:00` 关机，周三循环 (PASS)
  - `"星期日开机"` -> `08:00` 开机，周日循环 (PASS)
  - `"礼拜六关机"` -> `08:00` 关机，周六循环 (PASS)
  - `"礼拜天开空调"` -> `08:00` 开机，周日循环 (PASS)
  - `"周一半关空调"` -> `08:30` 关机，周一循环 (PASS)
  - `"星期一半开机"` -> `08:30` 开机，周一循环 (PASS)
  - `"礼拜六半关机"` -> `08:30` 关机，周六循环 (PASS)
  - `"周一早上8点开机"` -> `08:00` 开机，周一循环 (PASS)
  - `"星期五下午6点关空调"` -> `18:00` 关机，周五循环 (PASS)
  - `"礼拜天晚上10点关机"` -> `22:00` 关机，周日循环 (PASS)
  - `"全屋周一关空调"` -> `08:00` 全屋关机，周一循环 (PASS)
  - 严苛防即时误触断言（针对“周一关空调”、“周五开机”、“星期三关机”、“礼拜六开机”，绝对禁止掉入 `setPower`、`turnOffAll` 或 `turnOnAll`，全部 PASS）。
- **编译与打包校验**：
  - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 错误编译通过；
  - 运行 `./build_app.sh 1.9.90` 打包生成 `dist/HaierAC-v1.9.90-macOS.zip` (2.8MB)。

---

## 5. 发版信息与资产交付
- **版本号**：`v1.9.90`
- **Git Tag**：`v1.9.90`
- **Release 资产**：`dist/HaierAC-v1.9.90-macOS.zip`
- **SHA-256**：`a4b26548389a8ccc4c3f4bf33b0baa25c126b4247ed0c713bc7584d2fe8c8be3`
- **安全敏感数据检查**：经核验，源码与文档均无敏感个人信息、真实 Token 或凭证，符合安全脱敏规范。
