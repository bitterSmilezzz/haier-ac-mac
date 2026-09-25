# Haier AC Mac v1.9.45 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.45`
- **发版主题**：闭环滤网保养全链路重置复位穿透、全屋多设备滤网一键清零、状态栏快捷重置矩阵及制冷工况潜热动力学校准
- **核心目标与架构演进**：
  1. **滤网保养全链路重置/复位语音口令与 Siri 快捷指令穿透式闭环**：
     - 彻底根除用户在拆洗或更换滤网后发出“滤网已清洗”、“滤网洗好了”、“洗完滤网了”、“重置滤网”、“复位滤网”、“滤网换好了”等完成时态口令时，因包含“洗”被误拦截为查询滤网健康度并反向播报“滤网洁净度较低建议拆洗”的重大交互认知缺陷；
     - 新增 `VoiceCommand.resetFilterMaintenance`（定向/单机）与 `VoiceCommand.resetFilterMaintenanceAll`（全屋）指令，前置优先匹配重置意图并强化否定动作防御（如“别重置滤网”、“千万不要重置滤网”安全拦截，不被误触发）；
     - 在 `AppModel` 中提供统一的 `resetAllFilterMaintenance()`，在语音胶囊与多设备协同控制链路中支持单机、定向多房间与全屋滤网一键重置清零，洁净度瞬时恢复 100%；
     - macOS 快捷指令（Shortcuts）新增 `ResetFilterMaintenanceIntent`，全面支持 Siri 语音唤起（“用海尔空调重置滤网”、“滤网已清洗”）。
  2. **macOS 原生状态栏与滤网保养面板多设备批量重置矩阵**：
     - 在状态栏右键上下文菜单的“空调设备控制矩阵”各房间级联子菜单中，新增“🧼 重置滤网计时 (当前 XX%，良好/需拆洗)”快捷重置操作项；
     - 状态栏右键主菜单“滤网保养与自清洁”全面升级为级联子菜单，直观提供“打开滤网保养与自清洁面板...”与“🧼 一键重置全屋滤网计时 (恢复100%)”；
     - 优化 `FilterCareSheet` 弹窗界面：多设备环境下新增“全屋重置”按钮与防误触确认弹窗，一键清零全屋所有空调运行计时，无需逐台手动切换确认。
  3. **制冷工况环境湿度潜热冷凝动力学校准与自动模式物理自适应**：
     - 在 `EnergyAnalyticsEngine.estimateInstantaneousPower` 的制冷工况（`.cooling`）中引入环境湿度潜热冷凝相变能耗补偿（$2260\text{ kJ/kg}$ 汽化潜热）：高湿重载环境（$\text{RH} \ge 65\%$）冷凝负荷动态补偿最高 +66W，干燥低湿环境动态调减负荷（最低 -20W），消除以往忽视潜热造成的能耗偏低；
     - 在 `AppModel.calculateFilterWearFactor` 中，对自动模式（`.auto`）根据当前室内温度与设定温差动态切分制冷冷凝结露（1.25x）与制热微附着（1.05x），消除以往自动模式硬编码固定 1.00x 的物理失真。

---

## 2. 关键架构变更与代码实现

### 2.1 滤网保养重置与复位口令解析 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)
- **意图精准分流与时态识别**：
  - 增设 `isResetFilterMaintenance` 结构化谓词，覆盖“重置”、“复位”、“清零”、“已清洗”、“清洗完成”、“洗好了”、“洗完了”、“洗过了”、“换好了”、“换完了”、“已更换”、“更换完成”、“恢复100”及“洗/换/擦 + 干净了/好了/完了”等自然口语表达；
  - 置于滤网健康度查询（`queryFilterHealth`）前置阶段，彻底解决“洗好了”与“要洗吗”因共享“洗”字发生的语法冲突；
  - 扩展 `negativeActionRegex` 否定动词表（纳入“重置/复位/清零”），确保“别重置滤网”、“千万不要重置滤网”严密防御、安全拦截；
- **单元测试保障**：
  - 在 `VoiceCommandParserTests` 中追加 `testFilterMaintenanceReset`，覆盖单机重置（10项）、全屋重置（4项）、否定防御（3项）与查询隔离（2项），共 19 项断言全部 100% 通过。

### 2.2 全链路多端执行闭环与 Siri 快捷指令 (`VoiceCapsuleWindowController.swift` / `AppIntents.swift` / `AppModel.swift`)
- **AppModel 全局清零能力**：
  - 新增 `resetAllFilterMaintenance()`，遍历 `allUnifiedDevices` 重置所有机时并刷新最近清洗时间，发布操作成功通知；
- **语音胶囊分发**：
  - `VoiceCapsuleWindowController` 在单机与多设备控制流（`executeMultiDeviceCommand`）中无缝支持 `.resetFilterMaintenance`；
  - 全局前置指令支持 `.resetFilterMaintenanceAll` 全屋调度并即时反馈；
- **Siri / 快捷指令穿透**：
  - 实现 `ResetFilterMaintenanceIntent`，参数支持指定设备名称或“全屋/全部”，已注册至 `ACAppShortcuts`。

### 2.3 状态栏与保养弹窗多设备批量交互 (`StatusItemController.swift` / `FilterCareSheet.swift`)
- **状态栏右键级联子菜单**：
  - “空调设备控制矩阵”中每个房间均呈现该房间当前滤网洁净度百分比及快捷重置项；
  - “滤网保养与自清洁”升格为子菜单，支持直达主界面弹窗或直接一键重置全屋；
- **FilterCareSheet 批量重置**：
  - 多设备环境下提供“全屋重置”按钮与双重安全确认 Alert 弹窗。

### 2.4 热力学潜热相变能耗动力学 (`EnergyAnalyticsEngine.swift` / `AppModel.swift`)
- **制冷工况潜热模型**：
  - 引入 `latentHumComp` 补偿算法：$\text{RH} \ge 65\%$ 时冷凝吸热加重负荷最高 +66W，$\text{RH} \le 40\%$ 时干燥低潜热动态调减最高 -20W；恒温平衡与满载降温各区间平滑过渡；
- **自动模式磨损系数物理自适应**：
  - 判别室内温度与目标温差，制冷工况赋予 1.25x 湿附着系数，制热工况赋予 1.05x，提升等效寿命预测真实感。

---

## 3. 构建、测试与打包验证闭环
- **本地编译验证**：
  - 运行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 错误编译通过（`Build complete!`）；
- **应用打包与签名**：
  - 运行 `./build_app.sh 1.9.45`，成功构建并签名 `dist/HaierAC.app`（含桌面小组件扩展），并生成发布压缩包 `dist/HaierAC-v1.9.45-macOS.zip`（2.6MB）。

---

## 4. 敏感数据安全审计
- 全仓扫描确认无真实手机号、明文密码、第三方 Secret Token 或私人凭据提交。
