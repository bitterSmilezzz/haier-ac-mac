# Haier AC Mac Control

A native SwiftUI app to control Haier / Leader (统帅) smart air conditioners on macOS. Full control panel in the main window, plus a menu bar mini control panel (Control-Center-like).

> Personal project for learning purposes only. Based on reverse-engineered Haier Smart Home cloud protocol, referencing [banto6/haier](https://github.com/banto6/haier) (Apache-2.0) for protocol insights. Code is independently written.

## Features

- 🏷 **Cross-Weekend Repeating Schedule Engine, Status Bar Single-Device Deduplication & Filter Symmetry, and Continuous Aerodynamic Filter Damping Dynamics (v1.9.63)**:
  - ⏱️ **Cross-Weekend Repeating Schedule Engine & Full Task Semantics (`VoiceCommandParser.swift` / `AppModel.swift` / `VoiceCommandParserTests.swift`)**:
    - **Cross-Weekend Long Span Expansion**: Extended the shared `parseRepeatWeekdays` engine with multi-day cross-weekend recurring schedules: Friday-to-Monday (`[1, 2, 6, 7]`), Saturday-to-Tuesday (`[1, 2, 3, 7]`), and Sunday-anchored spans including Sunday-to-Friday (`[1..6]`), Sunday-to-Thursday (`[1..5]`), Sunday-to-Wednesday (`[1..4]`), and Sunday-to-Tuesday (`[1..3]`), harmonized with natural language integer mappings;
    - **Weekend Colloquial Variation Parity**: Normalized spoken variants like "周六日/周六天/星期六天/礼拜六天/礼拜六日" into standard weekend recurrence (`[1, 7]`);
    - **Task Scheduling Clearing & Universal Task Semantics**: Extended `isCancelSchedule`, `isPauseSchedule`, and `isResumeSchedule` with "清空" (clear all) and "任务" (task) keywords (e.g., "清空定时", "取消所有任务", "暂停所有任务", "恢复所有任务"), backed by defensive negation protection in `containsNegativeForAction` and `negativeActionRegex`;
    - **Harmonized UI Labels**: Aligned `AppModel.formatRepeatWeekdaysLabel` with all newly added recurring schedule spans.
  - 🍱 **macOS Status Bar Single-Device Deduplication & Filter Reset Symmetry (`StatusItemController.swift` / `VoiceCapsuleWindowController.swift`)**:
    - **Eradication of Redundant Root Schedule Menus for Single-Device Users**: Gated the root-level whole-house schedule menu to only appear when multiple devices exist (`allDevices.count > 1`), eliminating duplicate schedule menus in single-device mode;
    - **Full Control Parity with Single-Device Filter Reset**: Added a dedicated "🧼 重置滤网计时 (当前 X%，良好/需拆洗)" entry in single-device control areas, matching multi-device submenu capabilities;
    - **Graceful Multi-Device Voice Capsule Fallback**: Enhanced `executeMultiDeviceCommand` to handle self-cleaning (`.startSelfCleaning` / `.stopSelfCleaning`) and sleep curves (`.startSleepCurve` / `.stopSleepCurve`) with friendly single-device fallback feedback, eliminating batch execution rejection errors.
  - 🍃 **Continuous Linear Damping Dynamics for Aerodynamic Filter Wear (`AppModel.calculateFilterWearFactor`)**:
    - **Eliminated Step-Function Discontinuities**: Re-architected `calculateFilterWearFactor` to employ continuous linear interpolation aligned with the energy dynamics engine:
    - Auto-wind speed smoothly interpolates across steady-state micro-load (0.8°C) to heavy load (4.0°C) via `0.75 + progress * 0.55`;
    - High-temperature cooling condensation dynamically ramps across 0~5°C via `1.15 + progress * 0.30`, ensuring physically self-consistent filter cleanliness wear.

- 🏷 **Unified Repeat Schedule Parser Engine, Status Bar Single-Device Schedule & Countdown Full Symmetry, and Continuous Bilinear Inverter Overclock & PTC Damping Dynamics (v1.9.62)**:
  - ⏱️ **Unified Repeating Schedule Parser Engine Across NLP & Siri Shortcuts (`VoiceCommandParser.swift` / `AppModel.swift` / `AppIntents.swift` / `VoiceCommandParserTests.swift`)**:
    - **Shared Parser Extraction**: Extracted `public static func parseRepeatWeekdays(_ text: String) -> (weekdays: [Int], label: String)?` in `VoiceCommandParser`, eliminating over 60 lines of duplicate matching logic across NLP voice parsing and `AppIntents`, ensuring 100% semantic alignment;
    - **Monday-to-Sunday 7-Day Repeating Schedule**: Added full support for "周一至周日/周一到周日/星期一到星期天/礼拜一到礼拜天" (`[1, 2, 3, 4, 5, 6, 7]`), permanently resolving the defect where spoken 7-day recurring schedules fell back to single-shot tasks and were deleted after first execution;
    - **Expanded Contiguous Weekday Spans**: Added Tue-Wed (`[3, 4]`), Wed-Thu (`[4, 5]`), Thu-Fri (`[5, 6]`), Sun-Mon (`[1, 2]`), and Sat-Mon (`[1, 2, 7]`), seamlessly integrated with natural Chinese formatting in `AppModel.formatRepeatWeekdaysLabel`;
    - **Immediate Mis-Trigger Defense & Siri Phrases**: Hooked `parseRepeatWeekdays` into `hasTimingOrCountdownIntent` to safeguard against accidental immediate power-on when omitting the word "定时"; registered system shortcuts for Monday-to-Sunday schedules in `ACAppShortcuts`.
  - 🍱 **macOS Menu Bar Single-Device Schedule Matrix & Quick Countdown Symmetry (`StatusItemController.swift`)**:
    - **Single-Device & Multi-Device Parity**: Seamlessly introduced a dedicated "⏱ 快捷倒计时..." submenu in single-device mode (30m / 1h / 2h turn-off, 45m morning transition turn-off, 30m / 1h pre-cooling/pre-heating turn-on);
    - **Single-Device Schedule Lifecycle Management**: Added a dedicated "⏱ 计划调度..." submenu for single-device installations, listing all active and paused tasks with granular pause/resume/cancel controls and single-click device-level batch actions, delivering a consistent and elegant native macOS experience.
  - ⚡️ **Thermodynamic Inverter Overclock & PTC Auxiliary Heating Continuous Bilinear Dynamics (`EnergyAnalyticsEngine.swift`)**:
    - **Bilinear Smooth Transition Dynamics**: Overhauled high-heat cooling overclock compensation (`heatBoost`) and deep-freeze PTC auxiliary heat compensation (`coldBoost`) in `estimateInstantaneousPower`;
    - **Eliminated Hard Step Cliff Discontinuities**: Cooling mode smoothly scales over `indoor >= 28.0°C` and `delta >= 4.0°C` (eliminating the 100W cliff at 30°C / 5°C); heating mode smoothly scales over `indoor <= 17.0°C` and `delta >= 4.0°C` (eliminating the 120W cliff at 15°C / 5°C);
    - **Full-Mode Physical Consistency**: Symmetrically aligned `.auto` mode cooling and heating branches with these continuous transition ramps, reflecting true inverter compressor and PTC heating physics.

- 🏷 **Defensive Action Negation for Schedule Cancellation/Pause/Resume, Device-Level Menu Bar Schedule Matrix, Generalized Repeat Day Engine & Thermodynamic Auto-Wind Dynamics (v1.9.61)**:
  - 🛡️ **Schedule Action Negation Defense for Cancel, Pause & Resume (`VoiceCommandParser.swift` / `VoiceCommandParserTests.swift`)**:
    - **Thorough Defense Against Negated Schedule Modification Intentions**: The previous negation filter only blocked power-switching verbs (on/off/start). It did not guard schedule mutation phrases like "千万别取消定时", "不要取消定时任务", "别给我暂停定时", "千万不要恢复定时";
    - **Single-Device & Whole-House Scope Protection**: Introduced `containsNegativeForAction`, supporting up to 10 inserted characters between negation words and action keywords, preventing accidental cancellation or modification during casual speech or sentence revisions.
  - ⏱️ **Harmonized Repeat Schedule Engine & Compound Weekday Range Extension (`AppModel.swift` / `VoiceCommandParser.swift` / `AppIntents.swift`)**:
    - **Unified Architecture for Repeat Weekday Formatting**: Centralized formatting logic into `AppModel.formatRepeatWeekdaysLabel(_ repeatWeekdays: [Int]) -> String?`, removing hundreds of lines of duplicated code across `ScheduledAction.repeatLabel` and `BedtimeSchedule.repeatLabel`;
    - **Generalized High-Frequency Compound Weekdays**: Added Thu-Sat ("周四至周六", `[5, 6, 7]`), Fri-Sat ("周五至周六", `[6, 7]`), Tue-Sun ("周二至周日", `[1, 3, 4, 5, 6, 7]`), and Wed-Sun ("周三至周日", `[1, 4, 5, 6, 7]`), seamlessly integrated across NLP parser, scheduling UI labels, and `AppIntents`;
    - **Single-Device Schedule Control API**: Added `AppModel.setScheduledActionsEnabled(for deviceId: String, enabled: Bool) -> Int`.
  - 🍱 **macOS Menu Bar Per-Device Schedule Management Matrix (`StatusItemController.swift`)**:
    - **Dedicated Device Schedule Submenu**: Added a device-specific "⏱ 计划调度..." submenu inside each device's menu entry;
    - **Granular Per-Task Operations**: Displays all active and paused schedules for the specific device, with secondary popouts to quickly pause, resume, or cancel individual tasks;
    - **Device-Level Batch Operations**: Provides "⏸ 暂停该设备所有定时任务", "▶️ 恢复该设备所有定时任务", and "🗑️ 取消该设备所有定时任务" for swift bulk control.
  - ⚡️ **Thermodynamic Adaptive Auto-Wind Energy Dynamics Calibration (`EnergyAnalyticsEngine.swift`)**:
    - Refined the fan power offset (`windOffset`) in `estimateInstantaneousPower` when `windSpeed` is "自动" (Auto):
    - Replaced the hardcoded 40W constant with physics-based dynamic modeling: locked to low-speed 25W under dehumidify mode, steady 50W under fan mode, and continuous linear thermal damping (20W ~ 120W) based on `|indoor - target|` temperature differential in cooling/heating/auto modes.

- 🏷 **Comprehensive Schedule Batch Pause/Resume Lifecycle Across Voice & Siri, Generalized Compound Weekday Schedule Engine, and Dynamic Auto-Wind Thermodynamic Physical Consistency (v1.9.60)**:
  - ⏸️ **Schedule Lifecycle Management — Full-Stack Batch Pause / Resume Integration (`AppModel` / `VoiceCommandParser` / `VoiceCapsuleWindowController` / `AppIntents` / `StatusItemController`)**:
    - **`AppModel` Scheduling Lifecycle Expansion**: Added `setAllScheduledActionsEnabled(_ enabled: Bool) -> Int` and `setScheduledActionsEnabled(for:enabled:) -> Int`, enabling one-click batch pause or resume for whole-house or per-device schedules, returning affected action counts and instantly waking the scheduler timer;
    - **`VoiceCommand` Natural Language Full-Stack Integration**: Expanded `VoiceCommand` with `.pauseSchedules`, `.pauseSchedulesAll`, `.resumeSchedules`, and `.resumeSchedulesAll`; parser accurately understands spoken commands ("暂停定时", "暂停所有定时任务", "暂停全屋定时", "暂停倒计时", "恢复定时", "恢复全屋定时", "继续定时"), strictly protected by action negation defense ("千万别暂停定时"); voice capsule dispatches to single-device, whole-house, and multi-device targets with rich contextual feedback;
    - **Deep Siri Shortcuts & AppIntents Integration**: Added `PauseACSchedulesIntent` and `ResumeACSchedulesIntent`, registering high-frequency system phrases in `ACAppShortcuts` ("用海尔空调暂停定时", "用海尔空调暂停所有定时", "用海尔空调恢复定时", "用海尔空调恢复所有定时");
    - **macOS Status Bar Full Panoramic Awareness**: Added "⏸ 暂停全屋所有定时任务" and "▶️ 恢复全屋所有定时任务" to the schedule submenu; permanently fixed status bar tooltip and parent menu bugs where paused tasks were counted as "active", now intelligently reporting `⏱ 计划调度 (2 生效 / 1 暂停)...` or `⏱ 计划调度: 全部已暂停`.
  - ⏱️ **Natural Language Generalized Compound Weekday Schedule Engine & Immediate Mis-Trigger Defense (`VoiceCommandParser` / `VoiceCommandParserTests`)**:
    - **Exhaustive High-Frequency Compound Weekday Coverage**: Fully supports Wed-Fri ("周三至周五/周三到周五", `[4, 5, 6]`), Mon-Tue ("周一至周二/周一到周二", `[2, 3]`), Tue-Thu ("周二至周四/周二到周四", `[3, 4, 5]`), Tue-Sat (`[3, 4, 5, 6, 7]`), Wed-Sat (`[4, 5, 6, 7]`), Thu-Sun (`[1, 5, 6, 7]`), and Sat-Sun ("周六至周日/周六到周天/星期六到星期天", `[1, 7]`); harmonizes natural Chinese descriptors in `ScheduledAction.repeatLabel` and `BedtimeSchedule.repeatLabel`;
    - **Eradication of Omitted "定时" Commands Misfiring Immediate Power-On**: Introduced generalized weekday range prefix detection in `hasTimingOrCountdownIntent` (covering all combinations of "周X到/至", "星期X到/至", "礼拜X到/至"), completely eliminating the critical issue where commands like "全屋周三至周五早上8点开机" or "全屋周六到周日开机" bypassed scheduling checks and immediately powered on the whole house.
  - 🍃 **Aerodynamic Filter Health Algorithm Upgrade — Auto-Wind Operating Condition Physical Consistency Calibration (`AppModel.calculateFilterWearFactor`)**:
    - Refined physical coupling between auto wind speed and operating modes: under dehumidification mode (`.dehumidify`), since the microcomputer forces a low-velocity draft to prevent condensed moisture re-evaporation, auto wind speed locks to low-throughput `0.75` regardless of thermal delta, eliminating load overestimation; fan mode (`.fan`) lacks thermodynamic delta, so auto wind maintains steady throughput `0.85`; cooling and heating retain full adaptive thermal delta dynamics.

- 🏷 **Natural Language Extended Multi-Day Weekday Schedules, Adaptive Auto-Wind Filter Dynamics, macOS Status Bar Schedule Pause/Resume & Full-House Countdown Symmetry (v1.9.59)**:
  - ⏱️ **Natural Language "周一至周三 / 周二至周五 / 周五至周日 / 周末三天" Extended Multi-Day Weekday Repeating Schedule Closure (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `VoiceCommandParserTests`)**:
    - **Comprehensive Coverage of Compound Weekday Spans**: Full-stack support for Mon-Wed ("周一到周三/周一至周三/礼拜一到礼拜三/星期一到星期三", `[2, 3, 4]`, "周一至周三"), Tue-Fri ("周二到周五/周二至周五/礼拜二到礼拜五/星期二至星期五", `[3, 4, 5, 6]`, "周二至周五"), and Fri-Sun / Weekend 3 Days ("周五到周日/周五至周日/周末三天/礼拜五到礼拜天", `[1, 6, 7]`, "周五至周日"); thoroughly resolves spoken multi-day cycles being misparsed as single-shot tasks and destroyed upon first run;
    - **Natural Descriptor Alignment in `repeatLabel`**: Both `ScheduledAction.repeatLabel` and `BedtimeSchedule.repeatLabel` now naturally map `[2, 3, 4]`, `[3, 4, 5, 6]`, and `[1, 6, 7]` to elegant Chinese phrases instead of mechanical day concatenations;
    - **Enhanced Prefix Safeguards & Negation Defense**: Extended `hasTimingOrCountdownIntent` with compound spans to prevent spoken schedule commands like "周五到周日晚上10点开空调" from misfiring immediate power-on; negation regex reliably intercepts "千万别周五到周日开机", "不要周一至周三关空调".
  - 🍃 **Aerodynamic Filter Health Algorithm Upgrade — Adaptive Auto-Wind Dynamic Flux Calibration (`AppModel.calculateFilterWearFactor`)**:
    - Overhauled the legacy static `1.00` factor for auto wind speed in `calculateFilterWearFactor` with a physical Adaptive Auto-Wind Dynamics model based on indoor-to-target temperature differences;
    - When wind speed is set to "自动" (Auto): under high-load heavy thermal delta (`|indoor - target| >= 4.0°C`), the fan runs at maximum convection velocity, dynamically adapting `windFactor` to `1.30`; under equilibrium steady-state (`|indoor - target| <= 0.8°C`), the fan ramps down to whisper-quiet low speed, tuning `windFactor` down to `0.75`; normal transitions and missing temperature sensor conditions retain neutral `1.00`, eliminating algorithmic load underestimation and steady-state overestimation.
  - 🍱 **macOS Native Status Bar Schedule Management & Full-House Symmetry (`StatusItemController`)**:
    - **Per-Task Pause / Resume Toggle**: Added "⏸ 暂停此定时任务" / "▶️ 恢复此定时任务" in the schedule item context submenu, allowing users to temporarily disable schedules without having to delete and re-create them; paused tasks prominently display `[已暂停]` in the main menu list;
    - **Full-House Pre-Cooling/Pre-Heating Symmetry**: Added "❄️ 全屋 2 小时后开机预冷/预热" to the quick countdown submenu, achieving 100% action symmetry with existing 30m / 1h / 2h shutdown countdowns.
  - 🎙️ **Siri Shortcuts & AppIntents Repeat Schedule Alignment (`AppIntents.swift`)**:
    - `ScheduleACPowerIntent` recognizes "周一至周三", "周二至周五", "周五至周日"; registered system phrases in `ACAppShortcuts` ("用海尔空调周五至周日定时开机", "用海尔空调周一至周三定时开机").
  - 🧪 **Unit Test Suite Expansion (`VoiceCommandParserTests`)**:
    - Added comprehensive `testExtendedMultiWeekdayScheduleParsing` suite verifying single-device, whole-house, negation prevention, and immediate-power-on defense boundaries.

- 🏷 **Natural Language Libai (礼拜) Repeating Cycles & Multi-Day Weekday Combinations, Bedtime Schedule Prefix Defect Elimination, macOS Status Bar Full-House Pre-Cooling/Pre-Heating Symmetry & Siri Repeat Shortcuts (v1.9.58)**:
  - ⏱️ **Natural Language Libai (礼拜) Cycles & Multi-Day Weekday Combinations ("一三五/二四六/二四/周一至周四") Full-Stack Closure (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `VoiceCommandParserTests`)**:
    - **Eradication of Colloquial "礼拜" Repeating Schedules Falling Back to One-Time Tasks & Deleted Upon First Execution**: Permanently resolved the critical defect where spoken recurring commands with colloquial "礼拜" (e.g. "每个礼拜一早上8点开空调", "礼拜一到礼拜五早上8点开空调", "礼拜一至礼拜六早上7点开机", "礼拜六礼拜天早上9点开空调", "每个礼拜日晚上11点关空调") previously lacked keyword matching and fell back to single-shot `.schedulePower`, causing recurring schedules to be permanently deleted after firing once;
    - **Multi-Day Weekday Combinations (1-3-5 / 2-4-6 / 2-4 / Mon-Thu) Full Closure**: Accurately recognizes "每周一三五/周一三五" (`[2, 4, 6]`, "每周一、三、五"), "每周二四六/周二四六" (`[3, 5, 7]`, "每周二、四、六"), "每周二四/周二四" (`[3, 5]`, "每周二、四"), and "周一到周四/周一至周四" (`[2, 3, 4, 5]`, "周一至周四"), resolving the truncation defect where "每周一三五" was previously truncated to Monday only;
    - **Whole-House Scope & Long Compound Negation Defense Extension**: Expanded `hasTimingOrCountdownIntent` to incorporate "礼拜", "逢星期", "一三五", "二四六", "二四", preventing commands like "全屋每个礼拜一开机" from being misjudged as immediate power-on; negation regex protects against "千万别每个礼拜一开机", "别每周一三五开空调", "不要礼拜一到礼拜五开机".
  - ⏱️ **Bedtime Schedule Descriptor Double "周" Bug & Multi-Day Symmetry Alignment (`AppModel.swift`)**:
    - Harmonized `BedtimeSchedule.repeatLabel` with `ScheduledAction.repeatLabel`, permanently eliminating the awkward double "周" artifact ("每周 周一") and raw day-by-day concatenation ("每周 周一 周二 周三 周四 周五 周六"), formalizing natural Chinese descriptors: "每周一", "工作日", "周末", "周一至周六", "周一至周四", and "每周一、三、五".
  - 🍱 **macOS Native Status Bar Full-House Pre-Cooling/Pre-Heating Countdown Symmetry (`StatusItemController`)**:
    - In the top-level "⏱ 计划调度" -> "⚡️ 快捷倒计时调度..." submenu under the multi-device section, introduced "❄️ 全屋 30 分钟后开机预冷/预热" and "❄️ 全屋 1 小时后开机预冷/预热", establishing 100% action symmetry with existing full-house shutdown countdowns.
  - 🎙️ **Siri Shortcuts & AppIntents Schedule Flexibility Enhancement (`AppIntents.swift`)**:
    - `ScheduleACPowerIntent`'s `repeatSchedule` parameter now recognizes "礼拜", "周一至周四", "一三五", "二四六", "二四";
    - Registered intuitive phrases in `ACAppShortcuts` ("用海尔空调工作日定时开机", "用海尔空调周末定时开机", "用海尔空调一三五定时开机", "用海尔空调一三五定时关机").
  - 📊 **Energy Analytics Engine Device Minutes Initialization Robustness (`EnergyAnalyticsEngine.swift`)**:
    - Enhanced `EnergyDayRecord.init` to ensure `totalDeviceMinutes` is at least `max(sumModes, totalMinutes)` whenever total minutes is positive, guaranteeing data consistency under edge conditions.

- 🏷 **Natural Language Single Weekday & Extended Repeating Schedule Cycles, Scheduler Clock Drift Elimination, macOS Status Bar Per-Device Countdown Matrix & Siri Repeat Shortcuts (v1.9.57)**:
  - ⏱️ **Natural Language "每周一至周日/逢周一/周一到周六" Single Weekday & Extended Repeating Cycle Scheduling Closure (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `VoiceCommandParserTests`)**:
    - **Eradication of Single Weekday & Extended Cycle Requests Falling Back to One-Time Tasks & Deleted Upon First Execution**: Permanently fixed the critical defect where spoken recurring commands for specific weekdays (e.g. "每周一早上8点开空调", "每周五晚上10点关机", "每周日晚上11点关空调", "每个星期一早上7点开空调", "逢周一早上8点开机", "周一到周六早上7点开机") previously lacked weekday matching and fell back to single-shot `.schedulePower`, causing recurring schedules to be permanently deleted after firing once;
    - **Introduced Full Single Weekday (Mon~Sun) & Multi-Day Weekday Matrices**: Accurately recognizes "每周一" through "每周日" (`[2]`~`[7]`, `[1]`) as well as "周一到周六/周一至周六" (`[2,3,4,5,6,7]`); initial trigger timestamps (`initialFireDate`) are harmonized across single-device, whole-house, and multi-device dispatching, ensuring perpetual seamless cycle recurrence;
    - **Long Compound Negation Defense Extension**: Expanded the non-punctuation insertion span between negation and action verbs from 6 to 10 characters, robustly shielding against conversational phrases ("千万别每周一开机", "不要每个星期五开空调", "别周一到周六定时开机").
  - ⏱️ **Scheduler Clock Drift & System Sleep/Wake Timestamp Corruption Eradication (`AppModel.nextFireDate` / `AppModel.fireDueActions` / `ScheduledAction`)**:
    - **Eliminated Weekday Cycle Clock Drift & Wake Time Pollution**: Overhauled `nextFireDate` to strictly accept `originalFireDate` and preserve the exact original hour, minute, and second across future occurrences, permanently resolving the severe defect where passing `now` accumulated execution latency drifts and caused system sleep/wake events to corrupt recurring schedule fire times to the computer's wake-up moment;
    - **Fixed `repeatLabel` Redundant Prefix Bug**: Fixed awkward display strings where `[2]` became "每周周一" and `[2,3,4,5,6]` became "每周周一周二周三周四周五", formalizing natural Chinese descriptors: "每周一", "工作日", "周末", "周一至周六", and "每周一、三、五".
  - 🍱 **macOS Native Status Bar Per-Device Dedicated Countdown Matrix & Pre-Cooling/Pre-Heating Expansion (`StatusItemController`)**:
    - **Dedicated Per-Device Countdown Submenu**: Added a dedicated "⏱ 快捷倒计时..." submenu in the multi-device control matrix (`devSubmenu`) for each individual room/device (30 min / 1 hr / 2 hr off, plus 30 min / 1 hr pre-cooling/pre-heating on), resolving the restriction where users previously could only set countdowns for the primary device from the status bar;
    - **Top-Level Schedule Matrix Upgrade**: Added quick pre-cooling/pre-heating countdowns ("❄️ 快捷开机预冷/预热倒计时") and whole-house unified shutdown countdowns ("🏠 全屋统一关机倒计时"), with rich dynamic toast feedback.
  - 🎙️ **Siri Shortcuts & AppIntents Schedule Flexibility Enhancement (`AppIntents.swift`)**:
    - Added `repeatSchedule` parameter to `ScheduleACPowerIntent` (supporting "工作日", "周末", "每天", "每周一" ~ "每周日", "周一至周六"), removing the legacy constraint of daily repeats only;
    - Registered intuitive phrases in `ACAppShortcuts` ("用海尔空调工作日定时关机", "用海尔空调周末定时开机", "用海尔空调每天定时开机").
  - 🍃 **Aerodynamic Filter Wear Velocity Shearing Calibration for Fan Mode (`AppModel.calculateFilterWearFactor`)**:
    - In `calculateFilterWearFactor`, refined the `.fan` mode aerodynamics: under high/turbo wind velocities (`windFactor >= 1.35`), aerodynamic shear forces stir up and capture floating dry particulate matter at an accelerated rate, dynamically calibrating the mode factor to `0.95` (while keeping low/mid speed at `0.85`).


- 🏷 **Natural Language Repeating Cycle Scheduling (Daily/Weekdays/Weekend), Siri Shortcuts Scheduling Closure, macOS Status Bar Quick Shutdown Countdown & Auto-Mode Thermodynamic Symmetry (v1.9.56)**:
  - ⏱️ **Natural Language "每天/天天/工作日/周末/按星期" Repeating Cycle Scheduling Full-Stack Closure (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `VoiceCommandParserTests`)**:
    - **Eradication of Repeating Schedules Being Handled as One-Time Tasks & Deleted Upon First Execution**: Permanently resolved the critical defect where spoken recurring schedules (e.g. "每天晚上10点关机", "天天早上8点开空调", "工作日早上7点开机", "周末上午9点开空调", "周一到周五早上7点开机", "周六周日晚上11点关空调") were previously parsed only as single-shot `.schedulePower`, with `repeatsDaily` and `repeatWeekdays` hardcoded to `false` and `[]`, causing recurring requests to be permanently deleted after firing once;
    - **Introduced `scheduleRepeatPower` Command & Weekday Matrix**: Accurately recognizes "每天/天天/每日/每晚/每早" (`repeatsDaily = true`), "工作日/平时/周一到周五" (`repeatWeekdays = [2,3,4,5,6]`), and "周末/双休/周六周日" (`repeatWeekdays = [1,7]`); calculates initial trigger times via `AppModel.initialFireDate` across single-device, whole-house, and multi-device dispatching, ensuring perpetual seamless cycle recurrence;
    - **Deep-Night "每晚" Normalization & Negation Guard**: Corrected "每晚11点" time detection into 23:00 PM (preventing it from defaulting to 11:00 AM), with strict negation interceptors against accidental trigger phrases ("千万别每天定时开机", "不要工作日定时关机").
  - 🎙️ **Siri Shortcuts & AppIntents Schedule Automation Closure (`AppIntents.swift`)**:
    - Added `ScheduleACPowerIntent` supporting both countdown duration (e.g. 30, 60 minutes) and specific clock times (e.g. 22:00) with daily repeat option (`repeatsDaily: Bool`), targeted by device name or applied whole-house;
    - Registered intuitive phrases in `ACAppShortcuts` ("用海尔空调定时关机", "用海尔空调倒计时关机", "用海尔空调每天定时关机", "海尔空调定时关机"), closing the gap where Siri previously could only cancel schedules but not create them.
  - 🍱 **macOS Native Status Bar Quick Shutdown Countdown & Schedule Experience Upgrade (`StatusItemController`)**:
    - **Dedicated "⚡️ 快捷关机倒计时" Submenu**: Added quick presets ("⏱ 30 分钟后关机", "⏱ 1 小时后关机", "⏱ 2 小时后关机", "⏱ 晨间过渡关机 (45分钟)") accessible directly under "⏱ 计划调度" in both active and idle states, offering 1-click scheduling without opening the window;
    - **Deduplication & Recurring Cycle Visualization**: Eliminated duplicate device name prefixes in scheduled task items (`⏱ 客厅: 「客厅」22:00 关机`), and injected cycle tags (`[每天]`, `[工作日]`, `[周末]`) along with next execution timestamps in details submenus.
  - 🍃 **Auto Mode (.auto) Sensor-Free Thermodynamic Symmetry Alignment (`AppModel.calculateFilterWearFactor`)**:
    - In `calculateFilterWearFactor`, resolved the issue where auto mode defaulted to `1.00` steady-state whenever `indoorTemp == nil`;
    - Intelligently balances cooling vs. heating bias based on `targetTemp`: applies `1.20` for summer cooling bias ($T \le 25^\circ\text{C}$) and `1.10` for winter heating bias ($T > 25^\circ\text{C}$), achieving 100% thermodynamic symmetry with `EnergyAnalyticsEngine`.

- 🏷 **Cross-Day Clock Schedule Power On/Off & Deep-Night Normalization, Siri Shortcuts Schedule Management, macOS Status Bar Granular Task Control & Filter Dynamics (v1.9.55)**:
  - ⏱️ **Natural Language "明天/明早/明晚/次日/后天" Cross-Day Absolute Clock Scheduling & Deep-Night Normalization (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `VoiceCommandParserTests`)**:
    - **Eradication of Accidental Same-Day Scheduling for Spoken Cross-Day Clock Times**: Permanently fixed the critical bug where daytime commands like "明天晚上10点关机" or "明晚10点关机" previously evaluated target hour 22:00 as greater than the current hour, causing the legacy check `targetDate <= Date()` to evaluate to false and mistakenly schedule the action for *tonight* instead of *tomorrow night*; fully introduced explicit cross-day date calculations across single-device, whole-house, and multi-device dispatching;
    - **Deep-Night 9~11 PM Period Normalization & Early Morning Preservation**: Fixed colloquial "半夜9/10/11点" and "午夜11点" misclassification into morning hours by properly normalizing them to 21:00 ~ 23:00 PM while cleanly preserving early-morning "半夜1点/2点" at 01:00/02:00 AM;
    - **Symmetric 60-Minute Default Duration for Power-On Scheduling & Negation Guard**: Extended the default 60-minute duration fallback from power-off to power-on commands ("定时开机", "倒计时开机", "预约开机"), achieving complete semantic symmetry; added strict negation guards against scheduling requests ("千万别定时开机", "不要定时关机").
  - 🎙️ **Siri Shortcuts & AppIntents Schedule Management Integration (`AppIntents.swift`)**:
    - Introduced `CancelACSchedulesIntent` ("取消空调定时"), supporting targeted cancellation by device name or clearing all active scheduled actions across the home;
    - Registered intuitive phrases in `ACAppShortcuts` ("用海尔空调取消定时", "用海尔空调取消所有定时", "取消全屋定时海尔空调"), integrating seamlessly with macOS Shortcuts automation.
  - 🍱 **macOS Native Status Bar Granular Schedule Management & Complete Wind Speed Alignment (`StatusItemController`)**:
    - Upgraded each scheduled action in the status bar "⏱ 计划调度" section into an interactive submenu displaying device name, exact execution time, and an individual "❌ 取消该定时任务" action alongside "🗑 取消全屋所有定时与倒计时";
    - Aligned `formatDisplayWindSpeed` with "极速/高速/中速/低速" aliases, achieving 100% enum consistency across filter aerodynamics and the energy analytics engine.
  - 🍃 **Aerodynamic Filter Wear Sensor-Free Mode Normalization (`AppModel.calculateFilterWearFactor`)**:
    - Explicitly distinguished between steady-state maintenance mode and missing indoor temperature sensor conditions: when `indoorTemp == nil`, defaults to standard cooling load `1.30` and heating load `1.15`, eliminating systematic filter load underestimation caused by falling into lowest maintenance baselines.

- 🏷 **Natural Language "Up/Down" Relative Stepping Closure, Scorching Summer Cooling Filter Aerodynamics & Status Bar Schedule Perception (v1.9.54)**:
  - ⏱️ **Natural Language "上调/下调/往上/往下/向上/向下" Relative Temperature Stepping Closure (`VoiceCommandParser` / `VoiceCommandParserTests` / `AppIntents`)**:
    - **Thoroughly Closed High-Frequency Colloquial Stepping Gap**: Permanently resolved the critical bug where common daily voice commands such as "上调一度", "上调1度", "上调两度", "上调2度", "上调半度", "上调0.5度", "上调零点五度", "往上调1度", "往上调半度", "向上调一度", "向上调0.5度", "温度上调1度", "下调一度", "下调1度", "下调两度", "下调2度", "下调半度", "下调0.5度", "下调零点五度", "往下调1度", "往下调半度", "向下调一度", "向下调0.5度", and "温度下调1度" were previously dropped because directional keywords only matched "升/高/降/低", omitting "上调/下调/往上/往下/向上/向下";
    - **Whole-House Multi-Device Coordination**: Full support for whole-house relative stepping phrases ("全屋上调一度", "全屋上调半度", "全屋下调一度", "全屋下调半度");
    - **Siri Shortcuts Integration**: Added "用海尔空调上调温度" and "用海尔空调下调温度" to `ACAppShortcuts`, expanding Siri voice control capabilities;
    - **Structured Negation Defense**: Extended negation action guard to strictly disallow accidental triggers ("不要上调", "别下调", "千万别往上调").
  - 🍃 **Scorching Summer Cooling Aerodynamic Filter Wear & Thermodynamic Symmetry (`AppModel.calculateFilterWearFactor`)**:
    - Grounded in fluid mechanics and coil condensation physics: under severe summer cooling loads ($T \ge 30.0^\circ\text{C}$ or $\Delta T \ge 5.0^\circ\text{C}$), evaporator condensation and cross-flow fan throughput reach maximum design capacity, accelerating particulate entrapment;
    - Dynamically increased the heavy cooling wear factor to 1.45 (achieving thermal symmetry with high-humidity dehumidification), setting moderate cooling to 1.30 and steady-state maintenance to 1.15; aligned auto mode cooling to 1.35 factor, achieving 100% thermodynamic symmetry with inverter energy simulations.
  - 🍱 **macOS Native Status Bar Full Schedule Perception & Transparent Temperature Benchmarks (`StatusItemController`)**:
    - **Active Schedule Perception & One-Click Cancellation**: Added reactive `model.$scheduledActions` state awareness; hover tooltip displays active timers, and right-click context menu features a dedicated "⏱ 计划调度" section listing each scheduled task's target device and fire date, accompanied by a "🗑 取消全屋所有定时与倒计时" quick action;
    - **Transparent Whole-House Stepping Benchmarks**: Enriched whole-house 1°C and 0.5°C step items with current target temperature benchmarks ("均设 26°C" for uniform settings, "当前 24~26°C" for dispersed settings), providing crystal-clear state transparency.

- 🏷 **Chinese Compound Number Decimal Parsing & Clock Schedule Conflict Closure, Siri Shortcuts High-Precision Relative Stepping, High-Humidity Dehumidification Condensate Filter Dynamics & Status Bar 0.5°C Matrix Synchronization (v1.9.53)**:
  - ⏱️ **Natural Language Chinese Compound Number Decimal Parsing & Erroneous Clock Schedule Guard (`VoiceCommandParser` / `VoiceCommandParserTests`)**:
    - **Eradication of Accidental Midnight/Evening Scheduling for Chinese Compound Decimals**: Completely resolved the critical bug where high-frequency spoken commands like "开到二十点五", "开二十点五", "打开二十点五", "全屋开到二十点五", "全屋开二十点五", "空调开到二十点五", "制冷开到二十点五", "开到十八点五", "开到十九点五", "开到二十一点五", "开到二十二点五", and "开到二十三点五" previously suffered from inverted execution order where `compoundPattern` ran after `decimalPointPattern`, outputting broken intermediate tokens like "20点5" and "18点5"; `parseScheduleTime` subsequently matched 20 and 18 as valid clock hours and erroneously queued power-on schedules at 20:05 and 18:05 PM;
    - **Structured 1~99 Compound Number & Decimal Pattern Sequencing**: Re-architected `convertChineseNumbers` to first normalize 1~99 compound Chinese numbers into standard Arabic digits before executing `decimalPointPattern`, guaranteeing that "开到二十点五", "二十点五度", and "全屋开到二十点五" cleanly normalize to 20.5°C;
    - **Clock Schedule Semantic Exclusion Safeguard**: Introduced semantic action and range exclusion in `parseScheduleTime`, strictly disallowing bare numbers within the core AC temperature envelope (16~23°C) that lack "分/分钟" suffixes from being parsed as clock times.
  - 🎙️ **Siri Shortcuts & AppIntents Relative Stepping Ecosystem Integration (`AppIntents.swift`)**:
    - Introduced `AdjustACTemperatureIntent` for fine relative temperature adjustments, supporting custom `delta` values (e.g. +1°C, +0.5°C, -0.5°C, -2°C) with seamless single-device and whole-house dispatching;
    - Registered intuitive spoken phrases in `ACAppShortcuts` ("用海尔空调微调温度", "用海尔空调升高温度/降低温度", "用海尔空调升温/降温", "海尔空调 调高温度/调低温度"), achieving end-to-end Siri Shortcuts compatibility.
  - 🍃 **High-Humidity Dehumidification Water Film Aerodynamic Filter Dynamics (`AppModel.calculateFilterWearFactor`)**:
    - Grounded in fluid mechanics and psychrometric condensation: under high relative humidity (RH >= 75% rainy/muggy seasons), thick condensation water films on the evaporator and filter mesh accelerate particulate entrapment and mud clumping; dynamically increased the dehumidification wear factor from 1.30 to 1.45 (1.20 for low-humidity steady state), achieving 100% physical symmetry with inverter energy simulations.
  - 🍱 **macOS Native Status Bar 0.5°C Stepping Matrix Symmetry & Real-Time Temperature Feedback (`StatusItemController`)**:
    - Added running device count descriptors `(N台运行中)` / `(当前均未开机)` to whole-house 0.5°C micro-stepping items, ensuring strict visual and state symmetry with 1°C step items;
    - Enhanced single-device and device submenu 0.5°C micro-stepping items with real-time base temperature indicators (e.g. `🔼 升温 0.5°C (高精微调 · 当前 26.0°C)`), maximizing menu clarity and state transparency.

- 🏷 **Colloquial "0.5°C" Fine Stepping & Decimal Power-On Guard, High-Delta Heating Thermophoresis Filter Dynamics & Status Bar 0.5°C Stepping Matrix (v1.9.52)**:
  - ⏱️ **Natural Language Decimal Degree Normalization & Erroneous Clock Schedule Guard (`VoiceCommandParser` / `VoiceCommandParserTests`)**:
    - **Eradication of Accidental Midnight 00:05 Scheduling for Spoken Decimals**: Completely resolved the critical bug where spoken commands without the explicit "度" word (e.g. "开到26点5", "开26点5", "打开26点5", "全屋开到26点5", "全屋开26点5", "空调开到26点5", "制冷开到26点5") previously escaped decimal parsing, leading `parseScheduleOrCountdown` to erroneously treat "点5" as a clock schedule at 00:05 AM and queue `schedulePower(hour: 0, minute: 5, power: true)`; optimized `decimalPointPattern` with negative lookahead `(?![分分钟])` to accurately set 26.5°C target temperature;
    - **Lossless Spoken "零点五度 / 0点5度" Micro-Stepping**: Fixed regex character class omission of Chinese "零" and missing dot replacement in `extractNumber` that previously caused "升温零点五度", "降温零点五度", "全屋升温零点五度", and "全屋降温0点5度" to degrade to 1.0°C; now flawlessly executes $\pm 0.5^\circ\text{C}$ micro-adjustments;
    - **Strict Clock Schedule Validity Boundaries**: Enforced strict `h <= 23` and `m < 60` constraints in `parseScheduleTime`, preventing AC temperature values (24~30) from ever being misinterpreted as clock hours.
  - 🍃 **High-Delta Heating Thermophoresis & Aerodynamic Filter Dynamics (`AppModel.calculateFilterWearFactor`)**:
    - Formulated a thermodynamic filter wear model incorporating thermophoresis and convective particulate deposition: under heavy heating loads ($\Delta T \ge 5.0^\circ\text{C}$) or severe cold ($\le 12^\circ\text{C}$), increased the wear factor from static 1.05 to 1.25 (1.20 in auto mode heating), achieving 100% physical symmetry with inverter energy simulations.
  - 🍱 **macOS Native Status Bar 0.5°C Dual-Mode Stepping Matrix & Hardware Limit Guards (`StatusItemController`)**:
    - Added high-precision 「🔼 升温 0.5°C (高精微调)」 and 「🔽 降温 0.5°C (高精微调)」 items across single-device menus, multi-device submenus (`devSubmenu`), and whole-house synchronized controls;
    - Guarded with strict 16.5°C ~ 29.5°C hardware boundary enablement checks (`isEnabled`), preventing redundant network writes at extreme operational limits.

- 🏷 **Colloquial "X-Point-5" Degree Parsing, Stopping Power-Off Semantics, Airflow Dynamics Alignment & Status Bar Matrix Climate Perception (v1.9.51)**:
  - ⏱️ **Natural Language "X度五 / X度5" Temperature & Relative Stepping Precision (`VoiceCommandParser` / `VoiceCommandParserTests`)**:
    - **"X度五 / X度5" Absolute Temperature Extraction**: Thoroughly resolved the precision truncation flaw where high-frequency spoken commands like "二十六度五", "26度5", "开到25度5", "制冷二十六度五", "制冷26度5", "全屋二十六度五", and "全屋开到26度5" previously missed decimal conversion because the regex only checked "度半", resulting in severe 0.5°C truncation to integer values (26°C / 25°C); introduced `([一二两三四五六七八九\d]+)度(?:半|五|5)` to losslessly normalize spoken values to target decimal temperatures (26.5°C, 25.5°C);
    - **Spoken "一度五 / 1度5" Relative Stepping Micro-Tuning**: Resolved the issue where relative adjustments like "调高一度五", "升温1度5", "降温一度五", "调低1度5", "全屋升温一度五", and "全屋降温1度5" defaulted to 1.0°C; now accurately extracts and applies $\pm 1.5^\circ\text{C}$ adjustments;
    - **Stopping Verbal Shutdown Intent & Negative Safeguard**: Expanded power shutdown keyword matching to cover natural stop phrases ("把空调停了", "停止运行", "停止运转", "停止工作", "停掉空调", "全屋空调停止运行", "所有空调停止运行", "所有空调都停了"), routing correctly to `.setPower(false)` / `.turnOffAll` while preserving robust structured negation protection ("千万别把空调停了", "不要停止运行");
    - **Status & Humidity Query Expansion**: Full native recognition for colloquial climate queries ("查询状态", "空调开着吗", "空调开了吗", "空调关了吗", "空调开着没", "空调关了没", "室内湿度多少", "查询湿度"), dispatching to `.queryStatus` / `.queryStatusAll`.
  - 🍃 **Aerodynamic Airflow Gear Expansion & Humidity Dual-Control Convergence (`EnergyAnalyticsEngine` / `AppModel` / `VoiceCapsuleWindowController`)**:
    - Expanded airflow alias mappings in `EnergyAnalyticsEngine.estimateInstantaneousPower` and `AppModel.calculateFilterWearFactor` to include "极速", "高速", "低速", and "中速", ensuring 100% strict physical symmetry between aerodynamic filter loading and electric thermodynamic power;
    - Added the unified `currentIndoorHumidity(for:)` property accessor on `AppModel`, standardizing scattered humidity reading points;
    - Linked humidity dual-control feedback in voice queries (`queryStatus` / `queryStatusAll`), providing device-level relative humidity and whole-home average humidity reporting.
  - 🍱 **macOS Native Status Bar Multi-Device Matrix Perception Symmetry & Climate Presentation (`StatusItemController`)**:
    - Added an informational condition header at the top of each device submenu (`devSubmenu`) in the multi-device control matrix (e.g. `🟢 客厅空调: ❄️ 制冷 26°C [强劲风] (室内 28°C · 55% RH)`), achieving perfect visual symmetry with the single-device context menu;
    - Enriched single-device condition headers and status bar hover tooltips with indoor relative humidity (`(室内 26°C · 58% RH)`), providing denser, higher-fidelity ambient climate perception.

- 🏷 **Natural Language Delay Countdown Semantics & Instant Power-Off Guard, Colloquial Comfort Temp Stepping, Aerodynamic Airflow Symmetry & Status Bar Condition Perception (v1.9.50)**:
  - ⏱️ **Natural Language Delay Countdown Semantics Closure & Immediate Shutdown Guard (`VoiceCommandParser` / `VoiceCommandParserTests`)**:
    - **Prefix Delays and Direct Duration Countdown Alignment**: Permanently fixed the critical misoperation flaw where high-frequency spoken commands like "过半小时关机", "30分钟关机", "延迟半小时关机", "等一个小时关机", "全屋过半小时关机", "全屋30分钟关机", and "稍后30分钟开机" lacked the "后" or "定时" keywords, escaped countdown parsing, and were intercepted by immediate power toggles (`isPowerOff` / `isAllPowerOff`), immediately shutting down active air conditioners;
    - **Delay Intent Guard**: Introduced `hasTimingOrCountdownIntent` to safeguard delay time expressions across all power actions and extended `parseScheduleOrCountdown` to support prefix delays (`过`, `等`, `延迟`, `延后`, `稍后`) and direct durations;
    - **Clock Scheduling vs. Countdown Hierarchy Optimization**: Prioritizes clock schedule evaluations, guaranteeing inverse differential clock timings ("差半小时八点关机", "十点差五分关机") and countdowns operate with zero mutual interference;
    - **Decimal Dot-5 Normalization & Wind/Negation Protection**: Added support for Arabic numerals with dot-5 (e.g. "1点5小时后关机" cleanly parses to 90 minutes), guarded immediate power toggles against wind level expressions ("开到最大", "开三档风"), expanded negative action patterns to cover ventilation and dehumidification, and allowed colloquial shutdown intent "别吹了".
  - 🌡️ **Colloquial Thermal Sensation & Relative Stepping Expansion (`VoiceCommandParser` / `VoiceCommandParserTests`)**:
    - Broadened relative stepping vocabulary to accommodate natural comfort expressions: "暖和点", "暖一点", "更热一点", "热点", "凉快一点", "凉快点", "更冷一点", "太冻了", "冻死了", "热死了";
    - Seamless whole-house relative stepping linkage ("全屋暖和点" -> all units +1°C, "全屋凉快一点" -> all units -1°C).
  - 🍃 **Aerodynamic Airflow Power Consumption & Filter Wear Symmetry (`EnergyAnalyticsEngine` / `AppModel`)**:
    - Unified wind level evaluations in `EnergyAnalyticsEngine.estimateInstantaneousPower` and `AppModel.calculateFilterWearFactor` across English enumerations (`turbo`, `high`, `medium`, `mid`, `low`, `micro`, `quiet`, `mute`), gear digits (`1~3档`, `一/二/三档`), and colloquial descriptions (`超强`, `强劲`, `大风`, `小风`, `最大`, `最小`);
    - Eradicated the regression where English gear tokens or numeric levels fell back to 40W baseline in `EnergyAnalyticsEngine`, restoring physical symmetry between thermodynamic power consumption and aerodynamic filter loading.
  - 🍱 **macOS Native Status Bar Single-Device Real-Time Condition Header & Tooltip Refinement (`StatusItemController`)**:
    - For single-device setups, introduced an informative condition header item at the top of the right-click menu (e.g. `🟢 客厅空调: ❄️ 制冷 26°C [强劲风] (室内 28°C)` or `⚪️ 客厅空调: 待机 (室内 28°C)`), providing instant visibility into operational states without opening panels;
    - Enhanced status bar hover tooltips: integer temperatures omit superfluous `.0` decimals (`26°C`), and current fan speed labels (`[高风]`, `[中风]`, `[微风]`, `[自动风]`) are clearly indicated.

- 🏷 **Natural Language Half-Degree Temperature Tuning, Differential Time "Minute" Reverse Parsing, Turbo Airflow Filter Dynamics & Status Bar Matrix Real-Time Perception (v1.9.49)**:
  - ⏱️ **Natural Language "Half-Degree" Temperature High-Precision Tuning & Differential "Minute" Inverse Scheduling (`VoiceCommandParser` / `VoiceCommandParserTests`)**:
    - **"X度半" Absolute Temperature Extraction**: Permanently fixed the precision loss where high-frequency colloquial phrases ("二十六度半", "26度半", "开到25度半", "制冷二十六度半", "全屋二十六度半") dropped the "半" suffix and downgraded to integer values (e.g., 26°C); introduced `([一二两三四五六七八九\d]+)度半` pattern mapping accurately to decimal values (26.5°C, 25.5°C);
    - **"半度" and Compound "一度半/两度半" Relative Step Adjustment**: Thoroughly fixed relative temperature commands ("升温半度", "调高半度", "降半度", "调低半度", "降低半度", "升高半度", "全屋升高半度", "全屋降半度") which previously failed number extraction and defaulted to 1.0°C; standardized "半度" to "0.5度", allowing `extractNumber` and `validDelta` to accurately apply 0.5°C micro-stepping; also supports composite adjustments like "调高一度半" (+1.5°C) and "降温两度半" (-2.5°C);
    - **Differential / Inverse Scheduling Minute Regex Expansion**: In `parseScheduleTime`, updated inverse differential patterns `diffPattern1` and `diffPattern2` to match `(?:分钟|分)?`, eradicating failures for phrases containing "分钟" (e.g., "差五分钟十点关机", "10点差5分钟关机", "差5分钟10点关机", "差一刻钟十点关机", "十点差一刻钟关机", "差三刻钟十点关机", "差半小时八点关机", "八点差半小时关机").
  - 🍃 **Airflow Filter Wear Factor Turbo / High Speed Alignment (`AppModel`)**:
    - Fixed `AppModel.calculateFilterWearFactor` where `windFactor` only checked `"强力" / "turbo" / "超强"`, missing the primary Haier AC gears `"强劲"` and `"强"`;
    - Accurately assigns a 1.70 wear factor (up from the incorrect 1.00 baseline) when operating in Turbo / Strong airflow mode, matching `EnergyAnalyticsEngine`.
  - 🍱 **macOS Native Status Bar Device Matrix Real-Time State Perception (`StatusItemController`)**:
    - The right-click status bar context menu entries in "空调设备控制矩阵" now dynamically display active operating modes and target temperatures: e.g., `(🟢 制冷 26°C)`, `(🟢 制热 20°C)`, `(🟢 除湿 24°C)`, `(🟢 自动 24°C)`, `(🟢 送风)` instead of a generic `(🟢 开机)`;
    - Delivers full visibility into whole-home climate states directly from the status bar menu.
- 🏷 **Natural Language Midnight/Noon Clock Calibration, Differential Minute/Quarter Parsing, Auto Mode Latent Heat Dynamics & Status Bar Device Matrix Perception (v1.9.48)**:
  - ⏱️ **Natural Language Midnight & Noon Clock Calibration, Missing Minutes & Differential "差分/差刻" Time Parsing Defect Eradication (`VoiceCommandParser` / `VoiceCommandParserTests`)**:
    - Permanently eradicated the severe time-drift flaw for colloquial midnight hours ("晚上12点", "今晚12点", "半夜12点", "午夜12点", "凌晨12点", "今晚零点", "晚上0点"): previously, `isPM` incorrectly added 12 hours, misclassifying midnight as midday 12:00; now strictly normalized to `00:00`;
    - Standardized morning vs. noon boundaries, fixing "中午11点" being miscalculated as 23:00;
    - Fixed the missing-minute defect where connector "过" (e.g., "十点过五分", "十点过十分", "十点过一刻", "十点过半", "十点过三刻") blocked minute regex matching and caused accidental truncation to the whole hour (e.g. 10:00);
    - Comprehensive support for inverse differential time expressions: "十点差五分" / "差五分十点" (precisely calculated as 09:55) and "十点差一刻" / "差一刻十点" (precisely calculated as 09:45);
    - Completely blocked clock scheduling phrases like "定时在十点五分关机" from being hijacked by countdown regex (`定时` + `分`) into a 5-minute countdown.
  - ❄️ **Auto Mode Cooling Branch Full-Climate Latent Heat Dynamics Symmetry (`EnergyAnalyticsEngine`)**:
    - In `EnergyAnalyticsEngine.estimateInstantaneousPower` (`.auto` cooling branch `indoor >= target`), integrated evaporator latent heat of condensation compensation: high-humidity heavy load ($\text{RH} \ge 65\%$, up to +66W boost) and dry low-humidity reduction (down to -20W), with steady-state dampening ($0.4\times$) and unified 1800W ceiling;
    - Delivers 100% strict thermodynamic physical symmetry between intelligent auto cooling and standalone `.cooling` modes.
  - 🍱 **macOS Native Status Bar Device Matrix Real-Time Perception (`StatusItemController`)**:
    - The right-click status bar context menu entry "空调设备控制矩阵" now dynamically displays active online and running unit counts (e.g. `空调设备控制矩阵 (3台在线，2台运行中)...`);
    - Users can instantly perceive overall network and operational states at a single glance without opening submenus.
- 🏷 **Natural Language Half-Past Time Downgrade Protection, Full Wind Speed & Gear Mapping, Auto Mode Heating Humidity Dynamics & Status Bar Visual Perception (v1.9.47)**:
  - ⏱️ **Natural Language Clock Time "点五" Protection Against Accidental Countdown Downgrades (`VoiceCommandParser` / `VoiceCommandParserTests`)**:
    - Permanently eradicated the critical parsing defect caused by global unconditional replacement `str.replacingOccurrences(of: "点五", with: ".5")` in `convertChineseNumbers`: previously, everyday clock scheduling phrases like "十点五分关机/开机" (turn off/on at 10:05), "晚上8点5分关机", and "十点五十分关机" were corrupted into "10.5分关机" or "10.5十分关机", stripping the clock indicator "点" and causing `parseScheduleTime` to return `nil`, which was then seized by `parseCountdownMinutes` and misclassified as a 5-minute countdown (`.countdownPower(minutes: 5)`);
    - Replaced with strict contextual regex matching (`([一二两三四五六七八九\d]+)点五(?=度|°|个?小时|个钟头)`), ensuring decimal conversion occurs exclusively before temperature or hour units, completely preserving minutes in clock times;
    - Added comprehensive regression tests for "十点五分关机/开机", "十点零五分", "10点5分", "十点五十分", and "全屋晚上8点5分关空调".
  - 🍃 **Natural Language Wind Speed Colloquial Blind Spots & Gear Mapping Loop (`VoiceCommandParser` / `AppModel` / `VoiceCommandParserTests`)**:
    - Completely resolved the recognition failure for colloquial verb-separated wind speed phrases ("把风开大/风调大点/风开大点/把风开小/风调小点/风开小点/调大风速/调小风速/风大点/风小点");
    - Added full mapping for numerical and ordinal gears (1~4档, 一至四档, 低中高档, 极速风, 慢速, 柔风, 静音) mapping accurately to Quiet (微风), Medium (中风), Turbo (强劲), and Auto (自动);
    - Integrated multi-level normalization engine in `AppModel.setWindSpeed` to eliminate the regression where gear aliases fell back to "0" (Auto), ensuring 100% accurate dispatch across Voice, Siri Shortcuts, and Status Bar.
  - ❄️ **Auto Mode Heating Branch Full-Climate Environmental Humidity Thermodynamics Alignment (`EnergyAnalyticsEngine`)**:
    - In `EnergyAnalyticsEngine.estimateInstantaneousPower` (`.auto` heating branch `indoor < target`), aligned environmental humidity compensation with the standalone `.heating` mode: high-humidity frost/defrost cycles ($\text{RH} \ge 65\%$, up to +75W) and dry enthalpy compensation ($\text{RH} \le 40\%$, up to +30W), plus steady-state dampening;
    - Achieves 100% strict thermodynamic physical symmetry between intelligent auto mode and standalone heating/cooling modes.
  - 🍱 **macOS Native Status Bar Whole-House Wind Speed Visual Perception & Running Count Alignment (`StatusItemController`)**:
    - The right-click "🍃 全屋风速协同" submenu title now dynamically reflects active running units (e.g. `(2台运行中)` or `(当前均未开机)`);
    - Added synchronized consistency checkmark (`✓`): when all active running units share the same wind speed, a checkmark is displayed next to that speed, making whole-house ventilation status immediately transparent.
- 🏷 **Natural Language Colloquial Hours & Two-Quarter Alignment, All-Season Heating Humidity Dynamics, Status Bar Wind Speed Matrix & Siri Wind Speed Intent (v1.9.46)**:
  - ⏱️ **Natural Language Colloquial Hours ("X个小时/半个小时") & Two-Quarter Clock Defect Eradication (`VoiceCommandParser` / `VoiceCommandParserTests`)**:
    - Completely eliminated the widespread failure for colloquial hour countdowns containing classifier "个": restructured `hourPattern` to `(?:个?小时|个钟头)`, fixing recognition failure for "一个小时后关机", "两个小时后关机", "2个小时后关机", and "三个小时后关机"; added mapping for "半个小时后开机/关机" (30 min);
    - Resolved the severe time drift where "十点两刻关机", "十点二刻关机", and "十点2刻关机" were miscalculated as `10:02` (error of 28 minutes), precisely mapping them to 10:30;
    - Added "二刻钟" -> 30 min, and colloquial quarter-hour countdowns without "钟" ("一刻后" -> 15 min, "两刻后/二刻后" -> 30 min, "三刻后" -> 45 min);
    - Expanded whole-house quick power commands to seamlessly handle "全关/全部关/全都关" and "全开/全部开/全都开".
  - ❄️ **Heating Mode Environmental Humidity Thermodynamics & Filter Lifetime Dimension Alignment (`EnergyAnalyticsEngine` / `AppModel`)**:
    - Integrated environmental humidity compensation into `EnergyAnalyticsEngine.estimateInstantaneousPower` (`.heating`): high-humidity winter environments ($\text{RH} \ge 65\%$) account for outdoor coil frosting and high-pressure defrosting cycles (+75W peak boost), while dry environments ($\text{RH} \le 40\%$) compensate for thermal convection enthalpy (+30W peak boost), achieving 100% thermodynamic symmetry with cooling and auto modes;
    - Enhanced `AppModel.estimatedFilterRemainingDays` to prefer true accumulated machine runtime `totalDeviceMinutes` across all units rather than wall-clock duration, eliminating multi-device workload distortion.
  - 🍃 **macOS Native Menu Bar Full-House & Per-Device Wind Speed Control Matrix (`StatusItemController`)**:
    - Added a cascading "🍃 全屋风速协同" submenu to status bar right-click context menu, supporting synchronized Quiet (微风), Medium (中风), Turbo (强劲), and Auto (自动) speed control;
    - Added a "🍃 调节风速 (当前: XX)" submenu in each room's cascading menu within the AC control matrix; single-device mode also features the quick wind speed submenu.
  - 🎙️ **Siri / Shortcuts Wind Speed Intent (`AppIntents`)**:
    - Implemented `SetACWindSpeedIntent`, supporting Siri voice commands and Shortcuts workflows to set AC wind speeds ("用海尔空调设置风速为微风", "全屋调节风速为强劲"), finalizing system automation across all four foundational AC control axes.
- 🏷 **Filter Maintenance Reset & Full-House Batch Reset, Status Bar Quick Reset Matrix & Cooling Mode Latent Heat Dynamics (v1.9.45)**:
  - 🧼 **Filter Maintenance Reset Voice & Siri Shortcuts End-to-End Loop (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `AppIntents` / `AppModel` / `VoiceCommandParserTests`)**:
    - Completely resolved the major cognitive defect where users saying "滤网已清洗" (filter cleaned), "滤网洗好了", "洗完滤网了", "重置滤网" (reset filter), "复位滤网", or "滤网换好了" after washing/replacing filters were erroneously intercepted by query logic due to the word "洗", prompting the app to state "filter cleanliness is low, cleaning recommended";
    - Introduced `VoiceCommand.resetFilterMaintenance` (single/targeted) and `VoiceCommand.resetFilterMaintenanceAll` (whole-house) commands, matching reset intent ahead of queries while reinforcing negation defense (e.g. "别重置滤网" is safely blocked);
    - Implemented `resetAllFilterMaintenance()` in `AppModel` to zero out wear counters and restore cleanliness to 100% across all unified AC units;
    - Added `ResetFilterMaintenanceIntent` in macOS Shortcuts, supporting Siri voice execution ("用海尔空调重置滤网", "滤网已清洗").
  - 🍱 **macOS Native Menu Bar & Filter Care Sheet Batch Reset Matrix (`StatusItemController` / `FilterCareSheet`)**:
    - Added "🧼 重置滤网计时 (当前 XX%，良好/需拆洗)" directly inside each device's submenu in the AC control matrix;
    - Upgraded the status bar right-click "滤网保养与自清洁" item into a cascade submenu with "打开滤网保养与自清洁面板..." and "🧼 一键重置全屋滤网计时 (恢复100%)";
    - Enhanced `FilterCareSheet` with a "全屋重置" button and confirmation dialog for multi-device environments, allowing one-click resets for all AC units.
  - 💧 **Cooling Mode Ambient Latent Heat Condensation Dynamics & Auto Mode Adaptation (`EnergyAnalyticsEngine` / `AppModel`)**:
    - In `EnergyAnalyticsEngine.estimateInstantaneousPower` (`.cooling`), added ambient latent heat compensation ($2260\text{ kJ/kg}$ vaporization latent heat): high-humidity environments ($\text{RH} \ge 65\%$) dynamically boost load by up to +66W to account for condensation heat, while dry environments reduce load by up to -20W;
    - In `AppModel.calculateFilterWearFactor`, refined `.auto` mode to dynamically apply condensation wear (1.25x) during cooling and micro-adhesion (1.05x) during heating based on temperature delta, eliminating static 1.00x oversimplification.
- 🏷 **Natural Language Quarter/Hour Time Conversion, Filter Health Voice & Shortcuts Loop, Self-Cleaning Stop Symmetry & Dehumidification Thermal Dynamics (v1.9.44)**:
  - ⏱️ **Quarter-Hour & Colloquial Hour Time Conversion & Precise Clock Quarter Alignment (`VoiceCommandParser` / `VoiceCommandParserTests`)**:
    - Completely resolved the major natural language blind spot in `convertChineseNumbers`: previously, phrases like "一刻钟后关机" (turn off after 15 min), "两刻钟后关机" (30 min), "三刻钟后关机" (45 min), and "半个钟头后关机" (30 min) returned `nil` and failed recognition;
    - Fixed the broken compound expression "两个半钟头后关机" where missing "个半钟头" prevented conversion to 2.5 hours (150 minutes);
    - Permanently eradicated the hidden flaw in clock scheduling where "一刻/三刻" were simplistically replaced with digits "1/3", causing "十点一刻关机" to be miscalculated as `10:01` (14-minute error) and "十点三刻开机" as `10:03` (42-minute error); established 100% accurate time mapping for "十点一刻" (10:15), "十点三刻" (10:45), "晚上八点一刻" (20:15), and "明早七点三刻" (07:45).
  - 🌿 **Filter Cleanliness End-to-End Voice & Siri Shortcuts Integration (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `AppIntents` / `VoiceCommandParserTests`)**:
    - Introduced `VoiceCommand.queryFilterHealth` and `VoiceCommand.queryFilterHealthAll` voice commands, supporting spontaneous queries like "查询滤网", "滤网状态", "滤网洁净度", "滤网要洗吗", and "全屋滤网状态";
    - Voice capsule and multi-device pipelines leverage the aerodynamic equivalent wear model to provide clear cleanliness percentages, runtime hours, and maintenance advice;
    - Added `GetFilterHealthIntent` in macOS Shortcuts framework, allowing Siri and native macOS Automations to inspect filter health status on demand.
  - 🧼 **Self-Cleaning Stop Symmetry in Shortcuts & Single Source of Truth Primary Device Routing (`AppIntents` / `FilterCareSheet` / `StatusItemController`)**:
    - Added `StopSelfCleaningIntent` to AppIntents and registered it in the system shortcut provider, establishing complete symmetry with `StartSelfCleaningIntent` so users can abort 56°C evaporator self-cleaning anytime via Siri or Shortcuts;
    - Aligned initial device selection in `FilterCareSheet` to `model.primaryDeviceId`; refactored `StatusItemController` icon and tooltip primary device resolution directly to `model.primaryDeviceId`, preventing state drift in multi-device setups.
  - 💧 **Dehumidification Temperature-Humidity Coupled Thermodynamic Dynamics (`EnergyAnalyticsEngine`)**:
    - In `EnergyAnalyticsEngine.estimateInstantaneousPower` (`.dehumidify`), added indoor temperature thermodynamic compensation: adjusts for sensible heat load during high temperatures ($\ge 28^\circ\text{C}$, up to +80W) and simulates anti-frost inverter throttling during low temperatures ($\le 18^\circ\text{C}$, down to -60W).
- 🏷 **Natural Language Half-Hour Compound Conversion, Multi-Room Scope Hardening, Scene Preset Route Convergence & Menu Bar Control Center Alignment (v1.9.43)**:
  - ⏱️ **Natural Language Compound Half-Hour Countdown & Noon PM Timer Defect Remediation (`VoiceCommandParser` / `VoiceCommandParserTests`)**:
    - Completely resolved the major parsing bug where `convertChineseNumbers` previously replaced "半小时" unconditionally with "30分钟", causing colloquial phrases like "两个半小时后关机" (turn off after 2.5 hours) to become "两个30分钟", which collapsed into `30 minutes` (a severe 120-minute truncation); introduced structural regex matching (`([一二两三四五六七八九]|\d+)(?:个半小时|个钟头半|小时半|个小时半)`) to accurately translate "两个半小时" / "2个半小时" / "两小时半" to 2.5 hours (150 minutes) and "三个半小时" to 3.5 hours (210 minutes);
    - Resolved the noon timing defect where expressions like "中午1点关机" or "中午一点半关机" were misclassified as 01:00 / 01:30 AM (middle of the night) by adding "中午" and "午后" to the PM classifier, properly mapping them to 13:00 / 13:30 / 14:00 (while preserving 12:00 for noon).
  - 🛡️ **Targeted Multi-Room Commands Containing "全部/全都" Scope Defense (`VoiceCommandParser` / `VoiceCommandParserTests`)**:
    - Hardened `isAllDeviceScope` to differentiate between house-wide scope and multi-room targeted commands; phrases such as "把客厅和主卧全部关了" (turn off both living room and master bedroom completely) or "取消客厅和主卧全部定时" explicitly specify target rooms (`hasTargetRoomKeyword`), so adverbs like "全部/全都" apply strictly to the designated rooms rather than triggering `.turnOffAll` or `.cancelSchedulesAll`; whole-house triggers are strictly reserved for genuine global subjects like "全屋", "全家", "所有空调", or "全部空调".
  - 🌟 **Scene Preset Route Convergence & Multi-Room/Whole-House/Shortcuts Dispatch (`VoiceCapsuleWindowController` / `AppIntents`)**:
    - Fixed the routing bug where voice commands like "主卧睡眠情景" called `model.applyScene(scene)` without passing `targetDeviceId`, mistakenly defaulting to the primary device (e.g. living room);
    - Added whole-house scene scheduling (e.g. "全屋应用睡眠情景" dispatches with `allDevices: true`) and multi-room scene dispatch in `executeMultiDeviceCommand`;
    - Enhanced `ApplyACSceneIntent` in AppIntents with optional `deviceName` and `allDevices` parameters.
  - 🍱 **Menu Bar Control Center Single Source of Truth & Batch Control Panel Relative Stepping (`MenuBarControlsView` / `BatchControlView` / `AppModel`)**:
    - Eliminated stale state desynchronization in `MenuBarControlsView` by removing local `@State selectedDeviceId` and converging directly on `model.primaryDeviceId` as the single source of truth across the popover view, right-click menu, and global status item;
    - Upgraded batch temperature stepping in `BatchControlView` to utilize `adjustTemperature(includeStandby: true)`, preserving relative temperature offsets between different rooms and respecting the 16~30°C range bounds; expanded batch presets with Auto 24°C, Dehumidify, and Fan modes.
- 🏷 **Chinese Compound Numeral Overflow Remediation, Multi-Room Targeted Power Scope Defense, Unified Primary Device Routing & Menu Bar Active Unit Counter (v1.9.42)**:
  - 🔢 **Compound Chinese Numeral Overflow & Timer/Countdown Defect Remediation (`VoiceCommandParser` / `VoiceCommandParserTests`)**:
    - Completely resolved the overflow flaw where `convertChineseNumbers` previously mapped only up to 30 while omitting decades 31~99; commands like "四十分钟后关机" (turn off after 40 minutes) had "十" replaced with 10 and "四" with 4, corrupting into `410 minutes` (nearly 7 hours); similarly "四十五分钟" produced `415 minutes`, "五十分钟" produced `510 minutes`, and "三十五分钟" produced `305 minutes`;
    - Upgraded to structural compound numeral parsing (`([一二两三四五六七八九])?十([一二三四五六七八九])?`), offering 100% robust coverage across all 1~99 Chinese numbers ("四十五" -> 45, "四十" -> 40, "三十五" -> 35, "五十" -> 50, "六十" -> 60, "九十" -> 90) with full regression unit tests.
  - 🛡️ **Multi-Room Targeted Power Preemption & All-House Scope Defense (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `VoiceCommandParserTests`)**:
    - Permanently fixed the critical bug where targeted multi-room commands containing phrases like "都关了" or "都开了" (e.g. "客厅和主卧都关了" - turn off both living room and master bedroom) were greedily intercepted by `isAllPowerOff` / `isAllPowerOn`, which mistakenly caused the entire house's ACs (including children's room, study, etc.) to shut down or turn on;
    - Added room keyword scope validation (`hasTargetRoomKeyword`) to whole-house power rules, ensuring commands with specific room names cleanly bypass whole-house triggers and route into `executeMultiDeviceCommand` to act strictly upon the designated rooms.
  - 🍃 **End-to-End Fan Speed Execution & Fallback Hardening (`VoiceCapsuleWindowController`)**:
    - Eliminated the risk where multi-device fan speed adjustments failed silently without dispatching network commands when dynamic attribute metadata was not yet loaded;
    - Unified dispatch through `model.setWindSpeed(deviceIds:speedName:autoPowerOn:)`, supporting dynamic options, robust static grade fallbacks (1=quiet, 2=mid, 3=high, 0=auto), and auto-power-on for phrases containing "开".
  - 📍 **Centralized Primary Device Routing & Menu Bar Step-Adjust Device Counter (`AppModel` / `StatusItemController`)**:
    - Exposed unified `public var primaryDeviceId: String?` in `AppModel` (`menuBarDeviceId ?? allUnifiedDevices.first?.id`), standardizing primary device resolution and aligning filter care accumulation and reset logic across the codebase;
    - Enhanced right-click menu items "🔼 全屋统一升温 1°C" and "🔽 全屋统一降温 1°C" with real-time running device count indicators (e.g. `(N台运行中)` or `(当前均未开机)`), achieving 100% visual symmetry with whole-house preset actions.
  - ⚡️ **Fan Mode High-Flow Turbo Aerodynamic Power Range (`EnergyAnalyticsEngine`)**:
    - Expanded `.fan` mode power ceiling to 75.0W for high air volume turbo dynamics, providing richer thermodynamic and aerodynamic fidelity.
