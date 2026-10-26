# 2. macOS 26 and later

**Decision:** the minimum is macOS 26. It was macOS 27 until October 2026.

**Why:** one speech engine (`SpeechAnalyzer` + `SpeechTranscriber`, on-device) and Apple's on-device Foundation Models for meeting summaries, with no fallback code paths. Both shipped in macOS 26, so 26 keeps that rule and reaches Macs not yet on 27.

**Cost:** Macs that cannot run macOS 26 cannot run Quicknote. Code avoids APIs new in macOS 27, such as `AVAudioPCMBuffer(copying:)`.
