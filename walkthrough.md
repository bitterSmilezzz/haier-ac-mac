# Haier AC Mac v1.9.43 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.43`
- **发版主题**：闭环自然语言复合半小时缩水缺陷、多房间定向含全部/全都不越权、情景模式全链路路由及菜单栏主显统一同步
- **核心目标与架构演进**：
  1. **自然语言复合半小时时间缩水解析缺陷根治与中午 PM 钟点精准识别**：
     - 彻底重构时间预处理器（`convertChineseNumbers`）在处理“半小时”时的贪婪字符串替换缺陷。以往“两个半小时后关机”（150分钟）中“半小时”被简单替换为“30分钟”，导致前序量词“两个”断裂，提取正则误将其截断为“30分钟”，造成整整 120 分钟（2小时）的严重时间缩水；
     - 引入复合量词语法正则（`([一二两三四五六七八九]|\d+)(?:个半小时|个钟头半|小时半|个小时半)`），精准将“两个半小时/2个半小时/两小时半”映射为 2.5 小时（150分钟），“三个半小时”映射为 3.5 小时（210分钟）；
     - 补齐钟点定时中“中午/午后”时段标识，将“中午1点/中午一点半/中午2点”精准归一为 13:00 / 13:30 / 14:00，彻底根治此前误判为凌晨（01:00 AM）的严重缺陷。
  2. **多房间定向口令含“全部/全都”防越权全屋拦截加固**：
     - 加固全屋作用域分析逻辑（`isAllDeviceScope`）。当口令已包含明确的定向目标房间（`hasTargetRoomKeyword`，如“把客厅和主卧全部关了”、“取消客厅和主卧全部定时”）时，将“全部/全都”准确界定为修饰特定房间的并列副词，不再误判为全屋全局作用域；
     - 仅当明确出现“全屋”、“全家”、“整套”、“所有空调”、“全部空调”等全局主体量词时才触发全屋操作，彻底杜绝定向房间控制时越权关停全屋其他未提及空调。
  3. **情景模式全链路路由闭环与多设备/全屋/快捷指令协同**：
     - 修复胶囊语音在执行指定设备情景模式（如“主卧睡眠情景”）时未透传 `targetDeviceId` 导致默认穿透至客厅的缺陷；
     - 在 `isAllDeviceScope` 中补齐全屋情景调度（`allDevices: true`），并在 `executeMultiDeviceCommand` 中补全 `.applyScene` 批量下发，支持“客厅和主卧都开启睡眠模式”；
     - 同步升级 macOS 快捷指令 `ApplyACSceneIntent`，支持按设备名称定向应用情景或一键广播全屋。
  4. **菜单栏控制中心设备路由单源收敛与批量控制面板相对调温保护**：
     - 彻底移除 `MenuBarControlsView` 中的私有 `@State selectedDeviceId`，统一收敛至 `model.primaryDeviceId` 单一真实可信数据源，消除控制面板 Picker 与菜单栏右键主显设备切换脱节滞后的状态漂移；
     - 升级批量控制面板温控逻辑，采用相对调温 `model.adjustTemperature(delta:includeStandby: true)`，既保护关机设备避免被无意联动开机，又确保不同房间空调在各自设定基准上同步平移且受 16~30°C 极值边界防护；快捷预设补齐“智能 24°C”、“舒爽除湿”与“清新送风”。

---

## 2. 关键架构变更与代码实现

### 2.1 复合半小时时间与中午 PM 钟点结构化解析 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)
- **根治半小时字符串割裂**：
  - 在 `VoiceCommandParser.convertChineseNumbers` 中，将复合半小时识别提前至孤立“半小时”之前，运用正则 `([一二两三四五六七八九]|\d+)(?:个半小时|个钟头半|小时半|个小时半)` 先行折算为小数形式（如 `2.5小时`、`3.5小时`），然后再将孤立“半小时”转为 `30分钟`；
  - 增强 `parseTimeSpecification` 中钟点定时解析，增加“中午”和“午后”关键词（如“中午1点”、“午后2点半”），准确赋予 PM 属性并转换为 24 小时制的对应下午钟点。
- **单元测试保障**：
  - 在 `VoiceCommandParserTests` 中追加测试用例，覆盖“两个半小时后关机”（150分钟）、“三个半小时后开机”（210分钟）、“中午1点开机”（13:00）、“中午一点半关机”（13:30）等真实口语口令。

### 2.2 多房间定向口令含“全部/全都”防越权全屋拦截 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)
- **副词修饰与全局量词精准辨识**：
  - 优化 `isAllDeviceScope`：当 `hasTargetRoomKeyword` 为真且不含明确的“全屋/全家/整套/所有空调/全部空调/每台空调”时，判定其为局部定向控制，返回 `false`；
  - 允许指令安全流转至 `executeMultiDeviceCommand`，严格将操作约束在目标设备集（如仅限“客厅”和“主卧”），杜绝越权误杀全屋其他设备。

### 2.3 情景模式全链路路由闭环与快捷指令协同 (`VoiceCapsuleWindowController.swift` / `AppIntents.swift`)
- **路由贯通**：
  - 在 `executeCommand` 中，当解析为 `.applyScene(let scene)` 且指定了 `targetDeviceId` 时，将目标设备 ID 准确传递给 `model.applyScenePreset(scene, deviceId: targetDeviceId)`；
  - 在 `executeMultiDeviceCommand` 中增加 `case .applyScene(let scene)`，遍历匹配的目标设备并批量下发情景；
  - 升级 `ApplyACSceneIntent`，支持参数 `deviceName`（匹配指定空调）与 `allDevices`（广播全屋）。

### 2.4 菜单栏控制中心设备路由单源收敛与批量控制面板相对调温 (`MenuBarControlsView.swift` / `AppModel.swift` / `BatchControlView.swift`)
- **单源状态收敛**：
  - `MenuBarControlsView` 使用 `model.primaryDeviceId`，消除局部状态与全局主显设备的割裂；切换 Picker 直接调用 `model.setPrimaryDevice(id:)`，使得菜单栏图标、状态栏右键菜单与控制中心 Picker 实时同步；
- **批量相对调温与待机保护**：
  - `AppModel.adjustTemperature` 增加 `includeStandby: Bool = false` 参数，批量控制面板显式启用相对调温并保护待机设备，避免调温操作意外唤醒已关机设备；
  - 批量快捷预设拓展至常用工况，包含智能 24°C、舒爽除湿、清新送风与极速制冷。

---

## 3. 构建、测试与打包验证闭环
- **全链路独立断言校验**：
  - 针对复合半小时倒计时、中午/午后钟点定时、多房间定向防越权、全屋全量开关等共 20 项关键断言运行独立测试套件，全部 100% 通过（`🎉 ALL 20 VERIFICATION ASSERTIONS PASSED 100%!`）；
- **本地编译验证**：
  - 运行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 错误编译通过；
- **应用打包与签名**：
  - 运行 `./build_app.sh 1.9.43`，成功构建并签名 `dist/HaierAC.app`（含桌面小组件扩展），并生成发布压缩包 `dist/HaierAC-v1.9.43-macOS.zip`。

---

## 4. 敏感数据安全审计
- 全仓扫描确认无真实手机号、明文密码、第三方 Secret Token 或私人凭据提交。