- 🏷 **Whole-House Temperature Power Linking & Fan Speed Coordination, Boundary Feedback Hardening, All-Weather Auto Extreme Dynamics & Menu Bar Visual Polish (v1.9.41)**:
  - 🎙️ **Whole-House Temperature Standby Wakeup Linking & Power Guarding (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `VoiceCommandParserTests`)**:
    - Completely resolved the interactive flaw where spoken whole-house temperature commands prefixed with "开" (e.g. "全屋开26度", "所有空调开25", "全屋开24") merely adjusted target temperature while leaving standby units off; seamlessly linked standby power-on (`onOffStatus = true`) in `VoiceCapsuleWindowController` with explicit feedback "（并开启 N 台待机空调）";
    - Hardened `isAllPowerOn` by excluding 16.0°C ~ 30.0°C valid temperature values and fan speed keywords, preventing whole-house setpoints from being misclassified as generic power commands.
  - 🍃 **Whole-House Fan Speed Coordination & Batch Dispatch (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `AppModel` / `VoiceCommandParserTests`)**:
    - Addressed the limitation where whole-house fan speed commands (e.g. "全屋开大风", "所有空调开微风", "全屋自动风", "把所有空调都调到中速风") previously fell back to single-unit control; added `VoiceCommand.setWindSpeedAll(String)` command;
    - Excluded fan speed keywords in `parseAllPreset` and routed whole-house fan speed requests cleanly; implemented `setWindSpeed(deviceIds:speedName:autoPowerOn:)` and `setWindSpeedAll` in `AppModel` with automatic standby awakening.
  - 🌡️ **Accurate Relative Temperature Boundary Feedback (`VoiceCapsuleWindowController`)**:
    - Fixed misleading error reporting where adjusting temperature when all operating units had reached limits (30°C or 16°C) falsely reported "当前无任何开机运行中的在线空调"; established two-tier validation returning clear neutral boundary messages ("全屋运行中的空调均已达到最高温度上限 30°C / 最低温度下限 16°C");
    - Aligned single-unit and multi-device relative adjustment boundaries with clean limit notifications, eliminating redundant hardware writes and false success messages.
  - ⚡️ **All-Season Extreme Climate & Dual-Direction Humidity Inverter Dynamics in Auto Mode (`EnergyAnalyticsEngine`)**:
    - Fully incorporated extreme heatwave condenser degradation overload dynamics (`heatBoost` 100~280W, 1750W peak at $\ge 30^\circ\text{C}$) and severe winter low-temp PTC auxiliary heating dynamics (`coldBoost` 120~320W, 1950W peak at $\le 15^\circ\text{C}$) into `.auto` mode in `estimateInstantaneousPower`, establishing 100% thermodynamic symmetry with cooling and heating modes alongside dual-direction humidity adjustments.
  - 🍱 **macOS Menu Bar Matrix Visual Symmetry & Tooltip Health Confirmation (`StatusItemController`)**:
    - Added matching visual mode emojis (❄️, 🔥, 💧, 🍃, 🔄) across all room submenus in the right-click "空调设备控制矩阵...", unifying visual presentation with top-level menus;
    - Added positive filter health feedback in the hover tooltip ("✨ 全屋空调滤网状态良好") when all units operate with healthy filter cleanliness.
