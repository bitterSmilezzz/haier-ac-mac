# Haier AC Mac 控制

[English](README.en.md) | 中文

在 macOS 上控制海尔/统帅智能空调的原生 SwiftUI 应用。支持主窗口完整控制 + 菜单栏迷你控制面板（类似控制中心）。

> 个人项目，仅供学习交流。基于对海尔智家云开放协议的逆向研究，参考了 [banto6/haier](https://github.com/banto6/haier)（Apache-2.0）的协议实现思路，代码为独立编写。

## 功能

- 🏷 **全屋语音模式智能辨识与温控协同路由、防冷暖倒置 (v1.9.33)**：
  - 🎙️ **全屋自然语言模式与温控协同路由 (`VoiceCommandParser` / `VoiceCapsuleWindowController`)**：重构全屋语音解析与执行管道，彻底消除「全屋开暖气/制热」被 `isAllPowerOn` 误判为开机并执行默认制冷 26°C 导致的**冷暖颠倒严重缺陷**；新增 `presetAll(mode:temperature:)` 与 `setTemperatureAll(Double)` 指令模型，支持“全屋开暖气”、“全屋制热22度”、“所有空调开冷气25度”、“全屋调到24度”、“全屋送风”等自然语言语义直接映射，根据冷暖模式智能设定舒适基准温阶（制热 20°C / 制冷 26°C / 自动 24°C）。
  - 🏠 **多房间组合自然语言协同控制 (`VoiceCapsuleWindowController`)**：将设备目标解析器升级为多设备返回的 `resolveTargetDevices(for:model:)`，支持“客厅和主卧一起关了”、“把次卧跟客厅调到26度”等跨房间复合定向口语，通过 `executeMultiDeviceCommand` 实现多设备并发原子下发与统一成功反馈提示。
  - 🍱 **状态栏单机冷暖直达、多设备运行感知与功率动态格式化 (`StatusItemController`)**：
    - 单设备场景上下文菜单补齐「❄️ 一键制冷 26°C」与「🔥 一键制热 20°C」快捷操作，单双设备场景体验完全对齐；
    - 状态栏图标双态检测引入 `anyDeviceRunning` 判定，当主选设备待机而家中其他房间空调运行时，图标自动呈现实心工作态 `air.conditioner.horizontal.fill`，并在悬浮 Tooltip 中展示多房间运行状态；
    - 瞬时总功率智能自适应：超过 1000W 时自动切换为双精度 `kW` 呈现（如 `1.45 kW`），千瓦以下保持 `W` 显示。
  - 📱 **Siri 与系统快捷指令生态对齐 (`AppIntents`)**：新增 `TurnOnAllACIntent`（开启全屋空调），在 macOS 14+ 及回退分支完整注册至 `ACAppShortcutsProvider`，实现全屋开/关/清洁/调温在 Siri 端的双向闭环。
- 🏷 **批量控制设备作用域隔离、多设备自然语言目标路由与菜单栏全屋制热 (v1.9.32)**：
  - 🛡️ **批量控制面板设备穿透漏洞彻底隔离 (`BatchControlView` / `AppModel`)**：重构 `AppModel` 批量控制 API，将 `turnOffAllDevices` 与 `applyPresetToAllDevices` 升级为支持目标设备集合的 `turnOffDevices(deviceIds:)` 与 `applyPreset(deviceIds:mode:temperature:windSpeed:)`；批量控制面板中的快捷预设（清爽 26°C、暖房 20°C）与关机按钮严格绑定当前用户选中的 `deviceIds` 集合，按钮标题动态智能呈现「全屋关机」vs「所选关机」，彻底杜绝部分勾选时穿透控制未选中房间空调的越权缺陷。
  - 🎙️ **多房间自然语言设备目标智能路由 (`VoiceCapsuleWindowController`)**：新增 `resolveTargetDevice(for:model:)` 房间与设备名称解析器，智能匹配语音指令中的房间名词（如“客厅”、“主卧”、“次卧”、“书房”等），自动将指令路由至对应的具体空调，未指定时平滑回退为主控设备；针对目标设备增加离线与重连拦截（如“「客厅空调」当前离线，无法执行语音指令”），并在指令执行成功后提供具体设备反馈（如“已开启「客厅空调」”）。
  - 🗣️ **口语化句式与把字句语法增强 (`VoiceCommandParser`)**：全面强化中文自然语言口语化与把字句解析语法，支持“把所有的空调都关了”、“把空调全都关了”、“把客厅空调关了”、“次卧空调关一下”、“关闭次卧”、“打开客厅空调”、“开启主卧”等高频家庭口语，排除模式切换命令对开机逻辑的干扰，大幅提升指令识别宽容度。
  - 🍱 **macOS 状态栏季节适应全屋制热与可达性守卫 (`StatusItemController`)**：状态栏原生右键菜单新增「🔥 全屋舒适制热 20°C」快捷协同操作，与「❄️ 全屋清爽制冷 26°C」形成冷暖季双向覆盖；为全屋协同控制项引入 `hasControllable` 物理设备可达性门禁校验，网关重连或全屋设备离线时严格禁用，防止向无效设备批量下发。
- 🏷 **全屋智能协同控制、自然语言自清洁与状态栏实时功率感知 (v1.9.31)**：
  - 🏠 **全屋设备一键协同控制 (`turnOffAllDevices` / `applyPresetToAllDevices`)**：在 `AppModel` 中原生集成全屋一键关机与全屋快捷清爽预设，自动识别过滤在线可达且处于运行中的空调目标集，支持批量并发下发；在多设备批量控制面板 `BatchControlView` 中新增全屋「清爽 26°C」、「暖房 20°C」与「全屋关机」Bento 预设卡片，属性控制项引入首个有效属性设备动态探测，彻底解决首台设备离线导致控制面板空白的问题。
  - 🎙️ **自然语言语音控制升级全屋协同与自清洁托管 (`VoiceCapsuleWindowController`)**：语音指令体系全面扩充：新增全屋关机（“全屋关机”、“关闭所有空调”、“把所有的空调都关了”）、全屋开机（“开启所有空调”、“全屋开机”）以及蒸发器自清洁调度（“启动自清洁”、“蒸发器高温自清洁”、“停止自清洁”）；语音胶囊执行流程重构，全屋与停止指令优先分发，不受单一主控设备离线误拦，实现高容错调度。
  - 📱 **Siri 与系统快捷指令生态全面打通 (`AppIntents`)**：新增 `TurnOffAllACIntent`（关闭全屋空调）与 `StartSelfCleaningIntent`（启动自清洁），通过 `AppShortcutsProvider` 自动注册至 macOS 系统快捷指令与 Siri；修复温度调整 dialog 中的浮点截断 Bug，原生支持 0.5°C 精度细腻微调回显。
  - ⚡️ **macOS 状态栏瞬时总功率与滤网耗损实时感知 (`StatusItemController`)**：将 `EnergyAnalyticsEngine.shared.$currentInstantaneousPower` 与 `model.$filterAccumulatedMinutes` 全面接入 Combine 响应式监听流水线，悬浮 Tooltip 瞬时功率看板与滤网保养预警实时计算响应；原生右键菜单新增「❄️ 全屋清爽制冷 26°C」一键直达，关机动作直接联动全屋可达模型。
  - 🧪 **离线设备回风温度物理剥离**：在分钟级能耗动力学采样积分中，为离线断电设备严格隔离室内温度读取（`indoorTemp: isOnline ? indoorTemp : nil`），消除断网陈旧温度数据对动态热力学模型的干扰。
- 🏷 **全屋设备全链路平权与离线虚假能耗阻断 (v1.9.29)**：
  - 🏠 **全屋设备全链路 100% 平权对齐**：彻底消除项目中分散的 `model.devices.map + model.manualDevices.map` 拼接，全面收敛使用统一去重视图 `allUnifiedDevices`。菜单栏控制面板 `activeDevices` 接入 `effectiveDevices`，使局域网手动直连空调与云端空调在菜单栏弹窗中享有完全平等的设备切换、控制与状态感知能力；情景模式（`SceneViews`）、自动化定时调度（`ScheduleViews`）、主设备列表（`DeviceListView`）及 URL Scheme 启停全链路无死角对齐。
  - ⚡️ **动态可达性感知模型 (`effectiveDevices`)**：重构 `effectiveDevices` 计算属性，动态对齐底层 `reachability(for: u.id) == .available` 真实状态，杜绝云端初始抓取时的陈旧静态在线标记误导视图层。
  - 🛡️ **离线幽灵能耗与虚假滤网磨损彻底拦截**：在能耗动力学后台积分 `accumulatePeriodicWork` 中引入设备物理在线校验 `let isOnline = (reachability(for: dev.id) == .available)`。当空调硬件离线断电断网时，自动将其从高负荷压缩机运行工况切断，不再持续积分数百瓦虚假运行功率，不再为离线空调无故虚耗空气动力学滤网等效使用寿命。
  - 🌤️ **状态栏离线严谨防护与情景下发安全守卫**：状态栏主设备图标 `isPowerOn` 状态接入可达性校验，防止设备断网后图标依然错误高亮为空调运行中；`menuBarTemperatureText` 在设备离线时优雅置空，消除状态栏停留在离线前陈旧温度的误导；`applyScene` 全屋情景动作下发引入可达性熔断门禁，跳过不可控目标。
- 🏷 **全屋设备全链路统一感知与能耗工况动力学升级 (v1.9.29)**：
  - 🖥️ **macOS 状态栏全屋设备统一感知与 Tooltip 彻底重构**：将 `StatusItemController` 状态栏 Tooltip 与设备选择全面重构为基于 `allUnifiedDevices` 统一迭代；消除过去针对云端与手动设备的排他分支，多设备混合场景手动机型与云端机型均获得统一展示；补齐 `model.$manualDevices` Combine 发布者订阅，局域网设备增删即时触发状态栏刷新；待机设备补充展示室内回风传感器实时读数。
  - ⚡️ **56°C 蒸发器高温自清洁热力学能耗动力学建模与积分**：`EnergyAnalyticsEngine` 建立 56°C 高温蒸发器自清洁阶段（急冷结霜、微波解冻与高温烘干灭菌）热力学动力模型（基础功耗 920W + 风速偏置），并在 `accumulateSample` 中准确累计自清洁电量并归入高温热力学工况时长，彻底终结以往自清洁阶段被误算为 1.5W 待机微功耗导致的能耗严重低估缺陷。
  - 🎙️ **Siri 快捷指令与语音胶囊离线可达性拦截**：重构 `VoiceCapsuleWindowController` 与 `AppIntents`（`SetACPowerIntent`, `GetIndoorTemperatureIntent`, `StartSleepCurveIntent` 等）的目标设备解析与门禁逻辑，统一支持 `menuBarDeviceId` 优先与 `allUnifiedDevices` 全局解析；在指令执行前增加 `reachability(for: deviceId).isControllable` 校验，设备离线或网关重连中即时阻断并明确报错，杜绝向离线硬件虚报“操作成功”。
  - 🌙 **全屋多设备智能睡眠温阶指定与视图统一**：`SleepCurveSection` 引入多设备目标空调选择器，突破以往仅依赖首台云端设备的局限，多房间用户可自由为任一指定房间/局域网空调单独开启或终止睡眠温阶曲线；`EcoEnergySection` 能效综合评分与 `NetworkPresenceGuard` 离家防空转守护全面升级为消费 `allUnifiedDevices`。
- 🏷 **全屋统一设备模型与 AppKit 菜单原生门禁修复 (v1.9.28)**：
  - 🛡️ **AppKit NSMenu `autoenablesItems` 原生重写缺陷修复 (闭环 CR P1)**：全面为 `StatusItemController` 中的所有菜单实例（`menu`, `devicesMenu`, `devSubmenu`, `themeMenu`）设置 `autoenablesItems = false`，彻底消除 AppKit 在菜单展开时无视 `isEnabled` 重新强行启用菜单项的系统缺陷，确保离线与重连期间右键菜单中的设备控制项严格不可点击。
  - 🌙 **睡眠曲线「停止」会话纯本地解耦 (闭环 CR P2-1)**：细化睡眠卡片门禁粒度：由于 `stopSleepCurve()` 仅执行纯本地状态归档、定时器清理与助眠音频停止，解除了对其「停止」按钮的不可达禁用，确保设备离线或网关断开时用户依然能随时终止睡眠会话；同时在运行状态下提供柔性离线徽章，而空闲启动按钮严格维持可达性校验。
  - 🏠 **全屋关机计数与可控目标集严格对齐 (闭环 CR P2-2)**：修正状态栏右键「关闭全屋空调 (N 台运行中)」计数与执行逻辑，N 仅统计当前既可达 (`isControllable`) 又处于开机中的空调设备；`turnOffAllDevices` 下发目标集与标题计数 100% 绝对一致，杜绝向离线设备盲目发送指令。
  - 🌿 **56°C 深度保养产品激励策略因果链澄清 (闭环 CR P2-3)**：将 56°C 蒸发器自清洁后 7 天内的 10% 动力学负荷减免，在代码模型注释、界面徽章文案与文档中统一明确为「主动维护与深度清洁的产品健康激励策略」，消除与物理滤网截留机制的概念混淆。
  - 🧬 **全屋全形态设备统一抽象 (`UnifiedDevice`)**：在 `AppModel` 引入 `UnifiedDevice`，自动对云端绑定的 `devices` 与手动添加的 `manualDevices` 进行去重聚合，重构全屋统一设备视图 `allUnifiedDevices`；解决手动空调无法参与能耗动力学聚合、滤网健康跟踪及开机实时属性订阅的问题。
- 🏷 **闭环架构巡检与蒸发器自清洁健康生态联动 (v1.9.27)**：
  - 🛡️ **审查缺陷全面闭环与可达性 Fail-Closed 熔断**：闭环 CR P1 审查，在 `MenuBarControlsView` 中补齐智能睡眠卡片不可达门禁，并在 `AppModel.startSleepCurve` 入口增加守卫与通知；闭环 CR P2-1 审查，`reachability(for:)` 对未匹配设备改为 fail-closed（`.deviceOffline`），`MenuBarControlsView` header 状态圆点与文案全面收敛消费 `reachability`，`BatchControlView` 及 `sendAttributeToDevices` 修复 fail-open 风险并实现设备 ID 去重。
  - ⚡️ **反序列化逐条容错与无偏功率物理模型**：闭环 CR P2-3 审查，`EnergyDayRecord` 所有字段采用 `decodeIfPresent` 安全回退，引入 `FailableDecodable` 逐条解码容错，损坏单条记录隔离输出警告，杜绝整组清空；闭环 CR P2-2 审查，未识别模式功率估算采用制冷制热基于温差绝对值的无偏物理均值模型，消除系统偏差。
  - 🧼 **蒸发器自清洁动力学生态联动与 7 天翅片健康保护**：创新联动 56°C 蒸发器高温自清洁与空气动力学滤网健康模型，持久化记录各设备自清洁日期；自清洁后 7 天内享受 0.90x 动力学负荷减免，在滤网卡片与自清洁卡片高亮展示「✨ 56°C除菌保护中 (-10%负荷)」，自清洁启动全面接入可达性门禁。
  - 🍱 **macOS 状态栏三态全感知与全屋多设备级联控制**：状态栏 Tooltip 统一接入 `reachability` 精准呈现网关重连与设备离线；原生右键上下文菜单升级，支持「⏻ 关闭全屋空调」一键关机，并为各空调提供多设备级联子菜单（开关机、一键制冷 26°C、一键制热 20°C）。
- 🏷 **三态可达性防护与工况自洽能耗引擎 (v1.9.26)**：
  - 🛡️ **设备三态可达性模型全链路阻断与精准回执**：闭环 CR P2-3/4 审查与架构升级，建立 `DeviceReachability`（`.available`, `.gatewayReconnecting`, `.deviceOffline`）三态可达性模型。在菜单栏控制台、主控制面板及批量控制面板中，统一展示网关重连与离线横幅，彻底阻断不可达状态下的幽灵点击；批量控制严谨区分「未选择设备」与「全离线状态」，并在部分设备离线时精准提示已跳过离线条数。
  - ⚡️ **能耗动力学工况全面自洽与向后兼容反序列化**：闭环 CR P2-2/6 审查，`EnergyDayRecord` 新增 `unknownMinutes` 字段，实现自定义 `Codable` 编解码保证旧版 JSON 历史记录 100% 平滑反序列化；重构未知工况自适应功率估算，消除盲目强行兜底与功率虚标；能耗仪表盘新增今日工况运行时长分布看板（制冷/制热/除湿/送风/其他），实现全屋用电完全透明。
  - 🔄 **并发快速重试代际竞态消除**：闭环 CR P2-5 审查，在 `retryConnection` 引入代际计数器 `reconnectGeneration`，异步 Task 延迟唤醒后比对代际，杜绝高频连击重试导致的旧任务冲刷最新连接状态。
  - 🌬️ **相对湿度多维滤网负荷衰减算法**：高价值算法升级，`calculateFilterWearFactor` 引入室内相对湿度附着加权（高湿 ≥75% 赋予 1.25x 负荷膨胀加权，≥65% 赋予 1.12x，低湿干燥 ≤35% 赋予 0.95x 减免），真实反映高湿粉尘吸水膨胀与翅片附着机理。
  - 🧹 **冗余死代码全面清理**：闭环 CR P2-1 审查，彻底删除未使用的 `ACModeCode.localizedName` 死代码。
- 🏷 **网关在途连接安全守卫与菜单栏动态双态感知 (v1.9.25)**：
  - 🛡️ **WebSocket 在途孤儿连接防御与代际熔断**：闭环 CR P1 审查，在 `connect()` 增加任务空态守卫 `guard self.task == nil else { return }`，彻底阻断高频重入导致的并发多连接与死锁；`reconnectImmediately(force: true)` 强化旧任务强制取消与指针置空；`receiveLoop` 全生命周期强化 `task === self.task` 双重代际校验，彻底杜绝孤儿连接接收迟到包。
  - ⚡️ **能耗动力学模型中性自适应与模式精准解包**：闭环 CR P2-1 审查，瞬时功率估算未识别模式兜底由制冷切换为 `.auto`（基于中性温差计算，消除功率虚标）；能耗统计采样器增加精准模式匹配过滤，未识别模式不再计入 `runningCooling`，避免工况饼图失真；语音控制模式未命中时安全报错拦截，不再盲目强切制冷。
  - 🍱 **状态栏原生双态运行感知与右键直达**：主空调开机运行时状态栏图标自动由空心轮廓 `air.conditioner.horizontal` 切换为实心运行态 `air.conditioner.horizontal.fill`；状态栏右键上下文菜单支持主设备一键电源快速启停与在线状态感知；悬浮提示 Tooltip 实时呈现网关连通性。
  - 🛡️ **物理离线全链路防御与 Design Token 语义收敛**：在 `AppModel` 发送控制指令处增加物理离线拦截守卫，防止无效网络请求与虚假乐观更新；在 `Theme` 中收敛 `Theme.offline` 语义设计色彩，菜单栏与控制面板三态（运行/关机/离线）视觉无缝对齐。
- 🏷 **模式安全解包与实时音频轻量快照自愈引擎 (v1.9.24)**：
  - 🛡 **CR 模式语义安全闭环与滤网模型纠偏**：彻底修复 `ACModeCode.match` 未识别工况被强行兜底为制冷的假阳性缺陷；未知模式自动回落至中性基准磨损系数（1.00），彻底消除滤网等效工时高估 20%~35% 的系统偏差；状态栏悬浮 Tooltip 杜绝未识别模式谎报为「❄️ 制冷」并增加物理离线检测。
  - 🔒 **CoreAudio 实时线程纳秒级轻量互斥原子快照**：引入 `os_unfair_lock_s` 纳秒级轻量互斥锁与 `@unchecked Sendable` 的 `AudioRenderParameters` 快照器，实时音频渲染回调极速读取，彻底消灭 TSAN 数据竞争隐患。
  - ⚡️ **网络恢复与休眠唤醒极速秒级自愈**：扩展 `GatewayHandle` 与 `HaierGatewayClient` 极速自愈协议，在 `NWPathMonitor` 检测到网络畅通、切回家庭 Wi-Fi 或系统休眠唤醒时，自动重置指数退避并立即重连，告别长达 120 秒挂起等待。
  - 💡 **物理设备离线状态精细化感知**：菜单栏 Popover 顶部状态指示灯与 Tooltip 精准区分「设备离线 (未连网)」与常规「已关机」，杜绝无响应误解。
- 🏷 **全项目模式标准枚举与 CR 审查闭环 (v1.9.23)**：
  - 🔄 **协议模式码绝对对齐 (`ACModeCode`)**：闭环 CR P1 严重缺陷，彻底修复模式码定义倒挂导致送风工况被误当除湿（1.30x 高负荷）、造成滤网等效工时虚标高估 53% 的问题；统一全局空调运行模式码（0=制冷, 1=制热, 2=送风, 3=除湿, 6=自动），实现跨语音控制、动力学能耗引擎、自动化调度与健康模型的绝对对齐
  - 🍱 **Popover 树稳定性与多设备选中记忆**：闭环 CR P1 缺陷，消除频繁展开菜单栏时无条件重构 `rootView` 导致的 SwiftUI `@State` 重置；引入主题方案脏标记守护，双向对齐 `menuBarDeviceId`，并在设备切换时辅以 macOS 原生平滑弹簧动效
  - 💾 **滤网告警持久化与工况联动可用天数**：闭环 CR P2 审查，滤网健康告警防抖记录持久化至 `UserDefaults`，杜绝冷启动重复轰炸；收敛全局 `filterServiceLifeMinutes` 核心常量（15,000 分钟），按实际工况动力负荷系数联动折算剩余天数
  - 🎧 **助眠音频平滑渐变抗爆音引擎**：闭环 CR P2 审查，音量滑动与声型切换全面接入 `smoothGainTransition` 插值增益与代际熔断锁，杜绝快速拖拽时的音频破音与喀哒声
  - ⚡️ **全屋多设备状态感知与瞬时功率 Tooltip**：状态栏悬浮提示支持全屋所有空调运行工况与整屋瞬时用电总功率一览展示；修复自清洁状态下对温度显示开关的判断；全屋绿色能效得分支持多设备加权评估
- 🌬 **空气动力学多维度滤网健康衰减模型与智能保养 (v1.9.22)**：
  - 🌀 **风量与冷凝结露物理加权**：突破传统固定时长累加，独创空气动力学与湿度工况加权模型，综合风速档位（Turbo 1.7x、高风 1.35x、中风 1.0x、低风 0.8x、微风 0.6x）与热交换器冷凝结露因子（制冷温差 1.35x、除湿 1.30x、制热 1.05x、送风 0.85x）精确折算等效工时
  - 🛡 **系统级防尘减耗维护告警**：洁净度跌破 20% 时系统自动推送维护提醒，杜绝风阻上升导致的高能耗与霉菌滋生
  - 🧼 **多设备数据完全隔离与深层直达**：多设备独立折算运行工时与清洗记录，彻底消除数据污染；菜单栏支持直达保养弹窗，多设备自清洁支持一键平滑交接
- 🔊 **CoreAudio 硬件自适应双耳空间化声学引擎 (v1.9.22 强化)**：
  - 🛡 **代次状态机熔断机制**：引入 `fadeGeneration` 原子代次自增，彻底消除高频点击启停时的淡出 Task 竞态停止引擎缺陷；点击停止即刻响应，UI 交互零延迟
  - 🎧 **动态硬件采样率同步**：基于 `AVAudioEngine` 输出格式动态捕获硬件采样率（44.1kHz / 48kHz / 96kHz+），精确消除跨音频设备切换时的音调漂移与相位抖动
  - 🌊 **双耳去相关真实立体声合成**：左右声道采用独立独立滤波状态机（`b0L...b6L`, `b0R...b6R`）与 Brown 噪声漂移发生器，支持 CoreAudio 非交错与交错多通道缓冲流
  - 🎵 **5 大纯算法程序化自然声型**：春夜细雨、海风浪涌、森林微风、夏夜静谧、清晨林鸟，**零音频资源依赖（0 MB 资源包，~0% CPU 极低功耗）**
- ☁️ **macOS 状态栏动态感知与 Popover 即时主题刷新 (v1.9.22)**：
  - ✨ **自清洁与睡眠动态图标**：蒸发器自清洁期间状态栏图标动态切换为 `sparkles` 并显示 56°C 倒计时，睡眠曲线运行中显示 `moon.fill`
  - 🎨 **主题模式即时响应**：菜单栏 Popover 每次弹出动态注入当前配色主题，彻底解决切换主题后弹窗旧样式残留
- ⚡ **多设备动力学能耗聚合与精准瞬态积分 (v1.9.21)**：
  - 🏠 **全屋并发动力学功率模型**：全面支持多台空调并发动力学聚合，根据各设备模式、室内外温差梯度 $\Delta T$ 与风速动态计算瞬时功率（15W ~ 1650W/台）
  - ⏱ **精准流逝时间积分**：自适应系统休眠与调度抖动，基于真实硬件时间戳计算能量积分 `(power * deltaHours) / 1000.0`，彻底消除电量账单误差
  - 💰 **阶梯与峰谷分时电价账单**：支持单一平段与峰谷分时电价（峰时 0.65¥/谷时 0.35¥），长达 60 天每日历史账单与 7 日用电趋势柱状图
- 🧼 **56°C 蒸发器高温自清洁全生命周期托管 (v1.9.21)**：
  - 🔄 **全局状态机与后台常驻**：自清洁 20 分钟倒计时提升至 `AppModel` 全局托管，关闭弹窗仍于后台平稳运行
  - 🔔 **系统级完成通知**：自清洁结束通过 `UNUserNotificationCenter` 自动推送完成提醒
  - 📑 **多设备独立滤网健康管理**：多空调独立累计运行工时（250h 清洗周期），支持分设备重置与多设备维护状态切换
- 🛡 **全屋离家断网防空转智能守护 (v1.9.21)**：
  - 📡 **物理网络与 SSID 状态监听**：基于 `NWPathMonitor` 与 `CoreWLAN` 监听 Mac 网络状态与 Wi-Fi SSID
  - ⚠️ **全屋空调空转警报**：离家断网超 15 秒自动扫描全屋所有空调设备，聚合报警全部未关机设备、模式与设定温度
- ☁️ **控制中心式菜单栏与状态感知 Tooltip (v1.9.21)**：
  - 💡 **多维悬浮状态概览**：菜单栏图标悬浮提示动态显示主控设备状态、模式、温湿度、自清洁倒计时、睡眠方案与白噪音播控
  - ⚡ **右键快捷播控与直达**：右键菜单一键开/关助眠白噪音、直达滤网保养与自清洁面板
  - 🍱 **NSPopover 原生 Bento 控制卡**：自清洁进行中实时进度条、白噪音迷你播放器与 24h 极简 Sparkline（规避 macOS 26 `MenuBarExtra` 幽灵窗口缺陷）
- 🌙 **全维智能睡眠温阶体系**：
  - 🛏 **定时就寝与睡前预冷**：提前 15 分钟预冷营造入眠体感，到点无缝接管启动睡眠温阶
  - 🌡️ **室内温差自适应补偿 & 温湿度双控**：高湿加强控湿、低湿减缓抽湿呵护呼吸道，偏离预设时自动微调 ±1°C
  - ⌨️ **全局快捷键极速启停**：无论应用是否在前台，按 `Control + Option + S` 随时一键启停智能睡眠
  - 📑 **睡眠记录与数据导出**：支持标准 UTF-8 BOM CSV 导出、剪贴板复制与 ASCII 精美睡眠报告卡片分享
- 🎨 **全新设计系统与控制中心风格 (v1.9.0)**：
  - 🧊 **原生毛玻璃材质 (Vibrant Material)**：状态栏 NSPopover 全面采用 macOS 原生 Vibrant Material 毛玻璃效果与无边框微光卡片
  - 🍱 **模块化 Bento 网格布局**：菜单栏与主窗口采用精致 Bento 布局，功能边界分明、层次聚焦
  - 🌡️ **动态语义化模式色 (Mode Tint)**：根据空调工作模式自适应冷暖色调（制冷冰蓝、制热暖橙、除湿水青、送风薄荷、待机淡紫），卡片光晕与控制元素随状态呼吸流动
  - 💊 **触感温控大胶囊**：取代繁冗滑条，大号步进器胶囊支持 ±0.5°C 细腻步进与即时触觉反馈
  - 📟 **Hero Temperature Pod**：42pt 巨幅数字主温区，双层室温/湿度遥测胶囊
  - 📈 **Swift Charts 柔光趋势图**：24h 渐变柔光 Area Trend 曲线图与实时温度呼吸脉冲点（Pulsing Beacon），菜单栏配备极简 Sparkline
  - 📂 **分类折叠抽屉**：高级扩展设置按「风向摆风」「健康清洁」「伴眠能效」「高级硬件参数」四象限分类折叠，彻底告别冗长滚动
- 🔐 **手机号 + 密码登录**海尔智家云（统帅/海尔/卡萨帝设备通用）
- 🖥 **主窗口控制面板**：
  - 灯光/屏显开关（情景灯光置顶）
  - 电源、目标温度、模式、风速
  - 其余全部可写属性动态渲染（开关/选择器/滑块）
  - 📈 实时状态胶囊（室内温度/湿度/模式/风速）+ 24h 温度趋势曲线（Swift Charts）
- ☁️ **菜单栏迷你面板**：控制中心风格 Bento 弹窗，支持电源、温度胶囊加减、运行模式、风速与 24h 极简温度 Sparkline（`NSStatusItem + NSPopover`，规避 macOS 26 `MenuBarExtra` 幽灵窗口缺陷）
- 🧩 **桌面小组件**：小/中尺寸，实时显示室内温度、目标温度、湿度、运行状态（AppGroup 共享快照，状态变化即时刷新）
- 🎨 **三态主题**：跟随系统 / 浅色 / 深色（macOS Native + Linear 混合设计体系，双色板）
- 📡 实时状态：WebSocket 网关订阅属性推送，断线指数退避自动重连（5s→120s），心跳故障自检
- 🔑 Token 自动刷新（10 天有效期）：临近过期主动续期 + 凭据失效（401/403）自动续期重连，Keychain 凭据已迁移至加密文件存储
- ⏱ 本地调度：定时/倒计时任务（仅一次/每天/按星期多选），支持编辑/暂停/删除，到点自动下发 + 系统通知；情景模式一键应用（可指定设备或全部设备），支持编辑
- ⚡ 多设备批量控制：批量模式全选/多选设备，同发电源/温度/模式/风速
- 🗣 Shortcuts/快捷指令：开关电源、设置温度、切换模式、应用情景、查询温度（Siri 可用）
- 🛡 健壮性：连接代际隔离（旧连接迟到回调不误杀新连接）、登出竞态防护、断线后状态恢复、会话有效时一键重连（无需重新登录）

## 架构

```
SwiftUI App
├── HaierACCore        # 协议核心库（纯系统框架，零第三方依赖）
│   ├── DeviceProvider     # 提供商协议：多品牌扩展位（海尔/华为/米家）
│   ├── HaierProvider      # 海尔实现（登录/设备/数字模型/网关）
│   ├── RequestSigner      # SHA256 请求签名（CryptoKit）
│   ├── HaierCloudClient   # REST：登录/刷新/设备/数字模型/网关
│   ├── HaierGatewayClient # WebSocket：订阅/心跳/控制/断线重连（连接代际隔离）
│   ├── Zlib               # 下行数据解压（系统 libz）
│   ├── CredentialStore    # 凭据加密存储（硬件绑定密钥 + AES-GCM）
│   └── KeychainStore      # 旧版迁移（Keychain → 文件，一次性）
└── HaierACApp         # SwiftUI 界面
    ├── AppModel           # 状态机：登录/连接/控制/反馈/调度/情景/快照
    ├── StatusItemController # 菜单栏状态项（NSStatusItem + NSPopover）
    ├── Views/             # 登录/设备列表/控制面板/菜单栏面板/批量/调度/情景/反馈
    ├── AppIntents.swift   # Shortcuts/快捷指令集成
    └── Theme.swift        # 设计令牌（浅色/深色双色板、动态语义模式色、Bento 卡片材质）
└── HaierACWidget      # WidgetKit 桌面小组件（AppGroup 共享状态快照）
```

## 测试与 CI

```bash
swift test    # 协议层单测（签名/解析/解码；需完整 Xcode，本机 CLT 不含 XCTest）
```
GitHub Actions 自动在 macos-latest 上构建 + 测试。

## 构建

要求：macOS 13+，Xcode Command Line Tools（含 Swift 6）。

```bash
./build_app.sh            # 构建 + 打包 dist/HaierAC.app（默认 v1.9.0，不自动打开）
./build_app.sh 1.9.0 --open   # 指定版本号 + 构建后自动打开
```

## 隐私与安全

- **密码不落盘**：仅用于换取访问令牌，登录后立即从内存清除
- **Token 存本地文件**（`~/Library/Application Support/HaierAC/credentials.json`，权限 600 仅当前用户可读写），到期自动刷新
  - 为什么不用 Keychain：本应用为 ad-hoc 签名（个人项目每次打包重新签名），macOS 钥匙串对匿名签名调用者会反复弹出密码框；文件存储彻底消除弹窗，token 为短期凭证（10 天有效）风险可控
- **代码零敏感信息**：无硬编码账号/手机号/appKey；appKey 从 `HAIER_APP_KEY` 环境变量或本地 `~/.haier-ac-appkey` 文件读取（不入库）
- **日志脱敏**：诊断日志（`~/Library/Logs/HaierAC/app.log`）中 token 已脱敏
- 凭据仅与海尔官方云（zj.haier.net / uws.haier.net / wssgw.haier.net）通信

## 协议验证脚本（可选）

```bash
# 1. 协议验证：登录/设备/数字模型
HAIER_PHONE='手机号' HAIER_PASSWORD='密码' HAIER_APP_KEY='appKey' python3 verify_protocol.py

# 2. WebSocket 网关全量上报验证（需 uv）
HAIER_PHONE='手机号' HAIER_PASSWORD='密码' uv run --with websockets python3 websocket_verify.py 30

# 3. 真实控制指令测试（灯光开关开/关）
HAIER_PHONE='手机号' HAIER_PASSWORD='密码' uv run --with websockets python3 send_control_test.py
```

## 免责声明

本项目与海尔集团无关，非官方软件。仅限个人、合法、非商业用途。若海尔官方协议变更导致不可用，恕不另行通知。使用本项目产生的一切后果由使用者自行承担。
