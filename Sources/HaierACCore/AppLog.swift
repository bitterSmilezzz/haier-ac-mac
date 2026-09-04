import Foundation

/// 简单文件日志，写入 ~/Library/Logs/HaierAC/app.log
/// 优化：持久 FileHandle（避免每条日志打开/关闭句柄）+ 10MB 大小轮转
public enum AppLog {
    private static let logURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/HaierAC/app.log")
    /// 轮转阈值：超过则重命名 app.log → app.log.1（保留最近一份）
    private static let rotationThreshold: UInt64 = 10 * 1024 * 1024

    private static let queue = DispatchQueue(label: "haierac.log")
    /// 持久句柄（queue 内访问，避免竞争）
    private static var handle: FileHandle?
    private static var currentSize: UInt64 = 0

    public static func log(_ message: String) {
        let line = "[\(Self.timestamp())] \(message)\n"
        queue.async {
            Self.write(line)
        }
    }

    private static func write(_ line: String) {
        do {
            let dir = logURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            if handle == nil {
                // 首次写入：打开/创建文件，统计当前大小
                if !FileManager.default.fileExists(atPath: logURL.path) {
                    FileManager.default.createFile(atPath: logURL.path, contents: nil)
                }
                if let h = try? FileHandle(forWritingTo: logURL) {
                    h.seekToEndOfFile()
                    currentSize = (try? h.offset()) ?? 0
                    handle = h
                }
            }

            guard let handle else { return }

            // 轮转：超过阈值时归档当前文件并重建句柄
            if currentSize + UInt64(line.utf8.count) > rotationThreshold {
                rotate()
                guard let h = try? FileHandle(forWritingTo: logURL) else { return }
                h.seekToEndOfFile()
                currentSize = 0
                Self.handle = h
            }

            if let data = line.data(using: .utf8) {
                try handle.write(contentsOf: data)
                currentSize += UInt64(data.count)
            }
        } catch {
            print("AppLog error: \(error)")
        }
    }

    /// 轮转：app.log → app.log.1（删除旧 app.log.1），重建句柄
    private static func rotate() {
        handle?.closeFile()
        handle = nil
        let backup = logURL.appendingPathExtension("1")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: logURL, to: backup)
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f.string(from: Date())
    }
}
