# Haier AC Mac v1.9.32 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.32`
- **发版主题**：批量控制设备作用域隔离、多设备自然语言目标路由与菜单栏全屋制热
- **核心目标**：
  1. 彻底根除多设备批量控制面板中的越权穿透漏洞，使批量预设与关机严格限定在用户勾选的设备子集。
  2. 增强自然语言语音胶囊控制的定向路由能力，支持按房间或设备名（“客厅”、“主卧”、“次卧”等）精准定向执行。
  3. 大幅拓宽中文口语化句式与把字句容错语法（“把所有的空调都关了”、“次卧关一下”、“打开客厅空调”等）。
  4. macOS 状态栏右键上下文菜单增加「🔥 全屋舒适制热 20°C」，并全链路补全 `hasControllable` 物理设备可达性门禁。

---

## 2. 关键架构变更与代码实现

### 2.1 批量控制设备作用域隔离与重构 (`AppModel.swift` & `BatchControlView.swift`)
- **API 作用域解耦**：
  - 将原有的 `turnOffAllDevices` 升级为 `turnOffDevices(deviceIds: [String]? = nil)`，在保留无参全屋兼容的同时，支持指定目标设备 ID 列表；
  - 将 `applyPresetToAllDevices` 升级为 `applyPreset(deviceIds: [String]? = nil, mode:temperature:windSpeed:)`；
  - 自动对目标列表中的设备进行在线可达性 (`isControllable`) 校验与去重，杜绝空发与向离线设备盲目发送。
- **批量面板联动与交互加固**：
  - `BatchControlView` Bento 卡片中的预设按钮全面传入当前选中的 `deviceIds`；
  - 关机按钮文案动态适配：全选时显示「全屋关机」，局部选中时明确显示「所选关机」，消除用户心理疑惑。

### 2.2 多房间自然语言目标智能路由 (`VoiceCapsuleWindowController.swift`)
- **房间与设备名智能探测**：
  - 引入 `resolveTargetDevice(for:model:)`，优先进行完整设备名比对，其次进行去除“空调/海尔”后缀的房间核心词匹配（“客厅”、“主卧”、“次卧”、“书房”等）；
  - 未指定具体房间时，无缝回退为主控空调（`menuBarDeviceId ?? allUnifiedDevices.first?.id`）。
- **目标设备精准门禁与反馈**：
  - 针对解析出的具体目标设备执行可达性检查，离线时明确提醒（如“「客厅空调」当前离线，无法执行语音指令”）；
  - 成功执行后在反馈中附带房间/设备前缀（如“已开启「客厅空调」”或“已为「次卧空调」设定：22:00 关机”），多设备状态清晰透明。

### 2.3 中文口语化与把字句语法增强 (`VoiceCommandParser.swift`)
- **全屋指令口语丰富**：
  - 支持“把所有的空调都关了”、“把空调全都关了”、“把全部空调关掉”、“所有空调都关了”等句式；
  - 引入“所有/全部/全屋/全都” + “关/停”的自然语言结构组合匹配。
- **单设备与定向控制语法拓展**：
  - 丰富 `isPowerOff` 与 `isPowerOn`，支持“把...关了/关掉/关上”、“关一下”、“打开”、“开启”等口语化句式；
  - 在 `isPowerOn` 中增加模式切换冲突防御（排除“冷气”、“暖气”、“冷风”、“暖风”等），防止“开冷气”等模式指令被误拦为普通开机。

### 2.4 状态栏季节适应全屋制热与可达性守卫 (`StatusItemController.swift`)
- **冷暖双向全屋快捷协同**：
  - 状态栏原生右键菜单新增「🔥 全屋舒适制热 20°C」快捷协同选项，实现冬夏双季一键温控。
- **可达性门禁闭环**：
  - 全屋制冷、全屋制热菜单项的 `isEnabled` 统一受控于 `hasControllable`（网关连接且至少有一台空调在线可控），网关断开或全屋离线时严格置灰。

---

## 3. 构建、测试与打包验证
- **本地编译验证**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` 100% 编译通过；
- **自动化测试验证**：
  - `VoiceCommandParserTests` 新增 `testSpokenAndRoomPhrases` 测试用例，全面覆盖全屋口语、房间定向把字句与调温/模式解析；
- **生产发布产物**：
  - 运行 `./build_app.sh 1.9.32`，生成 `dist/HaierAC.app`（含 WidgetKit 扩展与原生代码签名）及分发包 `dist/HaierAC-v1.9.32-macOS.zip` (2.5MB)。
