//
//  MDEditorLite.swift
//  MDEditorLite
//
//  Created by Christian Tietze on 2017-07-21.
//  Copyright © 2017 Rudd Fawcett. All rights reserved.
//

#if os(iOS)
import UIKit

public class MDEditorLite: UITextView {

    var storage: Storage = Storage()

    /// Creates a new MDEditorLite.
    ///
    /// - parameter frame:     The frame of the text editor.
    ///
    /// - returns: A new MDEditorLite.
    convenience public init(frame: CGRect) {
        self.init(frame: frame, textContainer: nil)
        self.backgroundColor = .windowBackgroundColor
        self.tintColor = .textColor
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    convenience public init(frame: CGRect) {
        self.init(frame: frame)
    }
    
    convenience public init(frame: CGRect) {
        self.init(frame: frame, textContainer: nil)
        self.backgroundColor = .windowBackgroundColor
        self.tintColor = .textColor
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        let layoutManager = NSLayoutManager()
        let containerSize = CGSize(width: frame.size.width, height: CGFloat.greatestFiniteMagnitude)
        let container = NSTextContainer(size: containerSize)
        container.widthTracksTextView = true

        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        super.init(frame: frame, textContainer: container)
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        let layoutManager = NSLayoutManager()
        let containerSize = CGSize(width: frame.size.width, height: CGFloat.greatestFiniteMagnitude)
        let container = NSTextContainer(size: containerSize)
        container.widthTracksTextView = true

        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
    }
}
#endif


#if os(macOS)
import AppKit

public class MDEditorLite: NSTextView {

    var storage: MDStorage = MDStorage()

    public override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        self.backgroundColor = .windowBackgroundColor
        self.insertionPointColor = .textColor
    }

    public convenience override init(frame: CGRect) {
        let layoutManager = NSLayoutManager()
        let containerSize = CGSize(width: frame.size.width, height: CGFloat.greatestFiniteMagnitude)
        let container = NSTextContainer(size: containerSize)
        container.widthTracksTextView = true

        layoutManager.addTextContainer(container)
        self.init(frame: frame, textContainer: container)
        storage.addLayoutManager(layoutManager)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        let layoutManager = NSLayoutManager()
        if let container = textContainer {
            container.widthTracksTextView = true
            layoutManager.addTextContainer(container)
        }
        storage.addLayoutManager(layoutManager)
        textContainer?.replaceLayoutManager(layoutManager)
    }
}
#endif
