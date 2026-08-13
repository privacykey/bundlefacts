import Foundation

/// The `PrivacyInfo.xcprivacy` vocabulary as data: the four top-level keys
/// with their value rules, the 35 collected-data-type values across Apple's
/// 16 label categories, and the 6 purpose values. A manifest linter can
/// validate against these tables without hard-coding a single string.
public enum PrivacyVocabulary {

    // MARK: - Top-level manifest keys

    /// One documented top-level manifest key and the rule its value must
    /// satisfy. Any other top-level key is undocumented.
    public struct ManifestKey: Sendable, Hashable {
        public let name: String
        /// What Apple requires of the value.
        public let valueRule: String

        public init(name: String, valueRule: String) {
            self.name = name
            self.valueRule = valueRule
        }
    }

    // https://developer.apple.com/documentation/bundleresources/app-privacy-configuration
    public static let manifestKeys: [ManifestKey] = [
        ManifestKey(
            name: "NSPrivacyTracking",
            valueRule: "Boolean. True means the app or SDK uses data for tracking as defined by App Tracking Transparency, and a non-empty NSPrivacyTrackingDomains array must also be present. A non-Boolean type here is invalid."),
        ManifestKey(
            name: "NSPrivacyTrackingDomains",
            valueRule: "Array of strings. Each entry is a bare domain or subdomain (e.g. analytics.example.com): no scheme, no path or query component, no trailing slash. Invalid combinations: NSPrivacyTracking=true with an empty array; NSPrivacyTracking=false with a non-empty array. Without ATT permission, network requests to these domains fail at runtime."),
        ManifestKey(
            name: "NSPrivacyCollectedDataTypes",
            valueRule: "Array of dictionaries, one per collected data type, required on all platforms including macOS. Each dictionary has exactly four sub-keys: NSPrivacyCollectedDataType (one of the 35 documented values), NSPrivacyCollectedDataTypePurposes (array drawn from the 6 documented purposes), NSPrivacyCollectedDataTypeLinked (Boolean), NSPrivacyCollectedDataTypeTracking (Boolean). Invented data-type or purpose strings are invalid."),
        ManifestKey(
            name: "NSPrivacyAccessedAPITypes",
            valueRule: "Array of dictionaries; applies to iOS, iPadOS, tvOS, visionOS and watchOS only (macOS is excluded). Each dictionary has exactly two keys: NSPrivacyAccessedAPIType (one of the 5 NSPrivacyAccessedAPICategory* values) and NSPrivacyAccessedAPITypeReasons (a non-empty array of reason codes belonging to that category). An empty NSPrivacyAccessedAPITypes array is invalid: delete the key instead."),
    ]

    /// The documented top-level key names, for "unknown key" checks.
    public static let manifestKeyNames: Set<String> =
        Set(manifestKeys.map(\.name))

    // MARK: - Collected data types

    /// One documented `NSPrivacyCollectedDataType` value.
    public struct CollectedDataType: Sendable, Hashable {
        /// The identifier as it appears in a manifest. Spellings are exact
        /// and one is irregular: `NSPrivacyCollectedDataTypePhotosorVideos`
        /// has a lowercase "or".
        public let identifier: String
        /// The App Store nutrition-label name, e.g. "Email Address".
        public let displayName: String
        /// The label category the type belongs to, e.g. "Contact Info".
        public let category: String

        public init(identifier: String, displayName: String, category: String) {
            self.identifier = identifier
            self.displayName = displayName
            self.category = category
        }
    }

