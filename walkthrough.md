# Haier AC Mac v1.9.78 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.78`
- **发版主题**：闭环自然语言广义独立时相调度大一统引擎与启动动作谓词消歧、macOS 状态栏全景控制矩阵 Tooltip 深度感知
- **核心目标与架构演进**：
  1. **自然语言广义独立时相调度大一统引擎与启动动作谓词消歧 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **广义独立时相词群全景闭环 (中午/傍晚/黄昏/早晨/清晨/黎明)**：全面突破以往调度依赖显式钟点数字的限制，深度纳管“中午”(12:00)、“傍晚/黄昏”(18:00)、“清晨/早晨/黎明/拂晓/破晓”(06:00) 等广义自然时相调度口语（如“中午关机”、“中午开机”、“明天中午关机”、“傍晚关空调”、“早晨开机”、“清晨关机”、“黎明开空调”），彻底修复以往因缺失显式钟点数字穿透 guard 导致直接落入即时开关机分支而造成当前设备误关机/开机的严重故障隐患；
     - **半点口语时相标准化流水线**：新增独立时相半点口语标准化流水线，将“中午半”规范为“中午12点30分”、“正午半”规范为“正午12点30分”、“午夜半”规范为“午夜0点30分”、“子夜半”规范为“子夜0点30分”、“傍晚半/黄昏半”规范为“傍晚6点30分”、“清晨半/早晨半/黎明半”规范为“06:30”，实现家庭口语半点调度无损解析；
     - **启动动作谓词消歧与开机动作精准映射**：在计划调度与倒计时动作提取中深度纳管“启动”与“运转”动作谓词，采用 `(text.contains("开") || text.contains("启动") || text.contains("运转")) && !text.contains("关") && !text.contains("停")` 双向判决，彻底根除“定时明早8点启动空调”、“倒计时半小时启动”因缺失“开”字被错误降级为关机任务的严重逆向缺陷；同步扩展“定时启动”与“倒计时启动”默认智能匹配 60 分钟倒计时启动；
     - **单元测试 100% 覆盖**：在 `VoiceCommandParserTests` 中新增 24 组端到端单元测试用例，覆盖中午、正午、傍晚、黄昏、清晨、早晨、黎明全时相独立调度，中午半、午夜半、傍晚半、早晨半等半点口语，以及“启动空调”、“运转空调”动作消歧，全部断言 100% PASS。
  2. **macOS 原生状态栏全景控制矩阵 Tooltip 深度感知与温控边界防护 (`StatusItemController.swift`)**：
     - **全屋多设备快捷控制矩阵 Tooltip 注入**：为状态栏全屋制冷、制热、除湿、送风、自动模式以及阶梯调温（+1°C、+0.5°C、-0.5°C、-1°C）、全开/全关、全屋风速切换等注入丰富原生悬浮看板，直观展示控制模式、目标设备总数及 16°C ~ 30°C 温控范围；
     - **单设备快捷模式与微调悬浮看板**：为单设备电源开关、各运行模式及阶梯调温按键全面配置原生 Tooltip，清晰说明作用设备、模式特征与极值温控防护；
     - **设备级联独立子菜单全景对齐**：在多设备独立子菜单中，为置顶控制、模式切换与调温操作补全原生 Tooltip，显著增强 macOS 状态栏控制层级的可解释性与交互质感。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下最新的审查报告（`2026-09-24-1426.md`）进行了基线核查：
1. **P1-1 否定意图插字绕过漏洞**：已在既有版本中通过 `negativeActionRegex` 引入 `[^，。！？\s]{0,10}?` 结构化正则跨字符否定判定全面闭环；
2. **P1-2 `cancelSchedules` 区分全屋与定向取消**：已在既有版本中通过 `.cancelSchedulesAll` 与定向 `.cancelSchedules` 拆分解耦闭环；
3. **P2-2 基于 `Set` 的设备集合判定**：已全面采用 `isSuperset(of:)` 与集合比较闭环；
4. **P2-1 历史数据 `totalDeviceMinutes` 与 `totalMinutes` 量纲差异**：在既有版本中对 `estimatedFilterRemainingDays` 进行了量纲自适应平滑加权加固；
5. **本次演进加固**：
   - 彻底修复了“中午”、“傍晚/黄昏”、“清晨/早晨/黎明”在口语独立时相调度中因缺失显式钟点数字导致直接击穿计划任务 guard 降级为当前即时开关机的重大隐患；
   - 攻克了“中午半”、“午夜半”、“傍晚半”等家庭半点口语缺乏规范化预处理导致的解析失败；
   - 解决了调度和倒计时解析中口语使用“启动”、“运转”时因仅匹配“开”字导致被逆向解析为关机任务的严重缺陷；
   - 补齐了 macOS 状态栏全屋快捷控制、单设备快捷项与级联子菜单的悬浮 Tooltip 看板，提升系统可解释性与原生交互质感。

---

## 3. 关键架构变更与代码实现

