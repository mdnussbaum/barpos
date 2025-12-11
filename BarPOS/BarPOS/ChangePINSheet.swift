//
//  ChangePINSheet.swift
//  BarPOS
//
//  Created by Michael Nussbaum on 12/11/25.
//


//
//  ChangePINSheet.swift
//  BarPOS
//
//  Allows bartenders to change their PIN during their shift
//

import SwiftUI

// MARK: - Change PIN Sheet
struct ChangePINSheet: View {
    @EnvironmentObject var vm: InventoryVM
    @Environment(\.dismiss) private var dismiss
    
    let bartender: Bartender
    
    @State private var currentPIN: String = ""
    @State private var newPIN: String = ""
    @State private var confirmPIN: String = ""
    @State private var pinError: String = ""
    @State private var showSuccess: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Current PIN") {
                    SecureField("Current PIN", text: $currentPIN)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                }
                
                Section("New PIN") {
                    SecureField("New PIN (4-8 digits)", text: $newPIN)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                    
                    SecureField("Confirm New PIN", text: $confirmPIN)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                }
                
                if !pinError.isEmpty {
                    Section {
                        Text(pinError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                
                if showSuccess {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("PIN changed successfully")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .navigationTitle("Change PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        changePIN()
                    }
                    .disabled(currentPIN.isEmpty || newPIN.isEmpty || confirmPIN.isEmpty)
                }
            }
        }
    }
    
    private func changePIN() {
        pinError = ""
        showSuccess = false
        
        // Validate current PIN
        guard vm.validateBartenderPIN(bartender, pin: currentPIN) else {
            pinError = "Current PIN is incorrect"
            currentPIN = ""
            return
        }
        
        // Validate new PIN
        let trimmed = newPIN.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 4, trimmed.count <= 8, trimmed.allSatisfy({ $0.isNumber }) else {
            pinError = "New PIN must be 4-8 digits"
            return
        }
        
        guard trimmed == confirmPIN else {
            pinError = "New PINs do not match"
            return
        }
        
        // Save new PIN
        vm.changeBartenderPIN(bartenderID: bartender.id, newPIN: trimmed)
        
        // Show success and auto-dismiss after short delay
        showSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
}

#Preview {
    ChangePINSheet(bartender: Bartender(name: "Alex", pin: "1234"))
        .environmentObject(InventoryVM())
}