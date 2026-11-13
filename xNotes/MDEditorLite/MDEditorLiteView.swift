import SwiftUI

#if os(iOS)
import UIKit

public struct MDEditorLiteView: UIViewRepresentable {
    @Binding private var text: String
    private let isEditable: Bool

    public init(text: Binding<String>, isEditable: Bool = true) {
        self._text = text
        self.isEditable = isEditable
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> MDEditorLite {
        let view = MDEditorLite(frame: .zero)
        view.delegate = context.coordinator
        view.isEditable = isEditable
        view.text = text
        return view
    }

    public func updateUIView(_ uiView: MDEditorLite, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.isEditable = isEditable
        uiView.backgroundColor = .windowBackgroundColor
        uiView.tintColor = .textColor
    }

    public final class Coordinator: NSObject, UITextViewDelegate {
        private let parent: MDEditorLiteView

        init(_ parent: MDEditorLiteView) {
            self.parent = parent
        }

        public func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
        }
    }
}

#elseif os(macOS)
import AppKit

/// A range to select and reveal in the editor without taking keyboard focus.
/// A new `id` triggers the highlight again even for the same range.
public struct MDEditorHighlight: Equatable {
    public let id: UUID
    public let range: NSRange

    public init(id: UUID, range: NSRange) {
        self.id = id
        self.range = range
    }
}

public struct MDEditorLiteView: NSViewRepresentable {
    @Binding private var text: String
    private let isEditable: Bool
    private let highlight: MDEditorHighlight?
    private let font: NSFont?

    public init(text: Binding<String>, isEditable: Bool = true, font: NSFont? = nil, highlight: MDEditorHighlight? = nil) {
        self._text = text
        self.isEditable = isEditable
        self.font = font
        self.highlight = highlight
    }

    private func applyFont(to textView: MDEditorLite) {
        guard let font else { return }
        textView.storage.setBaseFont(font)
        textView.typingAttributes[.font] = font
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = MDEditorLite(frame: .zero)
        textView.delegate = context.coordinator
        textView.isEditable = isEditable
        applyFont(to: textView)
        textView.string = text
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: Swift.Double.greatestFiniteMagnitude, height: Swift.Double.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: textView
        )
        return scrollView
    }

    public func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? MDEditorLite else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.isEditable = isEditable
        textView.backgroundColor = .windowBackgroundColor
        textView.insertionPointColor = .textColor
        applyFont(to: textView)

        if let highlight, highlight != context.coordinator.lastHighlight {
            context.coordinator.lastHighlight = highlight
            // Defer until the text view is laid out and attached to a window.
            DispatchQueue.main.async {
                let length = (textView.string as NSString).length
                guard NSMaxRange(highlight.range) <= length else { return }
                textView.setSelectedRange(highlight.range)
                textView.scrollRangeToVisible(highlight.range)
                if textView.window != nil {
                    textView.showFindIndicator(for: highlight.range)
                }
            }
        }
    }

    public final class Coordinator: NSObject, NSTextViewDelegate {
        private let parent: MDEditorLiteView
        var lastHighlight: MDEditorHighlight?

        init(_ parent: MDEditorLiteView) {
            self.parent = parent
        }

        @objc public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
#endif
