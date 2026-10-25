import Foundation

/// The recorder's phase and clock. Elapsed time stops while paused and once stopped.
struct RecorderTimeline {
    enum Phase: Equatable { case idle, recording, paused, finishing }

    private(set) var phase = Phase.idle
    private var startedAt = Date.distantPast
    private var stoppedClockAt: Date?
    private var pausedTotal: TimeInterval = 0

    var canBookmark: Bool { phase == .recording }

    mutating func start(at date: Date) -> Bool {
        guard phase == .idle else { return false }
        self = RecorderTimeline(phase: .recording, startedAt: date)
        return true
    }

    mutating func pause(at date: Date) -> Bool {
        guard phase == .recording else { return false }
        phase = .paused
        stoppedClockAt = date
        return true
    }

    mutating func resume(at date: Date) -> Bool {
        guard phase == .paused, let pausedAt = stoppedClockAt else { return false }
        pausedTotal += date.timeIntervalSince(pausedAt)
        stoppedClockAt = nil
        phase = .recording
        return true
    }

    mutating func stop(at date: Date) -> Bool {
        guard phase == .recording || phase == .paused else { return false }
        stoppedClockAt = stoppedClockAt ?? date
        phase = .finishing
        return true
    }

    mutating func finished() { self = RecorderTimeline() }

    func elapsedMs(at date: Date) -> Int {
        guard phase != .idle else { return 0 }
        let clock = stoppedClockAt ?? date
        return max(0, Int((clock.timeIntervalSince(startedAt) - pausedTotal) * 1_000))
    }

    private init(phase: Phase, startedAt: Date) {
        self.phase = phase
        self.startedAt = startedAt
    }

    init() {}
}
