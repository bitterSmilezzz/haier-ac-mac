# Haier AC Mac v1.9.80 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.80`
- **发版主题**：闭环自然口语全天候时相调度大一统引擎、防即时开关机误触与状态栏全交互矩阵 Tooltip 100% 覆盖
- **核心目标与架构演进**：
  1. **自然口语全天候时相调度大一统引擎与防即时开关机误触 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **全天候口语时相词群全景闭环 (白天/日间/白昼/大清早/大半夜/大晚上/天亮/天黑/天明/天蒙蒙亮)**：全面解决自然口语中高频的自然时相独立调度（如“白天关空调”、“白天开机”、“大清早开机”、“大晚上开机”、“大半夜关机”、“天亮开机”、“天亮关空调”、“天黑关空调”、“天明开机”），自适应映射钟点（白天/日间/白昼 08:00，大清早/天亮/天明 06:00，天黑 18:00，大晚上 21:00，大半夜 23:00），彻底消灭以往因缺失显式钟点数字穿透时间 guard 导致直接落入即时开关机分支而造成当前设备误关机/开机的严重故障隐患；
     - **口语半点时相归一流水线全量纳管**：全面覆盖“白天半”(08:30)、“日间半”(08:30)、“白昼半”(08:30)、“大清早半”(06:30)、“天亮半”(06:30)、“天明半”(06:30)、“天黑半”(18:30)、“大晚上半”(21:30)、“大半夜半”(23:30)、“早间半”(07:30)、“晚间半”(21:30)、“夜间半”(21:30)、“入夜半”(21:30) 等半点口语标准化流水线，实现家庭自然口语半点调度无损解析；
     - **时间意图与倒计时拦截卫语句全防线 (`hasTimingOrCountdownIntent`)**：在语义提取底层将“白天”、“日间”、“白昼”、“大清早”、“大半夜”、“大晚上”、“天亮”、“天黑”、“天明”等词群全量注入前置守护，防止包含调度时相但未能被正则即时命中的口语句式被错误降级为当前立即关机或立即开机；
     - **测试集严格校验与历史断言纠偏**：修正 `VoiceCommandParserTests` 历史遗留断言，补充白天、日间、清晨、傍晚、天黑、天亮单次调度、半点调度、周期重复调度（工作日/每天白天关机）及严苛防即时开关机误触测试用例，全部断言 100% PASS。
  2. **变频压缩机连续运行机时即时清零同步与风机电动力学泛化 (`AppModel.swift` / `EnergyAnalyticsEngine.swift`)**：
     - **运行机时微秒级即时清零 (`deviceContinuousMinutes`)**：在 `sendAttribute`、`sendAttributeToDevices` 及 `turnOffDevices` 触发关机操作（`onOffStatus == false`）时，立即原子清零对应的连续开机机时 `deviceContinuousMinutes[deviceId] = 0`，彻底杜绝此前仅在 60 秒轮询采样周期中重置导致短时间内开关机错误继承高负荷热饱和阻抗补偿（Continuous Thermal Soak Drift）的缺陷；
     - **风机电动力学档位泛化兼容**：在 `EnergyAnalyticsEngine.estimateInstantaneousPower` 中，增强对 4 档 / 5 档 / 暴风 / 极速等新机型档位别名的功耗映射（4档 110W，5档/暴风 180W），全面对齐现代变频内机电控芯片特性。
  3. **macOS 原生状态栏全交互矩阵 100% Tooltip 深度感知与运行机时悬浮看板 (`StatusItemController.swift`)**：
     - **系统级菜单项 100% Tooltip 全覆盖**：为状态栏中此前未覆盖 Tooltip 的系统菜单项（语音控制、打开主窗口、助眠白噪音、开机自启、菜单栏温度显示、外观主题、主题切换各模式选项、退出应用）全面补齐原生 macOS Tooltip 悬浮提示，达成状态栏菜单 100% 交互可解释性；
     - **设备运行状态标头与连续开机机时穿透看板**：在多设备矩阵与单设备设备状态标头（`devConditionTitle` / `conditionTitle`）的 Tooltip 中，穿透呈现当前连续运转时长及热饱和补偿生效状态（如“连续运转：2 小时 30 分钟 (已进入变频恒温稳态，热饱和阻抗补偿生效中)”），将底层热物理动力学与用户界面感知无缝贯通。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下最新的审查报告进行了基线核查与深度代码走查：
