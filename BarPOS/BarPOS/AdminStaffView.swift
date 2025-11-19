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
                AddBartenderSheet { name in
                    vm.addBartender(name: name)
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
    let onSave: (String) -> Void
    
    @State private var name: String = ""
    
    var body: some View {
        Form {
            Section("Bartender Name") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
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
                    onSave(name)
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
    
    var body: some View {
        Form {
            Section("Bartender Name") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
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
                    var updated = bartender
                    updated.name = name.trimmingCharacters(in: .whitespaces)
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
