# Haier AC Mac v1.9.124 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.124`
- **发版主题**：闭环十八核心关键词与十二连续区间全景排班大一统、蒸发器阶段一过冷凝露动力学及状态栏全息感知死角清零
- **核心目标与架构演进**：
  1. **“十八核心关键词全景排班、十二连续区间复合拓扑与口语极限绝决转折否定防御”自然口语调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **纯十八核心关键词全景调度 (`octodecaKeywordsRegex`)**：新增 `octodecaKeywordsRegex`，全面支持多达 18 种核心周期关键词连缀（“工作日、平时、平日、双休日、双休、周末三天、周末、公休日、休假日、放假日、节假日、单休日、单休、大休日、大休、大周、小周和小休每天早8点开机” `[1..7]`），十全十美闭环超高维排班最后一公里死角；
     - **十二连续独立区间与高维复合拓扑拓展 (`duodecemRangeRegex` / `undecemRangeWithKeywordRegex` / `keywordWithUndecemRangeRegex` / `undecemKeywordsWithDualRangeRegex`)**：
       - `duodecemRangeRegex`：十二连续独立区间复合口语调度（如“周一至周一、周二至周二、周三至周三、周四至周四、周五至周五、周六至周六、周日至周日、周一到周一、周二到周二、周三到周三、周四到周四加周五到周五每天早8点开机” `[1..7]`）；
       - `undecemRangeWithKeywordRegex`：十一连续区间在先、核心关键词在后（如“周一至周一、周二至周二、周三至周三、周四至周四、周五至周五、周六至周六、周日至周日、周一到周一、周二到周二、周三到周三、周四到周四加单休每天早8点开机” `[1..7]`）；
       - `keywordWithUndecemRangeRegex`：核心关键词在先、十一连续区间在后（如“单休加周一至周一、周二至周二、周三至周三、周四至周四、周五至周五、周六至周六、周日至周日、周一到周一、周二到周二、周三到周三、周四到周四每天早8点开机” `[1..7]`）；
       - `undecemKeywordsWithDualRangeRegex`：十一核心关键词在先、双连续区间在后（如“工作日、平时、平日、双休日、双休、周末三天、周末、公休日、休假日、放假日和大休加周六至周六、周日到周日每天早8点开机” `[1..7]`）；
     - **强化极端口语绝决转折否定与全方位动作谓词拦截扩充**：扩充“哪怕粉身碎骨也千万不要开/关”、“断无可能开/关”、“哪怕万劫不复也别开/关”、“无论天摇地动都不要开/关”等极端绝决转折否定句式，杜绝复杂口语语义穿透误触发；
     - **单元测试 132 项 100% 满分覆盖**：新增 `testDuodecemRangeAndOctodecaKeywordsV19124` 严苛测试套件，全套 132 个单元测试零缺陷通过（0 failures）。
  2. **56°C 蒸发器自清洁阶段 1 初期过冷凝露微相变潜热与压缩机润滑油低温粘度机械阻尼动力学模型 (`EnergyAnalyticsEngine.swift`)**：
     - **阶段 1/4 (0~5min, 深冷结霜凝水初期)**：引入第 0~2 分钟初期过冷凝露相变微潜热成核与冷态机械启动润滑油高粘度阻尼（$+0\text{W} \sim +25\text{W}$ 动态附加功），并随冰核成核完全冻结向 0W 单调平滑衰减，达成四阶段相变热力学全生命周期微观机制严格自洽。
  3. **macOS 状态栏自清洁全息感知死角彻底清零与 FilterCareSheet 动效质感升维 (`StatusItemController.swift` / `FilterCareSheet.swift`)**：
     - **状态栏多设备标头与矩阵标签自清洁感知死角清零**：在多设备级联工况标头 `devConditionTitle`（含 Tooltip）、设备矩阵项状态标签 `statusBadge`、单设备工况标头 `conditionTitle`（含 Tooltip）全面补齐 `✨ 56°C自清洁 [\(phaseTag) \(cleanPct)%]` 动态阶段与剩余倒计时全息看板；
     - **FilterCareSheet 自清洁动效与质感升维**：为进度条增加平滑插值过渡动画，为自清洁四相态微徽章增加精致发光描边、阴影与平滑过渡微动效。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下审查报告及全仓架构进行了全景复核与缺陷深挖：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 保持严格的结构化正则匹配，本轮进一步扩充极端转折口语与多动作谓词，杜绝插字绕过与语义遗漏；
   - **定时取消定向与全屋作用域区分 (P1-2)**：解析层严格区分 `.cancelSchedulesAll` 与 `.cancelSchedules`，UI 文案与执行范围完全对齐；
   - **工况占比计算属性 (P2-1)**：`EcoEnergySection` 已统一消费 `EnergyAnalyticsEngine` 的占比计算属性；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **十八核心关键词与十二连续区间全景排班 (高价值优化)**：补齐 `octodecaKeywordsRegex`、`duodecemRangeRegex`、`undecemRangeWithKeywordRegex`、`keywordWithUndecemRangeRegex` 及 `undecemKeywordsWithDualRangeRegex`，消灭高维极端自然口语复合排班的解析断裂死角；
   - **蒸发器阶段一过冷凝露微相变与低温机械阻尼动力学模型 (高价值优化)**：重构阶段 1 结霜初期潜热成核与低温润滑油阻尼动态衰减过程，与阶段 2 解冻熔化、阶段 3 烘干汽化、阶段 4 送风排湿全面贯通；
   - **状态栏多设备标头与矩阵标签自清洁感知死角清零 (高价值优化)**：彻底消除状态栏多设备标头与矩阵标签中自清洁时相与进度的显示死角，并在保养面板增加平滑动画与视觉微动效。

