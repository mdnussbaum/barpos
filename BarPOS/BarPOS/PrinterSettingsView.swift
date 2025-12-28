import SwiftUI

struct PrinterSettingsView: View {
    @EnvironmentObject var vm: InventoryVM
    @StateObject private var printer: MockPrinterManager
    @Environment(\.dismiss) private var dismiss

    @State private var headerText: String = ""
    @State private var footerText: String = ""
    @State private var autoPrint: Bool = true
    @State private var autoDrawer: Bool = true
    @State private var showingTestResult = false
    @State private var testResultMessage = ""
    @State private var showingPINPrompt = false

    init() {
        // Initialize printer with default settings
        _printer = StateObject(wrappedValue: MockPrinterManager())
    }

    var body: some View {
        Form {
            // Connection Status
            Section("Printer Status") {
                HStack {
                    Text(printer.printerName)
                    Spacer()
                    if printer.isConnected {
                        HStack(spacing: 4) {
                            Circle().fill(.green).frame(width: 8, height: 8)
                            Text("Connected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Disconnected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Mock Printer (generates PDFs)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Actions
            Section {
                Button("Test Print") {
                    Task {
                        let success = await printer.testPrint()
                        testResultMessage = success ? "Test print successful! Check Files app for PDF." : "Test print failed"
                        showingTestResult = true
                    }
                }

                Button("Open Cash Drawer") {
                    if vm.isAdminUnlocked {
                        Task {
                            await printer.openCashDrawer()
                        }
                    } else {
                        showingPINPrompt = true
                    }
                }
            } header: {
                Text("Actions")
            }

            // Receipt Settings
            Section("Receipt Settings") {
                TextField("Header Text", text: $headerText)
                    .onChange(of: headerText) { _, newValue in
                        vm.printerSettings.headerText = newValue
                    }

                TextField("Footer Text", text: $footerText)
                    .onChange(of: footerText) { _, newValue in
                        vm.printerSettings.footerText = newValue
                    }

                Toggle("Auto-print receipts", isOn: $autoPrint)
                    .onChange(of: autoPrint) { _, newValue in
                        vm.printerSettings.autoPrintReceipts = newValue
                    }

                Toggle("Auto-open drawer (cash)", isOn: $autoDrawer)
                    .onChange(of: autoDrawer) { _, newValue in
                        vm.printerSettings.autoOpenDrawer = newValue
                    }
            }

            Section {
                Text("When hardware arrives, you'll be able to connect to real printers here. For now, receipts are saved as PDFs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Printer")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Test Print", isPresented: $showingTestResult) {
            Button("OK") { }
        } message: {
            Text(testResultMessage)
        }
        .sheet(isPresented: $showingPINPrompt) {
            AdminPINPrompt(onUnlock: {
                showingPINPrompt = false
                Task {
                    await printer.openCashDrawer()
                }
            })
        }
        .onAppear {
            // Load settings from VM
            headerText = vm.printerSettings.headerText
            footerText = vm.printerSettings.footerText
            autoPrint = vm.printerSettings.autoPrintReceipts
            autoDrawer = vm.printerSettings.autoOpenDrawer
        }
    }
}

// MARK: - Admin PIN Prompt

private struct AdminPINPrompt: View {
    @EnvironmentObject var vm: InventoryVM
    @Environment(\.dismiss) private var dismiss
    @State private var pin: String = ""
    @State private var errorMessage: String = ""

    let onUnlock: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Enter Admin PIN")
                    .font(.headline)

                SecureField("PIN", text: $pin)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button("Unlock") {
                    if vm.unlockAdmin(with: pin) {
                        onUnlock()
                        dismiss()
                    } else {
                        errorMessage = "Incorrect PIN"
                        pin = ""
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Admin Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
