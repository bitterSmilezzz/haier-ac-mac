import Foundation
import Security

/// Keychain 凭据存储（token 持久化，密码不落盘）
///
/// 注意：条目使用「无限制 ACL」（不绑定应用签名）。
/// 原因：本应用为个人项目，每次重新打包都会生成新的 ad-hoc 签名，
/// 若 ACL 绑定签名，重启应用就会反复弹出钥匙串授权框。
/// 无限制 ACL 在个人电脑场景下风险可控（token 10 天有效，非主密码）。
public enum KeychainStore {
    private static let service = "local.haierac.token"

    public static func save(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        // 无限制 ACL：空信任列表 = 不绑定任何应用签名
        var access: SecAccess?
        let status = SecAccessCreate("HaierAC" as CFString, [] as CFArray, &access)
        if status == errSecSuccess, let access {
            addQuery[kSecAttrAccess as String] = access
        }

        SecItemAdd(addQuery as CFDictionary, nil)
    }

    public static func load(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// 将已有条目迁移为无限制 ACL（读取后调用 save 会先删后建，自动换 ACL）
    public static func migrateAccessControl() {
        for key in ["accountToken", "refreshToken", "phone"] {
            if let value = load(forKey: key) {
                save(value, forKey: key)
            }
        }
    }

    /// 清理遗留的 Keychain 条目（迁移到文件存储后不再使用 Keychain）
    public static func clearLegacy() {
        for key in ["accountToken", "refreshToken", "phone"] {
            delete(forKey: key)
        }
    }
}

/// 凭据存储一次性迁移：旧 Keychain 数据 → 文件存储
extension CredentialStore {
    /// 若文件存储为空且 Keychain 有旧数据，则搬移并清理 Keychain（用户无需重新登录）。
    /// 通过 UserDefaults 标记保证 Keychain 只被访问一次——之后永不触碰，杜绝反复弹窗。
    public static func migrateFromKeychainIfNeeded() {
        let flagKey = "credentialMigrationAttempted"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        UserDefaults.standard.set(true, forKey: flagKey)  // 先置标记，防止重入

        guard load(forKey: "accountToken") == nil else { return }
        guard let token = KeychainStore.load(forKey: "accountToken"),
              let phone = KeychainStore.load(forKey: "phone") else { return }
        let refresh = KeychainStore.load(forKey: "refreshToken")
        save(token, forKey: "accountToken")
        if let refresh {
            save(refresh, forKey: "refreshToken")
        }
        save(phone, forKey: "phone")
        KeychainStore.clearLegacy()
    }
}
