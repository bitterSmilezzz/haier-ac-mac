import Foundation

/// 海尔智家 WebSocket 网关客户端
/// 职责：连接网关、订阅设备、发送控制指令、接收属性推送、心跳保活、断线重连
///
/// 连接代际模型：每次 connect() 新建的 URLSessionWebSocketTask 视为一代连接。
/// 所有 delegate 回调与 receiveLoop 都校验 `task === self.task`，旧一代连接的迟到
/// 回调（didClose/didComplete/receive failure）一律忽略，避免旧连接误杀新连接。
public final class HaierGatewayClient: NSObject, URLSessionWebSocketDelegate {
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var heartbeatTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempt = 0
    private let baseReconnectDelay: TimeInterval = 5
    private let maxReconnectDelay: TimeInterval = 120
    private var gatewayURL: URL?
    private let token: String
    private var deviceIds: [String]
    private var stopped = false

    public var onAttributes: ((String, [String: DeviceAttribute]) -> Void)?
    public var onDisconnected: ((Error?) -> Void)?
    public var onConnected: (() -> Void)?

    /// 当前是否已连接
    public private(set) var isConnected = false

    public init(token: String, deviceIds: [String]) {
        self.token = token
        self.deviceIds = deviceIds
        super.init()
    }

    deinit {
        session?.invalidateAndCancel()
    }

    public func start(gatewayURL: URL) {
        // stop() 后 session 已 invalidate 不可复用，这里总是重建
        session?.invalidateAndCancel()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        stopped = false
        self.gatewayURL = gatewayURL
        connect()
    }

    public func stop() {
        stopped = true
        isConnected = false
        heartbeatTask?.cancel()
        reconnectTask?.cancel()
        task?.cancel()
        task = nil
        session?.invalidateAndCancel()
        session = nil
    }

    /// 更新订阅设备列表（手动添加设备后调用；已连接时立即重新订阅）
    public func updateSubscription(deviceIds: [String]) {
        self.deviceIds = deviceIds
        guard isConnected, !stopped else { return }
        subscribe()
    }

    // MARK: - 连接

    private func connect() {
        guard let session, let gatewayURL, !stopped else { return }
        // 参考实现: '{server}/userag?token=..&agClientId=..'，必须保留 /userag 路径
        let urlString = gatewayURL.absoluteString + "/userag?token=\(token)&agClientId=\(token)"
        guard let url = URL(string: urlString) else { return }
        AppLog.log("WS 连接: \(gatewayURL.absoluteString)/userag (token 已脱敏)")

        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        receiveLoop(task)
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        // 只认当前代连接；stop 后到达的迟到 didOpen 直接忽略（防僵尸心跳）
        guard !stopped, webSocketTask === self.task else { return }
        AppLog.log("WS 已连接 (didOpen)")
        isConnected = true
        reconnectAttempt = 0  // 连接成功，重置退避计数
        subscribe()
        startHeartbeat()
        onConnected?()
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        guard webSocketTask === self.task else { return }  // 旧连接迟到回调，忽略
        AppLog.log("WS 关闭 closeCode=\(closeCode.rawValue)")
        handleDisconnect(nil, from: webSocketTask)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let wsTask = task as? URLSessionWebSocketTask, wsTask === self.task else { return }
        if let error {
            AppLog.log("WS 错误: \(error.localizedDescription)")
        }
        handleDisconnect(error, from: wsTask)
    }

    // MARK: - 发送

    private func subscribe() {
        send(topic: "BoundDevs", content: ["devs": deviceIds])
    }

    public func sendControl(deviceId: String, attributes: [String: Any], completion: ((Bool) -> Void)? = nil) {
        AppLog.log("发送控制: \(deviceId) \(attributes)")
        let sn = Self.randomString(32)
        let content: [String: Any] = [
            "trace": Self.randomString(32),
            "sn": sn,
            "data": [
                [
                    "sn": sn,
                    "index": 0,
                    "delaySeconds": 0,
                    "subSn": sn + ":0",
                    "deviceId": deviceId,
                    "cmdArgs": attributes,
                ]
            ],
        ]
        send(topic: "BatchCmdReq", content: content, completion: completion)
    }

