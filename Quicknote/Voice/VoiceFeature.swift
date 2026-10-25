/// Hold to talk (S05). Owned by the Voice unit.
enum VoiceFeature {
    /// When set, the transcript on release goes here instead of becoming a note (Snap voice captions).
    static var captionTarget: ((String) -> Void)? {
        get { holdToTalk.captionTarget }
        set { holdToTalk.captionTarget = newValue }
    }

    private static let holdToTalk = HoldToTalk(services: .live, presenter: HoldToTalkHUD())

    static func startHoldToTalk() { holdToTalk.keyDown() }
    static func stopHoldToTalk() { holdToTalk.keyUp() }
}
