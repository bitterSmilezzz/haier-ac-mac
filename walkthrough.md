# Haier AC Mac v1.9.113 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.113`
- **发版主题**：闭环七核心关键词与五元夹心排班大一统调度、滤网积尘气阻动力学衰减模型及控制中心微调持久化
- **核心目标与架构演进**：
  1. **“七核心关键词全景排班、五元夹心复合拓扑与口语多重否定强化拦截”自然口语调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **纯七核心关键词全景调度 (`heptaKeywordsRegex`)**：新增 `heptaKeywordsRegex`，支持全部 7 种核心关键词（“工作日、平时、平日、双休日、大休、小休和单休每天早8点开机” `[1..7]`），全面终结极端复合口语排班截断；
     - **五元夹心复合口语拓扑拓展 (`keywordWithRangeAndTriKeywordsRegex` / `triKeywordsWithRangeAndKeywordRegex` / `dualKeywordsWithRangeAndDualKeywordsRegex`)**：
       - `keywordWithRangeAndTriKeywordsRegex`：核心关键词在先、连续区间居中、三核心关键词在后（如“大休加周一至周三加小休、单休和工作日每天早8点开机” `[1..7]`）；
       - `triKeywordsWithRangeAndKeywordRegex`：三核心关键词在先、连续区间居中、核心关键词在后（如“大休、小休和单休加周一至周三加工作日每天早8点开机” `[1..7]`）；
       - `dualKeywordsWithRangeAndDualKeywordsRegex`：双核心关键词在先、连续区间居中、双核心关键词在后（如“工作日和平时加周六至周日加大休和小休每天早8点开机” `[1..7]`）；
     - **强化口语多重否定与动作防误触拦截**：在 `negativeActionRegex`、`containsNegativeForAction` 与 `containsNegativeAction` 中扩充否定前缀（“无论如何都不要”、“千万千万别”、“暂时先别”、“万万不可”、“万万不能”、“断不可”、“任何时候都不要”）及动作谓词（“关掉”、“停掉”、“开启”、“启动运行”、“调温”、“升温”、“降温”），守住零误关零误开底线；
     - **单元测试 100% 满分覆盖**：新增 `testHeptaKeywordsAndPentaCompoundScheduleV19113` 严苛测试套件，全套 121 个单元测试零缺陷通过（0 failures）。
  2. **能耗动力学滤网积尘气阻动力学衰减连续微补偿模型 (`EnergyAnalyticsEngine.swift` / `AppModel.swift`)**：
     - **滤网积尘气阻动力学衰减连续微补偿 (Air Filter Flow Resistance Impedance Model)**：在 `DeviceEnergySample` 与 `estimateInstantaneousPower` 中正式接入 `filterCleanlinessPct`（0 ~ 100%）；
     - 当空调滤网洁净度处于良好区间（50% ~ 100%）时，风道流阻处于额定标称工况（乘数 1.00）；当滤网洁净度处于受阻积尘区间（0% ~ 50%）时，系统自动进行连续平滑线性插值（乘数从 1.00 上升至 1.05），反映循环风量衰减下变频压缩机与风机需输出的微幅额外功耗补偿；
     - 与自清洁洁净度微收益（0.96 ~ 1.00）及机组热容量连续散热模型共同构成完备自洽的空气热动力学全景闭环。
  3. **macOS 菜单栏控制中心与原生状态栏微调精度状态持久化与双向联动 (`MenuBarControlsView.swift` / `StatusItemController.swift` / `AppModel.swift`)**：
     - **全屋调温微调步进持久化 (`wholeHouseFineStep`)**：在 `AppModel` 中将 `wholeHouseFineStep` 接入 `UserDefaults` 持久化，用户在控制中心切换 1.0°C / 0.5°C 步进精度后在窗口重新打开或应用重启时得以准确保持；
     - **控制中心与状态栏菜单双向联动**：状态栏全屋相对升降温 0.5°C 微调操作与 1.0°C 标准升降温操作自动同步更新 `model.wholeHouseFineStep`，消除原生状态栏与 SwiftUI 控制中心之间的状态断层。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下审查报告及全仓架构进行了全景复核与缺陷深挖：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 正则结构稳固，本轮进一步纳管“无论如何都不要/千万千万别/暂时先别/万万不可/断不可/任何时候都不要”，多字穿插插字防御更加严密；
   - **全屋与定向定时解耦 (P1-2)**：`cancelSchedules` 与 `cancelSchedulesAll` 精确分流，多设备批量取消分支全部贯通；
   - **工况占比计算属性消费 (P2-1)**：`EcoEnergySection` 已统一调用 4 个比率属性；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏与 UI 使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **七核心关键词排班与五元夹心复合拓扑 (P1 优化)**：补齐 `heptaKeywordsRegex`、`keywordWithRangeAndTriKeywordsRegex`、`triKeywordsWithRangeAndKeywordRegex`、`dualKeywordsWithRangeAndDualKeywordsRegex`，彻底消灭超多关键词排班与连续区间复合排班口语遗漏缺陷；
   - **强化口语多重否定防误触拦截 (P1 优化)**：扩充否定词与动作谓词，与全仓现有动作拦截规则达成 100% 结构对称，防止误触发；
   - **滤网积尘气阻动力学衰减模型 (P1 优化)**：在瞬时功率与采样聚合中接入 `filterCleanlinessPct`，气阻增大负荷增加 0% ~ 5% 连续微补偿，空气热动力学模拟全面闭环；
   - **控制中心微调步进持久化与双向联动 (P1 优化)**：`wholeHouseFineStep` 接入 `UserDefaults` 持久化，并在原生状态栏与控制中心之间实现无缝双向状态同步。

