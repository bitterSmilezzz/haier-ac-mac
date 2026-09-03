import Foundation

public enum HaierError: LocalizedError {
    case retCode(String, String)
    case http(Int)
    case invalidResponse
    case network(Error)

    public var errorDescription: String? {
        switch self {
        case .retCode(let code, let info):
            return "接口错误 \(code): \(info)"
        case .http(let code):
            return "HTTP \(code)"
        case .invalidResponse:
            return "响应解析失败"
        case .network(let err):
            return err.localizedDescription
        }
    }
}

/// 海尔智家云 REST 客户端
public struct HaierCloudClient {
    public let clientId: String   // 手机号
    public let session: URLSession
    public var token: String = ""

    private static let loginURL = URL(string: "https://zj.haier.net/api-gw/oauthserver/account/v1/login")!
    private static let refreshURL = URL(string: "https://zj.haier.net/api-gw/oauthserver/account/v1/refreshToken")!
    private static let devicesURL = URL(string: "https://uws.haier.net/uds/v1/protected/deviceinfos")!
    private static let digitalModelURL = URL(string: "https://uws.haier.net/shadow/v1/devdigitalmodels")!
    private static let gatewayURL = URL(string: "https://uws.haier.net/gmsWS/wsag/assign")!

    public init(clientId: String, session: URLSession = .shared) {
        self.clientId = clientId
        self.session = session
    }

    // MARK: - 通用请求

    private func request(_ url: URL, method: String = "POST", body: [String: Any]? = nil) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30

        let bodyData: Data?
        if let body {
            bodyData = try JSONSerialization.data(withJSONObject: body)
        } else {
            bodyData = nil
        }
        let bodyString = bodyData.map { String(data: $0, encoding: .utf8) ?? "" } ?? ""
        request.allHTTPHeaderFields = RequestSigner.headers(url: url, body: bodyString, token: token, clientId: clientId)
        request.httpBody = bodyData

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw HaierError.network(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw HaierError.http(http.statusCode)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HaierError.invalidResponse
        }

        if let retCode = json["retCode"] as? String, retCode != "00000" {
            throw HaierError.retCode(retCode, json["retInfo"] as? String ?? "")
        }
        return json
    }

    // MARK: - 账号

    public func login(phone: String, password: String) async throws -> TokenInfo {
        var client = self
        client.token = ""
        let json = try await client.request(Self.loginURL, body: ["username": phone, "password": password])
        guard let data = json["data"] as? [String: Any],
              let tokenInfo = data["tokenInfo"] as? [String: Any],
              let accountToken = tokenInfo["accountToken"] as? String,
              let refreshToken = tokenInfo["refreshToken"] as? String,
              let expiresIn = tokenInfo["expiresIn"] as? Int else {
            throw HaierError.invalidResponse
        }
        return TokenInfo(accountToken: accountToken, refreshToken: refreshToken, expiresIn: expiresIn)
    }

    public func refreshToken(_ refreshToken: String) async throws -> TokenInfo {
        let json = try await request(Self.refreshURL, body: ["refreshToken": refreshToken])
        guard let data = json["data"] as? [String: Any],
              let tokenInfo = data["tokenInfo"] as? [String: Any],
              let accountToken = tokenInfo["accountToken"] as? String,
              let refreshToken = tokenInfo["refreshToken"] as? String,
              let expiresIn = tokenInfo["expiresIn"] as? Int else {
            throw HaierError.invalidResponse
        }
        return TokenInfo(accountToken: accountToken, refreshToken: refreshToken, expiresIn: expiresIn)
    }

    // MARK: - 设备

    public func getDevices() async throws -> [DeviceInfo] {
        let json = try await request(Self.devicesURL, method: "GET")
        guard let rawList = json["deviceinfos"] as? [[String: Any]] else {
            throw HaierError.invalidResponse
        }
        return rawList.map { raw in
            DeviceInfo(
                deviceId: raw["deviceId"] as? String ?? "",
                deviceName: raw["deviceName"] as? String ?? "",
                deviceType: raw["deviceType"] as? String,
                productNameT: raw["productNameT"] as? String,
                online: raw["online"] as? Bool ?? false
            )
        }
    }

    /// 获取设备数字模型（属性定义 + 当前值）
    public func getDigitalModel(deviceId: String) async throws -> [DeviceAttribute] {
        let json = try await request(
            Self.digitalModelURL,
            body: ["deviceInfoList": [["deviceId": deviceId]]]
        )
        guard let detail = json["detailInfo"] as? [String: Any],
              let raw = detail[deviceId] as? String,
              let model = DigitalModel(detailJsonString: raw) else {
            throw HaierError.invalidResponse
        }
        return model.attributes
    }

    /// 获取 WebSocket 网关地址
    public func getGateway() async throws -> URL {
        let json = try await request(Self.gatewayURL, body: ["clientId": clientId, "token": token])
        guard let addr = json["agAddr"] as? String,
              let url = URL(string: addr.replacingOccurrences(of: "http://", with: "wss://")) else {
            throw HaierError.invalidResponse
        }
        return url
    }
}
