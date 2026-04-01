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

public struct MDEditorLiteView: NSViewRepresentable {
    @Binding private var text: String
    private let isEditable: Bool

    public init(text: Binding<String>, isEditable: Bool = true) {
        self._text = text
        self.isEditable = isEditable
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
        textView.string = text
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: Swift.Double.greatestFiniteMagnitude, height: Swift.Double.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
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
    }

    public final class Coordinator: NSObject, NSTextViewDelegate {
        private let parent: MDEditorLiteView

        init(_ parent: MDEditorLiteView) {
            self.parent = parent
        }

        public func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}
#endif
