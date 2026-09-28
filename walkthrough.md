# Haier AC Mac v1.9.59 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.59`
- **发版主题**：闭环自然语言扩展复合星期周期定时调度、自动风速热物理自适应滤网动力学、macOS 状态栏单项任务暂停/恢复切换及全屋倒计时对称
- **核心目标与架构演进**：
  1. **自然语言“周一至周三/周二至周五/周五至周日/周末三天”扩展复合星期周期定时全链路闭环 (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `VoiceCommandParserTests`)**：
     - **彻底补齐多日复合工作与周末周期口语解析**：全量支持“周一到周三/周一至周三/礼拜一到礼拜三/星期一到星期三”（`[2, 3, 4]`, "周一至周三"）、“周二到周五/周二至周五/礼拜二到礼拜五/星期二至星期五”（`[3, 4, 5, 6]`, "周二至周五"）以及“周五到周日/周五至周日/周五周六周日/周末三天/礼拜五到礼拜天”（`[1, 6, 7]`, "周五至周日"）；彻底解决家庭中前半周办公、周五延展至周末的多日特定周期调度被误判为单次任务且执行一次即被销毁的缺陷；
     - **调度模型 `repeatLabel` 中文优雅对齐**：在 `ScheduledAction.repeatLabel` 与 `BedtimeSchedule.repeatLabel` 中同步增设 `[2, 3, 4]`、`[3, 4, 5, 6]` 与 `[1, 6, 7]` 的自然语言中文映射，彻底取代原机械拼接描述；
     - **全屋作用域与前缀守卫加固**：在 `hasTimingOrCountdownIntent` 中纳入“周一到/周一至”、“周二到/周二至”、“周五到/周五至”、“周末三天”等，确保在用户省略“定时”二字时（如“周五到周日晚上10点开空调”），绝不会被提前误判拦截为即时开机；否定动作正则精准防御“千万别周五到周日开机”、“不要周一至周三关空调”。
  2. **空气动力学滤网健康算法升级 —— 自动风速热物理自适应通量动力学校准 (`AppModel.calculateFilterWearFactor`)**：
     - 在 `calculateFilterWearFactor` 中，彻底重构自动风速（`speed` 为自动）下的固定 `1.00` 粗糙模型，引入基于室内温度温差的热物理自适应风量动力学（Adaptive Auto-Wind Dynamics）；
     - 当空调设为自动风速时：大温差重载工况（`|indoor - target| >= 4.0°C`）室内风机微电脑全速拉升高风运转，等效 `windFactor` 动态自适应校准为 `1.30`；温差微小接近恒温稳态（`|indoor - target| <= 0.8°C`）自动降档为静音低风微运转，等效 `windFactor` 动态调优为 `0.75`；平稳过渡与无温感时维持中性 `1.00` 基准，彻底消除以往自动风速下大负荷低估与稳态高估的算法误差。
  3. **macOS 原生状态栏全景调度感知升级 —— 单项任务临时暂停/恢复快捷切换与全屋倒计时对称 (`StatusItemController`)**：
     - **单项任务快捷暂停/恢复切换**：在状态栏计划任务列表的二级子菜单中，新增「⏸ 暂停此定时任务」/「▶️ 恢复此定时任务」快捷切换项，支持用户在短期外出或临时不需要时一键暂停调度，免除取消删除后重新配置的繁琐；主菜单列表对处于暂停状态的任务增加清晰直观的 `[已暂停]` 状态标识；
     - **全屋快捷倒计时全对称**：在全屋快捷开机倒计时中增设「❄️ 全屋 2 小时后开机预冷/预热」，与现有的全屋 30分/1小时/2小时关机倒计时达成 100% 动作对称。
  4. **Siri 快捷指令与 AppIntents 复合周期调度对齐 (`AppIntents.swift`)**：
     - `ScheduleACPowerIntent` 的 `repeatSchedule` 参数同步扩充对“周一至周三”、“周二至周五”、“周五至周日”的识别解析；并在 `ACAppShortcuts` 注册“周五至周日定时开机”、“周一至周三定时开机”等高频系统短语。
  5. **单元测试体系全面扩充 (`VoiceCommandParserTests`)**：
     - 新增 `testExtendedMultiWeekdayScheduleParsing` 详尽用例，全面覆盖复合星期单机、全屋作用域、否定防误触与即时开机拦截边界。

