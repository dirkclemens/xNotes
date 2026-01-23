import Foundation
import Combine

class KeepWindowOpenState: ObservableObject {
    @Published var keepWindowOpen: Bool {
        didSet {
            UserDefaults.standard.set(keepWindowOpen, forKey: "keepWindowOpen")
        }
    }
    init() {
        self.keepWindowOpen = UserDefaults.standard.bool(forKey: "keepWindowOpen")
    }
}
