# Haier AC Mac Control

A native SwiftUI app to control Haier / Leader (统帅) smart air conditioners on macOS. Full control panel in the main window, plus a menu bar mini control panel (Control-Center-like).

> Personal project for learning purposes only. Based on reverse-engineered Haier Smart Home cloud protocol, referencing [banto6/haier](https://github.com/banto6/haier) (Apache-2.0) for protocol insights. Code is independently written.

## Features

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
