# Haier AC Mac Control

A native SwiftUI app to control Haier / Leader (统帅) smart air conditioners on macOS. Full control panel in the main window, plus a menu bar mini control panel (Control-Center-like).

> Personal project for learning purposes only. Based on reverse-engineered Haier Smart Home cloud protocol, referencing [banto6/haier](https://github.com/banto6/haier) (Apache-2.0) for protocol insights. Code is independently written.

## Features

- 🔐 **Phone + password login** to Haier Smart Home cloud (works with Leader/Haier/Casarte devices)
- 🖥 **Main window control panel**:
  - Display light / screen switches (scene light pinned on top)
  - Power, target temperature, operation mode, fan speed
  - All other writable attributes rendered dynamically (switches / pickers / sliders)
- ☁️ **Menu bar mini panel**: toggle the AC light without opening the main window (`MenuBarExtra` window style)
- 🎨 **Three theme modes**: Follow System / Light / Dark (Linear design system, dual palettes)
- 📡 Real-time state via WebSocket gateway subscription, auto-reconnect on drop
- 🔑 Token auto-refresh (10-day validity), Keychain persistence

## Architecture

```
SwiftUI App
├── HaierACCore        # Protocol core (system frameworks only, zero third-party deps)
│   ├── RequestSigner      # SHA256 request signing (CryptoKit)
│   ├── HaierCloudClient   # REST: login/refresh/devices/digital model/gateway
│   ├── HaierGatewayClient # WebSocket: subscribe/heartbeat/control/reconnect
│   ├── Zlib               # Downstream data decompression (system libz)
│   └── KeychainStore      # Secure token storage (Security)
└── HaierACApp         # SwiftUI UI
    ├── Views/             # Login / device list / control panel / menu bar panel
    └── Theme.swift        # Design tokens (light/dark dual palettes)
```

## Build

Requires macOS 13+, Xcode Command Line Tools (Swift 6).

```bash
./build_app.sh    # build + package dist/HaierAC.app + auto open
```

## Privacy & Security

- **Password never persisted**: used only to exchange for an access token, cleared from memory immediately after login
- **Token stored in Keychain** (system-encrypted, `local.haierac.token`), auto-refreshed on expiry
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
