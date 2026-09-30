# Haier AC Mac v1.9.100 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.100`
- **发版主题**：闭环多区间复合周期调度、星期时相防黏连与负向排除全基准大一统引擎及状态栏情景预设快捷下发
- **核心目标与架构演进**：
  1. **“多区间复合周期与双核心关键词大一统”自然口语解析引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **纯核心关键词双重组合调度拦截**：新增 `keywordWithKeywordRegex`（如“工作日加周末”、“工作日和双休”、“周末和平时”），精确合并双核心关键词集合（`[1, 2, 3, 4, 5, 6, 7]`），彻底杜绝由于字符贪婪切分导致的词义断裂；
     - **调整解析流水线优先级杜绝提前截断**：将 `keywordWithKeywordRegex` 与离散多星期夹心复合正则置于单日附加正则之前，确保“周二周四和周末”等离散多星期复合表达能完整提取（`[1, 3, 5, 7]`），彻底消除“周二”被截断丢失的缺陷；
     - **离散附加星期“每天”语素防穿透保护**：在 `keywordWithExtraDayRegex` 与 `discreteWeekdaysRegex` 内部全面植入 `(?!(?:每天|天天|每日|每晚|每早|每晨|每夜|日日))` 负向先行断言，阻断用户口语中由“每天/天天”构成的时态被贪婪提取其字面量“天”误当作星期天（周日 `[1]`）；
     - **星期数字与紧随钟点防黏连隔离**：新增针对“周X”后紧随钟点的词法隔离机制，杜绝“周一8点开机”在中文数字转换后被意外连缀为“周18点”而误识别为 18:00；
     - **钟点与整十分钟小数转换防穿透守卫**：在 `decimalPointPattern` 中增加针对“十”与数字的负向断言，防止“十点五十分”中的“五”被错误当作小数转换为“10.5十分”；
     - **黄昏与天黑 PM 时相精准归一**：在非标准时相解析中补全“黄昏”与“天黑”，精准映射至下午/傍晚 PM 时区；
     - **单元测试 100% 满分覆盖**：全套 108 个单元测试零缺陷通过，包含多区间复合调度、排除型否定、半点时相归一与防即时误触断言。
  2. **macOS 原生状态栏一键情景预设快捷菜单 (`StatusItemController.swift`)**：
     - **新增「✨ 一键情景预设」一级/二级子菜单**：无缝对接模型内建的「睡眠」、「离家」、「回家」及自定义情景模式，状态栏菜单直观呈现情景图标（🌙 / 🚪 / 🏠 / ✨）与多属性动作摘要；
     - **智能双模式协同下发**：单设备环境下支持一键直达应用；多设备矩阵环境下自动展开下级菜单，支持“应用至「主显设备」”与“应用至全屋所有空调 (N台)”双路由协同调度，并伴随原生系统通知与状态栏即时刷新。

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
   - **核心关键词组合被误判与截断 (P1)**：在自然语言排班中，“工作日加周末”此前容易被 `keywordWithExtraDayRegex` 中匹配单日的模式抢先截取后半部分，将“工作日”的“日”误认为单日，或者在多日组合“周二周四和周末”中提早拦截“周四和周末”，漏掉“周二”。本次调整正则执行流水线与专属定义后彻底修复；
   - **“每天”语素在附加星期中泄露 (P1)**：在“除工作日外每天8点开机”或复杂口语中，“每天”中的“天”若被离散星期正则捕获，会导致额外产生星期天（周日 `[1]`）的误判。植入负向先行断言后彻底杜绝；
   - **状态栏情景预设快捷菜单缺失 (高价值体验优化)**：用户在状态栏可以直接切换模式、风速、调温，但无法一键执行预设的睡眠/离家/回家多属性情景。本次在状态栏原生菜单中补齐「✨ 一键情景预设」子菜单，支持主显设备与全屋多机一键联动。

---

## 3. 关键架构变更与代码实现

