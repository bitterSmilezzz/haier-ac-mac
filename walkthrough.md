# Haier AC Mac v1.9.70 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.70`
- **发版主题**：闭环自然语言全基准集排除型周期调度通用大一统引擎、中国特色单休制纳管、macOS 状态栏同频批次任务跨天周期智能消歧与原子批处理重构
- **核心目标与架构演进**：
  1. **自然语言全基准集排除型周期调度通用大一统引擎与单休制纳管 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **大一统基准集合递归解析架构**：重构 `parseRepeatWeekdays` 为分层架构，解耦基础周期规则提取引擎 `parseBaseRepeatWeekdays`。在 `extractBaseScopeWeekdays` 中突破以往仅支持简单区间的死板局限，全面打通连续区间、离散多星期（如“一三五除了周三每天早8点开机”、“二四六除周四外每天早8点开机”）、复合区间与附加星期（如“工作日和周六除了周三每天早8点开机”）及中国特色单休制，彻底解决因基准集提取失败退化为全周 7 天扣减反向包含周日/周二等严重语义颠倒缺陷；
     - **“每天”与“每逢星期天”词法消歧及负向断言防线**：在 `rangeWithExtraDaysRegex`、`keywordWithExtraDayRegex` 与 `discreteWeekdaysRegex` 中引入负向先行断言 `(?!(?:每天|天天|每日|每晚|每早|每晨|每夜|日日))`，彻底消除中文口语中“工作日 每天早8点开机”或“周一至周五每天早8点开机”中“每天”被错误拆解为“每 + 天（星期天）”导致的严重多选一天（误计入周日）历史逻辑隐患；
     - **中国特色“单休制”（周一至周六工作、周日单休）全链路纳管**：在核心语义中将“单休”映射为 `[2, 3, 4, 5, 6, 7]`（“周一至周六”），支持“单休每天早8点开机”、“单休除周三外每天早8点开机”等；在 `formatRepeatWeekdaysLabel` 中补齐 `[3, 7]` 为“每周二、六”，`[2, 3, 5, 6, 7]` 规范映射为“每周一、二、四、五、六”；
     - **单元测试 100% 覆盖**：在 `VoiceCommandParserTests` 中新增 7 组端到端离散基准集合排除、复合基准集排除与单休制用例，全部断言 100% PASS。
  2. **macOS 原生状态栏同频批次任务跨天周期智能消歧与原子批处理重构 (`StatusItemController.swift` / `AppModel.swift`)**：
     - **同频任务跨天周期智能消歧与集合无序比对**：重构 `isSiblingSchedule`，将原脆弱的数组有序比对全面升级为 `Set(repeatWeekdays)` 无序集合语义比对，彻底杜绝元素顺序偏差导致的同频任务识别失败；针对重复周期任务（`repeatsDaily` 或 `!repeatWeekdays.isEmpty`），根据钟点与分钟（`hour` / `minute`）判定同一时间触发点，彻底解决多台设备因跨天计算时刻或微秒偏移引发的同频兄弟任务脱节断层；
     - **`AppModel` 原子批处理与主线程调度器降噪**：新增 `removeScheduledActions(ids: Set<UUID>)` 与 `setScheduledActionsEnabled(ids: Set<UUID>, enabled: Bool)`，将以往在循环中离散调用更新并重复触发 `wakeScheduler()` 与保存的开销收敛为单次原子批量处理，彻底消除多任务协同操作时的界面卡顿与调度器震荡。

---

## 2. 关键架构变更与代码实现

### 2.1 全基准范围大一统排除型周期调度通用引擎
- **`VoiceCommandParser.swift` 基础提取与排除分层解耦及大一统基准解析**：
  ```swift
  /// 解析文本中的重复周期规则 (v1.9.70 大一统全基准排除型周期调度引擎与单休制纳管)
  public static func parseRepeatWeekdays(_ text: String) -> (weekdays: [Int], label: String)? {
      // 0. 排除型否定星期周期优先解析 (v1.9.68, v1.9.69, v1.9.70 闭环全基准大一统排除引擎)
      if let exclusionResult = parseExclusionRepeatWeekdays(text) {
          return exclusionResult
      }
      return parseBaseRepeatWeekdays(text)
  }

  /// 从除外子句之外的文本中提取基准星期集合（Base Scope），若未指定则默认全周 7 天 (v1.9.70 大一统基准提取引擎)
  private static func extractBaseScopeWeekdays(from text: String) -> Set<Int>? {
      if let base = parseBaseRepeatWeekdays(text) {
          if base.weekdays.isEmpty {
              return Set([1, 2, 3, 4, 5, 6, 7]) // "每天" 表示全周 7 天
          } else {
              return Set(base.weekdays)
          }
      }
      return nil
  }
  ```

- **“每天”负向先行断言边界防护**：
  ```swift
  /// 匹配核心关键词复合星期口语 (v1.9.70 增加每天负向断言防误判为星期天)
  private static let keywordWithExtraDayRegex: NSRegularExpression? = {
      let pattern = #"(工作日|平时|周末|双休)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?!(?:每天|天天|每日|每晚|每早|每晨|每夜|日日))(?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7]|工作日|平时|周末|双休))"#
      return try? NSRegularExpression(pattern: pattern)
  }()
  ```

