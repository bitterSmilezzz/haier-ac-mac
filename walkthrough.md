# Haier AC Mac v1.9.105 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.105`
- **发版主题**：闭环复合排除与反相循环调度大一统、菜单栏控制中心全屋活跃调度全景感知与跨房间管理
- **核心目标与架构演进**：
  1. **“复合排除与反相循环调度大一统、零有效天安全拦截”调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **显式与隐式排除模式架构重构**：将排除模式拆分为 `explicitExclusionRepeatRegex`（显式带“外/之外/以外”边界）与 `implicitExclusionRepeatRegex`（隐式无“外”分界），彻底根除由于前置基准词预查与连词（`和`、`与`、`及`、`加`、`、`、`以及`）冲突引起的贪婪断裂漏洞；
     - **全景复合多关键词与多区间并列排除大一统**：全面覆盖“除了周末和大休每天早8点开机”（`[2, 3, 4, 5, 6]`）、“除了大休和小休每天早8点开机”（`[2, 3, 4, 5, 6]`）、“除了单休日和双休日每天早8点开机”（`[2, 3, 4, 5, 6]`）、“除了周一至周二和周五至周六每天早8点开机”（`[1, 4, 5]`）、“除周一至周二、周三至周四和周五至周六外每天早8点开机”（`[1]`）等高阶自然口语，彻底杜绝并列排除项被截断遗留至 `remainingText` 造成反向逆向执行的重大隐患；
     - **完全排除零运行天严格安全防御**：当排除项覆盖了基准集的所有日期（如“除了工作日和大休每天早8点开机”或“工作日除周一至周五外每天早8点开机”）时，严格判定为无有效运行天并执行安全拦截（返回 `nil`），坚决杜绝回退为单次执行或即时开关机误触；
     - **单元测试 100% 满分覆盖**：新增 `testCompoundExclusionAndAllInclusiveHardeningV19105` 严苛测试套件，包含多关键词并列排除、多区间并列排除、显式多区间排除及防即时误触断言，全套 113 个单元测试零缺陷通过。
  2. **macOS 菜单栏 Bento Popover 控制中心全屋活跃调度全景感知与跨房间管理 (`MenuBarControlsView.swift`)**：
     - **跨房间全屋活跃计划任务指示胶囊 (`activeSchedulePod`)**：打破单机盲区，当当前设备无定时但全屋其他设备有活跃定时任务时，智能展示全屋最近即将触发的计划任务（标明目标房间与时间，如「客厅」22:00 关机），杜绝信息遗漏；当本机与全屋均有定时时，副标题联动展示全屋计划总览计数；
     - **计划暂停态深度感知与一键恢复**：当全屋定时任务均处于临时暂停状态时，直观呈现“定时任务已暂停”胶囊状态并提供“一键恢复”快捷按钮；
     - **跨房间管理菜单全量贯通**：展开管理菜单新增支持“临时暂停/恢复生效「当前机」定时”、“临时暂停/恢复生效全屋所有定时”及“取消全屋所有定时”，与语音交互胶囊和主窗口达成 100% 全对称闭环管理；
     - **全交互原生微触感反馈 (`NSHapticFeedbackManager`)**：为所有恢复、暂停、取消等操作注入 macOS 原生系统级微触感震动反馈。

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
   - **复合排除与反相循环调度并列截断与反向逆执行缺陷 (P0/P1 修复)**：在自然语言周期排班中，当用户表达“除了周末和大休”或“除了周一至周二和周五至周六”时，原有正则由于前置预查贪婪匹配了连词后面的基准词，导致在连词处中途断裂，使得后半部分被错误当作基准范围甚至导致反向逆向执行（用户说不执行周末，结果被当成周末开启）。本次通过拆分显式与隐式排除模式并加入零有效天安全拦截，彻底根除此重大缺陷；
   - **菜单栏 Popover 控制中心跨房间调度盲区 (高价值体验优化)**：以往控制中心仅能看到当前选定设备的活跃任务，若当前房间无定时而其他房间有定时，整个面板完全不显示，造成信息盲区。本次全面升级跨房间感知，并支持全屋/单机的一键暂停与恢复。

---

## 3. 关键架构变更与代码实现

### 3.1 显式与隐式复合排除宏正则及零天数安全拦截
- **`VoiceCommandParser.swift`**：
  ```swift
  // 显式带“外/之外/以外”的排除模式
  private static let explicitExclusionRepeatRegex: NSRegularExpression? = {
      let pattern = #"(?:除了|除)\s*([^，,。！？\s]+?)\s*(?:之|以)?外"#
      return try? NSRegularExpression(pattern: pattern)
  }()

  // 隐式无“外”的排除模式（排除内容直到标点、时间词或非连词连接的基准词）
  private static let implicitExclusionRepeatRegex: NSRegularExpression? = {
      let pattern = #"(?:除了|除)\s*([^，,。！？\s]+?)(?=[，,。！？\s]|(?<!(?:和|与|及|加|以及|还有|另外|、|\s))\s*(?<!非)(?:工作日|平时|平日|双休日|双休|周末三天|周末|休息日|公休日|休假日|放假日|节假日|单休日|单休|大休日|大休|大周|小休日|小休|小周|一三五|二四六)(?=\s*(?:每天|天天|每日|每晚|每早|每晨|每夜|日日|\d|早|晚|夜|中|上|下|凌晨|午|点|时|:|开|关|停))|每天|天天|每日|每晚|每早|每晨|每夜|日日|(?<![周星期礼拜])(?:\d|早|晚|夜|中|上|下|凌晨|午|点|时|:|$|开|关|停))"#
      return try? NSRegularExpression(pattern: pattern)
  }()
  ```

### 3.2 菜单栏 Bento 控制中心跨房间活跃调度全景感知与暂停管理
- **`MenuBarControlsView.swift`**：
  ```swift
  // 跨房间活跃任务指示胶囊
  @ViewBuilder
  private func activeSchedulePod(device: DeviceInfo) -> some View {
      let allActions = model.scheduledActions
      let enabledActions = allActions.filter(\.enabled)
      let isAllPaused = !allActions.isEmpty && enabledActions.isEmpty
      ...
  }
  ```

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **113 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 执行 `./build_app.sh 1.9.105`：
   - 顺利生成 App 产物 `dist/HaierAC.app` 与发布安装包 `dist/HaierAC-v1.9.105-macOS.zip`（体积 2.9MB，内置桌面小组件扩展与签名，SHA256: `9ee11c8bb8be7ff57399d541dfc083087da149e5b051cc30ba36d1452ff21691`）。

---

## 5. 发版信息与提交记录
- **Git Commit**：`feat & fix: 闭环复合排除与反相循环调度大一统、菜单栏控制中心全屋活跃调度全景感知与跨房间管理 (v1.9.105)`
- **Git Tag**：`v1.9.105`
- **Release Asset**：`dist/HaierAC-v1.9.105-macOS.zip`
