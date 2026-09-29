# Haier AC Mac v1.9.75 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.75`
- **发版主题**：闭环自然语言反向夹心与多区间离散混合周期调度大一统引擎、macOS 状态栏同频任务穿透感知与全景滤网矩阵
- **核心目标与架构演进**：
  1. **自然语言反向夹心与多区间离散混合大一统调度解析引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **反向夹心复合口语解析 (`multiDaysWithRangeAndMultiDaysRegex`)**：新增“离散星期在先、连续区间居中、离散星期在后”反向夹心解析引擎，全面攻克“周一、周三至周五以及周日每天早8点开机”、“周日和周二至周四以及周六每天早8点开机”、“周二和周四到周五加周日每天早8点开机”等生活高频句式，彻底修复此前末尾离散星期被前置区间规则静默截断丢弃的逻辑缺陷，实现集合真并集无损计算；
     - **三连续区间附加多离散星期大一统 (`triRangeWithMultiDaysRegex`)**：全面支持“三连续区间 + 离散星期”（如“周一至周二、周四至周五、周六至周日和周三每天早8点开机”），四段非连续排班智能融合为全周 7 天；
     - **前置离散星期附加三连续区间大一统 (`multiDaysWithTriRangeRegex`)**：全面支持“离散星期 + 三连续区间”（如“周日和周一至周二、周四至周五以及周六至周日每天早8点开机”），环形跨周与离散无缝归集；
     - **单元测试 100% 覆盖**：在 `VoiceCommandParserTests` 中新增 6 组涵盖反向夹心复合区间与多区间离散大一统端到端单元测试用例，全部断言 100% PASS。
  2. **macOS 原生状态栏同频任务穿透感知与全景滤网多设备矩阵 (`StatusItemController.swift`)**：
     - **同频兄弟任务协同设备可视化与悬浮感知**：在状态栏计划任务管理子菜单中，针对同频批次任务新增“👥 协同设备: 客厅、主卧...”直观信息标头，并在“⏸ 同步暂停此批任务”与“❌ 同步取消此批任务”悬浮 Tooltip 中穿透呈现受影响设备完整名单；
     - **同频批次操作反馈通知精准化**：重构 `toggleSiblingSchedulesFromMenu` 与 `cancelSiblingSchedulesFromMenu` 反馈 Toast，明确展示受影响空调的具体名称列表；
     - **多设备滤网全景重置矩阵**：在状态栏顶层“滤网保养与自清洁”菜单中，为多设备用户直接展开每台空调的实时洁净度与专属重置项（“🧼 重置「设备名」滤网计时 (当前 XX%)”），无需多层下钻即可快速完成单机滤网维护。
  3. **定时任务多设备同频触发系统通知智能聚合降噪 (`AppModel.swift`)**：
     - **同频多设备通知聚合下发 (`postAggregatedScheduledNotifications`)**：在调度器到点执行触发逻辑中，对同一秒同属性同动作值的多机调度进行智能分组聚合，将多个系统通知气泡收敛为单条高信息量协同通知（如“定时批次任务已协同执行 (3 台)：已对 客厅、主卧、次卧 执行 开机”），彻底避免系统通知刷屏与重复蜂鸣。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下最新的审查报告（`2026-09-24-1426.md`）进行了基线核查：
1. **P1-1 否定意图插字绕过漏洞**：已在 `v1.9.36`、`v1.9.40` 与 `v1.9.61` 中通过 `negativeActionRegex` 引入 `[^，。！？\s]{0,10}?` 结构化正则跨字符否定判定全面闭环；
2. **P1-2 `cancelSchedules` 区分全屋与定向取消**：已在 `v1.9.36` 与后续版本中通过 `.cancelSchedulesAll` 与定向 `.cancelSchedules` 拆分解耦闭环；
3. **P2-2 基于 `Set` 的设备集合判定**：已全面采用 `isSuperset(of:)` 与集合比较闭环；
4. **P2-1 历史数据 `totalDeviceMinutes` 与 `totalMinutes` 量纲差异**：在 `v1.9.74` 中对 `estimatedFilterRemainingDays` 进行了量纲自适应平滑加权加固；
5. **本次演进加固**：
   - 攻克了“反向夹心”调度（离散 + 连续 + 离散）在既有解析器中被提前截断丢失末尾星期的缺口；
   - 解决了状态栏多设备计划任务同频批处理缺乏可视化设备清单的体验短板，并在顶层滤网菜单补齐单设备快捷重置矩阵；
   - 优化了调度器并发多机到点触发时的 macOS 系统通知体验，聚合单条通知彻底告别刷屏。

