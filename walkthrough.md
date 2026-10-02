# Haier AC Mac v1.9.120 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.120`
- **发版主题**：闭环十四核心关键词与八连续区间全景排班大一统、蒸发器相变温湿度连续耦合动力学及多端自清洁百分比感知
- **核心目标与架构演进**：
  1. **“十四核心关键词全景排班、八连续区间拓扑与极端口语转折否定防御”自然口语调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **纯十四核心关键词全景调度 (`quattuordecaKeywordsRegex`)**：新增 `quattuordecaKeywordsRegex`，全面支持覆盖全部 14 种核心周期关键词（“工作日、平时、平日、双休日、双休、周末三天、周末、公休日、休假日、放假日、节假日、大休日、大休和小休每天早8点开机” `[1..7]`），十全十美闭环复合排班最后一公里死角；
     - **八连续独立区间与高维复合拓扑拓展 (`octoRangeRegex` / `septemRangeWithKeywordRegex` / `keywordWithSeptemRangeRegex` / `heptaKeywordsWithDualRangeRegex`)**：
       - `octoRangeRegex`：八连续独立区间复合口语调度（如“周一至周一、周二至周二、周三至周三、周四至周四、周五至周五、周六至周六、周日至周日加周一到周一每天早8点开机” `[1..7]`）；
       - `septemRangeWithKeywordRegex`：七连续区间在先、核心关键词在后（如“周一至周一、周二至周二、周三至周三、周四至周四、周五至周五、周六至周六、周日至周日加单休每天早8点开机” `[1..7]`）；
       - `keywordWithSeptemRangeRegex`：核心关键词在先、七连续区间在后（如“单休日加周一至周一、周二至周二、周三至周三、周四至周四、周五至周五、周六至周六、周日至周日每天早8点开机” `[1..7]`）；
       - `heptaKeywordsWithDualRangeRegex`：七核心关键词在先、双连续区间在后（如“工作日、平时、平日、双休日、双休、周末和大休加周六至周六、周日到周日每天早8点开机” `[1..7]`）；
     - **极端口语转折否定与多动作谓词防御**：扩充“任凭天塌下来也别”、“任凭天塌地陷都不要”、“任凭如何都不要”、“至死都不要”、“横竖都不要”、“断断不可”、“千万切莫”、“万望不要”、“切切莫要”、“无论风吹雨打都不要”、“无论何等境况都不要”、“切切莫再”、“万万切莫”、“百计不要”、“纵然天塌地陷也别”、“决计断不可”等极端绝决否定句式，以及“开电辅热”、“开强风”、“开微风”、“开弱风”、“关冷气”、“关暖气”、“停冷气”、“停暖风”、“制冷运行”、“制热运行”等动作谓词，杜绝任何复杂口语绕过与语义穿透误触发；
     - **单元测试 128 项 100% 满分覆盖**：新增 `testOctoRangeAndQuattuordecaKeywordsV19120` 严苛测试套件，全套 128 个单元测试零缺陷通过（0 failures）。
  2. **蒸发器相变温湿度连续耦合热力学动力学模型与时相精细映射 (`EnergyAnalyticsEngine.swift`)**：
     - **环境温湿度显热与潜热连续微耦合 (Coupled Ambient Sensible & Latent Heat Thermodynamics)**：
       - **阶段 1/4 (0~5min, 深冷结霜凝水)**：引入高湿空气凝露相变潜热负荷补偿（`indoorHumidity >= 60%`, 额外 $+0\text{W} \sim +50\text{W}$）与高温初始降温显热负荷补偿（`indoorTemp >= 25.0°C`, 额外 $+0\text{W} \sim +40\text{W}$）；
       - **阶段 2/4 (5~10min, 逆循环微解冻剥离)**：换向阀协同强力化霜剥离翅片积尘，额定 780W；
       - **阶段 3/4 (10~18min, 56°C 高温恒温杀菌烘干)**：引入室内低温环境自然对流散热负荷补偿（`indoorTemp <= 18.0°C`, 额外 $+0\text{W} \sim +50\text{W}$），维持 56°C 高温持续灭菌；
       - **阶段 4/4 (>=18min, 送风排湿冷却恢复)**：由贯流风机常温微风排出残余水汽并冷却翅片，同时受滤网积尘流阻连续微阻尼调制（$1.00 \sim 1.05$）；
     - **自清洁机时时相精细归类 (`accumulateSample`)**：在采样累计中，将自清洁机时依据动力学时相精确归类（阶段 1&2 归入冷冻相变 `runningCooling`、阶段 3 归入高温热力学 `runningHeating`、阶段 4 归入平稳送风 `runningFan`），彻底消除此前全程机械归类为制热导致的工况机时失真。
  3. **macOS 控制中心与状态栏自清洁实时百分比与相变连续感知 (`MenuBarControlsView.swift` / `StatusItemController.swift`)**：
     - **控制中心实时进度与阶段深度感知**：在自清洁 Pod 中动态展示百分比进度与阶段描述（如 `阶段 1/4 • 急速深冷结霜裹尘 (15%)`、`阶段 3/4 • 56°C 高温杀菌烘干 (65%)`），呈现高品质动态流；
     - **状态栏根菜单与滤网入口精细百分比呈现**：状态栏根菜单与滤网入口动态格式化为 `56°C 自清洁中 [凝霜裹尘 18%] (16m24s)...`，系统级常驻感知体验一目了然。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下审查报告及全仓架构进行了全景复核与缺陷深挖：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 保持严格的结构化正则匹配，本轮进一步扩充极端转折口语与多动作谓词，杜绝插字绕过与语义遗漏；
   - **定时取消定向与全屋作用域区分 (P1-2)**：解析层严格区分 `.cancelSchedulesAll` 与 `.cancelSchedules`，UI 文案与执行范围完全对齐；
   - **工况占比计算属性 (P2-1)**：`EcoEnergySection` 已统一消费 `EnergyAnalyticsEngine` 的占比计算属性；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **十四核心关键词与八连续区间全景排班 (高价值优化)**：补齐 `quattuordecaKeywordsRegex`、`octoRangeRegex`、`septemRangeWithKeywordRegex`、`keywordWithSeptemRangeRegex` 及 `heptaKeywordsWithDualRangeRegex`，消灭高维极端自然口语复合排班的解析断裂死角；
   - **蒸发器自清洁显热/潜热连续微耦合与时相精细机时映射 (高价值优化)**：将环境温湿度显热与潜热动态耦合进四阶段自清洁功率计算中，并在 `accumulateSample` 中依据真实相变时相精准分摊冷冻、制热与送风机时；
   - **控制中心与状态栏动态相变百分比感知联动 (高价值优化)**：在控制中心和状态栏根菜单实现自清洁阶段与实时百分比的无缝协同呈现。

