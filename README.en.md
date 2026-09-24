# Haier AC Mac Control

A native SwiftUI app to control Haier / Leader (统帅) smart air conditioners on macOS. Full control panel in the main window, plus a menu bar mini control panel (Control-Center-like).

> Personal project for learning purposes only. Based on reverse-engineered Haier Smart Home cloud protocol, referencing [banto6/haier](https://github.com/banto6/haier) (Apache-2.0) for protocol insights. Code is independently written.

## Features

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
