# Haier AC Mac v1.9.77 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.77`
- **发版主题**：闭环自然语言深宵/子夜/通宵/正午全时相消歧与无钟点独立时相调度引擎、macOS 状态栏全景任务悬浮看板与全屋滤网健康矩阵
- **核心目标与架构演进**：
  1. **自然语言深宵/子夜/通宵/正午全时相消歧与无钟点独立时相调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **深宵/子夜/通宵/入夜时相词群全景闭环**：全面纳管“深宵”、“子夜”、“通宵”、“入夜”时相词，彻底修复以往口语中“子夜12点关机”/“深宵12点关机”因时态遗漏无法被映射为 00:00 午夜、反而被默认保留为 12:00 正午的严重颠倒缺陷；
     - **深宵与黎明后半夜双向精准消歧**：在 `isNocturnal` 夜间夜深判断中深度纳管“深宵”、“子夜”、“通宵”，当小时数在 6~11 时（如“深宵10点开空调”、“子夜11点关空调”）智能识别为夜间晚时段 22:00 / 23:00；而当小时数在 1~5 时（如“深宵1点关空调”、“子夜2点开机”、“通宵1点开空调”），精准保留为 01:00 / 02:00（子夜后半夜），绝不误判为下午 13:00 / 14:00；
     - **无钟点独立时相自然语言调度引擎**：彻底突破以往前置 guard 强依赖“点/时/:”字符的局限，全面支持家庭自然口语中高频的独立时相调度指令（如“午夜关机”、“午夜关空调”、“子夜关空调”、“子夜开机”、“正午开机”、“正午关空调”、“明天午夜关机”、“每周五午夜关机”、“全屋子夜关空调”），自适应映射“午夜/子夜”为 00:00、“正午”为 12:00，并协同周期重复规则无损流转，彻底根除以往因缺失“点”字穿透至即时开关机分支导致当前误关/开空调的严重隐患；
     - **单元测试 100% 覆盖**：在 `VoiceCommandParserTests` 中新增 16 组端到端单元测试用例，覆盖“子夜12点”、“子夜1点”、“子夜11点”、“深宵12点”、“深宵1点”、“深宵10点”、“通宵1点”、“午夜关机”、“午夜关空调”、“子夜关空调”、“子夜开机”、“正午关空调”、“正午开空调”、“明天午夜关机”、“每周五午夜关机”、“全屋子夜关空调”，全部断言 100% PASS。
  2. **macOS 原生状态栏全景任务悬浮看板与全屋滤网健康矩阵 (`StatusItemController.swift`)**：
     - **全屋与单机滤网健康矩阵悬浮看板 (`allDevicesFilterSummaryTooltip`)**：在状态栏顶层“滤网保养与自清洁”菜单项注入原生悬浮感知看板，多设备用户鼠标悬浮即可纵览全屋各台空调的当前洁净度百分比、累计运行机时、建议保养剩余寿命及 56°C 蒸发器高温自清洁保护期标识（✨），单设备用户悬浮直观呈现设备保养指引；
     - **计划调度与快捷倒计时全景悬浮感知**：在状态栏顶层“⏱ 计划调度”菜单项中，悬浮即可穿透掌握全屋生效中任务数、已暂停任务数及纳管设备名单；为“⚡️ 快捷倒计时调度...”、“⏸ 暂停全屋所有定时任务”、“▶️ 恢复全屋所有定时任务”、“🗑 取消全屋所有定时与倒计时”全面补全原生 macOS Tooltip 提示，显著增强状态栏可解释性与交互质感。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下最新的审查报告（`2026-09-24-1426.md`）进行了基线核查：
1. **P1-1 否定意图插字绕过漏洞**：已在既有版本中通过 `negativeActionRegex` 引入 `[^，。！？\s]{0,10}?` 结构化正则跨字符否定判定全面闭环；
2. **P1-2 `cancelSchedules` 区分全屋与定向取消**：已在既有版本中通过 `.cancelSchedulesAll` 与定向 `.cancelSchedules` 拆分解耦闭环；
3. **P2-2 基于 `Set` 的设备集合判定**：已全面采用 `isSuperset(of:)` 与集合比较闭环；
4. **P2-1 历史数据 `totalDeviceMinutes` 与 `totalMinutes` 量纲差异**：在既有版本中对 `estimatedFilterRemainingDays` 进行了量纲自适应平滑加权加固；
5. **本次演进加固**：
   - 彻底修复了“深宵/子夜/通宵/正午”在口语时段解析中因时相词缺漏导致的“子夜12点误为正午12点”、“深宵10点丢失晚间时态”缺陷；
   - 攻克了无显式“点”字时相（如“午夜关机”、“子夜关空调”、“正午开机”）因首行前置 guard 拦截导致直接穿透至即时开关机动作的重大缺陷；
   - 补齐了 macOS 状态栏顶层滤网项、计划调度项与批处理控制项的悬浮全景 Tooltip 看板，提升系统可解释性与原生交互质感。

---

## 3. 关键架构变更与代码实现

