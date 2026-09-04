import XCTest
@testable import HaierACCore

/// 测试数据由 Python zlib/gzip 生成（固定字节，避免运行时依赖）：
/// zlib.compress(...) 产生 zlib header（0x78）；gzip.compress(...) 产生 gzip header（0x1f 0x8b）。
/// Swift 实现以 windowBits=47 自动检测两种 header。
final class ZlibTests: XCTestCase {
    private func assertDecompresses(_ compressed: [UInt8], to expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let data = Data(compressed)
        let out = Zlib.decompress(data)
        XCTAssertNotNil(out, "decompress returned nil", file: file, line: line)
        let decoded = out.flatMap { String(data: $0, encoding: .utf8) }
        XCTAssertEqual(decoded, Optional(expected), file: file, line: line)
    }

    /// zlib header（0x78 0x9c）
    func testZlibHeaderShortString() {
        assertDecompresses(
            [120, 156, 243, 72, 205, 201, 201, 215, 81, 240, 72, 204, 76, 45, 82, 112, 116, 86, 4, 0, 45, 40, 4, 239],
            to: "Hello, Haier AC!"
        )
    }

    /// gzip header（0x1f 0x8b）
    func testGzipHeaderShortString() {
        assertDecompresses(
            [31, 139, 8, 0, 42, 34, 154, 106, 2, 255, 243, 72, 205, 201, 201, 215, 81, 240, 72, 204, 76, 45, 82, 112, 116, 86, 4, 0, 139, 40, 74, 145, 16, 0, 0, 0],
            to: "Hello, Haier AC!"
        )
    }

    /// zlib header + 较长 JSON 内容
    func testZlibHeaderLongJson() {
        assertDecompresses(
            [120, 156, 171, 86, 74, 73, 45, 203, 76, 78, 245, 76, 81, 178, 82, 74, 76, 74, 86, 210, 81, 42, 206, 3, 50, 13, 141, 140, 77, 76, 205, 204, 45, 44, 13, 32, 44, 160, 120, 126, 94, 78, 102, 94, 170, 146, 85, 73, 81, 105, 106, 45, 0, 194, 46, 15, 254],
            to: "{\"deviceId\":\"abc\",\"sn\":\"1234567890123456\",\"online\":true}"
        )
    }

    /// gzip header + 较长 JSON 内容
    func testGzipHeaderLongJson() {
        assertDecompresses(
            [31, 139, 8, 0, 42, 34, 154, 106, 2, 255, 171, 86, 74, 73, 45, 203, 76, 78, 245, 76, 81, 178, 82, 74, 76, 74, 86, 210, 81, 42, 206, 3, 50, 13, 141, 140, 77, 76, 205, 204, 45, 44, 13, 32, 44, 160, 120, 126, 94, 78, 102, 94, 170, 146, 85, 73, 81, 105, 106, 45, 0, 77, 139, 186, 246, 56, 0, 0, 0],
            to: "{\"deviceId\":\"abc\",\"sn\":\"1234567890123456\",\"online\":true}"
        )
    }

    /// 损坏数据返回 nil（而非崩溃/死循环）
    func testCorruptedDataReturnsNil() {
        XCTAssertNil(Zlib.decompress(Data([1, 2, 3, 4])))
        XCTAssertNil(Zlib.decompress(Data()))
        XCTAssertNil(Zlib.decompress(Data([0x78, 0x9c, 0xff])))
    }

    /// 边界回归：解压输出恰好为 64KB 整数倍（65536 / 131072 字节）时必须成功。
    /// 旧实现以 `while avail_out == 0` 作为循环条件，输出恰好 64KB 倍数时
    /// 流已结束但 avail_out 为 0，会多循环一次 inflate 返回 Z_STREAM_ERROR → 静默丢数据。
    /// 测试数据由 Python zlib.compress('x'*65536, 9) / zlib.compress('y'*131072, 9) 生成，
    /// 并经 Python zlib.decompress 自校验（长度与 adler32 均正确）。
    func testOutputExactlyMultipleOf64KB() {
        // 65536 字节输出（zlib header 0x78 0xda）
        let compressed1: [UInt8] = [120, 218, 237, 193, 1, 1, 0, 0, 0, 128, 144, 219, 205, 239, 8, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 106, 56, 79, 7, 9]
        let out1 = Zlib.decompress(Data(compressed1))
        XCTAssertNotNil(out1, "65536 字节整倍数输出解压失败")
        XCTAssertEqual(out1?.count, 65536)

        // 131072 字节输出（2 × 64KB）
        let compressed2: [UInt8] = [120, 218, 237, 193, 49, 1, 0, 0, 0, 194, 160, 220, 107, 239, 97, 13, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 110, 219, 231, 14, 47]
        let out2 = Zlib.decompress(Data(compressed2))
        XCTAssertNotNil(out2, "131072 字节整倍数输出解压失败")
        XCTAssertEqual(out2?.count, 131072)
    }

    /// 截断数据（输入耗尽但流未结束）返回 nil，而非返回半截结果
    func testTruncatedDataReturnsNil() {
        // 取 131072 用例的压缩数据并截掉后半，确保 deflate 流未走完
        let compressed: [UInt8] = [120, 218, 237, 193, 49, 1, 0, 0, 0, 194, 160, 220, 107, 239, 97, 13, 160, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 110, 219, 231, 14, 47]
        let truncated = Data(compressed.prefix(compressed.count / 2))
        XCTAssertNil(Zlib.decompress(truncated), "截断数据应返回 nil")
    }
}
