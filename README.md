# Haier AC Mac 控制

[English](README.en.md) | 中文

在 macOS 上控制海尔/统帅智能空调的原生 SwiftUI 应用。支持主窗口完整控制 + 菜单栏迷你控制面板（类似控制中心）。

> 个人项目，仅供学习交流。基于对海尔智家云开放协议的逆向研究，参考了 [banto6/haier](https://github.com/banto6/haier)（Apache-2.0）的协议实现思路，代码为独立编写。

## 功能

- 🔐 **手机号 + 密码登录**海尔智家云（统帅/海尔/卡萨帝设备通用）
- 🖥 **主窗口控制面板**：
  - 灯光/屏显开关（情景灯光置顶）
  - 电源、目标温度、模式、风速
  - 其余全部可写属性动态渲染（开关/选择器/滑块）
  - 📈 实时状态胶囊（室内温度/湿度/模式/风速）+ 24h 温度趋势曲线（Swift Charts）
- ☁️ **菜单栏迷你面板**：目标温度/湿度 + 24h 温度趋势迷你图 + 一键开关灯光（`NSStatusItem + NSPopover`，规避 macOS 26 `MenuBarExtra` 幽灵窗口缺陷）
- 🧩 **桌面小组件**：小/中尺寸，实时显示室内温度、目标温度、湿度、运行状态（AppGroup 共享快照，状态变化即时刷新）
- 🎨 **三态主题**：跟随系统 / 浅色 / 深色（Linear 设计体系，双色板）
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
    └── Theme.swift        # 设计令牌（浅色/深色双色板）
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
./build_app.sh            # 构建 + 打包 dist/HaierAC.app（默认 v1.8.2，不自动打开）
./build_app.sh 1.8.2 --open   # 指定版本号 + 构建后自动打开
```

## 隐私与安全

- **密码不落盘**：仅用于换取访问令牌，登录后立即从内存清除
- **Token 存本地文件**（`~/Library/Application Support/HaierAC/credentials.json`，权限 600 仅当前用户可读写），到期自动刷新
  - 为什么不用 Keychain：本应用为 ad-hoc 签名（个人项目每次打包重新签名），macOS 钥匙串对匿名签名调用者会反复弹出密码框；文件存储彻底消除弹窗，token 为短期凭证（10 天有效）风险可控
- **代码零敏感信息**：无硬编码账号/手机号；验证脚本从环境变量读取凭据
- **日志脱敏**：诊断日志（`~/Library/Logs/HaierAC/app.log`）中 token 已脱敏
- 凭据仅与海尔官方云（zj.haier.net / uws.haier.net / wssgw.haier.net）通信

## 协议验证脚本（可选）

```bash
# 1. 协议验证：登录/设备/数字模型
HAIER_PHONE='手机号' HAIER_PASSWORD='密码' python3 verify_protocol.py

# 2. WebSocket 网关全量上报验证（需 uv）
HAIER_PHONE='手机号' HAIER_PASSWORD='密码' uv run --with websockets python3 websocket_verify.py 30

# 3. 真实控制指令测试（灯光开关开/关）
HAIER_PHONE='手机号' HAIER_PASSWORD='密码' uv run --with websockets python3 send_control_test.py
```

## 免责声明

本项目与海尔集团无关，非官方软件。仅限个人、合法、非商业用途。若海尔官方协议变更导致不可用，恕不另行通知。使用本项目产生的一切后果由使用者自行承担。
