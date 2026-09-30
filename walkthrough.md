# Haier AC Mac v1.9.102 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.102`
- **发版主题**：闭环自然口语大休小休/大周小周/单休日全核心关键词大一统调度、批量情景预设矩阵打通与计划任务到点状态即时同步
- **核心目标与架构演进**：
  1. **“大休日/小休日/大周/小周/单休日”全景核心关键词复合调度大一统引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **全景核心词典扩充与正则长前缀优先校准**：将 `大休日|大周`（周末双休 `[1, 7]`）与 `小休日|小周|单休日`（单休周日休息 `[1]`）全景纳管至 `daysFromKeyword` 与 8 大复合周期调度正则表达式，并优化正则候选顺序使长前缀优先匹配，彻底解决口语中因“单休”贪婪提前截断导致“单休日”脱靶与“周末三天”周五丢失的历史隐患；
     - **全向复合口语无缝覆盖**：全面支持如“周一至周三和大休日早8点开机”（`[1, 2, 3, 4, 7]`）、“周一至周四加小休日晚9点关空调”（`[1, 2, 3, 4, 5]`）、“大周和周二至周四早8点开机”（`[1, 3, 4, 5, 7]`）、“工作日加单休日早8点开机”（`[1, 2, 3, 4, 5, 6]`）、“周六加单休日早8点开机”（`[1, 7]`）等复杂自然口语；
     - **单元测试 100% 满分覆盖**：新增 `testExtendedKeywordAndRangeUnificationV19102` 测试套件，全套 110 个单元测试零缺陷通过，同时包含严格的防即时误触断言。
  2. **批量控制面板情景预设矩阵打通与关机持续机时归零闭环 (`AppModel.swift` / `BatchControlView.swift` / `VoiceCapsuleWindowController.swift`)**：
     - **`AppModel.applyScene` 原生多设备批量分发支持**：升级方法签名支持 `targetDeviceIds: [String]?`，支持用户对任意多选设备一键统一下发情景动作，只分发给就绪可控设备并提供精准的聚合通知（如“已应用至所选 2 台空调（4 项动作）”）；
     - **批量控制面板 `BatchControlPanel` 新增情景预设快捷胶囊**：在批量控制面板中新增情景预设快捷网格，选中多台设备时直观展示情景胶囊卡片（🌙 睡眠、🚪 离家、🏠 回家等），支持一键批量下发；
     - **关机持续运行时间清零闭环**：修复应用情景执行关机动作（`onOffStatus == false`）时未重置 `deviceContinuousMinutes` 的缺陷，确保关机后运行机时即刻归零；
     - **计划调度到点触发本地属性即时同步**：在 `fireDueActions` 到点下发指令时，对本地设备属性执行即时乐观更新，并在定时关机时重置持续运行时间，使本地 UI 界面立刻与实际状态保持自洽，告别网关长延迟回读。

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
   - **核心关键词长词截断与漏识别缺陷 (P1 修复)**：在自然语言周期排班中，`rangeWithKeywordRegex`、`keywordWithRangeRegex` 等正则原先仅列出基础词汇，且 `单休` 排在 `单休日` 前面导致正则贪婪提取把“单休日”截断成“单休”，极性由周日误变为周一至周六；同时漏纳了“大休日”、“小休日”、“大周”、“小周”。本次重构统一纳入 `daysFromKeyword` 并校准 alternation 顺序，全面消除了该长词截断隐患；
   - **批量控制面板情景预设缺失 (高价值体验优化)**：用户在 `BatchControlPanel` 批量控制多台设备时，原先只能设置基础温度模式，缺少一键应用“睡眠”、“离家”、“回家”等情景的能力。本次在 `BatchControlPanel` 增加专属快捷胶囊矩阵，并在 `AppModel.applyScene` 原生支持 `targetDeviceIds: [String]?` 批量分发；
   - **定时任务到点 UI 状态不同步与机时未清零缺陷 (P2 修复)**：在 `fireDueActions` 执行到点任务时，补齐了本地属性乐观更新与关机运行时间清零，使调度任务执行后状态栏与卡片界面即刻生效。

