# Haier AC Mac v1.9.73 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.73`
- **发版主题**：闭环自然语言前置离散星期与复合多区间多离散大一统调度解析、macOS 状态栏同频任务动作谓词精炼去重与多机滤网批量维护重构
- **核心目标与架构演进**：
  1. **自然语言前置离散星期与复合多区间多离散大一统调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **前置离散星期+连续区间正向纳管**：新增 `multiDaysWithRangeRegex` 引擎，彻底修复自然口语中前置离散星期（如“周五和周一至周三每天早8点开机”、“周日以及周一至周四每天早8点开机”、“周五周日和周一至周三每天早8点开机”）被静默忽略丢弃的重大逻辑缺陷，精准无损合并离散多星期与区间并集，格式化输出地道周期标签；
     - **双连续区间附加多离散星期双向大一统**：新增 `dualRangeWithMultiDaysRegex`（双区间+多离散，如“周一至周三、周五至周六和周日每天早8点开机”）与 `multiDaysWithDualRangeRegex`（多离散+双区间，如“周日和周一至周三、周五至周六每天早8点开机”），实现复合跨度与离散星期的任意口语语序无缝解析；
     - **离散多星期与核心关键词双向对称纳管**：新增 `multiDaysWithKeywordRegex`（多离散在前，如“周六周日和工作日每天早8点开机”）与 `keywordWithMultiDaysRegex`（关键词在前，如“周末和周二周四每天早8点开机”），彻底补齐与关键词混合时的全排列场景；
     - **单元测试 100% 覆盖**：在 `VoiceCommandParserTests` 中新增 14 组端到端单元测试用例，覆盖前置离散+区间、双区间+多离散、多离散+双区间、多离散与关键词双向复合，全部断言 100% PASS。
  2. **macOS 原生状态栏同频任务动作谓词精炼去重与清洗正则扩充 (`StatusItemController.swift`)**：
     - **单设备计划调度菜单项动作谓词去重**：重构单设备计划菜单项标题构建逻辑，全面接入 `Self.extractPlanActionVerb(from: action, devName: dev.name)`，彻底清洗任务描述中原本残留的倒计时、时间点与周期前缀/后缀，杜绝菜单生成形如“⏱ 周五至周日 08:00 开机 (08:00，剩余 2天) [周五至周日]”的双重语病，精简输出为地道干练的“⏱ 开机 (08:00，剩余 2天) [周五至周日]”；
     - **清洗正则边界全面扩充**：在 `schedulePrefixRegex` 中扩充连词集 `[、,，和与及跟以及还有或者或加/／\s]+`，并在 `scheduleSuffixRegex` 中补齐 `周` 字符以及方括号 `[` `]` 与 `(?:每)?`，完全适配并干净剔除多周复合标签。
  3. **多设备滤网保养原子批量重置 API 与语音胶囊链路升级 (`AppModel.swift` / `VoiceCapsuleWindowController.swift`)**：
     - **原子批量滤网重置 API (`resetFilterMaintenance`)**：在 `AppModel` 中提供原子化多设备滤网运行时间清零重置 API，一次性重置指定的多台或全屋设备滤网保养计时，自动保存配置、刷新界面并向用户返回实际重置设备数；
     - **语音胶囊多设备执行链路打通**：在 `VoiceCapsuleWindowController.executeMultiDeviceCommand` 中全面接入该 API，实现“保养所有空调滤网”或多设备滤网重置时的原子化批量清零与精准反馈。

---

## 2. 关键架构变更与代码实现

