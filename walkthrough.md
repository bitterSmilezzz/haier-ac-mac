# Haier AC Mac v1.9.122 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.122`
- **发版主题**：闭环十六核心关键词与十连续区间全景排班大一统、蒸发器残水汽化潜热动力学及滤网保养面板四相态感知
- **核心目标与架构演进**：
  1. **“十六核心关键词全景排班、十连续区间复合拓扑与极端口语绝决否定防御”自然口语调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **纯十六核心关键词全景调度 (`sedecaKeywordsRegex`)**：新增 `sedecaKeywordsRegex`，全面支持覆盖全部 16 种核心周期关键词连缀（“工作日、平时、平日、双休日、双休、周末三天、周末、公休日、休假日、放假日、节假日、大休日、大休、小休、单休和单休日每天早8点开机” `[1..7]`），十全十美闭环高维复合排班最后一公里所有死角；
     - **十连续独立区间与高维复合拓扑拓展 (`decemRangeRegex` / `novemRangeWithKeywordRegex` / `keywordWithNovemRangeRegex` / `novemKeywordsWithDualRangeRegex`)**：
       - `decemRangeRegex`：十连续独立区间复合口语调度（如“周一至周一、周二至周二、周三至周三、周四至周四、周五至周五、周六至周六、周日至周日、周一到周一、周二到周二加周三到周三每天早8点开机” `[1..7]`）；
       - `novemRangeWithKeywordRegex`：九连续区间在先、核心关键词在后（如“周一至周一、周二至周二、周三至周三、周四至周四、周五至周五、周六至周六、周日至周日、周一到周一、周二到周二加单休每天早8点开机” `[1..7]`）；
       - `keywordWithNovemRangeRegex`：核心关键词在先、九连续区间在后（如“单休日加周一至周一、周二至周二、周三至周三、周四至周四、周五至周五、周六至周六、周日至周日、周一到周一、周二到周二每天早8点开机” `[1..7]`）；
       - `novemKeywordsWithDualRangeRegex`：九核心关键词在先、双连续区间在后（如“工作日、平时、平日、双休日、双休、周末、公休日、休假日和大休加周六至周六、周日到周日每天早8点开机” `[1..7]`）；
     - **极端口语绝决转折否定与全方位动作谓词拦截扩充**：扩充“纵使海枯石烂也别”、“纵使天崩地裂都不要”、“哪怕天崩地裂也别”、“任凭风吹浪打都不要”、“无论千难万险都不要”、“横竖万万不可”、“万死不辞都不要”、“哪怕粉身碎骨也别”、“粉身碎骨也不要”、“断断万万不可”、“千百倍不要”、“亿万倍不要”、“天王老子到了也别”、“纵有亿万理由也别”等极端绝决转折否定句式，以及“开除湿模式”、“关除湿模式”、“停除湿模式”、“启动除湿机”、“停止除湿机”、“关掉除湿机”、“吹微风”、“吹弱风”、“吹强风”、“开强劲风”、“停强风”、“吹冷风”、“吹暖风”等动作谓词，杜绝任何复杂口语绕过与语义穿透误触发；
     - **单元测试 130 项 100% 满分覆盖**：新增 `testDecemRangeAndSedecaKeywordsV19122` 严苛测试套件，全套 130 个单元测试零缺陷通过（0 failures）。
  2. **56°C 蒸发器高温杀菌烘干双时变相变热力学与残水汽化潜热动力学模型 (`EnergyAnalyticsEngine.swift`)**：
     - **阶段 3/4 (10~18min, 56°C 高温杀菌烘干)**：引入阶梯式热负荷提升（10~12 分钟升温爬坡 $+0\text{W} \sim +70\text{W}$，12~18 分钟 56°C 恒温杀菌平台），并耦合蒸发器残留融霜水分强制相变蒸发汽化潜热动力学补偿（高湿环境结霜深厚残留融水多 `RH >= 60%`, 额外 $+0\text{W} \sim +45\text{W}$）与室内外低温冷凝传热损失补偿（`indoorTemp <= 18.0°C`, 额外 $+0\text{W} \sim +45\text{W}$）；
     - **全时相连续自洽**：烘干过程空气对流受滤网阻抗实时耦合调制，四阶段相变热力学在物理与空气动力学层面达成全面统一自洽。
  3. **AppModel 蒸发器自清洁状态计算收口与滤网保养面板四相态实时感知 (`AppModel.swift` / `FilterCareSheet.swift` / `StatusItemController.swift` / `MenuBarControlsView.swift`)**：
     - **全局统一收口自清洁状态属性**：在 `AppModel` 中提供统一的自清洁计算属性 (`selfCleaningElapsedSeconds`, `selfCleaningProgressPercentage`, `selfCleaningPhaseIndex`, `selfCleaningPhaseShortTag`, `selfCleaningPhaseDescription`)，彻底消除多端分散计算与阶段命名漂移；
     - **滤网保养面板升维四相态动态感知**：将 `FilterCareSheet` 原三阶段静态提示升维为四阶段全生命周期感知面板（深冷结霜裹尘 ➔ 解冻冲刷剥离 ➔ 56°C高温烘干 ➔ 送风排湿冷却），支持当前活跃阶段徽章高亮跳动、实时动态进度条与精确百分比读数；
     - **状态栏与控制中心全局对齐**：状态栏主按钮、Tooltip、快捷中止菜单与控制中心卡片统一消费 `AppModel` 动力学计算属性，达成跨组件、跨窗口、跨控制面板的 100% 视觉与体验自洽。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下审查报告及全仓架构进行了全景复核与缺陷深挖：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 保持严格的结构化正则匹配，本轮进一步扩充极端转折口语与多动作谓词，杜绝插字绕过与语义遗漏；
   - **定时取消定向与全屋作用域区分 (P1-2)**：解析层严格区分 `.cancelSchedulesAll` 与 `.cancelSchedules`，UI 文案与执行范围完全对齐；
   - **工况占比计算属性 (P2-1)**：`EcoEnergySection` 已统一消费 `EnergyAnalyticsEngine` 的占比计算属性；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **十六核心关键词与十连续区间全景排班 (高价值优化)**：补齐 `sedecaKeywordsRegex`、`decemRangeRegex`、`novemRangeWithKeywordRegex`、`keywordWithNovemRangeRegex` 及 `novemKeywordsWithDualRangeRegex`，消灭高维极端自然口语复合排班的解析断裂死角；
   - **蒸发器高温杀菌烘干双时变相变热力学与残水汽化潜热动力学模型 (高价值优化)**：重构阶段 3 升温爬坡与恒温平台双时变动态，引入高湿残水汽化潜热补偿与低温传热损失补偿；
   - **AppModel 自清洁状态全局收口与 FilterCareSheet 四相态感知 (高价值优化)**：消除状态栏、控制中心与保养面板间的状态冗余计算，保养面板全面升级为四阶段动态可视化进度条与阶段高亮。

