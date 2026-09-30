# Haier AC Mac v1.9.98 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.98`
- **发版主题**：闭环全景反相周区间与离散多星期循环调度脱靶缺陷、macOS 原生状态栏全屋与单机风速待机唤醒大一统与滤网动力学抗待机抖动模型
- **核心目标与架构演进**：
  1. **“任意反相连续周区间（非周X至周Y）与离散多星期反相”自然周期循环调度大一统引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **彻底修复任意反相连续周区间脱靶缺陷**：针对自然口语中任意连续周区间反相（如“非周一至周三8点开机”、“非周一到周四8点开机”、“非周二至周六8点开机”、“非周五至周日8点开机”、“非周一至五8点开机”、“非周一~周三8点开机”），新增 `nonRepeatWeekdayRangeRegex` 通用连续周区间反相前置拦截引擎，通过拓扑环形区间展开精准计算补集（例如“非周一至周三”精准映射为排除周一至周三 `[2, 3, 4]`，在周四至周日 `[1, 5, 6, 7]` 运行），彻底消除原单星期正则贪婪截断漏排除周二周三的重大缺陷；
     - **彻底修复离散多星期反相与并列多星期极性颠倒及漏排除缺陷**：新增 `nonRepeatMultiWeekdaysRegex` 与固定习惯用语优先拦截流水线，涵盖“非一三五”（精准映射为除周一三五外的 `[1, 3, 5, 7]`，杜绝正相贪婪匹配导致的 180 度极性颠倒）、“非二四六”（映射为 `[1, 2, 4, 6]`）、“非二四”（映射为 `[1, 2, 4, 6, 7]`）、“非周六周日”/“非周六和周日”（映射为工作日 `[2, 3, 4, 5, 6]`）、“非周一和周三”/“非周一周三”（映射为排除周一周三的 `[1, 3, 5, 6, 7]`）及“非周二周四”等，多星期反相全景闭环；
     - **彻底修复排除型语义嵌套反相周区间与多星期（“除非周一至周三外每天开机”、“除非一三五外每天开机”）补集计算自洽**：在 `extractExcludedDays` 中建立反相连续区间与反相多星期的补集运算，确保“除非周一至周三外每天开机”正确保留并仅在周一至周三 `[2, 3, 4]` 运行；
     - **全景反相周区间与多星期半点时相归一及防即时误触加固**：全面纳管“非周一至周三半”、“非一三五半”、“非二四六半”、“非周六周日半”等映射至 08:30，并在 `hasTimingOrCountdownIntent` 中严密守护，绝不穿透至即时开关机；
     - **单元测试 100% 满分覆盖**：在 `VoiceCommandParserTests.swift` 中新增 `testNonWeekdayScheduleGeneralizationV1998`，包含 25 组严苛反相区间、多星期离散组合、排除型嵌套、半点归一及防误触断言，全部通过。
  2. **macOS 原生状态栏全屋与单机风速协同待机唤醒大一统 (`StatusItemController.swift`)**：
     - **全屋风速协同支持待机一键直接唤醒**：解耦顶层「🍃 全屋风速协同」菜单项门禁，从原本硬编码依赖 `!onDevices.isEmpty` 升级为基于网关可控裁决 `!controllableDevices.isEmpty`。当全屋空调均处于关机待机状态时，菜单项不再置灰禁用，用户可直接点击微风（🍃）、中风、强劲、自动风速一键全屋唤醒并切入该档位，杜绝了此前必须先开机再进菜单改风速的断层繁琐体验；
     - **单机与级联风速子菜单待机直接唤醒**：解耦单机风速调节菜单项的 `isPowerOn` 门禁，在待机状态下允许直接选择风速档位一键唤醒单机并设置风速；
     - **自适应悬浮 Tooltip 与运行指引**：待机时菜单项呈现“🍃 全屋风速协同 (全屋待机中 · 点击开启风速)...”，子项智能提示“一键开启全屋 N 台空调并设为微风/低速档，出风轻柔静音，适合夜间睡眠与母婴呵护”，与模式协同形成 100% 全对称大一统交互。
  3. **滤网寿命动力学预测算法抗待机抖动平滑增强 (`AppModel.swift`)**：
     - **消除开关机待机瞬态导致的剩余天数锯齿跳变**：为 `calculateCurrentFilterWearFactor` 增加 `allowStandbyConfig` 长期平滑推算参数，在 `estimatedFilterRemainingDays` 寿命预测中传入 `true`，以设备实际配置的运行模式、目标温度、风速及环境温湿度进行长期稳态推算，彻底消除空调关机待机时因强制重置为 1.0 导致的剩余天数剧烈虚高跳变，数据稳定拟真。
  4. **Siri 与快捷指令风速 Intent 待机自动唤醒与快捷词拓展 (`AppIntents.swift`)**：
     - **`SetACWindSpeedIntent` 支持待机自动唤醒**：在 Siri 与快捷指令调节风速时开启 `autoPowerOn: true`，设备处于关机状态时自动开启并应用指定风速；
     - **AppShortcuts 高频快捷短语扩展**：新增“用 Haier AC 开启微风”、“全屋微风”、“全屋自动风速”等便捷控制短语。

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
   - **反相连续周区间（“非周一至周三”）与离散多星期（“非一三五”）极性颠倒与截断脱靶缺陷 (P0/P1)**：此前单星期反相虽然解决了“非周一”，但“非周一至周三”因缺乏区间前置拦截，被 `非周([一-日])` 贪婪截断只排除了周一，漏排除了周二和周三；而“非一三五”、“非二四六”由于正向数字匹配被 180 度颠倒。本次架构新增通用拓扑区间补集与多星期正则流水线，彻底消除盲区；
   - **排除型嵌套反相语义“除非周一至周三外每天开机”运算自洽 (P1)**：在 `extractExcludedDays` 中构建连续区间补集反转，保证最终精准保留周一至周三；
   - **状态栏全屋协同风速项待机状态下置灰禁用 (P1/P2)**：全屋待机时「🍃 全屋风速协同」置灰，用户无法一键唤醒并设定风速；解耦后实现待机一键设定风速并自动唤醒，且全屋与单机、风速与模式完全对称；
   - **滤网剩余天数因设备待机产生锯齿状跳变 (P2)**：待机时瞬时磨损系数重置为 1.0，导致关机时剩余天数瞬间变多、开机又骤减；增加 `allowStandbyConfig` 消除待机扰动；
   - **Siri 快捷指令与 AppShortcuts 风速 Intent 联动 (P2)**：启用 `autoPowerOn: true` 并丰富 Siri 语音短语库。

