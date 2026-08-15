import Foundation

/// Apple's "commonly used third-party SDKs" list as data: the 86 SDKs whose
/// presence in an upload triggers App Store Connect's privacy-manifest and
/// signature checks, with a matcher that maps the names actually seen on
/// disk — framework/XCFramework directory names, SPM checkout names — onto
/// list entries.
///
/// Source: https://developer.apple.com/support/third-party-SDK-requirements/
/// (verified 2026-08).
public enum AppleSDKList {

    /// One listed SDK. Apple publishes some entries under two names
    /// ("BoringSSL / openssl_grpc"); those split into a canonical name plus
    /// alternatives, and the matcher treats every name as equal evidence
    /// for the entry.
    public struct Entry: Sendable, Hashable {
        /// The first name Apple publishes for the SDK, e.g. "BoringSSL".
        public let canonicalName: String
        /// The remaining published names for the same SDK, e.g.
        /// ["openssl_grpc"]. Empty for entries published under one name.
        public let alternativeNames: [String]

        public init(canonicalName: String, alternativeNames: [String] = []) {
            self.canonicalName = canonicalName
            self.alternativeNames = alternativeNames
        }

        /// Canonical name first, then alternatives, in published order.
        public var allNames: [String] { [canonicalName] + alternativeNames }
    }

    /// The exact published list, in Apple's order.
    public static let entries: [Entry] = [
        Entry(canonicalName: "Abseil"),
        Entry(canonicalName: "AFNetworking"),
        Entry(canonicalName: "Alamofire"),
        Entry(canonicalName: "AppAuth"),
        Entry(canonicalName: "BoringSSL", alternativeNames: ["openssl_grpc"]),
        Entry(canonicalName: "Capacitor"),
        Entry(canonicalName: "Charts"),
        Entry(canonicalName: "connectivity_plus"),
        Entry(canonicalName: "Cordova"),
        Entry(canonicalName: "device_info_plus"),
        Entry(canonicalName: "DKImagePickerController"),
        Entry(canonicalName: "DKPhotoGallery"),
        Entry(canonicalName: "FBAEMKit"),
        Entry(canonicalName: "FBLPromises"),
        Entry(canonicalName: "FBSDKCoreKit"),
        Entry(canonicalName: "FBSDKCoreKit_Basics"),
        Entry(canonicalName: "FBSDKLoginKit"),
        Entry(canonicalName: "FBSDKShareKit"),
        Entry(canonicalName: "file_picker"),
        Entry(canonicalName: "FirebaseABTesting"),
        Entry(canonicalName: "FirebaseAuth"),
        Entry(canonicalName: "FirebaseCore"),
        Entry(canonicalName: "FirebaseCoreDiagnostics"),
        Entry(canonicalName: "FirebaseCoreExtension"),
        Entry(canonicalName: "FirebaseCoreInternal"),
        Entry(canonicalName: "FirebaseCrashlytics"),
        Entry(canonicalName: "FirebaseDynamicLinks"),
        Entry(canonicalName: "FirebaseFirestore"),
        Entry(canonicalName: "FirebaseInstallations"),
        Entry(canonicalName: "FirebaseMessaging"),
        Entry(canonicalName: "FirebaseRemoteConfig"),
        Entry(canonicalName: "Flutter"),
        Entry(canonicalName: "flutter_inappwebview"),
        Entry(canonicalName: "flutter_local_notifications"),
        Entry(canonicalName: "fluttertoast"),
        Entry(canonicalName: "FMDB"),
        Entry(canonicalName: "geolocator_apple"),
        Entry(canonicalName: "GoogleDataTransport"),
        Entry(canonicalName: "GoogleSignIn"),
        Entry(canonicalName: "GoogleToolboxForMac"),
        Entry(canonicalName: "GoogleUtilities"),
        Entry(canonicalName: "grpcpp"),
        Entry(canonicalName: "GTMAppAuth"),
        Entry(canonicalName: "GTMSessionFetcher"),
        Entry(canonicalName: "hermes"),
        Entry(canonicalName: "image_picker_ios"),
        Entry(canonicalName: "IQKeyboardManager"),
        Entry(canonicalName: "IQKeyboardManagerSwift"),
        Entry(canonicalName: "Kingfisher"),
        Entry(canonicalName: "leveldb"),
        Entry(canonicalName: "Lottie"),
        Entry(canonicalName: "MBProgressHUD"),
        Entry(canonicalName: "nanopb"),
        Entry(canonicalName: "OneSignal"),
        Entry(canonicalName: "OneSignalCore"),
        Entry(canonicalName: "OneSignalExtension"),
        Entry(canonicalName: "OneSignalOutcomes"),
        Entry(canonicalName: "OpenSSL"),
        Entry(canonicalName: "OrderedSet"),
        Entry(canonicalName: "package_info"),
        Entry(canonicalName: "package_info_plus"),
        Entry(canonicalName: "path_provider"),
        Entry(canonicalName: "path_provider_ios"),
        Entry(canonicalName: "Promises"),
        Entry(canonicalName: "Protobuf"),
        Entry(canonicalName: "Reachability"),
        Entry(canonicalName: "RealmSwift"),
        Entry(canonicalName: "RxCocoa"),
        Entry(canonicalName: "RxRelay"),
        Entry(canonicalName: "RxSwift"),
        Entry(canonicalName: "SDWebImage"),
        Entry(canonicalName: "share_plus"),
        Entry(canonicalName: "shared_preferences_ios"),
        Entry(canonicalName: "SnapKit"),
        Entry(canonicalName: "sqflite"),
        Entry(canonicalName: "Starscream"),
        Entry(canonicalName: "SVProgressHUD"),
        Entry(canonicalName: "SwiftyGif"),
        Entry(canonicalName: "SwiftyJSON"),
        Entry(canonicalName: "Toast"),
        Entry(canonicalName: "UnityFramework"),
        Entry(canonicalName: "url_launcher"),
        Entry(canonicalName: "url_launcher_ios"),
        Entry(canonicalName: "video_player_avfoundation"),
        Entry(canonicalName: "wakelock"),
        Entry(canonicalName: "webview_flutter_wkwebview"),
    ]

