# Haier AC Mac v1.9.111 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.111`
- **发版主题**：闭环五核心关键词与口语排除大一统调度、状态栏与控制中心自清洁全生命周期操作闭环及全屋高精微调
- **核心目标与架构演进**：
  1. **“五核心关键词全景排班、口语排除引导词大一统与深层词法拆词断言修复”自然口语调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **深层正则词法截断 bug 彻底修复**：排查并修复 `implicitExclusionRepeatRegex` 隐式排除负向断言 `(?<![周星期礼拜平定])`，杜绝因包含“时”导致“平时”（工作日）与“定时”被拆分为“平”与“时”（被断言捕获截断）的深层隐患；
     - **口语排除引导词大一统**：在 `explicitExclusionRepeatRegex`、`implicitExclusionRepeatRegex` 与 `extractExcludedDays` 中全面纳管“除开”、“除去”、“刨除”、“扣除”，与原有“除”、“除了”等完全对称统一；
     - **五核心关键词全景复合调度闭环**：新增 `pentaKeywordsRegex` 并在 `parseBaseRepeatWeekdays` 中完备纳管五核心关键词复合组合（如“工作日、双休、大休、小休同单休日每天早8点开机” `[1..7]`），彻底消灭多关键词口语遗漏缺陷；
     - **排除型反相调度自动贯通**：如“除开工作日外每天早8点开机”精准计算为周末 `[1, 7]`、“刨除双休日和单休每天早8点开机”精准计算为单休工作日、“扣除大休和小休每天早8点开机”精准阻断；
     - **单元测试 100% 满分覆盖**：新增 `testPentaKeywordsAndColloquialExclusionV19111` 严苛测试套件，全套 119 个单元测试零缺陷通过（0 failures）。
  2. **macOS 原生状态栏与控制中心蒸发器自清洁全生命周期操作闭环 (`StatusItemController.swift` / `MenuBarControlsView.swift`)**：
     - **状态栏自清洁全入口闭环**：
       - 单设备独立模式菜单与多设备子菜单中，实时感知自清洁进度并在运行中展示“🛑 中止 56°C 自清洁 (剩余 mm:ss)”、空闲时展示“✨ 启动 56°C 蒸发器自清洁...”；
       - 顶层滤网子菜单中全面补齐自清洁进行中快捷中止项与全屋多机自清洁启动二级子菜单，消灭从状态栏无法直接发起或中止自清洁的操作断层；
       - 底层补齐 `@objc` 事件转发至 `AppModel.startSelfCleaning(deviceId:)` 与 `AppModel.stopSelfCleaning()`；
     - **控制中心（MenuBarControlsView）宿主动态感知与一键切换**：
       - 升级 `selfCleaningPod`，当全屋任意一台空调处于自清洁中时，动态呈现该机组名称（如“「客厅空调」自清洁进行中”），在非本机自清洁时支持一键“切至本机”与一键“中止”，消灭多机环境下的设备指代歧义。
  3. **macOS 菜单栏 Bento 控制中心全屋调温高精微调与标准步进双态切换 (`MenuBarControlsView.swift`)**：
     - **`1.0°C` 标准步进 / `0.5°C` 高精微调动态切换**：在全屋联动调温模式下，顶部操作栏增设 `1.0°` / `0.5°` 切换胶囊；
     - **全屋统一步进调节**：根据选定步进粒度动态下发全屋调温并自适应更新气泡提示（如“全屋运行中空调统一降温 0.5°C”），满足极端体感对细分温阶的高精度诉求。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下审查报告及全仓架构进行了全景复核与缺陷深挖：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 正则结构稳固，跨字符穿插防御严密；
   - **全屋与定向定时解耦 (P1-2)**：`cancelSchedules` 与 `cancelSchedulesAll` 精确分流，多设备批量取消分支全部贯通；
   - **工况占比计算属性消费 (P2-1)**：`EcoEnergySection` 已统一调用 4 个比率属性；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏与 UI Stepper 使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **词法断言截断与“平时/定时”拆词 bug (P0 修复)**：隐式排除中的时间词负向断言 `(?:\d|早|晚|夜|中|上|下|凌晨|午|点|时|:|开|关|停)` 包含“时”，当遇到口语“平时”或“定时”时，由于断言捕获“时”，导致“平时”被拆分为“平”与“时”，造成周期解析截断。通过在负向断言中增加排除 `[平定]`（即 `(?<![周星期礼拜平定])`），彻底治愈了该深层拆词缺陷；
   - **口语排除引导词大一统 (P1 修复)**：纳管“除开”、“除去”、“刨除”、“扣除”，解决口语排除词缺失缺陷；
   - **五核心关键词全景复合调度 (P1 优化)**：新增 `pentaKeywordsRegex` 闭环五核心关键词复合组合；
   - **状态栏自清洁操作全闭环 (P1 优化)**：在单机模式、多机子菜单以及顶层滤网保养菜单中打通自清洁启动与中止闭环；
   - **控制中心宿主感知与高精步进切换 (P1 优化)**：多机环境下感知清洁宿主与切至本机，提供 `1.0°` / `0.5°` 步进胶囊。

