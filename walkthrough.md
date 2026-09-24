# Haier AC Mac v1.9.35 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.35`
- **发版主题**：能耗工况动力学量纲校准、全屋设备机时精准分析、状态栏温阶微调矩阵与语音全屋相对调温
- **核心目标**：
  1. **彻底闭环外部 Code Review 审查遗留项（CR P2-1/2）**：消除 `EnergyAnalyticsEngine.swift` 中多设备并发运行时各模式工况分钟数之和超过自然自然墙钟时长的量纲冲突，建立「全屋自然流逝时长（`totalMinutes`）」与「设备累计总机时（`totalDeviceMinutes`，台·分）」双轴核算体系，提供无溢出安全比例计算，并在能耗仪表盘提供机时占比百分比看板。
  2. **完善 macOS 状态栏温度微调控制矩阵**：在 `StatusItemController` 右键菜单中为多设备场景提供「全屋统一升温/降温 1°C」，为单设备及多设备子菜单提供「升温/降温 1°C (当前 XX°C)」，严格联动 16~30°C 极值与在线开机可达性门禁。
  3. **增强自然语言语音交互（语音胶囊）**：支持“全屋调高两度”、“把所有空调都升温1度”、“全部空调调低一度”等全屋相对调温口语意图，打通全屋与多设备定向批量相对调温分发链路。

---

## 2. 关键架构变更与代码实现

### 2.1 能耗动力学工况量纲与设备机时精准化 (`EnergyAnalyticsEngine.swift` / `EcoEnergySection.swift`)
- **双轴核算模型**：
  - 将 `totalMinutes` 严格定义为全屋当日自然墙钟流逝分钟数（0~1440）；
  - 新增 `totalDeviceMinutes: Int`（全屋设备累计总机时，单位：台·分钟），在多设备同时工作时，每台运行中的设备产生的分钟数准确累加至对应的运行工况（`coolingMinutes`, `heatingMinutes` 等）以及 `totalDeviceMinutes` 中；
  - 各工况运行分钟数之和恒等于 `totalDeviceMinutes`，彻底消除了各工况分钟相加大于自然分钟数的量纲混淆；
- **Codable 向后兼容与安全防御**：
  - 自定义 `init(from decoder:)`，对历史存档中缺失 `totalDeviceMinutes` 字段的数据自动智能回退为 `max(sumOfModes, totalMinutes)`，保证旧版本数据 100% 优雅反序列化；
  - 新增 `effectiveDeviceMinutes`、`coolingRatio`、`heatingRatio`、`dehumRatio`、`fanRatio` 等安全计算属性，严格钳制除以零风险；
- **仪表板可视化升级**：
  - 在 `EcoEnergySection.swift` 的工况看板中引入设备机时占比百分比（如 `制冷 120m (60%)`），让用户直观掌握家庭全屋冷暖负荷分布。

### 2.2 macOS 状态栏温度微调控制矩阵 (`StatusItemController.swift` / `AppModel.swift`)
- **AppModel 相对与绝对调温 API**：
  - 新增 `adjustDeviceTemperature(deviceId:delta:)`：精准相对步进单台设备目标温度，严格限制在 16.0°C ~ 30.0°C 并在开机且可达时下发；
  - 新增 `adjustTemperature(deviceIds:delta:)` 与 `adjustTemperatureAll(delta:)`：支持指定多设备或全屋在线运行设备统一相对步进调温；
- **状态栏右键上下文菜单深度集成**：
  - 多设备全屋快捷区新增「🔼 全屋统一升温 1°C」与「🔽 全屋统一降温 1°C」，绑定 `stepUpAllTemperature` 与 `stepDownAllTemperature`；
  - 各设备子菜单新增「🔼 升温 1°C (当前 XX°C)」与「🔽 降温 1°C (当前 XX°C)」；
  - 单设备主菜单同步挂载单机升温与降温快捷项，当温度到达极限（30°C / 16°C）或设备关机离线时动态禁用，防止越界。

### 2.3 语音胶囊自然语言全屋相对调温 (`VoiceCommandParser.swift` / `VoiceCapsuleWindowController.swift`)
- **自然语言解析升级**：
  - 在 `VoiceCommand` 扩充 `adjustTemperatureAll(delta: Double)` 指令；
  - 新增 `parseAllRelativeTemperature` 模式，匹配包含“全屋/所有/全部/全都”以及升降温意图的口令（如“全屋调高两度”、“把所有空调都降温两度”、“全部空调调低一度”），排除模式关键词干扰；
- **语音胶囊执行分发与多设备定向联动**：
  - 在 `VoiceCapsuleWindowController` 中接入 `.adjustTemperatureAll` 全局分发，调用 `model.adjustTemperatureAll(delta:)`，精准反馈执行台数及升降温步进；
  - 在 `executeMultiDeviceCommand` 中打通多设备定向相对调温执行与反馈。

---

## 3. 构建、测试与验证闭环
- **本地编译验证**：
  - 采用 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，构建耗时 19.26 秒，0 错误，0 警告通过；
- **自动化测试套件**：
  - `VoiceCommandParserTests.swift` 扩充 `adjustTemperatureAll` 单元测试，测试覆盖“全屋调高两度”、“所有空调升温1度”、“把所有空调都降温两度”、“全部空调调低一度”用例；
- **打包分发**：
  - 运行 `./build_app.sh 1.9.35`，完成 `dist/HaierAC.app`（含小组件扩展及代码重签名）构建及 `dist/HaierAC-v1.9.35-macOS.zip` 打包输出。
