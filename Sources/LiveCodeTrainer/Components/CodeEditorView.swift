import AppKit
import SwiftUI

/// A native macOS code editor backed by `NSTextView`.
struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String

    var fontSize: CGFloat = 14
    var isEditable = true

    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true

        let textView = CodeTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindPanel = true
        textView.isGrammarCheckingEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 12, height: 10)
        textView.minSize = .zero
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = false

        scrollView.documentView = textView

        let rulerView = LineNumberRulerView(textView: textView, scrollView: scrollView)
        scrollView.verticalRulerView = rulerView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        context.coordinator.rulerView = rulerView

        applyAppearance(
            to: textView,
            in: scrollView,
            coordinator: context.coordinator
        )
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CodeTextView else {
            return
        }

        if textView.string != text {
            let selection = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(
                NSRange(
                    location: min(selection.location, (text as NSString).length),
                    length: 0
                )
            )
            context.coordinator.rulerView?.invalidateLineNumbers()
        }

        textView.isEditable = isEditable
        applyAppearance(
            to: textView,
            in: scrollView,
            coordinator: context.coordinator
        )
    }

    private func applyAppearance(
        to textView: NSTextView,
        in scrollView: NSScrollView,
        coordinator: Coordinator
    ) {
        let palette = EditorPalette(colorScheme: colorScheme)
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)

        textView.font = font
        textView.textColor = palette.text
        textView.backgroundColor = palette.background
        textView.insertionPointColor = palette.insertionPoint
        textView.selectedTextAttributes = [
            .backgroundColor: palette.selection,
            .foregroundColor: palette.text
        ]
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: palette.text
        ]
        coordinator.configure(palette: palette, font: font)
        coordinator.highlight(textView)

        scrollView.backgroundColor = palette.background
        scrollView.drawsBackground = true

        if let rulerView = scrollView.verticalRulerView as? LineNumberRulerView {
            rulerView.font = NSFont.monospacedDigitSystemFont(
                ofSize: max(fontSize - 2, 10),
                weight: .regular
            )
            rulerView.palette = palette
            rulerView.needsDisplay = true
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        private var text: Binding<String>
        private var palette = EditorPalette(colorScheme: .light)
        private var font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        private var isApplyingHighlighting = false
        fileprivate weak var rulerView: LineNumberRulerView?

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            text.wrappedValue = textView.string
            highlight(textView)
            rulerView?.invalidateLineNumbers()
        }

        fileprivate func configure(palette: EditorPalette, font: NSFont) {
            self.palette = palette
            self.font = font
        }

        fileprivate func highlight(_ textView: NSTextView) {
            guard !isApplyingHighlighting,
                  let storage = textView.textStorage
            else {
                return
            }

            isApplyingHighlighting = true
            defer { isApplyingHighlighting = false }

            let selection = textView.selectedRange()
            let fullRange = NSRange(location: 0, length: storage.length)
            let undoManager = textView.undoManager
            undoManager?.disableUndoRegistration()
            defer { undoManager?.enableUndoRegistration() }

            storage.beginEditing()
            storage.setAttributes(
                [
                    .font: font,
                    .foregroundColor: palette.text
                ],
                range: fullRange
            )
            for token in SwiftSyntaxHighlighter.tokens(in: storage.string) {
                storage.addAttribute(
                    .foregroundColor,
                    value: palette.color(for: token.kind),
                    range: token.range
                )
            }
            storage.endEditing()

            let safeLocation = min(selection.location, storage.length)
            let safeLength = min(selection.length, storage.length - safeLocation)
            textView.setSelectedRange(
                NSRange(location: safeLocation, length: safeLength)
            )
            textView.typingAttributes = [
                .font: font,
                .foregroundColor: palette.text
            ]
        }
    }
}

private final class CodeTextView: NSTextView {
    override func insertTab(_ sender: Any?) {
        insertText("    ", replacementRange: selectedRange())
    }
}

private struct EditorPalette {
    let background: NSColor
    let gutterBackground: NSColor
    let gutterSeparator: NSColor
    let lineNumber: NSColor
    let text: NSColor
    let insertionPoint: NSColor
    let selection: NSColor
    let keyword: NSColor
    let type: NSColor
    let string: NSColor
    let number: NSColor
    let comment: NSColor
    let attribute: NSColor
    let directive: NSColor
    let operatorSymbol: NSColor

