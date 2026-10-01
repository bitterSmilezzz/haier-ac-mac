# Haier AC Mac v1.9.115 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.115`
- **发版主题**：闭环九核心关键词与三连续区间复合排班大一统调度、软启动初态零阻尼校准及状态栏气阻健康感知
- **核心目标与架构演进**：
  1. **“九核心关键词全景排班、三连续区间复合拓扑与口语多重否定强化拦截”自然口语调度引擎 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**：
     - **纯九核心关键词全景调度 (`enneaKeywordsRegex`)**：新增 `enneaKeywordsRegex`，支持全部 9 种核心关键词（“工作日、平时、平日、双休、双休日、大休、小休、单休和单休日每天早8点开机” `[1..7]`），全面终结极端复合口语排班截断；
     - **三连续区间复合口语拓扑拓展 (`triRangeWithDualKeywordsRegex` / `dualKeywordsWithTriRangeRegex` / `keywordWithTriRangeAndKeywordRegex` / `rangeWithTriKeywordsAndRangeRegex`)**：
       - `triRangeWithDualKeywordsRegex`：三连续区间在先、双核心关键词在后（如“周一至周二、周三至周四、周五至周六加双休和大休每天早8点开机” `[1..7]`）；
       - `dualKeywordsWithTriRangeRegex`：双核心关键词在先、三连续区间在后（如“工作日和平时加周一到周二同周三到周四同周五至周六每天早8点开机” `[2..7]`）；
       - `keywordWithTriRangeAndKeywordRegex`：单核心词在先、三连续区间居中、单核心词在后（如“工作日加周一到周二、周三到周四、周五至周六加双休日每天早8点开机” `[1..7]`）；
       - `rangeWithTriKeywordsAndRangeRegex`：首区间在先、三核心关键词居中、尾区间在后（如“周一至周二加工作日、双休和大休加周五至周六每天早8点开机” `[1..7]`）；
     - **强化口语多重否定与动作防误触拦截**：在 `negativeActionRegex`、`containsNegativeForAction` 与 `containsNegativeAction` 中扩充否定前缀（“切莫”、“切勿”、“切莫要”、“千万切莫”、“断断不可”、“决计不可”）及动作谓词（“关机”、“开机”、“通电”），守住零误关零误开底线；
     - **单元测试 100% 满分覆盖**：新增 `testEnneaKeywordsAndHexaCompoundScheduleV19115` 严苛测试套件，全套 123 个单元测试零缺陷通过（0 failures）。
  2. **能耗动力学变频压缩机软启动初始采样时序校准与待机快速短路优化 (`AppModel.swift` / `EnergyAnalyticsEngine.swift`)**：
     - **软启动初始状态采样顺序缺陷修复**：修复 `deviceContinuousMinutes` 累加早于采样导致的开机第 0 分钟初始阻尼乘数（0.65 压缩机软启动超低频建立压差）被跳过的时序缺陷，确保开机第一分钟真实体现压缩机软启动物理规律；
     - **待机设备算力超轻量快速短路**：在 `estimateInstantaneousPower` 中加入关机与非自清洁状态快速卫语句短路，直接返回待机额定 1.5W，消除待机状态下多余的字符串匹配与复杂空气流阻动力学浮点运算开销。
  3. **macOS 原生状态栏菜单全景滤网健康预警与气阻负荷感知 (`StatusItemController.swift`)**：
     - **菜单悬停提示动态接入气阻功耗补偿**：在状态栏 Tooltip 与设备副标题中直观呈现积尘风道气阻功耗补偿百分比（如 `🚨滤网严重积尘 (气阻负荷 +5.0%)`、`⚠️滤网需保养 (气阻负荷 +2.5%)`）；
     - **设备状态卡片气阻阻抗标定**：在右键菜单设备详情中注入 `🚨滤网严重积尘 (风道阻抗极高)` 与 `⚠️滤网需保养 (循环气阻偏高)`，并集成 4 级洁净度分级保养提示（`极度受阻/建议拆洗/正常/良好`）；
     - **原生菜单与控制中心双向健康感知**：让用户在不打开主窗口的情况下，仅通过状态栏原生菜单即可秒级掌握全屋滤网状态与流阻动力学负荷。

---

## 2. 审查协同与代码巡检回顾

