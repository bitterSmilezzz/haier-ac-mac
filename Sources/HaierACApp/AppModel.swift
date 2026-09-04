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

/// 本地调度任务（定时/倒计时）：到点后向指定设备发送属性指令
/// 注意：本地调度仅在 App 运行时生效（菜单栏常驻/开机自启时通常满足）；
/// 任务不落云端，App 退出/睡眠期间到点的任务会顺延到下次唤醒补发。
struct ScheduledAction: Identifiable, Codable, Hashable {
    var id = UUID()
    /// 显示名称（如「晚上 10 点关机」）
    var name: String
    var deviceId: String
    var attrName: String
    /// 属性显示名（UI 展示用）
    var attrDesc: String
    /// 属性值（JSON 编码，AttrValue 不可直接 Codable）
    var attrValueJSON: Data
    /// 触发时刻（绝对时间；daily 重复时为下一次触发时刻）
    var fireDate: Date
    /// 是否每天重复
    var repeatsDaily: Bool = false
    var enabled: Bool = true

    var attrValue: AttrValue? {
        guard let any = try? JSONSerialization.jsonObject(with: attrValueJSON) else { return nil }
        return AttrValue(any)
    }

    static func valueJSON(_ value: AttrValue) -> Data? {
        try? JSONSerialization.data(withJSONObject: value.jsonValue)
    }
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

    // MARK: - 菜单栏实时温度（v1.4）

    /// 是否在菜单栏图标旁显示当前温度（持久化）
    @Published var menuBarShowTemperature: Bool {
        didSet {
            UserDefaults.standard.set(menuBarShowTemperature, forKey: "menuBarShowTemperature")
        }
    }
    /// 菜单栏温度取自哪台设备（nil = 第一台设备）
    @Published var menuBarDeviceId: String?

    /// 识别“室内温度”属性：可读、数值型，且不是目标/设定温度。
    /// 优先名称含 indoor/室内/环境 的属性，否则回退任意温度类属性。
    static func indoorTemperatureAttribute(in attrs: [String: DeviceAttribute]) -> DeviceAttribute? {
        let tempAttrs = attrs.values.filter { attr in
            guard attr.readable, attr.value != nil, attr.doubleValue != nil else { return false }
            let n = attr.name.lowercased()
            let d = attr.desc.lowercased()
            // 排除目标温度/设定温度（target/set/目标/设定）
            let isTarget = n.contains("target") || n.contains("set") || d.contains("目标") || d.contains("设定")
            guard !isTarget else { return false }
            // 温度类：名称含 temp/temperature/温度/环境
            return n.contains("temp") || d.contains("温度") || d.contains("环境")
        }
        if tempAttrs.isEmpty { return nil }
        // 优先“室内/环境温度”
        if let indoor = tempAttrs.first(where: {
            let n = $0.name.lowercased()
            let d = $0.desc.lowercased()
            return n.contains("indoor") || n.contains("room") || d.contains("室内") || d.contains("环境")
        }) {
            return indoor
        }
        return tempAttrs.sorted { $0.desc < $1.desc }.first
    }

    /// 当前菜单栏温度文案（如 "26.0°"），无数据时返回 nil
    var menuBarTemperatureText: String? {
        guard menuBarShowTemperature, let deviceId = menuBarDeviceId ?? devices.first?.id,
              let attr = Self.indoorTemperatureAttribute(in: attributes[deviceId] ?? [:]),
              let value = attr.doubleValue else { return nil }
        return String(format: "%.0f°", value)
    }

    // MARK: - 本地调度（定时/倒计时，v1.4）

