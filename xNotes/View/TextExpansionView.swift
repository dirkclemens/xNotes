//
//  TextExpansionView.swift
//  xNotes
//

import SwiftUI

struct CustomList<Content>: View where Content: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        List {
            content()
                .listSectionSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 0, trailing: 6))
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }
}

struct TextExpansionView: View {
    @EnvironmentObject var store: TextExpansionStore
    @State private var newTrigger: String = ""
    @State private var newReplacement: String = ""
    @State private var pendingDeleteRule: TextExpansionRule?
//    @State private var selection: UUID?
    @State private var selection = Set<UUID>()

    var body: some View {
        VStack(spacing: 0) {
//            List(items, selection: $selection) { item in
            List(selection: $selection) {
                ForEach($store.rules) { $rule in
                    HStack(spacing: 8) {
                        Toggle("", isOn: $rule.isEnabled)
                            .toggleStyle(.checkbox)
                            .labelsHidden()

                        TextField("Trigger", text: $rule.trigger)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)

                        TextField("Replacement", text: $rule.replacement, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: .infinity)

                        Button(action: {
                            pendingDeleteRule = rule
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(width: 20, height: 18)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Delete")
                    }
                    .controlSize(.small)
                    .font(.system(size: 12))
                    .listRowInsets(EdgeInsets(top: 1, leading: 6, bottom: 1, trailing: 6))
                    .contextMenu {
                        Button("Delete") {
                            pendingDeleteRule = rule
                        }
                    }
                }
                .onDelete { indexSet in
                    guard let index = indexSet.first else { return }
                    pendingDeleteRule = store.rules[index]
                }
            }
            .environment(\.defaultMinListRowHeight, 20)

            Divider()

            HStack(spacing: 8) {
                TextField("Trigger (e.g. :kr)", text: $newTrigger)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)

                TextField("Replacement (e.g. kind regards)", text: $newReplacement, axis: .vertical)
                    .textFieldStyle(.roundedBorder)

                Button("Add") {
                    store.addRule(trigger: newTrigger, replacement: newReplacement)
                    newTrigger = ""
                    newReplacement = ""
                }
                .disabled(!canAddRule)
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Delete Expansion?", isPresented: Binding(
            get: { pendingDeleteRule != nil },
            set: { if !$0 { pendingDeleteRule = nil } }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let pendingDeleteRule {
                    store.removeRule(id: pendingDeleteRule.id)
                }
                pendingDeleteRule = nil
            }
        } message: {
            if let pendingDeleteRule {
                Text("\"\(pendingDeleteRule.trigger)\" → \"\(pendingDeleteRule.replacement)\"")
            }
        }
    }

    private var canAddRule: Bool {
        !newTrigger.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
