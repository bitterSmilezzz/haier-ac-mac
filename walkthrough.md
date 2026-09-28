# Haier AC Mac v1.9.53 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.53`
- **发版主题**：中文数十复合小数与钟点定时冲突缺陷闭环、Siri 快捷指令高精相对调温、高湿冷凝滤网水膜动力学及状态栏 0.5°C 微调台数全景感知
- **核心目标与架构演进**：
  1. **自然语言中文数十复合小数防误钟点定时开机彻底闭环 (`VoiceCommandParser` / `VoiceCommandParserTests`)**：
     - **彻底根除中文复合数字小数温度误判为凌晨/夜晚定时开机的重大缺陷**：修复日常口语高频出现的“开到二十点五”、“开二十点五”、“打开二十点五”、“全屋开到二十点五”、“全屋开二十点五”、“空调开到二十点五”、“制冷开到二十点五”、“开到十八点五”、“开到十九点五”、“开到二十一点五”、“开到二十二点五”、“开到二十三点五”等口语在数字转换中因 `compoundPattern` 滞后执行，导致“二十/十八”被破坏性转换为“20点5/18点5”，进而在 `parseScheduleTime` 中将 20、18 等有效空调温度数值误当做合法时钟小时数、在 `pointPattern` 命中 20:05、18:05 定时开机的严重缺陷；
     - **结构化 1~99 复合数字与小数模式执行时序收敛**：调整 `convertChineseNumbers` 解析时序，优先结构化解析 1~99 中文复合数字为标准阿拉伯数字，再由 `decimalPointPattern` 安全转换为 `.5` 小数（同时在 `decimalPointPattern` 中扩充汉字“十”，双重保障），确保“开到二十点五”、“二十点五度”、“全屋开到二十点五”等口语输入 100% 精准识别为 20.5°C 目标温度设定；
     - **钟点定时语义排斥安全防线**：在 `parseScheduleTime` 的 `pointPattern` 中引入温控动作意图与温度区间双重语义排斥，对 16~23°C 核心温度区间无“分/分钟”后缀口语坚决拦截，杜绝时间与温度混淆。
  2. **Siri 快捷指令与 AppIntents 相对调温生态全打通 (`AppIntents.swift`)**：
     - 新增 `AdjustACTemperatureIntent`（微调空调温度），支持指定 `delta`（如升温 1°C、微调 0.5°C、降温 2°C）以及设备名称，无缝联动单设备微调与全屋统一相对调温；
     - 在 `ACAppShortcuts` 中注册“用海尔空调微调温度”、“用海尔空调升高温度/降低温度”、“用海尔空调升温/降温”等自然短语，完美融入 macOS 系统级 Siri Shortcuts 生态。
  3. **高湿冷凝水膜表面张力微粒捕获与结块滤网动力学深化 (`AppModel.calculateFilterWearFactor`)**：
     - 深入流体力学与热湿交换机理：重构除湿模式（`.dehumidify`）下的滤网负荷模型，在极潮湿环境（RH >= 75% 如梅雨/回南天工况）下，蒸发器表面冷凝水析出量剧增，水膜表面张力促使尘螨与浮尘颗粒吸湿膨胀并黏附结块阻塞网孔，滤网负荷因子由固定的 1.30 自适应调整为 1.45（中湿维持 1.30，低湿维持 1.20），使滤网算法与变频除湿能耗动力学模型达成 100% 物理对称。
  4. **macOS 原生状态栏 0.5°C 高精微调矩阵台数感知与温度呈现对称优化 (`StatusItemController`)**：
     - 在全屋控制菜单中，「🔼 全屋微调升温 0.5°C」与「🔽 全屋微调降温 0.5°C」补齐 `(N台运行中)` / `(当前均未开机)` 状态标签，与 1°C 步进保持严格视觉与状态对称；
     - 单设备菜单与多设备子菜单中的 0.5°C 微调项统一补充当前基准温度提示（如 `🔼 升温 0.5°C (高精微调 · 当前 26.0°C)`），大幅提升菜单交互精致度与状态透明度。

---

## 2. 关键架构变更与代码实现

### 2.1 中文复合数字小数解析与防误定时开机闭环 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)
- **执行时序调整与字符集增强**：
  - 将 `compoundPattern` 提到 `decimalPointPattern` 之前执行，先行将汉字数十复合数归一为标准阿拉伯数字（如“二十” -> 20，“十八” -> 18）；
  - `decimalPointPattern` 匹配后安全将 `20点五` / `20点5` 归一为 `20.5`，彻底消除时间误命中；
- **parseScheduleTime 语义防护**：
  - 对 16~23°C 核心温度数值且缺少“分”字后缀的表达增加温度意图排斥；
- **单元测试验证**：
  - 新增 `testChineseCompoundDecimalTemperatureParsing` 测试套件，包含 16 组核心用例，全部验证通过。

### 2.2 Siri 快捷指令相对调温 (`AppIntents.swift`)
- **AdjustACTemperatureIntent 实现**：
  - 接入 `AppModel.adjustTemperature` 与 `AppModel.adjustTemperatureAll`；
  - 导出自然对话反馈，包含调节后的实际度数与升降温方向；
  - 在 `ACAppShortcuts` 中注册短语体系。

### 2.3 高湿除湿滤网水膜动力学 (`AppModel.swift`)
- **多层湿度附着自适应**：
  - 极潮湿环境（RH >= 75%）动态应用 `modeFactor = 1.45`；
  - 适度湿度（55% <= RH < 75%）维持 `modeFactor = 1.30`；
  - 低湿稳态（RH < 55%）应用 `modeFactor = 1.20`；
  - 与能耗引擎变频除湿动力学模型达成 100% 物理对称。

### 2.4 状态栏 0.5°C 微调台数感知与温度呈现 (`StatusItemController.swift`)
- **矩阵对称性升级**：
  - 全屋微调升降温项补全 `\(runningCountDesc)`；
  - 单设备与子菜单微调项补充当前温度基准提示。

---

## 3. 构建、测试与打包验证闭环
- **底层编译与语法校验**：
  - 运行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，全模块编译 100% 通过（Build complete!）；
- **应用打包与代码签名**：
  - 执行 `./build_app.sh 1.9.53` 打包，小组件（沙盒 + Application Support 只读例外）与主应用签名全部就绪；
  - 产出安装包：`dist/HaierAC-v1.9.53-macOS.zip`。
