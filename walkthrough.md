# Haier AC Mac v1.9.37 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.37`
- **发版主题**：自然语言全链路否定安全防线、调度器解耦重置、除湿变频环境湿度动力学与多设备滤网自适应预测
- **核心目标与架构演进**：
  1. **自然语言全链路模式/情景/自清洁/睡眠温阶否定防护与防高温误烘烤**：
     - 扩展否定语义保护网至全屋预设 (`parseAllPreset`)、运行模式 (`parseMode`)、情景模式 (`parseScene`) 以及全屋绝对/相对调温 (`parseAllTemperature` / `parseAllRelativeTemperature`)，杜绝口语否定词导致误开机或误切模式；
     - 彻底消除当用户说“不要自清洁”、“别自清洁”、“别开自清洁”、“不要启动自清洁”等口令时，因仅匹配关停动作而落入缺省分支导致意外启动 56°C 蒸发器高温除菌烘烤的严重安全隐患，稳健识别否定词并安全降级为停止自清洁分支；
     - 睡眠温阶启停同步引入否定保护，识别“不要开启智能睡眠”、“别开睡眠曲线”等输入并安全降级为退出；支持“别定时”、“不要定时”口语映射为定时任务取消；
  2. **调度器解耦重置与原子全屋/定向定时管理**：
     - 在 `AppModel` 中提供原子封装方法 `cancelAllSchedules()`、`cancelSchedules(for deviceIds:)` 与 `cancelSchedules(for deviceId:)`，统一处理内存数据清除、`wakeScheduler()` 定时器重置唤醒、`UserDefaults` 同步与运行日志记录；
     - 解决语音胶囊在全屋及定向取消定时任务时直接操作集合而未调用 `wakeScheduler()` 导致后台定时休眠任务未被及时唤醒的隐患，全链路对齐执行范围与系统调度；
  3. **滤网深度算法：历史机时自适应寿命预测与多设备全生命周期动态感知**：
     - 深度打通 `EnergyAnalyticsEngine` 能耗历史与 `FilterCareSheet`，提取过去 14 天真实开机运行机时历史（如日均 8.5h），动态计算折算滤网剩余可用天数（呈现如“• 按近期日均 8.5h 习惯及当前工况估算约可用 45 天”），摆脱以往写死 6h 的生硬估算，兼顾无历史记录时的标准回退；
     - 状态栏右键菜单与悬浮 Tooltip 升级支持全屋多设备滤网健康聚合监测：当任何房间空调洁净度 $\le 30\%$ 时，右键菜单标明“全屋最低 XX%”并加注警示徽标，悬浮提示中明确指出需要拆洗的具体空调，杜绝次卧/儿童房滤网被遗忘；
  4. **除湿工况环境湿度变频能耗动力学建模**：
     - 在 `DeviceEnergySample` 与瞬时功率估算算法中正式引入环境湿度 (`indoorHumidity`) 维度；
     - 建立基于变频空调热力学除湿特性的三级动态响应机制：高湿重载区 ($\text{RH} \ge 70\%$) 蒸发器深度过冷持续冷凝 (520W~620W 基准)、中湿过渡区 ($55\% \le \text{RH} < 70\%$) 平衡变频除湿 (380W~500W 基准)、低湿/舒适区 ($\text{RH} < 55\%$) 防过度干燥与过冷超低频微载运转 (240W~320W 基准)；无湿度传感器时中性回归标准 420W 基准，使除湿能耗模拟更加拟真。

---

## 2. 关键架构变更与代码实现

### 2.1 自然语言全链路否定语义防线 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)
- **全屋预设与模式否定防护**：
  - `parseAllPreset`、`parseAllTemperature`、`parseAllRelativeTemperature` 前置注入 `guard !containsNegativeAction(text) else { return nil }`；
  - `parseMode` 与 `parseScene` 注入否定动作检测与常用否定词过滤，彻底拦截“全屋空调别开冷气”、“千万别开除湿”、“不要开暖气”、“别开离家模式”等输入，防止误判开机；
