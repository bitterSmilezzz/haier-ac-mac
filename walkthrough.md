# Haier AC Mac v1.9.74 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.74`
- **发版主题**：闭环自然语言三连续区间与夹心连续离散混合调度引擎、macOS 状态栏同频任务全层级批处理协同与滤网历史机时自适应重构
- **核心目标与架构演进**：
  1. **自然语言三连续区间与夹心连续离散混合大一统调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **三连续区间大一统复合调度 (`triRangeRepeatRegex`)**：新增三连续区间大一统解析引擎，全面攻克自然口语中多段非连续班制与复杂跨度周期（如“周一至周二、周四至周五和周六至周日每天早8点开机”、“周一到周二、周三到周四以及周五到周六每天早8点开机”），精准提取并无损计算并集；
     - **连续区间在先、离散居中、连续在后夹心复合调度 (`rangeWithMultiDaysAndRangeRegex`)**：新增夹心复合解析引擎，彻底解决离散星期居于两个连续区间中间时（如“周一至周三、周五以及周六至周日每天早8点开机”、“周一到周二、周四和周六到周日每天早8点开机”、“周一至周三和周五加周六至周日每天早8点开机”）无法匹配被截断的缺陷，环形区间与离散星期完整融合；
     - **紧凑无分隔离散多星期口语纳管 (`discreteWeekdaysRegex`)**：重构离散星期正则，全面兼容口语省略顿号/空格的紧凑连续星期组合（如“周一周三和周五周日每天早8点开机”、“周一周三周五每天早8点开机”、“周二周四周六每天早8点开机”、“周一周二和周四周五每天早8点开机”），杜绝以往仅能捕获中间子段导致首尾星期词被静默截断丢弃的历史隐患；
     - **单元测试 100% 覆盖**：在 `VoiceCommandParserTests` 中新增 10 组涵盖三连续区间、夹心混合区间及紧凑离散多星期的端到端单元测试用例，全部断言 100% PASS。
  2. **macOS 原生状态栏同频任务全层级批处理协同与公共菜单构建器 (`StatusItemController.swift`)**：
     - **公共单任务管理菜单构建器 (`buildSingleScheduleMenu`)**：重构并收敛状态栏单设备模式、设备子菜单与全局计划调度三处重复的任务管理子菜单构建逻辑，消除 70 余行重复模板代码；
     - **补全多设备子菜单下同频任务一键协同批处理能力**：在多设备模式的设备子菜单（`devSubmenu`）中，同步补齐同频兄弟任务的“⏸ 同步暂停此批任务 (N 台)”与“❌ 同步取消此批任务 (N 台)”，实现单设备视图、设备独立子菜单与全局调度矩阵的全景 100% 对称。
  3. **滤网寿命预测新老历史数据量纲自适应平滑加权 (`AppModel.swift`)**：
     - **历史混合数据日均机时折算自适应**：在 `estimatedFilterRemainingDays` 中，针对早期版本仅存 `totalMinutes` 墙钟时间与新版本存有 `totalDeviceMinutes` 真实设备机时的混合记录，采用量纲自适应平滑加权计算日均机时，杜绝历史墙钟时间错误除以设备数导致的机时严重低估与可用天数虚高。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下最新的审查报告（`2026-09-24-1426.md`）进行了基线核查：
1. **P1-1 否定意图插字绕过漏洞**：已在 `v1.9.36`、`v1.9.40` 与 `v1.9.61` 中通过 `negativeActionRegex` 引入 `[^，。！？\s]{0,10}?` 结构化正则跨字符否定判定全面闭环；
2. **P1-2 `cancelSchedules` 区分全屋与定向取消**：已在 `v1.9.36` 与后续版本中通过 `.cancelSchedulesAll` 与定向 `.cancelSchedules` 拆分解耦闭环；
3. **P2-2 基于 `Set` 的设备集合判定**：已全面采用 `isSuperset(of:)` 与集合比较闭环；
4. **P2-1 历史数据 `totalDeviceMinutes` 与 `totalMinutes` 量纲差异**：在本次 `v1.9.74` 中对 `estimatedFilterRemainingDays` 进行了量纲自适应平滑加权加固，彻底消除多版本数据混合时的估算偏差。

