import SwiftUI

/// Places views left to right at their natural size and starts a new row when the next one does not fit.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rows = Self.rows(widths: sizes.map(\.width), maxWidth: proposal.width ?? .infinity, spacing: spacing)
        let width = rows.map { row in row.map { sizes[$0].width }.reduce(0, +) + spacing * CGFloat(row.count - 1) }
        let height = rows.map { row in row.map { sizes[$0].height }.max() ?? 0 }.reduce(0, +)
        return CGSize(width: width.max() ?? 0, height: height + spacing * CGFloat(max(rows.count - 1, 0)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var top = bounds.minY
        for row in Self.rows(widths: sizes.map(\.width), maxWidth: bounds.width, spacing: spacing) {
            let height = row.map { sizes[$0].height }.max() ?? 0
            var left = bounds.minX
            for index in row {
                let origin = CGPoint(x: left, y: top + (height - sizes[index].height) / 2)
                subviews[index].place(at: origin, proposal: ProposedViewSize(sizes[index]))
                left += sizes[index].width + spacing
            }
            top += height + spacing
        }
    }

    /// Index ranges of the items on each row.
    static func rows(widths: [CGFloat], maxWidth: CGFloat, spacing: CGFloat) -> [Range<Int>] {
        var rows: [Range<Int>] = []
        var start = 0
        var rowWidth: CGFloat = 0
        for (index, width) in widths.enumerated() {
            if index > start && rowWidth + spacing + width > maxWidth {
                rows.append(start..<index)
                (start, rowWidth) = (index, width)
            } else {
                rowWidth += (index > start ? spacing : 0) + width
            }
        }
        if start < widths.count { rows.append(start..<widths.count) }
        return rows
    }
}
