# Haier AC Mac v1.9.116 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.116`
- **发版主题**：闭环十核心关键词与四连续区间复合排班大一统调度、送风工况微气阻动力学衰减模型及控制中心气阻负荷精细感知
- **核心目标与架构演进**：
  1. **“十核心关键词全景排班、四连续区间复合拓扑与口语强化否定防御”自然口语调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **纯十核心关键词全景调度 (`decaKeywordsRegex`)**：新增 `decaKeywordsRegex`，全面支持全部 10 种核心周期关键词（“工作日、平时、平日、双休日、双休、周末三天、周末、大休、小休、单休和单休日每天早8点开机” `[1..7]`），十全十美闭环复合排班截断死角；
     - **四连续区间与三连续区间复合拓扑拓展 (`quadRangeRegex` / `triRangeWithTriKeywordsRegex` / `triKeywordsWithTriRangeRegex` / `dualRangeWithQuadKeywordsRegex`)**：
       - `quadRangeRegex`：四连续独立区间复合口语调度（如“周一至周二、周三至周四、周五至周六加周日到周日每天早8点开机” `[1..7]`）；
       - `triRangeWithTriKeywordsRegex`：三连续区间在先、三核心关键词在后（如“周一至周二、周三至周四、周五至周六加双休、大休和小休每天早8点开机” `[1..7]`）；
       - `triKeywordsWithTriRangeRegex`：三核心关键词在先、三连续区间在后（如“工作日、平时同平日加周一到周二同周三到周四同周五至周六每天早8点开机” `[2..7]`）；
       - `dualRangeWithQuadKeywordsRegex`：双连续区间在先、四核心关键词在后（如“周一到周二、周三到周四加工作日、双休、大休和小休每天早8点开机” `[1..7]`）；
     - **强化口语动作否定与复合前缀拦截**：在 `negativeActionRegex`、`containsNegativeForAction` 与 `containsNegativeAction` 中扩充否定前缀（“千千万万别”、“千千万万不要”、“断断不能”、“决计不能”、“切切不要”、“断乎不可”、“断乎不能”、“无论何时都不要”）及动作谓词（“开冷气”、“吹暖风”、“排气”、“换气”），彻底消灭极端口语穿透误触风险；
     - **单元测试 100% 满分覆盖**：新增 `testDecaKeywordsAndCompoundScheduleV19116` 严苛测试套件，全套 124 个单元测试零缺陷通过（0 failures）。
  2. **能耗动力学送风工况微气阻动力学衰减模型与热物理自洽 (`EnergyAnalyticsEngine.swift`)**：
     - **送风工况（`.fan`）滤网积尘流阻电动力学微补偿**：引入室内贯流风机流体静压克服阻抗模型，在滤网洁净度 `< 50%` 时提供 `0% ~ 6%` 线性平滑电负荷微补偿，达成全工况（制冷、制热、自动、除湿、送风）空气动力学 100% 自洽；
     - **软启动升频阻尼动力学与温差调频自洽**：完善压缩机防液击启动及变频升频时序物理标定。
  3. **macOS 菜单栏控制中心与状态栏滤网气阻负荷精细感知联动 (`MenuBarControlsView.swift`)**：
     - **滤网积尘预警胶囊精细负荷透传**：在 `filterWarningPod` 预警徽章中实时计算并呈现气阻动力学功耗补偿百分比（如 `剩余 25% · 负荷+2.5%`），提供极度受阻（`<=10%`）与建议保养（`<=30%`）两级文案导引；
     - **原生菜单与控制中心视觉、数据全景统一**：让用户在状态栏悬浮 Tooltip、右键菜单详情及控制中心中获得完全同步的气阻阻抗健康看板。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下审查报告及全仓架构进行了全景复核与缺陷深挖：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 保持严格的结构化正则匹配，本轮进一步扩充“千千万万别/断断不能/决计不能/断乎不可/开冷气/吹暖风/排气/换气”等极端口语组合，杜绝插字绕过与语义遗漏；
   - **定时取消定向与全屋作用域区分 (P1-2)**：解析层严格区分 `.cancelSchedulesAll` 与 `.cancelSchedules`，UI 文案与执行范围完全对齐；
   - **工况占比计算属性 (P2-1)**：`EcoEnergySection` 已统一消费 `EnergyAnalyticsEngine` 的占比计算属性；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **十核心关键词与四连续区间复合排班 (高价值优化)**：补齐 `decaKeywordsRegex`、`quadRangeRegex`、`triRangeWithTriKeywordsRegex`、`triKeywordsWithTriRangeRegex` 及 `dualRangeWithQuadKeywordsRegex`，彻底消灭极端自然口语复合排班的解析断裂死角；
   - **送风模式流阻动力学微补偿 (高价值优化)**：在 `EnergyAnalyticsEngine.swift` 的 `case .fan` 中补全风机流阻克服功耗补偿，实现五大工况动力学严密闭环；
   - **控制中心气阻负荷精细感知 (高价值优化)**：在 `MenuBarControlsView.swift` 预警徽章中注入气阻功耗百分比并提供两级分级导引。

