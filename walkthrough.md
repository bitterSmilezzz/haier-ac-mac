# Haier AC Mac v1.9.44 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.44`
- **发版主题**：闭环自然语言「刻钟/钟头」时间解析缺陷、滤网全链路语音与快捷指令穿透、自清洁停止对称与除湿热力学双控
- **核心目标与架构演进**：
  1. **自然语言「刻钟/钟头」时间解析缺陷根治与钟点刻数定时对齐**：
     - 彻底根除中文数字预处理器（`convertChineseNumbers`）缺失“刻钟/半钟头”映射导致的重大口语解析盲区：以往“一刻钟后关机”（15分钟）、“两刻钟后关机”（30分钟）、“三刻钟后关机”（45分钟）、“半个钟头后关机”（30分钟）直接返回 `nil` 无法识别；
     - 修复此前口语“两个半钟头后关机”因正则缺少“个半钟头”未能折算为 2.5 小时（150分钟）的断裂缺陷；
     - 彻底根治钟点定时中因“一刻/三刻”被简单替换为数字“1/3”导致“十点一刻关机”被严重误判为 `10:01`（误差14分钟）、“十点三刻开机”被误判为 `10:03`（误差42分钟）的隐蔽缺陷；全面支持“十点一刻”（10:15）、“十点三刻”（10:45）、“晚上八点一刻”（20:15）与“明早七点三刻”（07:45），实现钟点刻数 100% 精准映射。
  2. **滤网健康度全链路语音与快捷指令（Shortcuts/Siri）穿透式闭环**：
     - 新增 `VoiceCommand.queryFilterHealth` 与 `VoiceCommand.queryFilterHealthAll` 语音指令，支持“查询滤网”、“滤网状态”、“滤网洁净度”、“滤网要洗吗”、“全屋滤网状态”等口语即时查询；
     - 语音胶囊与多设备协同链路结合空气动力学等效工时模型，精准反馈洁净度百分比、等效运行机时及清洗保养建议；
     - macOS 快捷指令（Shortcuts）新增 `GetFilterHealthIntent`，支持通过 Siri 或自动化捷径随时查询指定空调或主显设备的滤网健康状况。
  3. **自清洁快捷指令（StopSelfCleaningIntent）对称补全与全仓主显单源路由收敛**：
     - 在 AppIntents 中新增 `StopSelfCleaningIntent` 并注册至系统快捷指令库，与 `StartSelfCleaningIntent` 形成完整对称闭环，支持随时通过 Siri / 自动化捷径中止 56°C 蒸发器自清洁；
     - `FilterCareSheet` 弹窗初始选中设备收敛至 `model.primaryDeviceId` 单一真实可信数据源；`StatusItemController` 状态栏图标与 Tooltip 主显设备计算全面对齐 `model.primaryDeviceId`，消除多设备环境下硬编码默认设备的状态漂移。
  4. **除湿工况温湿双控热力学动力学校准**：
     - 在 `EnergyAnalyticsEngine.estimateInstantaneousPower` 的除湿工况（`.dehumidify`）中，引入室内温度热力学动态补偿：当室内温度偏高（$\ge 28^\circ\text{C}$）时动态补偿湿空气显热负荷（最高 +80W），当室内温度偏低（$\le 18^\circ\text{C}$）时拟真变频压缩机防结霜阶梯降频保护（最低 -60W），实现多维温湿度耦合仿真。

---

## 2. 关键架构变更与代码实现

### 2.1 刻钟、钟头与钟点刻数结构化解析 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)
- **根治刻钟盲区与钟点误判**：
  - 扩展 `convertChineseNumbers` 复合半小时正则匹配为 `([一二两三四五六七八九]|\d+)(?:个半小时|个钟头半|小时半|个小时半|个半钟头|钟头半)`，覆盖“两个半钟头/两钟头半”等各类口语；
  - 增设“半个钟头/半钟头”-> 30分钟，“一个半钟头/1个半钟头”-> 1.5小时；
  - 结构化规约“一刻钟”-> 15分钟、“两刻钟”-> 30分钟、“三刻钟”-> 45分钟；
  - 在钟点解析前置阶段将“点一刻/时一刻/点1刻/时1刻”归一为“点15分”，“点三刻/时三刻/点3刻/时3刻”归一为“点45分”，彻底根除 10:01 与 10:03 的时间漂移缺陷。