    private func send(topic: String, content: [String: Any], completion: ((Bool) -> Void)? = nil) {
        let payload: [String: Any] = [
            "agClientId": token,
            "topic": topic,
            "content": content,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let str = String(data: data, encoding: .utf8),
              let task else {
            completion?(false)
            return
        }
        task.send(.string(str)) { error in
            completion?(error == nil)
        }
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard !Task.isCancelled, let self, !self.stopped, self.isConnected else { break }
                self.send(topic: "HeartBeat", content: [
                    "sn": Self.randomString(32),
                    "duration": 0,
                ]) { success in
                    // 心跳发送失败 = 链路已断，立即走断线重连流程（不等系统回调）
                    if !success, self.isConnected, !self.stopped {
                        self.handleDisconnect(URLError(.networkConnectionLost), from: self.task)
                    }
                }
            }
        }
    }

    // MARK: - 接收

    private func receiveLoop(_ task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                // 连接代际已切换（重连/停止）：不再处理旧连接的消息
                guard task === self.task else { return }
                switch message {
                case .string(let text):
                    self.handle(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handle(text)
                    }
                @unknown default:
                    break
                }
                self.receiveLoop(task)
            case .failure(let error):
                guard task === self.task else { return }
                self.handleDisconnect(error, from: task)
            }
        }
    }

    private func handle(_ text: String) {
        // 日志脱敏：消息中的 agClientId 即 token，不落盘
        let redacted = text.replacingOccurrences(of: token, with: "***")
        AppLog.log("WS 收到: \(redacted.prefix(160))")
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let topic = json["topic"] as? String

        if topic == "GenMsgDown", let content = json["content"] as? [String: Any],
           content["businType"] as? String == "DigitalModel",
           let parsed = Self.parseDigitalModel(content: content) {
            onAttributes?(parsed.deviceId, parsed.attributes)
        }
    }

    // MARK: - 解码

    struct DigitalModelData {
        let deviceId: String
        let attributes: [String: DeviceAttribute]
    }

    /// 解析 DigitalModel 下行数据（base64 -> JSON -> base64+zlib -> attributes）
    private static func parseDigitalModel(content: [String: Any]) -> DigitalModelData? {
        guard let dataB64 = content["data"] as? String,
              let data = Data(base64Encoded: dataB64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let deviceId = json["dev"] as? String,
              let argsB64 = json["args"] as? String,
              let argsData = Data(base64Encoded: argsB64),
              let inflated = Zlib.decompress(argsData),
              let args = try? JSONSerialization.jsonObject(with: inflated) as? [String: Any],
              let rawAttrs = args["attributes"] as? [[String: Any]] else {
            return nil
        }
        var result: [String: DeviceAttribute] = [:]
        for raw in rawAttrs {
            let attr = DeviceAttribute(json: raw)
            if !attr.name.isEmpty {
                result[attr.name] = attr
            }
        }
        return DigitalModelData(deviceId: deviceId, attributes: result)
    }

    // MARK: - 断开/重连

    /// 断线处理：只处理当前代连接；stop 后仅清理状态，不触发重连与回调
    private func handleDisconnect(_ error: Error?, from task: URLSessionWebSocketTask?) {
        guard let task, task === self.task else { return }  // 代际校验：旧连接迟到回调直接忽略
        isConnected = false
        self.task?.cancel()
        self.task = nil
        heartbeatTask?.cancel()
        onDisconnected?(error)
        guard !stopped else { return }
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            // 指数退避：5s → 10s → 20s → … → 120s 封顶；连接成功时重置（didOpen）
            let delay = min(self.baseReconnectDelay * pow(2, Double(self.reconnectAttempt)), self.maxReconnectDelay)
            self.reconnectAttempt += 1
            AppLog.log("WS 断线，\(Int(delay))s 后重连（第 \(self.reconnectAttempt) 次）")
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled, !self.stopped else { return }
            self.connect()
        }
    }

    public static func randomString(_ length: Int) -> String {
        let chars = "abcdef1234567890"
        return String((0..<length).map { _ in chars.randomElement()! })
    }
}
