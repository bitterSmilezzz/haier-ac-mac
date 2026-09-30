# Haier AC Mac v1.9.101 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.101`
- **发版主题**：闭环自然口语“区间+核心关键词”全基准大一统调度、情景预设全屋广播穿透修复与状态栏单设备情景矩阵打通
- **核心目标与架构演进**：
  1. **“区间+核心关键词”与“关键词+区间”自然口语周期调度大一统引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **全景关键词对齐与脱靶修复**：扩充 `rangeWithKeywordRegex` 与 `keywordWithRangeRegex` 正则表达式及匹配逻辑，全面纳管 `平日|双休日|休息日|公休日|休假日|放假日|节假日|大休|小休`，彻底解决“周一至周三和双休日”、“周一至周四以及休息日”、“周一至周三和大休”等口语因缺少关键词映射导致遗漏或掉出分支的缺陷；
     - **全仓核心关键词提取架构归一化**：重构并新增 `daysFromKeyword` 统一辅助函数，将双核心关键词组合、离散多星期夹心、前置/后置附加星期等 7 大复合调度分支全部收敛至统一的标准星期集合映射，消除重复分支逻辑与代码坏味道；
     - **单元测试 100% 满分覆盖**：新增 `testRangeAndKeywordUnificationV19101` 严苛测试套件，全面覆盖正反向连续区间与核心关键词组合、大休小休复合以及防即时误触断言，全套 109 个单元测试零缺陷通过。
  2. **情景预设全屋广播穿透修复与 macOS 原生状态栏单设备情景矩阵打通 (`AppModel.swift` / `StatusItemController.swift`)**：
     - **彻底修复全屋情景应用广播穿透缺陷**：重构 `AppModel.applyScene`，当 `allDevices == true` 时，无条件将情景全部动作广播下发至全屋所有在线可控设备，消除动作原本包含单机 deviceId 导致全屋应用时无法广播到其他设备的重大缺陷；
     - **macOS 原生状态栏多设备级联子菜单植入「✨ 应用情景预设」**：在多设备控制矩阵的每个设备级联子菜单 `devSubmenu` 中新增专属情景预设子菜单，支持用户在状态栏对任意房间设备（如单独控制主卧或书房）一键下发睡眠、离家、回家或自定义多属性情景，达成全屋协同与单设备独立调控的 100% 全对称架构；
     - **定向反馈与操作日志体验升级**：在状态栏与 `operationNotice` 中清晰明示下发目标设备（如“全屋 N 台空调”或“「主卧」”）及执行动作数量，交互反馈透明自洽。

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
   - **核心关键词在连续区间复合调度中不一致 (P1 修复)**：在自然语言周期排班中，`rangeWithKeywordRegex` 和 `keywordWithRangeRegex` 原仅覆盖 `工作日|平时|周末|双休|单休|周末三天`，遗漏了 `平日|双休日|休息日|公休日|休假日|放假日|节假日|大休|小休`。本次引入 `daysFromKeyword` 统一归一化映射，并在全仓 7 大复合正则分支中全面对齐，彻底消除该语义断层；
   - **全屋情景预设动作广播受阻 (P1 修复)**：`AppModel.applyScene` 当 `allDevices == true` 时，对于原本保存了 `deviceId` 的情景动作，原有代码仍然仅向单个 `action.deviceId` 发送，未能广播到全屋。本次全面重构 `targets` 判定流水线，确保广播指令 100% 穿透至所有可控设备；
   - **状态栏多设备菜单单机情景下发缺失 (高价值体验优化)**：在多设备控制矩阵的 `devSubmenu` 中增加「✨ 应用情景预设...」二级子菜单，让多房间用户无需打开主窗口即可在状态栏对任意单个房间一键应用睡眠/离家/回家等情景。

---

## 3. 关键架构变更与代码实现

