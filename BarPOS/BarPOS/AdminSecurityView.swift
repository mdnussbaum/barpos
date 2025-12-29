import SwiftUI

struct AdminSecurityView: View {
    @EnvironmentObject var vm: InventoryVM

    // Manager PIN editor
    @State private var newPIN: String = ""
    @State private var confirmPIN: String = ""
    @State private var pinError: String = ""

    var body: some View {
        List {
            // MARK: - Manager PIN
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("New PIN (4–8 digits)", text: $newPIN)
                        .keyboardType(.numberPad)
                    SecureField("Confirm PIN", text: $confirmPIN)
                        .keyboardType(.numberPad)

                    if !pinError.isEmpty {
                        Text(pinError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    HStack {
                        Button("Save PIN") { savePIN() }
                            .buttonStyle(.borderedProminent)
                        Spacer()
                        if vm.isAdminUnlocked {
                            Button("Lock Admin") { vm.lockAdmin() }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            } header: {
                Text("Manager PIN")
            } footer: {
                Text("Set or change the manager PIN used for admin access in the History view.")
                    .font(.footnote)
            }

            // MARK: - Future: PIN on Entry
            Section {
                // TODO: Add PIN-on-entry toggle here when implementing Admin PIN protection
                Text("PIN protection for Admin section")
                    .foregroundStyle(.secondary)
                Text("Coming soon")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Access Control")
            }
        }
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Actions

    private func savePIN() {
        pinError = ""
        let trimmed = newPIN.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count >= 4, trimmed.count <= 8,
              trimmed.allSatisfy({ $0.isNumber }) else {
            pinError = "PIN must be 4–8 digits."
            return
        }
        guard trimmed == confirmPIN else {
            pinError = "PINs do not match."
            return
        }
        vm.managerPIN = trimmed
        vm.isAdminUnlocked = true
        newPIN = ""
        confirmPIN = ""
    }
}
