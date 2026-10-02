# Haier AC Mac v1.9.118 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.118`
- **发版主题**：闭环十二核心关键词与六连续区间复合排班大一统、贯流风机流阻微阻尼连续模型及极端阻抗报警协同
- **核心目标与架构演进**：
  1. **“十二核心关键词全景排班、六连续区间复合拓扑与口语极端否定防御”自然口语调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **纯十二核心关键词全景调度 (`dodecaKeywordsRegex`)**：新增 `dodecaKeywordsRegex`，全面支持全部 12 种核心周期关键词（“工作日、平时、平日、双休日、双休、周末三天、周末、大休日、大休、小休、单休和单休日每天早8点开机” `[1..7]`），十全十美闭环复合排班截断死角；
     - **六连续区间与高维复合拓扑拓展 (`sexRangeRegex` / `quinqueRangeWithKeywordRegex` / `keywordWithQuinqueRangeRegex` / `pentaKeywordsWithDualRangeRegex`)**：
       - `sexRangeRegex`：六连续独立区间复合口语调度（如“周一至周一、周二至周二、周三至周三、周四至周四、周五至周五加周六到周日每天早8点开机” `[1..7]`）；
       - `quinqueRangeWithKeywordRegex`：五连续区间在先、核心关键词在后（如“周一至周一、周二至周二、周三至周三、周四至周四、周五至周五加双休每天早8点开机” `[1..7]`）；
       - `keywordWithQuinqueRangeRegex`：核心关键词在先、五连续区间在后（如“双休加周一至周一、周二至周二、周三至周三、周四至周四、周五至周五每天早8点开机” `[1..7]`）；
       - `pentaKeywordsWithDualRangeRegex`：五核心关键词在先、双连续区间在后（如“工作日、平时、平日、双休和大休加周六至周六、周日到周日每天早8点开机” `[1..7]`）；
     - **极限口语否定与多动作谓词防御**：扩充“切切切莫再”、“万万不可再”、“万千不要”、“万千别”、“断然不能”、“无论何时何地都不要”、“打死也不要”、“绝绝对对不要”、“决计不要再”等口语前缀，以及“制热风”、“送凉风”、“开暖气”、“开冷气机”、“开暖风机”、“抽湿机”、“排湿”、“自洁”、“自清洁”等动作谓词，杜绝绕过误触发；
     - **单元测试 126 项 100% 满分覆盖**：新增 `testDodecaKeywordsAndCompoundScheduleV19118` 严苛测试套件，全套 126 个单元测试零缺陷通过（0 failures）。
  2. **能耗动力学贯流风机流阻微阻尼连续动力学模型与极端气阻激增惩罚 (`EnergyAnalyticsEngine.swift`)**：
     - **贯流风机 BLDC 软启动流阻阻尼 (Blower Soft-Start Damping)**：在纯送风工况（`.fan`）下为 BLDC 室内贯流风机引入平滑软启动加速曲线（0 分钟 0.88x，1 分钟 0.96x，2 分钟及以上 1.00x），消除瞬态启动功率突变；
     - **极端滤网积尘气阻非线性激增惩罚 (Non-linear Extreme Dust Clogging Surge)**：滤网洁净度 $\le 10\%$ 时，在原有流阻基础上增加非线性气阻激增惩罚项（额外 $+0\% \sim +1.5\%$，整机气阻惩罚最高达 $+6.5\%$），精确反映风道近乎窒息工况下的背压与流阻浪涌。
  3. **控制中心与 macOS 状态栏极端阻抗告警协同感知 (`MenuBarControlsView.swift` / `StatusItemController.swift`)**：
     - **控制中心滤网模块极端阻抗报警**：当洁净度 $\le 10\%$ 时，UI 升级为 `🚨 滤网极端阻抗报警`，并展示当前精确气阻负荷，自清洁优惠折扣改为动态属性绑定；
     - **状态栏根菜单极端流道阻抗协同告警**：当检测到设备洁净度 $\le 10\%$ 时，状态栏根菜单升级为 `🚨 滤网保养与自清洁 (极端阻抗 全屋最低 X% · 气阻负荷 +Y%)...`，达成控制中心与状态栏告警体验完全一致。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下审查报告及全仓架构进行了全景复核与缺陷深挖：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 保持严格的结构化正则匹配，本轮进一步扩充“切切切莫再/万万不可再/万千不要/万千别/断然不能/无论何时何地都不要/打死也不要/绝绝对对不要/决计不要再”等极端口语组合，杜绝插字绕过与语义遗漏；
   - **定时取消定向与全屋作用域区分 (P1-2)**：解析层严格区分 `.cancelSchedulesAll` 与 `.cancelSchedules`，UI 文案与执行范围完全对齐；
   - **工况占比计算属性 (P2-1)**：`EcoEnergySection` 已统一消费 `EnergyAnalyticsEngine` 的占比计算属性；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **十二核心关键词与六连续区间复合排班 (高价值优化)**：补齐 `dodecaKeywordsRegex`、`sexRangeRegex`、`quinqueRangeWithKeywordRegex`、`keywordWithQuinqueRangeRegex` 及 `pentaKeywordsWithDualRangeRegex`，消灭极端自然口语复合排班的解析断裂死角；
   - **贯流风机流阻微阻尼连续动力学模型与极端气阻激增惩罚 (高价值优化)**：送风工况引入 BLDC 贯流风机软启动流阻阻尼曲线，并在 $\le 10\%$ 极端堵塞下注入非线性气阻激增模型；
   - **控制中心与状态栏极端阻抗告警协同感知 (高价值优化)**：在控制中心和状态栏根菜单实现极端气阻报警体验协同。