1. **CR 历史问题全面复查闭环**：
   - 否定意图结构化正则防御（P1-1）持续生效；
   - 全屋与定向定时解耦（P1-2）保持清晰分工；
   - `Set` 超集集合比对与多设备批量边界防护（P2-2/P2-3）稳健运行。
2. **测试断言架构一致性纠偏**：
   - 在 `VoiceCommandParserTests.swift` 中，发现此前遗留的 `.schedulePowerAll`（该枚举在 `VoiceCommand` 架构中不存在，全屋调度由 `.schedulePower` 统一承载并通过 `displayText` 标注全屋作用域）断言，及时进行了标准化修正与对齐。
3. **本次深度优化与风险清零**：
   - 彻底消除了“白天关空调”、“工作日白天关机”、“大清早开机”、“天黑关机”等口语表达因缺失时相映射被当作即时开关机（`setPower` / `turnOffAll`）误执行的重大安全隐患；
   - 实现了连续开机机时（`deviceContinuousMinutes`）在关机瞬间的即时清零，确保热饱和阻抗衰减模型计算绝对精确。

---

## 3. 关键架构变更与代码实现

### 3.1 自然语言自然口语全天候时相调度大一统引擎与防即时开关机误触
- **`VoiceCommandParser.swift` `parseScheduleTime` 自然口语时相守护与映射**：
  ```swift
  // 必须包含“点”或“时”或者标准时间冒号，或者独立时相词群，且不是“小时” (v1.9.80 广义全时相大一统纳管)
  let hasTimePhase = normalized.contains("午夜") || normalized.contains("子夜") || normalized.contains("正午") ||
                     normalized.contains("中午") || normalized.contains("傍晚") || normalized.contains("黄昏") ||
                     normalized.contains("天黑") ||
                     normalized.contains("清晨") || normalized.contains("早晨") || normalized.contains("黎明") ||
                     normalized.contains("拂晓") || normalized.contains("破晓") || normalized.contains("清早") ||
                     normalized.contains("大清早") || normalized.contains("天亮") || normalized.contains("天明") ||
                     normalized.contains("天蒙蒙亮") ||
                     normalized.contains("早上") || normalized.contains("明早") || normalized.contains("今早") ||
                     normalized.contains("早间") || normalized.contains("上午") || normalized.contains("下午") ||
                     normalized.contains("午后") || normalized.contains("明午") || normalized.contains("晚上") ||
                     normalized.contains("今晚") || normalized.contains("明晚") || normalized.contains("晚间") ||
                     normalized.contains("入夜") || normalized.contains("夜间") || normalized.contains("夜里") ||
                     normalized.contains("大晚上") ||
                     normalized.contains("深夜") || normalized.contains("半夜") || normalized.contains("大半夜") ||
                     normalized.contains("凌晨") ||
                     normalized.contains("白天") || normalized.contains("日间") || normalized.contains("白昼") ||
                     normalized.contains("明天") || normalized.contains("后天") || normalized.contains("大后天") ||
                     normalized.contains("次日")
  ```
- **全时相独立映射与半点归一化**：
  - 白天/日间/白昼映射为 `08:00`，天黑映射为 `18:00`，大清早/天亮/天明映射为 `06:00`，大晚上映射为 `21:00`，大半夜映射为 `23:00`；
  - 接入“白天半”、“日间半”、“大清早半”、“天亮半”、“天黑半”、“大晚上半”、“大半夜半”等标准化流水线。
- **`hasTimingOrCountdownIntent` 全防线加固**：
  - 拦截所有包含上述时相词的长句，绝对禁止穿透至 `isPowerOff` / `isPowerOn` / `isAllPowerOff`。

