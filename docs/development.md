# Development

## Requirements

- macOS 27 and Xcode 27 (Swift 6.4)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.46+ (`scripts/bootstrap.sh` installs it with Homebrew)

## First run

```sh
scripts/bootstrap.sh          # generates Quicknote.xcodeproj and resolves packages
open Quicknote.xcodeproj      # run the Quicknote scheme
```

`Quicknote.xcodeproj` is generated from `project.yml` and is not committed. Run `xcodegen generate` after adding or removing files.

## Checks

| What | Command | Notes |
|---|---|---|
| Lint | `scripts/lint.sh` | `swift format` with `.swift-format`. Auto-fix: `swift format format --in-place --recursive Quicknote QuicknoteKit/Sources QuicknoteKit/Tests QuicknoteTests` |
| Tests | `scripts/test.sh` | QuicknoteKit with `swift test`, then the app with `xcodebuild test` |
| Coverage | `scripts/coverage.sh` | Line coverage for both |
| One package test | `swift test --package-path QuicknoteKit --filter EntryClassifierTests` | Fastest loop for logic |

Set `DERIVED_DATA=build/<name>` to give a parallel checkout its own build folder.

## Where code goes

- **`QuicknoteKit/`** (Swift package): logic with no UI and no system permissions. Storage, search, sorting, repeats, formatting, export, action items, canvas model. Everything here is unit-tested with Swift Testing.
- **`Quicknote/`** (app target): windows, panels and system integrations (shortcuts, Speech, audio, ScreenCaptureKit, EventKit, Accessibility, notifications, sharing, Sparkle). One folder per feature; each folder's `<Feature>Feature.swift` is the entry point the menu and shortcuts call.

See [architecture.md](architecture.md) for how the pieces fit.

## Conventions

- Swift 6 language mode. App target code is `@MainActor` by default (`SWIFT_DEFAULT_ACTOR_ISOLATION`); QuicknoteKit is not.
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`).
- New schema changes are new migrations in `QuicknoteKit/Sources/QuicknoteKit/Store/AppDatabase.swift`. Never edit a shipped migration.
- Every feature has a page in [features/](features/) that is updated in the same commit as the code.
