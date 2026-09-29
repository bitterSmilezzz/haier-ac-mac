# Haier AC Mac v1.9.76 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.76`
- **发版主题**：闭环自然语言深宵/夜里/子夜时段精准消歧、macOS 状态栏全景任务悬浮穿透感知与全设备滤网健康洞察
- **核心目标与架构演进**：
  1. **自然语言深宵/夜里/子夜与黎明自然语言时间精准消歧引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **后半夜自然语言口语精准归并 (01:00 ~ 05:00)**：彻底修复此前“夜里”前缀被粗暴放入全局 +12 小时累加列表的重大逻辑缺陷。在自然口语中，“夜里1点”、“夜里2点”、“夜里3点”、“夜里4点”、“夜里5点”真实意图为后半夜黎明子夜（01:00 ~ 05:00），修复后不再被错误折算为下午 13:00 ~ 17:00；
     - **深夜/夜间深宵时区与晚间对齐 (19:00 ~ 23:00)**：全面纳管“深夜”、“夜间”、“夜深”、“入夜”修饰词，当小时数在 6~11 时（如“深夜10点关机”、“深夜11点关空调”、“夜里10点关机”），智能识别为深宵晚间时段 22:00 / 23:00，彻底根除以往“深夜10点”因缺失时态映射丢失为上午 10:00 的缺陷；
     - **口语“晚上1点/2点”时序纠偏**：针对家庭口语习惯中常见的“晚上1点关空调”、“明晚2点开机”，精准映射为 01:00 / 02:00（子夜后半夜），绝非下午 13:00 / 14:00；
     - **单元测试 100% 覆盖**：在 `VoiceCommandParserTests` 中新增 9 组涵盖“夜里1点”、“夜里2点”、“夜里3点”、“夜里10点”、“深夜10点”、“深夜11点”、“深夜3点”、“晚上1点”、“晚上2点”的端到端时序单元测试，全部断言 100% PASS。
  2. **macOS 原生状态栏全景任务悬浮穿透感知与滤网运行全景洞察 (`StatusItemController.swift`)**：
     - **单设备与同频批次计划任务穿透悬浮感知 (`scheduleItemTooltip`)**：在状态栏计划调度各级菜单（全屋调度矩阵顶层菜单、多设备独立子菜单、单设备计划菜单）中，为每一项计划任务注入丰富的悬浮 Tooltip 穿透感知。若属于同频协同任务，悬浮即刻展示同频批次设备清单（“同频批次任务（共 N 台设备：客厅、主卧...）”及操作指引）；若为单机任务，直观提示目标空调、动作指令与下次精确触发时点；
     - **全设备滤网健康运行全景悬浮洞察 (`filterMaintenanceTooltip`)**：在滤网保养二级子菜单、单设备独立子菜单以及单设备状态栏菜单中，为所有滤网重置选项全面接入结构化悬浮 Tooltip，实时洞察该设备当前洁净度、已累计运行小时数/分钟数、建议保养剩余寿命以及是否处于 56°C 高温自清洁 7 天抑菌保护期；
     - **全屋一键重置操作意图悬浮提示**：为全屋滤网一键重置项增加悬浮提示，清晰说明该操作将一次性归零全屋所有空调运行计时并恢复 100% 洁净度。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下最新的审查报告（`2026-09-24-1426.md`）进行了基线核查：
1. **P1-1 否定意图插字绕过漏洞**：已在既有版本中通过 `negativeActionRegex` 引入 `[^，。！？\s]{0,10}?` 结构化正则跨字符否定判定全面闭环；
2. **P1-2 `cancelSchedules` 区分全屋与定向取消**：已在既有版本中通过 `.cancelSchedulesAll` 与定向 `.cancelSchedules` 拆分解耦闭环；
3. **P2-2 基于 `Set` 的设备集合判定**：已全面采用 `isSuperset(of:)` 与集合比较闭环；
4. **P2-1 历史数据 `totalDeviceMinutes` 与 `totalMinutes` 量纲差异**：在 `v1.9.74` 中对 `estimatedFilterRemainingDays` 进行了量纲自适应平滑加权加固；
5. **本次演进加固**：
   - 攻克了“夜里/深夜/午夜/半夜”在时间倒算与累加判定中，因粗暴累加 12 导致后半夜 01:00~05:00 误判为下午 13:00~17:00 的严重时序逻辑缺陷；
   - 解决了状态栏中计划调度任务与滤网保养项缺乏悬浮洞察提示的问题，为各层级菜单提供了透明详细的同频协同设备名单与滤网运行指标。

---

## 3. 关键架构变更与代码实现

