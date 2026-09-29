# Haier AC Mac v1.9.81 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.81`
- **发版主题**：闭环口语化日常时相大一统调度引擎、防即时开关机误触全防线与变频多档风速空气动力学深度对齐
- **核心目标与架构演进**：
  1. **日常自然口语独立时相调度大一统引擎与防即时开关机误触 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **高频自然口语时相词群全景闭环 (后半夜/晌午/三更半夜/天蒙蒙亮)**：深度纳管北方及各方言区家庭常用时相词群，“晌午”映射为正午 12:00，“后半夜”映射为 02:00（如“后半夜关空调”、“后半夜两点开机”），“三更半夜”映射为午夜 00:00，“天蒙蒙亮”映射为清晨 06:00，彻底消除无显式钟点家庭口语无法识别调度意图的体验断层；
     - **口语半点时相流水线全量拓展**：支持“晌午半”(12:30)、“后半夜半”(02:30)、“三更半夜半”(00:30)、“天蒙蒙亮半”(06:30) 等口语标准化流水线，消除半点口语表达障碍；
     - **成语习语标准化消歧与防即时开关机穿透全防线 (`hasTimingOrCountdownIntent`)**：将“三更半夜”作为固定夜间习语在数字转换层规范为“午夜”，消除因单字“三”被机械转换为阿拉伯数字“3”而导致无法识别独立时相并跌落至 23:00 的缺陷；在 `hasTimingOrCountdownIntent` 中将“晌午”、“后半夜”、“三更半夜”全量注入前置守护，绝对杜绝“后半夜关空调”、“晌午关机”等口语穿透到立即开关机造成误操作的严重故障隐患；
     - **测试集严格对齐与断言全量 PASS**：新增涵盖“晌午”、“后半夜”、“三更半夜”、“天蒙蒙亮”单次与周期重复调度（如“每天晌午关空调”、“工作日后半夜关空调”），以及严苛的防即时误触断言（如“后半夜关空调 != setPower(false)”、“后半夜关空调 != turnOffAll”），全部 20 组关键断言 100% 满分通过。
  2. **变频多档风速空气动力学等效工时磨损模型与控制引擎全量对齐 (`AppModel.swift`)**：
     - **5 档与暴风档位风阻通量建模 (`calculateFilterWearFactor`)**：全面消除以往仅硬编码 1~3 档导致现代变频内机反馈 4 档/5 档/暴风时错误跌落至“自动风速”温差阻尼模型的断层，建立物理自洽的空气动力学风阻与颗粒物通量磨损模型：5档/暴风/极速等效通量因子 1.85，4档/强风等效通量因子 1.50，3档 1.35，2档 1.00，1档 0.80，微风 0.60；
     - **`setWindSpeed` 风速归一化引擎全档位纳管**：在语音口语与批量控制下发“4档”、“5档”、“暴风”时，正确归一化映射为“强劲”并精准匹配内机硬件属性范围，根除此前被错误回退为“自动”风速的缺陷。
  3. **macOS 原生状态栏全交互矩阵 Tooltip 与档位感知矩阵 (`StatusItemController.swift`)**：
     - **风速调节全层级 100% 原生 Tooltip 覆盖**：为单设备、多设备子菜单及全屋风速协同菜单项（微风/中风/强劲/自动）全面注入原生 macOS Tooltip 悬浮提示，清晰说明各风档的气流特性、舒适度及使用场景；
     - **变频新机型档位感知与勾选一致性**：在菜单状态判定（`allOnSameSpeed` 与 `isSelected`）中全面支持 4 档、5 档、暴风等新机型状态的高精识别与统一勾选展示。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下最新的审查报告（`2026-09-24-1426.md`）进行了基线核查与深度代码走查：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 正则模型稳定运行，允许 0~10 个任意字符穿插，彻底解决插字绕过缺陷；
   - **全屋与定向定时解耦 (P1-2)**：`cancelSchedules` 与 `cancelSchedulesAll` 精确分流，多设备批量取消分支全部贯通；
   - **工况占比计算属性消费 (P2-1)**：`EcoEnergySection` 已统一调用 4 个比率属性；
   - **死分支清理 (P2-2)**：`.adjustTemperatureAll` 死分支已彻底清理；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏使能状态。
2. **测试断言架构一致性纠偏**：
   - 在 `VoiceCommandParserTests.swift` 中，纠偏了此前“每天”调度中遗留的 `[1, 2, 3, 4, 5, 6, 7]` 断言，对齐为标准的 `repeatWeekdays: []`。