---

## 3. 关键架构变更与代码实现

### 3.1 五核心关键词与口语排除大一统引擎
- **`VoiceCommandParser.swift`**：
  ```swift
  // 排除前缀负向断言排除 [平定]，防止“平时”与“定时”被截断
  #"(?<![周星期礼拜平定])(?:\d|早|晚|夜|中|上|下|凌晨|午|点|时|:|开|关|停)"#

  // 五核心关键词全景正则
  private static let pentaKeywordsRegex: NSRegularExpression? = {
      let pattern = #"(工作日|平时|双休|周末三天|大休|小休|周末|双休日|单休|单休日)\s*(?:[、,，和与及跟同以及还有或者或加/／\s]+)\s*(工作日|平时|双休|周末三天|大休|小休|周末|双休日|单休|单休日)\s*(?:[、,，和与及跟同以及还有或者或加/／\s]+)\s*(工作日|平时|双休|周末三天|大休|小休|周末|双休日|单休|单休日)\s*(?:[、,，和与及跟同以及还有或者或加/／\s]+)\s*(工作日|平时|双休|周末三天|大休|小休|周末|双休日|单休|单休日)\s*(?:[、,，和与及跟同以及还有或者或加/／\s]+)\s*(工作日|平时|双休|周末三天|大休|小休|周末|双休日|单休|单休日)"#
      return try? NSRegularExpression(pattern: pattern)
  }()
  ```

### 3.2 状态栏与控制中心自清洁操作闭环
- **`StatusItemController.swift`**：
  在单设备模式、多设备子菜单及顶层滤网子菜单中全面补齐自清洁启动与中止项：
  ```swift
  if isCleaningThisDev {
      let stopCleanItem = NSMenuItem(
          title: "🛑 中止 56°C 自清洁 (剩余 \(String(format: "%02d:%02d", m, s)))",
          action: #selector(stopSelfCleaningFromMenu),
          keyEquivalent: ""
      )
      ...
  } else {
      let cleanItem = NSMenuItem(
          title: "✨ 启动 56°C 蒸发器自清洁...",
          action: #selector(startDeviceSelfCleaningFromMenu(_:)),
          keyEquivalent: ""
      )
      ...
  }
  ```
- **`MenuBarControlsView.swift`**：
  升级 `selfCleaningPod`，多设备自清洁中支持宿主感知与“切至本机”一键转移。

### 3.3 控制中心全屋联动高精调温步进
- **`MenuBarControlsView.swift`**：
  全屋模式下增设 `1.0°` / `0.5°` 步进粒度胶囊，支持高精微调。

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **119 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build -c release`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 执行 `./build_app.sh 1.9.111`：
   - 顺利生成 App 产物 `dist/HaierAC.app` 与发布安装包 `dist/HaierAC-v1.9.111-macOS.zip`（SHA256: `b07fe2b5bf518e402602c0be30c1af523ce659c0a7c938ee8d4382fb03fa1452`）。

---

## 5. 发版信息与提交记录
- **Git Commit**：`feat & fix: 闭环五核心关键词与口语排除大一统调度、状态栏与控制中心自清洁全生命周期操作闭环及全屋高精微调 (v1.9.111)`
- **Git Tag**：`v1.9.111`
- **Release Asset**：`dist/HaierAC-v1.9.111-macOS.zip`
- **SHA256**：`b07fe2b5bf518e402602c0be30c1af523ce659c0a7c938ee8d4382fb03fa1452`
