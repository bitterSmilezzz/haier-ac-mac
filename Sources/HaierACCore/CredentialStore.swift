import Foundation
import CryptoKit
import IOKit

/// 凭据存储（文件方案 + AES-GCM 加密）
///
/// 为什么不用 Keychain：本应用使用 ad-hoc 签名（个人项目每次打包重新签名），
/// macOS 钥匙串对未签名/匿名签名的调用者即使 ACL 无限制也会反复弹出密码框。
/// 改用应用支持目录下的 600 权限文件（仅当前用户可读写），彻底消除弹窗。
///
/// 加密方案：以机器硬件标识 IOPlatformUUID 为种子，经 HKDF-SHA256 派生 256 位
/// AES 密钥，对文件内容做 AES-GCM 加密（文件格式：4 字节魔数 "HAC1" + 12 字节
/// 随机 nonce + 密文 + 16 字节 GCM tag）。密钥仅在内存中持有、不落盘、不经钥匙串，
/// 因此既满足「非明文存储」又保持零弹窗。
///
/// 兼容性：若磁盘上是旧版明文 JSON，读取时自动检测（魔数不匹配则按旧格式解码），
/// 解码成功后立即重写为加密格式——无缝迁移，用户无感。
///
/// 安全说明：存储的是短期访问令牌（10 天有效，可随时刷新/撤销），
/// 密码本身从不落盘；AES-GCM 加密 + 文件权限 600 + 系统全盘加密（FileVault 开启时）
/// 提供多层保护。
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

    // MARK: - 密钥派生

    /// 加密文件魔数，用于与旧版明文 JSON（以 `{` 开头）区分。
    private static let magic = Data("HAC1".utf8)

    /// AES-GCM nonce 长度（CryptoKit 默认 12 字节）。
    private static let nonceLength = 12

    /// 派生出的 AES-256 密钥。进程内缓存，仅内存持有、不落盘。
    private static let encryptionKey: SymmetricKey = deriveKey()

    /// 从机器硬件标识 IOPlatformUUID 派生 256 位密钥（HKDF-SHA256）。
    /// IOPlatformUUID 在 macOS 上是稳定的硬件唯一标识（与 `ioreg -rd1 -c IOPlatformExpertDevice`
    /// 输出一致），同一台机器每次派生结果相同，因此加密数据可跨启动解密。
    /// 读取失败时回退为随机密钥：此时加密退化为纯混淆（仅进程内一致），可接受。
    private static func deriveKey() -> SymmetricKey {
        guard let uuid = hardwareUUID() else {
            print("CredentialStore: 无法读取 IOPlatformUUID，回退随机密钥（混淆模式）")
            return SymmetricKey(size: .bits256)
        }
        let salt = Data("HaierAC.credentials.salt.v1".utf8)
        let info = Data("HaierAC.credentials.key.v1".utf8)
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Data(uuid.utf8)),
            salt: salt,
            info: info,
            outputByteCount: 32
        )
    }

    /// 通过 IOKit 读取 IOPlatformUUID（`ioreg -rd1 -c IOPlatformExpertDevice` 的同一字段）。
    private static func hardwareUUID() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        defer { IOObjectRelease(service) }
        guard service != 0 else { return nil }
        guard let prop = IORegistryEntryCreateCFProperty(
            service,
            kIOPlatformUUIDKey as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String else {
            return nil
        }
        return prop
    }

    // MARK: - 加密 / 解密

    /// 加密文件格式：4 字节魔数 "HAC1" + 12 字节 nonce + 密文 + 16 字节 GCM tag。
    private static func encrypt(_ plain: Data) throws -> Data {
        let nonce = AES.GCM.Nonce()
        let sealed = try AES.GCM.seal(plain, using: encryptionKey, nonce: nonce)
        var out = magic
        out.append(contentsOf: nonce.withUnsafeBytes { Data($0) })
        out.append(sealed.ciphertext)
        out.append(sealed.tag)
        return out
    }

    /// 解密并解码为 Credentials。数据不是加密格式、解密失败或解码失败时返回 nil。
    private static func decryptAndDecode(_ data: Data) -> Credentials? {
        guard data.count >= magic.count + nonceLength,
              data.prefix(magic.count).elementsEqual(magic) else { return nil }
        let payload = data.dropFirst(magic.count)
        guard payload.count >= nonceLength + 16 else { return nil }  // 至少 nonce + GCM tag
        let nonceData = payload.prefix(nonceLength)
        let ciphertext = payload.dropFirst(nonceLength).dropLast(16)
        let tag = payload.suffix(16)
        guard let nonce = try? AES.GCM.Nonce(data: nonceData),
              let box = try? AES.GCM.SealedBox(nonce: nonce, ciphertext: Data(ciphertext), tag: Data(tag)),
              let plain = try? AES.GCM.open(box, using: encryptionKey) else {
            return nil
        }
        return try? JSONDecoder().decode(Credentials.self, from: plain)
    }

    private static func loadFromDisk() -> Credentials {
        if let cache {
            return cache
        }
        guard let data = try? Data(contentsOf: fileURL) else {
            return Credentials()
        }
        // 新格式（加密）：直接解密
        if let creds = decryptAndDecode(data) {
            cache = creds
            return creds
        }
        // 旧格式（明文 JSON）：按旧格式读一次，并立即重写为加密格式（无缝迁移）。
        // 注：若文件是加密格式但解密失败（例如随机密钥回退跨启动），这里解码同样会失败，
        // 最终按无凭据处理，不会误判为旧明文。
        if let creds = try? JSONDecoder().decode(Credentials.self, from: data) {
            saveToDisk(creds)
            return creds
        }
        return Credentials()
    }

    private static func saveToDisk(_ creds: Credentials) {
        cache = creds
        do {
            let dir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let plain = try JSONEncoder().encode(creds)
            let encrypted = try encrypt(plain)
            try encrypted.write(to: fileURL, options: .atomic)
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
