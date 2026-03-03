import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject var vm: InventoryVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // MARK: My PIN
                Section("My PIN") {
                    if let bartender = activeBartender {
                        NavigationLink {
                            ChangePINSheet(bartender: bartender)
                                .environmentObject(vm)
                        } label: {
                            Label("Change PIN", systemImage: "lock.rotation")
                        }
                    } else {
                        Label("Start a shift to change your PIN", systemImage: "lock.rotation")
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Display
                Section("Display") {
                    Picker("Appearance", selection: $vm.colorScheme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: Receipt
                if activeBartender != nil {
                    Section("Receipt") {
                        Toggle("Show Tax", isOn: Binding(
                            get: { vm.printerSettings.showTax },
                            set: { vm.printerSettings.showTax = $0 }
                        ))
                        Toggle("Show Server Name", isOn: Binding(
                            get: { vm.printerSettings.showServer },
                            set: { vm.printerSettings.showServer = $0 }
                        ))
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Helpers

    private var activeBartender: Bartender? {
        vm.currentShift?.openedBy
    }
}
