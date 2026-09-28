# Haier AC Mac v1.9.50 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.50`
- **发版主题**：自然语言延迟倒计时语义闭环与防误立即关机、口语冷暖体感调温、全风量动力学校准及状态栏工况感知
- **核心目标与架构演进**：
  1. **自然语言延迟倒计时语义闭环与防误立即关机缺陷根治 (`VoiceCommandParser` / `VoiceCommandParserTests`)**：
     - **前置延迟助词与直接时长倒计时闭环**：彻底修复日常高频口语“过半小时关机”、“30分钟关机”、“延迟半小时关机”、“等一个小时关机”、“全屋过半小时关机”、“全屋30分钟关机”、“稍后30分钟开机”等因缺少“后”或“定时”关键词导致逃逸出倒计时判定，进而被立即开关机（`isPowerOff` / `isAllPowerOff`）提前拦截并执行立即关机的重大误操作隐患；
     - **延迟意图防误触守卫**：引入 `hasTimingOrCountdownIntent` 延迟时间意图守护，并在 `parseScheduleOrCountdown` 中全面支持延迟助词（过/等/延迟/延后/稍后）与直接时长表达式；
     - **钟点定时与倒计时判定层级优化**：优先判定钟点定时，确保具体钟点定时（含“差半小时八点关机”、“十点差五分关机”等逆序时间）与倒计时互不干扰、分秒不差；
     - **“点5”小数归一化与风量/动作否定保护**：补齐“点5”阿拉伯数字小数时间解析（如“1点5小时后关机”精确折算为 90 分钟），并在开关机判定中完善风量口令守卫（“开到最大”、“开三档风”正确识别为风速调节而非开启电源），同时扩充动作否定词涵盖送风与除湿，并特例放行日常高频关机口令“别吹了”。
  2. **自然语言口语化冷暖体感与相对调温扩展 (`VoiceCommandParser` / `VoiceCommandParserTests`)**：
     - 全面支持“暖和点”、“暖一点”、“更热一点”、“热点”、“凉快一点”、“凉快点”、“更冷一点”、“太冻了”、“冻死了”、“热死了”等日常高频体感表达；
     - 无缝联动全屋相对调温（如“全屋暖和点” -> 全屋升温 1°C，“全屋凉快一点” -> 全屋降温 1°C）。
  3. **全风量空气动力学能耗与滤网磨损衰减系数严格统一 (`EnergyAnalyticsEngine` / `AppModel`)**：
     - 在 `EnergyAnalyticsEngine.estimateInstantaneousPower` 与 `AppModel.calculateFilterWearFactor` 中，对风量档位判定进行多维度统配：覆盖英文枚举（`turbo`, `high`, `medium`, `mid`, `low`, `micro`, `quiet`, `mute`）、档位数字（`1~3档`, `一/二/三档`）以及口语化描述（`超强`, `强劲`, `大风`, `小风`, `最大`, `最小`）；
     - 彻底消除以往传入英文风速枚举或数字档位时在 `EnergyAnalyticsEngine` 中回退为 40W 默认基准导致的高风量电功率严重低估缺陷，实现全风量热力学能耗与空气动力学滤网积尘负荷的严格对称性仿真。
  4. **macOS 原生状态栏单机实时工况与室内温感知标头及悬浮 Tooltip 精致化 (`StatusItemController`)**：
     - 针对单设备用户场景，在状态栏右键上下文菜单顶部新增专属实时运行工况与室内温度感知标头（如 `🟢 客厅空调: ❄️ 制冷 26°C [强劲风] (室内 28°C)` 或 `⚪️ 客厅空调: 待机 (室内 28°C)`），无需打开面板即可掌握设备运行工况；
     - 状态栏悬浮 Tooltip 设备行全面优化：整数温度消除多余的 `.0` 展现（显示为 `26°C`），并同步展示当前风速档位标签（如 `[高风]`、`[中风]`、`[微风]`、`[自动风]`），视觉层级更加优雅、信息密度更高。

---

## 2. 关键架构变更与代码实现

### 2.1 延迟倒计时语义与防误立即关机闭环 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)
- **延迟助词与直接时长解析**：
  - 新增 `hasTimingOrCountdownIntent` 辅助判断，拦截 `isPowerOff`、`isPowerOn`、`isAllPowerOff`、`isAllPowerOn`；
  - 在 `parseScheduleOrCountdown` 中扩展 `isCountdownTrigger` 与 `hasDuration`，精准识别“过半小时关机”、“30分钟关机”、“延迟半小时关机”、“等一个小时关机”等口语并构建倒计时命令；
  - 调整优先级：优先检查具体钟点定时（`parseScheduleTime`），再进入倒计时解析，彻底解决逆序倒算钟点（如“差半小时八点关机”）与倒计时之间的边界竞争。
- **体感冷暖与动作否定守卫**：
  - 扩展 `warmerKeywords` 与 `coolerKeywords`，纳入“暖和点/更热一点/凉快一点/更冷一点”与“太冻了/冻死了/热死了”；
  - 扩展 `negativeActionRegex` 涵盖 `吹|送|抽|除`，并特例放行“别吹了”等同关机。
- **单元测试覆盖**：
  - 新增 `testCountdownDelayAndDirectDurationVariations`、`testColloquialRelativeTemperatureVariations` 与 `testFilterResetAndWindGuards`，覆盖超过 27 组真实自然语言口语用例，100% 校验通过。

### 2.2 全风量热力学电功率与滤网磨损空气动力学对齐 (`EnergyAnalyticsEngine.swift` / `AppModel.swift`)
- **多维度风量档位判定统配**：
  - 统一映射：强劲/Turbo（180W / 1.70）、高风/High（110W / 1.35）、中风/Medium（65W / 1.00）、低风/Low（35W / 0.80）、微风/Quiet（15W / 0.60）、自动风/Auto（40W / 1.00）；
  - 兼容英文枚举、数字档位与中文多变口语。

### 2.3 状态栏单机运行工况感知与悬浮 Tooltip 优化 (`StatusItemController.swift`)
- **单设备工况信息标头**：
  - 在单设备右键上下文菜单顶部新增禁用态信息标头，清晰展示当前状态、模式、目标温度、风速与室内温度；
- **Tooltip 整数温展示与风速标定**：
  - 消除整数温度的 `.0` 后缀，追加当前风速档位标签，提示信息更加干练明晰。

---

## 3. 构建、测试与打包验证闭环
- **底层编译与语法校验**：
  - 运行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，全模块编译 100% 通过（Build complete!）；
- **应用打包与代码签名**：
  - 执行 `./build_app.sh 1.9.50` 打包，小组件（沙盒 + Application Support 只读例外）与主应用签名全部就绪；
  - 产出安装包：`dist/HaierAC-v1.9.50-macOS.zip`（2.6MB）。
