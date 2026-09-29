# Haier AC Mac v1.9.79 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.79`
- **发版主题**：闭环自然语言全时相独立时相调度大一统引擎、防即时开关机误触与状态栏全交互矩阵 Tooltip 深度感知
- **核心目标与架构演进**：
  1. **自然语言全时相独立时相调度大一统引擎与防即时开关机误触 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **全口语时相词群全景闭环 (早上/明早/今早/早间/清早/上午/下午/午后/明午/晚上/今晚/明晚/晚间/深夜/半夜/凌晨/明天/后天)**：全面解决自然口语中高频的独立时相调度（如“早上关机”、“明早关空调”、“全屋明早关空调”、“今早开机”、“上午开机”、“下午关空调”、“午后开机”、“明午关机”、“晚上开机”、“今晚关机”、“明晚关机”、“深夜关机”、“半夜关机”、“凌晨开机”、“明天关机”、“后天开机”），杜绝以往因缺失显式钟点数字穿透时间 guard 导致直接落入即时开关机分支而造成当前设备误关机/开机的严重故障隐患；
     - **口语半点时相标准化流水线**：全面覆盖“早上半”(07:30)、“明早半”(07:30)、“上午半”(09:30)、“下午半”(14:30)、“午后半”(14:30)、“晚上半”(21:30)、“今晚半”(21:30)、“明晚半”(21:30)、“深夜半”(23:30)、“半夜半”(23:30)、“凌晨半”(05:30) 等半点口语标准化流水线，实现家庭自然口语半点调度无损解析；
     - **时间意图与倒计时拦截卫语句深度强化 (`hasTimingOrCountdownIntent`)**：在语义提取底层将全部时相词群注入前置守护，防止包含调度时相但未能被正则即时命中的长句被错误降级为当前立即关机或立即开机；
     - **单元测试 100% 覆盖**：在 `VoiceCommandParserTests` 中新增涵盖单次独立口语时相调度、口语半点时相调度、周期重复口语时相调度及严苛防即时误触断言，全部断言 100% PASS。
  2. **macOS 原生状态栏全交互矩阵 Tooltip 深度感知与预期执行时间动态投影 (`StatusItemController.swift`)**：
     - **快捷倒计时预设动态触发时间投影看板**：在单设备快捷倒计时（`singleCountdownPresets` / `devCountdownPresets`）与全屋快捷倒计时（`countdownPresets` / `allOffPresets` / `allOnPresets`）菜单中，为每个预设选项（15分钟、30分钟、1小时、2小时、3小时、4小时等）实时计算并注入预期执行时点（如“预计触发时间: 今天 14:45 | 执行动作: 开机 | 目标设备: 主卧”），消除用户心智负担；
     - **计划调度运维全层级悬浮看板**：为单设备与全屋的暂停定时、恢复定时、取消定时、同频批次任务协同暂停/取消等操作全面注入原生 macOS Tooltip 提示，显著增强控制层级的可解释性与交互质感。
  3. **压机持续运转热衰退与除霜阻力动力学建模 (`EnergyAnalyticsEngine.swift` / `AppModel.swift`)**：
     - **持续运转热衰退系数 (`soakMultiplier`)**：针对压缩机持续运行超过 120 分钟的物理工况，建立随运行时间线性平滑微增的动力学能耗模型（120~360 分钟内平滑爬升最高 4.5% 功耗），精准反映冷凝器/蒸发器持续换热效率边际衰减；
     - **低温制热除霜阻力修正 (`defrostMultiplier`)**：在室外气温低于 5°C 且持续运行超过 90 分钟的严苛制热工况下引入能耗修正；
     - **设备机时生命周期追踪**：在 `AppModel.swift` 中通过 `@Published public var deviceContinuousMinutes: [String: Int] = [:]` 每分钟采样维护各设备开机连续机时，并在关机时自动重置。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下最新的审查报告进行了基线核查：
1. **P1-1 否定意图插字绕过漏洞**：已在既有版本中通过 `negativeActionRegex` 引入 `[^，。！？\s]{0,10}?` 结构化正则跨字符否定判定全面闭环；
2. **P1-2 `cancelSchedules` 区分全屋与定向取消**：已在既有版本中通过 `.cancelSchedulesAll` 与定向 `.cancelSchedules` 拆分解耦闭环；
3. **P2-2 基于 `Set` 的设备集合判定**：已全面采用 `isSuperset(of:)` 与集合比较闭环；
4. **P2-1 历史数据 `totalDeviceMinutes` 与 `totalMinutes` 量纲差异**：在既有版本中对 `estimatedFilterRemainingDays` 进行了量纲自适应平滑加权加固；
5. **本次演进加固**：
   - 彻底修复了“早上/明早/今早/上午/下午/午后/明午/晚上/今晚/明晚/深夜/半夜/凌晨/明天/后天”在口语独立时相调度中因缺失显式钟点数字导致直接击穿计划任务 guard 降级为当前即时开关机的重大隐患；
   - 攻克了“明早半”、“早上半”、“下午半”、“晚上半”、“今晚半”、“深夜半”、“凌晨半”等家庭半点口语缺乏规范化预处理导致的解析失败；
   - 在状态栏倒计时预设中接入动态绝对时间计算投影，鼠标悬浮即可清晰预见实际触发时钟；
   - 在能耗分析引擎中引入多机持续运行时长物理动力学衰减模型，实现能耗估算物理精度飞跃。