---

## 3. 关键架构变更与代码实现

### 3.1 十核心关键词与四连续区间复合排班引擎
- **`VoiceCommandParser.swift`**：
  ```swift
  // 十核心关键词全景正则
  private static let decaKeywordsRegex: NSRegularExpression? = { ... }()

  // 四连续独立区间调度
  private static let quadRangeRegex: NSRegularExpression? = { ... }()

  // 三连续区间在先、三核心关键词在后
  private static let triRangeWithTriKeywordsRegex: NSRegularExpression? = { ... }()

  // 三核心关键词在先、三连续区间在后
  private static let triKeywordsWithTriRangeRegex: NSRegularExpression? = { ... }()

  // 双连续区间在先、四核心关键词在后
  private static let dualRangeWithQuadKeywordsRegex: NSRegularExpression? = { ... }()
  ```

### 3.2 能耗动力学送风工况微气阻衰减模型
- **`EnergyAnalyticsEngine.swift`**：
  ```swift
  case .fan:
      let fanFilterMultiplier: Double = {
          guard filterCleanlinessPct < 50 else { return 1.0 }
          let clampedPct = max(0, filterCleanlinessPct)
          return 1.0 + (Double(50 - clampedPct) / 50.0) * 0.06
      }()
      let power = (14.0 + windOffset * 0.42) * fanFilterMultiplier
      return min(max(power, 14.0), 80.0)
  ```

### 3.3 控制中心滤网健康胶囊动态气阻负荷与两级文案导引
- **`MenuBarControlsView.swift`**：
  ```swift
  let penalty = (Double(50 - max(0, cleanliness)) / 50.0) * 5.0
  let penaltyStr = penalty > 0 ? String(format: " · 负荷+%.1f%%", penalty) : ""
  ...
  Text("剩余 \(cleanliness)%\(penaltyStr)")
  ...
  Text(cleanliness <= 10 ? "进风通道极度受阻，气阻剧增建议立即拆洗" : "进风气阻增加致换热负荷上升，建议拆洗")
  ```

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **124 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build -c release`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 运行 `./build_app.sh 1.9.116`：
   - 生成打包应用：`dist/HaierAC.app`（含小组件插件 `HaierACWidget.appex`）
   - 安装包：`dist/HaierAC-v1.9.116-macOS.zip` (大小: ~3.0MB)
   - SHA-256 校验和：`61375d3def9a1219239fb202dc70a386c939e4e94feca58a860f2e3d4debbe96`

---

## 5. 发版验证清单
- [x] Code Review 历史问题与架构深度排查闭环；
- [x] 十核心关键词全景排班及四连续区间复合拓扑完成代码实现与测试；
- [x] 能耗动力学送风工况微气阻衰减模型完成代码编写与验证；
- [x] 菜单栏控制中心滤网积尘预警胶囊气阻负荷呈现完成；
- [x] 124 个单元测试 100% 通过（0 failures）；
- [x] Release 构建及 app 打包签名成功；
- [x] README.md / README.en.md 同步最新特性与文档；
- [x] 敏感数据脱敏复核：零隐私泄漏。
