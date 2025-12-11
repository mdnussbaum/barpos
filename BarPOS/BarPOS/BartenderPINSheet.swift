import SwiftUI

struct BartenderPINSheet: View {
    let bartenders: [Bartender]
    let carryoverTabs: [TabTicket]
    let vm: InventoryVM
    var onStart: (_ bartender: Bartender, _ openingCash: Decimal) -> Void
    var onCancel: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var selectedBartender: Bartender? = nil
    @State private var pinText: String = ""
    @State private var openingCashString: String = ""
    @State private var pinError: String = ""
    @State private var showPINEntry: Bool = false

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

                if !showPINEntry {
                    // Bartender selection
                    Section("Select Bartender") {
                        ForEach(bartenders) { bartender in
                            Button {
                                selectedBartender = bartender
                                showPINEntry = true
                                pinText = ""
                                pinError = ""
                            } label: {
                                HStack {
                                    Text(bartender.name)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    // PIN entry
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Enter PIN for \(selectedBartender?.name ?? "")")
                                .font(.headline)

                            SecureField("PIN", text: $pinText)
                                .keyboardType(.numberPad)
                                .textContentType(.oneTimeCode)
                                .textFieldStyle(.roundedBorder)

                            if !pinError.isEmpty {
                                Text(pinError)
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    Section("Opening Cash") {
                        TextField("0.00", text: $openingCashString)
                            .keyboardType(.decimalPad)
                    }

                    Section {
                        Button("Back to Bartender Selection") {
                            showPINEntry = false
                            selectedBartender = nil
                            pinText = ""
                            pinError = ""
                        }
                    }
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
                if showPINEntry {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Start") { startShift() }
                            .disabled(pinText.isEmpty)
                    }
                }
            }
        }
    }

    private func startShift() {
        guard let bartender = selectedBartender else { return }

        // Validate PIN
        if !vm.validateBartenderPIN(bartender, pin: pinText) {
            pinError = "Incorrect PIN. Try again."
            return
        }

        let opening = Decimal(string: openingCashString) ?? 0
        onStart(bartender, opening)
        dismiss()
    }
}

#Preview {
    BartenderPINSheet(
        bartenders: [
            Bartender(name: "Alex", pin: "1234"),
            Bartender(name: "Jamie", pin: "5678")
        ],
        carryoverTabs: [],
        vm: InventoryVM(),
        onStart: { _, _ in },
        onCancel: {}
    )
}
