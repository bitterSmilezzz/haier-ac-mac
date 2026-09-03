import Foundation

/// 凭据存储（文件方案）
///
/// 为什么不用 Keychain：本应用使用 ad-hoc 签名（个人项目每次打包重新签名），
/// macOS 钥匙串对未签名/匿名签名的调用者即使 ACL 无限制也会反复弹出密码框。
/// 改用应用支持目录下的 600 权限文件（仅当前用户可读写），彻底消除弹窗。
///
/// 安全说明：存储的是短期访问令牌（10 天有效，可随时刷新/撤销），
/// 密码本身从不落盘；文件权限 600 + 系统全盘加密（FileVault 开启时）提供基础保护。
public enum CredentialStore {
    /// 文件路径：~/Library/Application Support/HaierAC/credentials.json
    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("HaierAC/credentials.json", isDirectory: false)
    }

    private struct Credentials: Codable {
        var accountToken: String?
        var refreshToken: String?
        var phone: String?
    }

    private static var cache: Credentials?

    private static func loadFromDisk() -> Credentials {
        if let cache {
            return cache
        }
        guard let data = try? Data(contentsOf: fileURL),
              let creds = try? JSONDecoder().decode(Credentials.self, from: data) else {
            return Credentials()
        }
        cache = creds
        return creds
    }

    private static func saveToDisk(_ creds: Credentials) {
        cache = creds
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(creds)
            try data.write(to: fileURL, options: .atomic)
            // 权限 600：仅当前用户可读写
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        } catch {
            print("CredentialStore 写入失败: \(error)")
        }
    }

    // MARK: - 公开接口

    public static func save(_ value: String, forKey key: String) {
        var creds = loadFromDisk()
        switch key {
        case "accountToken": creds.accountToken = value
        case "refreshToken": creds.refreshToken = value
        case "phone": creds.phone = value
        default: break
        }
        saveToDisk(creds)
    }

    public static func load(forKey key: String) -> String? {
        let creds = loadFromDisk()
        switch key {
        case "accountToken": return creds.accountToken
        case "refreshToken": return creds.refreshToken
        case "phone": return creds.phone
        default: return nil
        }
    }

    public static func delete(forKey key: String) {
        var creds = loadFromDisk()
        switch key {
        case "accountToken": creds.accountToken = nil
        case "refreshToken": creds.refreshToken = nil
        case "phone": creds.phone = nil
        default: break
        }
        saveToDisk(creds)
    }

    /// 删除全部凭据（登出）
    public static func deleteAll() {
        cache = Credentials()
        try? FileManager.default.removeItem(at: fileURL)
    }
}
