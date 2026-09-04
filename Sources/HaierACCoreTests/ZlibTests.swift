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
}
