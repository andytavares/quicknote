# Releasing Quicknote

Quicknote is free. It is shipped as a Developer ID signed, notarized DMG outside the Mac App Store ([decision 8](decisions/0008-developer-id-distribution.md)) and updates itself with Sparkle 2.

## One-time setup

1. **Apple Developer Program.** Join it (paid, yearly). Notarization needs it even for a free app.
2. **Developer ID certificate.** Xcode > Settings > Accounts > Manage Certificates > `+` > Developer ID Application. Note its name: `security find-identity -v -p codesigning`.
3. **Notary credentials.** Create an app-specific password at appleid.apple.com, then:
   `xcrun notarytool store-credentials quicknote-notary --apple-id YOU --team-id TEAMID`
4. **Update signing key.** Run `build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys` (build once first so the tools exist). The private key stays in your login keychain; back it up with `generate_keys -x`. The public key is already in `Quicknote/Resources/Info.plist` (`SUPublicEDKey`); a new key would stop installed copies from updating.
5. **Hosting.** `SUFeedURL` is `https://github.com/andytavares/quicknote/releases/latest/download/appcast.xml`, so each release uploads its DMG and `appcast.xml` as assets. The repo must stay public for downloads and updates to work.

## Each release

```sh
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
export DEVELOPMENT_TEAM=TEAMID
export NOTARY_PROFILE=quicknote-notary
export RELEASE_DOWNLOAD_URL_PREFIX="https://github.com/andytavares/quicknote/releases/download/v1.0.0/"
scripts/release.sh 1.0.0
```

The script checks every prerequisite first, then: archives Release with hardened runtime and your Developer ID, builds `Quicknote-1.0.0.dmg`, notarizes (`notarytool submit --wait`), staples, validates, signs the update (`sign_update`) and regenerates `releases/appcast.xml` (`generate_appcast`). The version number is passed to `xcodebuild`; no files are edited. The build number is a timestamp.

Then publish: `gh release create v1.0.0 releases/Quicknote-1.0.0.dmg releases/appcast.xml`. `releases/` keeps older DMGs so the appcast keeps its history.

## How users get updates

New users download the DMG. Installed copies check the feed automatically (the "Check for updates automatically" setting, `SUEnableAutomaticChecks`) or from the menu: Check for updates. Debug builds never update; the menu item says so.

## Verify a build

```sh
xcrun stapler validate releases/Quicknote-1.0.0.dmg
spctl -a -t open --context context:primary-signature -vv releases/Quicknote-1.0.0.dmg
codesign -dv --verbose=4 /Applications/Quicknote.app   # look for flags=0x10000(runtime)
```

## Troubleshooting

- **Notarization "Invalid":** `xcrun notarytool log SUBMISSION_ID --keychain-profile quicknote-notary`. Usual causes: missing hardened runtime or secure timestamp, unsigned nested code.
- **`errSecInternalComponent` while signing:** unlock the keychain (`security unlock-keychain`).
- **Update not offered:** the new `CFBundleVersion` must be higher; the appcast must be reachable at `SUFeedURL`; the public key in the app must match the key that signed the DMG.
- **"Sparkle tools not found":** build the app once so SwiftPM downloads Sparkle into `build/SourcePackages`.
