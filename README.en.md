# Haier AC Mac Control

A native SwiftUI app to control Haier / Leader (统帅) smart air conditioners on macOS. Full control panel in the main window, plus a menu bar mini control panel (Control-Center-like).

> Personal project for learning purposes only. Based on reverse-engineered Haier Smart Home cloud protocol, referencing [banto6/haier](https://github.com/banto6/haier) (Apache-2.0) for protocol insights. Code is independently written.

## Features

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
