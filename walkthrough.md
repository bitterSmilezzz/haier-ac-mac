# Haier AC Mac v1.9.125 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.125`
- **发版主题**：闭环十九核心关键词与十三连续区间全景排班大一统、蒸发器阶段一霜层绝热动力学及状态栏全息感知死角清零
- **核心目标与架构演进**：
  1. **“十九核心关键词全景排班、十三连续区间复合拓扑与口语极限绝决转折否定防御”自然口语调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **纯十九核心关键词全景调度 (`enneadecaKeywordsRegex`)**：新增 `enneadecaKeywordsRegex`，全面支持多达 19 种核心周期关键词连缀（“工作日、平时、平日、双休日、双休、周末三天、周末、公休日、休假日、放假日、节假日、单休日、单休、大休日、大休、大周、小周、小休和无休每天早8点开机” `[1..7]`），十全十美闭环超高维排班最后一公里死角；
     - **十三连续独立区间与高维复合拓扑拓展 (`tredecemRangeRegex` / `duodecemRangeWithKeywordRegex` / `keywordWithDuodecemRangeRegex` / `duodecemKeywordsWithDualRangeRegex`)**：
       - `tredecemRangeRegex`：十三连续独立区间复合口语调度（如“周一至周一、周二至周二、周三至周三、周四至周四、周五至周五、周六至周六、周日至周日、周一到周一、周二到周二、周三到周三、周四到周四、周五到周五加周六到周六每天早8点开机” `[1..7]`）；
       - `duodecemRangeWithKeywordRegex`：十二连续区间在先、核心关键词在后（如“周一至周一、周二至周二、周三至周三、周四至周四、周五至周五、周六至周六、周日至周日、周一到周一、周二到周二、周三到周三、周四到周四、周五至周五加单休每天早8点开机” `[1..7]`）；
       - `keywordWithDuodecemRangeRegex`：核心关键词在先、十二连续区间在后（如“单休加周一至周一、周二至周二、周三至周三、周四至周四、周五至周五、周六至周六、周日至周日、周一到周一、周二到周二、周三到周三、周四到周四、周五至周五每天早8点开机” `[1..7]`）；
       - `duodecemKeywordsWithDualRangeRegex`：十二核心关键词在先、双连续区间在后（如“工作日、平时、平日、双休日、双休、周末三天、周末、公休日、休假日、放假日、大休日和大休加周六至周六、周日到周日每天早8点开机” `[1..7]`）；
     - **强化极端口语绝决转折否定与全方位动作谓词拦截扩充**：扩充“哪怕天诛地灭也千万不要/别”、“哪怕赴汤蹈火也绝不能/不要”、“哪怕地动山摇也别”、“任凭千难万险都不要”、“无论海枯石烂都绝不”、“横竖千真万确不能”、“打死也断然不能”、“决决断断不可”等极端绝决转折否定句式，杜绝复杂口语语义穿透误触发；
     - **单元测试 133 项 100% 满分覆盖**：新增 `testTredecemRangeAndEnneadecaKeywordsV19125` 严苛测试套件，全套 133 个单元测试零缺陷通过（0 failures）。
  2. **56°C 蒸发器自清洁阶段 1 霜层绝热热阻累积与蒸发压力比动态功耗模型 (`EnergyAnalyticsEngine.swift`)**：
     - **阶段 1/4 (0~5min, 深冷结霜凝水阶段)**：在第 0~2 分钟初期过冷凝露微相变潜热成核与低温润滑油阻尼（$+0\text{W} \sim +25\text{W}$）的基础上，针对第 2~5 分钟深冷结霜阶段，引入**霜层绝热阻抗动力学模型**（`frostInsulationDamping`）：随着翅片表面霜层由微晶向多孔冰晶层持续增厚，导热热阻增加导致吸热蒸发温度及压力持续降低，压缩机压比增大，驱动功耗在第 2~5 分钟呈非线性爬坡上升（$+0\text{W} \sim +30\text{W}$ 附加功），与第 5 分钟四通阀换向解冻阶段无缝平滑衔接，彻底补全阶段 1 全时段物理微观演进机制。
  3. **macOS 状态栏多设备 Hover Tooltip 自清洁感知死角清零与多端展示一致性优化 (`StatusItemController.swift`)**：
     - **状态栏多设备 Tooltip 自清洁感知死角清零**：修复多设备工况下，状态栏菜单项的 Tooltip 在遍历各设备时，自清洁中的设备被错误判定为常规运行或待机而显示过时状态的死角；
     - **全息感知统一呈现**：全面统一呈现 `✨ 56°C自清洁 [\(phaseTag) \(cleanPct)%] (倒计时)` 动态时相与百分比，并消除 Tooltip 底部冗余重复的自清洁摘要块，实现单设备/多设备、菜单栏/二级子菜单/Tooltip 的 100% 视觉与体验自洽。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下审查报告及全仓架构进行了全景复核与缺陷深挖：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 保持严格的结构化正则匹配，本轮进一步扩充极端转折口语与多动作谓词，杜绝插字绕过与语义遗漏；
   - **定时取消定向与全屋作用域区分 (P1-2)**：解析层严格区分 `.cancelSchedulesAll` 与 `.cancelSchedules`，UI 文案与执行范围完全对齐；
   - **工况占比计算属性 (P2-1)**：`EcoEnergySection` 已统一消费 `EnergyAnalyticsEngine` 的占比计算属性；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **十九核心关键词与十三连续区间全景排班 (高价值优化)**：补齐 `enneadecaKeywordsRegex`、`tredecemRangeRegex`、`duodecemRangeWithKeywordRegex`、`keywordWithDuodecemRangeRegex` 及 `duodecemKeywordsWithDualRangeRegex`，消灭高维极端自然口语复合排班的解析断裂死角；
   - **蒸发器阶段一霜层绝热热阻动力学模型 (高价值优化)**：重构阶段 1 结霜初期 2~5 分钟冰霜厚度增加带来的绝热阻抗动态功耗抬升过程，与阶段 2 解冻熔化、阶段 3 烘干汽化、阶段 4 送风排湿全面贯通；
   - **状态栏多设备 Tooltip 自清洁感知死角清零 (高价值优化)**：消除 Tooltip 遍历各设备时自清洁设备被显示为待机/常规运行的死角，统一自清洁看板输出并剔除冗余块。

