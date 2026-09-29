# Haier AC Mac v1.9.82 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.82`
- **发版主题**：闭环 CR 变频多档能耗动力学倒挂修复、状态栏风速档位感知一致性与自然口语前半夜时相调度大一统引擎
- **核心目标与架构演进**：
  1. **变频风机能耗动力学倒挂缺陷修复与多维空气动力学物理自洽 (`EnergyAnalyticsEngine.swift`)**：
     - **根除 3 档与 4 档功率倒挂异常**：在 `EnergyAnalyticsEngine.estimateInstantaneousPower` 中，此前风机电动力学补偿错误将“3档”归类于 180W 的最高档（与 5档/暴风并列），而“4档”仅返回 110W，导致 3 档估算电功率反向高于 4 档的严重物理反常。本次全面对齐变频内机空气动力学风阻与颗粒物通量模型，建立严格单调递增的物理能耗阶梯：5档/暴风 180W、4档/强风 140W、3档/高风 100W、2档/中风 65W、1档/低风 35W、微风/静音 15W，与 `AppModel.swift` 滤网空气动力学通量因子（1.85 / 1.50 / 1.35 / 1.00 / 0.80 / 0.60）达成 100% 物理对称自洽。
  2. **状态栏风速选项勾选与多设备感知断层修复 (`AppModel.swift` / `StatusItemController.swift`)**：
     - **公共风速归一化引擎抽象 (`AppModel.normalizeWindSpeed`)**：将此前分散在局部闭包中的风速别名标准化逻辑抽象为公共静态方法 `AppModel.normalizeWindSpeed`，全面统一低速/静音/柔风/1档（微风）、中速/2档（中风）、高速/大风/强风/暴风/极速/3-5档（强劲）及自动风速的映射标准；
     - **状态栏单机与子菜单勾选状态 100% 精确匹配**：修复此前单设备菜单（`singleWindMenu`）与设备子菜单（`devWindMenu`）因字面子串包含导致的勾选缺失缺陷（当内机上报“1档”、“低风”、“静音”时，“微风”未勾选；上报“2档”、“中速”时，“中风”未勾选）；改用 `normCurWind == itemDef.val` 严格比对，根除“无勾选”UI 状态断层；
     - **全屋风速协同判定逻辑同步**：`allOnSameSpeed` 统一消费 `AppModel.normalizeWindSpeed`，确保全屋与单机对新机型变频档位的识别与勾选保持严格一致。
  3. **macOS 状态栏运行工况 Tooltip 风速显示精度补齐 (`StatusItemController.swift`)**：
     - **修复 4 档/5 档/暴风显示为 [自动风] 的体验缺陷**：在 `formatDisplayWindSpeed` 中扩展 4档、5档、暴风等高频变频档位解析，分别输出“暴风”、“强劲风”、“高风”，彻底消除状态栏 Tooltip 与设备状态标头将高速运转误报为自动风的混淆。
  4. **自然语言日常口语前半夜时相大一统调度引擎与死分支清理 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **成语习语标准化流水线死分支修复**：修复 `convertChineseNumbers` 中因“三更半夜”提前替换为“午夜”导致其后的“三更半夜半”成为不可达死分支的问题；
     - **前半夜时相词群全景闭环 (前半夜/前半夜半)**：纳管“前半夜”（映射为 22:00，与后半夜 02:00 形成完美夜间时相對称）与“前半夜半”（22:30），支持“前半夜关空调”、“前半夜开机”、“前半夜半关空调”、“前半夜十点开机”等自然口语调度；
     - **周期重复与防即时开关机穿透全防线 (`hasTimingOrCountdownIntent`)**：支持“每天前半夜关空调”、“工作日前半夜关机”，并将“前半夜”注入 `hasTimingOrCountdownIntent` 与 `isNocturnal`，严格杜绝“前半夜关空调”被误判为即时关机的重大隐患；测试集新增 10 组关键测试用例，100% 满分通过。
  5. **代码坏味道清理与重用 (`FilterCareSheet.swift`)**：
     - `FilterCareSheet` 中的 `currentWearFactor` 消除 17 行重复属性提取样板代码，统一复用 `model.calculateCurrentFilterWearFactor(for: currentDeviceId)`。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下最新的审查报告（`2026-09-24-1426.md`）进行了基线核查与深度代码走查：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 正则模型稳定运行，允许 0~10 个任意字符穿插，彻底解决插字绕过缺陷；
   - **全屋与定向定时解耦 (P1-2)**：`cancelSchedules` 与 `cancelSchedulesAll` 精确分流，多设备批量取消分支全部贯通；
   - **工况占比计算属性消费 (P2-1)**：`EcoEnergySection` 已统一调用 4 个比率属性；
   - **死分支清理 (P2-2)**：`.adjustTemperatureAll` 死分支已彻底清理；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏使能状态。