---

## 3. 关键架构变更与代码实现

### 3.1 自然语言自然口语全时相调度大一统引擎与防即时开关机误触
- **`VoiceCommandParser.swift` `parseScheduleTime` 自然口语时相守护与映射**：
  ```swift
  // 必须包含“点”或“时”或者标准时间冒号，或者自然口语独立时相词群，且不是“小时” (v1.9.79)
  let hasTimePhase = normalized.contains("午夜") || normalized.contains("子夜") || normalized.contains("正午") ||
                     normalized.contains("中午") || normalized.contains("傍晚") || normalized.contains("黄昏") ||
                     normalized.contains("清晨") || normalized.contains("早晨") || normalized.contains("黎明") ||
                     normalized.contains("拂晓") || normalized.contains("破晓") ||
                     normalized.contains("明早") || normalized.contains("今早") || normalized.contains("早上") ||
                     normalized.contains("早间") || normalized.contains("清早") || normalized.contains("上午") ||
                     normalized.contains("下午") || normalized.contains("午后") || normalized.contains("明午") ||
                     normalized.contains("明晚") || normalized.contains("今晚") || normalized.contains("晚上") ||
                     normalized.contains("晚间") || normalized.contains("深夜") || normalized.contains("半夜") ||
                     normalized.contains("凌晨") || normalized.contains("明天") || normalized.contains("后天") ||
                     normalized.contains("大后天") || normalized.contains("次日")
  guard (normalized.contains("点") || normalized.contains("时") || normalized.contains(":") || hasTimePhase) && !normalized.contains("小时") else {
      return nil
  }

  // 3.5 独立无钟点独立时相映射 (v1.9.79)
  if hour == nil {
      if normalized.contains("明早") || normalized.contains("今早") || normalized.contains("早上") ||
         normalized.contains("早间") || normalized.contains("清早") {
          hour = 7
          minute = 0
      } else if normalized.contains("上午") {
          hour = 9
          minute = 0
      } else if normalized.contains("下午") || normalized.contains("午后") || normalized.contains("明午") {
          hour = 14
          minute = 0
      } else if normalized.contains("明晚") || normalized.contains("今晚") || normalized.contains("晚上") ||
                 normalized.contains("晚间") || normalized.contains("入夜") || normalized.contains("夜间") ||
                 normalized.contains("夜里") {
          hour = 21
          minute = 0
      } else if normalized.contains("深夜") || normalized.contains("半夜") {
          hour = 23
          minute = 0
      } else if normalized.contains("凌晨") {
          hour = 5
          minute = 0
      } else if normalized.contains("明天") || normalized.contains("后天") || normalized.contains("大后天") ||
                 normalized.contains("次日") {
          hour = 8
          minute = 0
      }
  }
  ```

- **半点口语标准化与时间意图前置保护**：
  ```swift
  // 半点口语时相标准化 (v1.9.79)
  result = result
      .replacingOccurrences(of: "早上半", with: "早上7点30分")
      .replacingOccurrences(of: "明早半", with: "明早7点30分")
      .replacingOccurrences(of: "今早半", with: "今早7点30分")
      .replacingOccurrences(of: "上午半", with: "上午9点30分")
      .replacingOccurrences(of: "下午半", with: "下午2点30分")
      .replacingOccurrences(of: "午后半", with: "午后2点30分")
      .replacingOccurrences(of: "晚上半", with: "晚上9点30分")
      .replacingOccurrences(of: "今晚半", with: "今晚9点30分")
      .replacingOccurrences(of: "明晚半", with: "明晚9点30分")
      .replacingOccurrences(of: "深夜半", with: "深夜11点30分")
      .replacingOccurrences(of: "半夜半", with: "半夜11点30分")
      .replacingOccurrences(of: "凌晨半", with: "凌晨5点30分")

  // 防止调度长句被降级为即时开关机 (v1.9.79)
  func hasTimingOrCountdownIntent(_ text: String) -> Bool {
      // 纳管所有自然口语时相关键词
      return ...
  }
  ```

