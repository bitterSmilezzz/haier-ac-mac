# Haier AC Mac v1.9.96 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.96`
- **发版主题**：闭环排除型否定与非单休/非单休日调度脱靶缺陷、Siri 全屋综合状态看板贯通与状态栏待机模式一键唤醒
- **核心目标与架构演进**：
  1. **“排除型否定时态与非单休/非单休日”自然周期循环调度逻辑脱靶缺陷彻底修复与防误触全闭环 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **彻底修复排除型否定时态中“非工作日/非平时/非平日/非周末/非双休/非单休”反相词被正相贪婪匹配导致的 180 度极性颠倒重大缺陷**：此前在排除型模式提取正则与 `extractExcludedDays` 中，由于子串贪婪匹配，导致“除非工作日外每天开机”（意图为非工作日即周末除外，在工作日执行）被错误识别为排除“工作日”，导致仅在周末开机；“除非周末外每天开机”被错误识别为排除“周末”，导致仅在工作日开机；本版本重构了 `exclusionRepeatRegex` 结构化非贪婪捕获边界，并在 `extractExcludedDays` 中建立了前置反相调度拦截（将“非工作日/非平日”排除映射至周末 `[1, 7]` 保留工作日 `[2, 3, 4, 5, 6]`，将“非周末/非双休/非双休日/非休息日”排除映射至工作日 `[2, 3, 4, 5, 6]` 保留周末 `[1, 7]`），彻底消除极性反转缺陷；
     - **彻底修复“单休日”与“逢单休”在排除型语义与基础周期中被“单休”贪婪匹配缺陷**：此前“除单休日外每天开机”中的“单休日”（周日）被贪婪截取识别为“单休”（周一至周六），导致排除了周一至周六仅在周日开机的重大颠倒；“非单休日开机”被截取颠倒为仅周日执行；本版本建立前置精准拦截，将“单休日/逢单休”在排除语义中精准映射为排除周日 `[1]`，保留周一至周六 `[2, 3, 4, 5, 6, 7]`；将“非单休日开机”在基础调度中精准映射为周一至周六 `[2, 3, 4, 5, 6, 7]`；将“非单休开机”精准映射为周末双休 `[1, 7]`；
     - **非单休与非单休日半点时相标准化归一流水线与防即时误触全景加固**：新增“非单休半”、“非单休日半”映射至 08:30；在 `hasTimingOrCountdownIntent` 中全面筑牢时态防线，严禁掉入即时开关机；
     - **单元测试 100% 满分覆盖**：在 `VoiceCommandParserTests.swift` 中新增 `testExclusionAndNonSingleRestScheduleHardeningV1996`，包含 28 组反相排除、单休日排除、非单休调度、半点归一及严苛防即时误触断言，全部通过。
  2. **Siri 与快捷指令 (`AppIntents.swift`) 综合状态看板与 AppShortcuts 索引缺陷闭环 (`AppIntents.swift`)**：
     - **修复 `GetACHumidityIntent` 在 macOS 14.0+ 快捷指令体系中漏注册缺陷**：此前仅在低版本 fallback 分支中注册，导致现代 macOS 无法在系统快捷指令与 Siri 中正确索引湿度查询；本次完成双版本统一注册；
     - **新增 `GetACStatusIntent` 综合状态看板**：支持语音或快捷指令查询单机当前开关机、模式、目标温度、室内温度、相对湿度与风速档位（如“「客厅」正在运行，当前为制冷模式，设定温度 26°C，风速微风，室内温度 25°C，相对湿度 52%”）；支持全屋查询自动汇总运行设备台数、全屋平均室温、平均相对湿度及各设备分布看板；
     - **AppShortcuts 系统无缝索引**：注册“用 Haier AC 查询状态”、“空调状态怎么样”等快捷短语。
  3. **macOS 原生状态栏待机模式一键唤醒与温控按钮极值防护 (`StatusItemController.swift` / `MenuBarControlsView.swift` / `DeviceControlView.swift`)**：
     - **单设备与矩阵设备专属运行模式待机一键唤醒**：优化状态栏单设备与多设备右键菜单中的「🔄 运行模式」子菜单，放开 `isPowerOn` 门禁（保留 `isControllable` 网关与离线防护），允许设备待机时直接点击目标模式（如制热、除湿）一键唤醒并平滑切入该模式，杜绝了必须先开旧模式吹冷/热风再二次进菜单切模式的繁琐断层；
     - **状态栏 Tooltip 与标题文案自适应**：待机时呈现“🔄 运行模式 (待机中 · 点击开启模式)”，菜单项智能提示“开启「客厅」并设为制热模式”；
     - **UI 触感与温控极限值（16°C/30°C）边界禁用防护**：在 `MenuBarControlsView.swift` 与 `DeviceControlView.swift` 的目标温度加减 Stepper 按钮中新增 `current <= min` 与 `current >= max` 边界禁用及自适应置灰色彩逻辑，消除极限温区无效网络下发与视觉反馈缺失。

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
   - **排除型反相调度“除非工作日外/除非周末外”极性颠倒重大缺陷 (P0/P1)**：在排除型调度中，“除非工作日外每天开机”由于直接匹配“工作日”导致排除了工作日，星期极性 180 度颠倒；同时“除单休日外每天开机”中的“单休日”（周日）被贪婪截取识别为“单休”（周一至周六），导致排除了周一至周六。本版本在 `extractExcludedDays` 与 `parseBaseRepeatWeekdays` 中建立核心前置反相与单休日识别，完美修复；
   - **Siri Shortcuts macOS 14+ 遗漏湿度 Intent 注册与综合状态查询缺失 (P1/P2)**：macOS 14+ `AppShortcutsProvider` 分支漏掉了 `GetACHumidityIntent`；且缺少一个综合看板让用户一句话掌握空调所有核心状态。本次闭环注册并新增 `GetACStatusIntent`；
   - **状态栏待机状态下无法直接选择模式唤醒 (P2)**：此前在多设备与单设备状态栏菜单中，设备待机时「🔄 运行模式」整组置灰禁用，用户想换模式开机必须先点开机（以之前的旧模式运转），再重新呼出菜单选择模式。本次放开待机模式选择，支持一键开机并切入指定模式。
   - **温度加减 Stepper 触达 16°C/30°C 极限时未禁用 (P2)**：已在 `MenuBarControlsView` 与 `DeviceControlView` 中增加边界防护，按钮禁用并变灰。