    // MARK: - Matching

    /// The form a name is compared under: one trailing ".framework" or
    /// ".xcframework" is stripped (case-insensitively), then case, hyphens
    /// and underscores are all ignored — "flutter-local-notifications" and
    /// "flutter_local_notifications.framework" normalise identically.
    /// `name` must be a single path component, not a path.
    public static func normalized(_ name: String) -> String {
        var stem = name[...]
        let lowered = name.lowercased()
        for suffix in [".xcframework", ".framework"] where lowered.hasSuffix(suffix) {
            stem = stem.dropLast(suffix.count)
            break
        }
        return stem.lowercased().filter { $0 != "-" && $0 != "_" }
    }

    /// Normalised name → entry, covering canonical and alternative names.
    /// Normalised spellings must never collide across entries — the test
    /// suite enforces that, so a list update cannot silently shadow one
    /// entry with another.
    private static let entriesByNormalizedName: [String: Entry] = {
        var out: [String: Entry] = [:]
        for entry in entries {
            for name in entry.allNames {
                out[normalized(name)] = entry
            }
        }
        return out
    }()

    /// The listed SDK a framework/bundle directory name or SPM checkout
    /// name refers to, or nil when it is not on the list. Matching is exact
    /// on the normalised form — no prefix or substring matching, so
    /// "AlamofireImage" does not match "Alamofire".
    public static func entry(matching name: String) -> Entry? {
        entriesByNormalizedName[normalized(name)]
    }

    /// Whether `name` refers to a listed SDK, under the same normalisation
    /// as `entry(matching:)`.
    public static func isListed(_ name: String) -> Bool {
        entry(matching: name) != nil
    }

    // MARK: - Enforcement rules

    /// The obligations Apple attaches to the list, as constants a report
    /// can cite.
    public enum Rules {
        /// From this day, App Store Connect rejects uploads in which a
        /// listed SDK ships without its own PrivacyInfo.xcprivacy.
        public static let manifestRequiredFrom = DateComponents(year: 2025, month: 2, day: 12)

        /// App Store Connect code for a listed SDK that is missing its
        /// privacy manifest.
        public static let missingManifestCode = "ITMS-91061"

        /// A listed SDK consumed as a binary dependency (prebuilt framework
        /// or XCFramework) must also carry a code signature; App Store
        /// Connect flags the gap under this code. SDKs built from source
        /// are outside this rule.
        public static let missingSignatureCode = "ITMS-91065"
    }
}