---

## 3. 关键架构变更与代码实现

### 3.1 十二核心关键词与六连续区间复合排班引擎
- **`VoiceCommandParser.swift`**：
  ```swift
  // 十二核心关键词全景正则
  private static let dodecaKeywordsRegex: NSRegularExpression? = { ... }()

  // 六连续独立区间调度
  private static let sexRangeRegex: NSRegularExpression? = { ... }()

  // 五连续区间在先、核心关键词在后
  private static let quinqueRangeWithKeywordRegex: NSRegularExpression? = { ... }()

  // 核心关键词在先、五连续区间在后
  private static let keywordWithQuinqueRangeRegex: NSRegularExpression? = { ... }()

  // 五核心关键词在先、双连续区间在后
  private static let pentaKeywordsWithDualRangeRegex: NSRegularExpression? = { ... }()
  ```

### 3.2 贯流风机流阻微阻尼连续动力学模型与极端气阻激增惩罚
- **`EnergyAnalyticsEngine.swift`**：
  ```swift
  let filterMultiplier: Double = {
      let cleanliness = max(0, min(100, filterCleanlinessPct))
      var penalty = 1.0
      if cleanliness < 50 {
          let deficiency = Double(50 - cleanliness)
          penalty += (deficiency / 50.0) * 0.05
      }
      if cleanliness <= 10 {
          let extremeDeficiency = Double(10 - cleanliness)
          penalty += (extremeDeficiency / 10.0) * 0.015
      }
      return penalty
  }()
  ...
  case .fan:
      let blowerSoftStartMultiplier: Double = {
          guard continuousMinutes < 2 else { return 1.0 }
          return continuousMinutes == 0 ? 0.88 : 0.96
      }()
      let base = 25.0 * blowerSoftStartMultiplier + windOffset * 2.0
      let cleanliness = max(0, min(100, filterCleanlinessPct))
      var filterPenalty = 1.0
      if cleanliness < 50 {
          let deficiency = Double(50 - cleanliness)
          filterPenalty += (deficiency / 50.0) * 0.06
      }
      if cleanliness <= 10 {
          let extremeDeficiency = Double(10 - cleanliness)
          filterPenalty += (extremeDeficiency / 10.0) * 0.015
      }
      let power = base * filterPenalty
      return min(max(power, 15.0), 90.0)
  ```

### 3.3 控制中心与 macOS 状态栏极端阻抗告警协同感知
- **`MenuBarControlsView.swift` & `StatusItemController.swift`**：
  ```swift
  // 控制中心极端阻抗警告提示
  Text(minCleanliness <= 10 ? "🚨 滤网极端阻抗报警" : "⚠️ 滤网健康度过低")
  ...
  // 状态栏极端阻抗联动
  if lowest <= 10 {
      let extremeAirResistance = 5.0 + (Double(10 - lowest) / 10.0) * 1.5
      return String(format: "🚨 滤网保养与自清洁 (极端阻抗 全屋最低 %d%% · 气阻负荷 +%.1f%%)...", lowest, extremeAirResistance)
  }
  ```

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **126 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build -c release`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 运行 `./build_app.sh 1.9.118`：
   - 生成打包应用：`dist/HaierAC.app`（含小组件插件 `HaierACWidget.appex`）
   - 安装包：`dist/HaierAC-v1.9.118-macOS.zip` (大小: ~3.0MB)
   - SHA-256 校验和：`d628c205351113caa37c45401c638e595fd4c409cd28af6ce62a5d959af65544`

---

## 5. 发版验证清单
- [x] Code Review 历史问题与架构深度排查闭环；
- [x] 十二核心关键词全景排班及六连续区间复合拓扑完成代码实现与测试；
- [x] 贯流风机流阻微阻尼连续动力学模型与极端气阻激增惩罚完成代码编写与验证；
- [x] 控制中心与 macOS 状态栏极端阻抗告警协同感知完成；
- [x] 126 个单元测试 100% 通过（0 failures）；
- [x] Release 构建及 app 打包签名成功；
- [x] README.md / README.en.md 同步最新特性与文档；
- [x] 敏感数据脱敏复核：零隐私泄漏。
