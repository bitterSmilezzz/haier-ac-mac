# Haier AC Mac v1.9.31 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.31`
- **发版主题**：全屋智能协同控制、自然语言自清洁与状态栏实时功率感知
- **核心目标**：
  1. 打通全屋多设备并发一键协同调度（全屋一键关机、全屋舒适预设）。
  2. 扩展自然语言语音胶囊控制体系，支持全屋级语义理解与 56°C 蒸发器高温自清洁自然语言托管，重构门禁防止单设备离线误拦。
  3. 扩充 macOS 系统原生快捷指令与 Siri 生态（`TurnOffAllACIntent`、`StartSelfCleaningIntent`），修复温度调整浮点截断。
  4. macOS 状态栏原生上下文菜单增强，Tooltip 接入实时瞬时总功率与滤网损耗 Combine 响应流。
  5. 严谨隔离离线设备室内温度采样，消除断电设备陈旧数据对动力学能耗模型的干扰。

---

## 2. 关键架构变更与代码实现

### 2.1 全屋一键协同控制 (`AppModel.swift`)
- **`turnOffAllDevices() -> Int`**：
  - 自动识别当前既在线可达 (`reachability.isControllable`) 又处于开机中的空调设备；
  - 并发下发 `onOffStatus = false`，向用户即时反馈关闭的设备台数，杜绝无效空发。
- **`applyPresetToAllDevices(mode:temperature:windSpeed:) -> Int`**：
  - 将所有在线可达的空调一键配置为指定模式（如制冷 26°C、制热 20°C），并同步设置风速；
  - 浮点温度格式化优化，整数自动消除 `.0`。

### 2.2 自然语言语音指令系统重构 (`VoiceCommandParser.swift` & `VoiceCapsuleWindowController.swift`)
- **新增指令枚举**：
  - `.turnOffAll`：全屋关机、关闭所有空调、把所有的空调都关了、全部关机；
  - `.turnOnAll`：开启所有空调、全部开机、全屋开机；
  - `.startSelfCleaning`：启动自清洁、蒸发器高温自清洁、清洗蒸发器；
  - `.stopSelfCleaning`：停止自清洁、关闭自清洁。
- **执行生命周期容错重构**：
  - 将全屋指令（`.turnOffAll` / `.turnOnAll`）和自清洁停止指令（`.stopSelfCleaning`）置于单一主设备可达性门禁之前先行拦截处理；
  - 彻底解决主选空调离线导致用户喊“关闭所有空调”被误拦报错的架构缺陷。

### 2.3 批量控制面板优化 (`BatchControlView.swift`)
- **控制属性探测容错**：
  - 扫描选中的多设备，优先采用首个属性非空的设备作为控制模板，杜绝首台设备离线导致控制面板变成空白；
- **全屋一键预设 Bento 卡片组**：
  - 在批量面板顶部新增「❄️ 清爽 26°C」、「🔥 暖房 20°C」与「⏻ 全屋关机」快捷预设卡片。

### 2.4 Siri / 系统快捷指令扩展 (`AppIntents.swift`)
- **新增 Intent**：
  - `TurnOffAllACIntent`：一键关闭全屋所有正在运行的空调；
  - `StartSelfCleaningIntent`：启动 56°C 蒸发器高温除菌自清洁托管；
- **Bug 修复**：
  - 修复 `SetACTemperatureIntent` 中将 Double 温度截断为 `Int` 的问题，完整支持海尔空调 0.5°C 精度细腻微调回显。
- **快捷指令自动发现注册**：
  - 在 `ACAppShortcuts` 中注册系统 Short Title 与 Siri 触发口令。

### 2.5 状态栏动态响应与菜单扩展 (`StatusItemController.swift`)
- **Combine 响应流补齐**：
  - 接入 `EnergyAnalyticsEngine.shared.$currentInstantaneousPower` 与 `model.$filterAccumulatedMinutes`；
  - 瞬时功率与滤网告警实时计算并刷新 Tooltip；
- **右键菜单扩展**：
  - 多设备场景下增加「❄️ 全屋清爽制冷 26°C」一键直达，关机动作直接复用 `model.turnOffAllDevices()`。

---

## 3. 构建、测试与打包验证
- **本地编译验证**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` 验证 100% 编译成功；
- **单元测试验证**：
  - 补充 `VoiceCommandParserTests` 自动化单元测试用例，覆盖全屋开关与自清洁语法解析；
- **发布产物打包**：
  - 执行 `./build_app.sh 1.9.30`，成功生成签名完整的 `dist/HaierAC.app`（含小组件插件）与发布包 `dist/HaierAC-v1.9.30-macOS.zip` (2.5MB)。