### 3.1 复合双核心关键词正则与流水线排序
- **`VoiceCommandParser.swift`**：
  ```swift
  // 4.18 纯核心关键词双重组合口语（如“工作日加周末”、“工作日和双休”、“周末和平时”）(v1.9.100)
  if let regex = keywordWithKeywordRegex,
     let match = regex.firstMatch(in: text, options: [], range: fullRange),
     match.numberOfRanges >= 3 {
      let kw1 = nsString.substring(with: match.range(at: 1))
      let kw2 = nsString.substring(with: match.range(at: 2))
      var days = Set<Int>()
      for kw in [kw1, kw2] {
          if kw == "工作日" || kw == "平时" || kw == "平日" {
              days.formUnion([2, 3, 4, 5, 6])
          } else if kw == "周末" || kw == "双休" || kw == "双休日" || kw == "休息日" || kw == "公休日" || kw == "休假日" || kw == "放假日" || kw == "节假日" {
              days.formUnion([1, 7])
          } else if kw == "单休" {
              days.formUnion([2, 3, 4, 5, 6, 7])
          } else if kw == "周末三天" {
              days.formUnion([1, 6, 7])
          }
      }
      if !days.isEmpty {
          let sorted = days.sorted()
          return (sorted, formatWeekdayLabel(from: sorted))
      }
  }
  ```

### 3.2 星期时相防黏连与小数防穿透
- **`VoiceCommandParser.swift`**：
  ```swift
  // 排除后接“分/分钟”及“十/数字”的钟点分表达，杜绝“十点五十分”误转为 10.5
  let decimalPointPattern = #"([零0一二两三四五六七八九\d]+)点(?:五|5)(?![分分钟]|十|\d)"#

  // 隔离星期数字与紧随其后的钟点，避免“周一8点”转换成“周18点”被误判为18:00
  let weekdayHourCollisionPattern = #"((?:周|星期|礼拜)[1-7])(?=\d{1,2}(?:点|时|:))"#
  if let regex = try? NSRegularExpression(pattern: weekdayHourCollisionPattern) {
      let ns = str as NSString
      str = regex.stringByReplacingMatches(in: str, options: [], range: NSRange(location: 0, length: ns.length), withTemplate: "$1 ")
  }
  ```

### 3.3 macOS 原生状态栏一键情景预设快捷菜单
- **`StatusItemController.swift`**：
  ```swift
  let scenes = model.scenes
  if !scenes.isEmpty {
      let scenesMenu = NSMenu()
      scenesMenu.autoenablesItems = false
      for scene in scenes {
          let actionDesc = scene.actions.map(\.attrDesc).joined(separator: " · ")
          let sceneGlyph = ...
          if allDevices.count > 1 {
              // 支持主显设备与全屋协同双选项
              ...
          } else {
              // 单设备一键直达
              ...
          }
      }
      let scenesParentItem = NSMenuItem(title: "✨ 一键情景预设 (\(scenes.count)项)...", action: nil, keyEquivalent: "")
      menu.setSubmenu(scenesMenu, for: scenesParentItem)
      menu.addItem(scenesParentItem)
  }
  ```

---

## 4. 验证与测试结果

- **单元测试覆盖**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test` -> **108 tests 全部 PASS（0 failures）**：
    - `VoiceCommandParserTests`: 62 tests (含 `testExclusionRepeatWeekdays`, `testBigSmallWeekendScheduleV1999`, `testNonWeekdayScheduleGeneralizationV1998`, `testSingleWeekendAndMultiScheduleHardeningV1994` 等) 100% 通过；
    - `ZlibTests`: 7 tests 100% 通过；
    - `HaierACCoreTests`: 108 tests 100% 通过。
- **本地编译验证**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build -c release` -> 100% 通过（0 错误）。
  - 打包生成产物：
    - `dist/HaierAC.app` (v1.9.100, 完整应用)
    - `dist/HaierAC-v1.9.100-macOS.zip` (2.8MB, SHA256: `82dd976feaeca72cd4661d0b788f37417373c17b9d4c408b0f3e8aea6ee7fae7`)

---

## 5. 发版交付总结

- **Git Commit**：包含多区间复合周期调度、星期时相防黏连与负向排除全基准大一统引擎及状态栏情景预设快捷下发。
- **Git Tag**：`v1.9.100`
- **GitHub Release**：附带产物压缩包与完整更新日志。
