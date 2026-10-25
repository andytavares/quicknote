import QuicknoteKit

/// Maps between transcript rows and positions in the recording.
enum TranscriptNavigator {
    static func startMs(ofRow row: Int, in segments: [TranscriptSegment]) -> Int? {
        segments.indices.contains(row) ? segments[row].startMs : nil
    }

    /// The last row that has started by `ms`, or nil before the first one.
    static func currentRow(atMs ms: Int, in segments: [TranscriptSegment]) -> Int? {
        segments.lastIndex { $0.startMs <= ms }
    }

    /// Where a mark sits on the scrubber, 0 to 1.
    static func fraction(ofMs ms: Int, durationMs: Int) -> Double {
        durationMs > 0 ? min(1, Double(ms) / Double(durationMs)) : 0
    }
}