- 🏷 **Structured Spoken Negation Guard, Whole-House Scheduling Dispatch, 5-in-1 Menu Bar Symmetry & Heatwave Cooling Dynamics (v1.9.40)**:
  - 🛡️ **Structured Natural Language Negation Defense & Phrase Insertion Bypass Elimination (`VoiceCommandParser` / `VoiceCommandParserTests`)**:
    - Completely resolved the bypass vulnerability where colloquial words, adverbs, or nouns inserted between negation words and action verbs (e.g., "别给我关了", "千万别现在关", "不用帮我关", "别太快关", "别乱调") failed to match whitelist character classes; upgraded to structural non-punctuation greedy matching `(?:别|不要|不用|先别|千万别|切勿|请勿|暂不)[^，。！？\s]{0,6}?(?:关|停|开|启动|运转|打开|关闭|调|设|升|降)` to robustly intercept conversational speech and prevent accidental whole-house or unit shutdowns;
    - Broadened negation defense across relative/absolute temperature adjustments, fan speeds, modes, and scenes, with comprehensive real-world test cases added.
  - ⏱️ **House-Wide Timer/Countdown Preemption Remediation & Multi-Device Coordination (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `VoiceCommandParserTests`)**:
    - Permanently eradicated the defect where commands like "全屋30分钟后关机" (turn off whole-house in 30 minutes) or "全屋半小时后开机" were greedily intercepted by immediate power-off/power-on logic due to pipeline order, which mistakenly caused immediate shutdowns; promoted schedule/countdown parsing prior to immediate power handlers and guarded power/temperature rules with countdown/timer filters;
    - Integrated whole-house and targeted multi-device countdown/schedule dispatch in `VoiceCapsuleWindowController` (`.countdownPower` and `.schedulePower`), setting timers concurrently with unified conversational feedback.
  - 🎙️ **Degree Suffix Omission in Spoken Absolute Temperature Parsing (`VoiceCommandParser` / `VoiceCommandParserTests`)**:
    - Fixed the defect where spoken temperature commands omitting the word "度" (e.g., "开26", "打开25", "开24") were captured by `isPowerOn` as simple power toggles, discarding the target temperature; added 16.0°C ~ 30.0°C valid range validation to accurately set temperature and awaken standby units.
  - 🍱 **macOS Menu Bar 5-in-1 Full Mode Matrix Symmetry & Quick Auto 24°C (`StatusItemController`)**:
    - Added "🔄 全屋智能自动 24°C (N Online)" to the right-click whole-house presets, completing the 5-in-1 operating mode matrix alongside Cool, Heat, Dehumidify, and Fan;
    - Added "一键智能自动 24°C" to per-device submenus and single-device context menus, establishing complete UI symmetry across all device tiers.
  - ⚡️ **Extreme Heatwave Overload & Condenser Degradation Inverter Dynamics (`EnergyAnalyticsEngine`)**:
    - Integrated extreme thermal load and condenser backpressure degradation into `.cooling` power estimation: when indoor temperatures are high ($\ge 30^\circ\text{C}$) and temperature difference is large ($\Delta T \ge 5^\circ\text{C}$), dynamically factors in inverter compressor over-frequency operation and thermal backpressure losses (+100W ~ 280W), expanding the cooling ceiling to 1750W for two-way seasonal symmetry with winter PTC heating.
