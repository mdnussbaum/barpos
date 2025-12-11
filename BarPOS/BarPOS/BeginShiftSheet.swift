import SwiftUI

struct BeginShiftSheet: View {
    @EnvironmentObject var vm: InventoryVM
    let carryoverTabs: [TabTicket]
    var onStart: (_ bartender: Bartender, _ openingCash: Decimal) -> Void
    var onCancel: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var authenticatedBartender: Bartender? = nil
    @State private var showingPINSheet = false
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
                                Text("There are \(carryoverTabCount) open tab(s) from the previous shift.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            
                Section("Bartender") {
                    if let bartender = authenticatedBartender {
                        HStack {
                            Text(bartender.name)
                                .font(.body)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Button("Change") {
                                authenticatedBartender = nil
                            }
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        }
                    } else {
                        Button("Select & Login…") {
                            showingPINSheet = true
                        }
                    }
                }

                Section("Opening Cash") {
                    TextField("0.00", text: $openingCashString)
                        .keyboardType(.decimalPad)
                        .disabled(authenticatedBartender == nil)
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
                        .disabled(authenticatedBartender == nil)
                }
            }
            .sheet(isPresented: $showingPINSheet) {
                BartenderPINSheet { bartender in
                    authenticatedBartender = bartender
                }
                .environmentObject(vm)
            }
        }
    }

    private func startShift() {
        guard let bartender = authenticatedBartender else { return }
        let opening = Decimal(string: openingCashString) ?? 0
        onStart(bartender, opening)
        dismiss()
    }
}

#Preview {
    BeginShiftSheet(
        carryoverTabs: [],
        onStart: { _, _ in },
        onCancel: {}
    )
    .environmentObject(InventoryVM())
}
