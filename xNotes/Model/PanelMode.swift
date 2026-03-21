//
//  PanelMode.swift
//  xNotes
//

import Foundation
import Combine

enum PanelMode: String {
    case full
    case clipboard
}

final class PanelModeController: ObservableObject {
    @Published var mode: PanelMode = .full
}
