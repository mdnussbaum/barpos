import SwiftUI

struct AdminView: View {
    @EnvironmentObject var vm: InventoryVM

    // Controls the inline PIN prompt for unlocking admin
    @State private var showingUnlockPIN = false
    @State private var pinInput: String = ""
    @State private var pinError: String = ""
    @FocusState private var isPINFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                // MARK: - My Settings (always visible)
                Section("My Settings") {
                    // Change PIN
                    if let bartender = vm.currentShift?.openedBy {
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

                    // Appearance
                    Picker("Appearance", selection: $vm.colorScheme) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }

                    // Show Tax
                    Toggle("Show Tax", isOn: Binding(
                        get: { vm.printerSettings.showTax },
                        set: { vm.printerSettings.showTax = $0 }
                    ))

                    // Show Server Name
                    Toggle("Show Server Name", isOn: Binding(
                        get: { vm.printerSettings.showServer },
                        set: { vm.printerSettings.showServer = $0 }
                    ))
                }

                // MARK: - Admin Access
                Section("Admin Access") {
                    if vm.isAdminUnlocked {
                        Button(role: .destructive) {
                            vm.lockAdmin()
                        } label: {
                            Label("Lock Admin", systemImage: "lock.fill")
                        }
                    } else {
                        Button {
                            pinInput = ""
                            pinError = ""
                            showingUnlockPIN = true
                        } label: {
                            Label("Unlock Admin", systemImage: "lock.open.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.borderedProminent)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }

                // MARK: - Admin Sections (visible only when unlocked)
                if vm.isAdminUnlocked {
                    Section("Data") {
                        NavigationLink {
                            AdminBackupsView()
                                .environmentObject(vm)
                        } label: {
                            Label("Backups", systemImage: "externaldrive.fill.badge.icloud")
                        }
                    }

                    Section("Catalog") {
                        NavigationLink {
                            AdminProductsView()
                                .environmentObject(vm)
                        } label: {
                            Label("Products", systemImage: "shippingbox")
                        }

                        NavigationLink {
                            PricingRulesView()
                                .environmentObject(vm)
                        } label: {
                            Label("Pricing Rules", systemImage: "dollarsign.circle")
                        }
                    }

                    Section("Payments") {
                        NavigationLink {
                            AdminPaymentsView()
                                .environmentObject(vm)
                        } label: {
                            Label("Payments", systemImage: "creditcard")
                        }
                    }

                    Section("Operations") {
                        NavigationLink {
                            AdminChipsView()
                                .environmentObject(vm)
                        } label: {
                            Label("Chips", systemImage: "circle.grid.2x2.fill")
                        }

                        NavigationLink {
                            AdminReportsView()
                                .environmentObject(vm)
                        } label: {
                            Label("Reports", systemImage: "doc.plaintext")
                        }

                        NavigationLink {
                            AnalyticsView()
                                .environmentObject(vm)
                        } label: {
                            Label("Analytics", systemImage: "chart.bar.xaxis")
                        }

                        NavigationLink {
                            InventoryOverviewView()
                                .environmentObject(vm)
                        } label: {
                            Label("Inventory", systemImage: "box.truck")
                        }

                        NavigationLink {
                            AuditLogView()
                                .environmentObject(vm)
                        } label: {
                            Label("Audit Log", systemImage: "doc.text.magnifyingglass")
                        }

                        NavigationLink {
                            PendingCocktailsView()
                                .environmentObject(vm)
                        } label: {
                            Label("Pending Cocktails", systemImage: "clock.badge.checkmark")
                        }

                        NavigationLink {
                            VoidLogView()
                                .environmentObject(vm)
                        } label: {
                            Label("Void Log", systemImage: "trash.slash")
                        }
                    }

                    Section("Hardware") {
                        NavigationLink {
                            PrinterSettingsView()
                                .environmentObject(vm)
                        } label: {
                            Label("Printer", systemImage: "printer.fill")
                        }
                    }

                    Section("Staff") {
                        NavigationLink {
                            AdminStaffView()
                                .environmentObject(vm)
                        } label: {
                            Label("Staff", systemImage: "person.2.fill")
                        }
                    }

                    Section("Security") {
                        NavigationLink {
                            AdminSecurityView()
                                .environmentObject(vm)
                        } label: {
                            Label("Security & PIN", systemImage: "lock.shield")
                        }
                    }
                }
            }
            .navigationTitle("Admin")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingUnlockPIN) {
            adminUnlockSheet
        }
    }

    // MARK: - Inline Unlock Sheet

    @ViewBuilder
    private var adminUnlockSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "lock.shield")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Admin Access")
                    .font(.title)
                    .bold()

                Text("Enter the manager PIN to access admin features")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    SecureField("Enter PIN", text: $pinInput)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .focused($isPINFocused)
                        .onChange(of: pinInput) { _, _ in
                            pinError = ""
                        }
                        .onSubmit {
                            attemptUnlock()
                        }

                    if !pinError.isEmpty {
                        Text(pinError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 40)

                Button(action: attemptUnlock) {
                    Text("Unlock")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(pinInput.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .disabled(pinInput.isEmpty)
                .padding(.horizontal, 40)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingUnlockPIN = false
                    }
                }
            }
            .onAppear {
                isPINFocused = true
            }
        }
    }

    // MARK: - Helpers

    private func attemptUnlock() {
        let success = vm.unlockAdmin(with: pinInput)
        if success {
            showingUnlockPIN = false
            pinInput = ""
        } else {
            pinError = "Incorrect PIN. Please try again."
            pinInput = ""
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
    }
}
