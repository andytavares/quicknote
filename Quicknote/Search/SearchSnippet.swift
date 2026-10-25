import Foundation
import QuicknoteKit
import SwiftUI

nonisolated enum SearchSnippet {
    /// Removes the match marks and bolds what they wrapped. An unclosed mark runs to the end.
    static func attributed(_ snippet: String) -> AttributedString {
        var result = AttributedString()
        var highlighted = false
        for character in snippet {
            if String(character) == SearchIndex.markStart {
                highlighted = true
            } else if String(character) == SearchIndex.markEnd {
                highlighted = false
            } else {
                var piece = AttributedString(String(character))
                if highlighted {
                    piece.inlinePresentationIntent = .stronglyEmphasized
                    piece.foregroundColor = .accentColor
                }
                result.append(piece)
            }
        }
        return result
    }

    static func plainText(_ snippet: String) -> String {
        snippet.replacingOccurrences(of: SearchIndex.markStart, with: "")
            .replacingOccurrences(of: SearchIndex.markEnd, with: "")
    }
}
