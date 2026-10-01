# Haier AC Mac v1.9.109 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.109`
- **发版主题**：闭环三关键词与区间四元调度全景大一统、自清洁全生命周期阻尼感知及菜单栏控制中心全屋电源快捷联动
- **核心目标与架构演进**：
  1. **“三核心关键词与单区间四元全景复合调度、连词‘同’全纳管”自然口语调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **三关键词在先四元调度拓扑补全**：新增 `triKeywordsWithRangeRegex`（三核心关键词在先+单连续区间在后，如“大休、小休和单休日加周一至周三每天晚8点开机” `[1, 2, 3, 4, 7]`、“工作日、双休同单休加周六至周日每天晚8点开机” `[1..7]`），消灭前置三词贪婪无法匹配漏洞；
     - **区间在先三关键词在后四元调度拓扑补全**：新增 `rangeWithTriKeywordsRegex`（单连续区间在先+三核心关键词在后，如“周一至周三加双休、大休和小休每天晚8点开机” `[1, 2, 3, 4, 7]`、“周六至周日同工作日、大休和单休每天早7点开机” `[1..7]`），彻底补齐四元排班拓扑中 3 关键词与 1 区间的全部组合；
     - **自然口语连词“同”全纳管**：在 `rangeWithDualKeywordsRegex`、`dualRangeWithDualKeywordsRegex`、`dualKeywordsWithDualRangeRegex`、`dualKeywordsWithRangeRegex` 等正则中全面补齐口语常见连词 `同`（如“大休同小休加周一至周三”、“周一至周三同大休和小休”），根除连词断裂导致的漏词缺陷；
     - **单元测试 100% 满分覆盖**：新增 `testQuadScheduleTriKeywordsAndRangeV19109` 严苛测试套件，全套 117 个单元测试零缺陷通过，杜绝误触。
  2. **蒸发器自清洁全生命周期阻尼感知与健康度动力学自洽 (`AppModel.swift` / `FilterCareSheet.swift`)**：
     - **自清洁保护期全生命周期纳管**：重构 `isSelfCleaningProtectionActive(for:)`，从固定 7 天扩充至覆盖自清洁后 14 天完整周期（含 7 天全效期及 7~14 天 C^0 级平滑阻尼过渡期），消除第 7 天后台仍在享受减免而 UI 保护状态截断消失的割裂；
     - **健康度与负荷减免动态感知**：新增 `selfCleaningDiscountPercentage(for:)`，在保养弹窗中动态感知当前实际负荷减免（0~7天显示“56°C除菌保养激励 (-10%负荷)”，7~14天动态显示“56°C除菌阻尼激励 (-X.X%负荷)”），达成 UI 与热物理动力学模型之间的严密自洽。
  3. **macOS 菜单栏 Bento 控制中心快捷开关 Bento 全屋电源快捷联动 (`MenuBarControlsView.swift`)**：
     - **多设备全屋电源快捷管理**：在多联机（>1台）环境下，快捷开关矩阵在单机开关旁提供“全屋电源快捷联动”按钮（全屋有开机时直观展示“全屋全关 (N)”，全待机时支持“全屋开机”）；
     - **三位一体全屋对称架构**：与一键情景 Bento、目标温度 Bento 完美呼应，构成 macOS 菜单栏控制中心的情景、温控、电源三位一体全屋/单机双态对称体系。

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
   - **自清洁全生命周期阻尼感知断层消除 (P1 优化)**：消除了第 7~14 天 UI 激励徽章提前消失的断层，建立动态减免百分比展示；
   - **三关键词与单区间四元排班拓扑补齐 (P0 修复)**：补齐了三关键词在前与在后的两类四元排班正则，统一纳管口语连词“同”，消灭了极端复合排班的词尾丢失问题；
   - **菜单栏控制中心全屋电源快捷联动闭环 (P1 优化)**：让菜单栏快捷控制在多联机环境下具备一键管理全屋电源的能力，形成全屋三位一体对称架构。

---

## 3. 关键架构变更与代码实现

### 3.1 三核心关键词与单区间四元复合排班与连词“同”纳管
- **`VoiceCommandParser.swift`**：
  ```swift
  // 三核心关键词在先、连续区间在后
  private static let triKeywordsWithRangeRegex: NSRegularExpression? = {
      let pattern = #"(工作日|平时|...)\s*(?:[、,，和与及跟同以及还有或者或加/／\s]+)\s*(工作日|平时|...)\s*(?:[、,，和与及跟同以及还有或者或加/／\s]+)\s*(工作日|平时|...)\s*(?:[、,，和与及跟同以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])"#
      return try? NSRegularExpression(pattern: pattern)
  }()

  // 连续区间在先、三核心关键词在后
  private static let rangeWithTriKeywordsRegex: NSRegularExpression? = {
      let pattern = #"(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟同以及还有或者或加/／\s]+)\s*(工作日|平时|...)\s*(?:[、,，和与及跟同以及还有或者或加/／\s]+)\s*(工作日|平时|...)\s*(?:[、,，和与及跟同以及还有或者或加/／\s]+)\s*(工作日|平时|...)"#
      return try? NSRegularExpression(pattern: pattern)
  }()
  ```

### 3.2 自清洁全生命周期阻尼感知与动态减免
- **`AppModel.swift`**：
  ```swift
  public func isSelfCleaningProtectionActive(for deviceId: String) -> Bool {
      guard let lastDate = deviceSelfCleaningDates[deviceId] else { return false }
      let elapsed = Date().timeIntervalSince(lastDate)
      return elapsed >= 0 && elapsed < 14 * 86400
  }

  public func selfCleaningDiscountPercentage(for deviceId: String) -> Double {
      let factor = selfCleaningProtectionFactor(for: deviceId)
      return max(0.0, (1.0 - factor) * 100.0)
  }
  ```
- **`FilterCareSheet.swift`**：
  依据 `selfCleaningDiscountPercentage` 动态渲染 0~7 天全效激励与 7~14 天平滑阻尼过渡激励。

### 3.3 控制中心快捷开关 Bento 全屋电源快捷联动
- **`MenuBarControlsView.swift`**：
  在多设备（`allDevices.count > 1`）场景下，快捷开关 Bento 增加全屋电源操作按键（`全屋全关 (N)` / `全屋开机`），调用 `turnOffAllDevices()` 与 `turnOnAllDevices()`。

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **117 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build -c release`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 执行 `./build_app.sh 1.9.109`：
   - 顺利生成 App 产物 `dist/HaierAC.app` 与发布安装包 `dist/HaierAC-v1.9.109-macOS.zip`（体积 2.9MB，SHA256: `7536c51c8ca1c99a8497b32b8f047f2596e19663f4f1741d4745fa19b3fbd29f`）。

---

## 5. 发版信息与提交记录
- **Git Commit**：`feat & fix: 闭环三关键词与区间四元调度全景大一统、自清洁全生命周期阻尼感知及菜单栏控制中心全屋电源快捷联动 (v1.9.109)`
- **Git Tag**：`v1.9.109`
- **Release Asset**：`dist/HaierAC-v1.9.109-macOS.zip`
- **SHA256**：`7536c51c8ca1c99a8497b32b8f047f2596e19663f4f1741d4745fa19b3fbd29f`
