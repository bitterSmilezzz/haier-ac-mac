# Haier AC Mac v1.9.104 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.104`
- **发版主题**：闭环三连续区间与核心关键词全景复合调度、菜单栏控制中心全屋情景切换与活跃定时胶囊
- **核心目标与架构演进**：
  1. **“三连续区间与核心关键词双向全景复合、区间+离散+关键词三元大一统”调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **三连续区间与关键词全景拓扑大一统**：新增 `triRangeWithKeywordRegex`（三连续区间在前+核心词在后）、`keywordWithTriRangeRegex`（核心词在前+三连续区间在后）、`rangeWithKeywordAndDualRangeRegex`（单区间在前+核心词居中+双区间在后夹心）与 `dualRangeWithKeywordAndRangeRegex`（双区间在前+核心词居中+单区间在后夹心）等高阶宏正则引擎；
     - **区间+离散星期+核心关键词三元复合大一统**：新增 `rangeWithMultiDaysAndKeywordRegex`、`keywordWithRangeAndMultiDaysRegex` 与 `multiDaysWithRangeAndKeywordRegex`，彻底闭环“单/双连续区间”、“离散多星期”与“核心关键词”任意排列组合的超高复杂度自然调度表达；
     - **彻底修复潜伏的核心关键词字尾字符截断漏洞**：为所有前置离散星期正则宏全面补齐防词尾“日”截断的负向后行断言 `(?<!(?:工作|平时|平日|单休日|单休|双休日|双休|休息|公休|休假|放假|节假|大休日|大休|大周|小休日|小休|小周|生|次|翌|当|昨|今|明|后|大后))`，坚决阻断“双休日/工作日/节假日”等词尾的“日”被贪婪误判为单个“周日”的重大解析隐患；
     - **全向复合自然口语无缝覆盖**：全面覆盖“周一到周二、周四到周五、周六到周日和大休早8点开机”（`[1, 2, 3, 5, 6, 7]`）、“周一至周二、周三至周四、周五至周六加单休日早8点开机”（`[1, 2, 3, 4, 5, 6, 7]`）、“周一至周三加周四、周五和大休早8点开机”（`[1, 2, 3, 4, 5, 6, 7]`）、“周一至周三加双休日和双休早8点开机”（`[1, 2, 3, 4, 7]`）等口语调度；
     - **单元测试 100% 满分覆盖**：新增 `testTriRangeAndKeywordAndTernaryUnificationV19104` 严苛测试套件，全套 112 个单元测试零缺陷通过，杜绝误触。
  2. **macOS 菜单栏 Bento Popover 控制中心全屋情景切换与活跃定时指示胶囊 (`MenuBarControlsView.swift`)**：
     - **活跃定时与倒计时任务快捷指示胶囊 (`activeSchedulePod`)**：在菜单栏控制中心快捷操作区下方无缝嵌入活跃调度胶囊，实时计算并展示最近即将触发的任务名称、周期类型（如“每天”、“工作日”、“一次性”）及精确倒计时；支持单任务一键快捷取消与多任务展开管理（取消单任务、取消当前机所有定时、全屋取消定时）；
     - **一键情景多设备「当前机 / 全屋」分段微型切换胶囊**：在菜单栏控制中心的「一键情景」区域引入多设备协同切换胶囊，支持用户秒级切换“当前机”独立下发与“全屋 (N台)”统一广播预设，达成与状态栏菜单、批量面板的 100% 全对称协同体验；
     - **全交互原生微触感反馈 (`NSHapticFeedbackManager`)**：为菜单栏 Bento 控制中心的电源开关、情景灯光、目标温度步进调节、运行模式切换、风速挡位选择、情景预设应用及定时任务管理全量注入 macOS 原生系统级微触感震动反馈，让交互更具物理质感。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下审查报告及全仓架构进行了全景复核与缺陷深挖：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 正则结构稳固，跨字符穿插防御严密；
   - **全屋与定向定时解耦 (P1-2)**：`cancelSchedules` 与 `cancelSchedulesAll` 精确分流，多设备批量取消分支全部贯通；
   - **工况占比计算属性消费 (P2-1)**：`EcoEnergySection` 已统一调用 4 个比率属性；
   - **死分支清理 (P2-2)**：`.adjustTemperatureAll` 死分支已彻底清理；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏与 UI Stepper 使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **三连续区间与核心关键词复合调度脱靶漏洞 (P1 修复)**：在自然语言周期排班中，当用户表达“周一至周二、周四至周五、周六至周日和大休”时，若没有三连续区间宏正则，会在双区间匹配后把第三段区间与末尾关键词截断；同时深入分析发现历史正则中由于缺乏前置负向后行断言，当“周六加单休日”或“周五加双休日”被离散正则处理时，“双休日/工作日”结尾的“日”会被贪婪误匹配为星期天 `[1]`。本次在补齐三连续区间拓扑的同时，全面筑牢字符截断防线，彻底根除此隐蔽缺陷；
   - **菜单栏 Popover 控制中心全屋情景与活跃调度缺失 (高价值体验优化)**：用户在日常使用中高频呼出菜单栏控制中心，但以往菜单栏缺乏活跃定时任务的直观指示，也无法一键广播全屋情景，更缺乏触控板微触感。本次在菜单栏 Popover 中无缝集成活跃定时指示胶囊与全屋情景切换，并注入原生 AppKit 微触感反馈。

---

## 3. 关键架构变更与代码实现

### 3.1 三连续区间、三元复合宏正则与关键词防截断
- **`VoiceCommandParser.swift`**：
  ```swift
  // 三连续区间在前 + 核心关键词在后
  private static let triRangeWithKeywordRegex: NSRegularExpression? = { ... }()

  // 核心关键词在前 + 三连续区间在后
  private static let keywordWithTriRangeRegex: NSRegularExpression? = { ... }()

  // 离散多星期匹配宏增加关键词尾字符负向断言防线
  private static let multiDaysNegativeLookbehind = #"(?<!(?:工作|平时|平日|单休日|单休|双休日|双休|休息|公休|休假|放假|节假|大休日|大休|大周|小休日|小休|小周|生|次|翌|当|昨|今|明|后|大后))"#
  ```

### 3.2 菜单栏 Bento 控制中心活跃定时胶囊与全屋情景微型切换
- **`MenuBarControlsView.swift`**：
  ```swift
  // 活跃定时指示胶囊
  @ViewBuilder
  private func activeSchedulePod(device: DeviceInfo) -> some View { ... }

  // 一键情景支持当前机 / 全屋 (N台) 分段切换
  private func scenesPod(device: DeviceInfo, reachability: AppModel.DeviceReachability) -> some View { ... }

  // AppKit 系统微触感反馈
  private func triggerHaptic() {
      NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
  }
  ```

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **112 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 执行 `./build_app.sh 1.9.104`：
   - 顺利生成 App 产物 `dist/HaierAC.app` 与发布安装包 `dist/HaierAC-v1.9.104-macOS.zip`（体积 2.9MB，内置桌面小组件扩展与签名，SHA256: `567d7b7d6d3b5fa5b6c3b8567fd130a08af81c6d25cb65ba5210a42dde067ca5`）。

---

## 5. 发版信息与提交记录
- **Git Commit**：`feat & fix: 闭环三连续区间与核心关键词全景复合调度、菜单栏控制中心全屋情景切换与活跃定时胶囊 (v1.9.104)`
- **Git Tag**：`v1.9.104`
- **Release Asset**：`dist/HaierAC-v1.9.104-macOS.zip`
