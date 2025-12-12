//
//  AdminStaffView.swift
//  BarPOS
//

import SwiftUI

struct AdminStaffView: View {
    @EnvironmentObject var vm: InventoryVM
    
    @State private var showingAddSheet = false
    @State private var editingBartender: Bartender?
    @State private var showActiveOnly = true
    
    private var filteredBartenders: [Bartender] {
        showActiveOnly
            ? vm.bartenders.filter { $0.isActive }
            : vm.bartenders
    }
    
    var body: some View {
        List {
            // Filter toggle
            Section {
                Toggle("Show active only", isOn: $showActiveOnly)
            }
            
            // Bartender list
            Section {
                if filteredBartenders.isEmpty {
                    Text(showActiveOnly ? "No active bartenders" : "No bartenders")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredBartenders) { bartender in
                        Button {
                            editingBartender = bartender
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bartender.name)
                                        .font(.headline)
                                    
                                    if !bartender.isActive {
                                        Text("Inactive")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if bartender.isActive {
                                Button(role: .destructive) {
                                    vm.disableBartender(bartender)
                                } label: {
                                    Label("Disable", systemImage: "xmark.circle")
                                }
                            } else {
                                Button {
                                    vm.enableBartender(bartender)
                                } label: {
                                    Label("Enable", systemImage: "checkmark.circle")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }
            } header: {
                Text("Bartenders")
            } footer: {
                Text("Disabled bartenders are hidden from shift selection but keep their history.")
                    .font(.caption)
            }
        }
        .navigationTitle("Staff")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
                    NavigationStack {
                        AddBartenderSheet { name, pin in
                            vm.addBartender(name: name, pin: pin)
                            showingAddSheet = false
                        }
                    }
                }
        
        .sheet(item: $editingBartender) { bartender in
            NavigationStack {
                EditBartenderSheet(bartender: bartender) { updated in
                    vm.updateBartender(updated)
                    editingBartender = nil
                }
            }
        }
    }
}

// MARK: - Add Bartender Sheet
struct AddBartenderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (String, String) -> Void

    @State private var name: String = ""
    @State private var pin: String = ""
    @State private var confirmPin: String = ""
    @State private var pinError: String = ""

    var body: some View {
        Form {
            Section("Bartender Name") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
            }

            Section("PIN (4-8 digits)") {
                SecureField("PIN", text: $pin)
                    .keyboardType(.numberPad)
                SecureField("Confirm PIN", text: $confirmPin)
                    .keyboardType(.numberPad)

                if !pinError.isEmpty {
                    Text(pinError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Add Bartender")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    pinError = ""
                    let trimmed = pin.trimmingCharacters(in: .whitespaces)
                    guard trimmed.count >= 4, trimmed.count <= 8, trimmed.allSatisfy({ $0.isNumber }) else {
                        pinError = "PIN must be 4-8 digits"
                        return
                    }
                    guard trimmed == confirmPin else {
                        pinError = "PINs do not match"
                        return
                    }
                    onSave(name, trimmed)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }
}

// MARK: - Edit Bartender Sheet
struct EditBartenderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let bartender: Bartender
    let onSave: (Bartender) -> Void

    @State private var name: String = ""
    @State private var pin: String = ""
    @State private var confirmPin: String = ""
    @State private var pinError: String = ""

    var body: some View {
        Form {
            Section("Bartender Name") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
            }

            Section("Change PIN (Optional)") {
                SecureField("New PIN (4-8 digits)", text: $pin)
                    .keyboardType(.numberPad)
                SecureField("Confirm New PIN", text: $confirmPin)
                    .keyboardType(.numberPad)

                Text("Leave blank to keep current PIN")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !pinError.isEmpty {
                    Text(pinError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(bartender.isActive ? "Active" : "Inactive")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Edit Bartender")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    pinError = ""
                    var updated = bartender
                    updated.name = name.trimmingCharacters(in: .whitespaces)

                    // Only update PIN if user entered something
                    if !pin.isEmpty {
                        let trimmed = pin.trimmingCharacters(in: .whitespaces)
                        guard trimmed.count >= 4, trimmed.count <= 8, trimmed.allSatisfy({ $0.isNumber }) else {
                            pinError = "PIN must be 4-8 digits"
                            return
                        }
                        guard trimmed == confirmPin else {
                            pinError = "PINs do not match"
                            return
                        }
                        updated.pin = trimmed
                    }

                    onSave(updated)
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            name = bartender.name
        }
    }
}