---

## 3. 关键架构变更与代码实现

### 3.1 自然语言三连续区间与夹心连续离散混合调度引擎
- **`VoiceCommandParser.swift` 正则模式扩充**：
  ```swift
  /// 匹配连续区间在先、多个离散星期居中、连续区间在后的夹心复合口语（如“周一至周三、周五以及周六至周日”、“周一到周二、周四和周六到周日”、“周一至周三和周五加周六至周日”） (v1.9.74)
  private static let rangeWithMultiDaysAndRangeRegex: NSRegularExpression? = {
      let pattern = #"(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?!(?:每天|天天|每日|每晚|每早|每晨|每夜|日日))((?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7])[、,，和与及跟以及还有或者或加/／\s]*)+)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])"#
      return try? NSRegularExpression(pattern: pattern)
  }()

  /// 匹配三连续区间大一统复合口语（如“周一至周二、周四至周五和周六至周日”、“周一到周二、周三到周四以及周五到周六”） (v1.9.74)
  private static let triRangeRepeatRegex: NSRegularExpression? = {
      let pattern = #"(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])"#
      return try? NSRegularExpression(pattern: pattern)
  }()

  /// 升级离散多星期组合正则以兼容紧凑无分隔场景 (v1.9.74)
  private static let discreteWeekdaysRegex: NSRegularExpression? = {
      let pattern = #"(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])(?:(?:\s*(?:[、,，和与及跟以及还有或者或加/／]\s*)+(?!(?:每天|天天|每日|每晚|每早|每晨|每夜|日日))(?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?([一二三四五六日天1-7])))|(?:\s*(?:[、,，和与及跟以及还有或者或加/／\s]*)(?!(?:每天|天天|每日|每晚|每早|每晨|每夜|日日))(?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7]))))+"#
      return try? NSRegularExpression(pattern: pattern)
  }()
  ```

- **解析逻辑并集结算**：
  ```swift
  // 0.0 三连续区间大一统复合口语 (v1.9.74)
  if let regex = triRangeRepeatRegex, ... {
      var days = Set(generateWeeklyRange(start: s1Wd, end: e1Wd))
      days.formUnion(generateWeeklyRange(start: s2Wd, end: e2Wd))
      days.formUnion(generateWeeklyRange(start: s3Wd, end: e3Wd))
      let sorted = days.sorted()
      return (sorted, formatWeekdayLabel(from: sorted))
  }

  // 0.05 连续区间在先、多个离散居中、连续在后夹心复合口语 (v1.9.74)
  if let regex = rangeWithMultiDaysAndRangeRegex, ... {
      var days = Set(generateWeeklyRange(start: s1Wd, end: e1Wd))
      days.formUnion(generateWeeklyRange(start: s2Wd, end: e2Wd))
      for ch in multi {
          if let wd = chineseDayCharToWeekday(ch) {
              days.insert(wd)
          }
      }
      let sorted = days.sorted()
      return (sorted, formatWeekdayLabel(from: sorted))
  }
  ```

### 3.2 macOS 原生状态栏同频任务全层级批处理协同
- **`StatusItemController.swift` 公共构建器收敛**：
  ```swift
  private func buildSingleScheduleMenu(action: ScheduledAction, allSchedules: [ScheduledAction], showDevName: String? = nil) -> NSMenu {
      let singleMenu = NSMenu()
      singleMenu.autoenablesItems = false
      // 组装设备归属、下次执行时间、周期重复标签、暂停/恢复、取消
      ...
      // 动态检测同频批次兄弟任务并提供一键协同管理 (v1.9.69, v1.9.70, v1.9.74 补全多设备子菜单全层级对称)
      let siblingActions = allSchedules.filter { StatusItemController.isSiblingSchedule($0, action) }
      if siblingActions.count > 1 {
          singleMenu.addItem(.separator())
          let anySiblingEnabled = siblingActions.contains(where: \.enabled)
          let syncToggleTitle = anySiblingEnabled ? "⏸ 同步暂停此批任务 (\(siblingActions.count) 台)" : "▶️ 同步恢复此批任务 (\(siblingActions.count) 台)"
          let syncToggleItem = NSMenuItem(title: syncToggleTitle, action: #selector(toggleSiblingSchedulesFromMenu(_:)), keyEquivalent: "")
          syncToggleItem.target = self
          syncToggleItem.representedObject = siblingActions.map(\.id.uuidString)
          singleMenu.addItem(syncToggleItem)

          let syncCancelItem = NSMenuItem(title: "❌ 同步取消此批任务 (\(siblingActions.count) 台)", action: #selector(cancelSiblingSchedulesFromMenu(_:)), keyEquivalent: "")
          syncCancelItem.target = self
          syncCancelItem.representedObject = siblingActions.map(\.id.uuidString)
          singleMenu.addItem(syncCancelItem)
      }
      return singleMenu
  }
  ```

