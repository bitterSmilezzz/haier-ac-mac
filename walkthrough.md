# Haier AC Mac v1.9.61 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.61`
- **发版主题**：闭环计划调度取消与暂停动作否定防线、单设备状态栏调度管理矩阵及自动风速能效动力学
- **核心目标与架构演进**：
  1. **外部 Code Review 缺陷闭环 —— 计划调度取消/暂停/恢复否定意图防线加固 (`VoiceCommandParser.swift`)**：
     - 彻底修复此前动作否定正则仅拦截开机/关机动词，导致“千万别取消定时”、“不要取消定时任务”、“别给我暂停定时”、“不要恢复定时”等否定口语穿透为实际执行动作的隐患；
     - 引入专用 `containsNegativeForAction(negativePrefixes:actions:maxInsertDistance: 10)`，覆盖单机与全屋范围，完美支持口语中插入至多 10 字符修饰词的否定表达，严密保护用户既定计划调度。
  2. **重复调度标签计算引擎架构收敛与复合星期拓展 (`AppModel.swift` / `VoiceCommandParser.swift` / `AppIntents.swift`)**：
     - 在 `AppModel` 提取统一的 `nonisolated public static func formatRepeatWeekdaysLabel(_ repeatWeekdays: [Int]) -> String?`，彻底消除 `ScheduledAction.repeatLabel` 与 `BedtimeSchedule.repeatLabel` 的重复实现；
     - 全链路支持高频复合星期周期：新增“周四至周六”（`[5, 6, 7]`）、“周五至周六”（`[6, 7]`）、“周二至周日”（`[1, 3, 4, 5, 6, 7]`）、“周三至周日”（`[1, 4, 5, 6, 7]`）；
     - `AppModel` 增设单设备调度状态切换接口 `setScheduledActionsEnabled(for deviceId: String, enabled: Bool) -> Int`。
  3. **自主架构优化 1 —— macOS 状态栏单设备计划调度全景控制矩阵 (`StatusItemController.swift`)**：
     - 在状态栏设备列表的二级子菜单中新增设备专属「⏱ 计划调度...」子菜单；
     - 直观罗列该设备当前生效与暂停的任务，支持单任务悬浮快速「⏸ 暂停」/「▶️ 恢复」/「🗑️ 取消」；
     - 提供该设备专属的一键「⏸ 暂停该设备所有定时任务」、「▶️ 恢复该设备所有定时任务」与「🗑️ 取消该设备所有定时任务」批量控制。
  4. **自主架构优化 2 —— 热物理自适应风速能效动力学校准 (`EnergyAnalyticsEngine.swift`)**：
     - 瞬时功率估算 `estimateInstantaneousPower` 中全面升级自动风速的 `windOffset` 附加功耗动力学；
     - 告别固定 40W 经验粗糙值：除湿工况锁定 25W 微风；送风工况维持 50W 中风；制冷/制热基于 `|indoor - target|` 温差引入 20W ~ 120W 连续线性动力学阻尼，实现能耗与真实变频空调工况的高度贴合。

---

## 2. 关键架构变更与代码实现

### 2.1 计划调度取消/暂停/恢复动作否定防线
- **`VoiceCommandParser.swift` 防御加固**：
  - 新增专用辅助函数：
    ```swift
    private func containsNegativeForAction(
        negativePrefixes: [String] = ["千万别", "千万不要", "绝不要", "切莫", "切勿", "不要", "不用", "别", "甭", "休要", "莫要", "免了", "无须", "无需"],
        actions: [String],
        maxInsertDistance: Int = 10
    ) -> Bool
    ```
  - `isCancelSchedule`：接入 `containsNegativeForAction(actions: ["取消", "清除", "删除", "撤销"])`，拦截“千万别取消定时”、“不要取消定时任务”；
  - `isPauseSchedule`：接入 `containsNegativeForAction(actions: ["暂停", "挂起", "停止"])`，拦截“别给我暂停定时”；
  - `isResumeSchedule`：接入 `containsNegativeForAction(actions: ["恢复", "继续", "开启"])`，拦截“千万不要恢复定时任务”；
  - `negativeActionRegex` 拓展取消类动词 `取消|清除|删除|撤销`。

### 2.2 重复调度标签计算引擎架构收敛与复合星期拓展
- **`AppModel.swift` 标签收敛**：
  - 提取 `nonisolated public static func formatRepeatWeekdaysLabel(_ repeatWeekdays: [Int]) -> String?`；
  - `ScheduledAction.repeatLabel` 与 `BedtimeSchedule.repeatLabel` 统一调用收敛接口；
  - 拓展支持 `[5, 6, 7]` ("周四至周六")、`[6, 7]` ("周五至周六")、`[1, 3, 4, 5, 6, 7]` ("周二至周日")、`[1, 4, 5, 6, 7]` ("周三至周日")。
- **`VoiceCommandParser.swift` / `AppIntents.swift` 全链路解析**：
  - 自然语言解析与 `ScheduleACPowerIntent` 完整贯通上述复合星期周期映射。

### 2.3 macOS 状态栏单设备计划调度全景控制矩阵
- **`StatusItemController.swift` 架构扩展**：
  - 在每个设备的二级菜单 `devSubmenu` 中构建专属 `devScheduleMenu`；
  - 罗列该设备绑定的所有任务，点击或二级悬浮子菜单提供快捷单任务控制；
  - 提供单设备批处理 action：`pauseDeviceSchedulesFromMenu`、`resumeDeviceSchedulesFromMenu`、`cancelDeviceSchedulesFromMenu`。

### 2.4 热物理自适应风速能效动力学
- **`EnergyAnalyticsEngine.swift` 工况细化**：
  ```swift
  case "自动":
      switch mode {
      case .dehumidify:
          windOffset = 25.0
      case .fan:
          windOffset = 50.0
      case .cool, .heat, .auto:
          let tempDiff = abs(indoorTemp - targetTemp)
          let clampedDiff = max(0.0, min(5.0, tempDiff))
          windOffset = 20.0 + (clampedDiff / 5.0) * 100.0
      }
  ```

---

## 3. 验证与测试闭环
- **单元测试与端到端断言**：
  - 在 `VoiceCommandParserTests.swift` 中新增用例，并通过直接编译测试驱动器验证：
    1. 取消定时否定动作防御验证 ("千万别取消定时", "不要取消定时任务", "别给我取消定时") ✅
    2. 暂停定时否定动作防御验证 ("别给我暂停定时", "千万不要暂停定时任务") ✅
    3. 恢复定时否定动作防御验证 ("千万不要恢复定时", "不要恢复定时任务") ✅
    4. 复合星期周期解析验证 ("周四至周六" -> `[5, 6, 7]`, "周五至周六" -> `[6, 7]`, "周二至周日" -> `[1, 3, 4, 5, 6, 7]`, "周三至周日" -> `[1, 4, 5, 6, 7]`) ✅
    5. 重复星期标签收敛一致性验证 (`AppModel.formatRepeatWeekdaysLabel`) ✅
    6. 自动风速能效动力学功率自洽验证 (除湿 25W, 送风 50W, 大温差 120W, 小温差 20W) ✅
- **编译与静态分析**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` 0 警告 0 错误编译通过。
- **发布构建与产物校验**：
  - 执行 `./build_app.sh 1.9.61`，打包签名产出：
    - `dist/HaierAC.app`
    - `dist/HaierAC-v1.9.61-macOS.zip` (大小: 2,847,887 bytes)
    - SHA256 校验和：`1bbb647355bddd64769e18cd1cd5d4a7c40c8453b08178f54f7ce0d5a8f29f33`