---

## 3. 关键架构变更与代码实现

### 3.1 七核心关键词与五元夹心复合拓扑排班引擎
- **`VoiceCommandParser.swift`**：
  ```swift
  // 七核心关键词全景正则
  private static let heptaKeywordsRegex: NSRegularExpression? = { ... }()

  // 核心词在先、连续区间居中、三核心词在后
  private static let keywordWithRangeAndTriKeywordsRegex: NSRegularExpression? = { ... }()

  // 三核心词在先、连续区间居中、核心词在后
  private static let triKeywordsWithRangeAndKeywordRegex: NSRegularExpression? = { ... }()

  // 双核心词在先、连续区间居中、双核心词在后
  private static let dualKeywordsWithRangeAndDualKeywordsRegex: NSRegularExpression? = { ... }()
  ```

### 3.2 滤网积尘气阻动力学衰减连续微补偿模型
- **`EnergyAnalyticsEngine.swift`**：
  ```swift
  // 滤网积尘气道流阻与换热动力学衰减连续微补偿 (Air Filter Flow Resistance Impedance Model)
  let filterMultiplier: Double = {
      guard isPowerOn && !isSelfCleaning && filterCleanlinessPct < 50 else { return 1.0 }
      let clampedPct = max(0, filterCleanlinessPct)
      let penalty = (Double(50 - clampedPct) / 50.0) * 0.05
      return min(1.05, 1.0 + penalty)
  }()

  let dynamicMultiplier = soakMultiplier * cleanMultiplier * filterMultiplier
  ```

### 3.3 控制中心与状态栏微调步进持久化与双向同步
- **`AppModel.swift` & `MenuBarControlsView.swift` & `StatusItemController.swift`**：
  在 `AppModel` 中提供 `wholeHouseFineStep` 属性并持久化至 `UserDefaults`，控制中心与原生状态栏菜单双向无缝同步步进粒度。

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **121 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build -c release`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 执行 `./build_app.sh 1.9.113`：
   - 顺利生成 App 产物 `dist/HaierAC.app` 与发布安装包 `dist/HaierAC-v1.9.113-macOS.zip`（SHA256: `f08c43e9de5c85efb60dd6774fb56b6c9279abb10e81db4d76b60c6378ce7efe`）。

---

## 5. 发版信息与提交记录
- **Git Commit**：`feat & fix: 闭环七核心关键词与五元夹心排班大一统调度、滤网积尘气阻动力学衰减模型及控制中心微调持久化 (v1.9.113)`
- **Git Tag**：`v1.9.113`
- **Release Asset**：`dist/HaierAC-v1.9.113-macOS.zip`
- **SHA256**：`f08c43e9de5c85efb60dd6774fb56b6c9279abb10e81db4d76b60c6378ce7efe`