根据本项目设定的外部 Agent Code Review 审查机制，巡检启动阶段对 `docs/code-review/` 目录下审查报告及全仓架构进行了全景复核与缺陷深挖：
1. **CR 历史问题全面复查闭环**：
   - **否定意图结构化正则防御 (P1-1)**：`containsNegativeAction` 正则结构稳固，本轮进一步扩充高强度否定前缀与动作谓词（“切莫/切勿/切莫要/千万切莫/断断不可/决计不可/关机/开机/通电”），彻底杜绝口语误触；
   - **采样时序时钟缺陷与死代码**：成功识别并修正 `deviceContinuousMinutes` 采样先于累加的时序缺陷，激活开机第 0 分钟软启动 0.65 阻尼；
   - **工况占比计算属性消费 (P2-1)**：`EcoEnergySection` 已统一调用 4 个比率属性；
   - **调温 16/30°C 边界防护 (P2-3)**：单设备与全屋协同均已严格实施边界限制并同步至状态栏与 UI 使能状态。
2. **本轮走查发现的高价值优化与缺陷闭环**：
   - **九核心关键词与三连续区间复合拓扑排班 (P1 优化)**：补齐 `enneaKeywordsRegex` 及三连续区间复合矩阵 4 大正则，消灭复杂复合排班在自然语言解析层面的死角；
   - **软启动初始状态采样顺序与待机短路 (P1 优化)**：修复分钟 0 乘数生效时序，加入待机 1.5W 快速返回；
   - **状态栏气阻健康感知与风道负荷标定 (P1 优化)**：原生菜单悬停与右键详情全面透传气阻百分比与 4 级保养警示。

---

## 3. 关键架构变更与代码实现

### 3.1 九核心关键词与三连续区间复合拓扑排班引擎
- **`VoiceCommandParser.swift`**：
  ```swift
  // 九核心关键词全景正则
  private static let enneaKeywordsRegex: NSRegularExpression? = { ... }()

  // 三连续区间在先、双核心关键词在后
  private static let triRangeWithDualKeywordsRegex: NSRegularExpression? = { ... }()

  // 双核心关键词在先、三连续区间在后
  private static let dualKeywordsWithTriRangeRegex: NSRegularExpression? = { ... }()

  // 单核心词、三连续区间、单核心词
  private static let keywordWithTriRangeAndKeywordRegex: NSRegularExpression? = { ... }()

  // 首区间、三核心关键词、尾区间
  private static let rangeWithTriKeywordsAndRangeRegex: NSRegularExpression? = { ... }()
  ```

### 3.2 软启动初始采样时序修复与待机快速短路
- **`AppModel.swift`**：
  ```swift
  let initialContinuousMinutes = deviceContinuousMinutes[dev.id] ?? 0
  if dev.isPowerOn {
      deviceContinuousMinutes[dev.id] = initialContinuousMinutes + 1
  } else {
      deviceContinuousMinutes[dev.id] = 0
  }
  let sample = DeviceEnergySample(
      deviceId: dev.id,
      ...
      continuousMinutes: initialContinuousMinutes,
      ...
  )
  ```
- **`EnergyAnalyticsEngine.swift`**：
  ```swift
  // 待机状态快速短路，跳过字符串与热动力学浮点运算
  guard isPowerOn || isSelfCleaning else {
      return 1.5
  }
  ```

### 3.3 原生状态栏全景气阻健康感知与分级维护提示
- **`StatusItemController.swift`**：
  将气阻功耗补偿百分比 `(1.05 - (1.00 + (1.0 - cleanPct / 50.0) * 0.05)) * 100` 动态注入状态栏 Tooltip、设备副标题及右键保养分级提示（“🚨 极度受阻”、“⚠️ 建议拆洗”）。

---

## 4. 本地编译、测试与产物验证

1. **自动化单元测试全通**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift test`：
   - 包含 `VoiceCommandParserTests`、`ZlibTests` 等在内共 **123 个单元测试 100% 成功通过（0 failures, 0 unexpected）**。
2. **Release 编译构建**：
   - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build -c release`：
   - 编译顺利通过，零警告零报错。
3. **应用打包与签名**：
   - 执行 `./build_app.sh 1.9.115`：
   - 顺利生成 App 产物 `dist/HaierAC.app` 与发布安装包 `dist/HaierAC-v1.9.115-macOS.zip`（SHA256: `775d63f896ac8945f42aadc0b944aad406914ff8afc18c3d21b19728b991f482`）。

---

## 5. 发版信息与提交记录
- **Git Commit**：`feat & fix: 闭环九核心关键词与三连续区间复合排班大一统、软启动初态零阻尼校准及状态栏气阻健康感知 (v1.9.115)`
- **Git Tag**：`v1.9.115`
- **Release Asset**：`dist/HaierAC-v1.9.115-macOS.zip`
- **SHA256**：`775d63f896ac8945f42aadc0b944aad406914ff8afc18c3d21b19728b991f482`
