# Haier AC Mac v1.9.42 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.42`
- **发版主题**：闭环中文数十复合数字溢出缺陷、多房间定向协同防越权、全仓主显路由收敛与状态栏运行台数精准反馈
- **核心目标与架构演进**：
  1. **自然语言中文数十复合数字溢出与倒计时/定时缺陷根治**：
     - 彻底根除中文数字转换器（`convertChineseNumbers`）以往仅映射 11~30、缺失 31~99 十位进阶导致的严重口语溢出缺陷；以往“四十分钟后关机”中“十”被替换为“10”，“四”被替换为“4”，拼接为 `410分钟`（近7小时）；“四十五分钟”被错误转化为 `415分钟`；“五十分钟”转化为 `510分钟`；“三十五分钟”转化为 `305分钟`；
     - 全面升级为基于自然语法结构的复合数字解析（`([一二两三四五六七八九])?十([一二三四五六七八九])?`），100% 覆盖 1~99 的任意中文数字组合（如“四十五”-> 45，“四十”-> 40，“三十五”-> 35，“五十”-> 50，“六十”-> 60，“九十”-> 90），彻底消除时间膨胀隐患；补齐完整的复合中文数字倒计时单元测试用例。
  2. **多房间定向协同“都关了/都开了”全屋越权抢占防御闭环**：
     - 彻底修复用户针对特定多房间下达口令（例如：“客厅和主卧都关了”、“把客厅和主卧都关了”、“客厅和次卧都开了”）时，因命中关键词“都关了”/“都开了”被 `isAllPowerOff` / `isAllPowerOn` 贪婪抢占，导致全屋所有未涉空调（如儿童房、老人房、书房等）被一锅端全量关机/开机的严重越权缺陷；
     - 在全屋开关机判定中增加房间/设备定向限定词防线（`hasTargetRoomKeyword`），确保当且仅当未指定特定房间时才视为全屋操作；定向多房间指令安全放行至多设备控制链路 `executeMultiDeviceCommand`，仅精准启停所指定的空调设备。
  3. **多设备与单设备风速控制全链路下发与健壮兜底**：
     - 修复此前多设备协同控制（`executeMultiDeviceCommand`）中调节风速时若设备属性元数据未就绪直接走 `else` 导致指令未真正下发的隐患；
     - 统一收敛至 `model.setWindSpeed(deviceIds:speedName:autoPowerOn:)`，支持动态元数据与静态档位（1微/2中/3强/0自动）平滑降级，并支持带“开”字口令自动联动唤醒待机设备。
  4. **全仓主显设备路由统一收敛与状态栏全屋相对调温台数对称**：
     - 在 `AppModel` 中提供统一的公开只读属性 `public var primaryDeviceId: String?`，集中全仓主显/首选设备路由标准（`menuBarDeviceId ?? allUnifiedDevices.first?.id`），并对齐滤网保养计时累加与重置逻辑，消除多设备环境下硬编码首台设备造成的逻辑漂移；
     - 状态栏右键菜单中，“🔼 全屋统一升温 1°C”与“🔽 全屋统一降温 1°C”全面补齐当前受影响的运行设备台数（如 `(N台运行中)` 或待机时提示 `(当前均未开机)`），与全屋模式预设保持 100% 交互信息对称。
  5. **送风工况强劲风量阻力功耗拓展**：
     - 拓展送风模式（`.fan`）在高风阻强劲档位（Turbo）下的动力学功率上限至 75W，使室内强风大风量状态下的热力与空气动力学仿真更为细腻真实。

---

## 2. 关键架构变更与代码实现

### 2.1 中文数十复合数字结构化解析 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)
- **根除数字拼接溢出**：
  - 重构 `VoiceCommandParser.convertChineseNumbers`，采用结构化正则 `([一二两三四五六七八九])?十([一二三四五六七八九])?` 逆序提取十位与个位数值，计算 `tens * 10 + ones` 替换回原文；
  - 完美解决“四十分钟”（40分）、“四十五分钟”（45分）、“五十分钟”（50分）、“六十分钟”（60分）、“九十分钟”（90分）、“三十五分钟”（35分）以及“二十六度”（26度）等各种口语定时与温控数字；
  - 在 `VoiceCommandParserTests` 中追加多组中文数十复合倒计时测试用例，全量通过校验。

### 2.2 多房间定向协同“都关了/都开了”越权抢占拦截 (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)
- **定向房间限定词防线**：
  - 新增 `targetRoomKeywords = ["客厅", "主卧", "次卧", "书房", "儿童房", "老人房", "客房", "餐厅", "阳台", "卧室", "厨房"]` 与 `hasTargetRoomKeyword` 判定；
  - 在 `isAllPowerOff` 与 `isAllPowerOn` 中设置前置守卫：当语句中包含明确房间词且不包含全局全量词时，拒绝将其判定为全屋开关；
  - 确保口令如“客厅和主卧都关了”正确解析为针对客厅与主卧的 `.setPower(false)`，经由 `executeMultiDeviceCommand` 仅关停这两台设备，防止误杀全屋其他房间空调。

### 2.3 风速多设备全链路下发与待机唤醒 (`VoiceCapsuleWindowController.swift`)
- **执行闭环与下发兜底**：
  - 在 `executeMultiDeviceCommand` 与单设备 `executeCommand` 中，重构 `case .setWindSpeed` 调用 `model.setWindSpeed(deviceIds:speedName:autoPowerOn:)`；
  - 无论设备的动态属性元数据是否已经从云端同步完成，均通过多级档位映射安全下发指令；并在口令含“开”（如“客厅和主卧开大风”）时联动唤醒待机设备。

### 2.4 全仓主显设备路由标准收敛与状态栏计数对称 (`AppModel.swift` / `StatusItemController.swift`)
- **主显路由收敛**：
  - `AppModel` 暴露公开属性 `primaryDeviceId`，统一将 `menuBarDeviceId ?? allUnifiedDevices.first?.id` 确立为全仓单例路由；
  - 滤网保养计时累加（`accumulateFilterMinutes`）与手动重置（`resetFilterMaintenance`）全面对齐 `primaryDeviceId`；
- **状态栏计数对称**：
  - 状态栏右键菜单中，“🔼 全屋统一升温 1°C”与“🔽 全屋统一降温 1°C”追加当前运行设备计数提示 `(N台运行中)` 或 `(当前均未开机)`，使得用户在点击前即可直观预期下发影响范围。

### 2.5 送风工况强劲风量阻力动力学功率上限拓展 (`EnergyAnalyticsEngine.swift`)
- 在 `EnergyAnalyticsEngine.estimateInstantaneousPower` 中，将 `.fan`（送风模式）瞬时功率上限从 65W 拓展至 75W，使强劲风速下的风机动力学能耗表现更加契合 1.5 匹大风量贯流风机特性。

---

## 3. 构建、测试与打包验证闭环
- **本地编译验证**：
  - 运行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，0 错误构建完成；
- **全链路独立断言校验**：
  - 针对中文复合数字倒计时、定向多房间开关防抢占、全屋全量开关等共 18 项关键断言运行独立测试套件，全部 100% 通过；
- **应用打包与签名**：
  - 运行 `./build_app.sh 1.9.42`，成功构建并签名 `dist/HaierAC.app`（含桌面小组件扩展），并生成发布压缩包 `dist/HaierAC-v1.9.42-macOS.zip`。

---

## 4. 敏感数据安全审计
- 全仓扫描确认无真实手机号、明文密码、第三方 Secret Token 或私人凭据提交。
