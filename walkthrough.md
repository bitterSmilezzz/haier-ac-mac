# Haier AC Mac v1.9.112 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.112`
- **发版主题**：闭环六核心关键词与五元复合排班大一统调度、控制中心模式风速全屋协同及自清洁能耗连续微补偿
- **核心目标与架构演进**：
  1. **“六核心关键词全景排班、五元复合拓扑拓展与口语排除词全纳管”自然口语调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **纯六核心关键词全景调度 (`hexaKeywordsRegex`)**：新增 `hexaKeywordsRegex`，支持六核心关键词复合排班（如“工作日、平时、双休、大休、小休同单休日每天早8点开机” `[1..7]`），彻底根除关键词超多时的口语截断；
     - **五元复合口语拓扑拓展 (`rangeWithQuadKeywordsRegex` / `quadKeywordsWithRangeRegex`)**：
       - `rangeWithQuadKeywordsRegex`：连续区间在先、四核心关键词在后（如“周三至周四加工作日、双休、大休和小休每天早8点开机” `[1..7]`）；
       - `quadKeywordsWithRangeRegex`：四核心关键词在先、连续区间在后（如“工作日、双休、大休和小休加周三至周四每天早8点开机” `[1..7]`）；
     - **口语排除引导词全面拓展**：在 `extractExcludedDays` 与 `implicitExclusionRepeatRegex` 中新增“除掉”、“排除”、“剔除”、“撇除”，与原有“除开/除去/刨除/扣除/除了”完全对齐；
     - **否定意图防误触加固**：在 `negativeActionRegex` 中增加“绝不能”、“绝不要”、“暂且别”、“先不用”，防止口语闲聊被误识别为开关机动作；
     - **单元测试 100% 满分覆盖**：新增 `testHexaKeywordsAndQuadCompositeV19112` 严苛测试套件，全套 120 个单元测试零缺陷通过（0 failures）。
  2. **能耗动力学蒸发器自清洁洁净度换热效率连续微补偿 (`EnergyAnalyticsEngine.swift` / `AppModel.swift`)**：
     - **自清洁能耗连续微补偿模型 (Evaporator Cleanliness Efficiency Bonus)**：在 `DeviceEnergySample` 与 `estimateInstantaneousPower` 中接入 `cleanlinessFactor`；
     - 结合 56°C 高温自清洁后的翅片热阻降低与风阻减小，在 14 天自清洁保护期内引入连续微补偿热阻尼模型，变频压缩机维持恒温所需电耗享受 0% ~ 4% 平滑节能收益，使物理能耗模拟与自清洁保养生态严密自洽。
  3. **macOS 菜单栏控制中心全屋模式与风速协同 Bento (`MenuBarControlsView.swift`)**：
     - **运行模式与风速全屋/单机双态切换 (`modeScopeAll`)**：在多设备环境下，`modeAndFanPod` 顶部增设作用域切换胶囊（“当前机” / “全屋 (N台运行)”）；
     - 开启全屋模式后，一键将全屋空调统一设为指定模式（制冷/制热/送风/除湿/自动）或指定风速（微风/中风/强劲/自动），并动态感知全屋一致性选中态；
     - 与情景预设 Bento (`sceneScopeAll`)、目标温度 Bento (`tempScopeAll`)、电源快捷管理形成完整的控制中心四位一体全屋协同矩阵。
  4. **macOS 原生状态栏自清洁看板细节优化 (`StatusItemController.swift`)**：
     - 状态栏悬浮 Tooltip 动态标明当前处于 56°C 高温自清洁中的具体机组名称（如“「客厅空调」56°C 高温除菌自清洁进行中”），消除多机环境下的指代模糊。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下审查报告及全仓架构进行了全景复核与缺陷深挖：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 正则结构稳固，本轮进一步纳管“绝不能/绝不要/暂且别/先不用”，穿插插字防御更加严密；
   - **全屋与定向定时解耦 (P1-2)**：`cancelSchedules` 与 `cancelSchedulesAll` 精确分流，多设备批量取消分支全部贯通；
   - **工况占比计算属性消费 (P2-1)**：`EcoEnergySection` 已统一调用 4 个比率属性；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏与 UI 使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **六核心关键词排班与五元复合拓扑 (P1 优化)**：补齐 `hexaKeywordsRegex`、`rangeWithQuadKeywordsRegex`、`quadKeywordsWithRangeRegex`，彻底消灭超多关键词排班与连续区间复合排班口语遗漏缺陷；
   - **口语排除词大一统 (P1 优化)**：纳管“除掉”、“排除”、“剔除”、“撇除”，与全仓现有排除规则达成 100% 结构对称；
   - **蒸发器自清洁能耗动力学闭环 (P1 优化)**：在瞬时功率与采样聚合中接入 `cleanlinessFactor`，在 14 天自清洁保护期内引入连续微补偿热阻尼模型，物理能耗模拟自洽；
   - **控制中心全屋模式与风速协同 (P1 优化)**：在 `modeAndFanPod` 中实现“当前机”与“全屋”双态切换，与情景、调温、电源构成完整的四位一体 Bento 矩阵；
   - **状态栏自清洁机组标头消歧 (P2 优化)**：悬浮 Tooltip 指向明确的自清洁机组名称。

---

## 3. 关键架构变更与代码实现

### 3.1 六核心关键词与五元复合拓扑排班引擎
- **`VoiceCommandParser.swift`**：
  ```swift
  // 六核心关键词全景正则
  private static let hexaKeywordsRegex: NSRegularExpression? = { ... }()

  // 连续区间在先、四核心关键词在后
  private static let rangeWithQuadKeywordsRegex: NSRegularExpression? = { ... }()

  // 四核心关键词在先、连续区间在后
  private static let quadKeywordsWithRangeRegex: NSRegularExpression? = { ... }()
  ```

### 3.2 蒸发器自清洁热力学连续微补偿能耗模型
- **`EnergyAnalyticsEngine.swift`**：
  ```swift
  // 蒸发器自清洁洁净度热阻力与换热效率连续动力学微补偿
  let cleanMultiplier: Double = {
      guard isPowerOn && !isSelfCleaning && cleanlinessFactor < 1.0 else { return 1.0 }
      let bonus = (1.0 - max(0.90, cleanlinessFactor)) * 0.40
      return max(0.95, 1.0 - bonus)
  }()

  let dynamicMultiplier = soakMultiplier * cleanMultiplier
  ```

### 3.3 控制中心模式与风速全屋协同 Bento
- **`MenuBarControlsView.swift`**：
  在 `modeAndFanPod` 顶部增设作用域切换胶囊，支持多设备环境下模式与风速的全屋一键同步。

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **120 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build -c release`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 执行 `./build_app.sh 1.9.112`：
   - 顺利生成 App 产物 `dist/HaierAC.app` 与发布安装包 `dist/HaierAC-v1.9.112-macOS.zip`（SHA256: `a9f3b37756b291ef0c64519eee222af2f37203637ab22b59ee53c1f72e7ae9e1`）。

---

## 5. 发版信息与提交记录
- **Git Commit**：`feat & fix: 闭环六核心关键词与五元复合排班大一统调度、控制中心模式风速全屋协同及自清洁能耗连续微补偿 (v1.9.112)`
- **Git Tag**：`v1.9.112`
- **Release Asset**：`dist/HaierAC-v1.9.112-macOS.zip`
- **SHA256**：`a9f3b37756b291ef0c64519eee222af2f37203637ab22b59ee53c1f72e7ae9e1`
