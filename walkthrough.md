# Haier AC Mac v1.9.60 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.60`
- **发版主题**：闭环计划调度批量暂停/恢复全链路、泛化复合星期周期调度引擎及自动风速工况物理自洽动力学
- **核心目标与架构演进**：
  1. **计划调度任务全生命周期管理 —— 批量暂停/恢复全链路打通 (`AppModel` / `VoiceCommandParser` / `VoiceCapsuleWindowController` / `AppIntents` / `StatusItemController`)**：
     - **AppModel 调度模型扩展**：新增 `setAllScheduledActionsEnabled(_ enabled: Bool) -> Int` 与 `setScheduledActionsEnabled(for:enabled:) -> Int`，支持一键批量暂停或恢复全屋/指定设备的所有定时任务，返回受影响的任务数并即时唤醒调度器；
     - **VoiceCommand 自然语言全链路闭环**：扩充 `.pauseSchedules`、`.pauseSchedulesAll`、`.resumeSchedules`、`.resumeSchedulesAll`，解析层精准识别“暂停定时/暂停所有定时任务/暂停全屋定时/暂停倒计时/恢复定时/恢复全屋定时/继续定时”，并受动作否定严格保护（“千万别暂停定时”）；语音胶囊实现单机、全屋与多设备三向分发与反馈；
     - **Siri 快捷指令与 AppIntents 深度集成**：新增 `PauseACSchedulesIntent` 与 `ResumeACSchedulesIntent`，并在 `ACAppShortcuts` 中注册“用海尔空调暂停定时”、“用海尔空调暂停所有定时”、“用海尔空调恢复定时”、“用海尔空调恢复所有定时”高频系统短语；
     - **macOS 状态栏原生全景感知重构**：二级子菜单新增「⏸ 暂停全屋所有定时任务」与「▶️ 恢复全屋所有定时任务」；彻底修复父级菜单与 Tooltip 将已暂停任务误算为“生效中”的统计缺陷，根据实际状态智能输出 `⏱ 计划调度 (2 生效 / 1 暂停)...` 或 `⏱ 计划调度: 全部已暂停`。
  2. **自然语言泛化复合星期周期定时调度引擎与即时误触发防线闭环 (`VoiceCommandParser` / `VoiceCommandParserTests`)**：
     - **全量覆盖高频复合星期周期**：全面支持“周三至周五/周三到周五”（`[4, 5, 6]`）、“周一至周二/周一到周二”（`[2, 3]`）、“周二至周四/周二到周四”（`[3, 4, 5]`）、“周二至周六”（`[3, 4, 5, 6, 7]`）、“周三至周六”（`[4, 5, 6, 7]`）、“周四至周日”（`[1, 5, 6, 7]`）、“周六至周日/周六到周天/星期六到星期天”（`[1, 7]`）；并在 `ScheduledAction.repeatLabel` 与 `BedtimeSchedule.repeatLabel` 对齐规范中文标签；
     - **彻底消除省略“定时”二字时误判为即时开机的严重缺陷**：在 `hasTimingOrCountdownIntent` 中全面引入任意星期范围前缀检测（覆盖“周X到/至”、“星期X到/至”、“礼拜X到/至”），彻底根除此前“全屋周三至周五早上8点开机”或“全屋周六到周日开机”穿透到 `isAllPowerOn` 立即全屋开机的重大缺陷。
  3. **空气动力学滤网健康算法升级 —— 自动风速工况物理自洽动力学校准 (`AppModel.calculateFilterWearFactor`)**：
     - 细化自动风速与空调运行模式的物理耦合：除湿工况（`.dehumidify`）因微电脑强制维持微风以防冷凝液二次蒸发，自动风速锁定微通量基准 `0.75`，消除温差带来的负荷高估；送风工况（`.fan`）无温差项，自动风速维持平稳通量 `0.85`；制冷/制热维持精准大温差与稳态自适应。

---

## 2. 关键架构变更与代码实现

### 2.1 计划调度全生命周期管理与批量暂停/恢复全链路
- **`AppModel.swift` 调度器批量控制**：
  - 新增 `setAllScheduledActionsEnabled(_ enabled: Bool) -> Int`：遍历更新 `scheduledActions`，当任务使能状态变化时更新，同步保存持久化存储并调用 `scheduleNextAction()` 重置定时器；
  - 新增 `setScheduledActionsEnabled(for deviceId: String, enabled: Bool) -> Int`：支持单设备定向批量暂停与恢复。
- **`VoiceCommandParser.swift` 语音指令建模**：
  - 扩展枚举 `VoiceCommand`：
    - `case pauseSchedules(deviceTarget: String?)`
    - `case pauseSchedulesAll`
    - `case resumeSchedules(deviceTarget: String?)`
    - `case resumeSchedulesAll`
  - 引入语义解析逻辑：
    - `isPauseSchedule`: 匹配“暂停定时/暂停所有定时/暂停定时任务/暂停倒计时/停止定时/挂起定时”；
    - `isResumeSchedule`: 匹配“恢复定时/恢复所有定时/恢复定时任务/恢复倒计时/继续定时/开启定时任务”；
    - 结合全屋目标（`isAllDevicesTarget`）与单设备目标（`deviceTarget`）分发对应 Command；
    - `negativeActionRegex` 接入暂停/恢复动词拦截，防御“千万别暂停定时”。
