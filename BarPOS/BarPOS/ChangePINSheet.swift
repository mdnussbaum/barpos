import SwiftUI

struct ChangePINSheet: View {
    let bartender: Bartender
    let vm: InventoryVM
    var onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var currentPin: String = ""
    @State private var newPin: String = ""
    @State private var confirmPin: String = ""
    @State private var errorMessage: String = ""

    private var isPinValid: Bool {
        newPin.count == 4 && newPin.allSatisfy { $0.isNumber }
    }

    private var pinsMatch: Bool {
        newPin == confirmPin
    }

    private var canSave: Bool {
        !currentPin.isEmpty && isPinValid && pinsMatch
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Current PIN", text: $currentPin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                } header: {
                    Text("Verify Identity")
                }

                Section {
                    SecureField("New PIN (4 digits)", text: $newPin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)

                    SecureField("Confirm New PIN", text: $confirmPin)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                } header: {
                    Text("New PIN")
                } footer: {
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    } else if !newPin.isEmpty && !isPinValid {
                        Text("PIN must be exactly 4 digits")
                            .foregroundColor(.red)
                    } else if !confirmPin.isEmpty && !pinsMatch {
                        Text("PINs do not match")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Change PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveNewPIN()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveNewPIN() {
        // Verify current PIN
        if !vm.validateBartenderPIN(bartender, pin: currentPin) {
            errorMessage = "Current PIN is incorrect"
            return
        }

        // Save new PIN
        vm.changeBartenderPIN(bartenderID: bartender.id, newPIN: newPin)
        onComplete()
        dismiss()
    }
}

#Preview {
    ChangePINSheet(
        bartender: Bartender(name: "Alex", pin: "1234"),
        vm: InventoryVM(),
        onComplete: {}
    )
}
