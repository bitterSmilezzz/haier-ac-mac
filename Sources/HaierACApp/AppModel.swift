import Foundation
import Combine
import SwiftUI
import ServiceManagement
import HaierACCore

/// 手动添加的设备（持久化到 UserDefaults）
struct ManualDevice: Identifiable, Codable, Hashable {
    let deviceId: String
    var name: String
    var id: String { deviceId }
}

/// 应用主状态模型
@MainActor
final class AppModel: ObservableObject {
    /// 全局单例（AppDelegate / 窗口 / 菜单栏共享同一实例）
    static let shared = AppModel()

    enum Phase: Equatable {
        case loggedOut
        case connecting
        case ready
        case error(String)
    }

    @Published var phase: Phase = .loggedOut
    @Published var phone: String = ""
    @Published var password: String = ""
    @Published var devices: [DeviceInfo] = []
    @Published var attributes: [String: [String: DeviceAttribute]] = [:]  // deviceId -> attrName -> attr
    @Published var gatewayConnected = false
    /// 主题模式（跟随系统/浅色/深色），持久化
    @Published var themeMode: ThemeMode {
        didSet {
            UserDefaults.standard.set(themeMode.rawValue, forKey: "themeMode")
        }
    }

    // MARK: - 设备发现与手动添加

    /// 是否正在扫描局域网
    @Published var isDiscovering = false
    /// 最近一次发现结果
    @Published var discoveredDevices: [DiscoveredDevice] = []
    /// 手动添加的设备（持久化）
    @Published var manualDevices: [ManualDevice] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(manualDevices) {
                UserDefaults.standard.set(data, forKey: "manualDevices")
            }
        }
    }
    /// 开机自启开关（持久化）
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            applyLaunchAtLogin()
        }
    }

    // MARK: - 操作反馈（U4）

    /// 最近一次操作的结果提示（主窗口/菜单栏面板显示 toast）
    struct OperationNotice: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let isError: Bool
    }

    @Published var operationNotice: OperationNotice?
    /// 待确认的操作（发送后等待网关回读）
    private var pendingConfirm: (deviceId: String, name: String, expected: AttrValue)?

    // MARK: - 更新检查（G3）

    @Published var updateAvailable: (version: String, url: URL)?

    private var provider: (any DeviceProvider)?
    private var context: ProviderContext?
    private var gatewayHandle: (any GatewayHandle)?
    private var deviceIds: [String] = []
    /// 会话代数：logout 时自增；异步链写回前校验，防止登出后旧任务回写状态
    private var sessionGeneration = 0

    init() {
        let saved = UserDefaults.standard.string(forKey: "themeMode")
        themeMode = ThemeMode(rawValue: saved ?? "") ?? .system
        launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")

        if let data = UserDefaults.standard.data(forKey: "manualDevices"),
           let saved = try? JSONDecoder().decode([ManualDevice].self, from: data) {
            manualDevices = saved
        }
    }

    // MARK: - 生命周期

    /// 启动时恢复会话（由 AppDelegate 在应用启动完成时调用）
    func restoreSession() {
        guard provider == nil else { return }  // 防重入：已有会话则跳过
        // 一次性迁移：旧版本 Keychain 数据 → 文件存储（无弹窗方案）
        CredentialStore.migrateFromKeychainIfNeeded()
        guard let savedToken = CredentialStore.load(forKey: "accountToken"),
              let savedPhone = CredentialStore.load(forKey: "phone") else { return }
        phone = savedPhone
        let provider = HaierProvider()
        self.provider = provider
        self.context = ProviderContext(
            providerId: provider.providerId,
            account: savedPhone,
            token: savedToken,
            refreshToken: CredentialStore.load(forKey: "refreshToken")
        )
        phase = .connecting
        Task {
            // token 临近过期时先静默续期，避免启动即连不上
            await refreshTokenIfNeeded()
            await connectAndLoad()
        }
    }

    func login() async {
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPhone.isEmpty, !password.isEmpty else {
            phase = .error("请输入手机号和密码")
            return
        }
        phase = .connecting
        do {
            let provider = HaierProvider()
            let context = try await provider.login(account: trimmedPhone, password: password)
            self.provider = provider
            self.context = context
            saveCredentials(context, phone: trimmedPhone)
            password = ""
            await connectAndLoad()
        } catch {
            phase = .error(AppModel.classifyError(error))
        }
    }

    /// 持久化会话凭据（含过期时刻，用于自动刷新决策）
    private func saveCredentials(_ context: ProviderContext, phone: String) {
        CredentialStore.save(context.token, forKey: "accountToken")
        if let refresh = context.refreshToken {
            CredentialStore.save(refresh, forKey: "refreshToken")
        }
        CredentialStore.save(phone, forKey: "phone")
        if let expiresAt = context.tokenExpiresAt {
            UserDefaults.standard.set(expiresAt.timeIntervalSince1970, forKey: "tokenExpiresAt")
        }
    }

    /// token 临近过期/已过期时静默续期（主动刷新，避免 10 天到期必须重登）
    @discardableResult
    func refreshTokenIfNeeded() async -> Bool {
        guard provider != nil, let context else { return false }
        // 手动添加设备等场景下 context 可能无 refreshToken，跳过
        guard let token = context.refreshToken, !token.isEmpty else { return false }
        let saved = UserDefaults.standard.double(forKey: "tokenExpiresAt")
        let expiresAt = saved > 0 ? Date(timeIntervalSince1970: saved) : context.tokenExpiresAt
        guard TokenRefreshPolicy.shouldRefresh(expiresAt: expiresAt) else { return false }
        return await refreshToken(using: token)
    }

    /// 凭据失效（401/403）时强制用 refreshToken 续期一次；成功更新内存 + 持久化
    private func refreshTokenForced() async -> Bool {
        guard let context, let token = context.refreshToken, !token.isEmpty else { return false }
        return await refreshToken(using: token)
    }

    /// 用 refreshToken 换新 token；成功更新内存 + 持久化并返回 true
    private func refreshToken(using refresh: String) async -> Bool {
        guard let provider, let context else { return false }
        do {
            let newContext = try await provider.refresh(account: context.account, refreshToken: refresh)
            self.context = newContext
            saveCredentials(newContext, phone: context.account)
            AppLog.log("Token 自动刷新成功")
            return true
        } catch {
            AppLog.log("Token 自动刷新失败: \(error.localizedDescription)")
            return false
        }
    }

    private func connectAndLoad() async {
        await connectAndLoad(retryingOnCredentialFailure: true)
    }

    private func connectAndLoad(retryingOnCredentialFailure: Bool) async {
        // 会话代数：本次连接链路的身份标识；logout 后自增，旧链路不得再写回状态
        let generation = sessionGeneration
        do {
            guard let provider, let context else { throw HaierError.invalidResponse }
            let devices = try await provider.fetchDevices(context: context)
            guard generation == sessionGeneration else { return }  // 期间已登出
            self.devices = devices
            deviceIds = devices.map(\.deviceId)
            AppLog.log("设备列表: \(devices.map { $0.deviceName }.joined(separator: ", "))")

            // 拉取所有设备数字模型（初始快照）
            for device in devices {
                if let attrs = try? await provider.fetchDigitalModel(context: context, deviceId: device.id) {
                    AppLog.log("数字模型 \(device.id): \(attrs.count) 个属性")
                    var map: [String: DeviceAttribute] = [:]
                    for attr in attrs where !attr.name.isEmpty {
                        map[attr.name] = attr
                    }
                    attributes[device.id] = map
                } else {
                    AppLog.log("数字模型 \(device.id) 获取失败")
                }
            }

            // 连接实时网关
            let handle = try await provider.connectGateway(
                context: context,
                deviceIds: deviceIds,
                onConnected: { [weak self] in
                    AppLog.log("网关已连接")
                    Task { @MainActor in
                        guard let self else { return }
                        self.gatewayConnected = true
                        self.phase = .ready
                    }
                },
                onAttributes: { [weak self] deviceId, attrs in
                    AppLog.log("收到属性推送: \(deviceId) \(attrs.count) 个")
                    Task { @MainActor in
                        guard let self else { return }
                        var map = self.attributes[deviceId] ?? [:]
                        for (name, attr) in attrs {
                            map[name] = attr
                        }
                        self.attributes[deviceId] = map
                        self.confirmPendingIfNeeded(deviceId: deviceId, attrs: attrs)
                    }
                },
                onDisconnected: { [weak self] _ in
                    AppLog.log("网关断开")
                    Task { @MainActor in
                        self?.gatewayConnected = false
                        self?.failPendingOnDisconnect()
                    }
                }
            )
            guard generation == sessionGeneration else { return }  // 期间已登出
            self.gatewayHandle = handle
            handle.start()
            // 设备列表已就绪即可进入 ready（网关连接状态由 onConnected/onDisconnected 回调驱动）
            phase = .ready
        } catch {
            AppLog.log("连接失败: \(error.localizedDescription)")
            // 凭据失效：尝试用 refreshToken 强制续期一次后重连；仍失败才报错引导重登
            if retryingOnCredentialFailure, TokenRefreshPolicy.isCredentialError(error),
               await refreshTokenForced() {
                await connectAndLoad(retryingOnCredentialFailure: false)
            } else {
                phase = .error(AppModel.classifyError(error))
            }
        }
    }

    func logout() {
        sessionGeneration += 1  // 使所有进行中的异步链失效
        gatewayHandle?.stop()
        gatewayHandle = nil
        gatewayConnected = false
        CredentialStore.deleteAll()
        UserDefaults.standard.removeObject(forKey: "tokenExpiresAt")
        provider = nil
        context = nil
        devices = []
        attributes = [:]
        phone = ""
        phase = .loggedOut
    }

    // MARK: - 控制

    /// 发送属性控制指令（值是原始 JSON 类型），并给出操作反馈
    func sendAttribute(_ name: String, value: AttrValue, deviceId: String) {
        AppLog.log("sendAttribute: \(name)=\(value.stringValue) device=\(deviceId)")

        // 失效预案：网关未连接时明确提示，不静默失败
        guard gatewayConnected, let handle = gatewayHandle else {
            operationNotice = OperationNotice(text: "⚠️ 连接中断，指令未发送（自动重连中）", isError: true)
            return
        }

        handle.sendControl(deviceId: deviceId, attributes: [name: value.jsonValue]) { [weak self] sent in
            Task { @MainActor in
                guard let self else { return }
                if !sent {
                    self.operationNotice = OperationNotice(text: "⚠️ 指令发送失败，请稍后重试", isError: true)
                }
            }
        }
        // 乐观更新
        if var map = attributes[deviceId], let old = map[name] {
            map[name] = old.updating(value: value)
            attributes[deviceId] = map
        }

        // 操作反馈：显示属性中文名（如「情景灯光」）
        let desc = attributes[deviceId]?[name]?.desc ?? name
        operationNotice = OperationNotice(text: "已发送：\(desc)", isError: false)
        // 记录待确认项，等网关回读确认生效
        pendingConfirm = (deviceId, name, value)
    }

    /// 网关推送属性时调用：确认待生效操作
    private func confirmPendingIfNeeded(deviceId: String, attrs: [String: DeviceAttribute]) {
        guard let pending = pendingConfirm,
              pending.deviceId == deviceId,
              let pushed = attrs[pending.name],
              pushed.value == pending.expected else { return }
        pendingConfirm = nil
        let desc = attrs[pending.name]?.desc ?? pending.name
        operationNotice = OperationNotice(text: "✅ \(desc) 已生效", isError: false)
    }

    /// 网关断开时调用：未确认的操作标记失败
    private func failPendingOnDisconnect() {
        guard let pending = pendingConfirm else { return }
        pendingConfirm = nil
        let desc = attributes[pending.deviceId]?[pending.name]?.desc ?? pending.name
        operationNotice = OperationNotice(text: "⚠️ \(desc) 可能未生效（连接中断）", isError: true)
    }

    /// 检查 GitHub 是否有新版本（G3 失效预案）
    func checkForUpdates() async {
        guard let url = URL(string: "https://api.github.com/repos/bitterSmilezzz/haier-ac-mac/releases/latest") else { return }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0"
        request.setValue("HaierAC-Mac/\(appVersion)", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let htmlURL = json["html_url"] as? String,
              let latestURL = URL(string: htmlURL) else { return }
        let current = appVersion
        // tag 形如 "v1.2.1"，去掉 v 前缀比较
        let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        if latest.compare(current, options: .numeric) == .orderedDescending {
            updateAvailable = (latest, latestURL)
            AppLog.log("发现新版本: \(latest) -> \(latestURL)")
        }
    }

    /// 错误分类（G3 失效预案）：区分网络 / 账号 / 协议问题，协议类引导用户查看仓库
    static func classifyError(_ error: Error) -> String {
        if let haierError = error as? HaierError {
            switch haierError {
            case .network:
                return "网络连接失败，请检查网络后重试"
            case .http(let code) where code == 401 || code == 403:
                return "账号凭据失效，请退出后重新登录"
            case .retCode(let code, _) where code.contains("430"):
                return "账号登录异常（\(code)），请重新登录"
            case .retCode(let code, _):
                // 未知业务错误：可能是海尔协议已变更
                return "海尔云接口返回异常（\(code)）。\n若反复出现，可能是协议已变更，请到 GitHub 仓库查看更新：github.com/bitterSmilezzz/haier-ac-mac"
            default:
                return "请求失败：\(error.localizedDescription)"
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "网络连接失败，请检查网络后重试"
            case .timedOut:
                return "连接超时，请稍后重试"
            default:
                return "网络错误：\(urlError.localizedDescription)"
            }
        }
        return error.localizedDescription
    }

    func attribute(_ name: String, deviceId: String) -> DeviceAttribute? {
        attributes[deviceId]?[name]
    }

    var isLoggedIn: Bool {
        if case .ready = phase { return true }
        return false
    }

    // MARK: - 局域网发现

    /// 扫描当前 WiFi 下的海尔设备
    func discoverDevices() async {
        guard !isDiscovering else { return }
        isDiscovering = true
        discoveredDevices = []
        AppLog.log("开始局域网发现")
        let found = await DeviceDiscovery.discover(timeout: 3)
        discoveredDevices = found
        isDiscovering = false
        AppLog.log("发现 \(found.count) 台设备: \(found.map { "\($0.ip)/\($0.mac)" }.joined(separator: ", "))")
    }

    /// 将发现到的设备（或手动输入 deviceId）加入列表并尝试拉取数字模型
    func addDevice(deviceId: String, name: String) async {
        let trimmed = deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let generation = sessionGeneration
        // 已在云端列表？无需重复添加
        if devices.contains(where: { $0.id == trimmed }) {
            return
        }
        // 已在手动列表？仅更新名称
        if let idx = manualDevices.firstIndex(where: { $0.deviceId == trimmed }) {
            manualDevices[idx].name = name.isEmpty ? manualDevices[idx].name : name
            return
        }
        manualDevices.append(ManualDevice(deviceId: trimmed, name: name.isEmpty ? trimmed : name))
        // 尝试拉取数字模型（验证设备可访问）
        if let provider, let context {
            if let attrs = try? await provider.fetchDigitalModel(context: context, deviceId: trimmed) {
                guard generation == sessionGeneration else { return }  // 期间已登出
                var map: [String: DeviceAttribute] = [:]
                for attr in attrs where !attr.name.isEmpty {
                    map[attr.name] = attr
                }
                attributes[trimmed] = map
            }
        }
        // 同步网关订阅，让手动设备也能收到属性推送与控制确认
        resubscribeGatewayIfNeeded()
    }

    /// 从手动列表移除设备
    func removeManualDevice(_ device: ManualDevice) {
        manualDevices.removeAll { $0.deviceId == device.deviceId }
        attributes[device.deviceId] = nil
        resubscribeGatewayIfNeeded()
    }

    /// 用「云端 + 手动」全量设备列表刷新网关订阅
    private func resubscribeGatewayIfNeeded() {
        guard let handle = gatewayHandle else { return }
        let allIds = devices.map(\.id) + manualDevices.map(\.deviceId)
        deviceIds = allIds
        handle.updateSubscription(deviceIds: allIds)
    }

    // MARK: - 开机自启

    private func applyLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            AppLog.log("自启设置失败: \(error.localizedDescription)")
        }
    }
}
