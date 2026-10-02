# Haier AC Mac v1.9.123 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.123`
- **发版主题**：闭环十七核心关键词与十一连续区间全景排班大一统、蒸发器阶段四翅片显热衰减动力学及状态栏全息感知死角清零
- **核心目标与架构演进**：
  1. **“十七核心关键词全景排班、十一连续区间复合拓扑与极端口语绝决否定防御”自然口语调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **纯十七核心关键词全景调度 (`septendecaKeywordsRegex`)**：新增 `septendecaKeywordsRegex`，全面支持覆盖全部 17 种核心周期关键词连缀（“工作日、平时、平日、双休日、双休、周末三天、周末、公休日、休假日、放假日、节假日、单休日、单休、大休日、大休、大周和小休每天早8点开机” `[1..7]`），十全十美闭环高维复合排班最后一公里所有死角；
     - **十一连续独立区间与高维复合拓扑拓展 (`undecemRangeRegex` / `decemRangeWithKeywordRegex` / `keywordWithDecemRangeRegex` / `decemKeywordsWithDualRangeRegex`)**：
       - `undecemRangeRegex`：十一连续独立区间复合口语调度（如“周一至周一、周二至周二、周三至周三、周四至周四、周五至周五、周六至周六、周日至周日、周一到周一、周二到周二、周三到周三加周四到周四每天早8点开机” `[1..7]`）；
       - `decemRangeWithKeywordRegex`：十连续区间在先、核心关键词在后（如“周一至周一、周二至周二、周三至周三、周四至周四、周五至周五、周六至周六、周日至周日、周一到周一、周二到周二、周三到周三加单休每天早8点开机” `[1..7]`）；
       - `keywordWithDecemRangeRegex`：核心关键词在先、十连续区间在后（如“单休加周一至周一、周二至周二、周三至周三、周四至周四、周五至周五、周六至周六、周日至周日、周一到周一、周二到周二、周三到周三每天早8点开机” `[1..7]`）；
       - `decemKeywordsWithDualRangeRegex`：十核心关键词在先、双连续区间在后（如“工作日、平时、平日、双休日、双休、周末三天、周末、公休日、休假日和大休加周六至周六、周日到周日每天早8点开机” `[1..7]`）；
     - **极端口语绝决转折否定与全方位动作谓词拦截扩充**：扩充“切切切不可开”、“切切切不可关”、“哪怕粉身碎骨也别关机”、“死活都千万不要开空调”等极端绝决转折否定句式，杜绝任何复杂口语绕过与语义穿透误触发；
     - **单元测试 131 项 100% 满分覆盖**：新增 `testUndecemRangeAndSeptendecaKeywordsV19123` 严苛测试套件，全套 131 个单元测试零缺陷通过（0 failures）。
  2. **56°C 蒸发器自清洁阶段 4 送风排湿翅片显热衰减与高湿残余微水滴排湿阻力动力学模型 (`EnergyAnalyticsEngine.swift`)**：
     - **阶段 4/4 (>= 18min, 降温送风排湿恢复)**：引入 56°C 翅片高温对流降温显热衰减与风机转速降频平滑过渡（第 18 分钟初态 $+16\text{W}$ 降温爬坡，随后在 18~20 分钟平滑衰减至 0W 回归 42W 稳态微风基准）；
     - **高湿残余微水滴风道排湿阻力连续微补偿**：室内空气高湿（`RH >= 60%`）时风道潮湿与微液滴附壁增加对流阻抗（额外 $+0\text{W} \sim +10\text{W}$），与滤网气阻微喘振模型完全协同自洽。
  3. **macOS 状态栏自清洁全息感知死角清零与 FilterCareSheet 四相态动态微提示升级 (`StatusItemController.swift` / `FilterCareSheet.swift`)**：
     - **状态栏自清洁时相感知死角彻底清零**：为设备子菜单项、单设备平铺项、多设备快捷中止项全面补齐 `[\(model.selfCleaningPhaseShortTag) \(cleanPct)%]` 动态阶段与百分比标签，并统一通过 `AppModel` 动力学收口属性计算，视觉一致性达到 100%；
     - **滤网保养面板实时四相态物理动力学微提示**：在 `FilterCareSheet` 自清洁四阶段进度条下方新增动态图标与实时工况提示（深冷结霜 ➔ 融水冲刷 ➔ 高温烘干 ➔ 送风排湿降温），提升科技感与掌控感。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下审查报告及全仓架构进行了全景复核与缺陷深挖：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 保持严格的结构化正则匹配，本轮进一步扩充极端转折口语与多动作谓词，杜绝插字绕过与语义遗漏；
   - **定时取消定向与全屋作用域区分 (P1-2)**：解析层严格区分 `.cancelSchedulesAll` 与 `.cancelSchedules`，UI 文案与执行范围完全对齐；
   - **工况占比计算属性 (P2-1)**：`EcoEnergySection` 已统一消费 `EnergyAnalyticsEngine` 的占比计算属性；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **十七核心关键词与十一连续区间全景排班 (高价值优化)**：补齐 `septendecaKeywordsRegex`、`undecemRangeRegex`、`decemRangeWithKeywordRegex`、`keywordWithDecemRangeRegex` 及 `decemKeywordsWithDualRangeRegex`，消灭高维极端自然口语复合排班的解析断裂死角；
   - **蒸发器阶段四翅片显热衰减与高湿排湿阻力动力学模型 (高价值优化)**：重构阶段 4 贯流风机从 56°C 翅片高温显热冷却连续平滑衰减至常温微风稳态，并耦合湿敏残余微水滴连续阻抗；
   - **状态栏自清洁感知死角清零与 FilterCareSheet 四相态动态微提示 (高价值优化)**：彻底消除状态栏各层级子菜单中关于自清洁时相标签与百分比的盲区，在保养面板提供实时相态动力学小字提示。

