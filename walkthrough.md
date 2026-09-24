# Haier AC Mac v1.9.41 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.41`
- **发版主题**：闭环全屋调温开机联动与风速协同调度、温限边界反馈优化、自动模式全天候极端动力学及状态栏视觉统一
- **核心目标与架构演进**：
  1. **全屋调温待机联动唤醒与开字调温防线闭环**：
     - 彻底根除口语“全屋开26度”、“所有空调开25”、“全屋开24”等带“开”字的全屋调温指令在设备关机待机时仅设置温度却未下发开机的严重交互缺陷；在 `VoiceCapsuleWindowController` 中无缝补齐待机设备联动唤醒开机（`onOffStatus = true`），反馈中明确标注“（并开启 N 台待机空调）”；
     - 在 `isAllPowerOn` 中增加 16.0°C ~ 30.0°C 有效温度区间与风速词的严格排除，杜绝任何全屋设定指令被抢占误判为单纯全屋开机。
  2. **全屋风速协同调度与全链路风速拓展**：
     - 针对用户发出“全屋开大风”、“所有空调开微风”、“全屋自动风”、“把所有空调都调到中速风”等全屋风速口令以往因缺少全屋作用域而回退为单机控制的缺陷，新增 `VoiceCommand.setWindSpeedAll(String)` 指令；
     - 在 `parseAllPreset` 中排除风速关键词，并在全屋流程中前置分发全屋风速；在 `AppModel` 中提供统一的批量与全屋风速控制 API `setWindSpeed(deviceIds:speedName:autoPowerOn:)` 与 `setWindSpeedAll`，全面支持开字联动唤醒待机设备。
  3. **全屋与单机相对调温温限边界精准反馈**：
     - 修复此前当全屋空调开机且已全部达到 30°C（或 16°C）极限时，用户说“全屋升温1度”，语音胶囊因变更数为 0 误报“当前无任何开机运行中的在线空调”的缺陷；完善两级判定：无运行空调报待机，运行中均达温限时给出明确温限提示（“全屋运行中的空调均已达到最高温度上限 30°C / 最低温度下限 16°C”）；
     - 单设备与多设备调温同步对齐边界守卫，达到极限时中性提示，杜绝冗余指令下发与虚假成功文案。
  4. **自动模式（Auto）全季节极端温差与环境湿度双控动力学深化**：
     - 在 `EnergyAnalyticsEngine.estimateInstantaneousPower` 中，将酷暑极端高温（$\ge 30^\circ\text{C}$）冷凝器散热恶化超频补偿（`heatBoost` 100~280W，顶峰 1750W）与冬季严寒低温（$\le 15^\circ\text{C}$）大温差 PTC 电辅热与大压比高频超载补偿（`coldBoost` 120~320W，顶峰 1950W）完整融入 `.auto` 模式，并接入双向环境湿度动力学微调，实现制冷、制热与自动三大核心工况全季节极端气候动力学的 100% 对称。
  5. **macOS 状态栏多设备控制矩阵视觉统一与 Tooltip 滤网健康正面提示**：
     - 状态栏右键“空调设备控制矩阵...”各房间子菜单中，为一键制冷、制热、除湿、送风、自动等全部模式补齐统一的模式符号（❄️、🔥、💧、🍃、🔄），与顶层菜单保持视觉一致性；
     - 状态栏悬浮 Tooltip 增加健康提示：当全屋滤网洁净度均处于良好状态时，显示“✨ 全屋空调滤网状态良好”。

---

## 2. 关键架构变更与代码实现

### 2.1 全屋调温待机联动开机与防线加固 (`VoiceCommandParser.swift` / `VoiceCapsuleWindowController.swift`)
- **联动开机补齐**：
  - 在 `VoiceCapsuleWindowController.executeCommand` 的 `case .setTemperatureAll(let temp)` 分支中检测 `spokenText.contains("开")`；若为待机设备，在下发目标温度的同时批量下发 `onOffStatus = true`；
  - 成功文案动态追加“（并开启 N 台待机空调）”，彻底消除了口语说“开”而硬件不开机的脱节问题；
- **全屋开机防线对称**：
  - 在 `isAllPowerOn` 中同步增加有效温度域（16.0 ~ 30.0°C）与风速词的严格排除，与单设备 `isPowerOn` 形成对称严密的安全防线。

