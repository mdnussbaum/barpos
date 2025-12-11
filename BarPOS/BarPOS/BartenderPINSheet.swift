//
//  BartenderPINSheet.swift
//  BarPOS
//
//  Created by Michael Nussbaum on 12/11/25.
//


//
//  BartenderPINSheet.swift
//  BarPOS
//
//  PIN authentication for bartender login
//

import SwiftUI

// MARK: - Bartender PIN Login Sheet
struct BartenderPINSheet: View {
    @EnvironmentObject var vm: InventoryVM
    @Environment(\.dismiss) private var dismiss
    
    let onAuthenticated: (Bartender) -> Void
    
    @State private var selectedBartenderID: UUID? = nil
    @State private var pin: String = ""
    @State private var pinError: String = ""
    
    private var activeBartenders: [Bartender] {
        vm.activeBartenders.filter { $0.pin != nil }
    }
    
    // Find TEST bartender for quick access
    private var testBartender: Bartender? {
        activeBartenders.first { $0.name.uppercased() == "TEST" }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Quick Test Login
                if let testBartender = testBartender {
                    Section {
                        Button {
                            onAuthenticated(testBartender)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "flask.fill")
                                    .foregroundStyle(.orange)
                                Text("Quick Test Login (TEST / 0000)")
                                    .foregroundStyle(.orange)
                                Spacer()
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    
                    Section {
                        Text("For testing only")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Select Bartender") {
                    Picker("Bartender", selection: $selectedBartenderID) {
                        Text("Select…").tag(nil as UUID?)
                        ForEach(activeBartenders) { bartender in
                            Text(bartender.name).tag(bartender.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                if selectedBartenderID != nil {
                    Section("Enter PIN") {
                        SecureField("PIN", text: $pin)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                        
                        if !pinError.isEmpty {
                            Text(pinError)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                if activeBartenders.isEmpty {
                    Section {
                        Text("No bartenders with PINs configured. Please contact manager.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Bartender Login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Login") {
                        authenticateBartender()
                    }
                    .disabled(selectedBartenderID == nil || pin.isEmpty)
                }
            }
        }
    }
    
    private func authenticateBartender() {
        pinError = ""
        
        guard let bartenderID = selectedBartenderID,
              let bartender = activeBartenders.first(where: { $0.id == bartenderID }) else {
            pinError = "Please select a bartender"
            return
        }
        
        if vm.validateBartenderPIN(bartender, pin: pin) {
            onAuthenticated(bartender)
            dismiss()
        } else {
            pinError = "Incorrect PIN. Please try again."
            pin = ""
        }
    }
}

#Preview {
    BartenderPINSheet { bartender in
        print("Authenticated: \(bartender.name)")
    }
    .environmentObject(InventoryVM())
}