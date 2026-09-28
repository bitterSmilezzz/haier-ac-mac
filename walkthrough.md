# Haier AC Mac v1.9.62 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.62`
- **发版主题**：闭环周期重复调度大一统解析引擎、单设备状态栏调度与倒计时全对称设计及变频能耗超频平滑过渡模型
- **核心目标与架构演进**：
  1. **周期重复调度全链路统一解析引擎与全星期范围扩展 (`VoiceCommandParser.swift` / `AppModel.swift` / `AppIntents.swift` / `VoiceCommandParserTests.swift`)**：
     - **公共引擎抽离**：在 `VoiceCommandParser` 中提取公共入口 `public static func parseRepeatWeekdays(_ text: String) -> (weekdays: [Int], label: String)?`，彻底消除 `VoiceCommandParser` 与 `AppIntents` 中两处 60+ 行的重复代码分支，保证语音交互与 Siri Shortcuts 100% 语义严密对齐；
     - **全量支持“周一至周日”7天全周调度**：补齐“周一至周日/周一到周日/星期一到星期天/礼拜一到礼拜天”（`[1, 2, 3, 4, 5, 6, 7]`），彻底根除口语“周一至周日晚上10点关空调”被降级为单次定时并在触发一次后永久销毁的缺陷；
     - **泛化拓展短周期连续星期范围**：新增“周二至周三”（`[3, 4]`）、“周三至周四”（`[4, 5]`）、“周四至周五”（`[5, 6]`）、“周日至周一”（`[1, 2]`）、“周六至周一”（`[1, 2, 7]`），并在 `AppModel.formatRepeatWeekdaysLabel` 中对齐自然语言中文映射；
     - **即时开机防线接入**：在 `hasTimingOrCountdownIntent` 中全面接入 `parseRepeatWeekdays` 判定，严密防守所有周期口语在省略“定时”二字时误穿透为即时开机；在 `ACAppShortcuts` 中注册“周一至周日定时开机/关机”系统短语。
  2. **macOS 状态栏单设备计划调度管理矩阵与快捷倒计时全对称设计 (`StatusItemController.swift`)**：
     - **单设备与多设备全景对称**：在单设备运行工况控制流中，无缝补齐专属「⏱ 快捷倒计时...」子菜单（30分/1小时/2小时后关机，晨间过渡关机45分钟，30分/1小时后开机预冷/预热）；
     - **单设备计划调度全生命周期管理**：新增单设备专属「⏱ 计划调度...」子菜单，直观罗列该设备所有生效中与已暂停任务，支持二级悬浮快速暂停/恢复/取消单任务，并提供该设备一键暂停/恢复/取消所有任务的快捷批处理能力，为单空调用户带来一致且优雅的原生 macOS 交互体验。
  3. **变频能耗动力学超频与 PTC 辅助电热连续过渡阻尼模型 (`EnergyAnalyticsEngine.swift`)**：
     - **双线性连续过渡动力学**：重构 `estimateInstantaneousPower` 中的酷暑高温超频补偿（`heatBoost`）与严寒低温 PTC 电辅热补偿（`coldBoost`）；
     - **消除阶跃突变断崖**：制冷工况在 `indoor >= 28.0°C` 与 `delta >= 4.0°C` 区间平滑线性过渡介入，消除 30°C/5°C 时的 100W 硬阶跃突变；制热工况在 `indoor <= 17.0°C` 与 `delta >= 4.0°C` 区间平滑线性过渡介入，消除 15°C/5°C 时的 120W 硬阶跃突变；
     - **全模式物理自洽对称**：在 `.auto` 模式的制冷与制热分支中同步对齐该平滑连续动力学，真实拟真变频压缩机与电辅热微调工况，提供平滑自洽的瞬时电功率曲线。

---

## 2. 关键架构变更与代码实现

### 2.1 周期重复调度大一统解析引擎
- **`VoiceCommandParser.swift` 架构解耦**：
  ```swift
  public static func parseRepeatWeekdays(_ text: String) -> (weekdays: [Int], label: String)? {
      // 统一收敛“工作日”、“周末”、“每天”、“周一至周日”、“周一至周五”以及所有复合星期范围
  }
  ```
- **`AppIntents.swift` 彻底消除冗余**：
  - `ScheduleACPowerIntent` 移除 60+ 行 `if/else` 重复解析，直接调用 `VoiceCommandParser.parseRepeatWeekdays(repeatDays)`；
  - `ACAppShortcuts` 注册“用海尔空调周一至周日定时开机/关机”。
- **`AppModel.swift` 中文标签同步补齐**：
  - `formatRepeatWeekdaysLabel` 扩充对 `[1..7]`（"周一至周日"）、`[3, 4]`（"周二至周三"）、`[4, 5]`（"周三至周四"）、`[5, 6]`（"周四至周五"）、`[1, 2]`（"周日至周一"）、`[1, 2, 7]`（"周六至周一"）的原生友好映射。

### 2.2 macOS 状态栏单设备全景对称控制
- **`StatusItemController.swift` 交互对称完善**：
  - 单设备模式下补全 `buildDeviceCountdownSubmenu(for: dev)`，提供关机与预冷/预热的倒计时快捷项；
  - 单设备模式下挂载 `buildDeviceScheduleSubmenu(for: dev)`，单任务与批量调度控制一应俱全。

### 2.3 变频能耗超频与 PTC 电辅热连续过渡动力学
- **`EnergyAnalyticsEngine.swift` 双线性平滑阻尼**：
  ```swift
  let heatBoost: Double = {
      guard indoorTemp >= 28.0 && delta >= 4.0 else { return 0.0 }
      let indoorFactor = min(1.0, (indoorTemp - 28.0) / 4.0)
      let deltaFactor = min(1.0, (delta - 4.0) / 3.0)
      return indoorFactor * deltaFactor * 100.0
  }()

  let coldBoost: Double = {
      guard indoorTemp <= 17.0 && delta >= 4.0 else { return 0.0 }
      let indoorFactor = min(1.0, (17.0 - indoorTemp) / 4.0)
      let deltaFactor = min(1.0, (delta - 4.0) / 3.0)
      return indoorFactor * deltaFactor * 120.0
  }()
  ```

---

## 3. 验证与测试闭环
- **单元测试与端到端断言**：
  - 在 `VoiceCommandParserTests.swift` 中新增 `testUnifiedRepeatWeekdayEngine`，编译运行通过 12 项关键断言：
    1. 周一至周日全周解析验证 ("周一至周日", "周一到周天", "星期一到星期日") -> `[1, 2, 3, 4, 5, 6, 7]` ✅
    2. 短周期连续星期范围解析验证 ("周二至周三" -> `[3, 4]`, "周三至周四" -> `[4, 5]`, "周四至周五" -> `[5, 6]`, "周日至周一" -> `[1, 2]`, "周六至周一" -> `[1, 2, 7]`) ✅
    3. `AppModel.formatRepeatWeekdaysLabel` 标签一致性对齐验证 ✅
    4. 省略“定时”二字时的周期口令防即时开机穿透验证 ("全屋周一至周日晚上10点开机", "周二至周三早上7点开空调") ✅
- **编译与静态分析**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` 0 警告 0 错误编译通过。
- **发布构建与产物校验**：
  - 执行 `./build_app.sh 1.9.62`，打包签名产出：
    - `dist/HaierAC.app`
    - `dist/HaierAC-v1.9.62-macOS.zip` (大小: 2,850,025 bytes)
    - SHA256 校验和：`e9e9b628acab17d0096c17b536cdc50fcf7c99a03f9af0665161b24c3e9c552b`
