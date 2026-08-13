import XCTest
import Foundation
import BundleFacts

/// Shape and content of the vocabulary tables: the counts Apple documents,
/// category scoping of reason codes, exact-match lookup behaviour, and the
/// irregular identifier spellings that trip up hand-rolled tables.
final class VocabularyTests: XCTestCase {

    // MARK: - RequiredReasonAPIs shape

    func testFiveCategoriesThirtySymbolsSeventeenReasonCodes() {
        XCTAssertEqual(RequiredReasonAPIs.categories.count, 5)
        XCTAssertEqual(RequiredReasonAPIs.categories.flatMap(\.symbols).count, 30)
        XCTAssertEqual(RequiredReasonAPIs.allReasonCodes.count, 17)
    }

    func testCategoriesCoverAllFiveDocumentedValues() {
        XCTAssertEqual(RequiredReasonAPIs.categories.map(\.category),
                       PrivacyManifest.AccessedAPI.Category.documented)
    }

    func testReasonCodesAreUniqueAndCategoryScoped() {
        let codes = RequiredReasonAPIs.allReasonCodes.map(\.code)
        XCTAssertEqual(Set(codes).count, codes.count, "reason codes never repeat across categories")
        XCTAssertEqual(RequiredReasonAPIs.categoryByReasonCode.count, 17)
        // Spot checks across the scoping map.
        XCTAssertEqual(RequiredReasonAPIs.categoryByReasonCode["C617.1"], .fileTimestamp)
        XCTAssertEqual(RequiredReasonAPIs.categoryByReasonCode["8FFB.1"], .systemBootTime)
        XCTAssertEqual(RequiredReasonAPIs.categoryByReasonCode["B728.1"], .diskSpace)
        XCTAssertEqual(RequiredReasonAPIs.categoryByReasonCode["3EC4.1"], .activeKeyboards)
        XCTAssertEqual(RequiredReasonAPIs.categoryByReasonCode["AC6B.1"], .userDefaults)
        // Real code, wrong category.
        XCTAssertFalse(RequiredReasonAPIs.isValid(reasonCode: "CA92.1", in: .fileTimestamp))
        XCTAssertTrue(RequiredReasonAPIs.isValid(reasonCode: "CA92.1", in: .userDefaults))
        // Invented code.
        XCTAssertFalse(RequiredReasonAPIs.isValid(reasonCode: "FFFF.9", in: .userDefaults))
    }

    func testEveryReasonCodeCarriesARestrictionNote() {
        for reason in RequiredReasonAPIs.allReasonCodes {
            XCTAssertFalse(reason.note.isEmpty, "\(reason.code) must explain its restriction")
        }
    }

    func testEverySymbolCarriesAtLeastOneNlistSpelling() {
        for entry in RequiredReasonAPIs.categories.flatMap(\.symbols) {
            XCTAssertFalse(entry.nlistSpellings.isEmpty, "\(entry.apiName) has no nlist spelling")
            for spelling in entry.nlistSpellings {
                XCTAssertTrue(spelling.hasPrefix("_"),
                              "nlist spellings carry the Mach-O leading underscore: \(spelling)")
            }
        }
    }

    // MARK: - Symbol lookup

    func testLibcAndObjCClassSpellingsBothResolve() {
        XCTAssertEqual(RequiredReasonAPIs.categories(forNlistSpelling: "_stat"), [.fileTimestamp])
        XCTAssertEqual(RequiredReasonAPIs.categories(forNlistSpelling: "_stat$INODE64"), [.fileTimestamp])
        XCTAssertEqual(RequiredReasonAPIs.categories(forNlistSpelling: "_OBJC_CLASS_$_NSUserDefaults"),
                       [.userDefaults])
        XCTAssertEqual(RequiredReasonAPIs.categories(forNlistSpelling: "_OBJC_CLASS_$_NSProcessInfo"),
                       [.systemBootTime])
        XCTAssertEqual(RequiredReasonAPIs.categories(forNlistSpelling: "_getattrlist"),
                       [.fileTimestamp, .diskSpace])
        XCTAssertEqual(RequiredReasonAPIs.categories(forNlistSpelling: "_statvfs"), [.diskSpace])
    }

    func testLookupIsExactMatchOnly() {
        XCTAssertTrue(RequiredReasonAPIs.categories(forNlistSpelling: "stat").isEmpty)
        XCTAssertTrue(RequiredReasonAPIs.categories(forNlistSpelling: "_stat ").isEmpty)
        XCTAssertTrue(RequiredReasonAPIs.categories(forNlistSpelling: "_statx").isEmpty)
        XCTAssertTrue(RequiredReasonAPIs.categories(forNlistSpelling: "NSUserDefaults").isEmpty)
    }

    // MARK: - PrivacyVocabulary shape

    func testFourManifestKeys() {
        XCTAssertEqual(PrivacyVocabulary.manifestKeys.count, 4)
        XCTAssertEqual(PrivacyVocabulary.manifestKeyNames,
                       ["NSPrivacyTracking", "NSPrivacyTrackingDomains",
                        "NSPrivacyCollectedDataTypes", "NSPrivacyAccessedAPITypes"])
    }

    func testThirtyFiveDataTypesAcrossSixteenCategories() {
        XCTAssertEqual(PrivacyVocabulary.collectedDataTypes.count, 35)
        XCTAssertEqual(PrivacyVocabulary.collectedDataCategories.count, 16)
        XCTAssertEqual(Set(PrivacyVocabulary.collectedDataTypes.map(\.category)),
                       Set(PrivacyVocabulary.collectedDataCategories),
                       "every data type sits in a documented category and every category is used")
        let ids = PrivacyVocabulary.collectedDataTypes.map(\.identifier)
        XCTAssertEqual(Set(ids).count, ids.count, "identifiers are unique")
    }

    func testSixPurposes() {
        XCTAssertEqual(PrivacyVocabulary.purposes.count, 6)
        XCTAssertEqual(PrivacyVocabulary.purposesByIdentifier[
            "NSPrivacyCollectedDataTypePurposeAnalytics"]?.displayName, "Analytics")
    }

    func testPhotosorVideosIrregularSpellingIsTheDocumentedOne() {
        XCTAssertNotNil(PrivacyVocabulary.collectedDataTypesByIdentifier[
            "NSPrivacyCollectedDataTypePhotosorVideos"])
        XCTAssertNil(PrivacyVocabulary.collectedDataTypesByIdentifier[
            "NSPrivacyCollectedDataTypePhotosOrVideos"],
            "the uppercase-Or spelling is not a documented identifier")
    }

    // MARK: - Display maps stay in sync with the vocabulary

    func testDisplayNameMapsDeriveFromVocabulary() {
        XCTAssertEqual(PrivacyManifest.collectedDataTypeNames.count, 35)
        XCTAssertEqual(PrivacyManifest.collectedDataPurposeNames.count, 6)
        XCTAssertEqual(PrivacyManifest.collectedDataTypeNames["NSPrivacyCollectedDataTypeName"], "Name")
        XCTAssertEqual(PrivacyManifest.collectedDataPurposeNames[
            "NSPrivacyCollectedDataTypePurposeOther"], "Other Purposes")
    }
}