    // https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype
    public static let collectedDataTypes: [CollectedDataType] = [
        // Contact Info
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeName",
                          displayName: "Name", category: "Contact Info"),
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeEmailAddress",
                          displayName: "Email Address", category: "Contact Info"),
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypePhoneNumber",
                          displayName: "Phone Number", category: "Contact Info"),
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypePhysicalAddress",
                          displayName: "Physical Address", category: "Contact Info"),
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeOtherUserContactInfo",
                          displayName: "Other User Contact Info", category: "Contact Info"),
        // Health & Fitness
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeHealth",
                          displayName: "Health", category: "Health & Fitness"),
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeFitness",
                          displayName: "Fitness", category: "Health & Fitness"),
        // Financial Info
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypePaymentInfo",
                          displayName: "Payment Info", category: "Financial Info"),
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeCreditInfo",
                          displayName: "Credit Info", category: "Financial Info"),
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeOtherFinancialInfo",
                          displayName: "Other Financial Info", category: "Financial Info"),
        // Location
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypePreciseLocation",
                          displayName: "Precise Location", category: "Location"),
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeCoarseLocation",
                          displayName: "Coarse Location", category: "Location"),
        // Sensitive Info
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeSensitiveInfo",
                          displayName: "Sensitive Info", category: "Sensitive Info"),
        // Contacts
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeContacts",
                          displayName: "Contacts", category: "Contacts"),
        // User Content
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeEmailsOrTextMessages",
                          displayName: "Emails or Text Messages", category: "User Content"),
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypePhotosorVideos",
                          displayName: "Photos or Videos", category: "User Content"),
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeAudioData",
                          displayName: "Audio Data", category: "User Content"),
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeGameplayContent",
                          displayName: "Gameplay Content", category: "User Content"),
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeCustomerSupport",
                          displayName: "Customer Support", category: "User Content"),
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeOtherUserContent",
                          displayName: "Other User Content", category: "User Content"),
        // Browsing History
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeBrowsingHistory",
                          displayName: "Browsing History", category: "Browsing History"),
        // Search History
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeSearchHistory",
                          displayName: "Search History", category: "Search History"),
        // Identifiers
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeUserID",
                          displayName: "User ID", category: "Identifiers"),
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeDeviceID",
                          displayName: "Device ID", category: "Identifiers"),
        // Purchases
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypePurchaseHistory",
                          displayName: "Purchase History", category: "Purchases"),
        // Usage Data
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeProductInteraction",
                          displayName: "Product Interaction", category: "Usage Data"),
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeAdvertisingData",
                          displayName: "Advertising Data", category: "Usage Data"),
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeOtherUsageData",
                          displayName: "Other Usage Data", category: "Usage Data"),
        // Diagnostics
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeCrashData",
                          displayName: "Crash Data", category: "Diagnostics"),
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypePerformanceData",
                          displayName: "Performance Data", category: "Diagnostics"),
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeOtherDiagnosticData",
                          displayName: "Other Diagnostic Data", category: "Diagnostics"),
        // Surroundings
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeEnvironmentScanning",
                          displayName: "Environment Scanning", category: "Surroundings"),
        // Body
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeHands",
                          displayName: "Hands", category: "Body"),
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeHead",
                          displayName: "Head", category: "Body"),
        // Other Data
        CollectedDataType(identifier: "NSPrivacyCollectedDataTypeOtherDataTypes",
                          displayName: "Other Data Types", category: "Other Data"),
    ]

    /// The 16 nutrition-label categories, in Apple's documentation order.
    public static let collectedDataCategories: [String] = [
        "Contact Info", "Health & Fitness", "Financial Info", "Location",
        "Sensitive Info", "Contacts", "User Content", "Browsing History",
        "Search History", "Identifiers", "Purchases", "Usage Data",
        "Diagnostics", "Surroundings", "Body", "Other Data",
    ]

    /// Identifier → data type, for exact-match validation.
    public static let collectedDataTypesByIdentifier: [String: CollectedDataType] =
        Dictionary(uniqueKeysWithValues: collectedDataTypes.map { ($0.identifier, $0) })

    // MARK: - Purposes

    /// One documented `NSPrivacyCollectedDataTypePurposes` value.
    public struct Purpose: Sendable, Hashable {
        /// The identifier as it appears in a manifest.
        public let identifier: String
        /// The App Store label, e.g. "Analytics".
        public let displayName: String

        public init(identifier: String, displayName: String) {
            self.identifier = identifier
            self.displayName = displayName
        }
    }

    // https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatypepurposes
    public static let purposes: [Purpose] = [
        Purpose(identifier: "NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising",
                displayName: "Third-Party Advertising"),
        Purpose(identifier: "NSPrivacyCollectedDataTypePurposeDeveloperAdvertising",
                displayName: "Developer's Advertising or Marketing"),
        Purpose(identifier: "NSPrivacyCollectedDataTypePurposeAnalytics",
                displayName: "Analytics"),
        Purpose(identifier: "NSPrivacyCollectedDataTypePurposeProductPersonalization",
                displayName: "Product Personalization"),
        Purpose(identifier: "NSPrivacyCollectedDataTypePurposeAppFunctionality",
                displayName: "App Functionality"),
        Purpose(identifier: "NSPrivacyCollectedDataTypePurposeOther",
                displayName: "Other Purposes"),
    ]

    /// Identifier → purpose, for exact-match validation.
    public static let purposesByIdentifier: [String: Purpose] =
        Dictionary(uniqueKeysWithValues: purposes.map { ($0.identifier, $0) })
}
