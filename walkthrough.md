# Haier AC Mac v1.9.33 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.33`
- **发版主题**：全屋语音模式智能辨识与温控协同路由、防冷暖倒置
- **核心目标**：
  1. 彻底根除「全屋开暖气/制热」因误判为纯开机导致执行默认制冷 26°C 的**严重冷暖颠倒缺陷**，打通全屋自然语言模式与温控协同通道。
  2. 增强自然语言多设备复合路由能力，原生支持“客厅和主卧一起关了”、“次卧跟客厅调到26度”等跨房间多目标批量原子控制。
  3. 完善 macOS 状态栏单机与多机场景体验对齐，单机模式新增一键冷暖预设，状态栏图标引入全屋活动感知，瞬时总功率智能切换 W / kW 格式。
  4. 完善 Apple 快捷指令与 Siri 生态闭环，新增 `TurnOnAllACIntent`（开启全屋空调），在 macOS 14+ 及回退分支完整注册。

---

## 2. 关键架构变更与代码实现

### 2.1 全屋自然语言模式与温控协同管道 (`VoiceCommandParser.swift`)
- **全新指令抽象模型**：
  - 新增 `VoiceParseResult.Command.presetAll(mode: String, temperature: Double?)` 与 `VoiceParseResult.Command.setTemperatureAll(Double)` 枚举；
- **防冷暖倒置与智能分流**：
  - 在 `VoiceCommandParser.parse` 顶层优先调度 `parseAllPreset` 与 `parseAllTemperature`；
  - 针对 `isAllPowerOn` 增加冷暖及温度词汇严格排除（“冷气”、“暖气”、“制冷”、“制热”、“冷风”、“暖风”、“度”），彻底消除了“全屋开暖气”被误判为全屋开机导致强制执行制冷 26°C 的严重逻辑倒置；
  - 智能基准温阶：制热指令（“全屋制热”、“全屋开暖气”）缺省温度映射为舒适制热 20°C，制冷指令（“全屋制冷”、“所有空调开冷气”）缺省温度映射为清爽制冷 26°C，送风与除湿指令保留模式不带温度，同时支持自定义温度（如“全屋开冷气25度”、“全屋制热22度”）。

### 2.2 多房间复合自然语言协同控制 (`VoiceCapsuleWindowController.swift`)
- **多房间目标解析升级**：
  - 将单设备解析器重构升级为 `resolveTargetDevices(for:model:) -> [AppModel.UnifiedDevice]`，能够准确提取语音指令中包含的多个房间（如“客厅和主卧”、“次卧跟主卧”）；
  - 新增 `executeMultiDeviceCommand`：结合 `model.sendAttributeToDevices` 与 `model.turnOffDevices`，支持多房间并发执行电源开关、温度调节、风速控制，并反馈精准多房间确认提示（如“已将「客厅空调, 主卧空调」温度调至 26.0°C”）。
- **全屋预设与调温执行调度**：
  - 处理 `.presetAll`：联动 `model.applyPresetToAllDevices`，针对除湿/送风批量下发模式，制冷/制热同步下发模式与目标温阶；
  - 处理 `.setTemperatureAll`：全屋联动下发 `targetTemperature` 属性，提供“已将全屋空调温度调至 24.0°C”直观回显。

### 2.3 macOS 状态栏交互与感知体验升级 (`StatusItemController.swift`)
- **单设备场景快捷冷暖直达**：
  - 单设备场景上下文菜单补齐「❄️ 一键制冷 26°C」与「🔥 一键制热 20°C」快捷操作，使单设备与多设备用户在右键菜单中享有完全一致的舒适温控体验；
- **全屋空调运行状态联动感知**：
  - 状态栏图标双态判定引入 `anyDeviceRunning` 检测：当主选空调待机但家中其他房间空调处于工作状态时，图标自动呈现实心运行态 `air.conditioner.horizontal.fill`，并在悬浮 Tooltip 中展示多房间运行状态；
- **瞬时功率智能单位自适应**：
  - 瞬时总功率在超过 1000W 时自动切换为双精度 `kW` 呈现（如 `1.45 kW`），千瓦以下保持 `W` 显示，数值清晰易读。

### 2.4 Siri 与快捷指令生态闭环 (`AppIntents.swift`)
- **新增全屋开机 Intent**：
  - 实现 `TurnOnAllACIntent`（开启全屋空调），一键开启全屋所有在线海尔空调并设置为清爽制冷 26°C；
  - 在 `ACAppShortcuts` 中为 macOS 14+ 及低版本回退分支注册“开启所有空调”、“全屋开机”语音短语与图标。

---

## 3. 构建、测试与打包验证
- **本地编译验证**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` 验证 100% 编译成功，0 错误，0 警告；
- **单元测试套件**：
  - `VoiceCommandParserTests` 新增 `testWholeHousePresetAndTemperature`，全面覆盖全屋制冷、全屋制热、全屋开暖气防倒置、全屋送风/除湿及统一温控命令用例；
- **分发打包**：
  - 执行 `./build_app.sh 1.9.33`，生成包含 Widget 扩展与原生代码签名的 `dist/HaierAC.app` 及分发包 `dist/HaierAC-v1.9.33-macOS.zip`。