- **`VoiceCapsuleWindowController.swift` 调度分发与交互反馈**：
  - 调度器响应 `.pauseSchedulesAll` 与 `.resumeSchedulesAll`：执行 `model.setAllScheduledActionsEnabled`，语音胶囊反馈如“已暂停全屋所有定时任务（共 3 项）”；
  - 调度器响应 `.pauseSchedules` 与 `.resumeSchedules`：针对指定或当前设备执行 `setScheduledActionsEnabled` 并提示状态。
- **`AppIntents.swift` Siri 快捷指令与 AppShortcuts 集成**：
  - 实现 `PauseACSchedulesIntent` 与 `ResumeACSchedulesIntent`；
  - `ACAppShortcuts` 注册常用短语：“用海尔空调暂停定时”、“用海尔空调恢复定时”。
- **`StatusItemController.swift` 状态栏全景感知感知重构**：
  - 状态栏计划菜单二级菜单增加「⏸ 暂停全屋所有定时任务」与「▶️ 恢复全屋所有定时任务」；
  - 修复 Tooltip 与父级菜单统计逻辑：区分 `activeCount` 与 `pausedCount`，当所有任务均暂停时显示 `全部已暂停`，混合时显示 `(X 生效 / Y 暂停)`。

### 2.2 泛化复合星期周期调度引擎与即时误触发防护
- **复合星期语义扩展**：
  - `VoiceCommandParser.swift` 中的 `repeatInfo` 扩展任意组合：
    - `周一至周二` (`[2, 3]`)
    - `周二至周四` (`[3, 4, 5]`)
    - `周二至周六` (`[3, 4, 5, 6, 7]`)
    - `周三至周五` (`[4, 5, 6]`)
    - `周三至周六` (`[4, 5, 6, 7]`)
    - `周四至周日` (`[1, 5, 6, 7]`)
    - `周六至周日` (`[1, 7]`)
  - `ScheduledAction.repeatLabel` 与 `BedtimeSchedule.repeatLabel` 中文标签对齐映射。
- **即时开机穿透防护**：
  - 重构 `hasTimingOrCountdownIntent`：增加通配正则 `(周|星期|礼拜)[一二三四五六日天](到|至)(周|星期|礼拜)?[一二三四五六日天]`；
  - 彻底根除口语“全屋周三至周五早上8点开机”或“周六到周日开空调”在省略显式“定时”二字时被误判穿透为即时开机的严重 Bug。

### 2.3 空气动力学滤网健康算法工况物理自洽
- **`AppModel.calculateFilterWearFactor` 模式自洽**：
  - 除湿模式（`.dehumidify`）：自动风速固定微风因子 `0.75`，符合空调除湿低风速防凝露重蒸发物理特性；
  - 送风模式（`.fan`）：自动风速固定平衡因子 `0.85`，无温差驱动；
  - 制冷/制热模式（`.cool` / `.heat`）：基于温差自适应（`>= 4°C` 对应 `1.30`，`<= 0.8°C` 对应 `0.75`）。

---

## 3. 验证与测试闭环
- **逻辑断言与单元测试**：
  - 新增 `testPauseAndResumeSchedules` 验证单机/全屋暂停恢复及否定防误触；
  - 新增 `testCompoundWeekdayScheduleRanges` 验证周一至周二、周二至周四、周三至周五、周六至周日等复合范围；
  - 运行 12 项端到端断言，验证全部通过：
    1. 暂停所有定时解析验证 (pauseSchedulesAll) ✅
    2. 全屋恢复定时解析验证 (resumeSchedulesAll) ✅
    3. 单设备暂停定时解析验证 (pauseSchedules) ✅
    4. 暂停定时否定防误触验证 ✅
    5. 周三至周五复合星期解析验证 ([4, 5, 6]) ✅
    6. 周一至周二复合星期解析验证 ([2, 3]) ✅
    7. 周六至周日复合星期解析验证 ([1, 7]) ✅
    8. 复合星期省略定时防开机穿透验证 ✅
    9. 批量暂停与恢复模型状态流转验证 ✅
    10. 滤网自动风速除湿工况校准 (0.75) ✅
    11. 滤网自动风速送风工况校准 (0.85) ✅
    12. 滤网自动风速制冷大温差工况校准 (1.30) ✅
- **编译与静态分析**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` 0 警告 0 错误编译通过。
- **产物构建与代码签名**：
  - `./build_app.sh 1.9.60` 成功构建并签名：
    - `dist/HaierAC.app`
    - `dist/HaierAC-v1.9.60-macOS.zip` (SHA256 完整哈希验证)。
