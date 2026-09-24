# Haier AC Mac v1.9.38 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.38`
- **发版主题**：闭环自然语言开字模式/调温拦截缺陷、状态栏首选设备路由对齐、多设备状态聚合查询与自动模式湿度动力学
- **核心目标与架构演进**：
  1. **自然语言开字前缀与调温拦截缺陷根治**：
     - 彻底修复以“开/打开/开启”为前缀的复合指令（如“开除湿”、“开制冷”、“开制热”、“开送风”、“开26度”、“开到26度”、“开大风”等）被 `isPowerOn` 贪婪前置拦截误判为单纯开机的严重缺陷；增加模式名、带“度”温度值、风速和情景关键词的显式排除，使其准确映射为对应的模式切换与温度调整；
     - 修复“关小风”、“风速关小一点”、“关小一点”等风量下调口语被误判为整机断电关机的问题；
     - 新增 `.queryStatusAll` 全屋状态查询指令模型，区分全屋状态查询（“全屋空调多少度”、“全屋空调状态”）与单机状态查询；
  2. **自清洁控制流与多设备批量状态聚合闭环**：
     - 修复 `VoiceCapsuleWindowController` 中 `.stopSelfCleaning` 分支遗漏的 `scheduleAutoDismiss(delay: 1.8)` 与 `return`，消除控制流泄漏至兜底逻辑的隐患；
     - 将 `.stopSleepCurve` 与 `.queryStatusAll` 提升至顶层多设备/单设备前置分发，避免误报“该操作暂不支持多设备批量执行”；
     - 在 `executeMultiDeviceCommand` 中补齐 `case .queryStatus` 状态聚合查询，按房间格式化汇总运行态与室内温度（如“「客厅」运行中，室温 24.5°C，制冷 26.0°C；「主卧」待机，室温 25.0°C”）；
     - 引入智能待机联动：当用户发出带“开”字的调温或模式切换时，自动为待机设备联锁唤醒开机（`onOffStatus = true`）；
  3. **macOS 状态栏首选设备路由对齐与动态设备计数**：
     - 修复状态栏右键菜单中的单机温度步进（`stepUpPrimaryTemperature` / `stepDownPrimaryTemperature`）与快捷模式预设（制冷/制热/除湿/送风）硬编码抓取 `allUnifiedDevices.first?.id` 导致的路由漂移缺陷，全面收敛对齐至用户当前选定的首选主控设备 `primaryDeviceId` (`model.menuBarDeviceId ?? model.allUnifiedDevices.first?.id`)；
     - 状态栏右键全屋快捷预设菜单项（全屋制冷/全屋制热/全屋除湿/全屋送风）动态显示当前在线可控设备数量（如 `❄️ 全屋清爽制冷 26°C (2台在线)`），反馈更加透明精准；
  4. **自动模式温湿度协同动力学建模**：
     - 在自动模式（`.auto`）瞬时功率估算中引入室内相对湿度（`indoorHumidity`）动力学补偿：高湿工况 ($\text{RH} \ge 65\%$) 自动叠加除湿蒸发负荷补偿，干爽工况 ($\text{RH} \le 45\%$) 相应平滑缩减微载功率，使自动工况功率响应更贴合变频空调的舒适平衡热力学。

---

## 2. 关键架构变更与代码实现

### 2.1 自然语言开字前缀与调温拦截缺陷根治 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)
- **开机与关机前置判定精准边界**：
  - `isPowerOn` 增加排除规则：排除任何包含模式名（制冷、冷气、制热、暖气、除湿、抽湿、送风、自动）、带“度”的温度表达（如“26度”、“26.5度”）、风速词（大风、小风、微风）以及情景模式的句式；
  - `isPowerOff` 增加排除“关小风”、“风速关小”、“关小一点”等调速句式；
  - 扩展 `VoiceCommand` 枚举新增 `queryStatusAll`；当口语包含“全屋/所有/全部”与“多少度/温度/状态”时精准解析为全屋查询。
- **单元测试套件全覆盖**：
  - 新增 30 项独立断言验证“开除湿”、“开制冷”、“开制热”、“开送风”、“开26度”、“开到25.5度”、“开大风”、“关小风”、“全屋空调多少度”等，全部一次性通过。

### 2.2 自清洁控制流与多设备状态聚合 (`VoiceCapsuleWindowController.swift`)
- **控制流补丁**：
  - 为 `.stopSelfCleaning` 补充 `scheduleAutoDismiss(delay: 1.8)` 与 `return`，消除掉入未捕获状态分支的隐患；
- **顶层指令前置分发**：
  - 将 `.stopSleepCurve` 和 `.queryStatusAll` 提取至 `targetDevices.count > 1` 的判断之前，避免多设备下报出“不支持批量执行”；
- **多设备状态聚合查询与口语格式化**：
  - `executeMultiDeviceCommand` 新增 `case .queryStatus`，自动遍历目标设备并按「设备名」+「运行态」+「室温」+「模式设定」格式化拼接多设备语音与界面反馈；
- **智能开机联动**：
  - 当通过“开”字设定温度或模式时，如果目标设备当前处于待机状态，则在下发温度/模式的同时将其电源状态自动联动置为 `true`。

### 2.3 状态栏首选设备路由对齐与右键计数 (`StatusItemController.swift`)
- **主选设备 ID 单一事实来源**：
  - 废弃 `model.allUnifiedDevices.first?.id` 的生硬引用，重构为统一计算属性 `primaryDeviceId` (`model.menuBarDeviceId ?? model.allUnifiedDevices.first?.id`)；
  - 单机调温（`stepUpPrimaryTemperature` / `stepDownPrimaryTemperature`）与快捷模式预设（`applyQuickCoolingPrimary` 等）全部改走 `primaryDeviceId`；
- **全屋快捷项动态可控设备计数**：
  - 右键上下文菜单的「全屋清爽制冷」、「全屋舒适制热」、「全屋舒爽除湿」、「全屋清新送风」标题中动态加入 `(N台在线)` 数量提示。

### 2.4 自动模式温湿度协同动力学建模 (`EnergyAnalyticsEngine.swift`)
- **自动模式湿度动力学补偿**：
  - 自动模式引入 `indoorHumidity` 判定：当 $\text{RH} \ge 65\%$ 时叠加潜热除湿负荷补偿（基准功耗与上限相应上浮）；
  - 当 $\text{RH} \le 45\%$ 时适当下调基础功耗（防过度耗能），真实还原变频空调微电脑对温湿度的多维度综合调控机制。

---

## 3. 构建、测试与打包验证闭环
- **本地编译验证**：
  - 运行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 错误，0 警告构建成功；
- **测试用例验证**：
  - 独立运行 `VoiceCommandParserTests` 30 组用例，全部验证通过；
- **应用打包与签名**：
  - 执行 `./build_app.sh 1.9.38`，构建生成 `dist/HaierAC.app`（包含 App 及小组件插件包）并打包为发布归档 `dist/HaierAC-v1.9.38-macOS.zip`。

---

## 4. 敏感数据安全审计
- 全仓扫描确认无真实手机号、明文密码、第三方 Secret Token 或私人凭据提交。