### 3.3 滤网寿命预测新老历史数据量纲自适应平滑加权
- **`AppModel.swift` 计算公式加固**：
  ```swift
  let devCount = max(1, allUnifiedDevices.count)
  let totalDevMinsSum = activeRecords.reduce(0.0) { sum, record in
      if record.totalDeviceMinutes > 0 {
          return sum + (Double(record.totalDeviceMinutes) / Double(devCount))
      } else {
          // 老版本历史记录无 totalDeviceMinutes 时，墙钟 totalMinutes 为并发运行基准，不重复除以设备数
          return sum + Double(record.totalMinutes)
      }
  }
  let avgDeviceMins = totalDevMinsSum / Double(activeRecords.count)
  dailyMinutes = max(30.0, avgDeviceMins)
  ```

---

## 4. 验证与测试结果

1. **单元测试与端到端断言**：
   - 编写并执行了涵盖 `v1.9.74` 新增模式的 10 组验证用例，全部验证通过（`10/10 passed`）：
     - `周一至周二、周四至周五和周六至周日每天早8点开机` -> `[1, 2, 3, 5, 6, 7]` "周四至周二"
     - `周一到周二、周三到周四以及周五到周六每天早8点开机` -> `[2, 3, 4, 5, 6, 7]` "周一至周六"
     - `周一至周三、周五以及周六至周日每天早8点开机` -> `[1, 2, 3, 4, 6, 7]` "周五至周三"
     - `周一到周二、周四和周六到周日每天早8点开机` -> `[1, 2, 3, 5, 7]` "每周日、一、二、四、六"
     - `周一至周三和周五加周六至周日每天早8点开机` -> `[1, 2, 3, 4, 6, 7]` "周五至周三"
     - `周一周三和周五周日每天早8点开机` -> `[1, 2, 4, 6]` "每周日、一、三、五"
     - `周一周三周五每天早8点开机` -> `[2, 4, 6]` "每周一、三、五"
     - `周二周四周六每天早8点开机` -> `[3, 5, 7]` "每周二、四、六"
     - `周一周二和周四周五每天早8点开机` -> `[2, 3, 5, 6]` "每周一、二、四、五"
     - `周一周三、周五和周日每天早8点开机` -> `[1, 2, 4, 6]` "每周日、一、三、五"
2. **Swift 编译验证**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 警告 0 错误全量编译成功。
3. **打包与代码签名**：
   - 执行 `./build_app.sh 1.9.74`，产物组装完成：
     - 主程序：`dist/HaierAC.app`（已签入 ad-hoc 签名）
     - 桌面组件扩展：`dist/HaierAC.app/Contents/PlugIns/HaierACWidget.appex`（带沙盒及临时例外签名）
     - 发行包：`dist/HaierAC-v1.9.74-macOS.zip` (2.8MB)

---

## 5. 发版信息与交付清单
- **Git Commit**：`feat & fix: 闭环自然语言三连续区间与夹心连续离散混合调度引擎、macOS 状态栏同频任务全层级批处理协同与滤网历史机时自适应重构 (v1.9.74)`
- **Git Tag**：`v1.9.74`
- **GitHub Release**：`v1.9.74`（附带 `dist/HaierAC-v1.9.74-macOS.zip`）
- **隐私底线检查**：全量代码及文档无任何手机号、Token、真实密码等敏感数据，100% 脱敏合规。
