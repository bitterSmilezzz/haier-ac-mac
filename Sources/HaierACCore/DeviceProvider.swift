import Foundation

/// 设备提供商会话上下文：一次登录的凭据
public struct ProviderContext {
    public let providerId: String
    public let account: String
    public let token: String
    public let refreshToken: String?
    /// token 过期时刻（由登录/刷新响应的 expiresIn 计算）；nil 表示未知（视为不过期，靠 401 兜底）
    public let tokenExpiresAt: Date?

    public init(providerId: String, account: String, token: String, refreshToken: String?, tokenExpiresAt: Date? = nil) {
        self.providerId = providerId
        self.account = account
        self.token = token
        self.refreshToken = refreshToken
        self.tokenExpiresAt = tokenExpiresAt
    }
}

/// Token 刷新决策（纯函数，便于单测）
public enum TokenRefreshPolicy {
    /// 距过期不足阈值时应主动刷新。expiresAt 为 nil（未知）时不主动刷新，靠 401 兜底。
    public static func shouldRefresh(expiresAt: Date?, now: Date = Date(), threshold: TimeInterval = 12 * 3600) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt.timeIntervalSince(now) <= threshold
    }

    /// 判断错误是否属于"凭据失效"（HTTP 401/403 或业务码 430/431 等），可触发刷新重试
    public static func isCredentialError(_ error: Error) -> Bool {
        if let haierError = error as? HaierError {
            switch haierError {
            case .http(let code):
                return code == 401 || code == 403
            case .retCode(let code, _):
                return code.contains("430") || code.contains("431") || code.contains("401") || code.contains("403")
            default:
                return false
            }
        }
        return false
    }
}

/// 属性变更回调（网关推送）
public typealias AttributesCallback = (_ deviceId: String, _ attributes: [String: DeviceAttribute]) -> Void

/// 实时通道句柄：连接生命周期 + 指令发送
public protocol GatewayHandle: AnyObject {
    var isConnected: Bool { get }
    func start()
    func stop()
    /// 发送控制指令；completion 报告底层是否发送成功（不代表设备已生效）
    func sendControl(deviceId: String, attributes: [String: Any], completion: ((Bool) -> Void)?)
    /// 更新订阅设备列表（手动添加设备后调用）
    func updateSubscription(deviceIds: [String])
}

/// 设备提供商协议：所有品牌（海尔/华为/米家…）接入的抽象接口。
/// 新增品牌时实现本协议并在 ProviderRegistry 注册，业务层无需改动。
public protocol DeviceProvider {
    /// 提供商唯一标识
    var providerId: String { get }

    /// 登录并返回会话上下文
    func login(account: String, password: String) async throws -> ProviderContext

    /// 用 refreshToken 刷新会话（account 用于构造客户端）
    func refresh(account: String, refreshToken: String) async throws -> ProviderContext

    /// 获取设备列表
    func fetchDevices(context: ProviderContext) async throws -> [DeviceInfo]

    /// 获取设备数字模型（属性定义 + 当前值）
    func fetchDigitalModel(context: ProviderContext, deviceId: String) async throws -> [DeviceAttribute]

    /// 建立实时通道（订阅属性推送），返回网关句柄
    func connectGateway(
        context: ProviderContext,
        deviceIds: [String],
        onConnected: @escaping () -> Void,
        onAttributes: @escaping AttributesCallback,
        onDisconnected: @escaping (Error?) -> Void
    ) async throws -> any GatewayHandle
}

/// 提供商注册表：按 providerId 查找实现
public enum ProviderRegistry {
    private static var providers: [String: any DeviceProvider] = [:]

    public static func register(_ provider: any DeviceProvider) {
        providers[provider.providerId] = provider
    }

    public static func provider(_ providerId: String) -> (any DeviceProvider)? {
        providers[providerId]
    }

    public static func allProviders() -> [(any DeviceProvider)] {
        Array(providers.values)
    }
}