---

## 3. 关键架构变更与代码实现

### 3.1 核心关键词全景扩充与长词优先正则校准
- **`VoiceCommandParser.swift`**：
  ```swift
  /// 将正向自然口语核心关键词映射为标准星期集合 (v1.9.101, v1.9.102 全景大一统核心关键词引擎)
  private static func daysFromKeyword(_ kw: String) -> Set<Int>? {
      if kw == "工作日" || kw == "平时" || kw == "平日" {
          return [2, 3, 4, 5, 6]
      } else if kw == "周末" || kw == "双休" || kw == "双休日" || kw == "休息日" || kw == "公休日" || kw == "休假日" || kw == "放假日" || kw == "节假日" || kw == "大休" || kw == "大休日" || kw == "大周" {
          return [1, 7]
      } else if kw == "单休" {
          return [2, 3, 4, 5, 6, 7]
      } else if kw == "小休" || kw == "小休日" || kw == "小周" || kw == "单休日" {
          return [1]
      } else if kw == "周末三天" {
          return [1, 6, 7]
      }
      return nil
  }
  ```

### 3.2 情景动作多设备批量分发与关机机时清零闭环
- **`AppModel.swift`**：
  ```swift
  func applyScene(_ scene: ScenePreset, targetDeviceId: String? = nil, targetDeviceIds: [String]? = nil, allDevices: Bool = false) {
      ...
      for action in scene.actions {
          guard let value = action.value else { continue }
          let targets: [String] = {
              if allDevices {
                  return defaultTargets
              } else if let ids = targetDeviceIds, !ids.isEmpty {
                  return ids
              } else if let targetDeviceId = targetDeviceId, !targetDeviceId.isEmpty {
                  return [targetDeviceId]
              } else if !action.deviceId.isEmpty {
                  return [action.deviceId]
              } else {
                  return defaultTargets
              }
          }()
          for deviceId in targets where !deviceId.isEmpty {
              guard reachability(for: deviceId).isControllable else { continue }
              gatewayHandle?.sendControl(deviceId: deviceId, attributes: [action.attrName: value.jsonValue], completion: nil)
              // 乐观更新
              if var map = attributes[deviceId], let old = map[action.attrName] {
                  map[action.attrName] = old.updating(value: value)
                  attributes[deviceId] = map
              }
              if action.attrName == "onOffStatus" && value.boolValue == false {
                  deviceContinuousMinutes[deviceId] = 0
              }
              controlledDeviceIds.insert(deviceId)
              sent += 1
          }
      }
      ...
  }
  ```

### 3.3 批量控制面板打通情景预设快捷胶囊
- **`BatchControlView.swift`**：
  ```swift
  // 批量情景预设快捷下发 (v1.9.102 矩阵打通)
  if !model.scenes.isEmpty {
      VStack(alignment: .leading, spacing: 6) {
          HStack {
              Label("情景预设（\(model.scenes.count) 项）", systemImage: "sparkles")
                  .font(.system(size: 11, weight: .medium))
                  .foregroundStyle(Theme.inkSubtle)
              Spacer()
          }
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
              ForEach(model.scenes) { scene in
                  Button {
                      model.applyScene(scene, targetDeviceIds: deviceIds)
                  } label: { ... }
              }
          }
      }
      .disabled(!isBatchAvailable)
      .opacity(isBatchAvailable ? 1.0 : 0.6)
  }
  ```

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **110 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 执行 `./build_app.sh`：
   - 顺利生成 App 产物 `dist/HaierAC.app` 与发布安装包 `dist/HaierAC-v1.9.102-macOS.zip`（体积 2.8MB，内置桌面小组件扩展与签名）。

---

## 5. 发版信息与提交记录
- **Git Commit**：`feat & fix: 闭环大休小休/大周小周/单休日全核心关键词大一统调度、批量情景预设矩阵打通与计划任务到点状态即时同步 (v1.9.102)`
- **Git Tag**：`v1.9.102`
- **Release Asset**：`dist/HaierAC-v1.9.102-macOS.zip`
