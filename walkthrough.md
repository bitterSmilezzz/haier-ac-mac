# Haier AC Mac v1.9.114 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.114`
- **发版主题**：闭环八核心关键词与六元复合排班大一统调度、变频压缩机软启动动态升频微阻尼模型及控制中心滤网健康感知
- **核心目标与架构演进**：
  1. **“八核心关键词全景排班、六元复合拓扑与口语多重否定强化拦截”自然口语调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **纯八核心关键词全景调度 (`octaKeywordsRegex`)**：新增 `octaKeywordsRegex`，支持全部 8 种核心关键词（“工作日、平时、平日、双休日、双休、大休、小休和单休每天早8点开机” `[1..7]`），全面终结极端复合口语排班截断；
     - **六元复合口语拓扑拓展 (`dualRangeWithTriKeywordsRegex` / `triKeywordsWithDualRangeRegex` / `keywordWithDualRangeAndDualKeywordsRegex` / `dualKeywordsWithDualRangeAndKeywordRegex` / `rangeWithDualKeywordsAndRangeWithKeywordRegex` / `rangeWithKeywordAndRangeWithDualKeywordsRegex`)**：
       - `dualRangeWithTriKeywordsRegex`：双连续区间在先、三核心关键词在后（如“周一至周二、周四至周五加大休、小休和单休每天早8点开机” `[1..7]`）；
       - `triKeywordsWithDualRangeRegex`：三核心关键词在先、双连续区间在后（如“大休、小休和单休加周一至周二、周四至周五每天早8点开机” `[1..7]`）；
       - `keywordWithDualRangeAndDualKeywordsRegex`：1 核心词在先、双区间居中、2 核心词在后（如“大休加周一至周二、周四至周五加小休和单休每天早8点开机” `[1..7]`）；
       - `dualKeywordsWithDualRangeAndKeywordRegex`：2 核心词在先、双区间居中、1 核心词在后（如“工作日和平时加周六至周日、周一至周二加大休每天早8点开机” `[1..7]`）；
       - `rangeWithDualKeywordsAndRangeWithKeywordRegex`：区间在先、双核心词、第二区间、第三核心词（如“周一至周二加大休和小休加周四至周五加工作日每天早8点开机” `[1..7]`）；
       - `rangeWithKeywordAndRangeWithDualKeywordsRegex`：区间在先、单核心词、第二区间、双核心词（如“周一至周二加工作日加周四至周五加大休和小休每天早8点开机” `[1..7]`）；
     - **强化口语多重否定与动作防误触拦截**：在 `negativeActionRegex`、`containsNegativeForAction` 与 `containsNegativeAction` 中扩充否定前缀（“可千万别”、“可千万不要”、“千万可别”、“万不可”、“亿万不可”、“切切不可”、“断不可”、“绝不可”、“决不可”、“决不能”、“决不要”）及动作谓词（“关停”、“切断”、“断开”、“断电”、“停机”），守住零误关零误开底线；
     - **单元测试 100% 满分覆盖**：新增 `testOctaKeywordsAndHexaCompoundScheduleV19114` 严苛测试套件，全套 122 个单元测试零缺陷通过（0 failures）。
  2. **能耗动力学变频压缩机软启动动态升频微阻尼模型 (`EnergyAnalyticsEngine.swift`)**：
     - **压缩机软启动与升频建立压差微阻尼 (Compressor Soft-Start Dynamic Ramping Model)**：在 `estimateInstantaneousPower` 中引入开机持续运行分钟数动态爬升阻尼；
     - 刚开机启动阶段（`continuousMinutes == 0`）：乘数 0.65，模拟变频压缩机超低频启动（20~30Hz）及建立高低压差阶段；
     - 运行第 1 分钟（`continuousMinutes == 1`）：乘数 0.85，模拟频率线性提升过程；
     - 运行第 2 分钟（`continuousMinutes == 2`）：乘数 0.95，平滑过渡；
     - 运行满 3 分钟以上（`continuousMinutes >= 3`）：乘数 1.00，完全进入温差与热容动力学标称变频运行区间；
     - 与机组热负荷衰减模型、自清洁微增益、滤网积尘气阻模型无缝融合，使瞬时功耗曲线高度拟真真实物理变频空调运转规律。
  3. **macOS 菜单栏控制中心滤网积尘预警胶囊与自清洁保护感知 (`MenuBarControlsView.swift`)**：
     - **滤网健康预警胶囊 (`filterWarningPod`)**：当设备滤网洁净度低至 `<= 30%` 时，控制中心动态注入醒目的琥珀黄/高危红预警条，展示当前洁净度百分比并提供一键直达“保养重置”操作，消灭用户对滤网保养忽视的健康隐患；
     - **自清洁 14 天保护态微徽标 (`selfCleaningPod`)**：自清洁完成后 14 天保护期内，控制中心动态展示绿色护盾徽标并标明“增效 +4%”，实时呼应热动力学自清洁节能增效状态；
     - **底部状态栏全屋快捷入口**：控制中心底部新增“滤网与清洁”快捷按钮，方便一键呼出 `FilterCareSheet` 深度保养面板。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下审查报告及全仓架构进行了全景复核与缺陷深挖：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 正则结构稳固，本轮进一步扩充高强度否定前缀与动作谓词（“可千万别/千万可别/万不可/亿万不可/关停/切断/断电/停机”），彻底杜绝口语误触；
   - **全屋与定向定时解耦 (P1-2)**：`cancelSchedules` 与 `cancelSchedulesAll` 精确分流，多设备批量取消分支全部贯通；
   - **工况占比计算属性消费 (P2-1)**：`EcoEnergySection` 已统一调用 4 个比率属性；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏与 UI 使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **八核心关键词与六元复合拓扑排班 (P1 优化)**：补齐 `octaKeywordsRegex` 及六元复合矩阵 6 大正则，消灭复杂复合排班在自然语言解析层面的死角；
   - **强化口语多重否定防误触拦截 (P1 优化)**：扩充否定词与动作谓词，与全仓现有动作拦截规则达成 100% 结构对称，防止误触发；
   - **变频压缩机软启动动态升频微阻尼模型 (P1 优化)**：瞬时功率估算中引入 0.65 -> 0.85 -> 0.95 -> 1.00 变频低频软启动动力学爬升模型；
   - **控制中心滤网积尘健康预警与清洁感知 (P1 优化)**：洁净度低于 30% 注入警示条，支持一键重置与快捷清洁入口。

