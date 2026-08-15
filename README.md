# bundlefacts

Bundle, Mach-O and privacy-manifest reading for Apple apps — the shared
facts layer for privacykey tools.

`BundleFacts` answers three questions about an `.app` on disk, from file
bytes alone, without shelling out to `nm`, `objdump`, `codesign` or anything
else:

1. **What is this bundle?** `AppBundle.resolve(bundleURL:)` recognises the
   three bundle shapes (standard macOS `Contents/` layout, flat iOS layout,
   and iOS-app-on-Apple-Silicon wrapper bundles), locates the executable and
   `Info.plist`, and classifies failures into an exportable taxonomy
   (`ScanFailureKind`) instead of raw error strings.
2. **What does its binary reference?** `MachOInspector` parses thin and
   universal Mach-O files directly: architectures, load-command facts
   (rpaths, dylibs, encryption, min OS / SDK / platform), and the
   undefined-external symbol table — the imports. Every fat slice is parsed;
   a dylib or symbol present in only one slice of a universal binary is
   still reported.
3. **What does its privacy manifest say?** `PrivacyManifestReader` parses
   `PrivacyInfo.xcprivacy` (XML or binary plist) leniently — it reports what
   the file says, even when what it says is invalid — and cross-checks the
   declared required-reason API categories against the binary's imported
   symbols.

Apple's vocabularies ship as data, verified against developer.apple.com
(August 2026):

- `RequiredReasonAPIs` — the 5 accessed-API categories, their 30 symbols
  with exact Mach-O nlist spellings (`_stat`, `_stat$INODE64`,
  `_OBJC_CLASS_$_NSUserDefaults`, …), and the 17 reason codes with their
  category scoping and restriction notes.
- `PrivacyVocabulary` — the 4 top-level manifest keys with their value
  rules, the 35 collected-data-type values across 16 label categories
  (including the irregular `NSPrivacyCollectedDataTypePhotosorVideos`
  spelling), and the 6 purpose values.
- `AppleSDKList` — the 86 "commonly used third-party SDKs", with combined
  entries ("BoringSSL / openssl_grpc") split into canonical + alternative
  names, a matcher for framework/XCFramework directory names and SPM
  checkout names (case-, hyphen- and underscore-insensitive, exact match
  only), and the enforcement-rule constants: privacy manifest required for
  listed SDKs since 2025-02-12 (ITMS-91061), signature required when
  consumed as a binary dependency (ITMS-91065).

## The two-gate purity story

This package is a foundation other tools stand on, so CI enforces two
invariants on every push:

- **Zero package dependencies.** `swift package show-dependencies` must
  print an empty tree, and no `Package.resolved` may exist. Foundation and
  XCTest only.
- **iOS cross-build.** The library must compile for
  `generic/platform=iOS`, keeping macOS-only imports out. The same facts
  layer serves macOS auditing tools and iOS-side tooling.

Run both locally with `just lint`.

## Public API surface

| Type | What it gives you |
| --- | --- |
| `AppBundle` | Resolved bundle: layout, platform, executable URL, architectures, layout-aware locations (`resourcesURL`, `frameworksURL`, `masReceiptURL`, …) |
| `AppBundleError` / `ScanFailureKind` | Failure taxonomy for batch scans |
| `MachOInspector.architectures(of:)` | Arch names for thin and fat binaries |
| `MachOInspector.loadCommands(of:)` | Rpaths, dylibs, encryption flag, stripped heuristic, min OS / SDK / platform, slice count — merged across all slices |
| `MachOInspector.importedSymbols(of:limit:)` | Undefined-external symbols, de-duplicated union across all slices |
| `PrivacyManifestReader.read(for:)` / `read(at:)` / `readAll(for:)` | Parsed `PrivacyManifest` from a bundle or a file |
| `PrivacyManifestReader.crossCheck(manifest:importedSymbols:)` | Declared-but-unused / used-but-undeclared categories with symbol evidence |
| `PrivacyManifestReader.trackingCrossCheck(manifest:trackerSDKNames:observedTrackerDomains:)` | Stated tracking vs observed tracker signals |
| `RequiredReasonAPIs` | Required-reason vocabulary as data, with exact-match symbol lookup |
| `PrivacyVocabulary` | Manifest-key, data-type and purpose vocabularies as data |

## Scope, honestly

- Symbol-based detection sees what the symbol table sees. APIs reached only
  through `objc_msgSend` (e.g. `ProcessInfo.systemUptime`) leave a class
  reference, not a per-member import, so those matches are class-level and
  can over-report. Swift-mangled accessor symbols are not enumerated.
- The manifest reader is a parser, not a linter. It preserves invalid
  values verbatim (unknown accessed-API categories keep their raw string)
  precisely so a linter built on top can name them; it does not judge them.
- No signature checks, no entitlements, no notarization, no network. Facts
  from bytes on disk only.

## Using it

```swift
.package(url: "https://github.com/privacykey/bundlefacts.git", from: "0.1.0")
```

```swift
import BundleFacts

let bundle = try AppBundle.resolve(bundleURL: url)
let symbols = Set(MachOInspector.importedSymbols(of: bundle.executableURL))
if let manifest = PrivacyManifestReader.read(for: bundle) {
    let check = PrivacyManifestReader.crossCheck(manifest: manifest,
                                                 importedSymbols: symbols)
    for miss in check.usedButUndeclared {
        print("\(miss.category.label): \(miss.evidence.joined(separator: ", "))")
    }
}
```

## License

Apache-2.0. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