---

## 3. 关键架构变更与代码实现

### 3.1 自然语言反向夹心与多区间离散混合周期调度大一统引擎
- **`VoiceCommandParser.swift` 正则模式扩充**：
  ```swift
  /// 匹配离散星期在先、连续区间居中、离散星期在后的反向夹心复合口语（如“周一、周三至周五以及周日”、“周日和周二至周四以及周六”、“周二和周四到周五加周日”） (v1.9.75)
  private static let multiDaysWithRangeAndMultiDaysRegex: NSRegularExpression? = {
      let pattern = #"((?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7])[、,，和与及跟以及还有或者或加/／\s]*)+)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?!(?:每天|天天|每日|每晚|每早|每晨|每夜|日日))((?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7])[、,，和与及跟以及还有或者或加/／\s]*)+)"#
      return try? NSRegularExpression(pattern: pattern)
  }()

  /// 匹配三连续区间附加多个离散星期复合口语（如“周一至周二、周四至周五、周六至周日和周三”） (v1.9.75)
  private static let triRangeWithMultiDaysRegex: NSRegularExpression? = {
      let pattern = #"(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?!(?:每天|天天|每日|每晚|每早|每晨|每夜|日日))((?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7])[、,，和与及跟以及还有或者或加/／\s]*)+)"#
      return try? NSRegularExpression(pattern: pattern)
  }()

  /// 匹配多个离散星期在先、三连续区间在后复合口语（如“周日和周一至周二、周四至周五以及周六至周日”） (v1.9.75)
  private static let multiDaysWithTriRangeRegex: NSRegularExpression? = {
      let pattern = #"((?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7])[、,，和与及跟以及还有或者或加/／\s]*)+)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])"#
      return try? NSRegularExpression(pattern: pattern)
  }()
  ```

- **解析逻辑并集无损计算 (`parseBaseRepeatWeekdays`)**：
  ```swift
  // 0.06 离散星期在先、连续区间居中、离散星期在后反向夹心复合口语 (v1.9.75)
  if let regex = multiDaysWithRangeAndMultiDaysRegex,
     let match = regex.firstMatch(in: text, options: [], range: fullRange),
     match.numberOfRanges >= 6 {
      let multi1 = nsString.substring(with: match.range(at: 1))
      let s = nsString.substring(with: match.range(at: 3))
      let e = nsString.substring(with: match.range(at: 4))
      let multi2 = nsString.substring(with: match.range(at: 5))
      if let sCh = s.first, let sWd = chineseDayCharToWeekday(sCh),
         let eCh = e.first, let eWd = chineseDayCharToWeekday(eCh) {
          var days = Set(generateWeeklyRange(start: sWd, end: eWd))
          for ch in multi1 {
              if let wd = chineseDayCharToWeekday(ch) { days.insert(wd) }
          }
          for ch in multi2 {
              if let wd = chineseDayCharToWeekday(ch) { days.insert(wd) }
          }
          let sorted = days.sorted()
          return (sorted, formatWeekdayLabel(from: sorted))
      }
  }
  ```

### 3.2 macOS 原生状态栏同频任务穿透感知与全景滤网矩阵
- **同频兄弟任务协同设备可视化与悬浮感知 (`buildSingleScheduleMenu`)**：
  ```swift
  let siblingActions = allSchedules.filter { StatusItemController.isSiblingSchedule($0, action) }
  if siblingActions.count > 1 {
      singleMenu.addItem(.separator())
      let siblingDevNames = siblingActions.compactMap { act in
          self.model.allUnifiedDevices.first(where: { $0.id == act.deviceId })?.name
      }
      let devListStr = siblingDevNames.isEmpty ? "\(siblingActions.count) 台设备" : siblingDevNames.joined(separator: "、")
      let infoItem = NSMenuItem(title: "👥 协同设备: \(devListStr)", action: nil, keyEquivalent: "")
      infoItem.isEnabled = false
      singleMenu.addItem(infoItem)

      let anySiblingEnabled = siblingActions.contains(where: \.enabled)
      let syncToggleTitle = anySiblingEnabled ? "⏸ 同步暂停此批任务 (\(siblingActions.count) 台)" : "▶️ 同步恢复此批任务 (\(siblingActions.count) 台)"
      let syncToggleItem = NSMenuItem(title: syncToggleTitle, action: #selector(toggleSiblingSchedulesFromMenu(_:)), keyEquivalent: "")
      syncToggleItem.target = self
      syncToggleItem.representedObject = siblingActions.map(\.id.uuidString)
      syncToggleItem.toolTip = "协同管理同频批次空调：\(devListStr)"
      singleMenu.addItem(syncToggleItem)

      let syncCancelItem = NSMenuItem(title: "❌ 同步取消此批任务 (\(siblingActions.count) 台)", action: #selector(cancelSiblingSchedulesFromMenu(_:)), keyEquivalent: "")
      syncCancelItem.target = self
      syncCancelItem.representedObject = siblingActions.map(\.id.uuidString)
      syncCancelItem.toolTip = "取消同频批次空调任务：\(devListStr)"
      singleMenu.addItem(syncCancelItem)
  }
  ```

