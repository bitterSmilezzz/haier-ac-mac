# Haier AC Mac v1.9.121 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.121`
- **发版主题**：闭环十五核心关键词与九连续区间全景排班大一统、蒸发器自清洁逆循环解冻潜热动力学及状态栏全域百分比感知
- **核心目标与架构演进**：
  1. **“十五核心关键词全景排班、九连续区间复合拓扑与极端口语绝决否定防御”自然口语调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **纯十五核心关键词全景调度 (`quindecaKeywordsRegex`)**：新增 `quindecaKeywordsRegex`，全面支持覆盖全部 15 种核心周期关键词连缀（“工作日、平时、平日、双休日、双休、周末三天、周末、公休日、休假日、放假日、节假日、大休日、大休、小休和单休每天早8点开机” `[1..7]`），十全十美闭环高维复合排班最后一公里死角；
     - **九连续独立区间与高维复合拓扑拓展 (`novemRangeRegex` / `octoRangeWithKeywordRegex` / `keywordWithOctoRangeRegex` / `octoKeywordsWithDualRangeRegex`)**：
       - `novemRangeRegex`：九连续独立区间复合口语调度（如“周一至周一、周二至周二、周三至周三、周四至周四、周五至周五、周六至周六、周日至周日、周一到周一加周二到周二每天早8点开机” `[1..7]`）；
       - `octoRangeWithKeywordRegex`：八连续区间在先、核心关键词在后（如“周一至周一、周二至周二、周三至周三、周四至周四、周五至周五、周六至周六、周日至周日、周一到周一加单休每天早8点开机” `[1..7]`）；
       - `keywordWithOctoRangeRegex`：核心关键词在先、八连续区间在后（如“单休日加周一至周一、周二至周二、周三至周三、周四至周四、周五至周五、周六至周六、周日至周日、周一到周一每天早8点开机” `[1..7]`）；
       - `octoKeywordsWithDualRangeRegex`：八核心关键词在先、双连续区间在后（如“工作日、平时、平日、双休日、双休、周末、公休日和大休加周六至周六、周日到周日每天早8点开机” `[1..7]`）；
     - **极端口语绝决转折否定与全方位动作谓词拦截扩充**：扩充“哪怕海枯石烂也别”、“哪怕天翻地覆都不要”、“哪怕天塌地陷也别”、“无论何种境地都不要”、“无论何种地步都不要”、“横竖断断不可”、“死活都不要”、“死活也不要”、“死活断不可”、“万死不辞也别”、“断断千千万万不可”、“百计千方莫要”、“百倍不要”、“千真万确不要”、“决计切莫”、“万望切莫”、“万望切切不可”、“天王老子来了也别”、“纵有千般理由也别”、“纵有万般理由都不要”等极端绝决转折否定句式，以及“开抽湿”、“关抽湿”、“停抽湿”、“开除湿机”、“关除湿机”、“停除湿机”、“送自然风”、“吹自然风”、“停自然风”、“关自然风”、“送微风”、“送弱风”、“送强风”、“开大风”、“关大风”、“停大风”、“开小风”、“制冷机”、“制热机”等动作谓词，杜绝任何复杂口语绕过与语义穿透误触发；
     - **单元测试 129 项 100% 满分覆盖**：新增 `testNovemRangeAndQuindecaKeywordsV19121` 严苛测试套件，全套 129 个单元测试零缺陷通过（0 failures）。
  2. **蒸发器自清洁逆循环微解冻融霜相变潜热与防再结冰动力学模型 (`EnergyAnalyticsEngine.swift`)**：
     - **阶段 2/4 (5~10min, 逆循环微解冻冲刷剥离)**：四通阀快速换向使高温冷媒逆向流入蒸发器，使冰霜迅速脱落剥离并随融水冲刷排出，引入相变熔化潜热动力学补偿（高湿环境结霜层深厚 `RH >= 60%`, 额外 $+0\text{W} \sim +40\text{W}$）、第 5~7 分钟相变熔化吸热峰值脉冲曲线、室内外低温冷凝传热损失补偿与防再结冰热力补偿（`indoorTemp <= 16.0°C`, 额外 $+0\text{W} \sim +35\text{W}$）；
     - **全时相连续自洽**：自清洁工况四阶段（阶段 1 急速深冷裹尘、阶段 2 逆循环微解冻冲刷、阶段 3 56°C 恒温杀菌烘干、阶段 4 送风排湿冷却）实现全时相物理自洽连续动力学建模。
  3. **macOS 状态栏按钮标题与悬浮 Tooltip 动态相变百分比与全域感知 (`StatusItemController.swift` / `MenuBarControlsView.swift`)**：
     - **状态栏主按钮实时时相与百分比呈现**：自清洁进行中状态栏主按钮标题呈现 `56°C [凝霜 18%] (16:24)`（温度开启时）或 `[凝霜 18%] (16:24)`（温度关闭时），使状态栏常驻视觉即刻掌握自清洁精确进展；
     - **状态栏悬浮 Tooltip 阶段与百分比全息展示**：悬浮 Tooltip 呈现 `✨ 蒸发器 56°C 深度自清洁中: [阶段 1/4 • 急速深冷结霜裹尘 (18%)] (剩余 16分24秒)`，与控制中心动态相变对齐；
     - **控制中心与状态栏时相文案 100% 对齐**：全面统一四阶段名称为“急速深冷结霜裹尘”、“逆循环微解冻冲刷”、“56°C 高温杀菌烘干”、“送风排湿冷却恢复”，消除跨模块感知偏差。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下审查报告及全仓架构进行了全景复核与缺陷深挖：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 保持严格的结构化正则匹配，本轮进一步扩充极端转折口语与多动作谓词，杜绝插字绕过与语义遗漏；
   - **定时取消定向与全屋作用域区分 (P1-2)**：解析层严格区分 `.cancelSchedulesAll` 与 `.cancelSchedules`，UI 文案与执行范围完全对齐；
   - **工况占比计算属性 (P2-1)**：`EcoEnergySection` 已统一消费 `EnergyAnalyticsEngine` 的占比计算属性；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **十五核心关键词与九连续区间全景排班 (高价值优化)**：补齐 `quindecaKeywordsRegex`、`novemRangeRegex`、`octoRangeWithKeywordRegex`、`keywordWithOctoRangeRegex` 及 `octoKeywordsWithDualRangeRegex`，消灭高维极端自然口语复合排班的解析断裂死角；
   - **蒸发器自清洁逆循环融霜相变潜热与防再结冰动力学模型 (高价值优化)**：在四阶段自清洁功率计算的阶段 2 引入融霜相变脉冲曲线、高湿潜热补偿与低温防再结冰热力补偿；
   - **状态栏与悬浮看板全息动态感知联动 (高价值优化)**：状态栏主按钮、悬浮气泡 Tooltip 与控制中心实现全息自清洁进度、时相与百分比的无缝协同呈现。

