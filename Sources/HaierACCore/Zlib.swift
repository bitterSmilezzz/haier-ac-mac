import Foundation
import zlib

/// zlib.h 宏常量（Swift 的 Clang importer 不导入 C 宏，此处取文档固定值）
private let Z_NO_FLUSH: Int32 = 0
private let Z_OK: Int32 = 0
private let Z_STREAM_END: Int32 = 1
private let Z_STREAM_ERROR: Int32 = -2
private let MAX_WBITS: Int32 = 15

/// 与 Python zlib.decompress(data, 16 + zlib.MAX_WBITS) 行为一致的解压
enum Zlib {
    static func decompress(_ data: Data) -> Data? {
        var stream = z_stream()
        let windowBits = Int32(32) + MAX_WBITS  // 47: 自动检测 zlib/gzip header

        let initResult: Int32 = data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) -> Int32 in
            guard let base = raw.bindMemory(to: Bytef.self).baseAddress else { return Z_STREAM_ERROR }
            stream.next_in = UnsafeMutablePointer(mutating: base)
            stream.avail_in = uInt(data.count)
            return inflateInit2_(&stream, windowBits, zlibVersion(), Int32(MemoryLayout<z_stream>.size))
        }
        guard initResult == Z_OK else { return nil }
        defer { inflateEnd(&stream) }

        var out = Data()
        let chunkSize = 1 << 16
        var chunk = [Bytef](repeating: 0, count: chunkSize)

        // 注意：`inflate` 必须在 withUnsafeMutableBytes 闭包内调用——
        // Swift 只保证 stream.next_out 指向的内存在该闭包作用域内有效（悬垂指针修正）。
        var status: Int32 = Z_OK
        repeat {
            status = chunk.withUnsafeMutableBytes { raw -> Int32 in
                guard let base = raw.bindMemory(to: Bytef.self).baseAddress else { return Z_STREAM_ERROR }
                stream.next_out = base
                stream.avail_out = uInt(chunkSize)
                return inflate(&stream, Z_NO_FLUSH)
            }
            guard status == Z_OK || status == Z_STREAM_END else { return nil }

            let produced = chunkSize - Int(stream.avail_out)
            if produced > 0 {
                out.append(chunk, count: produced)
            }

            // 输出缓冲未满但流未结束 = 输入数据截断，返回失败而非半截结果
            if status == Z_OK && stream.avail_out > 0 {
                return nil
            }
            // 循环退出条件：流结束（Z_STREAM_END）。
            // 不能用 `avail_out == 0` 作条件——输出恰好是 64KB 整数倍时
            // avail_out 为 0 但流已结束，会多循环一次导致 Z_STREAM_ERROR（边界 bug 修正）。
        } while status != Z_STREAM_END

        return out
    }
}
