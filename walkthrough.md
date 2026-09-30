# Haier AC Mac v1.9.107 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.107`
- **发版主题**：闭环口语夹心四元/三元调度与连词纳管、机组热容物理衰减自洽及状态栏情景与倒计时门禁加固
- **核心目标与架构演进**：
  1. **“核心关键词与连续区间夹心四元/三元调度、口语连词‘同’全景纳管”自然口语调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **核心关键词与连续区间夹心复合调度引擎**：新增 `keywordWithRangeAndKeywordRegex`（核心词在前+连续区间居中+核心词在后，如“大休、周一至周三加小休每天晚8点开机” `[1, 2, 3, 4, 7]`、“工作日加周六至周日和单休每天晚8点开机” `[1..7]`、“平时加周六至周日和大休每天晚8点开机” `[1..7]`、“双休加周一至周三加小休每天晚8点开机” `[1, 2, 3, 4, 7]`），彻底消灭前置区间正则贪婪截断导致末尾核心词丢失或时间/动作指令解析错位的顽疾；
     - **四元交替夹心全景拓扑大一统**：新增 `rangeWithDualKeywordsAndRangeRegex`（区间在先+双核心词居中+区间在后，如“周一至周二、大休和小休加周五至周六每天晚8点开机” `[1, 2, 3, 6, 7]`）与 `keywordWithDualRangeAndKeywordRegex`（核心词在先+双区间居中+核心词在后，如“大休、周一至周二、周四至周五加小休每天晚8点开机” `[1, 2, 3, 5, 6, 7]`），四元周期全排列拓扑自洽闭环；
     - **自然口语连词“同”全景纳管防断裂**：在 `implicitExclusionRepeatRegex` 负向预查断言与 `extractExcludedDays` 中全面补齐口语常见连词 `同`（如“除了周末同大休每天早8点开机”、“除周末同大休外每天早8点开机”），根除连词缺失导致的预查断裂隐患；
     - **单元测试 100% 满分覆盖**：新增 `testInterleavedRangeAndKeywordScheduleHardeningV19107` 测试套件，全套 115 个单元测试零缺陷通过，杜绝误触。
  2. **闭环变频机组热容量物理散热衰减模型在手动关机/开机/场景/定时触发时的强行置零冲突 (`AppModel.swift`)**：
     - 彻底清理 `sendAttribute`、`sendAttributeToDevices`、`turnOffDevices`、`applyScene` 与 `triggerAction` 5 处历史遗留的手动清零代码；
     - 变频机组换热器连续机时热阻阻抗与热饱和度严格遵循牛顿冷却物理散热衰减模型（待机时 3x 线性散热衰减），短时间关机/调档再开机平滑继承换热器残余物理热容量，长时间待机（连续 40~60 分钟以上）自然彻底冷却归零，消除算法自相矛盾。
  3. **macOS 原生状态栏与菜单栏控制中心情景预设及快捷倒计时可达性全状态门禁 (`StatusItemController.swift` / `MenuBarControlsView.swift`)**：
     - **状态栏情景预设可达性门禁精细化**：状态栏顶层「一键情景预设」子菜单中的「应用至主显设备」、「应用至全屋所有空调」及单设备项全面接入设备可达性（Reachability）精准判定，设备物理离线时灰显并禁用，杜绝无效点击；
     - **快捷倒计时调度门禁补齐**：状态栏「快捷倒计时调度」子菜单中的单机倒计时与全屋关机/开机预冷预热项全面补齐 `isEnabled` 门禁与离线防护；
     - **菜单栏 Bento 控制中心「一键情景」动态禁用与透明度同步**：根据当前选定生效范围（当前机/全屋），动态感知设备连通性与可达性状态，未连网或无可控设备时平滑禁用并呈现 0.6 不透明度防护态。

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
   - **变频机组热容量物理散热模型与手动控制强行置零的冲突 (P1 修复)**：在 v1.9.106 引入牛顿冷却连续性衰减模型后，`AppModel` 中 5 处历史遗留的开关机置零逻辑依然强制生效，导致用户手动操作、定时触发或场景应用时机组热容被瞬间粗暴清零。本轮彻底移除该强制置零逻辑，使热饱和度完全受物理衰减曲线接管；
   - **口语夹心排班正则缺失导致词尾截断 (P0 修复)**：当用户说出“大休、周一至周三加小休”或“工作日加周六至周日和单休”时，由于缺乏夹心排班宏，正则贪婪截断导致末尾核心词被当成正文残留或丢弃。本轮完整补齐夹心三元与四元排班正则引擎；
   - **原生状态栏与控制中心情景/倒计时离线可达性门禁穿透 (P1 修复)**：状态栏中的情景子菜单与快捷倒计时菜单原先仅判定网关连接，未判定具体目标设备物理在线状态。本轮全面接入 Reachability 门禁并同步控制中心动态透明度。