---

## 3. 关键架构变更与代码实现

### 3.1 十八核心关键词与十二连续区间复合排班引擎
- **`VoiceCommandParser.swift`**：
  ```swift
  // 十二连续独立区间调度
  private static let duodecemRangeRegex: NSRegularExpression? = { ... }()

  // 十一连续区间在先、核心关键词在后
  private static let undecemRangeWithKeywordRegex: NSRegularExpression? = { ... }()

  // 核心关键词在先、十一连续区间在后
  private static let keywordWithUndecemRangeRegex: NSRegularExpression? = { ... }()

  // 十一核心关键词在先、双连续区间在后
  private static let undecemKeywordsWithDualRangeRegex: NSRegularExpression? = { ... }()

  // 纯十八核心关键词全景正则
  private static let octodecaKeywordsRegex: NSRegularExpression? = { ... }()
  ```

### 3.2 蒸发器阶段一过冷凝露微相变与冷态机械阻尼动力学模型
- **`EnergyAnalyticsEngine.swift`**：
  ```swift
  // 阶段 1 (0~5 分钟, 深冷结霜凝水初期):
  let condensationRamp = max(0.0, (1.0 - (Double(cleaningMinutes) / 2.0)) * 25.0)
  cleaningPower = 380.0 + latentLoad + sensibleLoad + condensationRamp + (windOffset * 0.3)
  ```

### 3.3 状态栏多设备标头与矩阵标签感知死角清零
- **`StatusItemController.swift`**：
  ```swift
  // 多设备级联工况标头与 Tooltip
  let devConditionTitle = isCleaningThisDev ? "工况: ✨ 56°C自清洁 [\(phaseTag) \(cleanPct)%]" : "工况: \(statusText)"
  // 矩阵列表项
  let statusBadge = isCleaningThisDev ? " [✨ 56°C自清洁 \(phaseTag) \(cleanPct)%]" : (isOn ? " [开机]" : " [关机]")
  // 单设备工况标头与 Tooltip
  let conditionTitle = isCleaning ? "工况: ✨ 56°C自清洁 [\(phaseTag) \(cleanPct)%]" : "工况: \(statusText)"
  ```

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **132 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build -c release`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 运行 `./build_app.sh 1.9.124`：
   - 生成打包应用：`dist/HaierAC.app`（含小组件插件 `HaierACWidget.appex`）
   - 安装包：`dist/HaierAC-v1.9.124-macOS.zip` (大小: ~3.1MB)
   - SHA-256 校验和：`8598f90478a18c51a88e46889ff039c83394f49192cb00af1bffd688fdcf3698`

---

## 5. 发版验证清单
- [x] Code Review 历史问题与架构深度排查闭环；
- [x] 十八核心关键词全景排班及十二连续区间复合拓扑完成代码实现与测试；
- [x] 蒸发器阶段一初期过冷凝露微相变潜热与冷态机械阻尼动力学模型完成代码编写与验证；
- [x] 状态栏多设备标头与矩阵标签自清洁感知死角清零及 FilterCareSheet 动效质感升维；
- [x] 132 个单元测试 100% 通过（0 failures）；
- [x] Release 构建及 app 打包签名成功；
- [x] README.md / README.en.md 同步最新特性与文档；
- [x] 敏感数据脱敏复核：零隐私泄漏。
