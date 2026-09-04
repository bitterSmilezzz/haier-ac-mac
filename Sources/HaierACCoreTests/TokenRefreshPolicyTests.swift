import XCTest
@testable import HaierACCore

final class TokenRefreshPolicyTests: XCTestCase {
    // MARK: - shouldRefresh

    /// 未知过期时间（nil）：不主动刷新，靠 401 兜底
    func testNilExpiryNeverAutoRefresh() {
        XCTAssertFalse(TokenRefreshPolicy.shouldRefresh(expiresAt: nil))
    }

    /// 已过期：必须刷新
    func testExpiredMustRefresh() {
        let past = Date().addingTimeInterval(-60)
        XCTAssertTrue(TokenRefreshPolicy.shouldRefresh(expiresAt: past))
    }

    /// 恰好到阈值（12h）：刷新
    func testAtThresholdRefreshes() {
        let atThreshold = Date().addingTimeInterval(12 * 3600)
        XCTAssertTrue(TokenRefreshPolicy.shouldRefresh(expiresAt: atThreshold))
    }

    /// 阈值边缘（12h + 1s）：暂不刷新
    func testJustAboveThresholdDoesNotRefresh() {
        let soon = Date().addingTimeInterval(12 * 3600 + 1)
        XCTAssertFalse(TokenRefreshPolicy.shouldRefresh(expiresAt: soon))
    }

    /// 远期过期：不刷新
    func testFarFutureDoesNotRefresh() {
        let far = Date().addingTimeInterval(10 * 24 * 3600)
        XCTAssertFalse(TokenRefreshPolicy.shouldRefresh(expiresAt: far))
    }

    /// 自定义阈值生效
    func testCustomThreshold() {
        let expiresInOneHour = Date().addingTimeInterval(3600)
        XCTAssertTrue(TokenRefreshPolicy.shouldRefresh(expiresAt: expiresInOneHour, threshold: 2 * 3600))
        XCTAssertFalse(TokenRefreshPolicy.shouldRefresh(expiresAt: expiresInOneHour, threshold: 30 * 60))
    }

    /// 显式注入 now：时间敏感测试可重复
    func testExplicitNow() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let expiresAt = now.addingTimeInterval(3600)  // 距过期 1h
        XCTAssertTrue(TokenRefreshPolicy.shouldRefresh(expiresAt: expiresAt, now: now))
        XCTAssertFalse(TokenRefreshPolicy.shouldRefresh(expiresAt: expiresAt, now: now.addingTimeInterval(-13 * 3600)))
    }

    // MARK: - isCredentialError

    func testHttp401And403AreCredentialErrors() {
        XCTAssertTrue(TokenRefreshPolicy.isCredentialError(HaierError.http(401)))
        XCTAssertTrue(TokenRefreshPolicy.isCredentialError(HaierError.http(403)))
    }

    func testOtherHttpCodesAreNotCredentialErrors() {
        XCTAssertFalse(TokenRefreshPolicy.isCredentialError(HaierError.http(400)))
        XCTAssertFalse(TokenRefreshPolicy.isCredentialError(HaierError.http(500)))
        XCTAssertFalse(TokenRefreshPolicy.isCredentialError(HaierError.http(404)))
    }

    /// 业务码含 430/431/401/403 视为凭据失效
    func testRetCodesAreCredentialErrors() {
        XCTAssertTrue(TokenRefreshPolicy.isCredentialError(HaierError.retCode("43001", "登录态失效")))
        XCTAssertTrue(TokenRefreshPolicy.isCredentialError(HaierError.retCode("43102", "token 过期")))
        XCTAssertTrue(TokenRefreshPolicy.isCredentialError(HaierError.retCode("401", "unauthorized")))
    }

    func testOtherRetCodesAreNotCredentialErrors() {
        XCTAssertFalse(TokenRefreshPolicy.isCredentialError(HaierError.retCode("00000", "ok")))
        XCTAssertFalse(TokenRefreshPolicy.isCredentialError(HaierError.retCode("99999", "系统繁忙")))
    }

    func testNetworkAndParseErrorsAreNotCredentialErrors() {
        XCTAssertFalse(TokenRefreshPolicy.isCredentialError(HaierError.network(URLError(.notConnectedToInternet))))
        XCTAssertFalse(TokenRefreshPolicy.isCredentialError(HaierError.invalidResponse))
    }
}