---

## 3. 关键架构变更与代码实现

### 3.1 任意反相连续周区间与离散多星期循环调度大一统
- **`VoiceCommandParser.swift` 通用连续周区间与离散多星期前置拦截**：
  ```swift
  // 4.-1 通用任意连续周区间反相拦截 (v1.9.98)
  let nonRepeatWeekdayRangePattern = #"(?:每个?|每周|每逢|逢)?\s*非\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:至|到|~|-)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])"#
  if let nonRangeRegex = try? NSRegularExpression(pattern: nonRepeatWeekdayRangePattern) {
      let ns = text as NSString
      let fullRange = NSRange(location: 0, length: ns.length)
      if let m = nonRangeRegex.firstMatch(in: text, options: [], range: fullRange), m.numberOfRanges >= 3 {
          let sCh = ns.substring(with: m.range(at: 1)).first
          let eCh = ns.substring(with: m.range(at: 2)).first
          if let sCh = sCh, let eCh = eCh,
             let sWd = chineseDayCharToWeekday(sCh),
             let eWd = chineseDayCharToWeekday(eCh) {
              var rangeDays = Set<Int>()
              var cur = sWd
              while true {
                  rangeDays.insert(cur)
                  if cur == eWd { break }
                  cur = (cur % 7) + 1
                  if cur == sWd { break }
              }
              let targetDays = Set([1, 2, 3, 4, 5, 6, 7]).subtracting(rangeDays).sorted()
              let label = formatRepeatWeekdaysLabel(targetDays) ?? "每天"
              return (targetDays, label)
          }
      }
  }

  // 4.-2 通用多星期/离散星期反相拦截 (v1.9.98)
  ...
  ```
- **`hasTimingOrCountdownIntent` 与 `normalizeTimeExpressions` 严密时态防线**：
  全面纳管“非周一至周三”、“非一三五”、“非二四六”、“非周六周日”及半点归一（映射至 08:30），杜绝误触立即开关机。

