import Foundation
import Network
import CoreWLAN
import UserNotifications
import HaierACCore

/// Wi-Fi 网络与离家/回家感知守护器 (v1.9.20)
@MainActor
public final class NetworkPresenceGuard: ObservableObject {
    public static let shared = NetworkPresenceGuard()

    /// 是否开启离家未关机守护提醒
    @Published public var isGuardEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(isGuardEnabled, forKey: "homePresenceGuardEnabled")
        }
    }

    /// 用户绑定的家庭网络名称 (SSID 或自定义标签)
    @Published public var homeNetworkName: String = "我的家庭 Wi-Fi" {
        didSet {
            UserDefaults.standard.set(homeNetworkName, forKey: "homeNetworkNameKey")
        }
    }

    /// 当前是否处于家庭网络环境
    @Published public private(set) var isConnectedToHome: Bool = true

    /// 当前检测到的网络描述
    @Published public private(set) var currentNetworkStatusDesc: String = "已连接"

    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "local.haierac.networkpresence")
    private var lastDisconnectionCheck: Date?
    private var pendingAlertTask: Task<Void, Never>?

    private init() {
        self.isGuardEnabled = UserDefaults.standard.object(forKey: "homePresenceGuardEnabled") as? Bool ?? true
        if let savedName = UserDefaults.standard.string(forKey: "homeNetworkNameKey"), !savedName.isEmpty {
            self.homeNetworkName = savedName
        }
        setupPathMonitoring()
    }

    /// 获取当前 Mac 物理 Wi-Fi 的 SSID（若权限受限则返回接口状态）
    public func detectCurrentWiFiSSID() -> String? {
        if let iface = CWWiFiClient.shared().interface(), let ssid = iface.ssid(), !ssid.isEmpty {
            return ssid
        }
        return nil
    }

    /// 一键将当前所连网络绑定为家庭网络
    public func bindCurrentNetworkAsHome() {
        if let currentSSID = detectCurrentWiFiSSID() {
            homeNetworkName = currentSSID
        } else {
            homeNetworkName = "默认家庭网络"
        }
        isConnectedToHome = true
        AppLog.log("离家守护: 已绑定家庭网络为「\(homeNetworkName)」")
    }

    // MARK: - 网络监听与防空转判定

    private func setupPathMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    private func handlePathUpdate(_ path: NWPath) {
        let isConnected = path.status == .satisfied
        let isWiFi = path.usesInterfaceType(.wifi)

        let detectedSSID = detectCurrentWiFiSSID()

        if !isConnected {
            currentNetworkStatusDesc = "网络已断开"
            onNetworkStateChanged(inHome: false)
        } else if isWiFi {
            if let ssid = detectedSSID {
                currentNetworkStatusDesc = "Wi-Fi: \(ssid)"
                let match = (ssid == homeNetworkName)
                onNetworkStateChanged(inHome: match)
            } else {
                currentNetworkStatusDesc = "Wi-Fi 已连接"
                // 权限保护下若未暴露 SSID，保持当前判定
            }
        } else {
            currentNetworkStatusDesc = "有线网络/蜂窝热点"
            // 非家庭 Wi-Fi 环境
            onNetworkStateChanged(inHome: false)
        }
    }

    private func onNetworkStateChanged(inHome: Bool) {
        let previous = self.isConnectedToHome
        self.isConnectedToHome = inHome

        guard isGuardEnabled else { return }

        // 由在家 -> 离家/断网
        if previous && !inHome {
            scheduleLeaveHomeCheck()
        } else if !previous && inHome {
            pendingAlertTask?.cancel()
            AppLog.log("网络守护: 检测到已返回家庭网络「\(homeNetworkName)」")
        }
    }

    /// 离家延时防抖确认（断网 15 秒后若仍未恢复且空调开机，则发送警报）
    private func scheduleLeaveHomeCheck() {
        pendingAlertTask?.cancel()
        pendingAlertTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 15_000_000_000) // 15秒防抖
            if Task.isCancelled { return }

            guard !self.isConnectedToHome else { return }
            self.triggerLeaveHomeAlertIfNeeded()
        }
    }

    /// 触发离家空调防空转提醒
    private func triggerLeaveHomeAlertIfNeeded() {
        let model = AppModel.shared
        let deviceId = model.devices.first?.id ?? model.manualDevices.first?.deviceId
        guard let deviceId = deviceId else { return }
        let deviceName = model.devices.first?.deviceName ?? model.manualDevices.first?.name ?? "海尔空调"
        let isPowerOn = model.attribute("onOffStatus", deviceId: deviceId)?.boolValue ?? false

        guard isPowerOn else { return }

        let targetTemp = model.attribute("targetTemperature", deviceId: deviceId)?.doubleValue ?? 26.0
        let tempText = String(format: "%.0f°C", targetTemp)

        AppLog.log("⚠️ 离家防空转守护触发: 检测到已离开家庭网络，空调仍在开机运行 (\(tempText))")

        let content = UNMutableNotificationContent()
        content.title = "⚠️ 离家防空转提醒"
        content.body = "检测到您已离开家庭网络，\(deviceName) 仍在运行中（设定 \(tempText)）。如已出门请及时关机以防浪费电量。"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "leave-home-guard-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