### 3.1 自然语言深宵、子夜、通宵与无钟点独立时相调度引擎
- **`VoiceCommandParser.swift` `parseScheduleTime` 逻辑重构**：
  ```swift
  // 必须包含“点”或“时”或者标准时间冒号，或者独立时相词（午夜、子夜、正午），且不是“小时” (v1.9.77)
  guard (normalized.contains("点") || normalized.contains("时") || normalized.contains(":") ||
         normalized.contains("午夜") || normalized.contains("子夜") || normalized.contains("正午")) && !normalized.contains("小时") else {
      return nil
  }

  let hasColloquialEvening = (normalized.range(of: #"晚\s*\d+"#, options: .regularExpression) != nil)
  let isNightMidnight = normalized.contains("晚上") || normalized.contains("今晚") ||
                        normalized.contains("明晚") || normalized.contains("每晚") ||
                        normalized.contains("晚间") || normalized.contains("夜里") ||
                        normalized.contains("半夜") || normalized.contains("午夜") ||
                        normalized.contains("深夜") || normalized.contains("夜间") ||
                        normalized.contains("夜深") || normalized.contains("凌晨") ||
                        normalized.contains("深宵") || normalized.contains("子夜") ||
                        normalized.contains("通宵") || normalized.contains("入夜") ||
                        hasColloquialEvening

  // 3.5 独立无钟点独立时相结构（如“午夜关机” / “子夜关空调” -> 00:00；“正午开机” -> 12:00） (v1.9.77)
  if hour == nil {
      if normalized.contains("午夜") || normalized.contains("子夜") {
          hour = 0
          minute = 0
      } else if normalized.contains("正午") {
          hour = 12
          minute = 0
      }
  }

  // 5. 钟点时段与时态校准 (v1.9.77 闭环深宵/子夜/通宵/正午全时相消歧与无钟点独立时相调度引擎)
  if finalHour == 12 {
      if isNightMidnight {
          // “晚上12点”、“半夜12点”、“午夜12点”、“凌晨12点”、“深夜12点”、“深宵12点”、“子夜12点”均代表午夜 00:00
          finalHour = 0
      }
  } else if finalHour == 0 {
      // 明确的“零点/0点/0时/午夜/子夜”，无论前缀如何，恒定为 00:xx，严禁累加 12
      finalHour = 0
  } else if finalHour > 0 && finalHour < 12 {
      let isNocturnal = normalized.contains("夜里") || normalized.contains("半夜") ||
                        normalized.contains("午夜") || normalized.contains("深夜") ||
                        normalized.contains("夜间") || normalized.contains("夜深") ||
                        normalized.contains("深宵") || normalized.contains("子夜") ||
                        normalized.contains("通宵") || normalized.contains("入夜")
      // ...
      if isNocturnal {
          if finalHour >= 6 {
              finalHour += 12
          }
      }
  }
  ```

### 3.2 macOS 原生状态栏任务悬浮看板与全屋滤网健康矩阵
- **`StatusItemController.swift` 全景 Tooltip 看板注入**：
  ```swift
  /// 生成全屋所有空调滤网运行与健康保养状态全景悬浮感知提示 (v1.9.77)
  private func allDevicesFilterSummaryTooltip() -> String {
      let allDevices = model.allUnifiedDevices
      guard !allDevices.isEmpty else { return "暂无已绑定空调设备" }
      var lines: [String] = []
      lines.append("【全屋空调滤网健康全景】")
      for dev in allDevices {
          let cleanPct = model.filterCleanlinessPercentage(for: dev.id)
          let accMins = model.filterAccumulatedMinutes(for: dev.id)
          let accHours = accMins / 60
          let remHours = max(0, AppModel.filterServiceLifeMinutes - accMins) / 60
          let isProtected = model.isSelfCleaningProtectionActive(for: dev.id)
          let protectTag = isProtected ? " ✨[自清洁保护期]" : ""
          lines.append("• \(dev.name)：洁净度 \(cleanPct)%，累计 \(accHours)h (建议保养剩余约 \(remHours)h)\(protectTag)")
      }
      lines.append("展开子菜单可进行单台或全屋一键滤网重置与深度保养")
      return lines.joined(separator: "\n")
  }
  ```

---

## 4. 自动化测试与验证

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增针对深宵/子夜/通宵与独立时相调度的 16 组端到端单元测试用例：
  - `"子夜12点关机"` -> `00:00` 关机 (PASS)
  - `"子夜1点关空调"` -> `01:00` 关机 (PASS)
  - `"子夜11点关空调"` -> `23:00` 关机 (PASS)
  - `"深宵12点关机"` -> `00:00` 关机 (PASS)
  - `"深宵1点关空调"` -> `01:00` 关机 (PASS)
  - `"深宵10点开空调"` -> `22:00` 开机 (PASS)
  - `"通宵1点开机"` -> `01:00` 开机 (PASS)
  - `"午夜关机"` -> `00:00` 关机 (PASS)
  - `"午夜关空调"` -> `00:00` 关机 (PASS)
  - `"子夜关空调"` -> `00:00` 关机 (PASS)
  - `"子夜开机"` -> `00:00` 开机 (PASS)
  - `"正午关空调"` -> `12:00` 关机 (PASS)
  - `"正午开空调"` -> `12:00` 开机 (PASS)
  - `"明天午夜关机"` -> `明天 00:00` 关机 (PASS)
  - `"每周五午夜关机"` -> `每周五 00:00` 关机 (PASS)
  - `"全屋子夜关空调"` -> `全屋 00:00` 关机 (PASS)
- **编译与构建验证**：
  - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`：编译完成，100% 成功无错误；
  - 执行 `./build_app.sh 1.9.77`：Release 二进制与小组件扩展构建完成，完成 Ad-hoc 签名与 Entitlements 注入，成功生成 `dist/HaierAC.app` 与 `dist/HaierAC-v1.9.77-macOS.zip`。

---

## 5. 发版清单与资产

- **Git Commit & Tag**：`v1.9.77`
- **Release 资产**：`dist/HaierAC-v1.9.77-macOS.zip`
- **文件大小**：`2.8 MB`
- **SHA-256**：`7e558227833fca0371efc07f26cc652e2b93665c55a29a645c15a0371662679c`
- **发布方式**：GitHub Release via `gh release create v1.9.77`
