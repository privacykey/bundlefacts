import XCTest
import Foundation
import BundleFacts

/// `MachOInspector.importedSymbols` against real binaries on the host (the
/// system-binary cases skip themselves where those binaries don't exist)
/// and against non-Mach-O input.
final class ImportedSymbolsTests: XCTestCase {

    func testImportedSymbolsReadsSystemBinary() throws {
        let url = URL(fileURLWithPath: "/bin/ls")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path))
        let imports = MachOInspector.importedSymbols(of: url)
        XCTAssertFalse(imports.isEmpty, "ls should import libc functions")
        // ls links libSystem and calls into it. Underscore-prefixed (Mach-O).
        let names = Set(imports)
        XCTAssertTrue(names.contains(where: { $0.hasPrefix("_") }),
                      "imported symbols keep their leading underscore")
        // A couple of ubiquitous libc imports ls is guaranteed to use.
        XCTAssertTrue(names.contains("_printf") || names.contains("_fwrite")
                      || names.contains("_write") || names.contains("_exit"),
                      "expected a common libc import, got: \(imports.prefix(20))")
    }

    func testImportedSymbolsRespectsLimit() throws {
        let url = URL(fileURLWithPath: "/usr/lib/dyld")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: url.path))
        let capped = MachOInspector.importedSymbols(of: url, limit: 5)
        XCTAssertLessThanOrEqual(capped.count, 5)
    }

    func testImportedSymbolsOnNonMachOIsEmpty() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-macho-\(UUID().uuidString).txt")
        try "hello world, not a binary".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }
        XCTAssertEqual(MachOInspector.importedSymbols(of: tmp), [])
    }
}
