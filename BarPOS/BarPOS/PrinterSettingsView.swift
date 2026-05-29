import SwiftUI

struct PrinterSettingsView: View {
    @EnvironmentObject var vm: InventoryVM
    @ObservedObject private var printer = EpsonPrinterManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var headerText: String = ""
    @State private var footerText: String = ""
    @State private var autoPrint: Bool = true
    @State private var autoDrawer: Bool = true
    @State private var showingTestResult = false
    @State private var testResultTitle = "Test Print"
    @State private var testResultMessage = ""
    @State private var showingPINPrompt = false

    var body: some View {
        Form {
            // Connection Status
            Section("Printer Status") {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(printer.printerName)

                        Text(printer.lastStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let lastErrorMessage = printer.lastErrorMessage {
                            Text(lastErrorMessage)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }

                    Spacer()

                    if printer.isConnected {
                        HStack(spacing: 4) {
                            Circle().fill(.green).frame(width: 8, height: 8)
                            Text("Connected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Unavailable")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("Epson TM-M30II (Ethernet)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Actions
            Section {
                Button("Test Print") {
                    Task {
                        let success = await printer.testPrint()
                        testResultTitle = "Test Print"
                        testResultMessage = success
                            ? "Test print successful."
                            : printer.lastErrorMessage ?? "Test print failed. POS can still run, but receipts will not print until the printer is connected."
                        showingTestResult = true
                    }
                }

                Button("Open Cash Drawer") {
                    if vm.isAdminUnlocked {
                        Task {
                            let success = await printer.openCashDrawer()
                            if !success {
                                testResultTitle = "Cash Drawer"
                                testResultMessage = printer.lastErrorMessage ?? "Cash drawer failed. POS can still run."
                                showingTestResult = true
                            }
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
                Text("Connect an Epson TM-M30II printer via Ethernet. The printer will be discovered automatically on the local network.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Printer")
        .navigationBarTitleDisplayMode(.inline)
        .alert(testResultTitle, isPresented: $showingTestResult) {
            Button("OK") { }
        } message: {
            Text(testResultMessage)
        }
        .sheet(isPresented: $showingPINPrompt) {
            AdminPINPrompt(onUnlock: {
                showingPINPrompt = false
                Task {
                    let success = await printer.openCashDrawer()
                    if !success {
                        testResultTitle = "Cash Drawer"
                        testResultMessage = printer.lastErrorMessage ?? "Cash drawer failed. POS can still run."
                        showingTestResult = true
                    }
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
