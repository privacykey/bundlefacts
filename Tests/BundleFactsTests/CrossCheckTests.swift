import XCTest
import Foundation
import BundleFacts

/// `PrivacyManifestReader.crossCheck(manifest:importedSymbols:)` against
/// synthesized symbol sets: per-category detection, multi-category symbols,
/// exact matching, and both mismatch directions.
final class CrossCheckTests: XCTestCase {

    private func manifest(declaring categories: [PrivacyManifest.AccessedAPI.Category] = [],
                          reasons: [String] = []) -> PrivacyManifest {
        PrivacyManifest(
            url: URL(fileURLWithPath: "/fixture/PrivacyInfo.xcprivacy"),
            isTrackingDeclared: false,
            trackingDomains: [],
            collectedDataTypes: [],
            accessedAPITypes: categories.map {
                PrivacyManifest.AccessedAPI(rawType: $0.identifier, category: $0, reasons: reasons)
            })
    }

    // MARK: - Per-category detection from symbols

    func testFileTimestampDetectedFromStat() {
        let result = PrivacyManifestReader.crossCheck(
            manifest: manifest(), importedSymbols: ["_stat", "_printf"])
        XCTAssertEqual(result.usedButUndeclared.map(\.category), [.fileTimestamp])
        XCTAssertEqual(result.usedButUndeclared.first?.evidence, ["_stat"])
    }

    func testSystemBootTimeDetectedFromMachAbsoluteTime() {
        let result = PrivacyManifestReader.crossCheck(
            manifest: manifest(), importedSymbols: ["_mach_absolute_time"])
        XCTAssertEqual(result.usedButUndeclared.map(\.category), [.systemBootTime])
    }

    func testDiskSpaceDetectedFromStatfs() {
        let result = PrivacyManifestReader.crossCheck(
            manifest: manifest(), importedSymbols: ["_statfs"])
        XCTAssertEqual(result.usedButUndeclared.map(\.category), [.diskSpace])
    }

    func testActiveKeyboardsDetectedFromUITextInputModeClassRef() {
        let result = PrivacyManifestReader.crossCheck(
            manifest: manifest(), importedSymbols: ["_OBJC_CLASS_$_UITextInputMode"])
        XCTAssertEqual(result.usedButUndeclared.map(\.category), [.activeKeyboards])
    }

    func testUserDefaultsDetectedFromNSUserDefaultsClassRef() {
        let result = PrivacyManifestReader.crossCheck(
            manifest: manifest(), importedSymbols: ["_OBJC_CLASS_$_NSUserDefaults"])
        XCTAssertEqual(result.usedButUndeclared.map(\.category), [.userDefaults])
        XCTAssertEqual(result.usedButUndeclared.first?.evidence, ["_OBJC_CLASS_$_NSUserDefaults"])
    }

    func testINODE64SpellingsMatch() {
        // x86_64 slices import part of the stat family with a $INODE64 suffix.
        let result = PrivacyManifestReader.crossCheck(
            manifest: manifest(), importedSymbols: ["_stat$INODE64", "_fstatfs$INODE64"])
        XCTAssertEqual(result.usedButUndeclared.map(\.category), [.diskSpace, .fileTimestamp])
    }

    func testGetattrlistCountsForBothItsCategories() {
        // The getattrlist family sits in both FileTimestamp and DiskSpace.
        let result = PrivacyManifestReader.crossCheck(
            manifest: manifest(), importedSymbols: ["_getattrlist"])
        XCTAssertEqual(result.usedButUndeclared.map(\.category), [.diskSpace, .fileTimestamp])
        XCTAssertEqual(result.usedButUndeclared.map(\.evidence), [["_getattrlist"], ["_getattrlist"]])
    }

    // MARK: - Exact matching, no substrings

    func testMatchingIsExactNotSubstring() {
        let result = PrivacyManifestReader.crossCheck(
            manifest: manifest(),
            importedSymbols: ["stat",            // no leading underscore
                              "_stat64",         // not in the vocabulary
                              "_mystat",         // suffix collision
                              "_NSUserDefaults"] // not the class-ref spelling
        )
        XCTAssertTrue(result.isClean, "none of these spellings are in the vocabulary: \(result)")
    }

    func testCMPedometerIsNotEvidenceOfAnything() {
        // CoreMotion is not a required-reason API; a pedometer class ref
        // must not surface as user-defaults (or any other) evidence.
        let result = PrivacyManifestReader.crossCheck(
            manifest: manifest(), importedSymbols: ["_OBJC_CLASS_$_CMPedometer"])
        XCTAssertTrue(result.isClean)
    }

    // MARK: - Declared but unused

    func testDeclaredButUnusedSurfacesUnmatchedCategory() {
        let result = PrivacyManifestReader.crossCheck(
            manifest: manifest(declaring: [.userDefaults], reasons: ["CA92.1"]),
            importedSymbols: ["_printf"])
        XCTAssertEqual(result.declaredButUnused, [.userDefaults])
        XCTAssertTrue(result.usedButUndeclared.isEmpty)
    }

    func testUnknownDeclaredCategoryIsNotDeclaredButUnused() {
        // No symbol evidence can exist for an undocumented category; naming
        // the unknown value is a validity finding, not a cross-check one.
        let result = PrivacyManifestReader.crossCheck(
            manifest: manifest(declaring: [.unknown("NSPrivacyAccessedAPICategoryX")]),
            importedSymbols: [])
        XCTAssertTrue(result.isClean)
    }

    // MARK: - Clean runs

    func testDeclaredAndUsedIsClean() {
        let result = PrivacyManifestReader.crossCheck(
            manifest: manifest(declaring: [.userDefaults], reasons: ["CA92.1"]),
            importedSymbols: ["_OBJC_CLASS_$_NSUserDefaults"])
        XCTAssertTrue(result.isClean)
    }

    func testNoSymbolsNoDeclarationsIsClean() {
        let result = PrivacyManifestReader.crossCheck(
            manifest: manifest(), importedSymbols: [])
        XCTAssertTrue(result.isClean)
    }

    func testMultipleCategoriesSortedByIdentifier() {
        let result = PrivacyManifestReader.crossCheck(
            manifest: manifest(),
            importedSymbols: ["_OBJC_CLASS_$_NSUserDefaults", "_mach_absolute_time", "_stat"])
        XCTAssertEqual(result.usedButUndeclared.map(\.category),
                       [.fileTimestamp, .systemBootTime, .userDefaults],
                       "mismatches sort by category identifier")
    }

    // MARK: - Tracking cross-check

    func testTrackerSDKsContradictUndeclaredTracking() {
        let check = PrivacyManifestReader.trackingCrossCheck(
            manifest: manifest(), trackerSDKNames: ["AdAttributionKit SDK"],
            observedTrackerDomains: [])
        XCTAssertEqual(check.trackerSDKsButTrackingNotDeclared, ["AdAttributionKit SDK"])
    }

    func testDeclaredDomainCoversSubdomainsNeverParents() {
        let m = PrivacyManifest(
            url: URL(fileURLWithPath: "/fixture/PrivacyInfo.xcprivacy"),
            isTrackingDeclared: true,
            trackingDomains: ["analytics.example.com"],
            collectedDataTypes: [], accessedAPITypes: [])
        let check = PrivacyManifestReader.trackingCrossCheck(
            manifest: m, trackerSDKNames: [],
            observedTrackerDomains: ["v2.analytics.example.com", "example.com"])
        XCTAssertEqual(check.undeclaredTrackingDomains, ["example.com"],
                       "a declared domain covers its subdomains but never its parent apex")
    }
}