- **单休制核心语义与规范标签映射**：
  ```swift
  if text.contains("单休") {
      return ([2, 3, 4, 5, 6, 7], "周一至周六")
  }
  ```

### 2.2 macOS 状态栏同频批次任务跨天周期智能消歧与原子批处理
- **`StatusItemController.swift` 同频任务语义识别升维**：
  ```swift
  /// 判定两个计划调度任务是否属于同一时间、同一属性、同一动作值且同一重复规则的同频协同任务 (v1.9.70 升级无序集合比对与周期跨天智能同频判定)
  private static func isSiblingSchedule(_ a: ScheduledAction, _ b: ScheduledAction) -> Bool {
      guard a.attrName == b.attrName else { return false }
      guard a.attrValue == b.attrValue else { return false }
      guard a.repeatsDaily == b.repeatsDaily else { return false }
      guard Set(a.repeatWeekdays) == Set(b.repeatWeekdays) else { return false }
      if a.repeatsDaily || !a.repeatWeekdays.isEmpty {
          let cal = Calendar.current
          let hourA = cal.component(.hour, from: a.fireDate)
          let minA = cal.component(.minute, from: a.fireDate)
          let hourB = cal.component(.hour, from: b.fireDate)
          let minB = cal.component(.minute, from: b.fireDate)
          return hourA == hourB && minA == minB
      } else {
          return abs(a.fireDate.timeIntervalSince(b.fireDate)) <= 5.0
      }
  }
  ```

- **`AppModel.swift` 原子批处理 API**：
  ```swift
  /// 批量取消指定 ID 集合的定时调度任务并原子重置唤醒调度器 (v1.9.70)
  @discardableResult
  public func removeScheduledActions(ids: Set<UUID>) -> Int {
      guard !ids.isEmpty else { return 0 }
      let beforeCount = scheduledActions.count
      scheduledActions.removeAll { ids.contains($0.id) }
      let removed = beforeCount - scheduledActions.count
      if removed > 0 {
          wakeScheduler()
          AppLog.log("已批量取消指定定时调度任务（共 \(removed) 个）")
      }
      return removed
  }

  /// 批量启用/禁用指定 ID 集合的调度任务（返回受影响的任务数）(v1.9.70)
  @discardableResult
  public func setScheduledActionsEnabled(ids: Set<UUID>, enabled: Bool) -> Int {
      guard !ids.isEmpty else { return 0 }
      var changed = 0
      for idx in 0..<scheduledActions.count {
          if ids.contains(scheduledActions[idx].id) && scheduledActions[idx].enabled != enabled {
              scheduledActions[idx].enabled = enabled
              changed += 1
          }
      }
      if changed > 0 {
          AppLog.log("已\(enabled ? "恢复" : "暂停")指定批次定时调度任务（共 \(changed) 个）")
          wakeScheduler()
      }
      return changed
  }
  ```

---

## 3. 验证与测试闭环
- **单元测试断言覆盖**：
  - 在 `VoiceCommandParserTests.swift` 中运行测试，所有断言 100% PASS：
    1. “工作日除了周三每天早上8点开机” -> `[2, 3, 5, 6]`、每周一、二、四、五 08:00:00 ✅
    2. “工作日除周五外每天晚10点关空调” -> `[2, 3, 4, 5]`、周一至周四 22:00:00 ✅
    3. “一三五除了周三每天早8点开机” -> `[2, 6]`、每周一、五 08:00:00 ✅
    4. “二四六除周四外每天早8点开机” -> `[3, 7]`、每周二、六 08:00:00 ✅
    5. “工作日和周六除了周三每天早8点开机” -> `[2, 3, 5, 6, 7]`、每周一、二、四、五、六 08:00:00 ✅
    6. “单休每天早8点开机” -> `[2, 3, 4, 5, 6, 7]`、周一至周六 08:00:00 ✅
    7. “单休除周三外每天早8点开机” -> `[2, 3, 5, 6, 7]`、每周一、二、四、五、六 08:00:00 ✅
    8. “除周三外一三五每天早8点开机” -> `[2, 6]`、每周一、五 08:00:00 ✅
    9. “一三五每天早8点开机除周三外” -> `[2, 6]`、每周一、五 08:00:00 ✅
    10. 原有 23 组限定基准集与全周排除断言（如“除了周末”、“除周日外”、“每天晚10点关机除了周末”、“周末除周日外”）全部 100% 保持兼容通过 ✅
    11. `isSiblingSchedule` 无序比对与跨天钟点判定测试全部通过 ✅
- **本地编译与打包校验**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` 0 警告 0 错误编译通过；
  - `./build_app.sh 1.9.70` 构建成功：
    - `dist/HaierAC.app` (含 `HaierACWidget.appex` 小组件扩展)
    - `dist/HaierAC-v1.9.70-macOS.zip` (大小: 2.8M)
    - SHA256 校验和：`23cab9807cc117e8800e92a30a29aafc7f261451d7da65fe5342ea9144f35f0e`
- **安全敏感数据审查**：
  - 严密审查无任何个人手机号、真实密码、私有 API Key 或敏感隐私数据外泄。
