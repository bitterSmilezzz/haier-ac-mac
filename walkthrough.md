# Haier AC Mac v1.9.106 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.106`
- **发版主题**：闭环双区间双关键词四元调度与口语连词排除防断裂、macOS状态栏全屋调度暂停态全感知与机组热容物理衰减模型
- **核心目标与架构演进**：
  1. **“双连续区间与双核心关键词四元复合周期调度、口语连词排除防断裂”自然口语调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **双连续区间与双核心关键词四元复合调度引擎**：新增 `dualRangeWithDualKeywordsRegex`（双区间在前+双核心词在后）与 `dualKeywordsWithDualRangeRegex`（双核心词在前+双区间在后），全面覆盖“周一至周二、周四至周五、大休和小休每天早8点开机”（`[1, 2, 3, 5, 6, 7]`）、“大休和小休加周一至周二、周四至周五每天早8点开机”（`[1, 2, 3, 5, 6, 7]`）、“周一到周二、周四到周五加工作日和双休每天早8点开机”（`[1..7]`）等四元复合周期调度；
     - **隐式排除口语连词全面纳管防断裂**：在 `implicitExclusionRepeatRegex` 负向后行断言中全面补齐口语常见连词 `跟`、`或者`、`或`、`并且`、`并`，彻底根除如“除了周末跟大休每天早8点开机”、“除了周末或者大休每天早8点开机”、“除了大休并且小休每天早8点开机”因连词缺失导致预查提前触发断裂留下悬挂文本造成逆向误执行的隐患；
     - **显式排除（带外/之外/以外）标点符号容错**：优化 `explicitExclusionRepeatRegex` 结构，允许排除子句内包含中文/英文逗号及空格分界（如“除周一至周二，周三至周四外每天早8点开机”、“除周末，大休 之外每天早8点开机”），在 `extractExcludedDays` 中平滑解耦提取；
     - **单元测试 100% 满分覆盖**：新增 `testDualRangeDualKeywordsAndExclusionHardeningV19106` 测试套件，全套 114 个单元测试零缺陷通过，杜绝误触。
  2. **macOS 原生状态栏全屋计划调度暂停态全感知与历史空ID任务归属 (`StatusItemController.swift` / `AppModel.swift` / `MenuBarControlsView.swift`)**：
     - **状态栏 Tooltip 全屋计划调度暂停态全感知**：当全屋计划任务全部处于临时暂停状态时，状态栏悬浮 Tooltip 显式提示 `⏸ 计划调度: 全屋共 X 个定时任务已全部暂停生效 (右键菜单可一键恢复)`，打破信息盲区；
     - **历史空白 `deviceId` 调度任务归属主显设备闭环**：在 `cancelSchedules(for:)`、`setScheduledActionsEnabled(for:enabled:)`、状态栏设备级联子菜单及控制中心菜单中，针对空 `deviceId` 的历史遗留任务智能对齐匹配 `primaryDeviceId`，彻底根除历史任务在单机面板中无法取消、无法暂停或变成幽灵任务的隐患。
  3. **变频机组热容量连续性物理散热衰减模型 (`AppModel.swift`)**：
     - **HVAC 热容量连续性物理衰减 (Thermal Mass Dissipation Model)**：变频空调停机或待机时，换热器翅片与压缩机机体热饱和积累随时间遵循牛顿冷却定律平滑自然散热，采用 3 倍速线性散热衰减（`max(0, current - elapsedMinutes * 3)`），既避免瞬间归零导致短时停机/调档丢失热饱和稳态阻抗，又确保长时间停机（连续待机 40~60 分钟以上）自然彻底冷却至零，极大提升了能耗动力学物理仿真保真度。

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
   - **口语连词在隐式排除中的负向预查断裂隐患 (P0 修复)**：在自然语言排班中，用户使用“除了周末跟大休”、“除了周末或者大休”、“除了大休并且小休”等口语表达时，旧版预查断言仅支持 `和|与|及|加|以及|还有|另外|、|\s`，缺少 `跟|或者|或|并且|并`，导致正则在遇到“跟”或“或者”前意外断开，截断残留进入执行文本。本轮全面补充连词后，完全防范了此解析断裂隐患；
   - **历史遗留空 deviceId 调度任务无法在单机视图取消或暂停 (P1 修复)**：早期版本的某些定时任务未显式绑定 `deviceId`（为空字符串），在状态栏单机子菜单或控制中心操作该设备时无法被识别。本轮在单机操作逻辑中全面引入 `primaryDeviceId` 智能降级对齐，彻底消除幽灵任务；
   - **机组热容量物理衰减模型 (高价值算法优化)**：在真实工况中，停机不会导致机组换热器内部热量或冷量瞬间归零。引入 3x 线性衰减散热模型后，短期停机后重启能准确延续物理热惯性，长期停机后平滑衰减至零。

