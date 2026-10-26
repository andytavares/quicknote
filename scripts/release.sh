#!/usr/bin/env bash
# Builds, signs, notarizes and publishes-ready a Quicknote release. See docs/release.md.
# Usage: scripts/release.sh VERSION
set -euo pipefail
cd "$(dirname "$0")/.."

die() { echo "release.sh: $*" >&2; exit 1; }

require_env() {
  [[ -n "${!1:-}" ]] || die "environment variable $1 is not set. $2"
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || die "$1 not found. $2"
}

check_prerequisites() {
  [[ "${1:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "usage: scripts/release.sh VERSION (for example 1.0.0)"
  require_env DEVELOPER_ID_APPLICATION 'Set it to the "Developer ID Application: Name (TEAMID)" certificate name.'
  require_env DEVELOPMENT_TEAM 'Set it to your 10-character Apple team ID.'
  require_env NOTARY_PROFILE 'Create one with: xcrun notarytool store-credentials.'
  require_env RELEASE_DOWNLOAD_URL_PREFIX 'Set it to the public folder the DMGs are hosted in, ending in /.'
  require_tool xcodebuild 'Install Xcode.'
  require_tool xcodegen 'Install with: brew install xcodegen.'
  require_tool hdiutil 'It ships with macOS.'
  require_tool xcrun 'Install the Xcode command line tools.'
  [[ -x "$SPARKLE_BIN/generate_appcast" && -x "$SPARKLE_BIN/sign_update" ]] \
    || die "Sparkle tools not found in $SPARKLE_BIN. Build once so Swift Package Manager fetches Sparkle."
  grep -q 'REPLACE_WITH_SPARKLE_PUBLIC_KEY' Quicknote/Resources/Info.plist \
    && die "SUPublicEDKey in Info.plist is still the placeholder. Run generate_keys and paste the public key."
  return 0
}

archive_and_export() {
  local version="$1"
  xcodegen generate >/dev/null
  xcodebuild archive -quiet -project Quicknote.xcodeproj -scheme Quicknote -configuration Release \
    -destination 'generic/platform=macOS' -archivePath "$WORK_DIR/Quicknote.xcarchive" \
    -derivedDataPath build/DerivedData -clonedSourcePackagesDirPath build/SourcePackages \
    MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$(date +%Y%m%d%H%M)" \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$DEVELOPER_ID_APPLICATION" \
    DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" ENABLE_HARDENED_RUNTIME=YES OTHER_CODE_SIGN_FLAGS="--timestamp"
  # Export, not copy: only the Developer ID export re-signs Sparkle's helpers (sparkle-project.org/documentation/sandboxing).
  cat > "$WORK_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>developer-id</string>
  <key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>$DEVELOPER_ID_APPLICATION</string>
  <key>teamID</key><string>$DEVELOPMENT_TEAM</string>
</dict></plist>
PLIST
  xcodebuild -exportArchive -quiet -archivePath "$WORK_DIR/Quicknote.xcarchive" \
    -exportOptionsPlist "$WORK_DIR/ExportOptions.plist" -exportPath "$WORK_DIR"
  codesign --verify --deep --strict "$WORK_DIR/Quicknote.app"
}

build_dmg() {
  local dmg="$1" staging="$WORK_DIR/dmg"
  mkdir -p "$staging"
  cp -R "$WORK_DIR/Quicknote.app" "$staging/"
  ln -s /Applications "$staging/Applications"
  hdiutil create -quiet -volname Quicknote -srcfolder "$staging" -ov -format UDZO "$dmg"
  codesign --sign "$DEVELOPER_ID_APPLICATION" --timestamp "$dmg"
}

notarize_and_staple() {
  local dmg="$1"
  xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$dmg"
  xcrun stapler validate "$dmg"
  spctl -a -t open --context context:primary-signature -vv "$dmg"
}

publish_appcast() {
  local dmg="$1"
  mkdir -p releases
  cp "$dmg" releases/
  if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
    # CI has no keychain entry for the update key; Sparkle reads it from stdin.
    echo "$SPARKLE_PRIVATE_KEY" | "$SPARKLE_BIN/generate_appcast" --ed-key-file - \
      --download-url-prefix "$RELEASE_DOWNLOAD_URL_PREFIX" releases
  else
    "$SPARKLE_BIN/sign_update" "$dmg"
    "$SPARKLE_BIN/generate_appcast" --download-url-prefix "$RELEASE_DOWNLOAD_URL_PREFIX" releases
  fi
}

main() {
  SPARKLE_BIN="build/SourcePackages/artifacts/sparkle/Sparkle/bin"
  check_prerequisites "${1:-}"
  local version="$1"
  WORK_DIR="$(mktemp -d)"
  trap 'rm -rf "$WORK_DIR"' EXIT
  local dmg="$WORK_DIR/Quicknote-$version.dmg"
  archive_and_export "$version"
  build_dmg "$dmg"
  notarize_and_staple "$dmg"
  publish_appcast "$dmg"
  echo "Done. Upload releases/Quicknote-$version.dmg and releases/appcast.xml."
}

main "$@"