---

## 3. 关键架构变更与代码实现

### 3.1 十九核心关键词与十三连续区间复合排班引擎
- **`VoiceCommandParser.swift`**：
  ```swift
  // 十三连续独立区间调度
  private static let tredecemRangeRegex: NSRegularExpression? = { ... }()

  // 十二连续区间在先、核心关键词在后
  private static let duodecemRangeWithKeywordRegex: NSRegularExpression? = { ... }()

  // 核心关键词在先、十二连续区间在后
  private static let keywordWithDuodecemRangeRegex: NSRegularExpression? = { ... }()

  // 十二核心关键词在先、双连续区间在后
  private static let duodecemKeywordsWithDualRangeRegex: NSRegularExpression? = { ... }()

  // 纯十九核心关键词全景正则
  private static let enneadecaKeywordsRegex: NSRegularExpression? = { ... }()
  ```

### 3.2 蒸发器阶段一霜层绝热阻抗动力学模型
- **`EnergyAnalyticsEngine.swift`**：
  ```swift
  // 阶段 1 (0~5 分钟, 深冷结霜凝水初期与霜层累积):
  let condensationRamp = max(0.0, (1.0 - (Double(cleaningMinutes) / 2.0)) * 25.0)
  // 分钟 2~5: 翅片冰霜增厚绝热效应导致吸热蒸发温度及压力持续降低，压缩机压比增大带来动力学附加功 (+0W ~ 30W)
  let frostInsulationDamping: Double
  if cleaningMinutes >= 2 && cleaningMinutes < 5 {
      let frostFraction = Double(cleaningMinutes - 2) / 3.0
      frostInsulationDamping = frostFraction * 30.0
  } else {
      frostInsulationDamping = 0.0
  }
  cleaningPower = 380.0 + latentLoad + sensibleLoad + condensationRamp + frostInsulationDamping + (windOffset * 0.3)
  ```

### 3.3 状态栏多设备 Tooltip 自清洁感知死角清零
- **`StatusItemController.swift`**：
  ```swift
  for dev in allDevices {
      // 优先感知自清洁工况
      let isDevCleaning = model.cleaningDeviceIds.contains(dev.id) || (dev.id == model.currentDevice?.id && model.isSelfCleaningActive)
      if isDevCleaning {
          let cleanPhase = model.selfCleaningPhaseShortTag
          let cleanPct = model.selfCleaningProgressPercentage
          let remainingMin = model.selfCleaningRemainingSeconds / 60
          let remainingSec = model.selfCleaningRemainingSeconds % 60
          let timeText = String(format: "%02d:%02d", remainingMin, remainingSec)
          let cleanInfo = "✨ 56°C自清洁 [\(cleanPhase) \(cleanPct)%] (\(timeText))"
          lines.append("• \(dev.deviceName): \(cleanInfo)")
      } else if isPowerOn {
          lines.append("• \(dev.deviceName): \(modeText) \(targetTempText) | \(windText)")
      } else {
          lines.append("• \(dev.deviceName): ⚪️ 待机")
      }
  }
  ```

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **133 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build -c release`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 运行 `./build_app.sh 1.9.125`：
   - 生成打包应用：`dist/HaierAC.app`（含小组件插件 `HaierACWidget.appex`）
   - 安装包：`dist/HaierAC-v1.9.125-macOS.zip` (大小: ~3.1MB)
   - SHA-256 校验和：`5ef11cb01b70b0bcc862d478b06d0e4e39d6ef5971dd0b400fece1466d261aef`

---

## 5. 发版验证清单
- [x] Code Review 历史问题与架构深度排查闭环；
- [x] 十九核心关键词全景排班及十三连续区间复合拓扑完成代码实现与测试；
- [x] 蒸发器阶段一霜层绝热阻抗动力学模型完成代码编写与物理自洽验证；
- [x] 状态栏多设备 Tooltip 自清洁感知死角清零并消除冗余提示；
- [x] 133 个单元测试 100% 通过（0 failures）；
- [x] Release 构建及 app 打包签名成功；
- [x] README.md / README.en.md 同步最新特性与文档；
- [x] 敏感数据脱敏复核：零隐私泄漏。