    init(colorScheme: ColorScheme) {
        switch colorScheme {
        case .dark:
            background = NSColor(srgbRed: 0.075, green: 0.082, blue: 0.102, alpha: 1)
            gutterBackground = NSColor(srgbRed: 0.055, green: 0.061, blue: 0.078, alpha: 1)
            gutterSeparator = NSColor.white.withAlphaComponent(0.10)
            lineNumber = NSColor.white.withAlphaComponent(0.38)
            text = NSColor(srgbRed: 0.88, green: 0.90, blue: 0.94, alpha: 1)
            insertionPoint = .white
            selection = NSColor.systemBlue.withAlphaComponent(0.42)
            keyword = NSColor(srgbRed: 0.96, green: 0.48, blue: 0.73, alpha: 1)
            type = NSColor(srgbRed: 0.40, green: 0.82, blue: 0.90, alpha: 1)
            string = NSColor(srgbRed: 0.95, green: 0.64, blue: 0.48, alpha: 1)
            number = NSColor(srgbRed: 0.76, green: 0.67, blue: 0.98, alpha: 1)
            comment = NSColor(srgbRed: 0.46, green: 0.66, blue: 0.48, alpha: 1)
            attribute = NSColor(srgbRed: 0.95, green: 0.75, blue: 0.36, alpha: 1)
            directive = NSColor(srgbRed: 0.77, green: 0.57, blue: 0.94, alpha: 1)
            operatorSymbol = NSColor(srgbRed: 0.60, green: 0.72, blue: 0.94, alpha: 1)
        default:
            background = NSColor(srgbRed: 0.985, green: 0.985, blue: 0.99, alpha: 1)
            gutterBackground = NSColor(srgbRed: 0.95, green: 0.955, blue: 0.965, alpha: 1)
            gutterSeparator = NSColor.black.withAlphaComponent(0.10)
            lineNumber = NSColor.secondaryLabelColor
            text = NSColor.labelColor
            insertionPoint = NSColor.textColor
            selection = NSColor.selectedTextBackgroundColor
            keyword = NSColor(srgbRed: 0.68, green: 0.13, blue: 0.48, alpha: 1)
            type = NSColor(srgbRed: 0.04, green: 0.46, blue: 0.53, alpha: 1)
            string = NSColor(srgbRed: 0.76, green: 0.20, blue: 0.09, alpha: 1)
            number = NSColor(srgbRed: 0.34, green: 0.23, blue: 0.72, alpha: 1)
            comment = NSColor(srgbRed: 0.18, green: 0.48, blue: 0.20, alpha: 1)
            attribute = NSColor(srgbRed: 0.66, green: 0.38, blue: 0.02, alpha: 1)
            directive = NSColor(srgbRed: 0.49, green: 0.24, blue: 0.66, alpha: 1)
            operatorSymbol = NSColor(srgbRed: 0.16, green: 0.33, blue: 0.62, alpha: 1)
        }
    }

    func color(for kind: SwiftSyntaxKind) -> NSColor {
        switch kind {
        case .keyword: keyword
        case .type: type
        case .string: string
        case .number: number
        case .comment: comment
        case .attribute: attribute
        case .directive: directive
        case .operatorSymbol: operatorSymbol
        }
    }
}

private final class LineNumberRulerView: NSRulerView {
    weak var textView: NSTextView?
    var font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    var palette = EditorPalette(colorScheme: .light)

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)

        clientView = textView
        ruleThickness = 44

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(viewBoundsDidChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func invalidateLineNumbers() {
        updateRuleThickness()
        needsDisplay = true
    }

    @objc private func viewBoundsDidChange() {
        needsDisplay = true
    }

    private func updateRuleThickness() {
        guard let textView else {
            return
        }

        let lineCount = max(textView.string.reduce(into: 1) { count, character in
            if character == "\n" {
                count += 1
            }
        }, 1)
        let digits = max(String(lineCount).count, 2)
        let digitWidth = ("0" as NSString).size(withAttributes: [.font: font]).width
        ruleThickness = max(44, ceil(CGFloat(digits) * digitWidth + 20))
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard
            let textView,
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer
        else {
            return
        }

        palette.gutterBackground.setFill()
        bounds.fill()

        palette.gutterSeparator.setFill()
        NSRect(x: bounds.maxX - 1, y: bounds.minY, width: 1, height: bounds.height).fill()

        layoutManager.ensureLayout(for: textContainer)

        let string = textView.string as NSString
        let textLength = string.length
        var lineNumber = 1
        var lineStart = 0

        while lineStart <= textLength {
            let glyphIndex: Int
            if textLength == 0 {
                glyphIndex = 0
            } else {
                glyphIndex = layoutManager.glyphIndexForCharacter(
                    at: min(lineStart, textLength - 1)
                )
            }

            var lineRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphIndex,
                effectiveRange: nil
            )
            lineRect.origin.y += textView.textContainerOrigin.y

            let pointInRuler = convert(
                NSPoint(x: 0, y: lineRect.minY),
                from: textView
            )

            if pointInRuler.y + lineRect.height >= rect.minY,
               pointInRuler.y <= rect.maxY {
                draw(lineNumber: lineNumber, y: pointInRuler.y, lineHeight: lineRect.height)
            }

            guard lineStart < textLength else {
                break
            }

            let range = string.lineRange(for: NSRange(location: lineStart, length: 0))
            let nextLineStart = NSMaxRange(range)
            if nextLineStart <= lineStart {
                break
            }

            lineStart = nextLineStart
            lineNumber += 1
        }
    }

    private func draw(lineNumber: Int, y: CGFloat, lineHeight: CGFloat) {
        let value = String(lineNumber) as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: palette.lineNumber
        ]
        let size = value.size(withAttributes: attributes)
        let x = ruleThickness - size.width - 10
        let baselineY = y + max((lineHeight - size.height) / 2, 0)

        value.draw(at: NSPoint(x: x, y: baselineY), withAttributes: attributes)
    }
}
