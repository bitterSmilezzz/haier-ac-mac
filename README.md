# Haier AC Mac 控制

[English](README.en.md) | 中文

在 macOS 上控制海尔/统帅智能空调的原生 SwiftUI 应用。支持主窗口完整控制 + 菜单栏迷你控制面板（类似控制中心）。

> 个人项目，仅供学习交流。基于对海尔智家云开放协议的逆向研究，参考了 [banto6/haier](https://github.com/banto6/haier)（Apache-2.0）的协议实现思路，代码为独立编写。

## 功能

- 🏷 **闭环自然语言「刻钟/钟头」时间解析缺陷、滤网全链路语音与快捷指令穿透、自清洁停止对称与除湿热力学双控 (v1.9.44)**：
  - ⏱️ **自然语言「刻钟/钟头」时间解析缺陷与钟点刻数定时对齐 (`VoiceCommandParser` / `VoiceCommandParserTests`)**：
    - 彻底根除中文数字预处理器（`convertChineseNumbers`）缺失“刻钟/半钟头”映射导致的重大口语解析盲区：以往“一刻钟后关机”（15分钟）、“两刻钟后关机”（30分钟）、“三刻钟后关机”（45分钟）、“半个钟头后关机”（30分钟）直接返回 `nil` 无法识别；
    - 修复此前口语“两个半钟头后关机”因正则缺少“个半钟头”未能折算为 2.5 小时（150分钟）的断裂缺陷；
    - 彻底根治钟点定时中因“一刻/三刻”被简单替换为数字“1/3”导致“十点一刻关机”被严重误判为 `10:01`（误差14分钟）、“十点三刻开机”被误判为 `10:03`（误差42分钟）的隐蔽缺陷；全面支持“十点一刻”（10:15）、“十点三刻”（10:45）、“晚上八点一刻”（20:15）与“明早七点三刻”（07:45），实现钟点刻数 100% 精准映射。
  - 🌿 **滤网健康度全链路语音与快捷指令（Shortcuts/Siri）穿透式闭环 (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `AppIntents` / `VoiceCommandParserTests`)**：
    - 新增 `VoiceCommand.queryFilterHealth` 与 `VoiceCommand.queryFilterHealthAll` 语音指令，支持“查询滤网”、“滤网状态”、“滤网洁净度”、“滤网要洗吗”、“全屋滤网状态”等口语即时查询；
    - 语音胶囊与多设备协同链路结合空气动力学等效工时模型，精准反馈洁净度百分比、等效运行机时及清洗保养建议；
    - macOS 快捷指令（Shortcuts）新增 `GetFilterHealthIntent`，支持通过 Siri 或自动化捷径随时查询指定空调或主显设备的滤网健康状况。
  - 🧼 **自清洁快捷指令（StopSelfCleaningIntent）对称补全与全仓主显单源路由收敛 (`AppIntents` / `FilterCareSheet` / `StatusItemController`)**：
    - 在 AppIntents 中新增 `StopSelfCleaningIntent` 并注册至系统快捷指令库，与 `StartSelfCleaningIntent` 形成完整对称闭环，支持随时通过 Siri / 自动化捷径中止 56°C 蒸发器自清洁；
    - `FilterCareSheet` 弹窗初始选中设备收敛至 `model.primaryDeviceId` 单一真实可信数据源；`StatusItemController` 状态栏图标与 Tooltip 主显设备计算全面对齐 `model.primaryDeviceId`，消除多设备环境下硬编码默认设备的状态漂移。
  - 💧 **除湿工况温湿双控热力学动力学校准 (`EnergyAnalyticsEngine`)**：
    - 在 `EnergyAnalyticsEngine.estimateInstantaneousPower` 的除湿工况（`.dehumidify`）中，引入室内温度热力学动态补偿：当室内温度偏高（$\ge 28^\circ\text{C}$）时动态补偿湿空气显热负荷（最高 +80W），当室内温度偏低（$\le 18^\circ\text{C}$）时拟真变频压缩机防结霜阶梯降频保护（最低 -60W），实现多维温湿度耦合仿真。
- 🏷 **闭环自然语言复合半小时缩水缺陷、多房间定向含全部/全都不越权、情景模式全链路路由及菜单栏主显统一同步 (v1.9.43)**：
  - ⏱️ **自然语言复合半小时倒计时折算与中午钟点定时缺陷根治 (`VoiceCommandParser` / `VoiceCommandParserTests`)**：
    - 彻底根除 `convertChineseNumbers` 中粗暴将“半小时”替换为“30分钟”导致“两个半小时后关机”变成“两个30分钟”进而严重缩水为 `30分钟`（误差高达 120 分钟）的重大口语解析缺陷；引入基于自然语法的复合半小时正则匹配（`([一二两三四五六七八九]|\d+)(?:个半小时|个钟头半|小时半|个小时半)`），精准将“两个半小时”、“2个半小时”、“两小时半”转译为 2.5 小时（150 分钟），“三个半小时”转译为 3.5 小时（210 分钟），保证倒计时时间分秒不差；
    - 修复钟点定时中缺少“中午/午后”时段导致口语“中午1点关机”、“中午一点半关机”、“中午2点开机”被误判为凌晨（01:00 / 02:00 AM）的严重缺陷，精准归一为 13:00 / 13:30 / 14:00（12点保持 12:00），贴合中文自然习惯。
  - 🛡️ **多房间定向口令含“全部/全都”防越权全屋拦截加固 (`VoiceCommandParser` / `VoiceCommandParserTests`)**：
    - 彻底修复 `isAllDeviceScope` 以往仅凭包含“全部”或“全都”就武断判定为全屋全局作用域的缺陷；当用户表达“把客厅和主卧全部关了”、“客厅和主卧全都关掉”、“取消客厅和主卧全部定时”时，由于句中明确指定了目标房间（`hasTargetRoomKeyword`），精准界定“全部/全都”为前置房间副词，严禁越权泛化为全屋关机或全屋清空定时；仅当口令明确包含“全屋”、“全家”、“整套”、“所有空调”、“全部空调”等全局主体时才判定为全屋操作，彻底杜绝误伤其他房间空调。
  - 🌟 **情景模式全链路路由闭环与多设备/全屋/快捷指令协同 (`VoiceCapsuleWindowController` / `AppIntents`)**：
    - 彻底根除语音单设备执行“主卧睡眠情景”、“书房离家情景”时，因调用 `model.applyScene(scene)` 未传 `targetDeviceId` 导致穿透误发给客厅（首台默认设备）的严重路由漂移缺陷；
    - 补全全屋情景调度（如“全屋应用睡眠情景”自动下发 `allDevices: true`）与多设备定向情景协同（如“客厅和主卧应用睡眠情景”在 `executeMultiDeviceCommand` 中分发至对应设备）；
    - 在快捷指令 `ApplyACSceneIntent` 中增加可选 `deviceName` 与 `allDevices` 参数，并对齐主设备统一路由。
  - 🍱 **菜单栏控制中心设备路由单源收敛与批量控制面板相对调温 (`MenuBarControlsView` / `BatchControlView` / `AppModel`)**：
    - 消除 `MenuBarControlsView` 中独立的 `@State selectedDeviceId` 导致的状态滞后与脱节隐患，统一收敛至 `model.primaryDeviceId` 单一真实可信数据源（Single Source of Truth），让设备切换无论在控制面板内 Picker 还是状态栏右键上下文菜单均实时互通；
    - 批量控制面板（`BatchControlView`）中的温度增减步进全面升级为调用 `adjustTemperature(includeStandby: true)` 相对调温，保持多设备各自原有的温阶差异并受 16~30°C 极值边界防护，避免粗暴覆盖统一绝对值；并在批量预设中补全“智能 24°C”、“舒爽除湿”与“清新送风”，形成全模式快捷矩阵。
- 🏷 **闭环中文数十复合数字溢出缺陷、多房间定向协同防越权、全仓主显路由收敛与状态栏运行台数精准反馈 (v1.9.42)**：
  - 🔢 **自然语言中文数十复合数字溢出与倒计时/定时缺陷根治 (`VoiceCommandParser` / `VoiceCommandParserTests`)**：
    - 彻底根除中文数字转换器（`convertChineseNumbers`）以往仅映射 11~30、缺失 31~99 十位进阶导致的严重口语溢出缺陷；以往“四十分钟后关机”中“十”被替换为“10”，“四”被替换为“4”，拼接为 `410分钟`（近7小时）；“四十五分钟”被错误转化为 `415分钟`；“五十分钟”转化为 `510分钟`；“三十五分钟”转化为 `305分钟`；
    - 全面升级为基于自然语法结构的复合数字解析（`([一二两三四五六七八九])?十([一二三四五六七八九])?`），100% 覆盖 1~99 的任意中文数字组合（如“四十五”-> 45，“四十”-> 40，“三十五”-> 35，“五十”-> 50，“六十”-> 60，“九十”-> 90），彻底消除时间膨胀隐患；补齐完整的复合中文数字倒计时单元测试用例。
  - 🛡️ **多房间定向协同“都关了/都开了”全屋越权抢占防御闭环 (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `VoiceCommandParserTests`)**：
    - 彻底修复用户针对特定多房间下达口令（例如：“客厅和主卧都关了”、“把客厅和主卧都关了”、“客厅和次卧都开了”）时，因命中关键词“都关了”/“都开了”被 `isAllPowerOff` / `isAllPowerOn` 贪婪抢占，导致全屋所有未涉空调（如儿童房、老人房、书房等）被一锅端全量关机/开机的严重越权缺陷；
    - 在全屋开关机判定中增加房间/设备定向限定词防线（`hasTargetRoomKeyword`），确保当且仅当未指定特定房间时才视为全屋操作；定向多房间指令安全放行至多设备控制链路 `executeMultiDeviceCommand`，仅精准启停所指定的空调设备。
  - 🍃 **多设备与单设备风速控制全链路下发与健壮兜底 (`VoiceCapsuleWindowController`)**：
    - 修复此前多设备协同控制（`executeMultiDeviceCommand`）中调节风速时若设备属性元数据未就绪直接走 `else` 导致指令未真正下发的隐患；
    - 统一收敛至 `model.setWindSpeed(deviceIds:speedName:autoPowerOn:)`，支持动态元数据与静态档位（1微/2中/3强/0自动）平滑降级，并支持带“开”字口令自动联动唤醒待机设备。
  - 📍 **全仓主显设备路由统一收敛与状态栏全屋相对调温台数对称 (`AppModel` / `StatusItemController`)**：
    - 在 `AppModel` 中提供统一的公开只读属性 `public var primaryDeviceId: String?`，集中全仓主显/首选设备路由标准（`menuBarDeviceId ?? allUnifiedDevices.first?.id`），并对齐滤网保养计时累加与重置逻辑，消除多设备环境下硬编码首台设备造成的逻辑漂移；
    - 状态栏右键菜单中，“🔼 全屋统一升温 1°C”与“🔽 全屋统一降温 1°C”全面补齐当前受影响的运行设备台数（如 `(N台运行中)` 或待机时提示 `(当前均未开机)`），与全屋模式预设保持 100% 交互信息对称。
  - ⚡️ **送风工况强劲风量阻力功耗拓展 (`EnergyAnalyticsEngine`)**：
    - 拓展送风模式（`.fan`）在高风阻强劲档位（Turbo）下的动力学功率上限至 75W，使室内强风大风量状态下的热力与空气动力学仿真更为细腻真实。
- 🏷 **闭环全屋调温开机联动与风速协同调度、温限边界反馈优化、自动模式全天候极端动力学及状态栏视觉统一 (v1.9.41)**：
  - 🎙️ **全屋调温待机联动唤醒与开字调温防线闭环 (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `VoiceCommandParserTests`)**：
    - 彻底根除口语“全屋开26度”、“所有空调开25”、“全屋开24”等带“开”字的全屋调温指令在设备关机待机时仅设置温度却未下发开机的严重交互缺陷；在 `VoiceCapsuleWindowController` 中无缝补齐待机设备联动唤醒开机（`onOffStatus = true`），反馈中明确标注“（并开启 N 台待机空调）”；
    - 在 `isAllPowerOn` 中增加 16.0°C ~ 30.0°C 有效温度区间与风速词的严格排除，杜绝任何全屋设定指令被抢占误判为单纯全屋开机。
  - 🍃 **全屋风速协同调度与全链路风速拓展 (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `AppModel` / `VoiceCommandParserTests`)**：
    - 针对用户发出“全屋开大风”、“所有空调开微风”、“全屋自动风”、“把所有空调都调到中速风”等全屋风速口令以往因缺少全屋作用域而回退为单机控制的缺陷，新增 `VoiceCommand.setWindSpeedAll(String)` 指令；
    - 在 `parseAllPreset` 中排除风速关键词，并在全屋流程中前置分发全屋风速；在 `AppModel` 中提供统一的批量与全屋风速控制 API `setWindSpeed(deviceIds:speedName:autoPowerOn:)` 与 `setWindSpeedAll`，全面支持开字联动唤醒待机设备。
  - 🌡️ **全屋与单机相对调温温限边界精准反馈 (`VoiceCapsuleWindowController`)**：
    - 修复此前当全屋空调开机且已全部达到 30°C（或 16°C）极限时，用户说“全屋升温1度”，语音胶囊因变更数为 0 误报“当前无任何开机运行中的在线空调”的缺陷；完善两级判定：无运行空调报待机，运行中均达温限时给出明确温限提示（“全屋运行中的空调均已达到最高温度上限 30°C / 最低温度下限 16°C”）；
    - 单设备与多设备调温同步对齐边界守卫，达到极限时中性提示，杜绝冗余指令下发与虚假成功文案。
  - ⚡️ **自动模式（Auto）全季节极端温差与环境湿度双控动力学深化 (`EnergyAnalyticsEngine`)**：
    - 在 `EnergyAnalyticsEngine.estimateInstantaneousPower` 中，将酷暑极端高温（$\ge 30^\circ\text{C}$）冷凝器散热恶化超频补偿（`heatBoost` 100~280W，顶峰 1750W）与冬季严寒低温（$\le 15^\circ\text{C}$）大温差 PTC 电辅热与大压比高频超载补偿（`coldBoost` 120~320W，顶峰 1950W）完整融入 `.auto` 模式，并接入双向环境湿度动力学微调，实现制冷、制热与自动三大核心工况全季节极端气候动力学的 100% 对称。
  - 🍱 **macOS 状态栏多设备控制矩阵视觉统一与 Tooltip 滤网健康正面提示 (`StatusItemController`)**：
    - 状态栏右键“空调设备控制矩阵...”各房间子菜单中，为一键制冷、制热、除湿、送风、自动等全部模式补齐统一的模式符号（❄️、🔥、💧、🍃、🔄），与顶层菜单保持视觉一致性；
    - 状态栏悬浮 Tooltip 增加健康提示：当全屋滤网洁净度均处于良好状态时，显示“✨ 全屋空调滤网状态良好”。
- 🏷 **闭环自然语言结构化否定防御与全屋定时调度、状态栏五模对称及高温制冷动力学 (v1.9.40)**：
  - 🛡️ **自然语言否定结构化匹配防御与插字绕过根治 (`VoiceCommandParser` / `VoiceCommandParserTests`)**：
    - 针对口语否定词与动作动词之间插入修饰词或宾语（如“别给我关了”、“千万别现在关”、“不用帮我关”、“别太快关”、“别乱调”等）因以往白名单字符集穷举导致的漏判隐患，全面升级为基于自然语法结构的非标点贪婪捕获正则 `(?:别|不要|不用|先别|千万别|切勿|请勿|暂不)[^，。！？\s]{0,6}?(?:关|停|开|启动|运转|打开|关闭|调|设|升|降)`，稳健拦截任意带修饰插入语的否定口语，杜绝家庭闲聊误触发整机或全屋动作；
    - 针对相对/绝对调温、风速、模式、情景等动作动词扩充否定防御，测试套件新增多组真实场景否定用例。
  - ⏱️ **全屋定时/倒计时指令贪婪拦截缺陷根治与多设备协同 (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `VoiceCommandParserTests`)**：
    - 彻底根除“全屋30分钟后关机”、“全屋半小时后开机”因原解析管线中定时解析落后于全屋关机/开机而被贪婪抢占误判为立即全屋断电/开机的严重缺陷；将定时与倒计时解析提升至全屋开关机之前，并在全屋开关机与全屋调温前置条件中增加倒计时/定时关键词防御门禁；
    - 在 `VoiceCapsuleWindowController` 中打通全屋与多设备定向倒计时/定时（`.countdownPower` 与 `.schedulePower`）批量协同调度，支持一键为全屋或多房间同步下发延时任务并给出友好汇总反馈。
  - 🎙️ **开字前缀省略“度”字口语绝对调温解析闭环 (`VoiceCommandParser` / `VoiceCommandParserTests`)**：
    - 修复此前口语调温中省略“度”字（如“开26”、“打开25”、“开24”）被 `isPowerOn` 贪婪前置捕获误判为单纯开机而丢失目标温度的缺陷；通过对提取数字进行 16.0°C ~ 30.0°C 温度有效域严格校验，准确映射为设温指令并联动唤醒待机设备。
  - 🍱 **macOS 状态栏 5-in-1 全模式对称与一键智能自动 24°C (`StatusItemController`)**：
    - 在菜单栏右键全屋快捷预设中新增「🔄 全屋智能自动 24°C (N台在线)」，与全屋制冷、制热、除湿、送风构成完整的 5-in-1 全工况控制矩阵；
    - 在多设备控制矩阵各房间子菜单及单设备上下文菜单中均补齐「一键智能自动 24°C」，实现全屋与单机交互维度的全面对称。
  - ⚡️ **酷暑极端高温与冷凝器恶化能耗动力学超频补偿 (`EnergyAnalyticsEngine`)**：
    - 在制冷工况瞬时功率估算中引入酷暑热力负荷与冷凝器散热恶化补偿机制：当室内外温差大且室内温度极高（室内温度 $\ge 30^\circ\text{C}$，目标温差 $\Delta T \ge 5^\circ\text{C}$）时，拟真变频压缩机超频运转与冷凝器高背压功耗上升，动态叠加重载附加功耗（+100W ~ 280W），将制冷功率峰值拓展至 1750W，与冬季严寒 PTC 辅热模型形成双向季节动力学对称。
- 🏷 **闭环自然语言模式温度复合控制缺陷、状态栏设备矩阵主显一键切换与低温制热动力学 (v1.9.39)**：
  - 🎙️ **自然语言运行模式与设定温度复合指令缺陷根治 (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `VoiceCommandParserTests`)**：
    - 彻底根除口语中同时包含模式与目标温度（如“制冷26度”、“开制冷26度”、“开冷气25度”、“开暖气22度”、“开制热二十度”、“客厅制冷26度”、“主卧开暖气21度”、“客厅和主卧开制冷24度”）因解析顺序导致模式（`operationMode`）丢失的严重缺陷，防止以往夏天口语调温意外保留冬季制热模式造成的冷热倒置；
    - 新增 `VoiceCommand.setModeAndTemperature(mode:temperature:)` 指令模型；解析层前置识别模式与 16~30°C 目标温度；
    - 在单机与多设备批量执行链路（`executeMultiDeviceCommand`）中无缝联动唤醒待机设备、下发模式与目标温度，生成“清爽制冷 26°C”、“舒适制热 20°C”等自然反馈；
    - 全链路扩充调温与变频动作的否定安全防护（“别开制冷26度”、“不要开暖气22度”、“别调到26度”、“千万别开大风”等），杜绝任何误执行。
  - 🍱 **macOS 状态栏多设备矩阵一键常驻主显设备（Primary Device Pinning）(`StatusItemController`)**：
    - 在状态栏右键“空调设备控制矩阵...”各房间子菜单中，增设原生「★ 设为菜单栏主显设备」选项（当前主显设备显示「✓ 菜单栏常驻主显中」并禁用点击）；
    - 点击后一键将 `model.menuBarDeviceId` 切换至指定设备，并即刻触发 `refreshTemperature()` 刷新菜单栏实时温度显示、图标、悬浮 Tooltip 与 Bento Popover 默认聚焦，同时弹出 Toast 确认反馈；
    - 在子菜单顶层设备标题前标示 `★` 徽章，多设备家庭用户在状态栏无需打开主窗口即可随时切换主控房间。
  - ⚡️ **变频制热严寒低温 PTC 电辅热与大温差热负荷动力学校准 (`EnergyAnalyticsEngine`)**：
    - 在 `EnergyAnalyticsEngine.estimateInstantaneousPower` 中，深度优化冬季制热动力学：当室内外温差大且室内温度较低（室内温度 $\le 15^\circ\text{C}$，目标温差 $\Delta T \ge 5^\circ\text{C}$）时，拟真变频空调自动触发 PTC 辅助电加热与超频提温机制，动态计算热负荷附加功耗（+120W ~ 320W），大幅提升严寒季节与速热场景下的能耗仿真精度；
    - 送风模式引入阶梯风速风阻能耗微调，低速静音档微功耗（最低 14W），高速强劲档真实还原风机全速压降能耗。
- 🏷 **闭环自然语言开字模式/调温拦截缺陷、状态栏首选设备路由对齐、多设备状态聚合查询与自动模式湿度动力学 (v1.9.38)**：
  - 🎙️ **自然语言开字前缀与调温拦截缺陷根治 (`VoiceCommandParser` / `VoiceCommandParserTests`)**：
    - 修复此前口语中以“开/打开/开启”为前缀的复合指令（如“开除湿”、“开制冷”、“开制热”、“开送风”、“开26度”、“开到26度”、“开大风”等）被 `isPowerOn` 贪婪前置拦截误判为单纯开机的严重缺陷；增加模式名、带“度”温度值、风速和情景关键词的显式排除，使其准确映射为对应的模式切换与温度调整；
    - 修复“关小风”、“风速关小一点”、“关小一点”等风量下调口语被误判为整机断电关机的问题；
    - 新增 `.queryStatusAll` 全屋状态查询指令模型，区分全屋状态查询（“全屋空调多少度”、“全屋空调状态”）与单机状态查询。
  - 🛡️ **自清洁控制流与多设备批量状态聚合闭环 (`VoiceCapsuleWindowController`)**：
    - 修复 `.stopSelfCleaning` 分支中遗漏的 `scheduleAutoDismiss(delay: 1.8)` 与 `return`，消除控制流泄漏至兜底逻辑的隐患；
    - 将 `.stopSleepCurve` 与 `.queryStatusAll` 提升至顶层多设备/单设备前置分发，避免误报“该操作暂不支持多设备批量执行”；
    - 在 `executeMultiDeviceCommand` 中补齐 `case .queryStatus` 状态聚合查询，按房间格式化汇总运行态与室内温度（如“「客厅」运行中，室温 24.5°C，制冷 26.0°C；「主卧」待机，室温 25.0°C”）；
    - 引入智能待机联动：当用户发出带“开”字的调温或模式切换时，自动为待机设备联锁唤醒开机（`onOffStatus = true`）。
  - 🍱 **macOS 状态栏首选设备路由对齐与动态设备计数 (`StatusItemController`)**：
    - 修复状态栏右键菜单中的单机温度步进（`stepUpPrimaryTemperature` / `stepDownPrimaryTemperature`）与快捷模式预设（制冷/制热/除湿/送风）硬编码抓取 `allUnifiedDevices.first?.id` 导致的路由漂移缺陷，全面收敛对齐至用户当前选定的首选主控设备 `primaryDeviceId` (`model.menuBarDeviceId ?? model.allUnifiedDevices.first?.id`)；
    - 状态栏右键全屋快捷预设菜单项（全屋制冷/全屋制热/全屋除湿/全屋送风）动态显示当前在线可控设备数量（如 `❄️ 全屋清爽制冷 26°C (2台在线)`），反馈更加透明精准。
  - 💧 **自动模式温湿度协同动力学建模 (`EnergyAnalyticsEngine`)**：
    - 在自动模式（`.auto`）瞬时功率估算中引入室内相对湿度（`indoorHumidity`）动力学补偿：高湿工况 ($\text{RH} \ge 65\%$) 自动叠加除湿蒸发负荷补偿，干爽工况 ($\text{RH} \le 45\%$) 相应平滑缩减微载功率，使自动工况功率响应更贴合变频空调的舒适平衡热力学。
- 🏷 **自然语言全链路否定安全防线、调度器解耦重置、除湿变频环境湿度动力学与多设备滤网自适应预测 (v1.9.37)**：
  - 🛡️ **自然语言全链路模式/情景/自清洁/睡眠温阶否定防护与防高温误烘烤 (`VoiceCommandParser` / `VoiceCommandParserTests`)**：
    - 深度扩展否定语义保护网至全屋预设 (`parseAllPreset`)、运行模式 (`parseMode`)、情景模式 (`parseScene`) 以及全屋绝对/相对调温 (`parseAllTemperature` / `parseAllRelativeTemperature`)，杜绝如“全屋空调别开冷气”、“千万别开除湿”、“不要开暖气”、“别开离家模式”等口语被盲目映射为开机和模式切换；
    - 彻底根除当用户发出“不要自清洁”、“别自清洁”、“别开自清洁”、“不要启动自清洁”等口令时，因仅匹配关停动作而落入缺省分支导致意外启动 56°C 蒸发器高温除菌烘烤的严重安全隐患，稳健识别否定词并安全降级为停止自清洁分支；
    - 睡眠温阶启停同步引入否定保护，识别“不要开启智能睡眠”、“别开睡眠曲线”等输入并安全降级为退出；支持“别定时”、“不要定时”口语映射为定时任务取消。
  - ⏱️ **调度器解耦重置与原子全屋/定向定时管理 (`AppModel` / `VoiceCapsuleWindowController`)**：
    - 在 `AppModel` 中提供原子封装方法 `cancelAllSchedules()`、`cancelSchedules(for deviceIds:)` 与 `cancelSchedules(for deviceId:)`，统一处理内存数据清除、`wakeScheduler()` 定时器重置唤醒、`UserDefaults` 同步与运行日志记录；
    - 解决语音胶囊在全屋及定向取消定时任务时直接操作集合而未调用 `wakeScheduler()` 导致后台定时休眠任务未被及时唤醒的隐患，全链路对齐执行范围与系统调度。
  - 🧼 **滤网深度算法：历史机时自适应寿命预测与多设备全生命周期动态感知 (`FilterCareSheet` / `AppModel` / `StatusItemController`)**：
    - 深度打通 `EnergyAnalyticsEngine` 能耗历史与 `FilterCareSheet`，提取过去 14 天真实开机运行机时历史（如日均 8.5h），动态计算折算滤网剩余可用天数（呈现如“• 按近期日均 8.5h 习惯及当前工况估算约可用 45 天”），摆脱以往写死 6h 的生硬估算，兼顾无历史记录时的标准回退；
    - 状态栏右键菜单与悬浮 Tooltip 升级支持全屋多设备滤网健康聚合监测：当任何房间空调洁净度 $\le 30\%$ 时，右键菜单标明“全屋最低 XX%”并加注警示徽标，悬浮提示中明确指出需要拆洗的具体空调，杜绝次卧/儿童房滤网被遗忘。
  - 💧 **除湿工况环境湿度变频能耗动力学建模 (`EnergyAnalyticsEngine` / `AppModel`)**：
    - 在 `DeviceEnergySample` 与瞬时功率估算算法中正式引入环境湿度 (`indoorHumidity`) 维度；
    - 建立基于变频空调热力学除湿特性的三级动态响应机制：高湿重载区 ($\text{RH} \ge 70\%$) 蒸发器深度过冷持续冷凝 (520W~620W 基准)、中湿过渡区 ($55\% \le \text{RH} < 70\%$) 平衡变频除湿 (380W~500W 基准)、低湿/舒适区 ($\text{RH} < 55\%$) 防过度干燥与过冷超低频微载运转 (240W~320W 基准)；无湿度传感器时中性回归标准 420W 基准，使除湿能耗模拟更加拟真。
- 🏷 **闭环 CR 审查缺陷、自然语言插字防误关、全屋/定向定时解耦、能耗动力学阻尼与状态栏全模式拓展 (v1.9.36)**：
  - 🛡️ **自然语言结构化否定保护与插字防误触 (`VoiceCommandParser` / `VoiceCommandParserTests`，闭环 CR P1-1)**：
    - 彻底重构否定动作识别器 `containsNegativeAction`，从简单相邻子串升级为基于结构化语法与容错字符集的正则表达式匹配；
    - 针对否定词（“别”、“不要”、“不用”、“先别”、“千万别”等）与动作谓词（“关”、“开”、“停”等）之间插入修饰词、量词或对象词的句式（如“全屋空调别都关了”、“不要全部关掉”、“先别急着关”、“别马上关”、“别把全屋空调都关了”、“空调不用全开”等）实现 100% 稳健识别与拦截；
    - 在单元测试套件中扩充多条带插入词真实用例，筑牢防误关防线，彻底消除因否定失效引发的全屋误关机隐患。
  - ⏱️ **全屋与定向定时任务取消深度解耦与对称批量处理 (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `VoiceCommandParserTests`，闭环 CR P1-2)**：
    - 在 `VoiceCommand` 中新增 `.cancelSchedulesAll` 全屋指令；解析器区分“取消所有/全部/全屋定时”（映射为全屋清空）与单设备/定向取消（“取消定时与倒计时”）；
    - `VoiceCapsuleWindowController` 顶层接入 `.cancelSchedulesAll`，原子清空全屋所有定时与倒计时并提供明确全屋文案反馈；
    - 在多设备分发方法 `executeMultiDeviceCommand` 中补齐 `case .cancelSchedules` 批量取消分支，支持如“取消客厅和主卧的定时”等多设备定向定时清除，对齐执行范围与反馈口径；同时清理了不可达的死代码模式（闭环 CR P2-2）。
  - ⚡️ **能耗工况比例单一事实来源与历史数据口径平滑迁移 (`EnergyAnalyticsEngine` / `EcoEnergySection`，闭环 CR P2-1, P2-4)**：
    - 在 `EnergyDayRecord` 中补齐 `unknownRatio`，全仓视图层（`EcoEnergySection`）统一改用引擎计算的 `coolingRatio`、`heatingRatio`、`dehumRatio`、`fanRatio` 与 `unknownRatio` 百分比，消除重复计算与零调用点公开属性；
    - 明确记录迁移口径：v1.9.34 及更早版本历史数据以墙钟口径回填，新写入数据以设备机时严格聚合，确保老用户 60 天数据不丢失、图表展示平滑过渡。
  - 🌡️ **状态栏调温 16/30°C 极值边界严密门禁与 AppModel 冗余指令消除 (`StatusItemController` / `AppModel`，闭环 CR P2-3)**：
    - 为状态栏右键菜单中的「🔼 全屋统一升温 1°C」与「🔽 全屋统一降温 1°C」补齐极值边界条件，仅当存在未达 30°C（升温）或未达 16°C（降温）的运行中可控设备时才启用；
    - `AppModel.adjustTemperature` 增加目标变化检测，仅对实际温度发生变更的设备下发指令；当全屋均已达边界时返回 0 并给出友好中性提示，杜绝冗余硬件通信与虚假文案。
  - 🍱 **macOS 状态栏送风/除湿全模式拓展与全屋运行态实时汇总 (高价值优化点 1)**：
    - 状态栏右键菜单全面补齐「💧 全屋舒爽除湿」与「🍃 全屋清新送风」，并在多设备控制矩阵各子菜单与单设备菜单中均增设「一键除湿」与「一键送风」；
    - 状态栏悬浮 Tooltip 顶部新增多设备全局运行态汇总（如 `🏠 全屋 3 台空调中 2 台正在运行`），使全屋状态尽收眼底。
  - 💨 **变频压缩机恒温平衡区低频维持态动力学阻尼模型 (高价值优化点 2)**：
    - 升级 `EnergyAnalyticsEngine.estimateInstantaneousPower`，在制冷与制热模式中引入变频温差连续热阻尼模型；当室内温度达到设定目标（$|\Delta T| \le 0.5^\circ\text{C}$）时，压缩机平滑降载至超低频恒温维持态（制冷 220W 稳态，制热 300W 稳态），杜绝阶跃式功率突变，更精准模拟变频一级能效空调的真实省电特征。
- 🏷 **能耗工况量纲与设备机时精准化闭环、全屋与单机状态栏步进调温矩阵及语音全屋相对调温 (v1.9.35)**：
  - ⚡️ **能耗工况动力学量纲校准与设备机时精准分析 (`EnergyAnalyticsEngine` / `EcoEnergySection`，闭环 CR P2-1/2)**：
    - 解决多设备并发运行时各模式工况分钟数之和超过自然墙钟时长的量纲冲突，建立「全屋自然流逝时长（`totalMinutes`，分）」与「设备累计总机时（`totalDeviceMinutes`，台·分）」双轴核算体系；
    - 在 `EnergyDayRecord` 中引入 `totalDeviceMinutes` 字段，实现自定义 `Codable` 编解码向后兼容，自动平滑迁移历史存档；
    - 在各工况比例计算中封装安全无溢出属性（`effectiveDeviceMinutes`、`coolingRatio`、`heatingRatio`、`dehumRatio`、`fanRatio`），严密钳制除以零风险；
    - 升级能耗仪表板工况看板，直观呈现如 `制冷 120m (60%)` 的机时占比百分比，使多设备运行下的能耗分布一目了然。
  - 🍱 **macOS 状态栏温度微调控制矩阵 (`StatusItemController` / `AppModel`)**：
    - 状态栏右键上下文菜单全面补齐调温操作：多设备场景新增「🔼 全屋统一升温 1°C」与「🔽 全屋统一降温 1°C」，单设备场景及各空调子菜单新增「🔼 升温 1°C (当前 XX°C)」与「🔽 降温 1°C (当前 XX°C)」；
    - 精确联动 16.0°C ~ 30.0°C 硬件极限与开机可达性门禁，触达极值或设备待机/离线时自动禁用，杜绝越界与无效操作；
    - `AppModel` 原生提供 `adjustDeviceTemperature`、`adjustTemperature`、`adjustTemperatureAll` 等批量与单机调温 API。
  - 🎙️ **语音胶囊全屋相对调温与自然语言扩展 (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `VoiceCommandParserTests`)**：
    - 拓展全屋相对调温语音解析，支持“全屋调高两度”、“把所有空调都升温1度”、“全部空调调低一度”等自然语言，自动映射至 `.adjustTemperatureAll(delta:)` 指令；
    - 语音胶囊与多设备定向调度打通全屋与定向多设备相对调温执行与成功反馈提示。
- 🏷 **离线本地操作平权放行、纯电源开机防倒置与否定意图过滤 (v1.9.34)**：
  - 🛡️ **语音执行链门禁下移与本地操作全面平权 (`VoiceCapsuleWindowController`，闭环 CR P1-1)**：重构单设备指令派发的可达性门禁位置，从分发总入口后移至各硬件下发分支。针对状态查询（`.queryStatus`）、定时任务取消（`.cancelSchedules`）、睡眠曲线退出（`.stopSleepCurve`）以及睡眠报告读取（`.querySleepReport`）等纯本地逻辑全面放行，彻底消除当空调处于离线或网关重连时用户无法取消本地定时或查看状态的阻塞缺陷。
  - ⚡️ **纯电源全屋开机防冷暖倒置 (`AppModel` / `AppIntents` / `VoiceCapsule`，闭环 CR P1-2)**：新增 `turnOnDevices(deviceIds:)` 与 `turnOnAllDevices()`，仅下发 `onOffStatus = true`，严格保留并沿用各空调已有设定的运行模式与目标温度；将快捷指令 `TurnOnAllACIntent` 及全屋语音开机 `.turnOnAll` 彻底重构为调用纯电源开机，彻底根除以往全屋开机强行切换为制冷 26°C 导致的冬季冷暖颠倒隐患。
  - 🎯 **定时任务取消定向越权隔离 (`VoiceCapsuleWindowController`，闭环 CR P2-1)**：修复定向取消单设备定时任务（如“取消客厅定时”）时，因目标设备无任务而穿透兜底清空全屋所有设备定时任务的越权漏洞。
  - 📐 **集合精确比对与防脏数据机制 (`BatchControlView` / `AppModel`，闭环 CR P2-2)**：将批量控制与全屋状态判定中的 `count == allUnifiedDevices.count` 重构为基于 `Set` 的集合全等或超集判定，彻底杜绝包含历史解绑残留 ID 时因计数巧合引发的错误全屋提示。
  - 🗣️ **语音命令否定意图过滤与防误触守卫 (`VoiceCommandParser`，闭环 CR P2-3)**：引入否定动作检测器 `containsNegativeAction`，在开关机意图解析中增加否定词拦截（如“全屋空调别关了”、“客厅空调不要关”、“先别开”等），避免家庭闲聊及口语否定句被误识别为电源动作。
  - 🍱 **macOS 状态栏全屋开机协同与批量面板功能对称 (`StatusItemController` / `BatchControlView`)**：
    - 状态栏原生右键菜单新增「⏻ 开启全屋空调 (N 台待机)」快捷项，与「关闭全屋空调」形成对称闭环，保持各设备既有模式开机，并严格对齐 `isEnabled` 门禁口径；
    - 批量控制面板新增「全屋/所选开机」快捷按钮，形成清爽制冷、舒适制热、开机保持、关机待机的四合一完整快捷控制矩阵。
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
- 🏷 **全屋设备全链路平权与离线虚假能耗阻断 (v1.9.30)**：
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
