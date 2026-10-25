import QuicknoteKit
import SwiftUI

/// "Slack · #product-launch": the app, and for browsers the site, a note is captured in.
struct ContextChip: View {
    let context: CapturedContext

    var body: some View {
        let name = [context.appName, context.siteHost].compactMap { $0 }.joined(separator: " · ")
        Text(name)
            .font(.caption)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(.quaternary, in: Capsule())
            .accessibilityLabel("Captured in \(name)")
    }
}
