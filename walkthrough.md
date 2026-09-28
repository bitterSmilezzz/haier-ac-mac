# Haier AC Mac v1.9.55 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.55`
- **发版主题**：自然语言跨日钟点定时开/关机与深宵时区校准、Siri 快捷指令计划调度、macOS 状态栏单项调度管理及滤网动力学
- **核心目标与架构演进**：
  1. **自然语言“明天/明早/明晚/次日/后天”跨日绝对钟点定时开/关机与深宵时区校准 (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `VoiceCommandParserTests`)**：
     - **跨日绝对钟点定时防误定当天缺陷闭环**：彻底修复白天（如 14:00）说“明天晚上10点关机”或“明晚10点关机”时，因目标钟点 22:00 大于当前时刻，旧逻辑中仅依赖 `targetDate <= Date()` 导致未加 1 天、被错误定在“今天晚上 22:00”严重违背用户“明天”意图的重大缺陷；全链路引入“明天/明早/明晚/次日/后天/大后天”显式跨日计算，单机、全屋及多设备协同三条执行路径 100% 对齐；
     - **深宵 9~11 点时区精准规整与凌晨时段保持**：修复口语“半夜9/10/11点”或“午夜9/10/11点”因遗漏深夜时区规则导致被误解析为上午时段的缺陷，精准折算为 21:00 ~ 23:00 深夜时段，同时保持“半夜1点/2点”为 01:00/02:00；
     - **定时开机默认 60 分钟对称性补齐与否定防线闭环**：为“定时开机”、“倒计时开机”、“预约开机”补齐默认 60 分钟延时逻辑，与定时关机达成语义对称；并在取消定时与倒计时解析层增加动作否定排斥防御，对“千万别定时开机”、“不要定时关机”坚决拦截，杜绝误触发。
  2. **Siri 快捷指令与 AppIntents 计划调度体系打通 (`AppIntents.swift`)**：
     - 新增 `CancelACSchedulesIntent`（取消空调定时），支持指定设备取消或全屋一键清空所有生效中的定时/倒计时计划任务；
     - 在 `ACAppShortcuts`（以及 macOS < 14 兼容分支）中注册高频系统短语：“用海尔空调取消定时”、“用海尔空调取消所有定时”、“取消全屋定时海尔空调”，全面接入 macOS 系统级自动化与快捷指令生态。
  3. **macOS 原生状态栏计划调度单项管理与全风量文案一致性 (`StatusItemController`)**：
     - 在状态栏右键菜单「⏱ 计划调度」独立功能区中，将计划任务升级为级联子菜单结构，展示设备名、详细执行时间并提供「❌ 取消该定时任务」独立操作，配合「🗑 取消全屋所有定时与倒计时」，实现颗粒度精确到单个任务的原生级调度管理；
     - 补齐 `formatDisplayWindSpeed` 中“极速/高速/中速/低速”别名映射，与滤网空气动力学及能耗分析引擎达成 100% 枚举一致。
  4. **滤网负荷与空气动力学无室温传感器工况动力学校准 (`AppModel.calculateFilterWearFactor`)**：
     - 在 `calculateFilterWearFactor` 中，明确区分目标温度达成维持态与室温传感器缺失工况，当 `indoorTemp == nil` 时采用标准降温基准 `1.30` 与制热标准升温基准 `1.15`，消除以往直接回退至最低维持态（1.15 / 1.05）导致的滤网负荷系统性低估偏差。

---

## 2. 关键架构变更与代码实现

### 2.1 跨日绝对钟点定时与深宵深层校准 (`VoiceCommandParser.swift` / `VoiceCapsuleWindowController.swift`)
- **显式跨日语义解析**：
  - 在 `VoiceCapsuleWindowController` 全屋、单机与多设备三处 `schedulePower` 执行分支中，解析 `spokenText` 是否包含“明天”、“明早”、“明晚”、“次日”、“明儿”或“后天”、“大后天”；
  - 动态计算基准偏移天数并同步更新任务名称前缀（如“明天 22:00 关机”），彻底杜绝当期时间误判；
  - 在 `VoiceCommandParser.parseScheduleOrCountdown` 中同步注入 `dayDesc`（“定时在 明天 22:00 关机”），界面反馈语义完全透明。
- **深宵 9~11 点时段转换**：
  - 在 `parseScheduleTime` 规范 `(normalized.contains("半夜") || normalized.contains("午夜")) && finalHour >= 9` 时自动 `finalHour += 12`。
- **取消定时动作否定隔离**：
  - 在 `isCancelSchedule` 中过滤带有开/关/停/启动动作且包含否定词的口令，防止“千万别定时开机”误匹配“别定时”而触发取消定时。

### 2.2 Siri 快捷指令与 AppIntents 计划调度体系 (`AppIntents.swift`)
- **定义 `CancelACSchedulesIntent`**：
  - 参数 `deviceName: String?`，支持按房间或全屋取消；
  - 提供友好的 Siri 交互反馈。
- **注册短语体系**：
  - `"用 \(.applicationName) 取消定时"`
  - `"用 \(.applicationName) 取消所有定时"`
  - `"\(.applicationName) 取消定时"`
  - `"取消全屋定时 \(.applicationName)"`

### 2.3 状态栏级联计划调度管理与风速别名对齐 (`StatusItemController.swift`)
- **级联计划调度子菜单**：
  - 每个计划任务展开显示所属设备、格式化执行时间；
  - 挂载 `@objc private func cancelSingleScheduleFromMenu`，单键取消并弹出操作 Toast 与刷新状态栏。
- **风速口语枚举收敛**：
  - `formatDisplayWindSpeed` 补充“极速”（强劲风）、“高速”（高风）、“中速”（中风）、“低速”（低风）。

### 2.4 滤网动力学传感器缺失工况修正 (`AppModel.swift`)
- **冷热双向无偏负荷基准**：
  - 制冷模式在 `indoorTemp == nil` 时分配 `modeFactor = 1.30`；
  - 制热模式在 `indoorTemp == nil` 时分配 `modeFactor = 1.15`；
  - 与变频能耗动力学基准 100% 对齐。

---

## 3. 构建、测试与打包验证闭环
- **底层编译与语法校验**：
  - 运行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，全模块编译 100% 通过（Build complete!）；
- **独立用例验证**：
  - 18 项专用自动化测试用例全量验证通过（ALL 18 VERIFICATION CHECKS PASSED SUCCESSFULLY!）；
- **应用打包与代码签名**：
  - 执行 `./build_app.sh 1.9.55` 打包，小组件与主应用代码签名顺利完成；
  - 产出安装包：`dist/HaierAC-v1.9.55-macOS.zip`。
