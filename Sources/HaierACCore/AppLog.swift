import Foundation

/// 简单文件日志，写入 ~/Library/Logs/HaierAC/app.log
public enum AppLog {
    private static let logURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/HaierAC/app.log")

    private static let queue = DispatchQueue(label: "haierac.log")

    public static func log(_ message: String) {
        let line = "[\(Self.timestamp())] \(message)\n"
        queue.async {
            do {
                try FileManager.default.createDirectory(
                    at: logURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if !FileManager.default.fileExists(atPath: logURL.path) {
                    FileManager.default.createFile(atPath: logURL.path, contents: nil)
                }
                if let handle = try? FileHandle(forWritingTo: logURL) {
                    handle.seekToEndOfFile()
                    handle.write(Data(line.utf8))
                    try? handle.close()
                }
            } catch {
                print("AppLog error: \(error)")
            }
        }
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f.string(from: Date())
    }
}