- 🏷 **Natural Language Mode & Temperature Compound Control Defect Remediation, Menu Bar Primary Device Pinning & Low-Temp Heating Dynamics (v1.9.39)**:
  - 🎙️ **Root Fix for Mode Loss in Combined Mode & Temperature Spoken Commands (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `VoiceCommandParserTests`)**:
    - Completely resolved the defect where conversational commands combining both operation mode and target temperature (e.g. "制冷26度", "开制冷26度", "开冷气25度", "开暖气22度", "开制热二十度", "客厅制冷26度", "主卧开暖气21度", "客厅和主卧开制冷24度") lost their `operationMode` due to absolute temperature pattern matching precedence, preventing dangerous cold/hot inversion where units remained in winter heating mode despite summer cooling requests;
    - Introduced `VoiceCommand.setModeAndTemperature(mode:temperature:)` command model with pre-dispatch parsing of valid mode names and 16~30°C temperature ranges;
    - Seamlessly wakes standby units, synchronizes operation mode and target temperature across both single-device and multi-device pipelines (`executeMultiDeviceCommand`), providing natural conversational feedback ("清爽制冷 26°C", "舒适制热 20°C");
    - Extended structured negation protection to all temperature adjustment and inverter mode actions ("别开制冷26度", "不要开暖气22度", "别调到26度", "千万别开大风").
  - 🍱 **Menu Bar Primary Device Pinning in Device Matrix (`StatusItemController`)**:
    - Added native "★ 设为菜单栏主显设备" ("Pin as Menu Bar Primary Device") in right-click "空调设备控制矩阵..." device submenus (shows "✓ 菜单栏常驻主显中" when active);
    - Instantly switches `model.menuBarDeviceId`, triggers `refreshTemperature()` to update menu bar live temperature, icon, tooltip, and Bento popover focus, accompanied by an in-app confirmation Toast;
    - Badges primary devices with `★` in matrix menu titles, giving multi-unit users instant switching right from the status bar without opening the main window.
  - ⚡️ **Inverter Heating Low-Temp PTC Auxiliary Thermal Load Dynamics (`EnergyAnalyticsEngine`)**:
    - Deepened heating power thermodynamics in `estimateInstantaneousPower`: when indoor temperatures are low ($\le 15^\circ\text{C}$) and temperature difference is high ($\Delta T \ge 5^\circ\text{C}$), dynamically factors in PTC auxiliary electric heating and high-compression ratio boosts (+120W ~ 320W), vastly improving simulation accuracy for severe winter cold-starts;
    - Refined fan mode step dynamics, maintaining ultra-low micro-power (min 14W) at quiet speeds while capturing aerodynamic load at maximum blower speeds.