- **自清洁与睡眠温阶高温安全拦截**：
  - 自清洁解析中，当输入包含否定词（“别”、“不要”、“不用”）或触发 `containsNegativeAction` 时，安全路由至 `.stopSelfCleaning`（“停止蒸发器自清洁”），杜绝意外启动 56°C 高温烘干；
  - 睡眠曲线解析同步对齐，识别“不要开启智能睡眠”等指令并安全映射为 `.stopSleepCurve`；
  - `isCancelSchedule` 补充“别定时”、“不要定时”、“不用定时”关键词。

### 2.2 调度器解耦重置与原子管理 (`AppModel.swift` / `VoiceCapsuleWindowController.swift`)
- **AppModel 原生调度器重置方法**：
  - `cancelAllSchedules() -> Int`：原子清空 `scheduledActions` 并触发 `wakeScheduler()` 重新计算最近触发时钟；
  - `cancelSchedules(for deviceIds: [String]) -> Int`：按设备集合过滤并原子唤醒调度器；
  - `cancelSchedules(for deviceId: String) -> Int`：单设备便捷方法；
- **VoiceCapsuleWindowController 统一调用**：
  - 全屋取消定时（`.cancelSchedulesAll`）、多设备定向批量取消（`executeMultiDeviceCommand`）与单设备定向取消（`executeCommand`）统一改调 `AppModel` 原子方法，彻底解决定时器线程未能及时重构的问题。

### 2.3 滤网深度算法与全屋健康聚合感知 (`FilterCareSheet.swift` / `AppModel.swift` / `StatusItemController.swift`)
- **用户使用习惯自适应寿命推演**：
  - `AppModel.estimatedFilterRemainingDays(for:)` 结合 `EnergyAnalyticsEngine.historyRecords` 近 14 天活跃开机时长计算设备日均机时；
  - `FilterCareSheet` 根据用户真实作息与当前动力负荷自适应展示可用天数估算，极大提升维护参考价值；
- **状态栏多设备最低洁净度预警与聚合 Tooltip**：
  - 状态栏右键菜单在多设备环境下展示全屋最低洁净度（如 `⚠️ 滤网保养与自清洁 (全屋最低 25%)...`）；
  - 悬浮 Tooltip 自动扫描并罗列洁净度低于 30% 的所有设备名称及当前数值。

### 2.4 除湿工况环境湿度变频能耗动力学模型 (`EnergyAnalyticsEngine.swift` / `AppModel.swift`)
- **湿度维度注入**：
  - `DeviceEnergySample` 新增 `indoorHumidity: Double?` 字段并在 `AppModel.sampleMinuteEnergy` 中采集传入；
- **热力学三级变频除湿动力模型**：
  - $\text{RH} \ge 70\%$：高湿持续强冷凝负荷，功率上浮至 520W ~ 620W；
  - $55\% \le \text{RH} < 70\%$：舒适平衡区变频调节，基准 380W ~ 500W；
  - $\text{RH} < 55\%$：防过冷降频微载运转，功率下探至 240W ~ 320W；
  - 传感器缺失时中性平滑回归 420W 标称基准。

---

## 3. 构建、测试与打包验证闭环
- **本地编译验证**：
  - 执行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 错误，0 警告构建成功；
- **自动化测试断言验证**：
  - 编写并执行针对模式否定、自清洁否定、预设否定、睡眠温阶否定、定时取消与开关机的 21 组独立测试用例，100% 通过；
- **应用打包与签名**：
  - 运行 `./build_app.sh 1.9.37`，打包生成 `dist/HaierAC.app`（包含小组件扩展与沙盒权限配置）以及发布包 `dist/HaierAC-v1.9.37-macOS.zip`。

---

## 4. 敏感数据安全审计
- 全仓扫描确认无真实手机号、明文密码、第三方 Secret Token 或私人凭据提交。