### 3.2 变频压缩机连续运行机时即时清零同步
- **`AppModel.swift` 运行机时微秒级同步**：
  ```swift
  // 在 sendAttribute 中检测关机动作即时清零
  if name == "onOffStatus" && value.boolValue == false {
      deviceContinuousMinutes[deviceId] = 0
  }
  // 在 sendAttributeToDevices 与 turnOffDevices 中批量关机即时清零
  for id in controllableOnIds {
      deviceContinuousMinutes[id] = 0
  }
  ```
- **`EnergyAnalyticsEngine.swift` 风机动力学拓展**：
  - 支持“4档”(110W)、“5档/暴风”(180W) 宽容映射。

### 3.3 macOS 原生状态栏全交互矩阵 100% Tooltip 深度感知
- **`StatusItemController.swift` 全面补全 Tooltip**：
  - `voiceItem.toolTip = "启动语音交互胶囊 (快捷键: Control-Option-A)..."`
  - `openItem.toolTip = "打开海尔空调控制主界面..."`
  - `ambientItem.toolTip = "切换播放白噪音背景音..."`
  - `launchItem.toolTip = "设置登录 macOS 系统时是否自动启动..."`
  - `tempItem.toolTip = "切换是否在 macOS 顶部菜单栏图标旁直观显示..."`
  - `themeItem.toolTip = "切换应用外观主题..."`
  - `themeMenu` 各选项说明系统跟随、浅色、深色模式特性；
  - `quitItem.toolTip = "完全退出海尔空调控制应用并终止后台网关长连接与定时调度器"`；
  - 设备状态标头注入“连续运转：X小时Y分钟 (热饱和阻抗补偿生效中)”。

---

## 4. 自动化测试与验证

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增并校验端到端单元测试用例：
  - `"白天关空调"` -> `08:00` 关机 (PASS)
  - `"白天开机"` -> `08:00` 开机 (PASS)
  - `"全屋白天关空调"` -> `全屋 08:00` 关机 (PASS)
  - `"大清早开机"` -> `06:00` 开机 (PASS)
  - `"大晚上开机"` -> `21:00` 开机 (PASS)
  - `"大半夜关机"` -> `23:00` 关机 (PASS)
  - `"天亮开机"` -> `06:00` 开机 (PASS)
  - `"天亮关空调"` -> `06:00` 关机 (PASS)
  - `"天黑开空调"` -> `18:00` 开机 (PASS)
  - `"天黑关空调"` -> `18:00` 关机 (PASS)
  - `"天明开机"` -> `06:00` 开机 (PASS)
  - `"白天半关机"` -> `08:30` 关机 (PASS)
  - `"大清早半开机"` -> `06:30` 开机 (PASS)
  - `"大晚上半开机"` -> `21:30` 开机 (PASS)
  - `"大半夜半关机"` -> `23:30` 关机 (PASS)
  - `"天亮半开机"` -> `06:30` 开机 (PASS)
  - `"天黑半关机"` -> `18:30` 关机 (PASS)
  - `"每天白天关空调"` -> `每天 08:00` 关机 (PASS)
  - `"工作日白天关空调"` -> `工作日 08:00` 关机 (PASS)
  - 严苛防即时开关机误触断言（绝不误判为 `setPower`、`turnOffAll`、`turnOnAll`） (PASS)
  - 全部断言 100% PASS。
- **本地编译验证**：
  - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`：全模块 100% 编译成功无警告错误；
  - 执行 `./build_app.sh 1.9.80`：完成 Release 编译、桌面小组件 Bundle 打包、Ad-hoc 独立签名与临时沙盒权限绑定，打包产物 `dist/HaierAC.app` 与 `dist/HaierAC-v1.9.80-macOS.zip` 验证完毕。

---

## 5. 发版清单与资产

- **Git Commit & Tag**：`v1.9.80`
- **Release 资产**：`dist/HaierAC-v1.9.80-macOS.zip`
- **文件大小**：`2.8 MB`
- **SHA-256**：`4b6988fb290929fb6c587baf3b257c07299d013932a686f2f03f23bc489675d0`
- **发布方式**：GitHub Release via `gh release create v1.9.80`
