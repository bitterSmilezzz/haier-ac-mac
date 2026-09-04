import Foundation

/// 海尔智家 WebSocket 网关客户端
/// 职责：连接网关、订阅设备、发送控制指令、接收属性推送、心跳保活、断线重连
public final class HaierGatewayClient: NSObject, URLSessionWebSocketDelegate {
    private var session: URLSession!
    private var task: URLSessionWebSocketTask?
    private var heartbeatTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var gatewayURL: URL?
    private let token: String
    private let deviceIds: [String]
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
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    public func start(gatewayURL: URL) {
        stopped = false
        self.gatewayURL = gatewayURL
        connect()
    }

    public func stop() {
        stopped = true
        heartbeatTask?.cancel()
        reconnectTask?.cancel()
        task?.cancel()
        task = nil
    }

    // MARK: - 连接

    private func connect() {
        guard let gatewayURL, !stopped else { return }
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
        AppLog.log("WS 已连接 (didOpen)")
        isConnected = true
        subscribe()
        startHeartbeat()
        onConnected?()
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        AppLog.log("WS 关闭 closeCode=\(closeCode.rawValue)")
        handleDisconnect(nil)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            AppLog.log("WS 错误: \(error.localizedDescription)")
            handleDisconnect(error)
        }
    }

    // MARK: - 发送

    private func subscribe() {
        send(topic: "BoundDevs", content: ["devs": deviceIds])
    }

    public func sendControl(deviceId: String, attributes: [String: Any]) {
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
        send(topic: "BatchCmdReq", content: content)
    }

    private func send(topic: String, content: [String: Any]) {
        let payload: [String: Any] = [
            "agClientId": token,
            "topic": topic,
            "content": content,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let str = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(str)) { _ in }
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard !Task.isCancelled else { break }
                self?.send(topic: "HeartBeat", content: [
                    "sn": Self.randomString(32),
                    "duration": 0,
                ])
            }
        }
    }

    // MARK: - 接收

    private func receiveLoop(_ task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
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
                self.handleDisconnect(error)
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

    private func handleDisconnect(_ error: Error?) {
        isConnected = false
        task?.cancel()
        task = nil
        heartbeatTask?.cancel()
        onDisconnected?(error)
        guard !stopped else { return }
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard !Task.isCancelled else { return }
            self?.connect()
        }
    }

    public static func randomString(_ length: Int) -> String {
        let chars = "abcdef1234567890"
        return String((0..<length).map { _ in chars.randomElement()! })
    }
}