- 🏷 **Natural Language "Turn On" Mode/Temp Interception Fix, Menu Bar Primary Device Routing, Multi-Device Aggregated Status Query & Auto Mode Humidity Dynamics (v1.9.38)**:
  - 🎙️ **Root Fix for "Turn On" Mode & Temperature Preemption (`VoiceCommandParser` / `VoiceCommandParserTests`)**:
    - Completely resolved the defect where conversational phrases prefixed with "开/打开/开启" (e.g. "开除湿", "开制冷", "开制热", "开送风", "开26度", "开到26度", "开大风") were greedily preempted by `isPowerOn` and misclassified as simple power toggles; added explicit keyword exclusions for mode names, temperature values with "度", fan speeds, and scenes to ensure direct routing to mode switching and temperature adjustments;
    - Fixed fan speed downward adjustments ("关小风", "风速关小一点", "关小一点") being mistakenly caught by power-off rules;
    - Introduced `.queryStatusAll` command model to cleanly distinguish house-wide status queries ("全屋空调多少度", "全屋空调状态") from single-device inquiries.
  - 🛡️ **Self-Cleaning Control Flow & Multi-Device Aggregated Query Closure (`VoiceCapsuleWindowController`)**:
    - Added missing `scheduleAutoDismiss(delay: 1.8)` and `return` in `.stopSelfCleaning` branch, eliminating unintended fallthrough leaks;
    - Promoted `.stopSleepCurve` and `.queryStatusAll` to top-level priority dispatch, preventing premature "operation does not support multi-device batch execution" fallback warnings;
    - Implemented `case .queryStatus` in `executeMultiDeviceCommand` to format and aggregate room-by-room status telemetry (e.g. "「客厅」运行中，室温 24.5°C，制冷 26.0°C；「主卧」待机，室温 25.0°C");
    - Introduced smart standby interlock: when changing mode or setting temperature with "开", idle standby units automatically power on (`onOffStatus = true`).
  - 🍱 **Menu Bar Primary Device Routing Alignment & Live Online Count (`StatusItemController`)**:
    - Fixed routing drift in context menu step-up/step-down (`stepUpPrimaryTemperature` / `stepDownPrimaryTemperature`) and quick mode presets (Cooling/Heating/Dehumidify/Fan) which hardcoded `allUnifiedDevices.first?.id`, cleanly standardizing them onto the active user-selected primary device `primaryDeviceId` (`model.menuBarDeviceId ?? model.allUnifiedDevices.first?.id`);
    - Context menu whole-house quick preset items dynamically display controllable online unit counts (e.g. `❄️ Whole-House Cool 26°C (2 Online)`).
  - 💧 **Auto Mode Thermodynamic Humidity Dynamics Modeling (`EnergyAnalyticsEngine`)**:
    - Integrated indoor relative humidity (`indoorHumidity`) into `.auto` mode power estimation: humid conditions ($\text{RH} \ge 65\%$) dynamically factor in latent cooling loads, while dry conditions ($\text{RH} \le 45\%$) smoothly throttle micro-load power, ensuring realistic inverter thermodynamic responses.
