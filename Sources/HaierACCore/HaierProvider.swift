import Foundation

/// 海尔智家提供商：实现 DeviceProvider 协议
public struct HaierProvider: DeviceProvider {
    public let providerId = "haier"

    public init() {}

    public func login(account: String, password: String) async throws -> ProviderContext {
        var client = HaierCloudClient(clientId: account)
        let info = try await client.login(phone: account, password: password)
        client.token = info.accountToken
        return ProviderContext(
            providerId: providerId,
            account: account,
            token: info.accountToken,
            refreshToken: info.refreshToken,
            tokenExpiresAt: Date().addingTimeInterval(TimeInterval(info.expiresIn))
        )
    }

    public func refresh(account: String, refreshToken: String) async throws -> ProviderContext {
        var client = HaierCloudClient(clientId: account)
        let info = try await client.refreshToken(refreshToken)
        client.token = info.accountToken
        return ProviderContext(
            providerId: providerId,
            account: account,
            token: info.accountToken,
            refreshToken: info.refreshToken,
            tokenExpiresAt: Date().addingTimeInterval(TimeInterval(info.expiresIn))
        )
    }

    public func fetchDevices(context: ProviderContext) async throws -> [DeviceInfo] {
        var client = HaierCloudClient(clientId: context.account)
        client.token = context.token
        return try await client.getDevices()
    }

    public func fetchDigitalModel(context: ProviderContext, deviceId: String) async throws -> [DeviceAttribute] {
        var client = HaierCloudClient(clientId: context.account)
        client.token = context.token
        return try await client.getDigitalModel(deviceId: deviceId)
    }

    public func connectGateway(
        context: ProviderContext,
        deviceIds: [String],
        onConnected: @escaping () -> Void,
        onAttributes: @escaping AttributesCallback,
        onDisconnected: @escaping (Error?) -> Void
    ) async throws -> any GatewayHandle {
        var client = HaierCloudClient(clientId: context.account)
        client.token = context.token
        let gatewayURL = try await client.getGateway()
        let gateway = HaierGatewayClient(token: context.token, deviceIds: deviceIds)
        gateway.onConnected = onConnected
        gateway.onAttributes = onAttributes
        gateway.onDisconnected = onDisconnected
        return HaierGatewayHandle(gateway: gateway, url: gatewayURL)
    }
}

/// 海尔网关句柄：适配 GatewayHandle 协议
public final class HaierGatewayHandle: GatewayHandle {
    let gateway: HaierGatewayClient
    private let url: URL

    public var isConnected: Bool { gateway.isConnected }

    init(gateway: HaierGatewayClient, url: URL) {
        self.gateway = gateway
        self.url = url
    }

    deinit {
        gateway.stop()
    }

    public func start() {
        gateway.start(gatewayURL: url)
    }

    public func stop() {
        gateway.stop()
    }

    public func sendControl(deviceId: String, attributes: [String: Any], completion: ((Bool) -> Void)? = nil) {
        gateway.sendControl(deviceId: deviceId, attributes: attributes, completion: completion)
    }

    public func updateSubscription(deviceIds: [String]) {
        gateway.updateSubscription(deviceIds: deviceIds)
    }
}
