import AppKit
import SwiftUI

/// A plain-text editor whose text is centered both ways and automatically sized to fill the note,
/// the way a sticky note reads: short thoughts big, longer ones smaller.
struct NoteTextView: NSViewRepresentable {
    @Binding var text: String
    let font: NoteFont
    let textColor: NSColor

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = false
        scroll.borderType = .noBorder
        scroll.contentView.postsFrameChangedNotifications = true

        let textView = CenteredTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.string = text
        scroll.documentView = textView

        context.coordinator.observer = NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification, object: scroll.contentView, queue: .main
        ) { [weak textView] _ in textView?.refit() }
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? CenteredTextView else { return }
        context.coordinator.parent = self
        if textView.string != text { textView.string = text }
        textView.noteFont = font
        textView.noteTextColor = textColor
        textView.refit()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteTextView
        var observer: NSObjectProtocol?

        init(_ parent: NoteTextView) { self.parent = parent }
        deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? CenteredTextView else { return }
            parent.text = textView.string
            textView.refit()
        }
    }
}

final class CenteredTextView: NSTextView {
    var noteFont = NoteFont.bold
    var noteTextColor = NSColor.black

    private let padding = CGSize(width: 16, height: 34)
    private let largestFontSize: CGFloat = 40
    private let minFontSize: CGFloat = 13

    /// Picks the largest font size whose wrapped text fits the note, then re-centers vertically.
    func refit() {
        guard let scroll = enclosingScrollView else { return }
        let visible = scroll.contentSize
        guard visible.width > 0, visible.height > 0 else { return }

        let availableWidth = max(visible.width - padding.width * 2, 40)
        let availableHeight = max(visible.height - padding.height * 2, 40)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let sample = (string.isEmpty ? "Ag" : string) as NSString
        let words = (string.isEmpty ? "Ag" : string).split(whereSeparator: { $0.isWhitespace }).map(String.init)
        var size = largestFontSize
        while size > minFontSize {
            let font = noteFont.nsFont(size: size)
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .paragraphStyle: paragraph]
            // Never break a word across lines: the longest word has to fit on one line...
            let widest = words.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
            // ...and the wrapped text as a whole has to fit the height.
            let rect = sample.boundingRect(
                with: NSSize(width: availableWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes)
            if widest <= availableWidth, rect.height <= availableHeight { break }
            size -= 1
        }

        let chosen = noteFont.nsFont(size: size)
        if font != chosen { font = chosen }
        textColor = noteTextColor
        insertionPointColor = noteTextColor
        defaultParagraphStyle = paragraph
        alignment = .center
        typingAttributes = [.font: chosen, .foregroundColor: noteTextColor, .paragraphStyle: paragraph]
        recenter(visibleHeight: visible.height)
    }

    private func recenter(visibleHeight: CGFloat) {
        guard let layoutManager, let textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        let used = layoutManager.usedRect(for: textContainer).height
        let vertical = max(padding.height, (visibleHeight - used) / 2)
        if abs(textContainerInset.height - vertical) > 0.5 || textContainerInset.width != padding.width {
            textContainerInset = NSSize(width: padding.width, height: vertical)
        }
        minSize = NSSize(width: 0, height: visibleHeight)
    }
}