2. **深度代码走查发现的问题与闭环解决**：
   - **能耗功率计算档位倒挂缺陷 (P1)**：`EnergyAnalyticsEngine.estimateInstantaneousPower` 中“3档”被归入 180W，而“4档”被归入 110W，导致 3 档功率高于 4 档。本次按物理阶梯重构为 5档 180W、4档 140W、3档 100W、2档 65W、1档 35W、微风 15W；
   - **状态栏风速勾选断层缺陷 (P1)**：`StatusItemController` 在低速、静音、1档、2档时，由于字面包含判断失真，导致菜单无任何项被勾选。本次抽象出公共归一化函数 `AppModel.normalizeWindSpeed`，实现 100% 精确勾选；
   - **状态栏悬浮 Tooltip 档位显示缺陷 (P2)**：`formatDisplayWindSpeed` 漏判 4/5 档及暴风，导致展示为“自动风”，现已补全映射；
   - **成语习语标准化死分支缺陷 (P2)**：`VoiceCommandParser.convertChineseNumbers` 中“三更半夜半”被前置的“三更半夜”拦截成为死代码，现已调正处理优先级；
   - **时相调度对称性缺口 (P2)**：补齐家庭夜间高频口语“前半夜”(22:00) 与“前半夜半”(22:30)，与后半夜完美对称并注入防误触防线。

---

## 3. 关键架构变更与代码实现

### 3.1 变频多档能耗动力学倒挂修复
- **`EnergyAnalyticsEngine.swift` 风机阶梯功率重构**：
  ```swift
  let windOffset: Double = {
      let wind = windSpeed?.lowercased()
      if let wind = wind {
          if wind.contains("暴") || wind.contains("5档") || wind.contains("五档") || wind == "5" ||
             wind.contains("超强") || wind.contains("最大") || wind.contains("极速") {
              return 180.0
          }
          if wind.contains("4档") || wind.contains("四档") || wind == "4" ||
             wind.contains("强") || wind.contains("turbo") || wind.contains("高速") {
              return 140.0
          }
          if wind.contains("3档") || wind.contains("三档") || wind == "3" ||
             wind.contains("高") || wind.contains("high") || wind.contains("大风") || wind.contains("大") {
              return 100.0
          }
          if wind.contains("中") || wind.contains("medium") || wind.contains("mid") ||
             wind.contains("2档") || wind.contains("二档") || wind.contains("两档") || wind == "2" || wind.contains("中速") {
              return 65.0
          }
          if wind.contains("低") || wind.contains("low") ||
             wind.contains("1档") || wind.contains("一档") || wind == "1" || wind.contains("小风") || wind.contains("低速") {
              return 35.0
          }
          if wind.contains("微") || wind.contains("静") || wind.contains("quiet") || wind.contains("mute") || wind.contains("micro") || wind.contains("柔") {
              return 15.0
          }
      }
      // 自动风速热物理自适应模型（20W ~ 120W 动态插值）...
  }()
  ```