---

## 3. 关键架构变更与代码实现

### 3.1 夹心四元与三元复合宏正则与连词“同”纳管
- **`VoiceCommandParser.swift`**：
  ```swift
  // 核心关键词在前、连续区间居中、核心关键词在后夹心复合口语
  private static let keywordWithRangeAndKeywordRegex: NSRegularExpression? = {
      let pattern = #"(工作日|平时|平日|双休日|双休|周末三天|周末|休息日|公休日|休假日|放假日|节假日|单休日|单休|大休日|大休|大周|小休日|小休|小周)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(工作日|平时|平日|双休日|双休|周末三天|周末|休息日|公休日|休假日|放假日|节假日|单休日|单休|大休日|大休|大周|小休日|小休|小周)"#
      return try? NSRegularExpression(pattern: pattern)
  }()

  // 连续区间在先、双核心关键词居中、连续区间在后
  private static let rangeWithDualKeywordsAndRangeRegex: NSRegularExpression? = {
      let pattern = #"(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(工作日|平时|平日|双休日|双休|周末三天|周末|休息日|公休日|休假日|放假日|节假日|单休日|单休|大休日|大休|大周|小休日|小休|小周)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(工作日|平时|平日|双休日|双休|周末三天|周末|休息日|公休日|休假日|放假日|节假日|单休日|单休|大休日|大休|大周|小休日|小休|小周)\s*(?:[、,，和与及跟以及还有或者或加/／\s]+)\s*(?:每|逢|每逢)?(?:个)?(?:周|星期|礼拜)([一二三四五六日天1-7])\s*(?:到|至|-|~)\s*(?:周|星期|礼拜)?([一二三四五六日天1-7])"#
      return try? NSRegularExpression(pattern: pattern)
  }()
  ```

### 3.2 变频机组热容量物理散热模型自洽化
- **`AppModel.swift`**：
  移除 `sendAttribute`、`sendAttributeToDevices`、`turnOffDevices`、`applyScene` 与 `triggerAction` 中强制执行的 `deviceContinuousMinutes[deviceId] = 0`，确保机组停机后由 `updateEnergyAnalytics` 中的物理阻尼模型统一接管连续散热。

### 3.3 macOS 状态栏与控制中心情景及倒计时门禁加固
- **`StatusItemController.swift`** / **`MenuBarControlsView.swift`**：
  ```swift
  let isPrimaryControllable = model.gatewayConnected && (primaryId.map { model.reachability(for: $0).isControllable } ?? false)
  let hasControllable = model.gatewayConnected && allDevices.contains { model.reachability(for: $0.id).isControllable }
  
  // 菜单项 isEnabled 完整受控
  pItem.isEnabled = isPrimaryControllable
  applyAllItem.isEnabled = hasControllable
  ```

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **115 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 执行 `./build_app.sh 1.9.107`：
   - 顺利生成 App 产物 `dist/HaierAC.app` 与发布安装包 `dist/HaierAC-v1.9.107-macOS.zip`（体积 2.9MB，内置桌面小组件扩展与签名，SHA256: `e200c905fea5a625e458159ba53f524b3ec56d51b681f2286bd8c8dfb9bfde5f`）。

---

## 5. 发版信息与提交记录
- **Git Commit**：`feat & fix: 闭环口语夹心四元/三元调度与连词纳管、机组热容物理衰减自洽及状态栏情景与倒计时门禁加固 (v1.9.107)`
- **Git Tag**：`v1.9.107`
- **Release Asset**：`dist/HaierAC-v1.9.107-macOS.zip`
- **SHA256**：`e200c905fea5a625e458159ba53f524b3ec56d51b681f2286bd8c8dfb9bfde5f`
