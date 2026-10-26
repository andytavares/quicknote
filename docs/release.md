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

Merging to `main` releases automatically. When the `test` workflow passes on `main`, `.github/workflows/release.yml` bumps the patch number of the latest GitHub release (1.0.0 → 1.0.1), runs `scripts/release.sh` on that version and publishes the DMG and `appcast.xml` as release `vX.Y.Z`. For a minor or major bump, publish that release by hand once (below); automatic patch releases continue from it.

### Repository secrets (one time)

Settings › Secrets and variables › Actions › New repository secret:

| Secret | Value |
|---|---|
| `DEVELOPER_ID_P12` | The Developer ID Application certificate and key, exported from Keychain Access as `.p12`, then `base64 -i cert.p12 \| pbcopy` |
| `DEVELOPER_ID_P12_PASSWORD` | The password you set on that export |
| `DEVELOPER_ID_APPLICATION` | `Developer ID Application: Your Name (TEAMID)` |
| `DEVELOPMENT_TEAM` | Your 10-character team ID |
| `APPLE_ID` | The Apple ID email used for notarization |
| `APPLE_APP_PASSWORD` | An app-specific password from appleid.apple.com |
| `SPARKLE_PRIVATE_KEY` | Output of `generate_keys -x key.txt` (then delete `key.txt`) |

### By hand

```sh
export DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)"
export DEVELOPMENT_TEAM=TEAMID
export NOTARY_PROFILE=quicknote-notary
export RELEASE_DOWNLOAD_URL_PREFIX="https://github.com/andytavares/quicknote/releases/download/v1.0.0/"
scripts/release.sh 1.0.0
gh release create v1.0.0 releases/Quicknote-1.0.0.dmg releases/appcast.xml
```

The script checks every prerequisite first, then: archives Release with hardened runtime and your Developer ID, builds `Quicknote-1.0.0.dmg`, notarizes (`notarytool submit --wait`), staples, validates, signs the update and regenerates `releases/appcast.xml` (`generate_appcast`). The update key comes from `SPARKLE_PRIVATE_KEY` when set, otherwise from your keychain. The version number is passed to `xcodebuild`; no files are edited. The build number is a timestamp.

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