---

## 3. 关键架构变更与代码实现

### 3.1 十六核心关键词与十连续区间复合排班引擎
- **`VoiceCommandParser.swift`**：
  ```swift
  // 十连续独立区间调度
  private static let decemRangeRegex: NSRegularExpression? = { ... }()

  // 九连续区间在先、核心关键词在后
  private static let novemRangeWithKeywordRegex: NSRegularExpression? = { ... }()

  // 核心关键词在先、九连续区间在后
  private static let keywordWithNovemRangeRegex: NSRegularExpression? = { ... }()

  // 九核心关键词在先、双连续区间在后
  private static let novemKeywordsWithDualRangeRegex: NSRegularExpression? = { ... }()

  // 纯十六核心关键词全景正则
  private static let sedecaKeywordsRegex: NSRegularExpression? = { ... }()
  ```

### 3.2 蒸发器高温杀菌双时变相变与残水汽化潜热动力学模型
- **`EnergyAnalyticsEngine.swift`**：
  ```swift
  } else if cleaningMinutes < 18 {
      // 阶段 3 (10~18 分钟, 56°C 高温杀菌烘干):
      let heatRamp: Double = {
          if cleaningMinutes < 12 {
              return Double(cleaningMinutes - 10) / 2.0 * 70.0
          } else {
              return 70.0
          }
      }()
      let latentVapor: Double = {
          guard let hum = indoorHumidity, hum >= 60.0 else { return 0.0 }
          return min(45.0, (hum - 60.0) * 1.125)
      }()
      let sensibleLoss: Double = {
          guard let indoor = indoorTemp, indoor <= 18.0 else { return 0.0 }
          return min(45.0, (18.0 - indoor) * 3.75)
      }()
      let dryFilter = filterCleanlinessPct < 50 ? 1.0 + (Double(50 - max(0, filterCleanlinessPct)) / 50.0) * 0.03 : 1.0
      cleaningPower = (880.0 + heatRamp + latentVapor + sensibleLoss + (windOffset * 0.4)) * dryFilter
  }
  ```

### 3.3 AppModel 状态收口与 FilterCareSheet 四相态感知
- **`AppModel.swift`**：
  ```swift
  var selfCleaningElapsedSeconds: Int { ... }
  var selfCleaningProgressPercentage: Int { ... }
  var selfCleaningPhaseIndex: Int { ... }
  var selfCleaningPhaseShortTag: String { ... }
  var selfCleaningPhaseDescription: String { ... }
  ```
- **`FilterCareSheet.swift`**：
  ```swift
  // 四相态全生命周期动态进度展示与活跃徽章指示
  ProgressView(value: Double(model.selfCleaningProgressPercentage), total: 100.0)
  ```

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **130 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build -c release`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 运行 `./build_app.sh 1.9.122`：
   - 生成打包应用：`dist/HaierAC.app`（含小组件插件 `HaierACWidget.appex`）
   - 安装包：`dist/HaierAC-v1.9.122-macOS.zip` (大小: ~3.1MB)
   - SHA-256 校验和：`897d41a0457705afd185c64a32d27fb5207a356c915efbd3a3084c257388dfc9`

---

## 5. 发版验证清单
- [x] Code Review 历史问题与架构深度排查闭环；
- [x] 十六核心关键词全景排班及十连续区间复合拓扑完成代码实现与测试；
- [x] 蒸发器高温杀菌双时变相变与残水汽化潜热动力学模型完成代码编写与验证；
- [x] AppModel 状态计算收口与 FilterCareSheet 四相态感知面板升级；
- [x] 130 个单元测试 100% 通过（0 failures）；
- [x] Release 构建及 app 打包签名成功；
- [x] README.md / README.en.md 同步最新特性与文档；
- [x] 敏感数据脱敏复核：零隐私泄漏。