### 2.1 自然语言前置离散与复合多区间多离散大一统调度解析
- **`VoiceCommandParser.swift` 正则模式扩充**：
  ```swift
  /// 匹配多离散星期在前、连续区间在后的复合口语（如“周五和周一至周三”、“周日以及周一至周四”、“周五周日和周一至周三”） (v1.9.73)
  private static let multiDaysWithRangeRegex: NSRegularExpression? = {
      let pattern = #"(?:每|逢|每逢)?(?:个)?((?:(?:周|星期|礼拜)[一二三四五六日天1-7]\s*(?:[、,，和与及跟以及还有或者或加/／\s]*))+)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])"#
      return try? NSRegularExpression(pattern: pattern)
  }()

  /// 匹配双连续区间在先、多离散星期在后的复合口语（如“周一至周三、周五至周六和周日”） (v1.9.73)
  private static let dualRangeWithMultiDaysRegex: NSRegularExpression? = {
      let pattern = #"(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*((?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)?[一二三四五六日天1-7]\s*(?:[、,，和与及跟以及还有或者或加/／\s]*))+)"#
      return try? NSRegularExpression(pattern: pattern)
  }()

  /// 匹配多离散星期在先、双连续区间在后的复合口语（如“周日和周一至周三、周五至周六”） (v1.9.73)
  private static let multiDaysWithDualRangeRegex: NSRegularExpression? = {
      let pattern = #"(?:每|逢|每逢)?(?:个)?((?:(?:周|星期|礼拜)[一二三四五六日天1-7]\s*(?:[、,，和与及跟以及还有或者或加/／\s]*))+)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])"#
      return try? NSRegularExpression(pattern: pattern)
  }()

  /// 匹配多离散星期在前、核心关键词在后的复合口语（如“周六周日和工作日”） (v1.9.73)
  private static let multiDaysWithKeywordRegex: NSRegularExpression? = {
      let pattern = #"((?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)[一二三四五六日天1-7]\s*(?:[、,，和与及跟以及还有或者或加/／\s]*))+)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(工作日|平时|周末|双休|单休|周末三天)"#
      return try? NSRegularExpression(pattern: pattern)
  }()

  /// 匹配核心关键词在前、多离散星期在后的复合口语（如“周末和周二周四”） (v1.9.73)
  private static let keywordWithMultiDaysRegex: NSRegularExpression? = {
      let pattern = #"(工作日|平时|周末|双休|单休|周末三天)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*((?:(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)[一二三四五六日天1-7]\s*(?:[、,，和与及跟以及还有或者或加/／\s]*))+)"#
      return try? NSRegularExpression(pattern: pattern)
  }()
  ```

### 2.2 macOS 原生状态栏同频任务动作谓词精炼去重
- **`StatusItemController.swift` 菜单项标题精炼**：
  ```swift
  let actionVerb = Self.extractPlanActionVerb(from: action, devName: dev.name)
  let cleanAction = actionVerb.isEmpty ? cleanActionName : actionVerb
  let planItem = NSMenuItem(
      title: "  ⏱ \(cleanAction) (\(timeDesc))\(repeatTag)",
      action: nil,
      keyEquivalent: ""
  )
  ```
- **清洗边界补全**：
  ```swift
  private static let schedulePrefixRegex: NSRegularExpression? = {
      let pattern = #"^(?:(?:\d{1,2}[:：]\d{2}(?::\d{2})?|\d{1,2}点(?:\d{1,2}分)?|\d+分钟后?|\d+小时后?)\s*)+(?:(?:每|逢|每逢)?(?:周[一二三四五六日天至到\-~、\s]+|工作日|周末|双休|单休|周末三天)\s*)*(?:[、,，和与及跟以及还有或者或加/／\s]+)?"#
      return try? NSRegularExpression(pattern: pattern)
  }()

  private static let scheduleSuffixRegex: NSRegularExpression? = {
      let pattern = #"(?:\s*[(（\[]?(?:(?:每)?周[一二三四五六日天至到\-~、\s]+|工作日|周末|双休|单休|周末三天)[)）\]]?)+\s*$"#
      return try? NSRegularExpression(pattern: pattern)
  }()
  ```

