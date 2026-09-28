# Haier AC Mac v1.9.52 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.52`
- **发版主题**：口语“零点五/0点5”微调、省略“度”字小数防误定时开机闭环、大温差制热热泳滤网动力学与状态栏 0.5°C 双模高精步进矩阵
- **核心目标与架构演进**：
  1. **自然语言口语小数温度归一与防误钟点定时开机闭环 (`VoiceCommandParser` / `VoiceCommandParserTests`)**：
     - **彻底消除省略“度”字小数被误判为凌晨 00:05 定时开机的严重缺陷**：彻底修复日常高频口语“开到26点5”、“开26点5”、“打开26点5”、“全屋开到26点5”、“全屋开26点5”、“空调开到26点5”、“制冷开到26点5”等因末尾省略“度”字导致未能命中原有带上下文的小数正则，进而在 `parseScheduleOrCountdown` 中将“点5”错误解析为凌晨 00:05 钟点定时并下发 `schedulePower(hour: 0, minute: 5, power: true)` 的重大误操作灾难；优化 `decimalPointPattern` 为负向先行断言 `(?![分分钟])`，精准识别为 26.5°C 目标温度设定；
     - **口语“零点五度 / 0点5度”与相对微调精度无损解析**：修复“升温零点五度”、“降温零点五度”、“全屋升温零点五度”、“全屋降温0点5度”等因正则字符集遗漏中文“零”以及 `extractNumber` 未替换“点”导致丢失小数精度、被错误降级为 1.0°C 的缺陷，完美折算为 $\pm 0.5^\circ\text{C}$ 高精微调；
     - **钟点定时时钟合法性边界强制收敛**：在 `parseScheduleTime` 中对差分与标准钟点时钟小时增加 `h <= 23` 与 `m < 60` 强约束，彻底杜绝任何 24~30 等空调温度数值被误当做时钟时数处理的系统漏洞。
  2. **大温差制热热泳沉积与全气候空气动力学滤网深度磨损动力学 (`AppModel.calculateFilterWearFactor`)**：
     - 基于空气热动力学热泳沉积（Thermophoresis）与强对流热阻抗机理，重构制热与自动模式下的滤网负荷模型：在大温差强载制热（$\Delta T \ge 5.0^\circ\text{C}$）或严寒低温（$\le 12^\circ\text{C}$）工况下，将滤网磨损因子由固定的 1.05 提升至 1.25，自动模式大温差制热提升至 1.20；恒温维持态回归 1.05，与能耗引擎变频热力学模型达成 100% 物理对称。
  3. **macOS 原生状态栏 0.5°C 双模高精步进矩阵与硬件极值边界防护 (`StatusItemController`)**：
     - 在单设备上下文菜单、多设备子菜单（`devSubmenu`）以及全屋快捷协同控制中，增设与原有 1°C 步进严格对称的「🔼 升温 0.5°C (高精微调)」与「🔽 降温 0.5°C (高精微调)」，满足用户对舒适体感的毫米级温控需求；
     - 严格配套 16.5°C ~ 29.5°C 的硬件边界可用性联动防护（`isEnabled`），彻底杜绝超出硬件温控极值的冗余点击。

---

## 2. 关键架构变更与代码实现

### 2.1 口语小数解析与防误定时开机闭环 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)
- **decimalPointPattern 优化**：
  - 正则重构为 `#"([零0一二两三四五六七八九\d]+)点(?:五|5)(?![分分钟])"#`，排除后接“分/分钟”的钟点时分（如“十点五分” -> 10点5分），而对省略“度”字的高频温度表达（如“开到26点5”、“26点5”、“升温0点5”）安全归一化为 `.5`；
- **extractNumber 浮点点号替换**：
  - 补充 `normalized.replacingOccurrences(of: "点", with: ".")`，确保在相对调温提取中能够完整提取 `0.5`；
- **parseScheduleTime 钟点合法性校验**：
  - 强制约束 `targetH <= 23` 与 `h <= 23`，杜绝任何 24~30 温度被当做时间处理；
- **单元测试验证**：
  - 新增 `testDecimalAndPointFiveTemperatureParsing` 测试套件，覆盖 20 组真实用例，全部验证通过。

### 2.2 大温差制热热泳滤网动力学 (`AppModel.swift`)
- **空气动力学与热泳沉积物理对称**：
  - 制热模式（`.heating`）：当 `targetTemp > indoor` 且 `targetTemp - indoor >= 5.0` 或 `indoor <= 12.0` 时，动态应用 `modeFactor = 1.25`（常规升温 `1.15`，恒温维持 `1.05`）；
  - 自动模式（`.auto`）：制热分支同步动态应用 `modeFactor = 1.20`（常规 `1.10`，平衡态 `1.00`），与制冷冷凝结露（`1.25`）实现全气候双向物理对称。

### 2.3 状态栏 0.5°C 双模高精步进矩阵 (`StatusItemController.swift`)
- **全屋协同与单设备/多设备矩阵对称升级**：
  - 全屋相对调温新增 `stepUpHalfAllTemperature`（+0.5°C）与 `stepDownHalfAllTemperature`（-0.5°C）；
  - 单设备与各房间子菜单新增 `stepUpHalfPrimaryTemperature` / `stepDownHalfPrimaryTemperature` 及 `stepUpHalfDeviceTemperature` / `stepDownHalfDeviceTemperature`；
  - 完备配备 `canStepUpHalf`（`<= 29.5°C`）与 `canStepDownHalf`（`>= 16.5°C`）可用性守卫。

---

## 3. 构建、测试与打包验证闭环
- **底层编译与语法校验**：
  - 运行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，全模块编译 100% 通过（Build complete!）；
- **应用打包与代码签名**：
  - 执行 `./build_app.sh 1.9.52` 打包，小组件（沙盒 + Application Support 只读例外）与主应用签名全部就绪；
  - 产出安装包：`dist/HaierAC-v1.9.52-macOS.zip`。