---

## 3. 关键架构变更与代码实现

### 3.1 排除型否定与反相时态循环调度修复
- **`VoiceCommandParser.swift` 前置反相与单休日排除提取**：
  ```swift
  // 排除语义中的反相前置拦截 (v1.9.96)
  if excludedText.contains("非工作日") || excludedText.contains("非平日") {
      excludedDays.formUnion([1, 7])
      excludedText = excludedText.replacingOccurrences(of: "非工作日", with: "").replacingOccurrences(of: "非平日", with: "")
  }
  if excludedText.contains("非周末") || excludedText.contains("非双休") || excludedText.contains("非双休日") || excludedText.contains("非休息日") {
      excludedDays.formUnion([2, 3, 4, 5, 6])
      ...
  }
  if excludedText.contains("单休日") || excludedText.contains("逢单休") {
      excludedDays.insert(1) // 周日
      ...
  }
  ```
- **`hasTimingOrCountdownIntent` 严密时态防线**：
  全面纳管“非单休”、“非单休日”、“非单休半”、“非单休日半”等全量口语，杜绝误触立即开关机。

### 3.2 macOS 原生状态栏待机模式一键唤醒
- **`StatusItemController.swift`**：
  ```swift
  // 运行模式子菜单 (v1.9.96: 待机状态放开，允许一键唤醒并切换至指定模式)
  let devModeMenu = NSMenu()
  devModeMenu.autoenablesItems = false
  for itemDef in Self.modeLevels {
      let isSelected = isPowerOn && (modeCode == itemDef.code)
      let check = isSelected ? "✓ " : ""
      let item = NSMenuItem(title: "\(check)\(itemDef.title)", action: #selector(setDeviceModeFromMenu(_:)), keyEquivalent: "")
      item.target = self
      item.representedObject = ["deviceId": devId, "mode": itemDef.code.rawValue]
      item.isEnabled = isControllable // 待机只要在线可控即可一键唤醒并切入模式
      ...
  }
  ```

### 3.3 Siri 综合状态看板与 AppShortcuts 注册闭环
- **`AppIntents.swift`**：
  ```swift
  struct GetACStatusIntent: AppIntent {
      static var title: LocalizedStringResource = "查询空调综合状态"
      static var description = IntentDescription("查询空调当前开关机、模式、温度、湿度与风速状态看板", categoryName: "空调控制")
      ...
  }
  ```

---

## 4. 验证与测试结果

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增并校验端到端单元测试用例（28 组严苛断言 100% PASS）：
  - `"除非工作日外每天开机"` -> `08:00` 开机，工作日循环 (`[2, 3, 4, 5, 6]`) (PASS)
  - `"除非平时外每天开机"` -> `08:00` 开机，工作日循环 (`[2, 3, 4, 5, 6]`) (PASS)
  - `"除非周末外每天关机"` -> `08:00` 关机，周末循环 (`[1, 7]`) (PASS)
  - `"除非双休外每天关机"` -> `08:00` 关机，周末循环 (`[1, 7]`) (PASS)
  - `"除单休日外每天开机"` -> `08:00` 开机，周一至周六循环 (`[2, 3, 4, 5, 6, 7]`) (PASS)
  - `"除逢单休外每天开机"` -> `08:00` 开机，周一至周六循环 (`[2, 3, 4, 5, 6, 7]`) (PASS)
  - `"非单休日开机"` -> `08:00` 开机，周一至周六循环 (`[2, 3, 4, 5, 6, 7]`) (PASS)
  - `"非单休开机"` -> `08:00` 开机，周末双休循环 (`[1, 7]`) (PASS)
  - `"非单休半关机"` -> `08:30` 关机，周末双休循环 (`[1, 7]`) (PASS)
  - `"非单休日半开机"` -> `08:30` 开机，周一至周六循环 (`[2, 3, 4, 5, 6, 7]`) (PASS)
  - 严苛防即时误触断言（针对上述所有口语，严格禁止掉入 `setPower`、`turnOffAll` 或 `turnOnAll` 即时开关机，全部 PASS）。
- **编译与打包校验**：
  - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 警告 0 错误编译通过；
  - 运行 `./build_app.sh 1.9.96` 打包生成 `dist/HaierAC-v1.9.96-macOS.zip` (2.9MB)。

---

## 5. 发版信息与资产交付
- **版本号**：`v1.9.96`
- **Git Tag**：`v1.9.96`
- **Release 资产**：`dist/HaierAC-v1.9.96-macOS.zip`
- **SHA-256**：`8343860b406ade2add71883a12b5875fa1f7732ad43759347815403021f4dd7e`
- **安全敏感数据检查**：经核验，源码与文档均无敏感个人信息、真实 Token 或凭证，符合安全脱敏规范。
