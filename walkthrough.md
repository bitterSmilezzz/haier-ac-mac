# Haier AC Mac v1.9.39 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.39`
- **发版主题**：闭环自然语言模式温度复合控制缺陷、状态栏设备矩阵主显一键切换与低温制热动力学
- **核心目标与架构演进**：
  1. **自然语言运行模式与设定温度复合指令缺陷根治**：
     - 彻底根除口语中同时包含模式与目标温度（如“制冷26度”、“开制冷26度”、“开冷气25度”、“开暖气22度”、“开制热二十度”、“客厅制冷26度”、“主卧开暖气21度”、“客厅和主卧开制冷24度”）因原有解析流中 `parseAbsoluteTemperature` 优先捕获导致模式（`operationMode`）被意外丢弃的严重缺陷；
     - 新增 `VoiceCommand.setModeAndTemperature(mode: String, temperature: Double?)` 指令模型；解析器前置提取运行模式与 16~30°C 温度值，并提供“清爽制冷 26°C”、“舒适制热 20°C”等友好自然语言反馈；
     - 在单机与多设备批量执行链路（`executeMultiDeviceCommand`）中无缝联动唤醒待机设备、下发模式与目标温度；
     - 全链路扩充调温与变频动作的否定安全防护（“别开制冷26度”、“不要开暖气22度”、“别调到26度”、“千万别开大风”等），杜绝任何误执行。
  2. **macOS 状态栏多设备矩阵一键常驻主显设备（Primary Device Pinning）**：
     - 在状态栏右键“空调设备控制矩阵...”各房间子菜单中，增设原生「★ 设为菜单栏主显设备」选项（当前主显设备显示「✓ 菜单栏常驻主显中」并禁用点击）；
     - 点击后一键将 `model.menuBarDeviceId` 切换至指定设备，并即刻触发 `refreshTemperature()` 刷新菜单栏实时温度显示、图标、悬浮 Tooltip 与 Bento Popover 默认聚焦，同时弹出 Toast 确认反馈；
     - 在子菜单顶层设备标题前标示 `★` 徽章，多设备家庭用户在状态栏无需打开主窗口即可随时切换主控房间。
  3. **变频制热严寒低温 PTC 电辅热与大温差热负荷动力学校准**：
     - 在 `EnergyAnalyticsEngine.estimateInstantaneousPower` 中，深度优化冬季制热动力学：当室内外温差大且室内温度较低（室内温度 $\le 15^\circ\text{C}$，目标温差 $\Delta T \ge 5^\circ\text{C}$）时，拟真变频空调自动触发 PTC 辅助电加热与超频提温机制，动态计算热负荷附加功耗（+120W ~ 320W），大幅提升严寒季节与速热场景下的能耗仿真精度；
     - 送风模式引入阶梯风速风阻能耗微调，低速静音档微功耗（最低 14W），高速强劲档真实还原风机全速压降能耗。

---

## 2. 关键架构变更与代码实现

### 2.1 自然语言模式与温度复合指令闭环 (`VoiceCommandParser.swift` / `VoiceCapsuleWindowController.swift` / `VoiceCommandParserTests.swift`)
- **新增复合指令模型与解析层前置**：
  - `VoiceCommand` 扩充 `case setModeAndTemperature(mode: String, temperature: Double?)`；
  - `VoiceCommandParser.parse` 在绝对温度解析前插入 `parseModeAndTemperature`，精准抓取“模式词（制冷/冷气/制热/暖气/送风/除湿/自动等）”加“有效温度（16~30°C）”，同时排除全屋范围（交由 `parseAllPreset` 统一分发）；
  - 增强 `containsNegativeAction` 正则表达式与关键词列表，将“调/设/升/降”等动作动词纳入否定动作捕获，并在 `parseRelativeTemperature`、`parseAbsoluteTemperature` 与 `parseWindSpeed` 中加入否定安全防线。
- **单机与多设备批量执行链路对齐**：
  - `VoiceCapsuleWindowController.executeCommand` 与 `executeMultiDeviceCommand` 补齐 `case .setModeAndTemperature` 分支，当目标空调处于待机状态时联动唤醒电源（`onOffStatus = true`），并同步更新 `operationMode` 与 `targetTemperature`。
- **单元测试套件全覆盖**：
  - 新增 `testModeAndTemperature()` 包含 15+ 组独立断言，覆盖“制冷26度”、“开暖气22度”、“客厅制冷26度”、“主卧开暖气21度”、“客厅和主卧开制冷24度”、“别开制冷26度”（否定防护）等，全部验证通过。

### 2.2 状态栏多设备矩阵一键常驻主显设备 (`StatusItemController.swift`)
- **设备级联子菜单交互扩展**：
  - 为每个空调的级联控制子菜单增设「★ 设为菜单栏主显设备」/「✓ 菜单栏常驻主显中」菜单项，根据 `devId == primaryDeviceId` 动态计算状态；
  - 点击时触发 `@objc private func setPrimaryDeviceFromMenu`，原子更新 `model.menuBarDeviceId`，调用 `refreshTemperature()` 瞬时刷新菜单栏实时温度文本与图标，并通过 `model.operationNotice` 发送交互 Toast 提醒；
  - 设备项标题增加 `★` 前缀徽标，直观标识当前哪台设备正在常驻菜单栏。

### 2.3 制热严寒低温 PTC 电辅热与大温差热负荷动力学 (`EnergyAnalyticsEngine.swift`)
- **制热工况严寒速热 PTC 电热负荷**：
  - 在 `EnergyAnalyticsEngine.estimateInstantaneousPower` 的 `.heating` 分支中，增加当 `indoor <= 15.0 && delta >= 5.0` 时的热力补偿算法，动态叠加 `120.0 + (deficit * 10.0) + (excess * 12.0)`，最高功耗范围拓展至 1950W，完美贴合北方/湿冷南方冬天变频空调电辅热全开的高负荷动力学；
- **送风模式风阻阶梯**：
  - 微风/静音档基础功耗优化至 14W~20W，高风档真实还原风机压降负载至 60W~65W。

---

## 3. 构建、测试与打包验证闭环
- **本地编译验证**：
  - 运行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 错误，0 警告构建成功；
- **测试用例验证**：
  - 运行独立测试套件验证 `VoiceCommandParserTests` 21 组断言，全部通过；
- **应用打包与签名**：
  - 执行 `./build_app.sh 1.9.39`，生成 `dist/HaierAC.app`（含桌面小组件扩展）并成功导出发布压缩包 `dist/HaierAC-v1.9.39-macOS.zip`（2.6MB）。

---

## 4. 敏感数据安全审计
- 全仓扫描确认无真实手机号、明文密码、第三方 Secret Token 或私人凭据提交。