- 🏷 **Full-Chain Natural Language Negation Protection, Atomic Scheduler Decoupling, Humidity-Adaptive Dehumidification & Dynamic Filter Lifespan Prediction (v1.9.37)**:
  - 🛡️ **Full-Chain Negation Guard across Modes, Scenes, Self-Cleaning & Sleep Curves (`VoiceCommandParser` / `VoiceCommandParserTests`)**:
    - Broadened negation pattern screening across all-house presets (`parseAllPreset`), modes (`parseMode`), scenes (`parseScene`), and global temperature adjustments (`parseAllTemperature` / `parseAllRelativeTemperature`), preventing expressions like "全屋空调别开冷气", "千万别开除湿", "不要开暖气", or "别开离家模式" from mistakenly activating units or switching modes;
    - Completely resolved the critical safety vulnerability where negative commands such as "不要自清洁", "别自清洁", "别开自清洁", or "不要启动自清洁" fell into the default branch due to missing "stop" verbs and accidentally initiated the 56°C high-temperature evaporator baking cycle, safely routing them to cancellation/stop;
    - Extended negation protection to sleep curves ("不要开启智能睡眠", "别开睡眠曲线") and schedule commands ("别定时", "不要定时").
  - ⏱️ **Atomic Scheduler Decoupling & Centralized Schedule Cancellation (`AppModel` / `VoiceCapsuleWindowController`)**:
    - Provided atomic APIs in `AppModel` (`cancelAllSchedules()`, `cancelSchedules(for deviceIds:)`, `cancelSchedules(for deviceId:)`), unifying memory collection pruning, `wakeScheduler()` timer rescheduling, `UserDefaults` persistence, and diagnostic logging;
    - Fixed the dormant timer issue in Voice Capsule where manual collection filtering bypassed `wakeScheduler()`, keeping background sleeping tasks synchronized with actual schedule cancellations.
  - 🧼 **Deep Filter Health Analytics: Habit-Adaptive Lifespan Prediction & House-Wide Health Monitoring (`FilterCareSheet` / `AppModel` / `StatusItemController`)**:
    - Connected `EnergyAnalyticsEngine` operational logs with `FilterCareSheet`, dynamically calculating remaining filter days based on actual running habits over the past 14 days (e.g. "• Based on recent avg 8.5h/day usage and current load, approx. 45 days remaining"), replacing rigid hardcoded 6h assumptions;
    - Upgraded menu bar right-click menu and tooltip with house-wide filter health aggregation: displays "Whole-House Min XX%" and alert badges whenever any unit's cleanliness drops to $\le 30\%$, clearly identifying specific rooms needing filter washing.
  - 💧 **Humidity-Adaptive Dehumidification Inverter Power Modeling (`EnergyAnalyticsEngine` / `AppModel`)**:
    - Introduced ambient relative humidity (`indoorHumidity`) into `DeviceEnergySample` and power estimation algorithms;
    - Implemented a 3-tier dynamic thermodynamic response model: heavy moisture condensation zone ($\text{RH} \ge 70\%$, 520W~620W base), balanced variable-frequency dehumidification zone ($55\% \le \text{RH} < 70\%$, 380W~500W base), and low-humidity micro-load protection zone ($\text{RH} < 55\%$, 240W~320W base to prevent overcooling/overdrying), seamlessly defaulting to 420W when humidity sensors are unavailable.
