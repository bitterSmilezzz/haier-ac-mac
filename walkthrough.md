# Haier AC Mac v1.9.63 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.63`
- **发版主题**：闭环多日跨周与全任务调度语义泛化、macOS 状态栏单机去重对称重构及滤网气动力学连续阻尼模型
- **核心目标与架构演进**：
  1. **周期调度跨周全星期范围与调度全任务语义泛化 (`VoiceCommandParser.swift` / `AppModel.swift` / `VoiceCommandParserTests.swift`)**：
     - **跨周末长周期调度引擎拓展**：在公共解析引擎 `parseRepeatWeekdays` 中全面覆盖多日跨周末周期：“周五至周一”（`[1, 2, 6, 7]`）、“周六至周二”（`[1, 2, 3, 7]`）以及以周日为起点的“周日至周五”（`[1..6]`）、“周日至周四”（`[1..5]`）、“周日至周三”（`[1..4]`）、“周日至周二”（`[1..3]`），全链路打通中文口语与周几数字映射；
     - **周末口语全变体兼容**：补齐“周六日/周六天/星期六天/礼拜六天/礼拜六日”高频口语变体，统一收敛为标准周末（`[1, 7]`）；
     - **任务调度清空与全任务语义拓展**：在 `isCancelSchedule`、`isPauseSchedule`、`isResumeSchedule` 中引入“清空”与“任务”语义（如“清空定时”、“取消所有任务”、“暂停所有任务”、“恢复所有任务”），并在否定动作防线（`containsNegativeForAction` 与 `negativeActionRegex`）中同步增加“清空”保护，严防误清空；
     - **调度标签展示统一映射**：在 `AppModel.formatRepeatWeekdaysLabel` 中对齐新增的全部周期标签映射。
  2. **macOS 状态栏单设备去重重构与滤网快速重置对称设计 (`StatusItemController.swift` / `VoiceCapsuleWindowController.swift`)**：
     - **根除单设备双重计划菜单冗余**：重构状态栏计划调度布局逻辑，仅在多设备场景下渲染全局顶层「⏱ 计划调度...」菜单，单设备场景由其专属就绪菜单全权管理，彻底消除单设备用户界面中出现两个计划调度入口的冗余问题；
     - **单设备滤网快速重置入口全景对称**：在单设备运行工况控制区中，与多设备二级菜单对称补齐「🧼 重置滤网计时 (当前 X%，良好/需拆洗)」，实现单机与多机操控体验的严密自洽；
     - **语音胶囊多设备执行自愈降级**：在 `executeMultiDeviceCommand` 中补齐自清洁（`.startSelfCleaning` / `.stopSelfCleaning`）与睡眠曲线（`.startSleepCurve` / `.stopSleepCurve`）的分发逻辑，提供友好的单台优先执行与温和反馈，彻底消除“暂不支持多设备批量执行”报错。
  3. **滤网空气动力学连续线性阻尼物理模型 (`AppModel.calculateFilterWearFactor`)**：
     - **消除阶跃跳变断崖**：重构 `calculateFilterWearFactor` 中自动风速与制冷模式下的系数计算，采用与能耗引擎对齐的连续线性物理阻尼插值：
     - 自动风速在稳态微载（0.8°C）到重载大温差（4.0°C）之间采用连续渐进插值（`0.75 + progress * 0.55`），消除阶跃跳变；
     - 制冷大温差冷凝在 0~5°C 范围采用平滑线性插值（`1.15 + progress * 0.30`），保证滤网洁净度衰减曲线更加平滑自洽。

---

## 2. 关键架构变更与代码实现

### 2.1 跨周周期重复与全任务调度语义泛化
- **`VoiceCommandParser.swift` 周期规则拓展**：
  ```swift
  } else if text.contains("周五到周一") || text.contains("周五至周一") || ... {
      return ([1, 2, 6, 7], "周五至周一")
  } else if text.contains("周六到周二") || text.contains("周六至周二") || ... {
      return ([1, 2, 3, 7], "周六至周二")
  } else if text.contains("周日到周五") || text.contains("周日至周五") || ... {
      return ([1, 2, 3, 4, 5, 6], "周日至周五")
  ...
  ```
- **清空任务语义与否定安全防线加固**：
  - 判定扩展：“清空定时”、“清空倒计时”、“清空所有任务”、“清空任务”；
  - 否定防御：“千万别清空定时”、“不要清空所有任务”，杜绝误操作。
- **`AppModel.swift` 标签对齐**：
  - `formatRepeatWeekdaysLabel` 扩充对应中文格式化输出。

### 2.2 macOS 状态栏单机去重与全景对称
- **`StatusItemController.swift` 菜单去重与滤网重置对称**：
  ```swift
  // 单设备专属滤网快速重置
  let filterPct = model.filterCleanlinessPercentage(for: dev.id)
  let filterStatus = filterPct <= 20 ? "⚠️ 需拆洗" : "良好"
  let singleResetFilterItem = NSMenuItem(
      title: "🧼 重置滤网计时 (当前 \(filterPct)%，\(filterStatus))",
      action: #selector(resetDeviceFilterFromMenu(_:)),
      keyEquivalent: ""
  )
  ...
  // 顶层全局调度仅在多设备下挂载，单设备由专属子项管理
  if allDevices.count > 1 {
      // 计划调度与定时任务感知 (多设备全屋调度矩阵)
      ...
  }
  ```

### 2.3 滤网空气动力学连续线性阻尼物理模型
- **`AppModel.swift` 消除阶跃断崖**：
  ```swift
  // 稳态微载(0.8°C)到重载大温差(4.0°C)连续线性热物理阻尼插值 (v1.9.63 消除阶跃跳变，与能耗引擎对齐)
  let progress = (tempDelta - 0.8) / 3.2
  windFactor = 0.75 + (progress * 0.55)
  ...
  // 0~5°C 连续平滑线性阻尼插值 (1.15 ~ 1.45) (v1.9.63)
  let progress = min(1.0, max(0.0, diff / 5.0))
  modeFactor = 1.15 + (progress * 0.30)
  ```

---

## 3. 验证与测试闭环
- **单元测试与端到端断言**：
  - 在 `VoiceCommandParserTests.swift` 中新增 `testExtendedRepeatWeekdaysAndCancelTaskGeneralization`，并通过独立二进制完全验证所有用例：
    1. 周五至周一、周六至周二跨周末长周期解析验证 ✅
    2. 周日至各工作日周期范围解析验证 ✅
    3. 周末口语变体（周六日、周六天、星期六天、礼拜六天）统一归一化 ✅
    4. “取消所有任务”、“清空定时”、“清空所有定时任务”全语义覆盖 ✅
    5. “千万别清空定时”、“不要取消所有任务”动作否定防御拦截 ✅
- **编译与静态分析**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` 0 警告 0 错误编译通过。
- **发布构建与产物校验**：
  - 执行 `./build_app.sh 1.9.63`，打包签名产出：
    - `dist/HaierAC.app`
    - `dist/HaierAC-v1.9.63-macOS.zip` (大小: 2.7M)
    - SHA256 校验和：`99bfe7328f8d49667d5410445b2ddfaa4b8a13ae447e5fe23c4c6640611c45e7`