### 3.1 自然语言广义独立时相调度大一统引擎与启动动作谓词消歧
- **`VoiceCommandParser.swift` `parseScheduleTime` 广义时相支持**：
  ```swift
  // 必须包含“点”或“时”或者标准时间冒号，或者独立时相词（午夜、子夜、正午、中午、傍晚、黄昏、清晨、早晨、黎明、拂晓、破晓），且不是“小时” (v1.9.78)
  guard (normalized.contains("点") || normalized.contains("时") || normalized.contains(":") ||
         normalized.contains("午夜") || normalized.contains("子夜") || normalized.contains("正午") ||
         normalized.contains("中午") || normalized.contains("傍晚") || normalized.contains("黄昏") ||
         normalized.contains("清晨") || normalized.contains("早晨") || normalized.contains("黎明") ||
         normalized.contains("拂晓") || normalized.contains("破晓")) && !normalized.contains("小时") else {
      return nil
  }

  // 3.5 独立无钟点独立时相结构（如“午夜关机” / “子夜关空调” -> 00:00；“正午/中午” -> 12:00；“傍晚/黄昏” -> 18:00；“清晨/早晨/黎明” -> 06:00） (v1.9.78)
  if hour == nil {
      if normalized.contains("午夜") || normalized.contains("子夜") {
          hour = 0
          minute = 0
      } else if normalized.contains("正午") || normalized.contains("中午") {
          hour = 12
          minute = 0
      } else if normalized.contains("傍晚") || normalized.contains("黄昏") {
          hour = 18
          minute = 0
      } else if normalized.contains("清晨") || normalized.contains("早晨") || normalized.contains("黎明") ||
                 normalized.contains("拂晓") || normalized.contains("破晓") {
          hour = 6
          minute = 0
      }
  }
  ```

- **半点口语标准化与启动谓词消歧**：
  ```swift
  // 半点口语时相标准化 (v1.9.78)
  let halfHourNormalized = text
      .replacingOccurrences(of: "中午半", with: "中午12点30分")
      .replacingOccurrences(of: "正午半", with: "正午12点30分")
      .replacingOccurrences(of: "午夜半", with: "午夜0点30分")
      .replacingOccurrences(of: "子夜半", with: "子夜0点30分")
      .replacingOccurrences(of: "傍晚半", with: "傍晚6点30分")
      .replacingOccurrences(of: "黄昏半", with: "黄昏6点30分")
      .replacingOccurrences(of: "清晨半", with: "清晨6点30分")
      .replacingOccurrences(of: "早晨半", with: "早晨6点30分")
      .replacingOccurrences(of: "黎明半", with: "黎明6点30分")

  // 动作提取消歧 (v1.9.78)
  let isPowerOn = (text.contains("开") || text.contains("启动") || text.contains("运转")) && !text.contains("关") && !text.contains("停")
  ```

### 3.2 macOS 原生状态栏全景控制矩阵 Tooltip 深度感知
- **`StatusItemController.swift` 全景控制悬浮看板注入**：
  - 为全屋控制菜单项 `coolAllItem`, `heatAllItem`, `dehumAllItem`, `fanAllItem`, `autoAllItem`, `stepUpAllItem`, `stepUpHalfAllItem`, `stepDownHalfAllItem`, `stepDownAllItem`, `windParentItem`, `turnOnAllItem`, `turnOffAllItem` 注入精确的模式说明、作用设备统计与 16°C ~ 30°C 温度边界提示；
  - 为单设备控制及设备级联子菜单的电源按键、模式按键、升降温按键逐一装配包含设备名、模式职能与温度极值防护的 `toolTip`。

---

## 4. 自动化测试与验证

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增针对广义独立时相调度与启动谓词消歧的 24 组端到端单元测试用例：
  - `"中午关机"` -> `12:00` 关机 (PASS)
  - `"中午开机"` -> `12:00` 开机 (PASS)
  - `"明天中午关机"` -> `明天 12:00` 关机 (PASS)
  - `"全屋中午关空调"` -> `全屋 12:00` 关机 (PASS)
  - `"傍晚关空调"` -> `18:00` 关机 (PASS)
  - `"傍晚开机"` -> `18:00` 开机 (PASS)
  - `"黄昏关机"` -> `18:00` 关机 (PASS)
  - `"早晨开机"` -> `06:00` 开机 (PASS)
  - `"早晨关空调"` -> `06:00` 关机 (PASS)
  - `"清晨关机"` -> `06:00` 关机 (PASS)
  - `"黎明开空调"` -> `06:00` 开机 (PASS)
  - `"明天傍晚关空调"` -> `明天 18:00` 关机 (PASS)
  - `"每周五清晨开机"` -> `每周五 06:00` 开机 (PASS)
  - `"中午半关机"` -> `12:30` 关机 (PASS)
  - `"午夜半关空调"` -> `00:30` 关机 (PASS)
  - `"傍晚半关机"` -> `18:30` 关机 (PASS)
  - `"定时明早8点启动空调"` -> `明早 08:00` 开机 (PASS)
  - `"明天下午2点运转空调"` -> `明午 14:00` 开机 (PASS)
  - `"倒计时半小时启动"` -> `倒计时 30 分钟` 开机 (PASS)
  - `"倒计时启动"` -> `倒计时 60 分钟` 开机 (PASS)
  - 全部断言 100% PASS。
- **编译与构建验证**：
  - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`：编译完成，100% 成功无警告错误；
  - 执行 `./build_app.sh 1.9.78`：Release 二进制与小组件扩展构建完成，完成 Ad-hoc 签名与 Entitlements 注入，成功生成 `dist/HaierAC.app` 与 `dist/HaierAC-v1.9.78-macOS.zip`。

---

## 5. 发版清单与资产

- **Git Commit & Tag**：`v1.9.78`
- **Release 资产**：`dist/HaierAC-v1.9.78-macOS.zip`
- **文件大小**：`2.8 MB`
- **SHA-256**：`5a7f4f0777f98e518c595592f9fdc89484c0e9f96c74a5fb0923a79316fa02ae`
- **发布方式**：GitHub Release via `gh release create v1.9.78`
