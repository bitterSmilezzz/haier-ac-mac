# Haier AC Mac v1.9.64 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.64`
- **发版主题**：闭环跨周长周期调度与全任务撤销语义完备化、macOS 状态栏全局倒计时主显消歧及滤网环境湿度全域双线性平滑阻尼模型
- **核心目标与架构演进**：
  1. **滤网环境湿度与除湿冷凝全域连续双线性阻尼物理模型 (`AppModel.calculateFilterWearFactor`)**：
     - **根除环境湿度阶跃突变断崖**：重构 `calculateFilterWearFactor` 中的室内湿度附着因子 `humidityFactor`，将原本在 35%、65%、75% 的硬跳变升级为全域连续平滑双线性阻尼插值模型：
       - 干燥段（hum <= 45%）：在 25% ~ 45% 之间由 0.90 平滑线性过渡至 1.00（`0.90 + (hum - 25.0)/20.0 * 0.10`），hum < 25% 时保底 0.90；
       - 人体工学舒适平衡区（45% < hum <= 60%）：稳定维持中性 1.00；
       - 潮湿过渡区（60% < hum <= 75%）：在 60% ~ 75% 之间由 1.00 平滑线性过渡至 1.15（`1.00 + (hum - 60.0)/15.0 * 0.15`）；
       - 极高湿回南天区（hum > 75%）：由 1.15 平滑渐进至最高 1.30（`1.15 + (hum - 75.0)/15.0 * 0.15`）；
     - **除湿模式冷凝水膜动力学平滑对齐**：重构 `.dehumidify` 工况下的 `modeFactor`，在 50% ~ 70% 湿度之间线性插值过渡（1.20 ~ 1.35），并在 70% ~ 85% 极潮湿工况下平滑渐进至 1.50，使滤网损耗模型在温差、风量、湿度三个物理维度上全面达成连续可微、平滑自洽。
  2. **跨周长周期调度与全任务撤销语义完备化 (`VoiceCommandParser.swift` / `AppModel.swift` / `VoiceCommandParserTests.swift`)**：
     - **跨周末长周期调度引擎拓展**：在公共解析引擎 `parseRepeatWeekdays` 中全面覆盖更多跨周长周期规则：
       - “周五至周三”（`[1, 2, 3, 4, 6, 7]`）、“周五至周二”（`[1, 2, 3, 6, 7]`）；
       - “周六至周四”（`[1, 2, 3, 4, 5, 7]`）、“周六至周三”（`[1, 2, 3, 4, 7]`）；
       - “周四至周二”（`[1, 2, 3, 5, 6, 7]`）、“周四至周一”（`[1, 2, 5, 6, 7]`）、“周三至周一”（`[1, 2, 4, 5, 6, 7]`）；
       - 全量兼容“周X到周Y”、“周X至周Y”、“星期X到星期Y”、“礼拜X到礼拜Y”等高频生活口语变体；
     - **撤销任务与定时全语义打通**：在 `isCancelSchedule` 的 `cancelKeywords` 中补齐“撤销定时”、“撤销所有定时”、“撤销全部定时”、“撤销倒计时”、“撤销所有倒计时”、“撤销任务”、“撤销所有任务”全语义，并与结构化否定防御防线（`containsNegativeForAction`）严密对齐；
     - **调度标签展示统一映射**：在 `AppModel.formatRepeatWeekdaysLabel` 中对齐新增的全部周期标签映射。
  3. **macOS 状态栏全局快捷倒计时主显设备感知消歧 (`StatusItemController.swift`)**：
     - **多设备全局倒计时消除歧义**：重构多设备顶层「⏱ 计划调度...」子菜单下的「⚡️ 快捷倒计时调度...」，将原本未标明受控设备的单机预设项（如“⏱ 30 分钟后关机”）升级为明确包含主显设备名称的形式（如“⏱ 「客厅空调」30 分钟后关机”）；
     - **参数注入与精准分发**：在菜单 `representedObject` 中显式注入 `deviceId: primaryId`，杜绝依赖内部回退，与全屋倒计时项（“🏠 全屋 30 分钟后关机”）形成清晰的层级对照。

---

## 2. 关键架构变更与代码实现

### 2.1 滤网环境湿度全域双线性平滑阻尼模型
- **`AppModel.swift` 消除跳变断崖**：
  ```swift
  // 除湿冷凝水膜表面张力微粒捕获与结块动力学 (v1.9.64 升级连续平滑阻尼插值)
  if let hum = indoorHumidity {
      if hum >= 70.0 {
          let progress = min(1.0, max(0.0, (hum - 70.0) / 15.0))
          modeFactor = 1.35 + (progress * 0.15) // 1.35 ~ 1.50 极高湿连续平滑过渡
      } else if hum >= 50.0 {
          let progress = (hum - 50.0) / 20.0
          modeFactor = 1.20 + (progress * 0.15) // 1.20 ~ 1.35 中高湿连续线性插值
      } else {
          modeFactor = 1.20 // 低湿平稳基准
      }
  }

  // 室内湿度附着因子全域连续双线性阻尼插值 (v1.9.64)
  if let hum = indoorHumidity {
      if hum > 75.0 {
          let progress = min(1.0, max(0.0, (hum - 75.0) / 15.0))
          humidityFactor = 1.15 + (progress * 0.15) // 1.15 ~ 1.30 极高湿连续渐进
      } else if hum > 60.0 {
          let progress = (hum - 60.0) / 15.0
          humidityFactor = 1.00 + (progress * 0.15) // 1.00 ~ 1.15 潮湿过渡插值
      } else if hum < 45.0 {
          let progress = max(0.0, (hum - 25.0) / 20.0)
          humidityFactor = 0.90 + (min(1.0, progress) * 0.10) // 0.90 ~ 1.00 干燥平滑插值
      } else {
          humidityFactor = 1.00 // 45% ~ 60% 人体工学舒适平衡区
      }
  }
  ```