- 🏷 **CR Defect Remediation, Structured Spoken Negation Protection, Decoupled Whole-House Scheduling, Inverter Thermal Damping & Menu Bar Mode Expansion (v1.9.36)**:
  - 🛡️ **Structured Spoken Negation Guard & Intervening Phrase Shield (`VoiceCommandParser` / `VoiceCommandParserTests`, Closed CR P1-1)**:
    - Overhauled `containsNegativeAction` from a rigid adjacent-substring dictionary into a structured regex with comprehensive Chinese character-class tolerance;
    - Robustly intercepts negation clauses where modifier adverbs, quantifiers, disposal markers, or nouns intervene between negation words ("别", "不要", "不用", "先别", "千万别") and actuation verbs ("关", "开", "停")—covering patterns like "全屋空调别都关了", "不要全部关掉", "先别急着关", "别马上关", "别把全屋空调都关了", and "空调不用全开";
    - Expanded test suite with real-world inserted-word test cases, permanently eliminating false-positive whole-house power cutoffs triggered by colloquial negations.
  - ⏱️ **Decoupled Whole-House vs Targeted Schedule Cancellation & Batch Cancellation (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `VoiceCommandParserTests`, Closed CR P1-2)**:
    - Introduced `.cancelSchedulesAll` in `VoiceCommand`; verbal parser differentiates between all-house cancellations ("取消所有/全部/全屋定时") and targeted single-unit cancellations;
    - Voice Capsule cleanly routes `.cancelSchedulesAll` to wipe all active schedules and timers with distinct whole-house user feedback;
    - Added `case .cancelSchedules` in `executeMultiDeviceCommand` to support multi-room targeted schedule deletions (e.g., "取消客厅和主卧的定时"), aligning scope and voice confirmation while cleaning up unreachable dead code patterns (Closed CR P2-2).
  - ⚡️ **Single Source of Truth for Energy Ratios & Migration Compatibility (`EnergyAnalyticsEngine` / `EcoEnergySection`, Closed CR P2-1, P2-4)**:
    - Added `unknownRatio` to `EnergyDayRecord` and refactored UI layer (`EcoEnergySection`) to directly consume engine properties (`coolingRatio`, `heatingRatio`, `dehumRatio`, `fanRatio`, `unknownRatio`), eliminating duplicate math and unused public APIs;
    - Documented backward-compatibility migration: legacy pre-v1.9.35 records gracefully backfill from wall-clock sums, while new records calculate strict machine-minutes.
  - 🌡️ **Status Bar 16/30°C Limit Gating & Redundant Command Elimination (`StatusItemController` / `AppModel`, Closed CR P2-3)**:
    - Reinforced menu bar step-up/step-down items ("🔼 Step Up All ACs 1°C" / "🔽 Step Down All ACs 1°C") with boundary checks, enabling them only when running units are below 30°C or above 16°C;
    - Updated `AppModel.adjustTemperature` to filter out devices already at limits, returning 0 with a neutral notice when all units have reached the boundary, preventing redundant network commands.
  - 🍱 **macOS Menu Bar Dehumidify/Fan Mode Expansion & Whole-House Running Summary (High-Value Optimization 1)**:
    - Added "💧 Whole-House Dehumidify" and "🍃 Whole-House Fan" quick presets to the right-click menu, matching device submenus and single-device options for full mode coverage;
    - Enriched menu bar tooltip with a live house-wide summary header (e.g., `🏠 2 of 3 ACs running across the house`).
  - 💨 **Inverter Compressor Thermal Equilibrium Damping Model (High-Value Optimization 2)**:
    - Upgraded `EnergyAnalyticsEngine.estimateInstantaneousPower` with continuous thermal damping; when room temperature approaches the target setpoint ($|\Delta T| \le 0.5^\circ\text{C}$), the inverter compressor smoothly throttles down to ultra-low-frequency steady-state maintenance (220W for cooling, 300W for heating), eliminating step jumps and accurately reflecting Grade-1 energy efficiency.
- 🏷 **Thermodynamic Mode Dimensional Consistency, Device-Hours Analytics, Stepped Menu Bar Temperature Matrix & Whole-House Voice Temperature Stepping (v1.9.35)**:
  - ⚡️ **Thermodynamic Energy Analytics Calibration & Machine-Hours Precision (`EnergyAnalyticsEngine` / `EcoEnergySection`, Closed CR P2-1/2)**:
    - Resolved dimensional conflicts where aggregate operation mode minutes exceeded physical clock time under multi-device operation, establishing a dual-axis accounting model: natural elapsed wall-clock time (`totalMinutes`) vs total accumulated device machine-hours (`totalDeviceMinutes`, unit·min);
    - Integrated `totalDeviceMinutes` into `EnergyDayRecord` with backward-compatible custom `Codable` serialization, migrating legacy JSON records seamlessly;
    - Encapsulated zero-division safe metrics (`effectiveDeviceMinutes`, `coolingRatio`, `heatingRatio`, `dehumRatio`, `fanRatio`), hardening boundary calculations;
    - Enhanced Eco Energy Dashboard with contextual machine-hour percentages (e.g., `Cooling 120m (60%)`), giving immediate clarity on multi-room energy distribution.
  - 🍱 **macOS Menu Bar Fine-Grained Temperature Stepping Matrix (`StatusItemController` / `AppModel`)**:
    - Contextual right-click menu now provides complete temperature step controls: "🔼 Step Up All ACs 1°C" & "🔽 Step Down All ACs 1°C" in multi-device mode, plus "🔼 Step Up 1°C (Current XX°C)" & "🔽 Step Down 1°C (Current XX°C)" across individual submenus and single-device mode;
    - Coupled strictly with 16.0°C ~ 30.0°C hardware boundaries and power/reachability gating, dynamically disabling actions at limit values or when units are offline/idle;
    - Added core batch/single-device temperature stepping APIs in `AppModel` (`adjustDeviceTemperature`, `adjustTemperature`, `adjustTemperatureAll`).
  - 🎙️ **Voice Capsule Whole-House Relative Temperature Stepping (`VoiceCommandParser` / `VoiceCapsuleWindowController` / `VoiceCommandParserTests`)**:
    - Expanded voice recognition grammar to interpret natural relative temperature commands ("全屋调高两度", "所有空调升温1度", "全部空调调低一度"), mapping them to `.adjustTemperatureAll(delta:)`;
    - Connected Voice Capsule and multi-device dispatch to orchestrate concurrent relative temperature stepping with unified spoken confirmation.
- 🏷 **Offline Local Action Parity, Pure Power-On Safeguard & Negation Intent Filtering (v1.9.34)**:
  - 🛡️ **Reachability Guard Relocation & Local Action Parity (`VoiceCapsuleWindowController`, Closed CR P1-1)**: Relocated reachability gating from the overall dispatch entry down into individual physical actuator branches. Purely local operations—including status queries (`.queryStatus`), schedule cancellations (`.cancelSchedules`), sleep curve terminations (`.stopSleepCurve`), and sleep session reports (`.querySleepReport`)—now execute uninhibited, completely eliminating offline or reconnecting blockage when inspecting or managing local tasks.
  - ⚡️ **Pure Power-On Thermal Inversion Shield (`AppModel` / `AppIntents` / `VoiceCapsule`, Closed CR P1-2)**: Introduced `turnOnDevices(deviceIds:)` and `turnOnAllDevices()` to strictly transmit `onOffStatus = true` while preserving existing operational modes and target temperatures. Upgraded Siri's `TurnOnAllACIntent` and voice command `.turnOnAll` to pure power-on dispatch, eradicating winter thermal inversion caused by legacy hardcoded cooling resets.
  - 🎯 **Schedule Cancellation Targeted Scope Shield (`VoiceCapsuleWindowController`, Closed CR P2-1)**: Resolved a security scope leak where cancelling schedules for a specific device with no active timers accidentally fell back to wiping all timers across the entire house.
  - 📐 **Rigorous Set Equality & Stale ID Immunity (`BatchControlView` / `AppModel`, Closed CR P2-2)**: Refactored batch and whole-house comparison logic from naive count comparisons to `Set`-based superset and equality validations, preventing historical stale device IDs from falsely triggering whole-house action labels.
  - 🗣️ **Negative Intent Filtering & Spoken Safeguard (`VoiceCommandParser`, Closed CR P2-3)**: Implemented `containsNegativeAction` in verbal parser to intercept spoken negations (e.g. "别关", "不要关", "先别开"), preventing casual colloquial banter from unintentionally triggering appliance power changes.
  - 🍱 **Menu Bar Whole-House Power-On & Symmetrical Batch Matrix (`StatusItemController` / `BatchControlView`)**:
    - Added "⏻ Turn On All ACs (N Standby)" to the right-click menu, creating a complete symmetrical pair with whole-house shutdown while keeping existing presets and strictly aligning `isEnabled` gating;
    - Introduced "Turn On All / Selected" quick action in `BatchControlView`, forming a comprehensive 4-in-1 control matrix (Cooling, Heating, Power On, Standby).
- 🏷 **Whole-House Voice Mode Routing, Temperature Coordination & Thermal Inversion Safeguard (v1.9.33)**:
  - 🎙️ **Whole-House Voice Mode & Temperature Dispatch (`VoiceCommandParser` / `VoiceCapsuleWindowController`)**: Overhauled whole-house voice recognition and dispatch pipelines to eradicate the critical defect where heating requests ("全屋开暖气", "全屋开制热") were misclassified as generic power-on events by `isAllPowerOn` and inadvertently activated cooling at 26°C. Introduced `.presetAll(mode:temperature:)` and `.setTemperatureAll(Double)` commands, directly mapping natural verbal requests ("全屋开暖气", "全屋制热22度", "所有空调开冷气25度", "全屋调到24度", "全屋送风") to comfortable seasonal baselines (Heating 20°C / Cooling 26°C / Auto 24°C).
  - 🏠 **Multi-Room Combinatorial Voice Coordination (`VoiceCapsuleWindowController`)**: Upgraded room target parsing to `resolveTargetDevices(for:model:)`, supporting composite multi-room phrases like "客厅和主卧一起关了" (Turn off both living room and master bedroom) and "次卧跟客厅调到26度", leveraging `executeMultiDeviceCommand` for atomic multi-device command execution and unified status confirmation.
  - 🍱 **Menu Bar Single-Device Presets, Multi-Unit Activity Sensing & Dynamic Wattage Formatter (`StatusItemController`)**:
    - Context menu for single-device setups now includes "❄️ Quick Cool 26°C" and "🔥 Quick Heat 20°C" shortcuts, establishing complete feature parity with multi-device environments;
    - Dual-state menu bar icon now evaluates `anyDeviceRunning`, rendering solid `air.conditioner.horizontal.fill` whenever any air conditioner in the home is active even if the primary unit is idle, with comprehensive multi-room counts in the tooltip;
    - Instantaneous total power dynamically adapts between `W` and `kW` (formatting as `%.2f kW` when exceeding 1000W).
  - 📱 **Siri AppIntents & Shortcuts Ecosystem Parity (`AppIntents`)**: Introduced `TurnOnAllACIntent` (Turn On All ACs) across both macOS 14+ and fallback branches in `ACAppShortcutsProvider`, enabling seamless two-way Siri voice control for whole-house power, presets, and cleanings.
- 🏷 **Batch Scope Isolation, Multi-Device Natural Language Routing & Whole-House Winter Heating (v1.9.32)**:
  - 🛡️ **Batch Control Scope Penetration Safeguard (`BatchControlView` / `AppModel`)**: Refactored `AppModel` batch control methods by upgrading `turnOffAllDevices` and `applyPresetToAllDevices` into target-scoped `turnOffDevices(deviceIds:)` and `applyPreset(deviceIds:mode:temperature:windSpeed:)`. Batch preset buttons (Cool 26°C, Heat 20°C, Power Off) are now strictly constrained to the user's selected `deviceIds` subset with dynamic labels ("Power Off All" vs "Power Off Selected"), eliminating accidental remote actuation of unselected rooms.
  - 🎙️ **Multi-Room Voice Target Smart Routing (`VoiceCapsuleWindowController`)**: Introduced `resolveTargetDevice(for:model:)` room and device name parser to intelligently match spoken location tags (e.g. "Living Room", "Master Bedroom", "Study", "Bedroom 2"), dispatching commands directly to the targeted unit with seamless fallback to the primary device. Adds offline reachability interception per targeted unit (e.g. "'Living Room AC' is currently offline") and provides explicit device confirmation feedback.
  - 🗣️ **Conversational Grammar & Disposal-Clause Expansion (`VoiceCommandParser`)**: Significantly widened Chinese spoken syntax tolerance, supporting colloquial structures ("把所有的空调都关了", "把客厅空调关了", "次卧空调关一下", "关闭次卧", "打开客厅空调", "开启主卧") while preventing mode commands from falsely triggering general power toggles.
  - 🍱 **Menu Bar Whole-House Winter Heating & Controllability Guard (`StatusItemController`)**: Added "🔥 Quick Heat Whole House 20°C" to the menu bar right-click menu alongside quick cooling; hardened whole-house quick actions with `hasControllable` physical reachability guards to disable items when the gateway is reconnecting or all devices are offline.
- 🏷 **Whole-House Intelligent Coordination, Natural Voice Self-Cleaning & Real-Time Power Telemetry (v1.9.31)**:
  - 🏠 **Whole-House Unified Coordination (`turnOffAllDevices` / `applyPresetToAllDevices`)**: Natively integrated one-click whole-house power off and comfort preset commands into `AppModel`, automatically resolving reachable and powered-on target units for concurrent batch dispatch. Added Quick Bento Presets (Cooling 26°C, Heating 20°C, Power Off All) into `BatchControlView`, while introducing dynamic first-valid-attribute probing to ensure controls never render blank if the primary device is offline.
  - 🎙️ **Natural Language Voice Control Upgrade with Self-Cleaning Management (`VoiceCapsuleWindowController`)**: Expanded voice lexicon with whole-house shutdown ("全屋关机", "关闭所有空调"), whole-house power-on ("开启所有空调", "全屋开机"), and 56°C evaporator self-cleaning controls ("启动自清洁", "停止自清洁"). Refactored execution lifecycle so whole-house and session-stopping commands bypass single-device reachability barriers.
  - 📱 **Siri AppIntents & Shortcuts Ecosystem Integration (`AppIntents`)**: Added `TurnOffAllACIntent` and `StartSelfCleaningIntent`, automatically registered across macOS Shortcuts and Siri via `AppShortcutsProvider`. Fixed temperature dialog decimal truncation bug to natively support 0.5°C precise verbal feedback.
  - ⚡️ **Menu Bar Instantaneous Power & Filter Wear Reactivity (`StatusItemController`)**: Subscribed `EnergyAnalyticsEngine.shared.$currentInstantaneousPower` and `model.$filterAccumulatedMinutes` to the Combine status pipeline, ensuring tooltips reflect live wattage changes and filter maintenance alerts without delay. Added "❄️ Quick Cool Whole House 26°C" to the right-click context menu.
  - 🧪 **Offline Return-Air Telemetry Decoupling**: Strictly sanitized temperature feeds in minute-by-minute energy sampling (`indoorTemp: isOnline ? indoorTemp : nil`) to eliminate stale disconnected sensor readings from interfering with dynamic thermodynamic calculations.
- 🏷 **Full-Stack Whole-House Device Parity & Offline Energy Shielding (v1.9.30)**:
  - 🏠 **Full-Stack 100% Device Parity**: Completely eliminated disjointed manual device concatenations across the app in favor of `model.allUnifiedDevices`. Menu bar mini panel (`MenuBarControlsView`) now consumes `effectiveDevices`, giving LAN manual devices and cloud devices identical parity in switching, monitoring, and controls. Scene management (`SceneViews`), schedule management (`ScheduleViews`), main device list (`DeviceListView`), and URL scheme handlers now uniformly resolve targets via `allUnifiedDevices`.
  - ⚡️ **Dynamic Reachability Alignment (`effectiveDevices`)**: Refactored `effectiveDevices` to dynamically project true real-time connectivity status via `reachability(for: u.id) == .available`, eliminating stale static online flags cached from initial cloud fetches.
  - 🛡️ **Offline Phantom Energy & Filter Wear Shielding**: Reinforced background energy integration (`accumulatePeriodicWork`) with physical reachability gating (`let isOnline = (reachability(for: dev.id) == .available)`). When a physical unit disconnects from power or WiFi, it is immediately decoupled from active compressor energy integration and aerodynamic filter wear accumulation.
  - 🌤️ **Status Bar Strict Offline Protection & Scene Safety Gateways**: Main status bar running icon power state now strictly requires `reachability(for: targetId) == .available`; `menuBarTemperatureText` gracefully clears when offline to avoid displaying obsolete temperatures; `applyScene` dispatch guards actions against unreachable targets.
