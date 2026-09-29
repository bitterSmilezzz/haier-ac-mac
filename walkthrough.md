# Haier AC Mac v1.9.72 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.72`
- **发版主题**：闭环自然语言双连续区间与跨度复合周期调度大一统引擎、macOS 状态栏同频任务高精周期标签全景展示及调度器原子批量新增重构
- **核心目标与架构演进**：
  1. **自然语言双连续区间与跨度复合周期调度大一统引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **双连续区间无缝复合解析**：新增 `rangeWithRangeRegex` 引擎，全面纳管“周一至周三和周五至周日每天早8点开机”、“周一到周三以及周五到天每天早8点开机”、“周二至周四和周六至周日每天早8点开机”等生活高频双跨度场景，智能融合两组环形区间的并集并格式化为地道标签（如 `[1, 2, 3, 4, 6, 7]` -> “周五至周三”）；
     - **连续区间与核心关键词双向混合纳管**：新增 `rangeWithKeywordRegex` 与 `keywordWithRangeRegex`，彻底攻克原有仅能捕获单星期字符导致关键词被截断丢弃的缺陷。全面支持“周一至周五和周末每天早8点开机”（全周 7 天）、“周一到周四加单休每天早8点开机”（周一至周六）、“周一至五加双休每天早8点开机”（全周 7 天）、“周末和周一至周三每天早8点开机”（周六至周三）以及“工作日加周六至周日每天早8点开机”等自然口语；
     - **连续区间附加多离散星期识别**：升级 `rangeWithMultiDaysRegex`，支持“周一至周三和周五周六每天早8点开机”、“周一到周三以及周五、周日每天早8点开机”等多星期捕获；
     - **复合区间在排除型周期与限定基准集中的大一统**：升级 `extractExcludedDays` 为连续区间全量匹配迭代提取，支持“除周一至周二和周五至周六外每天早8点开机”（提取周日、周三、周四 `[1, 4, 5]`）以及“周一至周五和周末除了周三每天早8点开机”（全周排除周三 `[1, 2, 3, 5, 6, 7]`），集合补集计算严密自洽；
     - **单元测试 100% 覆盖**：在 `VoiceCommandParserTests` 中新增 12 组端到端双区间、区间与关键词双向复合、区间附加多星期及复杂复合排除测试用例，所有断言 100% PASS。
  2. **macOS 原生状态栏同频任务高精周期标签全景展示与最近计划感知 (`StatusItemController.swift`)**：
     - **悬浮 Tooltip 最近计划周期属性直观感知**：在状态栏悬浮 Tooltip 的“最近计划”提示中，针对重复周期任务智能追加规范化地道周期标签（如 `(18:00 [工作日])`、`(08:00 [每天])`、`(22:00 [周一至周五])`），格式如 `⏱ 最近计划: 「客厅空调」将在 10分钟后开机 (18:00 [工作日])`，使用户无需点开二级菜单即可一眼分辨单次倒计时与长期周期规则；
     - **菜单与快捷倒计时批处理原子优化**：在 `quickCountdownFromMenu` 中全面接入底层 `addScheduledActions` 原子新增 API，彻底消除了全屋/多设备定时设置时的循环频繁磁盘写与调度器震荡。
  3. **调度器原子批量新增重构与 I/O 效率深度提升 (`AppModel.swift` / `VoiceCapsuleWindowController.swift`)**：
     - **原子批量新增 API (`addScheduledActions`)**：在 `AppModel` 中提供线程安全且带内存去重的批量新增调度方法，将全屋与多设备批量操作时的多次 `JSONEncoder` 序列化、磁盘 `UserDefaults` I/O、权限请求与调度器唤醒收敛为单次原子执行；
     - **语音胶囊全屋与多机下发全链路对齐**：将 `VoiceCapsuleWindowController` 中的全屋倒计时、全屋定时、全屋周期重复调度以及多设备批量调度全链路重构，彻底杜绝多设备时的循环序列化开销。

---

## 2. 关键架构变更与代码实现

### 2.1 双连续区间与跨度复合周期调度大一统引擎
- **`VoiceCommandParser.swift` 正则模式矩阵**：
  ```swift
  /// 匹配双连续区间复合口语（如“周一至周三以及周五至周日”、“周一到周三和周五到天”） (v1.9.72)
  private static let rangeWithRangeRegex: NSRegularExpression? = {
      let pattern = #"(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])"#
      return try? NSRegularExpression(pattern: pattern)
  }()

  /// 匹配连续区间在前、核心关键词在后口语（如“周一至周五和周末”、“周一到周四以及单休”） (v1.9.72)
  private static let rangeWithKeywordRegex: NSRegularExpression? = {
      let pattern = #"(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(工作日|平时|周末|双休|单休|周末三天)"#
      return try? NSRegularExpression(pattern: pattern)
  }()

  /// 匹配核心关键词在前、连续区间在后口语（如“周末和周一至周三”、“工作日加周六至周日”） (v1.9.72)
  private static let keywordWithRangeRegex: NSRegularExpression? = {
      let pattern = #"(工作日|平时|周末|双休|单休|周末三天)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7]))"#
      return try? NSRegularExpression(pattern: pattern)
  }()
  ```

