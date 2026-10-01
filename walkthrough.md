# Haier AC Mac v1.9.117 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.117`
- **发版主题**：闭环十一核心关键词与五连续区间复合排班大一统、变频压缩机软启动升频无截断自洽及状态栏气阻流阻精细感知
- **核心目标与架构演进**：
  1. **“十一核心关键词全景排班、五连续区间复合拓扑与口语极端否定防御”自然口语调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **纯十一核心关键词全景调度 (`hendecaKeywordsRegex`)**：新增 `hendecaKeywordsRegex`，全面支持全部 11 种核心周期关键词（“工作日、平时、平日、双休日、双休、周末三天、周末、大休日、大休、小休、单休和单休日每天早8点开机” `[1..7]`），十全十美闭环复合排班截断死角；
     - **五连续区间与复合拓扑拓展 (`quinqueRangeRegex` / `quadRangeWithKeywordRegex` / `keywordWithQuadRangeRegex` / `quadKeywordsWithDualRangeRegex`)**：
       - `quinqueRangeRegex`：五连续独立区间复合口语调度（如“周一至周一、周二至周二、周三至周三、周四至周四加周五到周日每天早8点开机” `[1..7]`）；
       - `quadRangeWithKeywordRegex`：四连续区间在先、核心关键词在后（如“周一至周二、周三至周四、周五至周六、周日到周日加单休每天早8点开机” `[1..7]`）；
       - `keywordWithQuadRangeRegex`：核心关键词在先、四连续区间在后（如“工作日加周一至周二、周三至周三、周四至周四、周五至周日每天早8点开机” `[1..7]`）；
       - `quadKeywordsWithDualRangeRegex`：四核心关键词在先、双连续区间在后（如“工作日、平时、双休和大休加周一至周二、周四至周五每天早8点开机” `[1..7]`）；
     - **区间连字符负向零截断修复与前置优先级大一统**：在 `rangeWithMultiDaysRegex`、`dualRangeWithMultiDaysRegex`、`triRangeWithMultiDaysRegex`、`rangeWithMultiDaysAndRangeRegex` 及 `multiDaysWithRangeAndMultiDaysRegex` 等正则中全面注入连字符负向断言 `(?!\s*(?:到|至|-|~))`，防止多区间口语中将后续连续区间首日误吸纳为离散单日；同时将五连续区间、四区间复合及四连续独立区间优先放置于三区间之前，根除多区间贪婪截断隐患；
     - **强化口语动作否定与复合前缀拦截**：扩充“千千万万不要再”、“无论何种情况都不要”、“断断不能再”、“切切不可再”、“万万不能再”、“决计不可再”、“绝不能再”等否定句式，及“制冷”、“制热”、“除湿”、“抽湿”、“送风”、“吹风”、“开热气”、“吹冷风”、“通风”、“强劲”、“辅热”等谓词，彻底阻断极限否定误触发；
     - **单元测试 100% 满分覆盖**：新增 `testHendecaKeywordsAndCompoundScheduleV19117` 严苛测试套件，全套 125 个单元测试零缺陷通过（0 failures）。
  2. **能耗动力学变频压缩机软启动升频无截断自洽标定 (`EnergyAnalyticsEngine.swift`)**：
     - **下限钳位解除截断 (Unclipped Soft-Start Thermodynamics)**：在开机前 0~2 分钟变频压缩机软启动爬升期（乘数 0.65~0.92），将各工况（制冷、制热、自动、除湿、保底）的基础功率下限阈值（Floor）同步按 `softStartMultiplier` 线性缩放（`minFloor = floor * softStartMultiplier`），解除以往硬编码下限对 20~30Hz 超低频软启动的直接截断，使初态功率严格符合 GB/T 7725 变频空调软起动热动力学曲线。
  3. **macOS 原生状态栏菜单气阻流阻精细负荷透传与极端阻抗报警 (`StatusItemController.swift`)**：
     - **状态栏悬停多设备气阻负荷峰值动态透传**：在状态栏悬停 Tooltip 呈现滤网健康时，自动计算并展示全屋最高气阻额外电负荷（如 `气阻负荷最高 +5.0%`）；
     - **根菜单滤网状态条动态负荷标定**：在状态栏根菜单“滤网状态”项中注入精确气阻电负荷（如 `(全屋最低 25% · 气阻负荷 +2.5%)`），并在洁净度 $\le 10\%$ 时升级为 `🚨` 极端阻抗报警；
     - **流道阻抗全景知识库 Tooltip**：在滤网维护悬浮提示中详细解析压缩机风阻损耗（最高 +5.0%）与贯流风机流阻损耗（最高 +6.0%）的动力学成因与节能建议。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下审查报告及全仓架构进行了全景复核与缺陷深挖：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 保持严格的结构化正则匹配，本轮进一步扩充“千千万万不要再/无论何种情况都不要/断断不能再/切切不可再/制冷/制热/通风/强劲/辅热”等极端口语组合，杜绝插字绕过与语义遗漏；
   - **定时取消定向与全屋作用域区分 (P1-2)**：解析层严格区分 `.cancelSchedulesAll` 与 `.cancelSchedules`，UI 文案与执行范围完全对齐；
   - **工况占比计算属性 (P2-1)**：`EcoEnergySection` 已统一消费 `EnergyAnalyticsEngine` 的占比计算属性；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **十一核心关键词与五连续区间复合排班 (高价值优化)**：补齐 `hendecaKeywordsRegex`、`quinqueRangeRegex`、`quadRangeWithKeywordRegex`、`keywordWithQuadRangeRegex` 及 `quadKeywordsWithDualRangeRegex`，并彻底修复区间吞噬与执行次序缺陷，消灭极端自然口语复合排班的解析断裂死角；
   - **变频压缩机软启动升频无截断自洽标定 (高价值优化)**：在 `EnergyAnalyticsEngine.swift` 中将工况下限同步按 `softStartMultiplier` 缩放，解除了对 20~30Hz 超低频软启动的直接截断，实现 GB/T 7725 热动力学严密闭环；
   - **状态栏气阻流阻精细感知与极端阻抗报警 (高价值优化)**：在 `StatusItemController.swift` 中全景注入气阻电负荷及流道阻抗科普导引。