---

## 3. 关键架构变更与代码实现

### 3.1 十四核心关键词与八连续区间复合排班引擎
- **`VoiceCommandParser.swift`**：
  ```swift
  // 八连续独立区间调度
  private static let octoRangeRegex: NSRegularExpression? = { ... }()

  // 七连续区间在先、核心关键词在后
  private static let septemRangeWithKeywordRegex: NSRegularExpression? = { ... }()

  // 核心关键词在先、七连续区间在后
  private static let keywordWithSeptemRangeRegex: NSRegularExpression? = { ... }()

  // 七核心关键词在先、双连续区间在后
  private static let heptaKeywordsWithDualRangeRegex: NSRegularExpression? = { ... }()

  // 纯十四核心关键词全景正则
  private static let quattuordecaKeywordsRegex: NSRegularExpression? = { ... }()
  ```

### 3.2 蒸发器自清洁温湿度连续耦合与时相精细映射
- **`EnergyAnalyticsEngine.swift`**：
  ```swift
  if isSelfCleaning {
      let cleaningMinutes = continuousMinutes
      let cleaningPower: Double
      if cleaningMinutes < 5 {
          let ramp = min(1.0, Double(cleaningMinutes) / 5.0)
          let latentFrost: Double = {
              guard let hum = indoorHumidity, hum >= 60.0 else { return 0.0 }
              return min(50.0, (hum - 60.0) * 1.25)
          }()
          let sensibleFrost: Double = {
              guard let indoor = indoorTemp, indoor >= 25.0 else { return 0.0 }
              return min(40.0, (indoor - 25.0) * 4.0)
          }()
          cleaningPower = 880.0 + (ramp * 80.0) + (windOffset * 0.4) + latentFrost + sensibleFrost
      } else if cleaningMinutes < 10 {
          cleaningPower = 780.0 + (windOffset * 0.3)
      } else if cleaningMinutes < 18 {
          let heatPhase = min(1.0, Double(cleaningMinutes - 10) / 8.0)
          let coldLoss: Double = {
              guard let indoor = indoorTemp, indoor <= 18.0 else { return 0.0 }
              return min(50.0, (18.0 - indoor) * 5.0)
          }()
          cleaningPower = 1000.0 + (heatPhase * 40.0) + (windOffset * 0.5) + coldLoss
      } else {
          let fanFilter = filterCleanlinessPct < 50 ? 1.0 + (Double(50 - max(0, filterCleanlinessPct)) / 50.0) * 0.05 : 1.0
          cleaningPower = (48.0 + (windOffset * 0.2)) * fanFilter
      }
      return min(max(cleaningPower, 40.0), 1250.0)
  }
  ```
  ```swift
  if sample.isSelfCleaning {
      // 自清洁依据执行时相精确映射至动力学分类 (v1.9.120: 消除全程笼统归入制热导致的机时失真)
      if sample.continuousMinutes < 10 {
          runningCooling += 1 // 阶段 1&2 急速深冷与微解冻冲刷归入冷冻相变工况
      } else if sample.continuousMinutes < 18 {
          runningHeating += 1 // 阶段 3 56°C 恒温烘干灭菌归入高温热力学工况
      } else {
          runningFan += 1     // 阶段 4 常温微风排湿冷却归入平稳送风工况
      }
  }
  ```

