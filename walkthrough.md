# Haier AC Mac v1.9.57 发布与巡检演进报告

## 1. 概述与版本定位
- **版本号**：`v1.9.57`
- **发版主题**：闭环自然语言单星期与扩展周期重复定时、调度器防时钟漂移、macOS 状态栏单设备独立倒计时矩阵及 Siri 快捷指令周期调度
- **核心目标与架构演进**：
  1. **自然语言“每周一至周日/逢周一/周一到周六”单星期与扩展周期重复定时全链路闭环 (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `VoiceCommandParserTests`)**：
     - **彻底修复单星期与多日扩展周期重复被误当单次任务且执行一次即被永久删除的严重缺陷**：彻底修复日常语音高频说出“每周一早上8点开空调”、“每周五晚上10点关机”、“每周日晚上11点关空调”、“每个星期一早上7点开空调”、“逢周一早上8点开机”、“周一到周六早上7点开机”等特定周期口令时，旧逻辑遗漏星期周期判定导致回退至单次 `.schedulePower` 且在首次触发后被永久删除的缺陷；
     - **全链路扩充单星期（周一至周日）与多日扩展星期矩阵**：解析层精准辨识“每周一”至“每周日”（`[2]`~`[7]`, `[1]`）以及“周一到周六/周一至周六”（`[2,3,4,5,6,7]`）；单机、全屋与多设备三条执行流统一计算周期初始触发时刻（`initialFireDate`），在触发后自动按周/星期循环无缝顺延；
     - **长复合否定意图防线扩展**：将否定词与动作谓词之间的插字检测窗口由 6 字符扩展至 10 字符，完美防御长修饰口令（“千万别每周一开机”、“不要每个星期五开空调”、“别周一到周六定时开机”），杜绝家庭闲聊误触发。
  2. **计划调度器时钟漂移与系统睡眠唤醒时间篡改彻底修复 (`AppModel.nextFireDate` / `AppModel.fireDueActions` / `ScheduledAction`)**：
     - **根治按星期重复调度时钟累加漂移与睡眠唤醒时间污染**：重构 `nextFireDate` 逻辑，严格传入 `originalFireDate` 并在顺延时完整保留原任务的时、分、秒，彻底根除此前因向 `nextFireDate(after:)` 传入 `now` 导致每次触发累加秒级偏差、以及 Mac 睡眠唤醒后任务触发时间被错误篡改为唤醒时刻的严重缺陷；
     - **彻底根治 `repeatLabel` 语病与双重前缀**：修复 `[2]` 被格式化为“每周周一”、`[2,3,4,5,6]` 被格式化为“每周周一周二周三周四周五”的界面语病，规范为清晰自然的“每周一”、“工作日”、“周末”、“周一至周六”及“每周一、三、五”中文描述。
  3. **macOS 原生状态栏单设备独立倒计时矩阵与全屋开机预冷/预热扩展 (`StatusItemController`)**：
     - **多设备控制矩阵专属倒计时子菜单**：在状态栏多设备控制矩阵（`devSubmenu`）中为每台设备增设专属「⏱ 快捷倒计时...」子菜单（支持 30分/1小时/2小时关机以及 30分/1小时开机预冷/预热），彻底解决以往只能控制主设备、无法在状态栏为其他房间设置倒计时的痛点；
     - **顶层计划调度矩阵升级**：顶层「⏱ 计划调度」子菜单增设「❄️ 快捷开机预冷/预热倒计时」与「🏠 全屋统一关机倒计时」预设，重构 `quickCountdownFromMenu` 完美兼容设备级与全屋级调度，提供精准清晰的 Toast 操作反馈。
  4. **Siri 快捷指令与 AppIntents 计划调度灵活性提升 (`AppIntents.swift`)**：
     - `ScheduleACPowerIntent` 新增 `repeatSchedule` 周期重复参数（支持设定“工作日”、“周末”、“每天”、“每周一”至“每周日”、“周一至周六”），消除以往只能设定每天重复的生态限制；
     - 在 `ACAppShortcuts` 中注册“工作日定时关机/开机”、“周末定时关机/开机”、“每天定时开机”等高频系统短语。
  5. **送风工况高风速空气动力学滤网负荷模型校准 (`AppModel.calculateFilterWearFactor`)**：
     - 在 `calculateFilterWearFactor` 的 `.fan` 分支中细化空气动力学机理：当室内处于强劲/高风速运转时（`windFactor >= 1.35`），高速风切力扬起微尘并增大流通截留截面，动态校准工况因子为 `0.95`（低中风速维持 `0.85`）。

