# Haier AC Mac v1.9.56 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.56`
- **发版主题**：自然语言周期重复定时（每天/工作日/周末）、Siri 快捷指令计划调度闭环、macOS 状态栏快捷关机倒计时矩阵及自动模式热物理动力学校准
- **核心目标与架构演进**：
  1. **自然语言“每天/天天/工作日/周末/按星期”周期循环定时调度全链路闭环 (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `VoiceCommandParserTests`)**：
     - **周期定时误当单次任务且执行一次即被永久删除缺陷闭环**：彻底修复日常语音高频说出“每天晚上10点关机”、“天天早上8点开空调”、“工作日早上7点开机”、“周末上午9点开空调”、“周一到周五早上7点开机”、“周六周日晚上11点关空调”等周期性计划时，旧逻辑仅按单次 `.schedulePower` 解析且在执行层将 `repeatsDaily` 与 `repeatWeekdays` 全部写死为 `false` 与 `[]`，导致任务仅触发一次便被永久删除的严重缺陷；
     - **全链路引入 `scheduleRepeatPower` 周期指令与星期矩阵**：解析层精准辨识“每天/天天/每日/每晚/每早”(`repeatsDaily = true`)、“工作日/平时/周一到周五/周一至周五”(`repeatWeekdays = [2,3,4,5,6]`) 以及“周末/双休/周六周日”(`repeatWeekdays = [1,7]`)；单机、全屋与多设备三条执行流统一计算周期初始触发时刻（`initialFireDate`），在触发后自动按日/星期无缝顺延；
     - **深宵每晚时区自适应补齐与否定防线闭环**：修复“每晚11点关机”因时态规则遗漏“每晚”导致被误判为上午 11:00 的缺陷，精准归入 23:00 深夜时段，并对“千万别每天定时开机”、“不要工作日定时关机”坚决实施否定拦截。
  2. **Siri 快捷指令与 AppIntents 计划调度体系双向闭环 (`AppIntents.swift`)**：
     - 新增 `ScheduleACPowerIntent`（设置空调定时与倒计时），全面支持设定倒计时分钟数（如 30、60 分钟）、具体钟点（如 22:00）以及每天循环重复（`repeatsDaily: Bool`），支持指定单设备或全屋统一下发；
     - 在 `ACAppShortcuts` 中注册高频短语体系：“用海尔空调定时关机”、“用海尔空调倒计时关机”、“用海尔空调每天定时关机”、“海尔空调定时关机”、“海尔空调倒计时关机”，彻底补全以往 Siri 快捷指令“只能取消定时、不能创建定时”的生态不对称缺陷。
  3. **macOS 原生状态栏快捷关机倒计时矩阵与计划调度体验升级 (`StatusItemController`)**：
     - **增设「⚡️ 快捷关机倒计时」原生独立子菜单**：在状态栏「⏱ 计划调度」中提供「⏱ 30 分钟后关机」、「⏱ 1 小时后关机」、「⏱ 2 小时后关机」及「⏱ 晨间过渡关机 (45分钟)」快捷项，支持空任务状态与活跃状态一键直达设定，操作后即时弹出 Toast 反馈并刷新状态栏，无需唤起主窗口或语音即可高频操作；
     - **去重与周期重复视觉优化**：剔除计划任务列表中设备名称双重重复（`⏱ 客厅: 「客厅」22:00 关机`）的视觉瑕疵，并在任务项及详情子菜单中注入 `[每天]`、`[工作日]`、`[周末]` 周期重复标签与下次触发时间。
  4. **自动模式（.auto）无传感器工况与制冷/制热动力学热物理对称校准 (`AppModel.calculateFilterWearFactor`)**：
     - 在 `calculateFilterWearFactor` 中，彻底修复自动模式在 `indoorTemp == nil` 时直接回退至 `1.00` 维持态导致的断崖式负荷低估缺陷；
     - 联动设定目标温度智能判定热力偏向：当 `targetTemp <= 25.0` 时按夏季偏冷工况采用 `1.20` 因子，当 `targetTemp > 25.0` 时按冬季偏热工况采用 `1.10` 因子，与 `EnergyAnalyticsEngine` 的自动模式工况分配机制达成 100% 物理对称。

---

## 2. 关键架构变更与代码实现