### 3.3 控制中心与 macOS 状态栏动态相变百分比感知联动
- **`MenuBarControlsView.swift` & `StatusItemController.swift`**：
  ```swift
  // 控制中心自清洁 Pod 动态展示实时百分比
  let cleanPct = min(100, max(0, Int(round((Double(elapsed) / 1200.0) * 100))))
  let phaseDesc: String = {
      if elapsed < 300 { return "阶段 1/4 • 急速深冷结霜裹尘 (\(cleanPct)%)" }
      else if elapsed < 600 { return "阶段 2/4 • 逆循环微解冻剥离 (\(cleanPct)%)" }
      else if elapsed < 1080 { return "阶段 3/4 • 56°C 高温杀菌烘干 (\(cleanPct)%)" }
      else { return "阶段 4/4 • 送风排湿冷却恢复 (\(cleanPct)%)" }
  }()
  ```
  ```swift
  // 状态栏根菜单动态阶段与百分比标签
  let cleanPct = min(100, max(0, Int(round((Double(elapsed) / 1200.0) * 100))))
  return "56°C 自清洁中 [\(phaseTag) \(cleanPct)%] (\(rem / 60)m\(rem % 60)s)..."
  ```

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **128 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build -c release`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 运行 `./build_app.sh 1.9.120`：
   - 生成打包应用：`dist/HaierAC.app`（含小组件插件 `HaierACWidget.appex`）
   - 安装包：`dist/HaierAC-v1.9.120-macOS.zip` (大小: ~3.0MB)
   - SHA-256 校验和：`44947e160610d449ebbd306b5356713cf48595f811843fef556bf242ee917ba7`

---

## 5. 发版验证清单
- [x] Code Review 历史问题与架构深度排查闭环；
- [x] 十四核心关键词全景排班及八连续区间复合拓扑完成代码实现与测试；
- [x] 蒸发器自清洁显热/潜热连续微耦合动力学及机时时相映射完成；
- [x] 控制中心与 macOS 状态栏动态相变百分比感知联动完成；
- [x] 128 个单元测试 100% 通过（0 failures）；
- [x] Release 构建及 app 打包签名成功；
- [x] README.md / README.en.md 同步最新特性与文档；
- [x] 敏感数据脱敏复核：零隐私泄漏。