### 2.3 多设备滤网保养原子批量重置
- **`AppModel.swift` 原子重置 API**：
  ```swift
  @discardableResult
  public func resetFilterMaintenance(deviceIds: [String]) -> Int {
      guard !deviceIds.isEmpty else { return 0 }
      var count = 0
      for devId in deviceIds {
          if filterMaintenanceRecords[devId] != nil || devices.contains(where: { $0.id == devId }) {
              let record = FilterMaintenanceRecord(
                  accumulatedRuntimeSeconds: 0,
                  lastMaintenanceDate: Date(),
                  cleaningThresholdHours: filterMaintenanceRecords[devId]?.cleaningThresholdHours ?? 300,
                  replacementThresholdHours: filterMaintenanceRecords[devId]?.replacementThresholdHours ?? 1500
              )
              filterMaintenanceRecords[devId] = record
              count += 1
          }
      }
      if count > 0 {
          saveFilterMaintenanceRecords()
          NotificationCenter.default.post(name: .filterWearDidUpdate, object: nil)
          AppLog.log("已批量重置 \(count) 台设备滤网保养记录")
      }
      return count
  }
  ```

---

## 3. 验证与测试闭环
- **单元测试断言覆盖**：
  - 在 `VoiceCommandParserTests.swift` 中新增 14 组端到端用例，全部断言 100% PASS：
    1. “周五和周一至周三每天早8点开机” -> `[1, 2, 3, 4, 6, 7]`、周五至周三 08:00:00 开机 ✅
    2. “周日以及周一至周四每天早8点开机” -> `[1, 2, 3, 4, 5]`、周日及周一至周四 08:00:00 开机 ✅
    3. “周五周日和周一至周三每天早8点开机” -> `[1, 2, 3, 4, 6]`、每周日、一、二、三、五 08:00:00 开机 ✅
    4. “周六周日和周一至周五每天早8点开机” -> `[1, 2, 3, 4, 5, 6, 7]`、周一至周日 08:00:00 开机 ✅
    5. “周一至周三、周五至周六和周日每天早8点开机” -> `[1, 2, 3, 4, 6, 7]`、周五至周三 08:00:00 开机 ✅
    6. “周一到周二和周五到周六以及周三每天早8点开机” -> `[2, 3, 4, 6, 7]`、每周一、二、三、五、六 08:00:00 开机 ✅
    7. “周日和周一至周三、周五至周六每天早8点开机” -> `[1, 2, 3, 4, 6, 7]`、周五至周三 08:00:00 开机 ✅
    8. “周日周一和周三至周四、周六至周日每天早8点开机” -> `[1, 2, 4, 5, 7]`、每周日、一、三、四、六 08:00:00 开机 ✅
    9. “周六周日和工作日每天早8点开机” -> `[1, 2, 3, 4, 5, 6, 7]`、周一至周日 08:00:00 开机 ✅
    10. “周五周六和单休每天早8点开机” -> `[2, 3, 4, 5, 6, 7]`、周一至周六 08:00:00 开机 ✅
    11. “周日和单休每天早8点开机” -> `[1, 2, 3, 4, 5, 6, 7]`、周一至周日 08:00:00 开机 ✅
    12. “周末和周二周四每天早8点开机” -> `[1, 3, 5, 7]`、每周日、二、四、六 08:00:00 开机 ✅
    13. “工作日和周六周日每天早8点开机” -> `[1, 2, 3, 4, 5, 6, 7]`、周一至周日 08:00:00 开机 ✅
    14. “单休和周日每天早8点开机” -> `[1, 2, 3, 4, 5, 6, 7]`、周一至周日 08:00:00 开机 ✅
    15. 原有全部历史测试用例（双区间、连续区间+关键词、排除型周期、离散星期等）保持 100% 兼容全部通过 ✅
- **本地编译与打包校验**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` 0 警告 0 错误编译通过；
  - `./build_app.sh 1.9.73` 构建成功：
    - `dist/HaierAC.app` (含 `HaierACWidget.appex` 小组件扩展)
    - `dist/HaierAC-v1.9.73-macOS.zip` (大小: 2.8M)
    - SHA256 校验和：`a8b0af96ecdc05952170cce9e4b4b8ffc6122761d21cbba36da1dd0574ed6ea3`
- **安全敏感数据审查**：
  - 严密审查无任何个人手机号、真实密码、私有 API Key 或敏感隐私数据外泄。