### 3.2 macOS 原生状态栏全屋与单机风速待机唤醒
- **`StatusItemController.swift`**：
  ```swift
  let controllableDevices = model.allUnifiedDevices.filter { model.reachability(for: $0.id).isControllable }
  let windSpeedRunningDesc = !onDevices.isEmpty ? (allOnSameWindSpeed != nil ? " (\(onDevices.count)台运行中 · 当前\(allOnSameWindSpeed!.desc))" : " (\(onDevices.count)台运行中 · 风速不同)") : " (全屋待机中 · 点击开启风速)"
  let canSetWindSpeedAll = model.gatewayConnected && !controllableDevices.isEmpty

  for itemDef in windLevels {
      let isSelected = (allOnSameWindSpeed == itemDef.code)
      let check = isSelected ? "✓ " : ""
      let item = NSMenuItem(title: "\(check)\(itemDef.title)", action: #selector(setAllWindSpeedFromMenu(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = itemDef.code.rawValue
      item.isEnabled = canSetWindSpeedAll
      ...
  }
  ```

### 3.3 滤网寿命预测抗待机抖动平滑模型
- **`AppModel.swift`**：
  ```swift
  func calculateCurrentFilterWearFactor(for device: ACDevice, allowStandbyConfig: Bool = false) -> Double {
      guard device.isPowerOn || allowStandbyConfig else { return 1.0 }
      ...
  }

  var estimatedFilterRemainingDays: Int {
      ...
      let wearFactor = calculateCurrentFilterWearFactor(for: dev, allowStandbyConfig: true)
      ...
  }
  ```

---

## 4. 验证与测试结果

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增并校验端到端单元测试用例（25 组严苛断言 100% PASS）：
  - `"非周一至周三8点开机"` -> `08:00` 开机，周四至周日循环 (`[1, 5, 6, 7]`) (PASS)
  - `"非周一到周四8点开机"` -> `08:00` 开机，周五至周日循环 (`[1, 6, 7]`) (PASS)
  - `"非周二至周六8点开机"` -> `08:00` 开机，周日至周一循环 (`[1, 2]`) (PASS)
  - `"非周五至周日8点开机"` -> `08:00` 开机，周一至周四循环 (`[2, 3, 4, 5]`) (PASS)
  - `"非周一至五8点开机"` -> `08:00` 开机，周末循环 (`[1, 7]`) (PASS)
  - `"非周一~周三8点开机"` -> `08:00` 开机，周四至周日循环 (`[1, 5, 6, 7]`) (PASS)
  - `"非一三五8点开机"` -> `08:00` 开机，周二四六日循环 (`[1, 3, 5, 7]`) (PASS)
  - `"非二四六8点开机"` -> `08:00` 开机，周一三五日循环 (`[1, 2, 4, 6]`) (PASS)
  - `"非二四8点开机"` -> `08:00` 开机，周一三五六日循环 (`[1, 2, 4, 6, 7]`) (PASS)
  - `"非周六周日8点开机"` -> `08:00` 开机，工作日循环 (`[2, 3, 4, 5, 6]`) (PASS)
  - `"非周六和周日8点开机"` -> `08:00` 开机，工作日循环 (`[2, 3, 4, 5, 6]`) (PASS)
  - `"非周一和周三8点开机"` -> `08:00` 开机，周二四五六日循环 (`[1, 3, 5, 6, 7]`) (PASS)
  - `"非周一周三8点开机"` -> `08:00` 开机，周二四五六日循环 (`[1, 3, 5, 6, 7]`) (PASS)
  - `"非周二周四8点开机"` -> `08:00` 开机，周一三五六日循环 (`[1, 2, 4, 6, 7]`) (PASS)
  - `"除非周一至周三外每天开机"` -> `08:00` 开机，每周一至周三 (`[2, 3, 4]`) (PASS)
  - `"除非一三五外每天开机"` -> `08:00` 开机，每周一三五 (`[2, 4, 6]`) (PASS)
  - `"非周一至周三半开机"` -> `08:30` 开机，周四至周日循环 (`[1, 5, 6, 7]`) (PASS)
  - `"非一三五半开机"` -> `08:30` 开机，周二四六日循环 (`[1, 3, 5, 7]`) (PASS)
  - `"非二四六半关机"` -> `08:30` 关机，周一三五日循环 (`[1, 2, 4, 6]`) (PASS)
  - 防即时误触全景断言：6 组反相口语严苛断言绝不触发 `setPower`、`turnOffAll` 或 `turnOnAll` (PASS)

- **本地编译验证**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` -> 100% 通过（0 错误，0 致命告警）
  - `./build_app.sh 1.9.98` -> 打包成功：
    - `dist/HaierAC.app` (v1.9.98, 含小组件)
    - `dist/HaierAC-v1.9.98-macOS.zip` (SHA256 完整，已归档)
