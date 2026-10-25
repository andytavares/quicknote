#!/bin/sh
# Prints line coverage for QuicknoteKit (logic) and the Quicknote app target.
set -eu
cd "$(dirname "$0")/.."
swift test --package-path QuicknoteKit --scratch-path build/kit-coverage --enable-code-coverage >/dev/null
PROFILE="$(swift test --package-path QuicknoteKit --scratch-path build/kit-coverage --show-codecov-path)"
BIN="build/kit-coverage/debug/QuicknoteKitPackageTests.xctest/Contents/MacOS/QuicknoteKitPackageTests"
echo "QuicknoteKit:"
xcrun llvm-cov report "$BIN" -instr-profile "$(dirname "$PROFILE")/default.profdata" \
  -ignore-filename-regex '(\.build|build/|Tests/)' | tail -1
xcodegen generate --quiet
rm -rf build/coverage.xcresult
xcodebuild test -quiet -project Quicknote.xcodeproj -scheme Quicknote -destination 'platform=macOS' \
  -derivedDataPath build/DerivedData -clonedSourcePackagesDirPath build/SourcePackages \
  -enableCodeCoverage YES -resultBundlePath build/coverage.xcresult
echo "Quicknote app:"
xcrun xccov view --report --only-targets build/coverage.xcresult
