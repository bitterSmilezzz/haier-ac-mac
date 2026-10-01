# Haier AC Mac v1.9.110 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.110`
- **发版主题**：闭环交替四元与纯四/三关键词全景调度、状态栏自清洁阻尼全景感知及节能管家能耗激励动态联动
- **核心目标与架构演进**：
  1. **“交替四元调度全景拓扑完备、纯四/三核心关键词大一统与连词全纳管”自然口语调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **交替四元调度拓扑全景完备闭环**：补齐双连续区间与双核心关键词在数学排列中的最后 2 种交替排列拓扑：
       - `rangeWithKeywordAndRangeWithKeywordRegex`（区间在先+核心词居中+区间+核心词在后，如“周一至周二加大休同周四至周五加小休每天晚8点开机” `[1, 2, 3, 5, 6, 7]`、“周一到周二加工作日和周六至周日加单休每天早8点开机” `[1..7]`）；
       - `keywordWithRangeAndKeywordWithRangeRegex`（核心词在先+区间+核心词+区间在后，如“大休加周一至周二同小休加周四至周五每天晚8点开机” `[1, 2, 3, 5, 6, 7]`、“工作日加周六至周日和单休加周一至周二每天早7点关机” `[1..7]`）；
       达成 2 区间 + 2 关键词的全部 6 种数学组合 $\binom{4}{2} = 6$ 100% 完备自洽；
     - **纯四核心关键词与纯三核心关键词全景调度大一统**：新增 `quadKeywordsRegex`（如“工作日、双休、大休和小休每天晚8点开机” `[1..7]`）与 `triKeywordsRegex`（如“大休、小休和单休每天晚8点开机” `[1..7]`、“工作日、双休同单休每天早7点关机” `[1..7]`、“大休、小休和单休日每天晚8点开机” `[1, 7]`），彻底根除因缺少纯多关键词正则导致的口语截断与末尾词悬挂遗漏缺陷；
     - **排除型反相调度自动贯通**：交替四元与纯四/三核心关键词能力无缝穿透至 `parseExclusionRepeatWeekdays`（如“除周一至周二加大休同周四至周五加小休外每天早8点开机”精准计算为 `[4]` 每周三、“除了大休、小休和单休日外每天早8点开机”精准计算为 `[2, 3, 4, 5, 6]` 工作日、“除了工作日、双休、大休和小休每天早8点开机”安全拦截零天执行）；
     - **单元测试 100% 满分覆盖**：新增 `testAlternatingQuadScheduleAndPureQuadTriKeywordsV19110` 严苛测试套件，全套 118 个单元测试 100% 零缺陷通过，杜绝误触。
  2. **macOS 原生状态栏蒸发器自清洁全生命周期阻尼全景感知 (`StatusItemController.swift`)**：
     - **状态栏悬浮 Tooltip 自清洁保护期状态全感知**：在菜单栏图标鼠标悬浮感知看板中，实时探测全屋空调自清洁状态，若处于 14 天自清洁保护期，动态提示“✨ 「设备名」蒸发器自清洁健康保护生效中 (全效减免 10%/阻尼减免 X.X%负荷)”或“全屋 N 台空调蒸发器自清洁健康保护生效中 (动态阻尼节能减负)”；
     - **滤网全景与单机健康看板自洽重构**：全景健康面板中将静态标签升级为动态阻尼激励标签（`✨[自清洁全效激励 -10%]` / `✨[自清洁阻尼激励 -X.X%]`）；单机维护详情面板中消除“7天内”硬编码，动态呈现当前所处的“全效健康保护期（负荷减免 10%）”或“平滑阻尼过渡期（动态减免 X.X% 负荷）”，彻底终结信息断层。
  3. **节能减排管家 Bento 卡片蒸发器自清洁健康保养能效减免动态激励 (`EcoEnergySection.swift` / `MenuBarControlsView.swift`)**：
     - **自清洁能耗减免物理感知胶囊**：在能耗与电费估算卡片中，深度连通 `AppModel` 自清洁平滑阻尼物理模型，当设备处于自清洁保护期时，动态呈现绿色“自清洁能效激励”卡片，直观告知用户 56°C 高温除菌带来的热阻消除与动态能耗负荷减免；
     - **可达性判定一致性加固**：控制中心快捷开关 Bento 统一接入 `.isControllable` 判定，消灭局部视图状态判定分叉。

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
   - **状态栏滤网自清洁阻尼提示断层与硬编码消除 (P1 修复)**：消除了状态栏中遗留的“7天内”硬编码描述，全面对齐 14 天 C^0 级平滑阻尼模型及动态负荷减免百分比；并在状态栏主图标 Tooltip 中增加保护期感知；
   - **交替四元调度拓扑与纯四/三关键词拓扑补齐 (P0 修复)**：补齐了 2 区间 + 2 关键词的全部 6 种数学组合排列，支持交替穿插排班及纯多关键词复合排班，消灭了口语截断缺陷；
   - **能耗管家自清洁能效减免动态感知与门禁加固 (P1 优化)**：在 EcoEnergySection 中新增动态能效激励感知卡片，直观呈现 56°C 除菌对换热能效的改善，加固 MenuBarControlsView 可达性判定。