### 3.1 自然语言深宵与黎明时段消歧引擎
- **`VoiceCommandParser.swift` `parseScheduleTime` 逻辑重构**：
  ```swift
  // 5. 钟点时段与时态校准 (v1.9.76 闭环深宵/夜里/半夜/子夜/凌晨自然语言口语时段精准消歧)
  if finalHour == 12 {
      if isNightMidnight {
          // “晚上12点”、“半夜12点”、“午夜12点”、“凌晨12点”、“深夜12点”均代表午夜 00:00
          finalHour = 0
      }
  } else if finalHour == 0 {
      // 明确的“零点/0点/0时”，无论前缀如何，恒定为 00:xx，严禁累加 12
      finalHour = 0
  } else if finalHour > 0 && finalHour < 12 {
      let isNocturnal = normalized.contains("夜里") || normalized.contains("半夜") ||
                        normalized.contains("午夜") || normalized.contains("深夜") ||
                        normalized.contains("夜间") || normalized.contains("夜深") ||
                        normalized.contains("入夜")
      let isEveningStandard = normalized.contains("晚上") || normalized.contains("今晚") ||
                              normalized.contains("明晚") || normalized.contains("每晚") ||
                              normalized.contains("晚间") || hasColloquialEvening

      if isAfternoonPM {
          // 下午、傍晚、午后 1~11 点 -> 13:00 ~ 23:00
          finalHour += 12
      } else if isNoon && finalHour <= 5 {
          // 中午 1 点、2 点等午后时段 -> 13:00 ~ 17:00
          finalHour += 12
      } else if isNocturnal {
          // 深夜/半夜/午夜/夜里/夜间：
          // 6~11 点属于傍晚/入夜/深宵时段（如“夜里7点”=19:00、“夜里8点”=20:00、“半夜10点”=22:00、“深夜11点”=23:00）累加 12
          // 1~5 点属于后半夜/黎明子夜时段（如“夜里1点”=01:00、“半夜2点”=02:00、“深夜3点”=03:00），保持 01:00 ~ 05:00，严禁累加 12 误判为下午 (v1.9.76)
          if finalHour >= 6 {
              finalHour += 12
          }
      } else if isEveningStandard {
          // 晚上/今晚/明晚/每晚/晚间：
          // 6~11 点属于标准晚间（如“晚上8点”=20:00、“晚上11点”=23:00）累加 12
          // 1~5 点口语表达习惯（如“晚上1点睡/明晚2点关机”实际指后半夜 01:00/02:00），保持 01:00 ~ 05:00，绝非下午 13:00/14:00 (v1.9.76)
          if finalHour >= 6 {
              finalHour += 12
          }
      }
  }
  ```

### 3.2 macOS 原生状态栏任务悬浮穿透感知与滤网全景洞察
- **`StatusItemController.swift` Tooltip 注入**：
  ```swift
  /// 生成单台空调滤网运行与健康保养悬浮感知提示 (v1.9.76)
  private func filterMaintenanceTooltip(for deviceId: String, deviceName: String? = nil) -> String {
      let name = deviceName ?? model.allUnifiedDevices.first(where: { $0.id == deviceId })?.name ?? "空调"
      let cleanPct = model.filterCleanlinessPercentage(for: deviceId)
      let accMins = model.filterAccumulatedMinutes(for: deviceId)
      let accHours = accMins / 60
      let remMins = max(0, AppModel.filterServiceLifeMinutes - accMins)
      let remHours = remMins / 60
      let isProtected = model.isSelfCleaningProtectionActive(for: deviceId)

      var lines: [String] = []
      lines.append("设备：\(name)")
      lines.append("滤网健康度：\(cleanPct)%")
      lines.append("累计运行：\(accHours) 小时 (\(accMins) 分钟)")
      lines.append("建议保养剩余：约 \(remHours) 小时")
      if isProtected {
          lines.append("✨ 处于蒸发器自清洁健康保护期（7天内）")
      }
      lines.append("点击重置此设备滤网计时，洁净度恢复 100%")
      return lines.joined(separator: "\n")
  }

  /// 生成计划调度任务悬浮感知提示，穿透展示单设备与同频批次协同设备全景 (v1.9.76)
  private func scheduleItemTooltip(for action: ScheduledAction, devName: String, cleanActionName: String, timeStr: String, remainingDesc: String) -> String {
      let siblingActions = model.scheduledActions.filter { StatusItemController.isSiblingSchedule($0, action) }
      if siblingActions.count > 1 {
          let siblingDevNames = siblingActions.compactMap { act in
              model.allUnifiedDevices.first(where: { $0.id == act.deviceId })?.name
          }
          let devListStr = siblingDevNames.isEmpty ? "\(siblingActions.count) 台设备" : siblingDevNames.joined(separator: "、")
          return "同频批次任务（共 \(siblingActions.count) 台设备：\(devListStr)）\n动作：\(cleanActionName)\n下次触发：\(timeStr)\(remainingDesc)\n展开子菜单可进行单任务管理或同步协同批处理"
      } else {
          return "设备：\(devName)\n动作：\(cleanActionName)\n下次触发：\(timeStr)\(remainingDesc)\n展开子菜单可暂停、恢复或取消该任务"
      }
  }
  ```

---

## 4. 自动化测试与验证

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增针对深宵/夜里/深夜/凌晨与口语晚间后半夜的 9 组端到端单元测试用例：
  - `"夜里1点开机"` -> `01:00` 开机 (PASS)
  - `"夜里2点关空调"` -> `02:00` 关机 (PASS)
  - `"夜里3点关机"` -> `03:00` 关机 (PASS)
  - `"夜里10点关空调"` -> `22:00` 关机 (PASS)
  - `"深夜10点关机"` -> `22:00` 关机 (PASS)
  - `"深夜11点关空调"` -> `23:00` 关机 (PASS)
  - `"深夜3点关机"` -> `03:00` 关机 (PASS)
  - `"晚上1点关空调"` -> `01:00` 关机 (PASS)
  - `"晚上2点开机"` -> `02:00` 开机 (PASS)
- **编译与构建验证**：
  - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`：编译耗时 18.35 秒，100% 成功无错误；
  - 执行 `./build_app.sh 1.9.76`：Release 二进制与小组件扩展构建完成，完成 Ad-hoc 签名与 Entitlements 注入，成功生成 `dist/HaierAC.app` 与 `dist/HaierAC-v1.9.76-macOS.zip`。

---

## 5. 发版清单与资产

- **Git Commit & Tag**：`v1.9.76`
- **Release 资产**：`dist/HaierAC-v1.9.76-macOS.zip`
- **文件大小**：`2.8 MB`
- **SHA-256**：`b06bb21e5b5ca6616acae153af048fff596522d5a17abd2902ae984c71ac6e62`
- **发布方式**：GitHub Release via `gh release create v1.9.76`
