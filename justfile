# List available commands
default:
    @just --list

# Build the BundleFacts library
[group("dev")]
build:
    swift build

# Run the full test suite (same as CI)
[group("dev")]
test:
    swift test

# Run both purity gates: zero package dependencies + iOS cross-build
[group("dev")]
lint:
    test ! -e Package.resolved
    test "$(swift package show-dependencies)" = "No external dependencies found"
    xcodebuild -scheme bundlefacts -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build

# Remove SPM build output
[group("dev")]
clean:
    rm -rf .build