### 2.2 跨周长周期调度与全任务撤销语义拓展
- **`VoiceCommandParser.swift` 周期与撤销拓展**：
  ```swift
  } else if text.contains("周五到周三") || text.contains("周五至周三") || ... {
      return ([1, 2, 3, 4, 6, 7], "周五至周三")
  } else if text.contains("周五到周二") || text.contains("周五至周二") || ... {
      return ([1, 2, 3, 6, 7], "周五至周二")
  } else if text.contains("周六到周四") || text.contains("周六至周四") || ... {
      return ([1, 2, 3, 4, 5, 7], "周六至周四")
  } else if text.contains("周六到周三") || text.contains("周六至周三") || ... {
      return ([1, 2, 3, 4, 7], "周六至周三")
  ...
  let cancelKeywords = [
      ...
      "撤销定时", "撤销所有定时", "撤销全部定时", "撤销倒计时", "撤销所有倒计时",
      "撤销所有任务", "撤销全部任务", "撤销任务", "清除所有任务", "删除所有任务"
  ]
  ```
- **`AppModel.swift` 标签映射对齐**：
  - `formatRepeatWeekdaysLabel` 扩充对 `[1, 2, 3, 6, 7]`（"周五至周二"）、`[1, 2, 3, 4, 6, 7]`（"周五至周三"）、`[1, 2, 3, 4, 7]`（"周六至周三"）、`[1, 2, 3, 4, 5, 7]`（"周六至周四"）、`[1, 2, 5, 6, 7]`（"周四至周一"）、`[1, 2, 3, 5, 6, 7]`（"周四至周二"）、`[1, 2, 4, 5, 6, 7]`（"周三至周一"）的原生友好输出。

### 2.3 macOS 状态栏全局快捷倒计时主显消歧
- **`StatusItemController.swift` 显式主显标注与参数注入**：
  ```swift
  let primaryDev = model.allUnifiedDevices.first(where: { $0.id == primaryDeviceId }) ?? model.allUnifiedDevices.first
  let primaryName = primaryDev?.name ?? "主显设备"
  let primaryId = primaryDev?.id

  let countdownPresets: [(title: String, mins: Int, powerOn: Bool)] = [
      ("⏱ 「\(primaryName)」30 分钟后关机", 30, false),
      ("⏱ 「\(primaryName)」1 小时后关机", 60, false),
      ("⏱ 「\(primaryName)」2 小时后关机", 120, false),
      ("⏱ 「\(primaryName)」晨间过渡关机 (45分钟)", 45, false),
      ("❄️ 「\(primaryName)」30 分钟后开机预冷/预热", 30, true),
      ("❄️ 「\(primaryName)」1 小时后开机预冷/预热", 60, true)
  ]
  ...
  var repObj: [String: Any] = ["minutes": preset.mins, "powerOn": preset.powerOn]
  if let primaryId {
      repObj["deviceId"] = primaryId
  }
  pItem.representedObject = repObj
  ```

---

## 3. 验证与测试闭环
- **单元测试与独立二进制验证**：
  - 在 `VoiceCommandParserTests.swift` 中新增 `testExtendedCrossWeekendCyclesAndRevokeSchedules`，并通过编译运行 100% 验证所有关键断言：
    1. 周五至周三、周五至周二跨周末长周期解析验证 ✅
    2. 周六至周四、周六至周三跨周末长周期解析验证 ✅
    3. 周四至周二、周四至周一、周三至周一跨周长周期解析验证 ✅
    4. “撤销定时”、“撤销所有定时”、“撤销所有任务”、“撤销倒计时”语义覆盖 ✅
    5. “千万别撤销定时”、“不要撤销所有任务”否定防线拦截验证 ✅
    6. 滤网环境湿度双线性连续阻尼插值模型数学连续性与平滑度验证 ✅
- **编译与静态分析**：
  - `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build` 0 警告 0 错误编译通过。
- **发布构建与产物校验**：
  - 执行 `./build_app.sh 1.9.64`，打包签名产出：
    - `dist/HaierAC.app`
    - `dist/HaierAC-v1.9.64-macOS.zip` (大小: 2.7M)
    - SHA256 校验和：`d5dedff73c409c2c6326cf62899c2a8d921b388480c11c7c2926922f4a3eb23a`
