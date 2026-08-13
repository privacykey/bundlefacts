import XCTest
import Foundation
import BundleFacts

/// Exact parse results for every fixture in the golden corpus. The reader is
/// deliberately lenient — invalid manifests still parse, and these tests pin
/// down exactly what a linter building on the parsed form can and cannot see.
final class PrivacyManifestParserTests: XCTestCase {

    private func fixture(_ name: String) throws -> URL {
        try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: "xcprivacy",
                              subdirectory: "Fixtures"),
            "missing fixture \(name).xcprivacy")
    }

    private func parse(_ name: String) throws -> PrivacyManifest {
        try XCTUnwrap(PrivacyManifestReader.read(at: try fixture(name)),
                      "fixture \(name).xcprivacy should parse")
    }

    // MARK: - Valid exemplars

    func testValidEmptyManifestParses() throws {
        let m = try parse("valid-empty")
        XCTAssertFalse(m.isTrackingDeclared)
        XCTAssertEqual(m.trackingDomains, [])
        XCTAssertEqual(m.collectedDataTypes, [])
        XCTAssertEqual(m.accessedAPITypes, [])
    }

    func testValidMinimalNoTracking() throws {
        let m = try parse("valid-minimal-no-tracking")
        XCTAssertFalse(m.isTrackingDeclared)
        XCTAssertEqual(m.trackingDomains, [])
    }

    func testValidTrackingWithDomains() throws {
        let m = try parse("valid-tracking-with-domains")
        XCTAssertTrue(m.isTrackingDeclared)
        XCTAssertEqual(m.trackingDomains, ["tracker.example.com", "analytics.example.net"])
    }

    func testValidCollectedDataParsesExactly() throws {
        let m = try parse("valid-collected-data")
        XCTAssertEqual(m.collectedDataTypes.count, 2)
        let email = m.collectedDataTypes[0]
        XCTAssertEqual(email.rawType, "NSPrivacyCollectedDataTypeEmailAddress")
        XCTAssertEqual(email.displayName, "Email Address")
        XCTAssertTrue(email.linkedToUser)
        XCTAssertFalse(email.usedForTracking)
        XCTAssertEqual(email.purposes, ["App Functionality"])
        let crash = m.collectedDataTypes[1]
        XCTAssertEqual(crash.rawType, "NSPrivacyCollectedDataTypeCrashData")
        XCTAssertEqual(crash.displayName, "Crash Data")
        XCTAssertFalse(crash.linkedToUser)
        XCTAssertEqual(crash.purposes, ["Analytics"])
    }

    func testValidAccessedAPIFileTimestamp() throws {
        let m = try parse("valid-accessed-api-file-timestamp")
        XCTAssertEqual(m.accessedAPITypes.count, 1)
        let api = try XCTUnwrap(m.accessedAPITypes.first)
        XCTAssertEqual(api.rawType, "NSPrivacyAccessedAPICategoryFileTimestamp")
        XCTAssertEqual(api.category, .fileTimestamp)
        XCTAssertEqual(api.reasons, ["C617.1"])
    }

    func testValidAccessedAPIAllFiveCategories() throws {
        let m = try parse("valid-accessed-api-all-five")
        XCTAssertEqual(m.accessedAPITypes.map(\.category),
                       [.fileTimestamp, .systemBootTime, .diskSpace, .activeKeyboards, .userDefaults])
        XCTAssertEqual(m.accessedAPITypes.map(\.reasons),
                       [["DDA9.1"], ["35F9.1"], ["E174.1"], ["54BD.1"], ["CA92.1"]])
        // Every declared reason belongs to its declared category.
        for api in m.accessedAPITypes {
            for reason in api.reasons {
                XCTAssertTrue(RequiredReasonAPIs.isValid(reasonCode: reason, in: api.category),
                              "\(reason) should be valid under \(api.category.identifier)")
            }
        }
    }

    func testValidFullParsesEverySection() throws {
        let m = try parse("valid-full")
        XCTAssertTrue(m.isTrackingDeclared)
        XCTAssertEqual(m.trackingDomains, ["tracker.example.com"])
        XCTAssertEqual(m.collectedDataTypes.map(\.rawType), ["NSPrivacyCollectedDataTypeDeviceID"])
        XCTAssertEqual(m.collectedDataTypes.first?.displayName, "Device ID")
        XCTAssertEqual(m.collectedDataTypes.first?.usedForTracking, true)
        XCTAssertEqual(m.collectedDataTypes.first?.purposes, ["Third-Party Advertising"])
        XCTAssertEqual(m.accessedAPITypes.map(\.category), [.userDefaults])
    }

    func testValidPhotosorVideosIrregularIdentifier() throws {
        // The documented identifier really is "PhotosorVideos" (lowercase or).
        let m = try parse("valid-photos-or-videos")
        let t = try XCTUnwrap(m.collectedDataTypes.first)
        XCTAssertEqual(t.rawType, "NSPrivacyCollectedDataTypePhotosorVideos")
        XCTAssertEqual(t.displayName, "Photos or Videos")
    }

    func testValidMultipleReasonsPreserveOrder() throws {
        let m = try parse("valid-multiple-reasons")
        XCTAssertEqual(m.accessedAPITypes.first?.reasons, ["CA92.1", "1C8F.1", "AC6B.1"])
    }

    func testBinaryPlistParsesIdenticallyToXML() throws {
        let xml = try parse("valid-full")
        let bin = try parse("valid-binary-plist")
        XCTAssertEqual(bin.isTrackingDeclared, xml.isTrackingDeclared)
        XCTAssertEqual(bin.trackingDomains, xml.trackingDomains)
        XCTAssertEqual(bin.collectedDataTypes, xml.collectedDataTypes)
        XCTAssertEqual(bin.accessedAPITypes, xml.accessedAPITypes)
    }

    // MARK: - Invalid manifests still parse; the parse result is exact

    func testUnknownTopLevelKeyIsIgnoredByTheParser() throws {
        // The reader surfaces the documented keys only; spotting the
        // undocumented NSPrivacyFunLevel is a plist-level linter check
        // against PrivacyVocabulary.manifestKeyNames.
        let m = try parse("invalid-unknown-top-level-key")
        XCTAssertFalse(m.isTrackingDeclared)
        XCTAssertEqual(m.collectedDataTypes, [])
        XCTAssertFalse(PrivacyVocabulary.manifestKeyNames.contains("NSPrivacyFunLevel"))
    }

    func testInventedDataTypeIsPreservedVerbatim() throws {
        let m = try parse("invalid-invented-data-type")
        let t = try XCTUnwrap(m.collectedDataTypes.first)
        XCTAssertEqual(t.rawType, "NSPrivacyCollectedDataTypeShoeSize")
        XCTAssertEqual(t.displayName, "NSPrivacyCollectedDataTypeShoeSize",
                       "no display name exists for an invented type; the raw value passes through")
        XCTAssertNil(PrivacyVocabulary.collectedDataTypesByIdentifier[t.rawType])
    }

    func testInventedPurposeIsPreservedVerbatim() throws {
        let m = try parse("invalid-invented-purpose")
        XCTAssertEqual(m.collectedDataTypes.first?.purposes,
                       ["NSPrivacyCollectedDataTypePurposeVibes"])
        XCTAssertNil(PrivacyVocabulary.purposesByIdentifier["NSPrivacyCollectedDataTypePurposeVibes"])
    }

    func testEmptyAccessedAPIArrayParsesAsEmpty() throws {
        let m = try parse("invalid-empty-accessed-api-array")
        XCTAssertEqual(m.accessedAPITypes, [])
    }

    func testReasonUnderWrongCategoryParsesButFailsScoping() throws {
        let m = try parse("invalid-reason-wrong-category")
        let api = try XCTUnwrap(m.accessedAPITypes.first)
        XCTAssertEqual(api.category, .fileTimestamp)
        XCTAssertEqual(api.reasons, ["CA92.1"])
        // CA92.1 is real — but it belongs to UserDefaults, not FileTimestamp.
        XCTAssertFalse(RequiredReasonAPIs.isValid(reasonCode: "CA92.1", in: .fileTimestamp))
        XCTAssertEqual(RequiredReasonAPIs.categoryByReasonCode["CA92.1"], .userDefaults)
    }

    func testTrackingTrueWithEmptyDomains() throws {
        let m = try parse("invalid-tracking-true-empty-domains")
        XCTAssertTrue(m.isTrackingDeclared)
        XCTAssertEqual(m.trackingDomains, [])
    }

    func testTrackingTrueWithMissingDomains() throws {
        let m = try parse("invalid-tracking-true-missing-domains")
        XCTAssertTrue(m.isTrackingDeclared)
        XCTAssertEqual(m.trackingDomains, [])
    }

    func testTrackingFalseWithNonEmptyDomains() throws {
        let m = try parse("invalid-tracking-false-nonempty-domains")
        XCTAssertFalse(m.isTrackingDeclared)
        XCTAssertEqual(m.trackingDomains, ["tracker.example.com"])
    }

    func testMalformedDomainStringsPassThroughVerbatim() throws {
        // The reader reports what the file says; the string-format rules
        // (no scheme, no path, no trailing slash) are the linter's to apply.
        XCTAssertEqual(try parse("invalid-domain-scheme").trackingDomains,
                       ["https://tracker.example.com"])
        XCTAssertEqual(try parse("invalid-domain-path").trackingDomains,
                       ["tracker.example.com/pixel"])
        XCTAssertEqual(try parse("invalid-domain-trailing-slash").trackingDomains,
                       ["tracker.example.com/"])
    }

    func testNonBooleanTrackingReadsAsFalse() throws {
        // NSPrivacyTracking = "true" (a string) is invalid; the lenient
        // reader coerces non-Booleans to false. A type-level linter check
        // needs the raw plist, not this parse.
        let m = try parse("invalid-non-boolean-tracking")
        XCTAssertFalse(m.isTrackingDeclared)
        XCTAssertEqual(m.trackingDomains, ["tracker.example.com"])
    }

    func testUnknownAPICategoryIsPreservedNotCollapsed() throws {
        let m = try parse("invalid-unknown-api-category")
        let api = try XCTUnwrap(m.accessedAPITypes.first)
        XCTAssertEqual(api.category, .unknown("NSPrivacyAccessedAPICategorySystemClipboard"))
        XCTAssertEqual(api.category.identifier, "NSPrivacyAccessedAPICategorySystemClipboard",
                       "a linter must be able to name the exact unknown category")
        XCTAssertFalse(api.category.isDocumented)
        XCTAssertEqual(api.rawType, "NSPrivacyAccessedAPICategorySystemClipboard")
    }

    func testEmptyReasonsArrayParsesAsEmpty() throws {
        let m = try parse("invalid-empty-reasons")
        let api = try XCTUnwrap(m.accessedAPITypes.first)
        XCTAssertEqual(api.category, .fileTimestamp)
        XCTAssertEqual(api.reasons, [])
    }

    func testWrongCasingDataTypeIsNotTheDocumentedIdentifier() throws {
        let m = try parse("invalid-data-type-wrong-casing")
        let t = try XCTUnwrap(m.collectedDataTypes.first)
        XCTAssertEqual(t.rawType, "NSPrivacyCollectedDataTypePhotosOrVideos")
        XCTAssertEqual(t.displayName, t.rawType,
                       "the uppercase-Or spelling is undocumented, so no display name maps")
        XCTAssertNil(PrivacyVocabulary.collectedDataTypesByIdentifier[t.rawType])
    }

    // MARK: - Category Codable round-trip

    func testCategoryEncodesAsIdentifierString() throws {
        let cats: [PrivacyManifest.AccessedAPI.Category] =
            [.userDefaults, .unknown("NSPrivacyAccessedAPICategoryX")]
        let data = try JSONEncoder().encode(cats)
        XCTAssertEqual(String(data: data, encoding: .utf8),
                       #"["NSPrivacyAccessedAPICategoryUserDefaults","NSPrivacyAccessedAPICategoryX"]"#)
        let decoded = try JSONDecoder().decode([PrivacyManifest.AccessedAPI.Category].self, from: data)
        XCTAssertEqual(decoded, cats)
    }
}
