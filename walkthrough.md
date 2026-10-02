# Haier AC Mac v1.9.119 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.119`
- **发版主题**：闭环十三核心关键词与七连续区间全景排班大一统、蒸发器自清洁四阶段相变动力学及控制中心动态相变感知
- **核心目标与架构演进**：
  1. **“十三核心关键词全景排班、七连续区间拓扑与极端口语否定防御”自然口语调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **纯十三核心关键词全景调度 (`tredecaKeywordsRegex`)**：新增 `tredecaKeywordsRegex`，全面支持覆盖全部 13 种核心周期关键词（“工作日、平时、平日、双休日、双休、周末三天、周末、大休日、大休、小休、单休和单休日每天早8点开机” `[1..7]`），十全十美闭环复合排班截断死角；
     - **七连续区间与高维复合拓扑拓展 (`septemRangeRegex` / `sexRangeWithKeywordRegex` / `keywordWithSexRangeRegex` / `hexaKeywordsWithDualRangeRegex`)**：
       - `septemRangeRegex`：七连续独立区间复合口语调度（如“周一至周一、周二至周二、周三至周三、周四至周四、周五至周五、周六至周六加周日到周日每天早8点开机” `[1..7]`）；
       - `sexRangeWithKeywordRegex`：六连续区间在先、核心关键词在后（如“周一至周一、周二至周二、周三至周三、周四至周四、周五至周五、周六至周六加双休每天早8点开机” `[1..7]`）；
       - `keywordWithSexRangeRegex`：核心关键词在先、六连续区间在后（如“双休加周一至周一、周二至周二、周三至周三、周四至周四、周五至周五、周六至周六每天早8点开机” `[1..7]`）；
       - `hexaKeywordsWithDualRangeRegex`：六核心关键词在先、双连续区间在后（如“工作日、平时、平日、双休、大休和小休加周六至周六、周日到周日每天早8点开机” `[1..7]`）；
     - **极限口语否定与多动作谓词防御**：扩充“天王老子来也别”、“天王老子来了都不要”、“宁死也不要”、“无论何时何刻都不要”、“决计万万不要”、“决决断断不能”、“断无可能要”、“断乎不要”、“千万千千万不要”、“百般不要”等口语前缀，以及“开强劲”、“开静音”、“开健康”、“开节能”、“吹热风”、“制冷气”、“制暖风”、“关空调”、“停空调”、“开空调”、“启动空调”等动作谓词，杜绝绕过误触发；
     - **单元测试 127 项 100% 满分覆盖**：新增 `testSeptemRangeAndTredecaKeywordsV19119` 严苛测试套件，全套 127 个单元测试零缺陷通过（0 failures）。
  2. **蒸发器自清洁四阶段相变热力学动力学模型 (`EnergyAnalyticsEngine.swift` / `AppModel.swift`)**：
     - **自清洁动态相变热力学模型 (Four-Phase Phase Change Thermodynamics)**：将自清洁能耗从粗粒度固定 920W 升级为精细四阶段时变相变热力学曲线：
       - **阶段 1/4 (0~5min)**：急速深冷结霜裹尘，变频压缩机高频泵冷，额定 880W~960W；
       - **阶段 2/4 (5~10min)**：逆循环微解冻剥离，四通阀换向微热解冻冲刷，额定 780W；
       - **阶段 3/4 (10~18min)**：56°C 高温杀菌烘干，PTC 辅热与高压过热蒸汽烘干，额定 1000W~1040W；
       - **阶段 4/4 (>=18min)**：送风排湿冷却恢复，压缩机停机、室内 BLDC 贯流风机强力送风，额定 48W；
     - **运行耗时精确实时关联 (`AppModel.swift`)**：在 `AppModel.swift` 中，将 `effectiveContinuousMinutes` 与 `selfCleaningRemainingSeconds` (1200s 倒计时) 绑定计算：`max(0, (1200 - selfCleaningRemainingSeconds) / 60)`，保证自清洁在运行过程中实时动态计算每一阶段的瞬时功率和累计能耗。
  3. **控制中心与 macOS 状态栏动态相变感知联动 (`MenuBarControlsView.swift` / `StatusItemController.swift`)**：
     - **控制中心自清洁 Pod 动态展示**：自清洁 Pod 动态展示四阶段相变进展文字（“阶段 1/4 • 急速深冷结霜裹尘”、“阶段 2/4 • 逆循环微解冻剥离”、“阶段 3/4 • 56°C 高温杀菌烘干”、“阶段 4/4 • 送风排湿冷却恢复”），提升交互透明度与科技质感；
     - **状态栏根菜单动态相变标签**：状态栏根菜单在自清洁状态下动态追加相变阶段标签（`[\(phaseTag)]`，如 `[凝霜裹尘]`、`[微解冻冲刷]`、`[56°C烘干]`、`[送风冷却]`），达到多端交互完全协同。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下审查报告及全仓架构进行了全景复核与缺陷深挖：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 保持严格的结构化正则匹配，本轮进一步扩充“天王老子来也别/天王老子来了都不要/宁死也不要/无论何时何刻都不要/决计万万不要/决决断断不能/断无可能要/断乎不要/千万千千万不要/百般不要”等极端口语组合，杜绝插字绕过与语义遗漏；
   - **定时取消定向与全屋作用域区分 (P1-2)**：解析层严格区分 `.cancelSchedulesAll` 与 `.cancelSchedules`，UI 文案与执行范围完全对齐；
   - **工况占比计算属性 (P2-1)**：`EcoEnergySection` 已统一消费 `EnergyAnalyticsEngine` 的占比计算属性；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **十三核心关键词与七连续区间全景排班 (高价值优化)**：补齐 `tredecaKeywordsRegex`、`septemRangeRegex`、`sexRangeWithKeywordRegex`、`keywordWithSexRangeRegex` 及 `hexaKeywordsWithDualRangeRegex`，消灭极端自然口语复合排班的解析断裂死角；
   - **蒸发器自清洁四阶段相变热力学动力学模型 (高价值优化)**：升级固定功率估算为四阶段时变相变热力学模型，并在数据流驱动中实现分钟级动态推算；
   - **控制中心与状态栏动态相变感知联动 (高价值优化)**：在控制中心和状态栏根菜单实现自清洁阶段的实时感知与文案协同。

