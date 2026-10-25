#!/bin/sh
# Runs every test: the QuicknoteKit package, then the app.
# DERIVED_DATA lets parallel checkouts build without sharing a build folder.
set -eu
cd "$(dirname "$0")/.."
DERIVED_DATA="${DERIVED_DATA:-build/DerivedData}"
swift test --package-path QuicknoteKit --scratch-path "build/kit-$(basename "$DERIVED_DATA")"
xcodegen generate --quiet
xcodebuild test -quiet -project Quicknote.xcodeproj -scheme Quicknote -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA" -clonedSourcePackagesDirPath build/SourcePackages