- **单元测试保障**：
  - 在 `VoiceCommandParserTests` 中追加 `testQuarterHourAndHourCountdown`，覆盖一刻钟、两刻钟、三刻钟、半个钟头、两个半钟头、十点一刻、十点三刻等 17 项断言，全量通过校验。

### 2.2 滤网健康度全链路穿透与 Siri 快捷指令 (`VoiceCommandParser.swift` / `VoiceCapsuleWindowController.swift` / `AppIntents.swift`)
- **指令与执行贯通**：
  - `VoiceCommandParser.parse` 增加滤网关键词识别，映射为 `.queryFilterHealth`（单设备/主设备）或 `.queryFilterHealthAll`（全屋作用域）；
  - `VoiceCapsuleWindowController` 在单设备与多设备（`executeMultiDeviceCommand`）中完整消费该指令，读取 `filterCleanlinessPercentage` 与等效运行时长并给出健康评估（“良好”或“建议及时拆洗保养”）；
  - `AppIntents` 新增 `GetFilterHealthIntent`，使得用户能够通过 Siri 询问“海尔空调滤网怎么样”直接获取状态弹窗与语音对话反馈。

### 2.3 自清洁停止对称性与全仓单源主显路由 (`AppIntents.swift` / `FilterCareSheet.swift` / `StatusItemController.swift`)
- **快捷指令对称闭环**：
  - 实现 `StopSelfCleaningIntent` 并添加至 `ACAppShortcuts`，支持用户通过 Siri 口令“用海尔空调停止自清洁”随时中断高温自清洁托管程序；
- **单源主显路由收敛**：
  - `FilterCareSheet` 中的 `currentDeviceId` 优先对齐 `model.primaryDeviceId`；
  - `StatusItemController` 的 `refreshTemperature` 图标与 Tooltip 判定将 `model.menuBarDeviceId ?? allUnifiedDevices.first?.id` 重构为 `model.primaryDeviceId`，杜绝状态漂移。

### 2.4 除湿工况多维温湿动力学补偿 (`EnergyAnalyticsEngine.swift`)
- 在 `EnergyAnalyticsEngine.estimateInstantaneousPower` 中，`.dehumidify` 模式在多维湿度曲线（潜热负荷）的基础上，融合室内温度显热负荷与防结霜降频补偿：
  - 酷热高温湿空气显热补偿：$\ge 28^\circ\text{C}$ 时最高补偿 +80W；
  - 阴冷低温蒸发器防霜降频：$\le 18^\circ\text{C}$ 时阶梯下调 -60W；
  - 钳制功率在 [200.0, 730.0] W 物理合理范围。

---

## 3. 构建、测试与打包验证闭环
- **全链路独立断言校验**：
  - 针对刻钟倒计时、半钟头倒计时、钟点刻数定时、滤网健康度语音查询、全屋滤网状态、否定意图插字安全防线等共 25 项关键断言运行独立测试套件，全部 100% 通过（`🎉 ALL 25 VERIFICATION ASSERTIONS PASSED 100%!`）；
- **本地编译验证**：
  - 运行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 错误编译通过（`Build complete!`）；
- **应用打包与签名**：
  - 运行 `./build_app.sh 1.9.44`，成功构建并签名 `dist/HaierAC.app`（含桌面小组件扩展），并生成发布压缩包 `dist/HaierAC-v1.9.44-macOS.zip`（2.6MB）。

---

## 4. 敏感数据安全审计
- 全仓扫描确认无真实手机号、明文密码、第三方 Secret Token 或私人凭据提交。