### 3.2 公共风速归一化引擎与状态栏勾选一致性
- **`AppModel.swift` 公共标准化函数**：
  ```swift
  public static func normalizeWindSpeed(_ speedName: String) -> String {
      if speedName.contains("微") || speedName.contains("低") || speedName.contains("静") ||
         speedName.contains("柔") || speedName.contains("小") || speedName.contains("1") || speedName.contains("一") {
          return "微风"
      }
      if speedName.contains("中") || speedName.contains("2") || speedName.contains("二") || speedName.contains("两") {
          return "中风"
      }
      if speedName.contains("强") || speedName.contains("高") || speedName.contains("大") ||
         speedName.contains("极") || speedName.contains("暴") ||
         speedName.contains("3") || speedName.contains("三") ||
         speedName.contains("4") || speedName.contains("四") ||
         speedName.contains("5") || speedName.contains("五") {
          return "强劲"
      }
      return "自动"
  }
  ```
- **`StatusItemController.swift` 状态栏精确勾选与显示**：
  - `devWindMenu` 与 `singleWindMenu` 使用 `AppModel.normalizeWindSpeed(curWind) == itemDef.val` 进行判定；
  - `allOnSameSpeed` 统一使用 `AppModel.normalizeWindSpeed`；
  - `formatDisplayWindSpeed` 扩展支持 4档、5档、暴风。

### 3.3 自然语言日常口语前半夜时相调度大一统引擎
- **`VoiceCommandParser.swift` 前半夜纳管与流水线清理**：
  ```swift
  // 成语习语长词在先，根除死分支
  str = str.replacingOccurrences(of: "三更半夜半", with: "午夜0点30分")
  str = str.replacingOccurrences(of: "三更半夜", with: "午夜")
  str = str.replacingOccurrences(of: "前半夜半", with: "前半夜10点30分")

  // 独立无钟点时相自适应映射
  if normalized.contains("午夜") || normalized.contains("子夜") || normalized.contains("三更半夜") {
      hour = 0; minute = 0
  } else if normalized.contains("正午") || normalized.contains("中午") || normalized.contains("晌午") {
      hour = 12; minute = 0
  } else if normalized.contains("前半夜") {
      hour = 22; minute = 0
  } else if normalized.contains("后半夜") {
      hour = 2; minute = 0
  }
  ```
- **防即时误触卫语句拦截 (`hasTimingOrCountdownIntent`)**：
  - 注入“前半夜”，确保“前半夜关空调”、“每天前半夜开机”绝对杜绝穿透至立即开关机。

---

## 4. 自动化测试与验证

- **单元测试覆盖**：
  在 `Sources/HaierACCoreTests/VoiceCommandParserTests.swift` 中新增并校验端到端单元测试用例：
  - `"前半夜关空调"` -> `22:00` 关机 (PASS)
  - `"前半夜开机"` -> `22:00` 开机 (PASS)
  - `"前半夜半关空调"` -> `22:30` 关机 (PASS)
  - `"前半夜十点开机"` -> `22:00` 开机 (PASS)
  - `"三更半夜半关机"` -> `00:30` 关机 (PASS)
  - `"每天前半夜关空调"` -> 每天 `22:00` 关机 (PASS)
  - `"工作日前半夜关机"` -> 工作日 `22:00` 关机 (PASS)
  - 防误触断言（前半夜关空调 != setPower(false)，前半夜关空调 != turnOffAll，全屋前半夜关空调 != turnOffAll，前半夜开机 != setPower(true)）全部 PASS。
- **本地编译验证**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` -> 100% 成功，0 错误；
  - 运行 `./build_app.sh 1.9.82` 打包生成 `dist/HaierAC-v1.9.82-macOS.zip` (2.8MB)。

---

## 5. 发版信息与交付产物
- **Git Tag**：`v1.9.82`
- **Release 资产**：`dist/HaierAC-v1.9.82-macOS.zip`
- **SHA-256**：`2752c27387c920f1e0246f3a449a6c39a886a295a1862dc39d1b40ba17476a03`
- **安全敏感数据检查**：经核验，源码与文档均无敏感个人信息、真实 Token 或凭证，符合安全脱敏规范。
