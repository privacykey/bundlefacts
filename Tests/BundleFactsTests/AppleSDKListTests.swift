import XCTest
import Foundation
import BundleFacts

/// Shape of the commonly-used-SDK table, the alternative-name split, and
/// the disk-name matcher's normalisation and exact-match behaviour.
final class AppleSDKListTests: XCTestCase {

    // MARK: - Table shape

    func testExactlyEightySixEntriesInPublishedOrder() {
        XCTAssertEqual(AppleSDKList.entries.count, 86)
        XCTAssertEqual(AppleSDKList.entries.first?.canonicalName, "Abseil")
        XCTAssertEqual(AppleSDKList.entries.last?.canonicalName, "webview_flutter_wkwebview")
        let canonicals = AppleSDKList.entries.map(\.canonicalName)
        XCTAssertEqual(Set(canonicals).count, canonicals.count, "canonical names never repeat")
    }

    func testCombinedEntriesSplitIntoAlternatives() {
        let boringSSL = AppleSDKList.entries.first { $0.canonicalName == "BoringSSL" }
        XCTAssertEqual(boringSSL?.alternativeNames, ["openssl_grpc"])
        XCTAssertEqual(boringSSL?.allNames, ["BoringSSL", "openssl_grpc"])
        // BoringSSL is the only combined entry on the current list.
        XCTAssertEqual(AppleSDKList.entries.filter { !$0.alternativeNames.isEmpty }.map(\.canonicalName),
                       ["BoringSSL"])
        // No published name carries an unsplit " / " separator.
        for name in AppleSDKList.entries.flatMap(\.allNames) {
            XCTAssertFalse(name.contains("/"), "unsplit combined entry: \(name)")
        }
    }

    func testNormalizedNamesNeverCollideAcrossEntries() {
        let normalized = AppleSDKList.entries.flatMap(\.allNames).map { AppleSDKList.normalized($0) }
        XCTAssertEqual(Set(normalized).count, normalized.count,
                       "a collision would let one entry shadow another in the matcher")
    }

    // MARK: - Matcher positives

    func testFrameworkDirectoryNamesMatch() {
        XCTAssertEqual(AppleSDKList.entry(matching: "Alamofire.framework")?.canonicalName, "Alamofire")
        XCTAssertEqual(AppleSDKList.entry(matching: "Alamofire.xcframework")?.canonicalName, "Alamofire")
        XCTAssertEqual(AppleSDKList.entry(matching: "Alamofire")?.canonicalName, "Alamofire")
        // A canonical name that itself ends in "Framework" survives stripping.
        XCTAssertEqual(AppleSDKList.entry(matching: "UnityFramework.framework")?.canonicalName,
                       "UnityFramework")
        XCTAssertEqual(AppleSDKList.entry(matching: "UnityFramework")?.canonicalName, "UnityFramework")
        XCTAssertTrue(AppleSDKList.isListed("Kingfisher"))
    }

    func testSeparatorAndCaseVariantsMatch() {
        for variant in ["flutter_local_notifications",
                        "flutter-local-notifications",
                        "FLUTTER_LOCAL_NOTIFICATIONS",
                        "flutter_local_notifications.framework"] {
            XCTAssertEqual(AppleSDKList.entry(matching: variant)?.canonicalName,
                           "flutter_local_notifications", variant)
        }
        XCTAssertEqual(AppleSDKList.entry(matching: "device-info-plus")?.canonicalName,
                       "device_info_plus")
    }

    func testAlternativeNamesMatchTheirEntry() {
        XCTAssertEqual(AppleSDKList.entry(matching: "openssl_grpc")?.canonicalName, "BoringSSL")
        XCTAssertEqual(AppleSDKList.entry(matching: "openssl-grpc.framework")?.canonicalName, "BoringSSL")
        // The standalone OpenSSL entry stays distinct from BoringSSL's alternative.
        XCTAssertEqual(AppleSDKList.entry(matching: "OpenSSL")?.canonicalName, "OpenSSL")
    }

    // MARK: - Matcher negatives

    func testUnlistedNamesDoNotMatch() {
        XCTAssertNil(AppleSDKList.entry(matching: "Sparkle"))
        XCTAssertNil(AppleSDKList.entry(matching: "Sparkle.framework"))
        XCTAssertNil(AppleSDKList.entry(matching: "NotAnSDK"))
        XCTAssertNil(AppleSDKList.entry(matching: ""))
        XCTAssertFalse(AppleSDKList.isListed("Sparkle"))
    }

    func testMatchingIsExactNotPrefixOrSubstring() {
        XCTAssertNil(AppleSDKList.entry(matching: "AlamofireImage"))
        XCTAssertNil(AppleSDKList.entry(matching: "FirebaseCoreX"))
        XCTAssertNil(AppleSDKList.entry(matching: "Firebase"))
    }

    // MARK: - Normalisation

    func testNormalizationStripsOneSuffixIgnoresCaseAndSeparators() {
        XCTAssertEqual(AppleSDKList.normalized("Alamofire.framework"), "alamofire")
        XCTAssertEqual(AppleSDKList.normalized("Alamofire.XCFramework"), "alamofire")
        XCTAssertEqual(AppleSDKList.normalized("flutter-local_notifications"), "flutterlocalnotifications")
        // Only a trailing suffix is stripped; interior text is untouched.
        XCTAssertEqual(AppleSDKList.normalized("UnityFramework"), "unityframework")
        XCTAssertEqual(AppleSDKList.normalized(".framework"), "")
    }

    // MARK: - Enforcement rule constants

    func testRuleConstants() {
        XCTAssertEqual(AppleSDKList.Rules.manifestRequiredFrom,
                       DateComponents(year: 2025, month: 2, day: 12))
        XCTAssertEqual(AppleSDKList.Rules.missingManifestCode, "ITMS-91061")
        XCTAssertEqual(AppleSDKList.Rules.missingSignatureCode, "ITMS-91065")
    }
}