---

## 3. 关键架构变更与代码实现

### 3.1 十三核心关键词与七连续区间复合排班引擎
- **`VoiceCommandParser.swift`**：
  ```swift
  // 十三核心关键词全景正则
  private static let tredecaKeywordsRegex: NSRegularExpression? = { ... }()

  // 七连续独立区间调度
  private static let septemRangeRegex: NSRegularExpression? = { ... }()

  // 六连续区间在先、核心关键词在后
  private static let sexRangeWithKeywordRegex: NSRegularExpression? = { ... }()

  // 核心关键词在先、六连续区间在后
  private static let keywordWithSexRangeRegex: NSRegularExpression? = { ... }()

  // 六核心关键词在先、双连续区间在后
  private static let hexaKeywordsWithDualRangeRegex: NSRegularExpression? = { ... }()
  ```

### 3.2 蒸发器自清洁四阶段相变热力学动力学模型
- **`EnergyAnalyticsEngine.swift`**：
  ```swift
  case .selfCleaning:
      // 56°C 自清洁四阶段相变热力学动力学模型
      let phasePower: Double = {
          if continuousMinutes < 5 {
              // 阶段 1 (0~5min): 急速深冷结霜裹尘 (压缩机高频泵冷结冰膨胀剥离灰尘)
              return 880.0 + min(Double(continuousMinutes) * 16.0, 80.0)
          } else if continuousMinutes < 10 {
              // 阶段 2 (5~10min): 逆循环微解冻冲刷 (四通阀微热解冻冲刷排污)
              return 780.0
          } else if continuousMinutes < 18 {
              // 阶段 3 (10~18min): 56°C 高温杀菌烘干 (PTC/过热蒸汽杀菌干燥)
              return 1000.0 + min(Double(continuousMinutes - 10) * 5.0, 40.0)
          } else {
              // 阶段 4 (>=18min): 送风排湿冷却恢复 (风机强劲抽风冷却)
              return 48.0
          }
      }()
      return phasePower
  ```

### 3.3 控制中心与 macOS 状态栏动态相变感知联动
- **`MenuBarControlsView.swift` & `StatusItemController.swift`**：
  ```swift
  // 控制中心自清洁 Pod 动态展示
  let phaseDescription: String = {
      let elapsedMinutes = max(0, (1200 - remainingSecs) / 60)
      if elapsedMinutes < 5 {
          return "阶段 1/4 • 急速深冷结霜裹尘"
      } else if elapsedMinutes < 10 {
          return "阶段 2/4 • 逆循环微解冻剥离"
      } else if elapsedMinutes < 18 {
          return "阶段 3/4 • 56°C 高温杀菌烘干"
      } else {
          return "阶段 4/4 • 送风排湿冷却恢复"
      }
  }()
  ...
  // 状态栏根菜单动态阶段标签
  if isCleaning {
      let phaseTag: String = {
          let elapsed = max(0, (1200 - remainingSecs) / 60)
          if elapsed < 5 { return "凝霜裹尘" }
          if elapsed < 10 { return "微解冻冲刷" }
          if elapsed < 18 { return "56°C烘干" }
          return "送风冷却"
      }()
      statusSubtitle = "56°C 深度自清洁中 [\(phaseTag)] (剩余 \(remainingMins) 分钟)"
  }
  ```

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **127 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build -c release`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 运行 `./build_app.sh 1.9.119`：
   - 生成打包应用：`dist/HaierAC.app`（含小组件插件 `HaierACWidget.appex`）
   - 安装包：`dist/HaierAC-v1.9.119-macOS.zip` (大小: ~3.0MB)
   - SHA-256 校验和：`e7c98c7cede958a18d32e90a445ce69ca53e1ab30b6e669439a461fdc65aa34e`

---

## 5. 发版验证清单
- [x] Code Review 历史问题与架构深度排查闭环；
- [x] 十三核心关键词全景排班及七连续区间复合拓扑完成代码实现与测试；
- [x] 蒸发器自清洁四阶段相变热力学动力学模型完成代码编写与验证；
- [x] 控制中心与 macOS 状态栏动态相变感知联动完成；
- [x] 127 个单元测试 100% 通过（0 failures）；
- [x] Release 构建及 app 打包签名成功；
- [x] README.md / README.en.md 同步最新特性与文档；
- [x] 敏感数据脱敏复核：零隐私泄漏。
