import Foundation
import Observation

/// The single counter value, persisted across launches.
@MainActor
@Observable
final class Counter {
    var value: Int {
        didSet { UserDefaults.standard.set(value, forKey: "counterValue") }
    }

    init() {
        value = UserDefaults.standard.integer(forKey: "counterValue")
    }
}
