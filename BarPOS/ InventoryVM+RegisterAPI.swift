import Foundation

extension InventoryVM {
    // MARK: - Tab helpers used by RegisterView
    func ensureAtLeastOneTab() {
        if tabs.isEmpty { createNewTab() }
        if activeTabID == nil { activeTabID = tabs.keys.first }
    }

    func createNewTab() {
        let id = UUID()
        let display = Date().formatted(.dateTime.month(.abbreviated).day()) + " • #\(nextTabSequence)"
        let ticket = TabTicket(id: id, name: display, lines: [], createdAt: Date())
        tabs[id] = ticket
        activeTabID = id
        nextTabSequence += 1
        saveState()
    }

    func selectTab(id: UUID) { activeTabID = id }

    func renameActiveTab(_ newName: String) {
        guard let id = activeTabID, var t = tabs[id] else { return }
        t.name = newName
        tabs[id] = t
        saveState()
    }

    func deleteActiveTabIfEmpty() {
        guard let id = activeTabID, let t = tabs[id], t.lines.isEmpty else { return }
        tabs.removeValue(forKey: id)
        if tabs.isEmpty { createNewTab() }
        activeTabID = tabs.keys.first
        saveState()
    }

    var tabIDsForUI: [UUID] {
        tabs.values.sorted { $0.createdAt < $1.createdAt }.map { $0.id }
    }

    func tabDisplayName(id: UUID) -> String {
        tabs[id]?.name ?? "Tab"
    }


    // Internal mutation helper
    func mutateActiveTicket(_ mutate: (inout TabTicket) -> Void) {
        guard let id = activeTabID, var ticket = tabs[id] else { return }
        mutate(&ticket)
        tabs[id] = ticket
    }
}
