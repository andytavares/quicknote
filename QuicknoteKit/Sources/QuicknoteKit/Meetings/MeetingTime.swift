/// Shared clock text for positions inside a recording.
public enum MeetingTime {
    /// "18:32" under an hour, "1:02:05" from an hour on. Negative input shows as zero.
    public static func format(ms: Int) -> String {
        let totalSeconds = max(ms, 0) / 1_000
        let (hours, minutes, seconds) = (totalSeconds / 3_600, totalSeconds / 60 % 60, totalSeconds % 60)
        let minutesAndSeconds = "\(pad(minutes, 2)):\(pad(seconds, 2))"
        return hours > 0 ? "\(hours):\(minutesAndSeconds)" : minutesAndSeconds
    }

    private static func pad(_ value: Int, _ width: Int) -> String {
        let digits = String(value)
        return String(repeating: "0", count: max(width - digits.count, 0)) + digits
    }
}