---

## 2. 关键架构变更与代码实现

### 2.1 扩展复合星期周期定时调度 (`VoiceCommandParser.swift` / `VoiceCapsuleWindowController.swift`)
- **意图模式识别与指令建模**：
  - 在 `parseScheduleOrCountdown` 的 `repeatInfo` 闭包中扩充循环周期修饰语规则：
    - `周一到周三` / `周一至周三` / `星期一到星期三` / `礼拜一到礼拜三` 对应 `[2, 3, 4]`，标签 `"周一至周三"`；
    - `周二到周五` / `周二至周五` / `星期二到星期五` / `礼拜二到礼拜五` 对应 `[3, 4, 5, 6]`，标签 `"周二至周五"`；
    - `周五到周日` / `周五至周日` / `星期五到星期天` / `周五周六周日` / `周末三天` 对应 `[1, 6, 7]`，标签 `"周五至周日"`；
  - 在 `hasTimingOrCountdownIntent` 中纳入 `"周一到"`, `"周一至"`, `"周二到"`, `"周二至"`, `"周五到"`, `"周五至"`, `"周末三天"`，彻底杜绝省略“定时”二字时被误判为即时开机动作；
  - 否定动作正则与动作否定机制覆盖“千万别周五到周日开机”、“不要周一至周三关空调”、“别周二到周五定时开机”。

### 2.2 自动风速热物理自适应滤网动力学校准 (`AppModel.swift`)
- **热物理通量自适应**：
  - 在 `calculateFilterWearFactor` 中，当 `speed` 为自动时，基于室内温度与设定温度差值 `|indoor - target|` 动态求取风扇通量；
  - `|indoor - target| >= 4.0°C` 时采用 `1.30`，`|indoor - target| <= 0.8°C` 时采用 `0.75`，常规区间维持 `1.00`，达成全气候自洽。

### 2.3 状态栏单项任务暂停/恢复切换与全屋倒计时对称 (`StatusItemController.swift`)
- **单项任务临时暂停/恢复**：
  - 在任务二级子菜单中加入「⏸ 暂停此定时任务」/「▶️ 恢复此定时任务」，绑定 `toggleSingleScheduleEnabledFromMenu`，调用 `model.setScheduledActionEnabled`；
  - 菜单标题增加 `[已暂停]` 视觉反馈，并在全屋开机倒计时菜单中增加「❄️ 全屋 2 小时后开机预冷/预热」。

### 2.4 Siri 快捷指令与周期调度体系升级 (`AppIntents.swift`)
- **`ScheduleACPowerIntent` 支持复合周期**：
  - `repeatSchedule` 参数智能解析识别“周一至周三”、“周二至周五”、“周五至周日”；
  - 在 `ACAppShortcuts` 中注册“周五至周日定时开机”、“周五至周日定时关机”、“周一至周三定时开机”等高频系统短语。

---

## 3. 构建、测试与打包验证闭环
- **底层编译与语法校验**：
  - 运行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` 与 `swift build -c release`，全模块编译 100% 通过（Build complete!）；
- **单元测试扩充与验证**：
  - 在 `VoiceCommandParserTests.swift` 中新增 `testExtendedMultiWeekdayScheduleParsing`，包含 7 项测试断言与否定防误触验证；
- **应用打包与代码签名**：
  - 执行 `./build_app.sh 1.9.59` 打包，小组件（沙盒 + Application Support 只读例外）与主应用代码签名顺利完成；
  - 产出安装包：`dist/HaierAC-v1.9.59-macOS.zip`。