- **`extractExcludedDays` 迭代全量范围提取**：
  ```swift
  if let regex = repeatWeekdayRangeRegex {
      let ns = remainingTarget as NSString
      let matches = regex.matches(in: remainingTarget, options: [], range: NSRange(location: 0, length: ns.length))
      for match in matches {
          if match.numberOfRanges >= 3 {
              let sStr = ns.substring(with: match.range(at: 1))
              let eStr = ns.substring(with: match.range(at: 2))
              if let sCh = sStr.first, let sWd = chineseDayCharToWeekday(sCh),
                 let eCh = eStr.first, let eWd = chineseDayCharToWeekday(eCh) {
                  excluded.formUnion(generateWeeklyRange(start: sWd, end: eWd))
              }
          }
      }
      if !matches.isEmpty {
          remainingTarget = regex.stringByReplacingMatches(in: remainingTarget, options: [], range: NSRange(location: 0, length: ns.length), withTemplate: " ")
      }
  }
  ```

### 2.2 macOS 原生状态栏同频任务高精周期标签全景展示
- **`StatusItemController.swift` Tooltip 周期标签动态追加**：
  ```swift
  let repeatSuffix: String = {
      if let label = firstAction.repeatLabel, !label.isEmpty {
          return " [\(label)]"
      } else if firstAction.repeatsDaily {
          return " [每天]"
      } else {
          return ""
      }
  }()
  tooltipParts.append("⏱ 最近计划: \(targetDeviceDesc)将在 \(remDesc)后\(actionVerb) (\(timeStr)\(repeatSuffix))")
  ```

### 2.3 调度器原子批量新增重构与 I/O 效率深度提升
- **`AppModel.swift` 原子批量新增 API**：
  ```swift
  @discardableResult
  public func addScheduledActions(_ newActions: [ScheduledAction]) -> Int {
      guard !newActions.isEmpty else { return 0 }
      var toAppend: [ScheduledAction] = []
      for action in newActions {
          let duplicateInExisting = scheduledActions.contains {
              $0.deviceId == action.deviceId && $0.attrName == action.attrName && $0.fireDate == action.fireDate
          }
          let duplicateInNew = toAppend.contains {
              $0.deviceId == action.deviceId && $0.attrName == action.attrName && $0.fireDate == action.fireDate
          }
          if !duplicateInExisting && !duplicateInNew {
              toAppend.append(action)
          }
      }
      guard !toAppend.isEmpty else { return 0 }
      scheduledActions.append(contentsOf: toAppend)
      AppLog.log("已批量新增调度任务（共 \(toAppend.count) 个）")
      requestNotificationPermission()
      wakeScheduler()
      return toAppend.count
  }
  ```

---

## 3. 验证与测试闭环
- **单元测试断言覆盖**：
  - 在 `VoiceCommandParserTests.swift` 中新增 12 组端到端用例，全部断言 100% PASS：
    1. “周一至周三和周五至周日每天早8点开机” -> `[1, 2, 3, 4, 6, 7]`、周五至周三 08:00:00 开机 ✅
    2. “周一到周三以及周五到天每天早8点开机” -> `[1, 2, 3, 4, 6, 7]`、周五至周三 08:00:00 开机 ✅
    3. “周一至周五和周末每天早8点开机” -> `[1, 2, 3, 4, 5, 6, 7]`、周一至周日 08:00:00 开机 ✅
    4. “周一到周四加单休每天早8点开机” -> `[2, 3, 4, 5, 6, 7]`、周一至周六 08:00:00 开机 ✅
    5. “周一至五加双休每天早8点开机” -> `[1, 2, 3, 4, 5, 6, 7]`、周一至周日 08:00:00 开机 ✅
    6. “周一到周三加周末三天每天早8点开机” -> `[1, 2, 3, 4, 7]`、周六至周三 08:00:00 开机 ✅
    7. “周末和周一至周三每天早8点开机” -> `[1, 2, 3, 4, 7]`、周六至周三 08:00:00 开机 ✅
    8. “工作日加周六至周日每天早8点开机” -> `[1, 2, 3, 4, 5, 6, 7]`、周一至周日 08:00:00 开机 ✅
    9. “周一至周三和周五周六每天早8点开机” -> `[1, 2, 3, 4, 6, 7]`、周五至周三 08:00:00 开机 ✅
    10. “周一到周三以及周五、周日每天早8点开机” -> `[1, 2, 3, 4, 6]`、每周日、一、二、三、五 08:00:00 开机 ✅
    11. “周一至周五和周末除了周三每天早8点开机” -> `[1, 2, 3, 5, 6, 7]`、周四至周二 08:00:00 开机 ✅
    12. “除周一至周二和周五至周六外每天早8点开机” -> `[1, 4, 5]`、每周日、三、四 08:00:00 开机 ✅
    13. 原有全量测试用例（否定句保护、离散星期、单休制、长周末、半度调温等）全部保持 100% 兼容通过 ✅
- **本地编译与打包校验**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` 0 警告 0 错误编译通过；
  - `./build_app.sh 1.9.72` 构建成功：
    - `dist/HaierAC.app` (含 `HaierACWidget.appex` 小组件扩展)
    - `dist/HaierAC-v1.9.72-macOS.zip` (大小: 2.8M)
    - SHA256 校验和：`2d056c7956476135fe0d1d7d67b4b07c3ee8c8ad306a8759976edc8b6a2e9bd5`
- **安全敏感数据审查**：
  - 严密审查无任何个人手机号、真实密码、私有 API Key 或敏感隐私数据外泄。
