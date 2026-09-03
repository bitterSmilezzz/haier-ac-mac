import Foundation

/// 设备属性值的原始类型（与服务器 JSON 类型保持一致，控制时原样回传）
public enum AttrValue: Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    public init(_ jsonValue: Any) {
        switch jsonValue {
        case let s as String: self = .string(s)
        case let b as Bool: self = .bool(b)
        case let n as NSNumber:
            // 区分 Int / Double
            if CFNumberGetType(n as CFNumber) == .charType {
                self = .bool(n.boolValue)
            } else if n.doubleValue == n.doubleValue.rounded() && abs(n.doubleValue) < 1e15 {
                self = .int(n.intValue)
            } else {
                self = .double(n.doubleValue)
            }
        default: self = .null
        }
    }

    public var stringValue: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .bool(let b): return b ? "true" : "false"
        case .null: return ""
        }
    }

    public var jsonValue: Any {
        switch self {
        case .string(let s): return s
        case .int(let i): return i
        case .double(let d): return d
        case .bool(let b): return b
        case .null: return NSNull()
        }
    }
}

public struct TokenInfo: Codable {
    public let accountToken: String
    public let refreshToken: String
    public let expiresIn: Int

    public init(accountToken: String, refreshToken: String, expiresIn: Int) {
        self.accountToken = accountToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
    }
}

public struct DeviceInfo: Identifiable, Hashable {
    public let deviceId: String
    public let deviceName: String
    public let deviceType: String?
    public let productNameT: String?
    public let online: Bool

    public var id: String { deviceId }

    public init(deviceId: String, deviceName: String, deviceType: String?, productNameT: String?, online: Bool) {
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.deviceType = deviceType
        self.productNameT = productNameT
        self.online = online
    }
}

/// LIST 类型属性的一个选项
public struct ListOption: Identifiable, Hashable {
    public let data: AttrValue
    public let desc: String
    public var id: String { "\(data.stringValue)|\(desc)" }

    public init(data: AttrValue, desc: String) {
        self.data = data
        self.desc = desc
    }
}

/// 属性取值范围
public enum AttributeValueRange: Hashable {
    case step(min: Double, max: Double, step: Double)
    case list([ListOption])
}

/// 设备数字模型中的一个属性
public struct DeviceAttribute: Identifiable, Hashable {
    public let name: String
    public let desc: String
    public let value: AttrValue?
    public let readable: Bool
    public let writable: Bool
    public let valueRange: AttributeValueRange?

    public var id: String { name }

    public var isBinarySwitch: Bool {
        guard case .list(let opts) = valueRange, opts.count == 2 else { return false }
        let vals = opts.map { $0.data.stringValue.lowercased() }
        return vals.contains("true") && vals.contains("false")
    }

    public var boolValue: Bool? {
        guard let value else { return nil }
        switch value {
        case .bool(let b): return b
        case .string(let s): return s.lowercased() == "true"
        case .int(let i): return i != 0
        default: return nil
        }
    }

    public var doubleValue: Double? {
        guard let value else { return nil }
        switch value {
        case .double(let d): return d
        case .int(let i): return Double(i)
        case .string(let s): return Double(s)
        default: return nil
        }
    }

    /// 灯光/屏显相关属性（UI 置顶显示）
    public var isLightRelated: Bool {
        let d = desc.lowercased()
        let n = name.lowercased()
        return d.contains("灯光") || d.contains("亮度") || d.contains("背光") || d.contains("屏显")
            || n.contains("light") || n.contains("brightness") || n.contains("backlight") || n.contains("screen")
    }

    /// 返回更新 value 后的副本（用于乐观更新）
    public func updating(value newValue: AttrValue) -> DeviceAttribute {
        DeviceAttribute(name: name, desc: desc, value: newValue, readable: readable, writable: writable, valueRange: valueRange)
    }

    public init(name: String, desc: String, value: AttrValue?, readable: Bool, writable: Bool, valueRange: AttributeValueRange?) {
        self.name = name
        self.desc = desc
        self.value = value
        self.readable = readable
        self.writable = writable
        self.valueRange = valueRange
    }

    public init(json: [String: Any]) {
        self.name = json["name"] as? String ?? ""
        self.desc = json["desc"] as? String ?? ""
        self.readable = json["readable"] as? Bool ?? false
        self.writable = json["writable"] as? Bool ?? false
        self.value = json["value"].map(AttrValue.init)

        if let vr = json["valueRange"] as? [String: Any] {
            let type = (vr["type"] as? String)?.lowercased()
            if type == "step", let ds = vr["dataStep"] as? [String: Any] {
                let toDouble: (Any?) -> Double? = {
                    switch $0 {
                    case let s as String: return Double(s)
                    case let n as NSNumber: return n.doubleValue
                    default: return nil
                    }
                }
                if let minV = toDouble(ds["minValue"]), let maxV = toDouble(ds["maxValue"]) {
                    let stepV = toDouble(ds["step"]) ?? 1
                    self.valueRange = .step(min: minV, max: maxV, step: stepV)
                } else {
                    self.valueRange = nil
                }
            } else if type == "list", let dl = vr["dataList"] as? [[String: Any]] {
                let options = dl.map { item -> ListOption in
                    ListOption(data: AttrValue(item["data"] as Any), desc: item["desc"] as? String ?? "")
                }
                self.valueRange = .list(options)
            } else {
                self.valueRange = nil
            }
        } else {
            self.valueRange = nil
        }
    }
}

/// 数字模型响应：detailInfo[deviceId] 是 JSON 字符串
public struct DigitalModel {
    public let attributes: [DeviceAttribute]

    public init?(detailJsonString: String) {
        guard let data = detailJsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawAttrs = obj["attributes"] as? [[String: Any]] else {
            return nil
        }
        self.attributes = rawAttrs.map { DeviceAttribute(json: $0) }
    }
}
