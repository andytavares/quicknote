import SwiftUI

extension Color {
    /// Notes and calendars store colours as `#RRGGBB`; anything else is grey.
    nonisolated init(hex: String) {
        let digits = UInt32(hex.dropFirst(), radix: 16) ?? 0x808080
        self.init(
            red: Double((digits >> 16) & 0xFF) / 255, green: Double((digits >> 8) & 0xFF) / 255,
            blue: Double(digits & 0xFF) / 255)
    }
}