---

## 3. 关键架构变更与代码实现

### 3.1 交替四元调度与纯多关键词排班引擎
- **`VoiceCommandParser.swift`**：
  ```swift
  // 连续区间在先、核心关键词居中、连续区间、核心关键词在后
  private static let rangeWithKeywordAndRangeWithKeywordRegex: NSRegularExpression? = {
      let pattern = #"(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟同以及还有或者或加/／\s]+)\s*(工作日|平时|...)\s*(?:[、,，和与及跟同以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟同以及还有或者或加/／\s]+)\s*(工作日|平时|...)"#
      return try? NSRegularExpression(pattern: pattern)
  }()

  // 核心关键词在先、连续区间、核心关键词、连续区间在后
  private static let keywordWithRangeAndKeywordWithRangeRegex: NSRegularExpression? = {
      let pattern = #"(工作日|平时|...)\s*(?:[、,，和与及跟同以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟同以及还有或者或加/／\s]+)\s*(工作日|平时|...)\s*(?:[、,，和与及跟同以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])"#
      return try? NSRegularExpression(pattern: pattern)
  }()

  // 纯四核心关键词与纯三核心关键词
  private static let quadKeywordsRegex: NSRegularExpression? = { ... }()
  private static let triKeywordsRegex: NSRegularExpression? = { ... }()
  ```

### 3.2 状态栏自清洁全生命周期阻尼全景感知
- **`StatusItemController.swift`**：
  ```swift
  let protectedDevices = allDevices.filter { model.isSelfCleaningProtectionActive(for: $0.id) }
  if !protectedDevices.isEmpty {
      if protectedDevices.count == 1, let dev = protectedDevices.first {
          let discount = model.selfCleaningDiscountPercentage(for: dev.id)
          let desc = discount >= 9.9 ? "全效减免 10%" : String(format: "阻尼减免 %.1f%%", discount)
          tooltipParts.append("✨ 「\(dev.name)」蒸发器自清洁健康保护生效中 (\(desc)负荷)")
      } else {
          tooltipParts.append("✨ 全屋 \(protectedDevices.count) 台空调蒸发器自清洁健康保护生效中 (动态阻尼节能减负)")
      }
  }
  ```

### 3.3 节能管家自清洁能效减免动态激励
- **`EcoEnergySection.swift`**：
  当受控机组处于自清洁保护期内，卡片动态展示“自清洁能效激励”卡片，让用户直观获知保养带来的负荷减免收益。

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **118 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build -c release`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 执行 `./build_app.sh 1.9.110`：
   - 顺利生成 App 产物 `dist/HaierAC.app` 与发布安装包 `dist/HaierAC-v1.9.110-macOS.zip`（体积 2.9MB，SHA256: `591e2c1f02bbf0ef5ece0a0a44911fd8ae15280f4aebf5b0d31202684b857dfd`）。

---

## 5. 发版信息与提交记录
- **Git Commit**：`feat & fix: 闭环交替四元与纯四/三关键词全景调度、状态栏自清洁阻尼全景感知及节能管家能耗激励动态联动 (v1.9.110)`
- **Git Tag**：`v1.9.110`
- **Release Asset**：`dist/HaierAC-v1.9.110-macOS.zip`
- **SHA256**：`591e2c1f02bbf0ef5ece0a0a44911fd8ae15280f4aebf5b0d31202684b857dfd`
