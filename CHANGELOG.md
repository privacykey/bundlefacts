# Changelog

Notable changes to bundlefacts. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-08-15

### Added

- `AppleSDKList` — Apple's "commonly used third-party SDKs" list as data:
  the 86 published entries in published order, with combined entries such as
  "BoringSSL / openssl_grpc" split into a canonical name plus alternatives;
  a matcher that resolves framework/XCFramework directory names and SPM
  checkout names case-insensitively, hyphen/underscore-insensitively, with
  exact (never prefix or substring) matching; and the enforcement-rule
  constants a report cites — privacy manifest required for listed SDKs
  since 2025-02-12 (ITMS-91061), code signature required when a listed SDK
  is consumed as a binary dependency (ITMS-91065).
- This changelog.

## [0.1.0] - 2026-08-14

Initial release.

### Added

- `AppBundle.resolve(bundleURL:)` — recognises the three bundle shapes
  (macOS `Contents/` layout, flat iOS, iOS-app-on-Apple-Silicon wrapper),
  locates the executable and `Info.plist`, and classifies failures into an
  exportable taxonomy (`ScanFailureKind`).
- `MachOInspector` — direct parsing of thin and universal Mach-O files:
  architectures, load-command facts (rpaths, dylibs, encryption, min OS /
  SDK / platform) and the undefined-external symbol table, across every fat
  slice.
- `PrivacyManifestReader` — lenient `PrivacyInfo.xcprivacy` parsing (XML and
  binary plist) plus cross-checking of declared required-reason API
  categories against the binary's imported symbols.
- `RequiredReasonAPIs` and `PrivacyVocabulary` — Apple's privacy
  vocabularies as data, verified against developer.apple.com (2026-08).
- CI with two purity gates: zero package dependencies and an iOS
  cross-build.
