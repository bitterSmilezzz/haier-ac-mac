import Foundation

/// 设备提供商会话上下文：一次登录的凭据
public struct ProviderContext {
    public let providerId: String
    public let account: String
    public let token: String
    public let refreshToken: String?

    public init(providerId: String, account: String, token: String, refreshToken: String?) {
        self.providerId = providerId
        self.account = account
        self.token = token
        self.refreshToken = refreshToken
    }
}

/// 属性变更回调（网关推送）
public typealias AttributesCallback = (_ deviceId: String, _ attributes: [String: DeviceAttribute]) -> Void

/// 实时通道句柄：连接生命周期 + 指令发送
public protocol GatewayHandle: AnyObject {
    var isConnected: Bool { get }
    func start()
    func stop()
    func sendControl(deviceId: String, attributes: [String: Any])
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
