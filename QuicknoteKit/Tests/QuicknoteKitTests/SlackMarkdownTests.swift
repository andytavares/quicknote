import Foundation
import Testing

@testable import QuicknoteKit

struct SlackMarkdownTests {
    private func styled(_ text: String, _ style: StyleSpan.Style) -> [String] {
        let nsText = text as NSString
        return SlackMarkdown.spans(in: text).filter { $0.style == style }
            .map { nsText.substring(with: $0.range) }
    }

    @Test func boldAndItalicCoverTheirMarks() {
        #expect(styled("a *bold* and _it_", .bold) == ["*bold*"])
        #expect(styled("a *bold* and _it_", .italic) == ["_it_"])
    }

    @Test func marksAreReportedAsMarkers() {
        #expect(styled("*x*", .marker) == ["*", "*"])
    }

    @Test func spaceInsideMarksIsNotStyled() {
        #expect(styled("2 * 3 * 4", .bold).isEmpty)
        #expect(styled("*bold *", .bold).isEmpty)
    }

    @Test func marksInsideWordsAreNotStyled() {
        #expect(styled("rename snake_case_name now", .italic).isEmpty)
        #expect(styled("2*3*4 is 24", .bold).isEmpty)
        #expect(styled("(see _this_) and *that*.", .italic) == ["_this_"])
        #expect(styled("(see _this_) and *that*.", .bold) == ["*that*"])
    }

    @Test func styleDoesNotSpanLines() {
        #expect(styled("*one\ntwo*", .bold).isEmpty)
    }

    @Test func rangesAreUTF16AfterEmoji() {
        let spans = SlackMarkdown.spans(in: "😀 *hi*").filter { $0.style == .bold }
        #expect(spans.map(\.range) == [NSRange(location: 3, length: 4)])
        #expect(styled("日本 *語* 🚀 _é_", .bold) == ["*語*"])
        #expect(styled("日本 *語* 🚀 _é_", .italic) == ["_é_"])
    }

    @Test func dashAtLineStartIsAListItem() {
        let text = "intro\n- one\nnot - this"
        let items = SlackMarkdown.spans(in: text).filter { $0.style == .listItem }
        #expect(items.map(\.range) == [NSRange(location: 6, length: 2)])
    }

    @Test func checkboxesAtLineStart() {
        let text = "[] a\n[ ] b\n[x] c\n- [x] d\nno [] here"
        let boxes = SlackMarkdown.spans(in: text).compactMap { span -> Bool? in
            if case .checkbox(let checked) = span.style { return checked }
            return nil
        }
        #expect(boxes == [false, false, true, true])
    }

    @Test func linksCarryTheirTitle() {
        let spans = SlackMarkdown.spans(in: "go [[ Pricing ]] now")
        let link = spans.first { $0.style == .link(title: "Pricing") }
        #expect(link?.range == NSRange(location: 3, length: 13))
        let markers = spans.filter { $0.style == .marker }.map(\.range)
        #expect(markers == [NSRange(location: 3, length: 2), NSRange(location: 14, length: 2)])
    }

    @Test func togglingCheckboxFlipsOnlyThatLine() {
        let text = "[] a\n- [x] b\n[ ] c"
        #expect(SlackMarkdown.togglingCheckbox(in: text, line: 0) == "[x] a\n- [x] b\n[ ] c")
        #expect(SlackMarkdown.togglingCheckbox(in: text, line: 1) == "[] a\n- [ ] b\n[ ] c")
        #expect(SlackMarkdown.togglingCheckbox(in: text, line: 2) == "[] a\n- [x] b\n[x] c")
    }

    @Test func togglingAfterEmojiAndOnPlainLineIsSafe() {
        #expect(SlackMarkdown.togglingCheckbox(in: "😀\n[] é", line: 1) == "😀\n[x] é")
        #expect(SlackMarkdown.togglingCheckbox(in: "plain", line: 0) == "plain")
        #expect(SlackMarkdown.togglingCheckbox(in: "plain", line: 5) == "plain")
    }

    // MARK: Standard Markdown

    @Test func hashesAtLineStartMakeHeadings() {
        let text = "# Title\n## Sub\n### Small\n#### four\n#nospace\nmid # no"
        #expect(styled(text, .heading(level: 1)) == ["# Title"])
        #expect(styled(text, .heading(level: 2)) == ["## Sub"])
        #expect(styled(text, .heading(level: 3)) == ["### Small"])
        #expect(styled("#nospace", .heading(level: 1)).isEmpty)
        #expect(styled("# Title", .marker) == ["# "])
    }

    @Test func doubleStarsAreBoldWithBothMarksDimmed() {
        #expect(styled("a **bold** b", .bold) == ["**bold**"])
        #expect(styled("a **bold** b", .marker) == ["**", "**"])
        #expect(styled("2**3**4", .bold).isEmpty)
    }

    @Test func tildesStrikeAndBackticksMarkCode() {
        #expect(styled("was ~~old~~ now", .strikethrough) == ["~~old~~"])
        #expect(styled("run `make test` now", .code) == ["`make test`"])
        #expect(styled("run `make test` now", .marker) == ["`", "`"])
    }

    @Test func codeHidesFormattingInside() {
        #expect(styled("`*not bold*`", .bold).isEmpty)
        #expect(styled("`snake_case_`", .italic).isEmpty)
    }

    @Test func starPlusAndNumbersStartListItems() {
        let text = "* star\n+ plus\n12. twelve\n*bold*\n3.no"
        let nsText = text as NSString
        let items = SlackMarkdown.spans(in: text).filter { $0.style == .listItem }.map {
            nsText.substring(with: $0.range)
        }
        #expect(items == ["* ", "+ ", "12. "])
    }

    @Test func checkboxAfterStarIsACheckbox() {
        let spans = SlackMarkdown.spans(in: "* [x] done")
        #expect(spans.contains { $0.style == .checkbox(checked: true) })
    }

    @Test func enterContinuesListsAndCheckboxes() {
        #expect(SlackMarkdown.continuation(after: "- milk") == .next("- "))
        #expect(SlackMarkdown.continuation(after: "* milk") == .next("* "))
        #expect(SlackMarkdown.continuation(after: "9. milk") == .next("10. "))
        #expect(SlackMarkdown.continuation(after: "[x] milk") == .next("[ ] "))
        #expect(SlackMarkdown.continuation(after: "- [x] milk") == .next("- [ ] "))
        #expect(SlackMarkdown.continuation(after: "  - nested") == .next("  - "))
        #expect(SlackMarkdown.continuation(after: "plain") == nil)
    }

    @Test func enterOnAnEmptyItemEndsTheList() {
        #expect(SlackMarkdown.continuation(after: "- ") == .end)
        #expect(SlackMarkdown.continuation(after: "[ ] ") == .end)
        #expect(SlackMarkdown.continuation(after: "3. ") == .end)
    }
}
