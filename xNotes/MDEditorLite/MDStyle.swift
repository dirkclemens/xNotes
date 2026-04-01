//
//  Style.swift
//  MDEditorLite
//
//  Created by Rudd Fawcett on 10/14/16.
//  Copyright © 2016 Rudd Fawcett. All rights reserved.
//

import Foundation

public struct MDStyle {
    public let regex: NSRegularExpression
    public let attributes: [NSAttributedString.Key: Any]

    public init(element: MDElement, attributes: [NSAttributedString.Key: Any]) {
        self.regex = element.toRegex()
        self.attributes = attributes
    }

    public init(regex: NSRegularExpression, attributes: [NSAttributedString.Key: Any]) {
        self.regex = regex
        self.attributes = attributes
    }

    public init() {
        self.regex = MDElement.unknown.toRegex()
        self.attributes = [:]
    }
}
