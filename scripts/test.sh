#!/bin/sh
# Runs every test: the QuicknoteKit package, then the app.
# DERIVED_DATA lets parallel checkouts build without sharing a build folder.
set -eu
cd "$(dirname "$0")/.."
DERIVED_DATA="${DERIVED_DATA:-build/DerivedData}"
swift test --package-path QuicknoteKit --scratch-path "build/kit-$(basename "$DERIVED_DATA")"
xcodegen generate --quiet
# The app tests can only launch on macOS 27+; older hosts (GitHub's runners today) build them without running.
action=test
destination='platform=macOS'
if [ "$(sw_vers -productVersion | cut -d. -f1)" -lt 27 ]; then
  action=build-for-testing
  destination='generic/platform=macOS'
  echo "macOS $(sw_vers -productVersion) < 27: building the app tests, not running them."
fi
xcodebuild "$action" -quiet -project Quicknote.xcodeproj -scheme Quicknote -destination "$destination" \
  -derivedDataPath "$DERIVED_DATA" -clonedSourcePackagesDirPath build/SourcePackages