- 🏷 **Unified Whole-House Perception & Energy Dynamics Upgrade (v1.9.29)**:
  - 🖥️ **Status Bar Whole-House Perception & Tooltip Overhaul**: Completely refactored `StatusItemController` tooltips and device targeting onto `allUnifiedDevices`, removing legacy split branches between cloud and manual units. Now simultaneously displays all online, offline, and standby devices across both cloud and LAN integrations; added Combine subscription for `model.$manualDevices` so added/removed local units instantly refresh the menu bar; standby units now display ambient room temperatures when available.
  - ⚡️ **56°C Evaporator Self-Cleaning Thermodynamic Power Modeling & Integration**: Established a thermodynamic power model in `EnergyAnalyticsEngine` for 56°C high-temp evaporator cleaning (frosting, defrosting, and 56°C sterilization stages: ~920W base + fan offset); accurately integrates energy consumption and runtime into high-temperature thermal operation hours during cleaning cycles, fixing previous underestimations where cleanings were miscalculated as 1.5W idle standby.
  - 🎙️ **Siri AppIntents & Voice Capsule Reachability Gating**: Refactored target device resolution across `VoiceCapsuleWindowController` and all `AppIntents` (`SetACPowerIntent`, `GetIndoorTemperatureIntent`, `StartSleepCurveIntent`, etc.) with `menuBarDeviceId` precedence and `allUnifiedDevices` lookup; added fail-closed gating via `reachability(for: deviceId).isControllable` to actively intercept offline or reconnecting units with informative error prompts instead of misleading success confirmations.
  - 🌙 **Whole-House Multi-Device Sleep Curve Target Selection**: Added target device selector to `SleepCurveSection`, allowing multi-room users to target any specific cloud or LAN air conditioner for custom sleep temperature curves; upgraded `EcoEnergySection` whole-house eco score and `NetworkPresenceGuard` departure guard to consume `allUnifiedDevices`.
- 🏷 **Unified Whole-House Device Abstraction & AppKit NSMenu Gating Fix (v1.9.28)**:
  - 🛡️ **AppKit NSMenu `autoenablesItems` Gating Fix (CR P1 Closure)**: Enforced `autoenablesItems = false` across all NSMenu instances (`menu`, `devicesMenu`, `devSubmenu`, `themeMenu`) in `StatusItemController`. Completely fixes the AppKit bug where `isEnabled` assignments were overwritten upon presentation, guaranteeing offline and reconnecting state items are strictly disabled.
  - 🌙 **Sleep Session Stop Decoupled from Reachability (CR P2-1 Closure)**: Granularly decoupled sleep curve controls: because `stopSleepCurve()` is a strictly local routine (archiving state, stopping ambient sound, clearing schedules), its "Stop" button remains accessible even when the device or gateway is offline. Idle "Start" button remains strictly guarded by device reachability.
  - 🏠 **Whole-House Off Device Count Alignment (CR P2-2 Closure)**: Corrected the context menu title "Turn Off All ACs (N Running)" and its dispatch logic to strictly count and target devices that are both currently controllable (`isControllable`) and powered on.
  - 🌿 **56°C Maintenance Incentive Policy Clarification (CR P2-3 Closure)**: Clarified in model comments, UI badges, and docs that the 10% load reduction following a 56°C evaporator cleaning is a product health incentive policy rather than a claim of physical filtration disparity.
  - 🧬 **Unified Device Abstraction (`UnifiedDevice`)**: Introduced `UnifiedDevice` model and `allUnifiedDevices` in `AppModel`, unifying cloud-discovered and manually configured air conditioners into a single deduplicated roster. Fixes manual devices missing real-time attribute subscriptions, filter tracking, and dynamic energy calculations.
- 🏷 **Architecture Audit Closure & Evaporator Self-Cleaning Eco Dynamics (v1.9.27)**:
  - 🛡️ **Comprehensive CR Defect Closure & Fail-Closed Gateways**: Closed CR P1 by wiring `DeviceReachability` gating to the Sleep Control pod in `MenuBarControlsView` and inserting reachability checks in `AppModel.startSleepCurve`; closed CR P2-1 by switching unmatched device reachability to fail-closed (`.deviceOffline`), synchronizing header status badges to consume reachability, and fixing fail-open risks & deduplicating targets in `sendAttributeToDevices`.
  - ⚡️ **Granular Deserialization Resilience & Unbiased Energy Dynamics**: Closed CR P2-3 by safeguarding all `EnergyDayRecord` keys with `decodeIfPresent` and wrapping decode iterations in `FailableDecodable` to isolate corrupted items with warnings instead of dropping the entire dataset; closed CR P2-2 by adopting an unbiased physical average model ($465.0 + |\Delta T| \times 102.5$) for unrecognized operation modes.
  - 🧼 **Evaporator 56°C Self-Cleaning Dynamics & 7-Day Protection**: Dynamically connected 56°C evaporator high-temperature self-cleaning with the aerodynamic filter model; records per-device cleaning timestamps and grants a 0.90x load mitigation factor for 7 days post-cleaning, displayed with a dedicated "✨ 56°C Protection Active (-10%)" badge.
  - 🍱 **macOS Status Item Tri-State Tooltip & Whole-House Cascade Menu**: Status item tooltip now reflects `.gatewayReconnecting` and `.deviceOffline` states; right-click context menu enhanced with one-click "Turn Off All ACs" and cascading device control submenus (Power, 26°C Cool, 20°C Heat).
- 🏷 **Tri-State Reachability Defense & Self-Consistent Energy Analytics (v1.9.26)**:
  - 🛡️ **Unified Device Reachability Model & Precise Batch Feedback**: Closed CR P2-3/4 by establishing `DeviceReachability` (`.available`, `.gatewayReconnecting`, `.deviceOffline`). Unified banners and action disabling across Menu Bar, Device Control, and Batch Control views, eliminating ghost clicks when offline or reconnecting. Batch control strictly separates empty selections from completely offline targets, and explicitly reports skipped offline units when partial targets are reachable.
  - ⚡️ **Energy Analytics Self-Consistency & Backwards-Compatible Decodable**: Closed CR P2-2/6 by adding `unknownMinutes` to `EnergyDayRecord` with custom Codable implementation ensuring 100% smooth deserialization of historical UserDefaults JSONs; refactored unknown mode power estimation to adaptively scale with neutral delta-T rather than overestimating; added real-time mode runtime distribution breakdown (Cooling, Heating, Dehumidifying, Fan, Other) to the Eco energy dashboard.
  - 🔄 **Reconnection Generation Race Elimination**: Closed CR P2-5 by introducing `reconnectGeneration` counter in `retryConnection`, validating task currency upon async resumption to prevent stale retries from overwriting latest connection state.
  - 🌬️ **Multi-Dimensional Relative Humidity Filter Wear Model**: High-value physics enhancement in `calculateFilterWearFactor`, factoring in indoor relative humidity (≥75% RH applies 1.25x moisture particulate swelling factor, ≥65% applies 1.12x, ≤35% applies 0.95x discount), closely aligning with physical dust hydration and coil adhesion behaviors.
  - 🧹 **Dead Code Elimination**: Closed CR P2-1 by removing unused `ACModeCode.localizedName`.
- 🏷 **In-Flight Connection Guard & Dynamic Dual-State Status Bar (v1.9.25)**:
  - 🛡️ **WebSocket In-Flight Guard & Task Generation Validation**: Closed CR P1 defect by adding strict `guard self.task == nil else { return }` in `connect()`, completely preventing orphan duplicate connections under rapid reentrancy; `reconnectImmediately(force: true)` cancels and clears existing tasks before re-handshaking; `receiveLoop` enforces `task === self.task` validation across all async phases.
  - ⚡️ **Neutral Power Baseline & Precise Mode Matching**: Closed CR P2-1 by updating instantaneous power model to fallback to `.auto` instead of forced cooling; sampling engine excludes unrecognized modes from `runningCooling` hours; voice control returns descriptive failure when mode is unrecognized instead of forced cooling.
  - 🍱 **Dynamic Menu Bar Dual-State Icon & Context Menu Toggle**: Status bar icon dynamically renders solid `air.conditioner.horizontal.fill` when any AC is active and running, and outline `air.conditioner.horizontal` when standby; right-click context menu now provides one-click power toggle for the primary AC.
  - 🛡️ **Full-Stack Physical Offline Defense & Semantic Design Token**: Added offline checks before sending commands in `AppModel` to block ghost optimistic UI; standardized `Theme.offline` token across menu bar and main window status capsules.
- 🏷 **Safe Mode Decoding & Lightweight Audio Snapshot Engine (v1.9.24)**:
  - 🛡 **CR Mode Semantic Safety & Wear Model Alignment**: Fixed raw mode fallback bug where unrecognized modes defaulted to cooling; non-recognized states now safely use neutral base wear factor (1.00), preventing 20%~35% filter wear overestimation.
  - 🔒 **CoreAudio Realtime Thread Lightweight Parameter Snapshotting**: Replaced closure captures and main-actor variable reads inside `AVAudioSourceNode` render loop with `os_unfair_lock`-backed parameter snapshotting, completely eliminating TSAN data-race hazards.
  - ⚡️ **Sub-Second Gateway Healing**: Auto-resets backoff attempts upon `NWPathMonitor` reconnection or system wake-up, cutting reconnection latency from up to 120s down to milliseconds.
  - 💡 **Deep Physical Offline Status Awareness**: Header pod clearly distinguishes device offline status from normal power-off state with helpful tooltips.
- 🎨 **Brand New Design System & Control Center Style (v1.9.0)**:
  - 🧊 **Native Vibrant Material**: NSStatusItem NSPopover adopts native translucent materials with subtle glass borders and glow.
  - 🍱 **Modular Bento Grid**: Structured Bento card layout across menu bar and main window for crisp visual hierarchy.
  - 🌡️ **Dynamic Semantic Mode Tint**: Adaptive contextual colors reflecting current AC mode (Cooling Ice-Blue, Heating Warm-Orange, Dehumidify Cyan, Fan Mint-Green, Standby Purple) with subtle card glow.
  - 💊 **Tactile Temperature Stepper Pill**: Replaced clumsy sliders with high-touch ±0.5°C stepper capsules.
  - 📟 **Hero Temperature Pod**: Prominent 42pt temperature display with dual-pill indoor temperature & humidity telemetry.
  - 📈 **Swift Charts Area Trend & Pulsing Beacon**: 24h temperature area curves with gradient fills and real-time pulsing beacons; compact sparkline in menu bar popover.
  - 📂 **Categorized Collapsible Drawers**: Advanced device settings neatly grouped into Vane/Airflow, Health/Clean, Sleep/Eco, and Hardware Diagnostics.
- 🔐 **Phone + password login** to Haier Smart Home cloud (works with Leader/Haier/Casarte devices)
- 🖥 **Main window control panel**:
  - Screen/light display toggle (scene light pinned on top)
  - Power, target temperature, operation mode, fan speed
  - All other writable attributes rendered dynamically
  - 📈 Real-time status capsules (indoor temp/humidity/mode/fan) + 24h temperature trend (Swift Charts)
- ☁️ **Menu bar mini panel**: Control Center-style Bento Popover with power, temperature stepper, mode/fan quick buttons, and 24h sparkline (`NSStatusItem + NSPopover`, avoiding macOS 26 `MenuBarExtra` ghost window bug)
- 🧩 **Desktop Widgets**: Small & Medium widgets showing temperature, humidity, and status via AppGroup shared snapshots
- 🎨 **Three theme modes**: Follow System / Light / Dark (macOS Native + Linear hybrid design tokens)
- 📡 Real-time state via WebSocket gateway subscription, exponential backoff auto-reconnect (5s→120s), heartbeat self-check
- 🔑 Token auto-refresh (10-day validity) with encrypted local storage
- ⏱ Local scheduler & scene presets: Timers, countdowns, and one-tap scene modes with macOS notifications
- ⚡ Batch control: Select multiple devices and set power/temperature/mode/fan speed simultaneously
- 🗣 Shortcuts & Siri integration: Power toggle, temperature adjustment, scene application, and status queries
- 🛡 Robustness: Generation-isolated connections, race-condition protection, quick reconnect on active sessions

## Architecture

```
SwiftUI App
├── HaierACCore        # Protocol core (system frameworks only, zero third-party deps)
│   ├── DeviceProvider     # Multi-brand provider interface
│   ├── HaierProvider      # Haier cloud implementation (login/device/digital model/gateway)
│   ├── RequestSigner      # SHA256 request signing (CryptoKit)
│   ├── HaierCloudClient   # REST: login/refresh/devices/digital model/gateway
│   ├── HaierGatewayClient # WebSocket: subscribe/heartbeat/control/reconnect
│   ├── Zlib               # Downstream data decompression (system libz)
│   ├── CredentialStore    # Encrypted storage (hardware-bound key + AES-GCM)
│   └── KeychainStore      # Migration utility
└── HaierACApp         # SwiftUI UI
    ├── AppModel           # State machine: login/connection/control/scheduler/scenes
    ├── StatusItemController # Status bar controller (NSStatusItem + NSPopover)
    ├── Views/             # Login / device list / control panel / menu bar / batch / scenes
    ├── AppIntents.swift   # Shortcuts & Siri integration
    └── Theme.swift        # Design tokens (palettes, mode tints, Bento styling)
└── HaierACWidget      # WidgetKit desktop widget (AppGroup state snapshot)
```

## Build

Requires macOS 13+, Xcode Command Line Tools (Swift 6).

```bash
./build_app.sh            # build + package dist/HaierAC.app (default v1.9.0, does not auto open)
./build_app.sh 1.9.0 --open   # specify version + auto open after packaging
```

## Privacy & Security

- **Password never persisted**: used only to exchange for an access token, cleared from memory immediately after login
- **Token stored in encrypted local file** (`~/Library/Application Support/HaierAC/credentials.json`, mode 600), auto-refreshed on expiry
- **Zero hardcoded secrets**: no account/phone/appKey in code; appKey is read from the `HAIER_APP_KEY` env var or a local `~/.haier-ac-appkey` file (never committed)
- **Redacted logs**: tokens are masked in diagnostic logs (`~/Library/Logs/HaierAC/app.log`)
- Credentials only ever talk to official Haier endpoints (zj.haier.net / uws.haier.net / wssgw.haier.net)

## Protocol Verification Scripts (optional)

```bash
# 1. Verify login / devices / digital model
HAIER_PHONE='phone' HAIER_PASSWORD='password' HAIER_APP_KEY='appKey' python3 verify_protocol.py

# 2. WebSocket gateway full-property report (requires uv)
HAIER_PHONE='phone' HAIER_PASSWORD='password' uv run --with websockets python3 websocket_verify.py 30

# 3. Real control command test (light toggle)
HAIER_PHONE='phone' HAIER_PASSWORD='password' uv run --with websockets python3 send_control_test.py
```

## Disclaimer

This project is not affiliated with or endorsed by Haier Group. Not official software. For personal, legal, non-commercial use only. If Haier changes their protocol, the app may stop working without notice. Use at your own risk.
