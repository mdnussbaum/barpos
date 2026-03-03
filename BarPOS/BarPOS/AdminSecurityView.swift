import SwiftUI

struct AdminSecurityView: View {
    @EnvironmentObject var vm: InventoryVM

    // Manager PIN editor
    @State private var newPIN: String = ""
    @State private var confirmPIN: String = ""
    @State private var pinError: String = ""
    @FocusState private var newPINFocused: Bool

    var body: some View {
        List {
            // MARK: - Manager PIN
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("New PIN (4–8 digits)", text: $newPIN)
                        .keyboardType(.numberPad)
                        .focused($newPINFocused)
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

            // MARK: - Access Control Status
            Section {
                HStack {
                    Label("Admin PIN is set", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(vm.managerPIN.isEmpty ? .red : .green)
                    Spacer()
                    Text(vm.managerPIN.isEmpty ? "Not set" : "Active")
                        .font(.footnote)
                        .foregroundStyle(vm.managerPIN.isEmpty ? .red : .secondary)
                }

                Stepper(
                    "Auto-lock after \(vm.autoLockTimeout) min",
                    value: $vm.autoLockTimeout,
                    in: 1...15
                )
            } header: {
                Text("Access Control")
            } footer: {
                Text("Admin panel locks automatically after \(vm.autoLockTimeout) minute\(vm.autoLockTimeout == 1 ? "" : "s") of inactivity.")
                    .font(.footnote)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Security")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                newPINFocused = true
            }
        }
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
