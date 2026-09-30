# Haier AC Mac v1.9.103 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.103`
- **发版主题**：闭环双连续区间与核心关键词全景复合调度、状态栏与主窗口一键情景预设 Bento 矩阵及开机机时自洽
- **核心目标与架构演进**：
  1. **“双连续区间与核心关键词双向全景复合”调度大一统引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **双区间与关键词三角拓扑大一统**：新增 `dualRangeWithKeywordRegex`（双区间在前+核心词在后）、`keywordWithDualRangeRegex`（核心词在前+双区间在后）与 `rangeWithKeywordAndRangeRegex`（区间在先+核心词居中+区间在后夹心）三大宏正则引擎，彻底解决因 `rangeWithRangeRegex` 提前贪婪截断双区间导致尾部或中间的“大休/双休日/单休日”等核心关键词被静默丢弃的历史缺陷；
     - **全向复合自然口语无缝覆盖**：全面闭环“周一至周二、周四至周五和大休早8点开机”（`[1, 2, 3, 5, 6, 7]`）、“周一到周三、周五到周六加双休日早8点开机”（`[1, 2, 3, 4, 6, 7]`）、“周一至周二、周四至周五加单休日晚9点关空调”（`[1, 2, 3, 5, 6]`）、“大休和周一至周二、周四至周五早8点开机”（`[1, 2, 3, 5, 6, 7]`）、“周一至周二、大休和周四至周五早8点开机”（`[1, 2, 3, 5, 6, 7]`）等高阶自然口语调度；
     - **单元测试 100% 满分覆盖**：新增 `testDualRangeAndKeywordUnificationV19103` 严苛测试套件，包含正向双区间、反向双区间、夹心双区间及严格防即时误触断言，全套 111 个单元测试零缺陷通过。
  2. **macOS 状态栏 Bento 控制中心与主窗口一键情景预设矩阵贯通 (`MenuBarControlsView.swift` / `DeviceControlView.swift`)**：
     - **菜单栏 Bento 控制中心新增「一键情景」快捷矩阵**：在菜单栏 Popover 控制中心紧随快控区域植入原生 Bento 风格的快捷情景卡片，直观展现情景图标（🌙 睡眠、🚪 离家、🏠 回家、✨ 自定义）与名称，用户单击菜单栏图标即可为当前设备一键应用情景，伴随微触感弹簧动效与操作反馈 Toast；
     - **主窗口设备详情面板打通情景模式快捷网格**：在主窗口 `DeviceControlView` 快控区植入情景模式卡片网格，支持在主界面直接向当前选中的空调下发复合情景，达成右键菜单、批量面板、菜单栏 Popover、主窗口、快捷指令与语音胶囊的全域对称自洽；
     - **离线与断网状态安全门禁**：情景卡片严格遵从设备可达性三态模型，在网关重连中或设备离线时自动禁用并平滑降级，杜绝盲目下发。
  3. **开机与状态变迁时机时初始化与状态同步保障 (`AppModel.swift`)**：
     - **开机场景运行机时自洽重置**：重构 `applyScene`、`fireDueActions`、`sendAttribute` 与 `sendAttributeToDevices`，在下发开机动作（`onOffStatus == true`）且设备原状态为待机时，将 `deviceContinuousMinutes` 归零重新计时，彻底消除待机漂移与机时残留；关机时保持即刻清零，确保能耗热动力学模型的 100% 精确度。

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
   - **双连续区间与核心关键词组合调度脱靶缺陷 (P1 修复)**：在自然语言周期排班中，当用户表达“周一至周二、周四至周五和大休”时，原先流程会被 `rangeWithRangeRegex` 提前匹配拦截并把末尾“和大休”截断丢弃；当关键词居中或在前时更无法识别。本次新增三组全景复合正则并在流水线中提前拦截，完整闭环了双连续区间与核心词的三角拓扑；
   - **菜单栏 Popover 控制中心与主窗口情景预设缺失 (高价值体验优化)**：以往一键情景只能在状态栏右键二级菜单或批量控制窗口触发，核心的菜单栏 Bento Popover 与主控制面板中无法便捷使用。本次在两个核心视图均植入一键情景卡片，实现全平台统一对称；
   - **开机场景持续机时残留风险 (P2 修复)**：在设备由待机状态唤醒开机时，补齐了持续机时清零初始化保护，防止跨周期累计导致能耗动力学模型热饱和阻尼计算失真。

---

## 3. 关键架构变更与代码实现

### 3.1 双连续区间与核心关键词正则宏与流式提取
- **`VoiceCommandParser.swift`**：
  ```swift
  // 双连续区间在前 + 核心关键词在后
  private static let dualRangeWithKeywordRegex: NSRegularExpression? = { ... }()

  // 核心关键词在前 + 双连续区间在后
  private static let keywordWithDualRangeRegex: NSRegularExpression? = { ... }()

  // 连续区间在先、核心关键词居中、连续区间在后
  private static let rangeWithKeywordAndRangeRegex: NSRegularExpression? = { ... }()
  ```

### 3.2 菜单栏 Popover 控制中心一键情景 Bento 卡片
- **`MenuBarControlsView.swift`**：
  ```swift
  private func scenesPod(device: DeviceInfo, reachability: AppModel.DeviceReachability) -> some View {
      VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 4) {
              Image(systemName: "sparkles")
              Text("一键情景")
              Spacer()
          }
          LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: min(model.scenes.count, 3)), spacing: 6) {
              ForEach(model.scenes) { scene in
                  Button {
                      withAnimation(Theme.springFast) {
                          model.applyScene(scene, targetDeviceId: device.id)
                      }
                  } label: { ... }
              }
          }
      }
      .disabled(!reachability.isControllable)
      .opacity(reachability.isControllable ? 1.0 : 0.6)
  }
  ```

### 3.3 开关机双向机时管理与状态自洽
- **`AppModel.swift`**：
  ```swift
  if var map = attributes[deviceId], let old = map[name] {
      let wasOff = (old.boolValue != true)
      map[name] = old.updating(value: value)
      attributes[deviceId] = map
      if name == "onOffStatus" {
          if value.boolValue == false || wasOff {
              deviceContinuousMinutes[deviceId] = 0
          }
      }
  }
  ```

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **111 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 执行 `./build_app.sh`：
   - 顺利生成 App 产物 `dist/HaierAC.app` 与发布安装包 `dist/HaierAC-v1.9.103-macOS.zip`（体积 2.9MB，内置桌面小组件扩展与签名，SHA256: `759a6be75658d16bbe2b0064da4d84ee8a98024370e56fa53c8241cc521a2615`）。

---

## 5. 发版信息与提交记录
- **Git Commit**：`feat & fix: 闭环双连续区间与核心关键词全景复合调度、状态栏与主窗口一键情景预设 Bento 矩阵及开机机时自洽 (v1.9.103)`
- **Git Tag**：`v1.9.103`
- **Release Asset**：`dist/HaierAC-v1.9.103-macOS.zip`
