import Foundation
import Combine
import SwiftUI
import HaierACCore

/// 应用主状态模型
@MainActor
final class AppModel: ObservableObject {
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

    private var client: HaierCloudClient?
    private var gateway: HaierGatewayClient?
    private var tokenInfo: TokenInfo?
    private var deviceIds: [String] = []

    init() {
        let saved = UserDefaults.standard.string(forKey: "themeMode")
        themeMode = ThemeMode(rawValue: saved ?? "") ?? .system
    }

    // MARK: - 生命周期

    func restoreSession() {
        guard let savedToken = KeychainStore.load(forKey: "accountToken"),
              let savedPhone = KeychainStore.load(forKey: "phone") else { return }
        phone = savedPhone
        client = HaierCloudClient(clientId: savedPhone)
        client?.token = savedToken
        tokenInfo = nil
        phase = .connecting
        Task {
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
            var client = HaierCloudClient(clientId: trimmedPhone)
            let info = try await client.login(phone: trimmedPhone, password: password)
            AppLog.log("登录成功 expiresIn=\(info.expiresIn)")
            client.token = info.accountToken
            self.client = client
            tokenInfo = info
            KeychainStore.save(info.accountToken, forKey: "accountToken")
            KeychainStore.save(info.refreshToken, forKey: "refreshToken")
            KeychainStore.save(trimmedPhone, forKey: "phone")
            password = ""
            await connectAndLoad()
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func logout() {
        gateway?.stop()
        gateway = nil
        KeychainStore.delete(forKey: "accountToken")
        KeychainStore.delete(forKey: "refreshToken")
        KeychainStore.delete(forKey: "phone")
        devices = []
        attributes = [:]
        phone = ""
        phase = .loggedOut
    }

    private func connectAndLoad() async {
        do {
            guard let client else { throw HaierError.invalidResponse }
            let devices = try await client.getDevices()
            self.devices = devices
            deviceIds = devices.map(\.deviceId)
            AppLog.log("设备列表: \(devices.map { $0.deviceName }.joined(separator: ", "))")

            // 拉取所有设备数字模型（初始快照）
            for device in devices {
                if let attrs = try? await client.getDigitalModel(deviceId: device.id) {
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
            let gatewayURL = try await client.getGateway()
            AppLog.log("网关地址: \(gatewayURL.absoluteString)")
            let gateway = HaierGatewayClient(token: client.token, deviceIds: deviceIds)
            self.gateway = gateway
            gateway.onAttributes = { [weak self] deviceId, attrs in
                AppLog.log("收到属性推送: \(deviceId) \(attrs.count) 个")
                Task { @MainActor in
                    guard let self else { return }
                    var map = self.attributes[deviceId] ?? [:]
                    for (name, attr) in attrs {
                        map[name] = attr
                    }
                    self.attributes[deviceId] = map
                }
            }
            gateway.onDisconnected = { [weak self] _ in
                AppLog.log("网关断开")
                Task { @MainActor in
                    self?.gatewayConnected = false
                }
            }
            gateway.start(gatewayURL: gatewayURL)
            gatewayConnected = true
            phase = .ready
        } catch {
            AppLog.log("连接失败: \(error.localizedDescription)")
            phase = .error(error.localizedDescription)
        }
    }

    // MARK: - 控制

    /// 发送属性控制指令（值是原始 JSON 类型）
    func sendAttribute(_ name: String, value: AttrValue, deviceId: String) {
        AppLog.log("sendAttribute: \(name)=\(value.stringValue) device=\(deviceId)")
        gateway?.sendControl(deviceId: deviceId, attributes: [name: value.jsonValue])
        // 乐观更新
        if var map = attributes[deviceId], let old = map[name] {
            map[name] = old.updating(value: value)
            attributes[deviceId] = map
        }
    }

    func attribute(_ name: String, deviceId: String) -> DeviceAttribute? {
        attributes[deviceId]?[name]
    }

    var isLoggedIn: Bool {
        if case .ready = phase { return true }
        return false
    }
}
