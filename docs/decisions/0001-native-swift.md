# 1. Native Swift app

**Decision:** SwiftUI with AppKit where SwiftUI falls short (panels, edge windows, the text editor).

**Why:** nearly every feature is a macOS integration (global shortcuts, non-activating panels, Accessibility, ScreenCaptureKit, Core Audio, Speech, EventKit). Tauri or Electron would need native plugins for each one anyway.

**Rejected:** Tauri 2, Electron.