---

## 3. 关键架构变更与代码实现

### 3.1 十五核心关键词与九连续区间复合排班引擎
- **`VoiceCommandParser.swift`**：
  ```swift
  // 九连续独立区间调度
  private static let novemRangeRegex: NSRegularExpression? = { ... }()

  // 八连续区间在先、核心关键词在后
  private static let octoRangeWithKeywordRegex: NSRegularExpression? = { ... }()

  // 核心关键词在先、八连续区间在后
  private static let keywordWithOctoRangeRegex: NSRegularExpression? = { ... }()

  // 八核心关键词在先、双连续区间在后
  private static let octoKeywordsWithDualRangeRegex: NSRegularExpression? = { ... }()

  // 纯十五核心关键词全景正则
  private static let quindecaKeywordsRegex: NSRegularExpression? = { ... }()
  ```

### 3.2 蒸发器自清洁逆循环融霜相变潜热与防再结冰动力学模型
- **`EnergyAnalyticsEngine.swift`**：
  ```swift
  } else if cleaningMinutes < 10 {
      // 阶段 2 (5~10 分钟, 逆循环微解冻冲刷剥离):
      // 四通阀快速换向使高温冷媒逆向流入蒸发器，使冰霜迅速脱落剥离并随融水冲刷排出 (v1.9.121 逆循环相变融霜潜热与防再结冰动力学自洽)。
      let meltRamp: Double = {
          if cleaningMinutes <= 7 {
              return Double(cleaningMinutes - 5) / 2.0 * 40.0
          } else {
              return max(0.0, (1.0 - (Double(cleaningMinutes - 7) / 3.0)) * 40.0)
          }
      }()
      let latentMelt: Double = {
          guard let hum = indoorHumidity, hum >= 60.0 else { return 0.0 }
          return min(40.0, (hum - 60.0) * 1.0)
      }()
      let sensibleMelt: Double = {
          guard let indoor = indoorTemp, indoor <= 16.0 else { return 0.0 }
          return min(35.0, (16.0 - indoor) * 4.375)
      }()
      let washFilter = filterCleanlinessPct < 50 ? 1.0 + (Double(50 - max(0, filterCleanlinessPct)) / 50.0) * 0.04 : 1.0
      cleaningPower = (780.0 + meltRamp + (windOffset * 0.3) + latentMelt + sensibleMelt) * washFilter
  }
  ```

### 3.3 macOS 状态栏按钮标题与悬浮 Tooltip 动态相变百分比与全域感知
- **`StatusItemController.swift` & `MenuBarControlsView.swift`**：
  ```swift
  // 状态栏常驻按钮实时百分比呈现
  let phaseTag: String = {
      if elapsed < 300 { return "凝霜" }
      else if elapsed < 600 { return "冲刷" }
      else if elapsed < 1080 { return "烘干" }
      else { return "送风" }
  }()
  button.title = " 56°C [\(phaseTag) \(cleanPct)%] (\(String(format: "%02d:%02d", m, s)))"

  // 状态栏全局悬浮看板 Tooltip
  tooltipParts.append("✨ 蒸发器 56°C 深度自清洁中: [\(phaseDesc) (\(cleanPct)%)] (剩余 \(m)分\(s)秒)")
  ```

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **129 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build -c release`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 运行 `./build_app.sh 1.9.121`：
   - 生成打包应用：`dist/HaierAC.app`（含小组件插件 `HaierACWidget.appex`）
   - 安装包：`dist/HaierAC-v1.9.121-macOS.zip` (大小: ~3.0MB)
   - SHA-256 校验和：`9eb7743baae69f82f73d54ed40554487e2479b39f34fe45df66454200cd7673e`

---

## 5. 发版验证清单
- [x] Code Review 历史问题与架构深度排查闭环；
- [x] 十五核心关键词全景排班及九连续区间复合拓扑完成代码实现与测试；
- [x] 蒸发器自清洁逆循环融霜相变潜热与防再结冰动力学模型完成代码编写与验证；
- [x] 状态栏主按钮与悬浮看板 Tooltip 自清洁全息动态感知联动完成；
- [x] 129 个单元测试 100% 通过（0 failures）；
- [x] Release 构建及 app 打包签名成功；
- [x] README.md / README.en.md 同步最新特性与文档；
- [x] 敏感数据脱敏复核：零隐私泄漏。