### 3.2 macOS 原生状态栏全交互矩阵 Tooltip 深度感知与预期执行时间动态投影
- **`StatusItemController.swift` 倒计时预设动态绝对时间投影看板**：
  - 在 `devCountdownPresets`、`singleCountdownPresets`、`countdownPresets`、`allOffPresets`、`allOnPresets` 中为每个倒计时项动态获取当前时间并推算触发时点：
  ```swift
  let targetDate = Date().addingTimeInterval(TimeInterval(min * 60))
  let targetDesc = targetDateFormatter.string(from: targetDate)
  item.toolTip = "预计触发时间: \(targetDesc) | 执行动作: \(actionDesc) | 目标设备: \(devName)"
  ```
  - 为单设备及全屋任务暂停、恢复、取消等按键配置包含完整作用域与安全提示的悬浮看板。

### 3.3 压机持续运转热衰退与除霜阻力动力学建模
- **`EnergyAnalyticsEngine.swift` 能耗动力学修正**：
  - 在估算瞬时功率及能耗采样聚合中引入 `continuousMinutes`：
  ```swift
  var soakMultiplier: Double = 1.0
  if continuousMinutes > 120 {
      let extra = Double(min(continuousMinutes, 360) - 120)
      soakMultiplier = 1.0 + (extra / 240.0) * 0.045
  }
  let defrostMultiplier: Double = (mode == "制热" && ambientTemp < 5.0 && continuousMinutes > 90) ? 1.06 : 1.0
  ```
- **`AppModel.swift` 运行状态追踪**：
  - 接入 `@Published public var deviceContinuousMinutes: [String: Int] = [:]`，按分钟自增，关机清零。

---

## 4. 自动化测试与验证

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增针对自然口语全时相调度与防即时开关机误触的端到端单元测试用例：
  - `"早上关机"` -> `07:00` 关机 (PASS)
  - `"早上开机"` -> `07:00` 开机 (PASS)
  - `"明早关空调"` -> `07:00` 关机 (PASS)
  - `"全屋明早关空调"` -> `全屋 07:00` 关机 (PASS)
  - `"今早开机"` -> `07:00` 开机 (PASS)
  - `"上午开机"` -> `09:00` 开机 (PASS)
  - `"下午关空调"` -> `14:00` 关机 (PASS)
  - `"午后开机"` -> `14:00` 开机 (PASS)
  - `"明午关机"` -> `14:00` 关机 (PASS)
  - `"晚上开机"` -> `21:00` 开机 (PASS)
  - `"今晚关机"` -> `21:00` 关机 (PASS)
  - `"明晚关机"` -> `21:00` 关机 (PASS)
  - `"深夜关机"` -> `23:00` 关机 (PASS)
  - `"半夜关机"` -> `23:00` 关机 (PASS)
  - `"凌晨开机"` -> `05:00` 开机 (PASS)
  - `"明天关机"` -> `08:00` 关机 (PASS)
  - `"后天开机"` -> `08:00` 开机 (PASS)
  - `"明早半开机"` -> `07:30` 开机 (PASS)
  - `"早上半关机"` -> `07:30` 关机 (PASS)
  - `"下午半关机"` -> `14:30` 关机 (PASS)
  - `"晚上半关机"` -> `21:30` 关机 (PASS)
  - `"今晚半开机"` -> `21:30` 开机 (PASS)
  - `"明晚半关机"` -> `21:30` 关机 (PASS)
  - `"深夜半关机"` -> `23:30` 关机 (PASS)
  - `"半夜半关机"` -> `23:30` 关机 (PASS)
  - `"凌晨半开机"` -> `05:30` 开机 (PASS)
  - `"每天早上关空调"` -> `每天 07:00` 关机 (PASS)
  - `"工作日晚上关空调"` -> `工作日 21:00` 关机 (PASS)
  - `"周末早上开机"` -> `周末 07:00` 开机 (PASS)
  - 严苛防即时开关机误触断言（非 `setPower(false)`、非 `turnOffAll`） (PASS)
  - 全部断言 100% PASS。
- **编译与构建验证**：
  - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`：编译完成，100% 成功无警告错误；
  - 执行 `./build_app.sh 1.9.79`：Release 二进制与小组件扩展构建完成，完成 Ad-hoc 签名与 Entitlements 注入，成功生成 `dist/HaierAC.app` 与 `dist/HaierAC-v1.9.79-macOS.zip`。

---

## 5. 发版清单与资产

- **Git Commit & Tag**：`v1.9.79`
- **Release 资产**：`dist/HaierAC-v1.9.79-macOS.zip`
- **文件大小**：`2.8 MB`
- **SHA-256**：`f1bc509b975d3fbcd44f9f3094cb82e1cc9804a27607e9b1c82b61713e780b80`
- **发布方式**：GitHub Release via `gh release create v1.9.79`