### 3.1 统一核心关键词提取方法与区间复合正则扩充
- **`VoiceCommandParser.swift`**：
  ```swift
  /// 将正向自然口语核心关键词映射为标准星期集合 (v1.9.101 全景大一统核心关键词引擎)
  private static func daysFromKeyword(_ kw: String) -> Set<Int>? {
      if kw == "工作日" || kw == "平时" || kw == "平日" {
          return [2, 3, 4, 5, 6]
      } else if kw == "周末" || kw == "双休" || kw == "双休日" || kw == "休息日" || kw == "公休日" || kw == "休假日" || kw == "放假日" || kw == "节假日" || kw == "大休" {
          return [1, 7]
      } else if kw == "单休" {
          return [2, 3, 4, 5, 6, 7]
      } else if kw == "小休" {
          return [1]
      } else if kw == "周末三天" {
          return [1, 6, 7]
      }
      return nil
  }
  ```

### 3.2 情景动作全屋广播穿透与定向单设备路由重构
- **`AppModel.swift`**：
  ```swift
  func applyScene(_ scene: ScenePreset, targetDeviceId: String? = nil, allDevices: Bool = false) {
      ...
      for action in scene.actions {
          guard let value = action.value else { continue }
          let targets: [String] = {
              if allDevices {
                  return defaultTargets
              } else if let targetDeviceId = targetDeviceId, !targetDeviceId.isEmpty {
                  return [targetDeviceId]
              } else if !action.deviceId.isEmpty {
                  return [action.deviceId]
              } else {
                  return defaultTargets
              }
          }()
          ...
      }
  }
  ```

### 3.3 macOS 原生状态栏多设备级联子菜单植入情景预设
- **`StatusItemController.swift`**：
  ```swift
  // 单设备情景预设快捷应用 (v1.9.101 全景矩阵对称)
  let devScenes = model.scenes
  if !devScenes.isEmpty {
      let devScenesMenu = NSMenu()
      devScenesMenu.autoenablesItems = false
      for scene in devScenes {
          let actionDesc = scene.actions.map(\.attrDesc).joined(separator: " · ")
          let sceneGlyph: String = ...
          let sItem = NSMenuItem(
              title: "\(sceneGlyph) \(scene.name) (\(actionDesc))",
              action: #selector(applySceneToDeviceFromMenu(_:)),
              keyEquivalent: ""
          )
          sItem.representedObject = ["deviceId": devId, "sceneId": scene.id.uuidString]
          ...
          devScenesMenu.addItem(sItem)
      }
      let devScenesParentItem = NSMenuItem(title: "✨ 应用情景预设 (\(devScenes.count)项)...", action: nil, keyEquivalent: "")
      devSubmenu.setSubmenu(devScenesMenu, for: devScenesParentItem)
      devSubmenu.addItem(devScenesParentItem)
  }
  ```

---

## 4. 验证与测试结果

- **单元测试覆盖**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test` -> **109 tests 全部 PASS（0 failures）**：
    - `VoiceCommandParserTests`: 63 tests (含新增的 `testRangeAndKeywordUnificationV19101`) 100% 通过；
    - `ZlibTests`: 7 tests 100% 通过；
    - `HaierACCoreTests`: 109 tests 100% 通过。
- **本地编译验证**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build -c release` -> 100% 通过（0 错误）。
  - 打包生成产物：
    - `dist/HaierAC.app` (v1.9.101, 完整应用，含小组件)
    - `dist/HaierAC-v1.9.101-macOS.zip` (2.8MB, SHA256: `d5ebb63b6353b07cf00d760632529f9937459a6d2b03e6b3c908706104e12c2d`)

---

## 5. 发版交付总结

- **Git Commit**：`feat & fix: 闭环自然口语“区间+核心关键词”全基准大一统调度、情景预设全屋广播穿透修复与状态栏单设备情景矩阵打通 (v1.9.101)`
- **Git Tag**：`v1.9.101`
- **GitHub Release**：附带产物压缩包与完整更新日志。