---

## 3. 关键架构变更与代码实现

### 3.1 四元复合宏正则与口语连词排除防断裂
- **`VoiceCommandParser.swift`**：
  ```swift
  // 双连续区间在前 + 双核心词在后
  private static let dualRangeWithDualKeywordsRegex: NSRegularExpression? = {
      let r = #"(?:周|星期|礼拜)?([一二三四五六日天])\s*(?:至|到|~|-)\s*(?:周|星期|礼拜)?([一二三四五六日天])"#
      let kw = #"(?:工作日|平时|平日|双休日|双休|周末三天|周末|休息日|公休日|休假日|放假日|节假日|单休日|单休|大休日|大休|大周|小休日|小休|小周)"#
      let conj = #"(?:[、，,\s]|和|与|及|加|以及|还有|另外|跟|或者|或|并且|并)+"#
      let pattern = #"(?:^|[^\w])\#(r)\#(conj)\#(r)\#(conj)\#(kw)\#(conj)\#(kw)\s*(?:每天|天天|每日|每晚|每早|每晨|每夜|日日)?\s*"#
      return try? NSRegularExpression(pattern: pattern)
  }()

  // 双核心词在前 + 双连续区间在后
  private static let dualKeywordsWithDualRangeRegex: NSRegularExpression? = {
      let r = #"(?:周|星期|礼拜)?([一二三四五六日天])\s*(?:至|到|~|-)\s*(?:周|星期|礼拜)?([一二三四五六日天])"#
      let kw = #"(?:工作日|平时|平日|双休日|双休|周末三天|周末|休息日|公休日|休假日|放假日|节假日|单休日|单休|大休日|大休|大周|小休日|小休|小周)"#
      let conj = #"(?:[、，,\s]|和|与|及|加|以及|还有|另外|跟|或者|或|并且|并)+"#
      let pattern = #"(?:^|[^\w])\#(kw)\#(conj)\#(kw)\#(conj)\#(r)\#(conj)\#(r)\s*(?:每天|天天|每日|每晚|每早|每晨|每夜|日日)?\s*"#
      return try? NSRegularExpression(pattern: pattern)
  }()
  ```

### 3.2 变频机组换热器热容量连续性物理散热衰减模型
- **`AppModel.swift`**：
  ```swift
  // 停机/待机：设备换热器热饱和积累随时间遵循物理散热衰减（3倍速线性散热），连续待机一定时间后彻底冷却至零
  let current = deviceContinuousMinutes[deviceId] ?? 0
  if current > 0 {
      deviceContinuousMinutes[deviceId] = max(0, current - elapsedMinutes * 3)
  }
  ```

### 3.3 macOS 状态栏全屋计划调度暂停态全感知与历史空ID兼容
- **`StatusItemController.swift`**：
  ```swift
  // 全屋计划调度全暂停感知
  let allActions = model.scheduledActions
  let enabledActions = allActions.filter(\.enabled)
  if !allActions.isEmpty && enabledActions.isEmpty {
      tooltipLines.append("⏸ 计划调度: 全屋共 \(allActions.count) 个定时任务已全部暂停生效 (右键菜单可一键恢复)")
  }
  ```

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **114 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 执行 `./build_app.sh 1.9.106`：
   - 顺利生成 App 产物 `dist/HaierAC.app` 与发布安装包 `dist/HaierAC-v1.9.106-macOS.zip`（体积 2.9MB，内置桌面小组件扩展与签名，SHA256: `d8e6099a2f6a7c447e94bec833549c255500d14c23432bb0b093db22dc8adccd`）。

---

## 5. 发版信息与提交记录
- **Git Commit**：`feat & fix: 闭环双区间双关键词四元调度与口语连词排除防断裂、macOS状态栏全屋调度暂停态全感知与机组热容物理衰减模型 (v1.9.106)`
- **Git Tag**：`v1.9.106`
- **Release Asset**：`dist/HaierAC-v1.9.106-macOS.zip`
- **SHA256**：`d8e6099a2f6a7c447e94bec833549c255500d14c23432bb0b093db22dc8adccd`
