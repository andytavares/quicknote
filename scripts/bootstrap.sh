#!/bin/sh
# Installs XcodeGen if needed, generates Quicknote.xcodeproj and resolves packages.
set -eu
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || brew install xcodegen
xcodegen generate --quiet
xcodebuild -resolvePackageDependencies -project Quicknote.xcodeproj -scheme Quicknote \
  -clonedSourcePackagesDirPath build/SourcePackages >/dev/null
echo "Ready. Open Quicknote.xcodeproj or run scripts/test.sh"