### 2.2 全屋风速协同调度与全链路风速拓展 (`VoiceCommandParser.swift` / `VoiceCapsuleWindowController.swift` / `AppModel.swift`)
- **指令模型拓展**：
  - `VoiceCommand` 新增 `case setWindSpeedAll(String)`；
  - `parseWindSpeed` 感知全屋范围 `isAllDeviceScope`，准确解析为全屋风速指令（如“全屋开大风”->`.setWindSpeedAll("强劲")`，“所有空调开微风”->`.setWindSpeedAll("微风")`，“全屋自动风”->`.setWindSpeedAll("自动")`）；
  - `parseAllPreset` 排除风速词，避免模式抢占；并在全屋流程中前置分发；
- **模型层与执行层批量 API**：
  - `AppModel` 增设 `setWindSpeed(deviceIds:speedName:autoPowerOn:)` 与 `setWindSpeedAll(speedName:autoPowerOn:)`；
  - `VoiceCapsuleWindowController` 前置接管 `.setWindSpeedAll`，一键为全屋空调设定目标风速并支持待机唤醒。

### 2.3 全屋与单机相对调温边界语义优化 (`VoiceCapsuleWindowController.swift`)
- **根除误导性反馈**：
  - `adjustTemperatureAll` 改为先判断是否存在开机设备；若无开机设备则提示待机，若有开机设备但 `count == 0` 则明确告知“全屋运行中的空调均已达到最高温度上限 30°C / 最低温度下限 16°C”；
  - 单设备 `case .adjustTemperature(let delta)` 在已达极限（`currentTemp >= 30.0 && delta > 0` 或 `currentTemp <= 16.0 && delta < 0`）时，立即拦截并反馈“已达到最高/最低温限”，避免无效网络请求与文案误报；多设备批量调温同步补齐该逻辑。

### 2.4 自动模式全气候极端温差与湿度双控动力学 (`EnergyAnalyticsEngine.swift`)
- **全季节极端气候动力学对称**：
  - 在 `estimateInstantaneousPower` 的 `case .auto` 自动模式中，将夏季酷暑高温冷凝恶化超频动力学（`heatBoost`）与冬季严寒大温差 PTC 电辅热动力学（`coldBoost`）全面接入；
  - 当室内高温 $\ge 30^\circ\text{C}$ 且 $\Delta T \ge 5^\circ\text{C}$ 时，动态累加 100~280W 功耗，峰值功耗放宽至 1750W；
  - 当室内低温 $\le 15^\circ\text{C}$ 且 $\Delta T \ge 5^\circ\text{C}$ 时，动态累加 120~320W 功耗，峰值功耗放宽至 1950W；
  - 自动制热态接入环境湿度微调补偿，实现制冷、制热与自动三大工况全季节极端气候动力学的完全对称。

### 2.5 状态栏设备矩阵视觉 Emoji 统一与 Tooltip 优化 (`StatusItemController.swift`)
- **子菜单 Emoji 对齐**：
  - 在“空调设备控制矩阵...”各设备子菜单中，为一键制冷 26°C、一键制热 20°C、一键除湿、一键送风、一键智能自动 24°C 全面补齐模式符号（❄️、🔥、💧、🍃、🔄）；
- **滤网健康状态正面反馈**：
  - 悬浮 Tooltip 在全屋滤网洁净度良好（均在安全阈值以上）时，显示“✨ 全屋空调滤网状态良好”，使用户对全屋健康状态心中有数。

---

## 3. 构建、测试与打包验证闭环
- **本地编译验证**：
  - 运行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 错误构建成功；
- **全链路独立断言校验**：
  - 针对 `VoiceCommandParserTests` 与全屋风速、全屋开字调温、相对调温边界、结构化否定等全部新增断言进行自动化测试，全部通过；
- **应用打包与签名**：
  - 执行 `./build_app.sh 1.9.41`，成功生成 `dist/HaierAC.app`（含桌面小组件扩展）并导出分发包 `dist/HaierAC-v1.9.41-macOS.zip`（2.6MB）。

---

## 4. 敏感数据安全审计
- 全仓扫描确认无真实手机号、明文密码、第三方 Secret Token 或私人凭据提交。