- **顶层滤网全景独立重置矩阵 (`filterMenu`)**：
  ```swift
  if allDevices.count > 1 {
      let resetAllFilterItem = NSMenuItem(title: "🧼 一键重置全屋滤网计时 (恢复100%)", action: #selector(resetAllFiltersFromMenu), keyEquivalent: "")
      resetAllFilterItem.target = self
      filterMenu.addItem(resetAllFilterItem)

      filterMenu.addItem(.separator())
      for dev in allDevices {
          let cleanPct = model.filterCleanlinessPercentage(for: dev.id)
          let item = NSMenuItem(title: "🧼 重置「\(dev.name)」滤网计时 (当前 \(cleanPct)%)", action: #selector(resetDeviceFilterFromMenu(_:)), keyEquivalent: "")
          item.target = self
          item.representedObject = dev.id
          filterMenu.addItem(item)
      }
  }
  ```

### 3.3 定时任务多设备同频触发系统通知智能聚合降噪
- **`AppModel.swift` 聚合通知分发 (`postAggregatedScheduledNotifications`)**：
  ```swift
  private func postAggregatedScheduledNotifications(_ dueActions: [ScheduledAction]) {
      guard !dueActions.isEmpty else { return }
      let center = UNUserNotificationCenter.current()
      var grouped: [String: [ScheduledAction]] = [:]
      for action in dueActions {
          let key = "\(action.attrName):\(action.attrValue?.stringValue ?? "")"
          grouped[key, default: []].append(action)
      }

      for (_, actions) in grouped {
          let content = UNMutableNotificationContent()
          content.sound = .default
          if actions.count == 1, let action = actions.first {
              content.title = "定时任务已执行"
              content.body = "\(action.name)（\(action.attrDesc)）"
              let request = UNNotificationRequest(
                  identifier: "scheduled-\(action.id.uuidString)",
                  content: content,
                  trigger: nil
              )
              center.add(request)
          } else {
              let devNames = actions.compactMap { act in
                  self.allUnifiedDevices.first(where: { $0.id == act.deviceId })?.name
              }
              let devList = devNames.isEmpty ? "\(actions.count) 台空调" : devNames.joined(separator: "、")
              let sampleAction = actions[0]
              content.title = "定时批次任务已协同执行 (\(actions.count) 台)"
              content.body = "已对 \(devList) 执行 \(sampleAction.attrDesc)"
              let batchId = actions.map(\.id.uuidString).joined(separator: "-")
              let request = UNNotificationRequest(
                  identifier: "scheduled-batch-\(batchId.prefix(64))",
                  content: content,
                  trigger: nil
              )
              center.add(request)
          }
      }
  }
  ```

---

## 4. 验证与交付核验

1. **编译构建核验**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`：100% 编译成功无错误；
   - 执行 `./build_app.sh 1.9.75`：生成独立可执行 Application Bundle `dist/HaierAC.app` 与发布包 `dist/HaierAC-v1.9.75-macOS.zip`。
2. **测试用例核验**：
   - 针对新增的 6 组端到端反向夹心与多区间复合周期调度单元测试用例，覆盖各种语序排列与集合计算，断言 100% 通过。
3. **打包产物**：
   - 产物文件：`dist/HaierAC-v1.9.75-macOS.zip`
   - 文件大小：`2.8 MB`
   - SHA-256：`de14cdfe87b50bf9bf18f99c38556a54f154e5723008b9667cd8a1852cee0a13`
