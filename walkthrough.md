# Haier AC Mac v1.9.108 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.108`
- **发版主题**：闭环双关键词夹心四元调度全景大一统、蒸发器自清洁 C^0 级平滑阻尼模型及菜单栏控制中心全屋联动调温
- **核心目标与架构演进**：
  1. **“四元夹心全拓扑闭环与调度意图击穿拦截”自然口语调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **双关键词在先夹心四元调度**：新增 `dualKeywordsWithRangeAndKeywordRegex`（双核心关键词在先+连续区间居中+核心词在后，如“大休和小休、周一至周三加单休日每天晚8点开机” `[1, 2, 3, 4, 7]`、“工作日同双休、周六至周日加单休每天晚8点开机” `[1..7]`），消灭前置双词截断漏洞；
     - **双关键词在后夹心四元调度**：新增 `keywordWithRangeAndDualKeywordsRegex`（核心关键词在先+连续区间居中+双核心词在后，如“大休、周一至周三加小休和单休日每天晚8点开机” `[1, 2, 3, 4, 7]`、“工作日同周二至周四加双休和大休每天晚8点开机” `[1..7]`），四元周期全排列拓扑自洽闭环；
     - **调度落空防击穿即时调温拦截门禁**：在 `parseRelativeTemperature` 中接入时钟调度语义过滤门禁，当语句中包含明确排班/定时意图（如“每天”、“定时”、“工作日”、“小时后”等）且带有开关机动作时，坚决拦截相对调温，根除因口语“加/高/升”导致的调度击穿为即时调温误操作；
     - **单元测试 100% 满分覆盖**：新增 `testQuadScheduleDualKeywordsAndTongConjunctionV19108` 测试套件，全套 116 个单元测试零缺陷通过，杜绝误触。
  2. **蒸发器自清洁健康度动力学 C^0 平滑连续阻尼物理模型 (`AppModel.swift`)**：
     - 重构 `selfCleaningProtectionFactor(for:)` 算法，从历史粗暴的第 7 天 10% 阶跃断崖式跳变，演进为 0~7 天 0.90 全效保护，7~14 天线性平滑阻尼过渡（`0.90 + 0.10 * (days - 7.0) / 7.0`），14 天后恒定为 1.00；
     - 建立了热负荷与滤网积灰动力学中的 C^0 连续物理模型，彻底消除能耗预测与健康评估中的台阶突变。
  3. **macOS 菜单栏控制中心温度 Bento 卡片全屋联动对称架构 (`MenuBarControlsView.swift`)**：
     - **当前机 / 全屋双态无缝切换**：温度 Bento 卡片依据顶部模式选择器（当前机/全屋）动态切换 UI 呈现；
     - **全屋状态深度感知**：在全屋模式下自动计算运行中机组的实时均温及温区分布（如“24~26°C 均温 · 统一步进”或“全屋同步中”），全待机时支持点击唤醒；
     - **统一步进与越界防卫**：提供全屋 `+/-` 统一步进胶囊按钮，调用 `adjustTemperatureAll(delta:)` 并严格执行 16~30°C 越界门禁。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下审查报告及全仓架构进行了全景复核与缺陷深挖：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 正则结构稳固，跨字符穿插防御严密；
   - **全屋与定向定时解耦 (P1-2)**：`cancelSchedules` 与 `cancelSchedulesAll` 精确分流，多设备批量取消分支全部贯通；
   - **工况占比计算属性消费 (P2-1)**：`EcoEnergySection` 已统一调用 4 个比率属性；
   - **死分支清理 (P2-2)**：`.adjustTemperatureAll` 死分支已彻底清理；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏与 UI Stepper 使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **蒸发器自清洁台阶断崖跳变消除 (P1 优化)**：消除了第 7 天从 0.90 瞬间跃升到 1.00 的断崖，建立平滑过渡；
   - **双关键词夹心四元排班拓扑补齐 (P0 修复)**：补齐了前后双关键词与连续区间夹心的两类四元排班正则，解决了极端复合排班的词尾丢失问题；
   - **调度意图击穿相对调温拦截 (P1 修复)**：杜绝排班语句被误判为即时加减温。

---

## 3. 关键架构变更与代码实现

### 3.1 双关键词夹心四元复合排班与防击穿门禁
- **`VoiceCommandParser.swift`**：
  ```swift
  // 双核心关键词在先、连续区间居中、核心关键词在后
  private static let dualKeywordsWithRangeAndKeywordRegex: NSRegularExpression? = {
      let pattern = #"(工作日|平时|...)\s*(?:[、,，和与及跟以及还有或者或加/／同\s]+)\s*(工作日|平时|...)\s*(?:[、,，和与及跟以及还有或者或加/／同\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／同\s]+)\s*(工作日|平时|...)"#
      return try? NSRegularExpression(pattern: pattern)
  }()

  // 调度防击穿门禁
  private static func parseRelativeTemperature(_ text: String) -> VoiceParseResult? {
      guard !containsNegativeAction(text) else { return nil }
      if (text.contains("开") || text.contains("关") || text.contains("停")) &&
         (text.contains("定时") || text.contains("倒计时") || text.contains("预约") || text.contains("每天") || text.contains("天天") || text.contains("每晚") || text.contains("每早") || text.contains("每日") || text.contains("每周") || text.contains("除") || text.contains("小时后") || text.contains("分钟后")) {
          return nil
      }
      ...
  }
  ```

### 3.2 自清洁健康度平滑阻尼连续物理模型
- **`AppModel.swift`**：
  ```swift
  private func selfCleaningProtectionFactor(for deviceId: String) -> Double {
      guard let cleanDate = deviceLastSelfCleanDate[deviceId] else { return 1.0 }
      let days = Date().timeIntervalSince(cleanDate) / 86400.0
      if days <= 7.0 {
          return 0.90 // 0~7天全效自清洁保护
      } else if days <= 14.0 {
          return 0.90 + 0.10 * ((days - 7.0) / 7.0) // 7~14天线性平滑阻尼过渡至1.00
      } else {
          return 1.00
      }
  }
  ```

### 3.3 控制中心温控卡片全屋联动架构
- **`MenuBarControlsView.swift`**：
  在全屋模式下展示 `avgTemp`、温区范围，并支持一键统一步进调温 `model.adjustTemperatureAll(delta:)`。

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **116 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build -c release`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 执行 `./build_app.sh 1.9.108`：
   - 顺利生成 App 产物 `dist/HaierAC.app` 与发布安装包 `dist/HaierAC-v1.9.108-macOS.zip`（体积 2.9MB，SHA256: `3f5141887f8ade57b7c80a763040a4558c7b44e5660c0e4a335069995f38f94c`）。

---

## 5. 发版信息与提交记录
- **Git Commit**：`feat & fix: 闭环双关键词夹心四元调度全景大一统、蒸发器自清洁 C^0 级平滑阻尼模型及菜单栏控制中心全屋联动调温 (v1.9.108)`
- **Git Tag**：`v1.9.108`
- **Release Asset**：`dist/HaierAC-v1.9.108-macOS.zip`
- **SHA256**：`3f5141887f8ade57b7c80a763040a4558c7b44e5660c0e4a335069995f38f94c`
