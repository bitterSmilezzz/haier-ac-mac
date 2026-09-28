# Haier AC Mac v1.9.51 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.51`
- **发版主题**：口语“X度五/X度5”高精解析、停止关机意图与温湿度工况全景感知
- **核心目标与架构演进**：
  1. **自然语言口语“X度五 / X度5”温度与相对微调高精解析 (`VoiceCommandParser` / `VoiceCommandParserTests`)**：
     - **“X度五 / X度5”绝对温度精准提取**：彻底修复日常口语高频出现的“二十六度五”、“26度5”、“开到25度5”、“制冷二十六度五”、“制冷26度5”、“全屋二十六度五”、“全屋开到26度5”在归一化中由于仅匹配“度半”而遗漏“度五/度5”导致丢失 0.5°C 精度、被错误降级为整数温度（如 26°C / 25°C）的严重缺陷；通过 `([一二两三四五六七八九\d]+)度(?:半|五|5)` 统一正则，精准无损折算为 26.5°C、25.5°C 等 0.5°C 步进目标温度；
     - **口语“一度五 / 1度5”相对调温微调**：解决“调高一度五”、“升温1度5”、“降温一度五”、“调低1度5”以及全屋联动“全屋升温一度五”、“全屋降温1度5”在相对调温中被错误判定为 1.0°C 的缺陷，精准提取为 $\pm 1.5^\circ\text{C}$ 微调；
     - **“停止”类口语关机意图与否定安全闭环**：扩充开关机意图判定，覆盖日常高频口语“把空调停了”、“停止运行”、“停止运转”、“停止工作”、“停掉空调”以及全屋口令“全屋空调停止运行”、“所有空调停止运行”、“所有空调都停了”，精准分发为单机/全屋关机指令（`.setPower(false)` / `.turnOffAll`），同时保持结构化否定安全防线（“千万别把空调停了”、“不要停止运行”等严格拦截）；
     - **状态与温湿度口语查询扩展**：全面支持“查询状态”、“空调开着吗”、“空调开了吗”、“空调关了吗”、“空调开着没”、“空调关了没”、“室内湿度多少”、“查询湿度”等自然口语，智能分发至 `.queryStatus` / `.queryStatusAll`。
  2. **空气动力学风量档位扩展与温湿度双控感知收敛 (`EnergyAnalyticsEngine` / `AppModel` / `VoiceCapsuleWindowController`)**：
     - 在 `EnergyAnalyticsEngine.estimateInstantaneousPower` 与 `AppModel.calculateFilterWearFactor` 中扩展“极速”、“高速”、“低速”、“中速”等风速别名映射，确保全仓风速档位空气动力学与电热功率动力学 100% 严格对齐；
     - 在 `AppModel` 中提供统一的 `currentIndoorHumidity(for:)` 属性访问器，收敛散落的多处温湿度属性读取；
     - 在语音状态查询（`queryStatus` / `queryStatusAll`）中联动温湿度双控，提供设备湿度与全屋平均环境湿度反馈。
  3. **macOS 原生状态栏多设备控制矩阵实时工况感知对称性与温湿度全景呈现 (`StatusItemController`)**：
     - 在状态栏右键菜单的「空调设备控制矩阵」各个子设备菜单项（`devSubmenu`）顶部，增设与单设备模式严格对称的实时工况感知禁用态标头（如 `🟢 客厅空调: ❄️ 制冷 26°C [强劲风] (室内 28°C · 55% RH)`），使多设备场景下每个房间设备的当前状态一目了然；
     - 在单设备工况标头与悬浮 Tooltip 设备行中，加入环境湿度感知展示（如 `(室内 26°C · 58% RH)`），提升视觉精致度与信息感知密度。

---

## 2. 关键架构变更与代码实现

### 2.1 口语“X度五/X度5”精确解析与停止关机意图闭环 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)
- **度五/度5正则归一化**：
  - 将 `degreeHalfPattern` 升级为 `degreeHalfOrFivePattern = #"([一二两三四五六七八九\d]+)度(?:半|五|5)"#`，无缝支持“二十六度五/26度5/开到25度5/制冷26度5/全屋26度5/调高一度五/升温1度5/降温一度五”；
  - 补充 `五分度 -> 0.5度` 替换。
- **停止类口语关机识别**：
  - `isPowerOff` 扩充停止关键词：`"停止运行", "停止运转", "停止工作", "停掉空调", "停掉", "停一下", "停止"`，并支持以 `停/停止/停了/停机` 开头与结尾的口语结构；
  - `isAllPowerOff` 扩充全屋停止口令：`"停止所有空调", "停止全部空调", "所有空调停止", "全部空调停止", "全屋停止", "所有空调都停了", "全部空调都停了", "全屋停机", "全部停机"`。
- **状态与温湿度查询扩展**：
  - 扩充查询词库，支持“空调开着吗/空调关了吗/空调开了没/空调关了没/室内湿度多少/查询湿度/查询状态”。
- **单元测试验证**：
  - 新增 `testOralDegreeFiveAndStoppingAndStatusQueries` 测试套件，覆盖 20 组真实用例，全部验证通过。

### 2.2 全风量档位扩展与温湿度双控收敛 (`EnergyAnalyticsEngine.swift` / `AppModel.swift` / `VoiceCapsuleWindowController.swift`)
- **全风量别名对齐**：
  - 在 `EnergyAnalyticsEngine.estimateInstantaneousPower` 与 `AppModel.calculateFilterWearFactor` 中，对“极速/高速/中速/低速”进行空气动力学系数统一映射。
- **温湿度双控属性收敛与语音反馈**：
  - `AppModel` 增设 `public func currentIndoorHumidity(for deviceId: String) -> Double?`；
  - `VoiceCapsuleWindowController` 的 `.queryStatus` 与 `.queryStatusAll` 增加环境相对湿度感知与平均湿度播报。

### 2.3 状态栏多设备矩阵工况对称与温湿度呈现 (`StatusItemController.swift`)
- **多设备矩阵标头对称化**：
  - 在 `devSubmenu` 顶部插入实时工况与温湿度感知信息标头（如 `🟢 客厅空调: ❄️ 制冷 26°C [强劲风] (室内 28°C · 55% RH)`），使多设备矩阵与单设备菜单完全对称；
- **Tooltip 与单设备标头丰富化**：
  - 注入设备当前相对湿度 `(室内 26°C · 58% RH)`。

---

## 3. 构建、测试与打包验证闭环
- **底层编译与语法校验**：
  - 运行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，全模块编译 100% 通过（Build complete!）；
- **应用打包与代码签名**：
  - 执行 `./build_app.sh 1.9.51` 打包，小组件（沙盒 + Application Support 只读例外）与主应用签名全部就绪；
  - 产出安装包：`dist/HaierAC-v1.9.51-macOS.zip`。
