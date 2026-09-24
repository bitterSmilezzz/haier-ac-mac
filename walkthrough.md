# Haier AC Mac v1.9.36 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.36`
- **发版主题**：闭环 CR 审查缺陷、自然语言插字防误关、全屋/定向定时解耦、能耗动力学阻尼与状态栏全模式拓展
- **核心目标**：
  1. **彻底闭环外部 Code Review 审查报告（`docs/code-review/2026-09-24-1426.md`）中的全部遗留缺陷**：
     - **P1-1**：重构 `VoiceCommandParser.containsNegativeAction`，解决否定动作词与否定前缀之间插入任意字符（如“全屋空调别都关了”、“不要全部关掉”、“先别急着关”）导致否定意图失效误关全屋的严重缺陷，并补充单元测试；
     - **P1-2**：深度解耦全屋取消定时与定向单设备/多设备取消定时，新增 `VoiceCommand.cancelSchedulesAll`，统一执行范围与文案口径，补齐多设备定向定时批量清除；
     - **P2-1**：统一能耗工况机时比例计算的单一事实来源，`EcoEnergySection` 全面改用引擎的 `coolingRatio`、`heatingRatio`、`dehumRatio`、`fanRatio` 与补齐的 `unknownRatio`，消除零调用点公开 API 与重复计算；
     - **P2-2**：清理 `VoiceCapsuleWindowController.executeMultiDeviceCommand` 中不可达的死代码分支 `.adjustTemperatureAll`；
     - **P2-3**：补齐状态栏全屋升降温 16/30°C 极限硬件边界判定，并在 `AppModel.adjustTemperature` 中增加实际变更检测，杜绝冗余硬件下发与虚假提示；
     - **P2-4**：完善 `totalDeviceMinutes` 字段注释与文档说明，明确 v1.9.34 及更早记录的墙钟回填兼容策略。
  2. **高价值架构与产品体验自主演进优化**：
     - **优化点一（macOS 原生状态栏全模式对称拓展与运行态实时汇总）**：状态栏右键上下文菜单全面补齐「💧 全屋除湿」与「🍃 全屋送风」，在单设备菜单与设备矩阵各子菜单中同步增设「一键除湿」与「一键送风」；状态栏悬浮 Tooltip 顶部实时呈现全屋多设备运行汇总（如 `🏠 全屋 3 台空调中 2 台正在运行`）；
     - **优化点二（变频压缩机恒温维持态低频阻尼动力学模型）**：在 `EnergyAnalyticsEngine.estimateInstantaneousPower` 中引入变频热阻尼模型，当室内外温差接近 0 时平滑过渡到超低频恒温维持态（制冷 220W 稳态，制热 300W 稳态），更真实反映变频一级能效空调物理能耗。

---

## 2. 关键架构变更与代码实现

### 2.1 结构化否定动作识别器与插字防误触 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)
- **结构化正则匹配 (`negativeActionRegex`)**：
  - 将否定词前缀（“别”、“不要”、“不用”、“不必”、“无需”、“先别”、“暂不”、“千万别”等）与动作谓词（“关”、“停”、“开”、“启动”、“运转”、“打开”、“关闭”）之间的插入字进行字符类限定（`[都全部屋所有一起统通马上立刻赶紧急着再又先直接也把给将空调设备机器电源它这个那房间主卧客厅]{0,6}`）；
  - 彻底解决“全屋空调别都关了”、“不要全部关掉”、“先别急着关”、“别马上关”、“千万不要全部打开”、“别把全屋空调都关了”、“空调不用全开”等高频家庭口语；
  - 避免“室温别太高开26度”等非否定电源动作被误拦截；
- **测试回归防线**：
  - `VoiceCommandParserTests.testNegationProtection` 扩充各类插字关机与插字开机用例，杜绝倒退。

### 2.2 全屋与定向定时任务取消解耦 (`VoiceCommandParser.swift` / `VoiceCapsuleWindowController.swift`)
- **指令模型拆分**：
  - 新增 `VoiceCommand.cancelSchedulesAll`，解析器在遇到“取消所有定时”、“取消全部定时”、“取消全屋定时”、“全屋取消倒计时”等全屋口令时映射为 `.cancelSchedulesAll`，文案对齐为“取消全屋所有定时与倒计时”；单设备或未指明全屋时保持 `.cancelSchedules`；
- **全屋与多设备执行闭环**：
  - 顶层接入 `.cancelSchedulesAll`：原子清空 `model.scheduledActions.removeAll()`，并提示“已取消全屋所有定时与倒计时任务（共 N 个）”；
  - 多设备 `executeMultiDeviceCommand` 补齐 `case .cancelSchedules`：遍历目标设备集合，批量清除对应定时任务并给出清晰统计文案；
  - 移除不可达的 `.adjustTemperatureAll` 分支（闭环 CR P2-2）。

### 2.3 状态栏 16/30°C 边界门禁与 AppModel 冗余指令消除 (`StatusItemController.swift` / `AppModel.swift`)
- **状态栏全屋升降温边界校验**：
  - 「🔼 全屋统一升温 1°C」：仅在当前存在目标温度 `< 30.0` 的在线开机设备时启用；
  - 「🔽 全屋统一降温 1°C」：仅在当前存在目标温度 `> 16.0` 的在线开机设备时启用；
- **AppModel 极值下发保护**：
  - `adjustTemperature` 与 `adjustDeviceTemperature` 仅对目标温度与当前温度不相等的设备下发网络指令；
  - 当所有运行中设备已在极限边界时返回 0，并给出中性提示“已达到最高/最低温度上限”，杜绝网络资源浪费与虚假成功提示。

### 2.4 能耗工况比例单一事实来源与历史数据迁移 (`EnergyAnalyticsEngine.swift` / `EcoEnergySection.swift`)
- **单一事实来源**：
  - `EnergyDayRecord` 补齐 `unknownRatio` 计算属性；
  - `EcoEnergySection.swift` 移除视图内的手动百分比重算，全面改用 `today.coolingRatio`、`today.heatingRatio`、`today.dehumRatio`、`today.fanRatio`、`today.unknownRatio`；
- **历史记录向后兼容**：
  - 明确标注并处理 v1.9.34 及更早版本历史数据回填机制，保障 60 天数据安全过渡。

### 2.5 自主高价值优化点：全模式状态栏拓展与变频恒温阻尼
- **状态栏全模式覆盖与全屋态汇总**：
  - 右键菜单新增「💧 全屋舒爽除湿」与「🍃 全屋清新送风」；
  - 设备级联矩阵子菜单与单设备菜单同步补齐「一键除湿」与「一键送风」；
  - 菜单栏悬浮 Tooltip 顶部新增多设备汇总指示；
- **变频压缩机恒温平衡态低频阻尼**：
  - 当温差 $|\Delta T| \le 0.5^\circ\text{C}$ 时，变频压缩机功率平滑进入低频维持态（制冷 220W 稳态，制热 300W 稳态），消除突变跳变，精准契合物理规律。

---

## 3. 构建、测试与验证闭环
- **本地编译验证**：
  - 使用 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 错误，0 警告构建成功；
- **自动化测试断言验证**：
  - 运行覆盖 18 组断言的独立测试套件，全面验证插字否定保护、全屋取消定时、定向取消定时、正常开关机等场景，100% 验证通过；
- **应用打包与签名**：
  - 运行 `./build_app.sh 1.9.36`，生成 `dist/HaierAC.app`（包含 `HaierACWidget.appex` 桌面小组件扩展与沙盒权限配置）以及发布包 `dist/HaierAC-v1.9.36-macOS.zip`。