    /// 调度任务列表（持久化到 UserDefaults）
    @Published var scheduledActions: [ScheduledAction] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(scheduledActions) {
                UserDefaults.standard.set(data, forKey: "scheduledActions")
            }
        }
    }
    private var schedulerTask: Task<Void, Never>?

    /// 启动调度轮询（登录/恢复会话成功后调用；App 退出前持续运行）
    func startScheduler() {
        guard schedulerTask == nil else { return }
        if let data = UserDefaults.standard.data(forKey: "scheduledActions"),
           let saved = try? JSONDecoder().decode([ScheduledAction].self, from: data) {
            scheduledActions = saved
        }
        schedulerTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                self.fireDueActions()
                try? await Task.sleep(nanoseconds: 15_000_000_000)  // 15s 轮询
            }
        }
    }

    func stopScheduler() {
        schedulerTask?.cancel()
        schedulerTask = nil
    }

    /// 新增调度任务（fireDate 为绝对触发时刻；倒计时由调用方换算为 fireDate）
    func addScheduledAction(_ action: ScheduledAction) {
        // 去重：同设备同属性同触发时刻
        guard !scheduledActions.contains(where: {
            $0.deviceId == action.deviceId && $0.attrName == action.attrName && $0.fireDate == action.fireDate
        }) else { return }
        scheduledActions.append(action)
        AppLog.log("新增调度: \(action.name) @ \(action.fireDate)")
    }

    func removeScheduledAction(_ action: ScheduledAction) {
        scheduledActions.removeAll { $0.id == action.id }
    }

    /// 轮询检查：到点任务下发指令；每日重复任务自动顺延到下一天
    private func fireDueActions() {        let now = Date()
        let due = scheduledActions.filter { $0.enabled && $0.fireDate <= now }
        guard !due.isEmpty else { return }
        for action in due {
            guard let value = action.attrValue else { continue }
            AppLog.log("调度触发: \(action.name) -> \(action.deviceId).\(action.attrName)=\(value.stringValue)")
            // 静默下发（不走操作反馈 toast，避免轮询批量触发刷屏）
            gatewayHandle?.sendControl(deviceId: action.deviceId, attributes: [action.attrName: value.jsonValue], completion: nil)
            if action.repeatsDaily {
                // 顺延到下一个整点重复时刻（保留原时刻的时:分）
                var next = Calendar.current.date(byAdding: .day, value: 1, to: action.fireDate) ?? action.fireDate.addingTimeInterval(86400)
                // 若因应用长时间未运行导致积压多个周期，只补发一次、推进到最近未来
                while next <= now {
                    next = Calendar.current.date(byAdding: .day, value: 1, to: next) ?? next.addingTimeInterval(86400)
                }
                if let idx = scheduledActions.firstIndex(where: { $0.id == action.id }) {
                    scheduledActions[idx].fireDate = next
                }
            } else {
                scheduledActions.removeAll { $0.id == action.id }  // 一次性任务：触发后删除
            }
        }
    }

    // MARK: - 更新检查（G3）

    @Published var updateAvailable: (version: String, url: URL)?

    // MARK: - 情景模式（v1.4）

    /// 情景模式：一组「设备 → 属性 → 值」的组合，一键下发
    struct ScenePreset: Identifiable, Codable, Hashable {
        var id = UUID()
        var name: String
        var icon: String = "sparkles"
        /// 动作列表（deviceId → attrName → 值 JSON）
        var actions: [SceneAction]
    }

    struct SceneAction: Codable, Hashable {
        var deviceId: String
        var attrName: String
        var attrDesc: String
        var valueJSON: Data

        var value: AttrValue? {
            guard let any = try? JSONSerialization.jsonObject(with: valueJSON) else { return nil }
            return AttrValue(any)
        }
    }

    /// 情景模式列表（持久化）
    @Published var scenes: [ScenePreset] = [] {
        didSet {
            if let data = try? JSONEncoder().encode(scenes) {
                UserDefaults.standard.set(data, forKey: "scenes")
            }
        }
    }

    /// 首次启动写入内置默认情景
    private func seedDefaultScenesIfNeeded() {
        guard UserDefaults.standard.data(forKey: "scenes") == nil else { return }
        scenes = Self.defaultScenes
    }

    /// 内置默认情景（属性名为海尔数字模型通用名；设备不支持时静默跳过）
    static let defaultScenes: [ScenePreset] = [
        ScenePreset(name: "睡眠", icon: "moon.stars.fill", actions: [
            SceneAction(deviceId: "", attrName: "targetTemperature", attrDesc: "目标温度", valueJSON: try! JSONSerialization.data(withJSONObject: 26)),
            SceneAction(deviceId: "", attrName: "windSpeed", attrDesc: "风速", valueJSON: try! JSONSerialization.data(withJSONObject: "low")),
        ]),
        ScenePreset(name: "离家", icon: "house.fill", actions: [
            SceneAction(deviceId: "", attrName: "onOffStatus", attrDesc: "电源", valueJSON: try! JSONSerialization.data(withJSONObject: false)),
        ]),
        ScenePreset(name: "回家", icon: "house.and.flag.fill", actions: [
            SceneAction(deviceId: "", attrName: "onOffStatus", attrDesc: "电源", valueJSON: try! JSONSerialization.data(withJSONObject: true)),
            SceneAction(deviceId: "", attrName: "targetTemperature", attrDesc: "目标温度", valueJSON: try! JSONSerialization.data(withJSONObject: 24)),
        ]),
    ]

    /// 用当前选中设备的属性生成默认动作占位（由 UI 填充）
    func addScene(name: String, icon: String, actions: [SceneAction]) {
        scenes.append(ScenePreset(name: name, icon: icon, actions: actions))
        AppLog.log("新增情景: \(name) (\(actions.count) 个动作)")
    }

    func removeScene(_ scene: ScenePreset) {
        scenes.removeAll { $0.id == scene.id }
    }

    /// 一键应用情景：逐个下发动作（静默，不回 toast）。
    /// 动作 deviceId 为空时默认作用于第一台设备（可在 UI 中选目标设备）。
    func applyScene(_ scene: ScenePreset, targetDeviceId: String? = nil) {
        guard gatewayConnected else {
            operationNotice = OperationNotice(text: "⚠️ 连接中断，情景未应用", isError: true)
            return
        }
        let fallbackId = targetDeviceId ?? devices.first?.id
        var sent = 0
        for action in scene.actions {
            guard let value = action.value else { continue }
            let deviceId = action.deviceId.isEmpty ? (fallbackId ?? "") : action.deviceId
            guard !deviceId.isEmpty else { continue }
            gatewayHandle?.sendControl(deviceId: deviceId, attributes: [action.attrName: value.jsonValue], completion: nil)
            // 乐观更新
            if var map = attributes[deviceId], let old = map[action.attrName] {
                map[action.attrName] = old.updating(value: value)
                attributes[deviceId] = map
            }
            sent += 1
        }
        AppLog.log("应用情景: \(scene.name) (\(sent) 个动作)")
        operationNotice = OperationNotice(text: sent > 0 ? "✅ 情景「\(scene.name)」已下发（\(sent) 项）" : "⚠️ 情景「\(scene.name)」无可下发的动作", isError: sent == 0)
    }

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
        menuBarShowTemperature = UserDefaults.standard.object(forKey: "menuBarShowTemperature") as? Bool ?? true

        if let data = UserDefaults.standard.data(forKey: "manualDevices"),
           let saved = try? JSONDecoder().decode([ManualDevice].self, from: data) {
            manualDevices = saved
        }
        if let data = UserDefaults.standard.data(forKey: "scenes"),
           let saved = try? JSONDecoder().decode([ScenePreset].self, from: data) {
            scenes = saved
        } else {
            seedDefaultScenesIfNeeded()
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
        startScheduler()  // 登录态调度轮询（无论本次连接成功与否，任务列表可用）
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
            startScheduler()  // 登录成功：启动调度轮询
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
        stopScheduler()
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

    /// 批量下发同一指令到多台设备（v1.5）；返回值：成功下发的设备数
    @discardableResult
    func sendAttributeToDevices(_ name: String, value: AttrValue, deviceIds: [String]) -> Int {
        guard gatewayConnected, let handle = gatewayHandle else {
            operationNotice = OperationNotice(text: "⚠️ 连接中断，指令未发送（自动重连中）", isError: true)
            return 0
        }
        var sent = 0
        for deviceId in deviceIds {
            handle.sendControl(deviceId: deviceId, attributes: [name: value.jsonValue]) { [weak self] ok in
                if !ok {
                    Task { @MainActor in
                        self?.operationNotice = OperationNotice(text: "⚠️ 部分设备指令发送失败", isError: true)
                    }
                }
            }
            if var map = attributes[deviceId], let old = map[name] {
                map[name] = old.updating(value: value)
                attributes[deviceId] = map
            }
            sent += 1
        }
        let desc = attributes[deviceIds.first ?? ""]?[name]?.desc ?? name
        AppLog.log("批量下发: \(name)=\(value.stringValue) → \(deviceIds.count) 台设备")
        operationNotice = OperationNotice(text: "已发送：\(desc) → \(sent) 台设备", isError: false)
        return sent
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
