import Foundation
import Darwin

/// 局域网发现到的设备（海尔 WiFi 模块，汉枫方案）
public struct DiscoveredDevice: Identifiable, Hashable {
    public let ip: String
    public let mac: String
    public let sn: String
    /// 若响应为 JSON 且含 deviceId（海尔云设备标识）
    public let deviceId: String?

    public var id: String { mac.isEmpty ? ip : mac }
}

/// 局域网设备发现：UDP 广播 HF-A11ASSISTHREAD（海尔/汉枫 WiFi 模块通用发现协议）
public enum DeviceDiscovery {
    /// 发现端口：48899 为标准汉枫发现端口，30000 为海尔 App 曾用端口，双发保险
    static let ports: [UInt16] = [48899, 30000]
    static let magic = "HF-A11ASSISTHREAD"

    /// 在当前局域网执行发现
    /// - Parameters:
    ///   - timeout: 监听时长（秒）
    ///   - interfaces: 可选，指定绑定的网卡名（如 "en0"），默认所有
    public static func discover(timeout: TimeInterval = 3, interface: String? = nil) async -> [DiscoveredDevice] {
        await Task.detached(priority: .userInitiated) {
            discoverSync(timeout: timeout, interface: interface)
        }.value
    }

    // MARK: - 同步实现（POSIX UDP）

    private static func discoverSync(timeout: TimeInterval, interface: String?) -> [DiscoveredDevice] {
        var devices: [String: DiscoveredDevice] = [:]

        // 创建广播 socket
        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { return [] }
        defer { close(fd) }

        // 允许广播
        var broadcast: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &broadcast, socklen_t(MemoryLayout<Int32>.size))
        // 允许端口复用（多网卡/多进程场景）
        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        // 绑定任意端口（发送/接收同一 socket）
        var localAddr = sockaddr_in()
        localAddr.sin_family = sa_family_t(AF_INET)
        localAddr.sin_port = 0
        localAddr.sin_addr.s_addr = INADDR_ANY
        let bindResult = withUnsafePointer(to: &localAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { return [] }

        // 设置接收超时
        var tv = timeval(tv_sec: Int(timeout), tv_usec: Int32((timeout - Double(Int(timeout))) * 1_000_000))
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        // 对每个端口发送广播指令
        for port in ports {
            var dest = sockaddr_in()
            dest.sin_family = sa_family_t(AF_INET)
            dest.sin_port = port.bigEndian
            dest.sin_addr.s_addr = inet_addr("255.255.255.255")

            let sent = withUnsafePointer(to: &dest) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(fd, magic, magic.utf8.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            _ = sent
        }

        // 接收响应直到超时
        let deadline = Date().addingTimeInterval(timeout)
        let bufferSize = 2048
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        while Date() < deadline {
            var from = sockaddr_in()
            var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = withUnsafeMutablePointer(to: &from) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(fd, &buffer, bufferSize, 0, $0, &fromLen)
                }
            }

            if n < 0 {
                // 超时或错误，结束
                break
            }
            guard n > 0 else { continue }

            let ip = String(cString: inet_ntoa(from.sin_addr))
            let raw = String(decoding: buffer[0..<n], as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let device = parseResponse(raw, ip: ip) {
                devices[device.id] = device
            }
        }

        return Array(devices.values)
    }

    // MARK: - 响应解析

    /// 解析模块响应：优先 JSON（可能含 deviceId），其次 "IP,MAC,SN" 逗号分隔
    private static func parseResponse(_ raw: String, ip: String) -> DiscoveredDevice? {
        // 1) JSON 格式（部分模块返回 {"deviceId":"...","moduleType":"...",...}）
        if let data = raw.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let deviceId = json["deviceId"] as? String
            let mac = (json["mac"] as? String) ?? (json["MAC"] as? String) ?? ""
            let sn = (json["sn"] as? String) ?? (json["SN"] as? String) ?? ""
            if deviceId != nil || !mac.isEmpty {
                return DiscoveredDevice(ip: ip, mac: mac, sn: sn, deviceId: deviceId)
            }
        }

        // 2) 逗号分隔：IP,MAC,SN（标准汉枫模块格式）
        let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count >= 2 {
            return DiscoveredDevice(
                ip: parts[0].isEmpty ? ip : parts[0],
                mac: parts.count > 1 ? parts[1] : "",
                sn: parts.count > 2 ? parts[2] : "",
                deviceId: nil
            )
        }

        // 3) 裸 IP 或未知格式：至少记录 IP
        if !raw.isEmpty && raw.contains(".") {
            return DiscoveredDevice(ip: ip, mac: "", sn: raw, deviceId: nil)
        }
        return nil
    }
}
