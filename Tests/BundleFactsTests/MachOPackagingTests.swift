import XCTest
import Foundation
import BundleFacts

/// Mach-O parsing against hand-assembled fixtures: LC_BUILD_VERSION decode,
/// all-fat-slice load commands, and all-fat-slice symbol-table reads.
final class MachOPackagingTests: XCTestCase {

    // MARK: - byte helpers

    private func le32(_ v: UInt32) -> [UInt8] {
        [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)]
    }
    private func be32(_ v: UInt32) -> [UInt8] {
        [UInt8((v >> 24) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)]
    }
    private func le64(_ v: UInt64) -> [UInt8] {
        (0..<8).map { UInt8((v >> ($0 * 8)) & 0xFF) }
    }

    /// A minimal 64-bit Mach-O slice with an LC_BUILD_VERSION (platform
    /// macOS), optionally one LC_LOAD_DYLIB, and optionally an LC_SYMTAB
    /// whose nlist_64 table marks every named symbol as an undefined
    /// external (N_UNDF | N_EXT) — i.e. an import.
    private func thinSlice(cputype: UInt32, minos: UInt32, dylib: String?,
                           importedSymbols: [String] = []) -> [UInt8] {
        var lcs: [UInt8] = []
        var ncmds: UInt32 = 0
        // LC_BUILD_VERSION: cmd cmdsize platform minos sdk ntools  (24 bytes)
        lcs += le32(0x32) + le32(24) + le32(1) + le32(minos) + le32(0x000F0000) + le32(0)
        ncmds += 1
        if let d = dylib {
            var name = Array(d.utf8) + [0]
            while name.count % 8 != 0 { name.append(0) }
            let cmdsize = UInt32(24 + name.count)
            // cmd cmdsize | name_off timestamp current compat | name
            lcs += le32(0xC) + le32(cmdsize) + le32(24) + le32(0) + le32(0) + le32(0) + name
            ncmds += 1
        }

        // Symbol + string tables live after the load commands; LC_SYMTAB's
        // symoff/stroff are relative to the slice base.
        var tables: [UInt8] = []
        if !importedSymbols.isEmpty {
            let headerSize = 32
            let symtabCmdSize = 24
            let symoff = headerSize + lcs.count + symtabCmdSize
            let nlistSize = 16
            let stroff = symoff + importedSymbols.count * nlistSize

            // String table: offset 0 is reserved for the empty name.
            var strtab: [UInt8] = [0]
            var nlists: [UInt8] = []
            for name in importedSymbols {
                let nStrx = UInt32(strtab.count)
                strtab += Array(name.utf8) + [0]
                // nlist_64: n_strx(4) n_type(1)=N_UNDF|N_EXT n_sect(1) n_desc(2) n_value(8)
                nlists += le32(nStrx) + [0x01, 0x00, 0x00, 0x00] + le64(0)
            }
            // LC_SYMTAB: cmd cmdsize symoff nsyms stroff strsize
            lcs += le32(0x2) + le32(UInt32(symtabCmdSize))
                + le32(UInt32(symoff)) + le32(UInt32(importedSymbols.count))
                + le32(UInt32(stroff)) + le32(UInt32(strtab.count))
            ncmds += 1
            tables = nlists + strtab
        }

        var header: [UInt8] = []
        header += le32(0xFEEDFACF)            // mh_magic_64
        header += le32(cputype)
        header += le32(0)                     // cpusubtype
        header += le32(2)                     // MH_EXECUTE
        header += le32(ncmds)
        header += le32(UInt32(lcs.count))     // sizeofcmds
        header += le32(0)                     // flags
        header += le32(0)                     // reserved
        return header + lcs + tables
    }

    /// Wrap two slices into a 32-bit fat header (arm64 first, x86_64 second).
    private func fatBinary(_ s0: [UInt8], _ s1: [UInt8]) -> [UInt8] {
        let o0 = 8 + 40                 // fat_header(8) + 2 fat_arch(20 each)
        let o1 = o0 + s0.count
        var fat: [UInt8] = []
        fat += be32(0xCAFEBABE) + be32(2)
        fat += be32(0x0100000C) + be32(0) + be32(UInt32(o0)) + be32(UInt32(s0.count)) + be32(0)
        fat += be32(0x01000007) + be32(0) + be32(UInt32(o1)) + be32(UInt32(s1.count)) + be32(0)
        precondition(fat.count == o0, "fat header must end exactly at first slice offset")
        return fat + s0 + s1
    }

    private func writeTemp(_ bytes: [UInt8]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bfmacho-\(UUID().uuidString).bin")
        try Data(bytes).write(to: url)
        return url
    }

    // MARK: - LC_BUILD_VERSION (thin)

    func testThinBuildVersionParsed() throws {
        let url = try writeTemp(thinSlice(cputype: 0x0100000C, minos: 0x000E0000, dylib: nil)) // arm64, 14.0
        defer { try? FileManager.default.removeItem(at: url) }
        let lc = MachOInspector.loadCommands(of: url)
        XCTAssertEqual(lc.buildPlatform, "macOS")
        XCTAssertEqual(lc.minOSVersion, "14.0")
        XCTAssertEqual(lc.sdkVersion, "15.0")
        XCTAssertEqual(lc.sliceCount, 1)
    }

    // MARK: - all fat slices: load commands

    func testFatBinaryParsesBothSlices_andMergesSecondSliceDylib() throws {
        let s0 = thinSlice(cputype: 0x0100000C, minos: 0x000E0000, dylib: nil)                       // arm64 14.0
        let s1 = thinSlice(cputype: 0x01000007, minos: 0x000D0000, dylib: "@rpath/SecondSliceOnly.dylib") // x86_64 13.0
        let url = try writeTemp(fatBinary(s0, s1))
        defer { try? FileManager.default.removeItem(at: url) }
        let lc = MachOInspector.loadCommands(of: url)
        XCTAssertEqual(lc.sliceCount, 2, "both fat slices should be parsed")
        XCTAssertTrue(lc.dylibs.contains("@rpath/SecondSliceOnly.dylib"),
                      "a dylib present only in the 2nd slice must surface, got \(lc.dylibs)")
        XCTAssertEqual(lc.minOSVersion, "14.0", "first slice's min OS wins")
        XCTAssertEqual(lc.buildPlatform, "macOS")
    }

    // MARK: - all fat slices: imported symbols

    func testThinSliceImportedSymbolsParsed() throws {
        let url = try writeTemp(thinSlice(cputype: 0x0100000C, minos: 0x000E0000, dylib: nil,
                                          importedSymbols: ["_printf", "_stat"]))
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(Set(MachOInspector.importedSymbols(of: url)), ["_printf", "_stat"])
    }

    func testFatBinaryReportsSymbolImportedByOnlyOneSlice() throws {
        // A universal binary whose x86_64 slice imports a required-reason
        // symbol (`_stat$INODE64`) that the arm64 slice does not. The union
        // across slices must report it: parsing only the first slice would
        // fail the `_stat$INODE64` assertion below.
        let s0 = thinSlice(cputype: 0x0100000C, minos: 0x000E0000, dylib: nil,
                           importedSymbols: ["_printf", "_malloc"])                 // arm64
        let s1 = thinSlice(cputype: 0x01000007, minos: 0x000D0000, dylib: nil,
                           importedSymbols: ["_printf", "_stat$INODE64"])           // x86_64
        let url = try writeTemp(fatBinary(s0, s1))
        defer { try? FileManager.default.removeItem(at: url) }

        let symbols = MachOInspector.importedSymbols(of: url)
        XCTAssertTrue(symbols.contains("_stat$INODE64"),
                      "a symbol imported only by the second slice must be reported, got \(symbols)")
        XCTAssertTrue(symbols.contains("_malloc"),
                      "first-slice-only symbols must also be reported")
        XCTAssertEqual(symbols.filter { $0 == "_printf" }.count, 1,
                       "symbols imported by both slices appear exactly once")
        XCTAssertEqual(Set(symbols), ["_printf", "_malloc", "_stat$INODE64"])
    }

    func testFatBinarySymbolUnionRespectsLimit() throws {
        let s0 = thinSlice(cputype: 0x0100000C, minos: 0x000E0000, dylib: nil,
                           importedSymbols: ["_a", "_b", "_c"])
        let s1 = thinSlice(cputype: 0x01000007, minos: 0x000D0000, dylib: nil,
                           importedSymbols: ["_d", "_e", "_f"])
        let url = try writeTemp(fatBinary(s0, s1))
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(MachOInspector.importedSymbols(of: url, limit: 4).count, 4,
                       "the limit caps the union across slices, not each slice")
        XCTAssertEqual(MachOInspector.importedSymbols(of: url).count, 6)
    }

    // MARK: - version / platform decode helpers

    func testDecodeVersionAndPlatform() {
        XCTAssertEqual(MachOInspector.decodeVersion(0x000E0500), "14.5")
        XCTAssertEqual(MachOInspector.decodeVersion(0x000E0501), "14.5.1")
        XCTAssertEqual(MachOInspector.platformName(1), "macOS")
        XCTAssertEqual(MachOInspector.platformName(6), "macCatalyst")
        XCTAssertNil(MachOInspector.platformName(99))
    }

    // MARK: - architectures

    func testArchitecturesOfFatBinary() throws {
        let s0 = thinSlice(cputype: 0x0100000C, minos: 0x000E0000, dylib: nil)
        let s1 = thinSlice(cputype: 0x01000007, minos: 0x000D0000, dylib: nil)
        let url = try writeTemp(fatBinary(s0, s1))
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(try MachOInspector.architectures(of: url), ["arm64", "x86_64"])
    }
}