3. **本次深度优化与风险清零**：
   - 根除了“后半夜关空调”、“晌午关机”等高频家庭口语穿透时间守卫导致立即误关机/开机的重大缺陷；
   - 修复了变频内机 4 档/5 档/暴风风速在滤网动力学模型与 `setWindSpeed` 中被错误判为“自动风速”的物理失真。

---

## 3. 关键架构变更与代码实现

### 3.1 自然语言日常时相调度大一统引擎与防即时开关机误触
- **`VoiceCommandParser.swift` 时相纳管与成语归一化**：
  ```swift
  // 成语习语标准化规整
  str = str.replacingOccurrences(of: "三更半夜", with: "午夜")
  str = str.replacingOccurrences(of: "晌午半", with: "晌午12点30分")
  str = str.replacingOccurrences(of: "后半夜半", with: "后半夜2点30分")
  str = str.replacingOccurrences(of: "天蒙蒙亮半", with: "天蒙蒙亮6点30分")

  // 独立无钟点时相自适应映射
  if normalized.contains("午夜") || normalized.contains("子夜") || normalized.contains("三更半夜") {
      hour = 0; minute = 0
  } else if normalized.contains("正午") || normalized.contains("中午") || normalized.contains("晌午") {
      hour = 12; minute = 0
  } else if normalized.contains("后半夜") {
      hour = 2; minute = 0
  }
  ```
- **时相与夜深校准防线 (`isNocturnal`)**：
  - 纳管“后半夜”与“三更半夜”，若用户说“后半夜两点”，保持 02:00，绝不误累加 12 变成 14:00。
- **`hasTimingOrCountdownIntent` 全防线加固**：
  - 拦截所有包含“晌午”、“后半夜”、“三更半夜”的长句，坚决禁止穿透至 `isPowerOff` / `isPowerOn`。

### 3.2 变频多档风速空气动力学等效工时磨损模型
- **`AppModel.swift` 5 档与暴风档位风阻通量重构**：
  ```swift
  if speed.contains("暴") || speed.contains("5档") || speed.contains("五档") || speed == "5" ||
     speed.contains("超强") || speed.contains("最大") || speed.contains("极速") {
      windFactor = 1.85
  } else if speed.contains("4档") || speed.contains("四档") || speed == "4" ||
            speed.contains("强") || speed.contains("turbo") || speed.contains("高速") {
      windFactor = 1.50
  } else if speed.contains("3档") || speed.contains("三档") || speed == "3" ||
            speed.contains("高") || speed.contains("high") || speed.contains("大风") || speed.contains("大") {
      windFactor = 1.35
  }
  ```
- **`setWindSpeed` 归一化引擎补齐**：
  - 支持 4、四、5、五、暴 等档位映射至“强劲”，消除回退至“自动”的逻辑缺陷。

### 3.3 macOS 原生状态栏全交互矩阵 Tooltip 覆盖
- **`StatusItemController.swift` 全面补全 Tooltip**：
  - 单设备、多设备、全屋风速协同菜单项全面配置说明文本；
  - 状态识别逻辑（`allOnSameSpeed` / `isSelected`）纳管 4/5 档及暴风。

---

## 4. 自动化测试与验证

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增并校验端到端单元测试用例：
  - `"晌午关空调"` -> `12:00` 关机 (PASS)
  - `"晌午开机"` -> `12:00` 开机 (PASS)
  - `"晌午半关空调"` -> `12:30` 关机 (PASS)
  - `"后半夜关空调"` -> `02:00` 关机 (PASS)
  - `"后半夜两点开机"` -> `02:00` 开机 (PASS)
  - `"后半夜半关机"` -> `02:30` 关机 (PASS)
  - `"三更半夜关机"` -> `00:00` 关机 (PASS)
  - `"三更半夜开机"` -> `00:00` 开机 (PASS)
  - `"天蒙蒙亮关机"` -> `06:00` 关机 (PASS)
  - `"天蒙蒙亮半开机"` -> `06:30` 开机 (PASS)
  - `"每天晌午关空调"` -> 每天 `12:00` (PASS)
  - `"工作日后半夜关空调"` -> 工作日 `02:00` (PASS)
  - 防误触断言（后半夜/晌午/三更半夜/天蒙蒙亮均不触发即时开关机）全部 PASS。
- **本地编译验证**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` -> 100% 成功，0 错误；
  - 运行 `./build_app.sh 1.9.81` 打包生成 `dist/HaierAC-v1.9.81-macOS.zip` (2.8MB)。

---

## 5. 发版信息与交付产物
- **Git Tag**：`v1.9.81`
- **Release 资产**：`dist/HaierAC-v1.9.81-macOS.zip`
- **安全敏感数据检查**：经核验，源码与文档均无敏感个人信息、真实 Token 或凭证，符合安全脱敏规范。