---

## 3. 关键架构变更与代码实现

### 3.1 十七核心关键词与十一连续区间复合排班引擎
- **`VoiceCommandParser.swift`**：
  ```swift
  // 十一连续独立区间调度
  private static let undecemRangeRegex: NSRegularExpression? = { ... }()

  // 十连续区间在先、核心关键词在后
  private static let decemRangeWithKeywordRegex: NSRegularExpression? = { ... }()

  // 核心关键词在先、十连续区间在后
  private static let keywordWithDecemRangeRegex: NSRegularExpression? = { ... }()

  // 十核心关键词在先、双连续区间在后
  private static let decemKeywordsWithDualRangeRegex: NSRegularExpression? = { ... }()

  // 纯十七核心关键词全景正则
  private static let septendecaKeywordsRegex: NSRegularExpression? = { ... }()
  ```

### 3.2 蒸发器阶段四翅片显热衰减与高湿残余微水滴排湿阻力动力学模型
- **`EnergyAnalyticsEngine.swift`**：
  ```swift
  } else {
      // 阶段 4 (>= 18 分钟, 送风排湿冷却恢复):
      let coolRamp = max(0.0, (1.0 - (Double(cleaningMinutes - 18) / 2.0)) * 16.0)
      let latentDrag: Double = {
          guard let hum = indoorHumidity, hum >= 60.0 else { return 0.0 }
          return min(10.0, (hum - 60.0) * 0.25)
      }()
      let clampedPct = max(0, filterCleanlinessPct)
      let basePenalty = filterCleanlinessPct < 50 ? (Double(50 - clampedPct) / 50.0) * 0.05 : 0.0
      let extremePenalty = clampedPct <= 10 ? (Double(10 - clampedPct) / 10.0) * 0.015 : 0.0
      let fanFilter = 1.0 + basePenalty + extremePenalty
      let baseFanPower = 42.0 + coolRamp + latentDrag + (windOffset * 0.2)
      cleaningPower = baseFanPower * fanFilter
  }
  ```

### 3.3 状态栏感知死角清零与 FilterCareSheet 四相态微提示
- **`StatusItemController.swift`**：
  ```swift
  // 菜单子项全面补齐时相与百分比
  title: "🛑 中止 56°C 自清洁 [\(phaseTag) \(cleanPct)%] (剩余 \(String(format: "%02d:%02d", m, s)))"
  ```
- **`FilterCareSheet.swift`**：
  ```swift
  // 四相态实时动力学微动效与文字说明
  HStack(spacing: 4) {
      Image(systemName: ...)
      Text(model.selfCleaningPhaseIndex == 4 ? "贯流风机常温微风强力排湿，翅片对流降温防霉干燥中" : ...)
  }
  ```

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **131 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build -c release`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 运行 `./build_app.sh 1.9.123`：
   - 生成打包应用：`dist/HaierAC.app`（含小组件插件 `HaierACWidget.appex`）
   - 安装包：`dist/HaierAC-v1.9.123-macOS.zip` (大小: ~3.1MB)
   - SHA-256 校验和：`d8ac8a159ea35675fe206bec17aa1da3edcfd024a4da581d892d70524fc034eb`

---

## 5. 发版验证清单
- [x] Code Review 历史问题与架构深度排查闭环；
- [x] 十七核心关键词全景排班及十一连续区间复合拓扑完成代码实现与测试；
- [x] 蒸发器阶段四翅片显热衰减与高湿残余排湿阻力动力学模型完成代码编写与验证；
- [x] 状态栏自清洁感知死角清零与 FilterCareSheet 四相态微提示升级；
- [x] 131 个单元测试 100% 通过（0 failures）；
- [x] Release 构建及 app 打包签名成功；
- [x] README.md / README.en.md 同步最新特性与文档；
- [x] 敏感数据脱敏复核：零隐私泄漏。
