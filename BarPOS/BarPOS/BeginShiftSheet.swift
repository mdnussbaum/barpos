import SwiftUI

struct BeginShiftSheet: View {
    // Inputs provided by the presenter (RegisterView)
    let bartenders: [Bartender]
    let carryoverTabs: [TabTicket]
    var onStart: (_ bartender: Bartender, _ openingCash: Decimal) -> Void
    var onCancel: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var selectedBartenderID: UUID? = nil
    @State private var openingCashString: String = ""
    
    private var hasCarryoverTabs: Bool {
        !carryoverTabs.isEmpty
    }
    
    private var carryoverTabCount: Int {
        carryoverTabs.count
    }

    var body: some View {
            NavigationStack {
                Form {
                    // Debug
                    let _ = print("🔍 Carryover tabs count: \(carryoverTabs.count)")
                    let _ = print("🔍 Has carryover: \(hasCarryoverTabs)")
                    
                    // Carryover warning
                    if hasCarryoverTabs {
                        Section {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Carryover Tabs")
                                        .font(.headline)
                                    Text("There are \(carryoverTabCount) open tab(s) from the previous shift with items that need to be closed.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                
                Section("Bartender") {
                    Picker("Bartender", selection: $selectedBartenderID) {
                        Text("Select…").tag(nil as UUID?)
                        ForEach(bartenders) { person in
                            Text(person.name).tag(person.id as UUID?)
                        }
                    }
                }

                Section("Opening Cash") {
                    TextField("0.00", text: $openingCashString)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Begin Shift")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Start") { startShift() }
                        .disabled(selectedBartenderID == nil)
                }
            }
        }
    }

    private func startShift() {
        guard
            let id = selectedBartenderID,
            let bartender = bartenders.first(where: { $0.id == id })
        else { return }

        let opening = Decimal(string: openingCashString) ?? 0
        onStart(bartender, opening)
        dismiss()
    }
}

#Preview {
    BeginShiftSheet(
        bartenders: [
            Bartender(name: "Alex"), Bartender(name: "Jamie")
        ],
        carryoverTabs: [],
        onStart: { _, _ in },
        onCancel: {}
    )
}
