//
//  TextExpansionStore.swift
//  xNotes
//

import Foundation
import Combine

@MainActor
final class TextExpansionStore: ObservableObject {
    static let shared = TextExpansionStore()

    @Published var rules: [TextExpansionRule] = [] {
        didSet {
            save()
        }
    }

    private let storageKey = "textExpansionRules"

    private init() {
        load()
    }

    func addRule(trigger: String, replacement: String) {
        let trimmedTrigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTrigger.isEmpty else { return }
        let newRule = TextExpansionRule(trigger: trimmedTrigger, replacement: replacement)
        rules.append(newRule)
    }

    func updateRule(_ rule: TextExpansionRule) {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[index] = rule
    }

    func removeRule(id: UUID) {
        rules.removeAll { $0.id == id }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([TextExpansionRule].self, from: data) else {
            return
        }
        rules = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
