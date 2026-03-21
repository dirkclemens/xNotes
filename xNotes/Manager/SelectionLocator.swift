//
//  SelectionLocator.swift
//  xNotes
//

import Foundation
import AppKit
import ApplicationServices
import Combine

final class SelectionLocator {
    static func preferredAnchorPoint() -> NSPoint? {
        if let rect = selectedTextRectInScreen() {
            return NSPoint(x: rect.midX, y: rect.minY)
        }
        return nil
    }

    private static func selectedTextRectInScreen() -> CGRect? {
        guard AXIsProcessTrusted() else { return nil }

        let system = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused,
              CFGetTypeID(focused) == AXUIElementGetTypeID() else {
            return nil
        }
        let focusedElement = focused as! AXUIElement

        var rangeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let rangeValue,
              CFGetTypeID(rangeValue) == AXValueGetTypeID() else {
            return nil
        }
        let rangeAX = rangeValue as! AXValue
        guard AXValueGetType(rangeAX) == .cfRange else {
            return nil
        }

        var range = CFRange()
        AXValueGetValue(rangeAX, .cfRange, &range)
        guard let rangeParam = AXValueCreate(.cfRange, &range) else { return nil }

        var boundsValue: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(
            focusedElement,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeParam,
            &boundsValue
        ) == .success,
              let boundsValue,
              CFGetTypeID(boundsValue) == AXValueGetTypeID() else {
            return nil
        }
        let boundsAX = boundsValue as! AXValue
        guard AXValueGetType(boundsAX) == .cgRect else {
            return nil
        }

        var rect = CGRect.zero
        AXValueGetValue(boundsAX, .cgRect, &rect)
        return rect.isEmpty ? nil : rect
    }
}