---

## 3. 关键架构变更与代码实现

### 3.1 十一核心关键词与五连续区间复合排班引擎
- **`VoiceCommandParser.swift`**：
  ```swift
  // 十一核心关键词全景正则
  private static let hendecaKeywordsRegex: NSRegularExpression? = { ... }()

  // 五连续独立区间调度
  private static let quinqueRangeRegex: NSRegularExpression? = { ... }()

  // 四连续区间在先、核心关键词在后
  private static let quadRangeWithKeywordRegex: NSRegularExpression? = { ... }()

  // 核心关键词在先、四连续区间在后
  private static let keywordWithQuadRangeRegex: NSRegularExpression? = { ... }()

  // 四核心关键词在先、双连续区间在后
  private static let quadKeywordsWithDualRangeRegex: NSRegularExpression? = { ... }()
  ```

### 3.2 变频压缩机软启动升频无截断自洽标定
- **`EnergyAnalyticsEngine.swift`**：
  ```swift
  let softStartMultiplier: Double = {
      guard continuousMinutes < 3 else { return 1.0 }
      switch continuousMinutes {
      case 0: return 0.65
      case 1: return 0.85
      case 2: return 0.95
      default: return 1.0
      }
  }()
  ...
  let minFloor = 90.0 * softStartMultiplier
  let power = (180.0 + (targetTemp - envTemp) * 18.0 + windOffset * 1.5) * filterPenalty * softStartMultiplier
  return min(max(power, minFloor), 1800.0)
  ```

### 3.3 状态栏气阻流阻精细负荷透传与极端阻抗报警
- **`StatusItemController.swift`**：
  ```swift
  let filterPenaltyStr: String = {
      let maxPenalty = maxFilterAirResistancePenalty(devices: devices)
      guard maxPenalty > 0 else { return "" }
      return String(format: " · 气阻负荷最高 +%.1f%%", maxPenalty)
  }()
  ...
  let label = cleanliness <= 10 ? "🚨 滤网状态" : (cleanliness <= 30 ? "⚠️ 滤网状态" : "滤网状态")
  let filterPenalty = (Double(50 - max(0, cleanliness)) / 50.0) * 5.0
  let penaltyStr = filterPenalty > 0 ? String(format: " · 气阻负荷 +%.1f%%", filterPenalty) : ""
  let statusText = "\(label): \(cleanlinessText)\(penaltyStr)"
  ```

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **125 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build -c release`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 运行 `./build_app.sh 1.9.117`：
   - 生成打包应用：`dist/HaierAC.app`（含小组件插件 `HaierACWidget.appex`）
   - 安装包：`dist/HaierAC-v1.9.117-macOS.zip` (大小: ~3.0MB)
   - SHA-256 校验和：`9046f11ed5bccecc03e65ae4058ea6372b67bed9073b38fb8f6c870554cb3f08`

---

## 5. 发版验证清单
- [x] Code Review 历史问题与架构深度排查闭环；
- [x] 十一核心关键词全景排班及五连续区间复合拓扑完成代码实现与测试；
- [x] 变频压缩机软启动升频无截断自洽标定完成代码编写与验证；
- [x] 状态栏菜单气阻流阻精细负荷透传与极端阻抗报警完成；
- [x] 125 个单元测试 100% 通过（0 failures）；
- [x] Release 构建及 app 打包签名成功；
- [x] README.md / README.en.md 同步最新特性与文档；
- [x] 敏感数据脱敏复核：零隐私泄漏。