### 2.1 循环周期定时调度全链路闭环 (`VoiceCommandParser.swift` / `VoiceCapsuleWindowController.swift`)
- **意图模式识别与指令建模**：
  - 在 `VoiceCommand` 枚举中新增 `scheduleRepeatPower(hour: Int, minute: Int, power: Bool, repeatWeekdays: [Int], repeatLabel: String)`；
  - 在 `parseScheduleOrCountdown` 中解析自然语言中的循环周期修饰语：
    - `每天/天天/每日/每晚/每早` -> `repeatWeekdays: []`, `label: "每天"`, 驱动 `repeatsDaily = true`；
    - `工作日/平时/周一到周五/周一至周五` -> `repeatWeekdays: [2, 3, 4, 5, 6]`, `label: "工作日"`；
    - `周末/双休/周六周日/周六和周日` -> `repeatWeekdays: [1, 7]`, `label: "周末"`；
  - 在 `hasTimingOrCountdownIntent` 中纳入循环周期关键词，彻底杜绝“全屋每天晚上10点关机”被 `isAllPowerOff` 粗暴拦截截断的问题。
- **初始触发时刻计算与无缝调度**：
  - 在 `AppModel` 中提供 `initialFireDate(forHour:minute:weekdays:calendar:)`，依据当前星期与目标钟点精确计算初始触发时刻，避免因“首次触发未发生”而导致调度器直接跳过当期任务；
  - `VoiceCapsuleWindowController` 中单设备、全屋与多设备三条执行流统一构造带有 `repeatsDaily` 与 `repeatWeekdays` 的 `ScheduledAction`，并在语音反馈中明确播报：“已为客厅设定：每天 22:00 关机” 或 “已为全屋设定：工作日 07:00 开机”。

### 2.2 Siri 快捷指令与 AppIntents 计划调度体系 (`AppIntents.swift`)
- **定义 `ScheduleACPowerIntent`**：
  - 参数：`powerOn: Bool`（默认 false 关机）、`countdownMinutes: Int?`（倒计时分钟）、`timeString: String?`（钟点如 22:00）、`repeatsDaily: Bool`（每天重复）、`deviceName: String?`（可选设备）；
  - 自动适配倒计时与绝对钟点双模触发；
  - 提供友好的 Siri 对话反馈与多设备全屋作用域透传。
- **注册短语体系**：
  - `"用 \(.applicationName) 定时关机"`
  - `"用 \(.applicationName) 倒计时关机"`
  - `"用 \(.applicationName) 每天定时关机"`
  - `"\(.applicationName) 定时关机"`
  - `"\(.applicationName) 倒计时关机"`
  - `"\(.applicationName) 每天定时关机"`

### 2.3 状态栏快捷关机倒计时矩阵与视觉精细化 (`StatusItemController.swift`)
- **快捷关机倒计时独立子菜单**：
  - 在状态栏右键菜单「⏱ 计划调度」独立功能区中，增设「⚡️ 快捷关机倒计时...」子菜单（包含 30 分钟、1 小时、2 小时、45 分钟预设）；
  - 支持直接单键点击设定，下发本地调度并刷新状态栏，即使当前无生效计划任务亦可一键调用。
- **设备名前缀去重与周期标签感知**：
  - 修复 `cleanActionName` 剔除与设备名完全相同的冗余前缀（如 `「客厅」`）；
  - 单项菜单展示 `[每天]` / `[工作日]` / `[周末]` 周期标签；
  - 详情子菜单注入「下次执行时间」与「周期重复」独立条目。

### 2.4 自动模式滤网动力学热物理对称校准 (`AppModel.swift`)
- **热力工况智能平衡**：
  - 当 `indoorTemp == nil` 时，自动模式不再粗暴回退至最低平衡态 `1.00`；
  - 依据 `targetTemp <= 25.0` 智能判别夏季偏冷（`modeFactor = 1.20`），`targetTemp > 25.0` 判别冬季偏热（`modeFactor = 1.10`），与 `EnergyAnalyticsEngine` 的自动模式工况统计机制达成 100% 物理对称。

---

## 3. 构建、测试与打包验证闭环
- **底层编译与语法校验**：
  - 运行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，全模块编译 100% 通过（Build complete!）；
- **独立用例验证**：
  - 18 项专用自动化测试用例全量验证通过（ALL 18 VERIFICATION CHECKS PASSED SUCCESSFULLY!）；
- **应用打包与代码签名**：
  - 执行 `./build_app.sh 1.9.56` 打包，小组件与主应用代码签名顺利完成；
  - 产出安装包：`dist/HaierAC-v1.9.56-macOS.zip`。