---

## 3. 关键架构变更与代码实现

### 3.1 八核心关键词与六元复合拓扑排班引擎
- **`VoiceCommandParser.swift`**：
  ```swift
  // 八核心关键词全景正则
  private static let octaKeywordsRegex: NSRegularExpression? = { ... }()

  // 双区间在先、三核心关键词在后
  private static let dualRangeWithTriKeywordsRegex: NSRegularExpression? = { ... }()

  // 三核心关键词在先、双区间在后
  private static let triKeywordsWithDualRangeRegex: NSRegularExpression? = { ... }()

  // 1 核心词、双区间、2 核心词
  private static let keywordWithDualRangeAndDualKeywordsRegex: NSRegularExpression? = { ... }()

  // 2 核心词、双区间、1 核心词
  private static let dualKeywordsWithDualRangeAndKeywordRegex: NSRegularExpression? = { ... }()

  // 区间 + 双核心词 + 区间 + 核心词
  private static let rangeWithDualKeywordsAndRangeWithKeywordRegex: NSRegularExpression? = { ... }()

  // 区间 + 核心词 + 区间 + 双核心词
  private static let rangeWithKeywordAndRangeWithDualKeywordsRegex: NSRegularExpression? = { ... }()
  ```

### 3.2 变频压缩机软启动动态升频微阻尼模型
- **`EnergyAnalyticsEngine.swift`**：
  ```swift
  // 变频压缩机软启动动态升频微阻尼 (Compressor Soft-Start Dynamic Ramping Model)
  let softStartMultiplier: Double = {
      guard isPowerOn && !isSelfCleaning else { return 1.0 }
      switch continuousMinutes {
      case 0:
          return 0.65 // 刚启动建立压差低频阶段 (20~30Hz)
      case 1:
          return 0.85 // 升频过渡阶段 (30~55Hz)
      case 2:
          return 0.95 // 接近额定负载过渡
      default:
          return 1.00 // 满频/额定温差变频 PID 调节阶段
      }
  }()

  let dynamicMultiplier = soakMultiplier * cleanMultiplier * filterMultiplier * softStartMultiplier
  ```

### 3.3 控制中心滤网健康预警胶囊与自清洁保护感知
- **`MenuBarControlsView.swift`**：
  在控制中心主面板根据 `device.filterCleanlinessPct` 动态插入 `filterWarningPod`，在 `selfCleaningPod` 中呈现 14 天绿色保护护盾与“增效 +4%”徽标，并在底部栏提供“滤网与清洁”快捷访问按键。

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **122 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build -c release`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 执行 `./build_app.sh 1.9.114`：
   - 顺利生成 App 产物 `dist/HaierAC.app` 与发布安装包 `dist/HaierAC-v1.9.114-macOS.zip`（SHA256: `f67e045d11e5312dcf8ceb88850081104c5703140f05e456108d39b70c3880e4`）。

---

## 5. 发版信息与提交记录
- **Git Commit**：`feat & fix: 闭环八核心关键词与六元复合排班大一统调度、变频压缩机软启动动态升频微阻尼模型及控制中心滤网健康感知 (v1.9.114)`
- **Git Tag**：`v1.9.114`
- **Release Asset**：`dist/HaierAC-v1.9.114-macOS.zip`
- **SHA256**：`f67e045d11e5312dcf8ceb88850081104c5703140f05e456108d39b70c3880e4`