---

## 2. 关键架构变更与代码实现

### 2.1 单星期与扩展周期重复定时调度 (`VoiceCommandParser.swift` / `VoiceCapsuleWindowController.swift`)
- **意图模式识别与指令建模**：
  - 在 `parseScheduleOrCountdown` 中扩充循环周期修饰语规则：
    - `每周一` 至 `每周日`、`每个星期一` 至 `每个星期日`、`逢周一` 等对应单个星期标量（`[2]` ~ `[7]`, `[1]`）；
    - `周一到周六` / `周一至周六` 对应 `[2, 3, 4, 5, 6, 7]`；
  - 在 `hasTimingOrCountdownIntent` 中纳入 `"每周"`, `"每逢"`, `"逢周"`, `"每个周"`, `"每个星期"`, `"每夜"`，彻底杜绝“全屋每周一早上8点开机”被误判为即时开机动作；
  - 将 `negativeActionRegex` 的非空插字跨度从 6 字符扩展至 10 字符，守住否定语义安全底线。

### 2.2 计划调度器时钟漂移与显示语病根治 (`AppModel.swift`)
- **时、分、秒严格保持与时间锚定**：
  - 新增 `nextFireDate(after now: Date, originalFireDate: Date, weekdays: [Int], calendar: Calendar = .current) -> Date`；
  - 提取 `originalFireDate` 的精确时、分、秒，在 `now` 之后寻找下一个符合 `weekdays` 的时刻，彻底避免 `now` 带来的时间偏移与系统唤醒篡改。
- **`ScheduledAction.repeatLabel` 规范化**：
  - 剔除多余的重复词“周”，针对单星期输出“每周一”，工作日输出“工作日”，周末输出“周末”，六日工作制输出“周一至周六”，多星期组合输出“每周一、三、五”。

### 2.3 状态栏设备矩阵专属倒计时与全屋开机扩展 (`StatusItemController.swift`)
- **设备级独立快捷倒计时**：
  - 在多设备矩阵的 `devSubmenu` 中直接挂载「⏱ 快捷倒计时...」，包含 30分钟、1小时、2小时关机以及 30分钟、1小时开机预冷/预热，精准控制任意房间空调。
- **顶层计划调度功能扩充**：
  - 增加全屋统一关机与开机预冷/预热选项，重构 `quickCountdownFromMenu(_:)`，支持接收包含 `minutes`, `powerOn`, `deviceId`, `all` 的完整参数字典，统一输出语义透明的 Toast 提示。

### 2.4 Siri 快捷指令与周期调度体系升级 (`AppIntents.swift`)
- **`ScheduleACPowerIntent` 支持周期参数**：
  - 增加 `repeatSchedule: String?`，内部智能解析为对应 `weekdays` 与 `repeatsDaily`；
  - 完善 `ACAppShortcuts` 短语库，覆盖工作日、周末和每天定时开/关机。

### 2.5 送风工况气动力学滤网衰减模型校准 (`AppModel.swift`)
- **风速截留动力学细化**：
  - 送风模式（`.fan`）在高风量通量（`windFactor >= 1.35`）下动态校准工况因子为 `0.95`，低中风量维持 `0.85`，与流体力学真实吸尘机理达成物理对称。

---

## 3. 构建、测试与打包验证闭环
- **底层编译与语法校验**：
  - 运行 `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk swift build`，全模块编译 100% 通过（Build complete!）；
- **独立用例验证**：
  - 25 项专用自动化测试用例全量验证通过（ALL 25 VERIFICATION CHECKS PASSED SUCCESSFULLY!）；
- **应用打包与代码签名**：
  - 执行 `./build_app.sh 1.9.57` 打包，小组件（沙盒 + Application Support 只读例外）与主应用代码签名顺利完成；
  - 产出安装包：`dist/HaierAC-v1.9.57-macOS.zip`。
