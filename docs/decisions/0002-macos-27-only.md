# 2. macOS 27 and later only

**Decision:** the minimum is the latest macOS (27).

**Why:** one speech engine (`SpeechAnalyzer` + `SpeechTranscriber`, on-device) and Apple's on-device Foundation Models for meeting summaries, with no fallback code paths.

**Cost:** Macs that cannot run macOS 27 cannot run Quicknote.
