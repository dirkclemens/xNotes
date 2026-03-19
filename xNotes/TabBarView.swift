//
//  TabBarView.swift
//  xNotes
//

import SwiftUI

struct TabBarView: View {
    @ObservedObject var notesManager: NotesManager
    @AppStorage("keepWindowOpen") private var keepWindowOpen: Bool = false
    let buttonSize: CGFloat = 18

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 2) {
                    ForEach(Array(notesManager.tabs.enumerated()), id: \.element.id) { index, tab in
                        TabButton(
                            notesManager: notesManager,
                            tab: tab,
                            index: index,
                            isSelected: notesManager.selectedTabId == tab.id,
                            onSelect: { notesManager.selectedTabId = tab.id },
                            onClose: (notesManager.tabs.count > 1 && !tab.isLocked) ? { notesManager.removeTab(tab) } : nil,
                            onEditTitle: { newTitle in notesManager.updateTitle(for: tab.id, title: newTitle) },
                            onEditColor: { newColor in notesManager.updateColor(for: tab.id, color: newColor) },
                            onToggleLock: { isLocked in notesManager.updateLocked(for: tab.id, isLocked: isLocked) }
                        )
                        .padding(1)
                    }
                }
            }
            .background(Color(red: 0.937, green: 0.937, blue: 0.937))
            .cornerRadius(16)

            Button(action: { notesManager.addTab() }) {
                Image(systemName: "plus")
                    .font(.system(size: 11))
                    .frame(width: buttonSize, height: buttonSize)
            }
            .cornerRadius(16)

            Button(action: { keepWindowOpen.toggle() }) {
                Image(systemName: keepWindowOpen ? "pin.fill" : "pin")
                    .font(.system(size: 13))
                    .frame(width: buttonSize, height: buttonSize)
                    .foregroundColor(keepWindowOpen ? .accentColor : .secondary)
            }
            .help(keepWindowOpen ? "Window stays open" : "Window closes on focus loss")
            .cornerRadius(16)
        }
        .padding(10)
        .background(.windowBackground)
    }
}
