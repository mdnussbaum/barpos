import SwiftUI

struct EndShiftSheet: View {
    @EnvironmentObject var vm: InventoryVM
    @Environment(\.dismiss) private var dismiss

    @State private var closingCashString: String = ""
    @State private var showUnsettledAlert = false
    @State private var unsettledDetail = ""


    
    var body: some View {
        NavigationStack {
            List {
                if let shift = vm.currentShift {
                    Section("Shift") {
                        LabeledContent("Bartender", value: shift.openedBy?.name ?? "—")
                        LabeledContent("Started", value: shift.startedAt.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("Opening Balance", value: (shift.openingCash ?? 0).currencyString())
                    }

                    Section("Count drawer cash") {
                        VStack(spacing: 12) {
                            HStack {
                                Text("Counted Cash")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(closingCashString.isEmpty ? "$0.00" : "$\(closingCashString)")
                                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                                    .foregroundStyle(closingCashString.isEmpty ? .secondary : .primary)
                            }
                            .padding(.vertical, 4)

                            let cashKeys: [[String]] = [
                                ["7","8","9"],
                                ["4","5","6"],
                                ["1","2","3"],
                                ["00","0","⌫"]
                            ]
                            VStack(spacing: 8) {
                                ForEach(cashKeys, id: \.self) { row in
                                    HStack(spacing: 8) {
                                        ForEach(row, id: \.self) { key in
                                            Button {
                                                handleCashKey(key)
                                            } label: {
                                                Text(key)
                                                    .font(.title3)
                                                    .fontWeight(.medium)
                                                    .frame(maxWidth: .infinity, minHeight: 52)
                                                    .background(key == "⌫" ? Color(.systemFill) : Color(.secondarySystemBackground))
                                                    .foregroundStyle(key == "⌫" ? .red : .primary)
                                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }

                            Text("Enter the physically counted cash total. We'll compare it to opening + cash sales in the report.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    Section("Totals (so far)") {
                        let cashSales  = shift.metrics.byPayment[.cash] ?? 0
                        let cardSales  = shift.metrics.byPayment[.card] ?? 0
                        let otherSales = shift.metrics.byPayment[.other] ?? 0
                        LabeledContent("Cash Sales (closed)", value: cashSales.currencyString())
                        LabeledContent("Card Sales (closed)", value: cardSales.currencyString())
                        LabeledContent("Other Sales (closed)", value: otherSales.currencyString())
                    }
                } else {
                    Text("No active shift.")
                        .foregroundStyle(.secondary)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("End Shift")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") {
                        // Check for unsettled tabs
                        if vm.hasUnsettledTabs {
                            unsettledDetail = vm.unsettledTabs.map { tab in
                                let items = tab.lines.map { "• \($0.qty)x \($0.product.name)" }.joined(separator: "\n")
                                return "\(tab.name)\n\(items)"
                            }.joined(separator: "\n\n")
                            
                            showUnsettledAlert = true
                            return
                        }

                        // Require a valid counted-cash entry
                        guard let counted = Decimal(string: closingCashString), counted >= 0 else { return }

                        // Settle shift
                        if vm.settleShift(closingCash: counted) {
                            dismiss()
                        }
                    }
                    .disabled(vm.currentShift == nil)
                }
            }
            .onAppear {
                closingCashString = ""
            }
            .confirmationDialog("Unsettled Tabs", isPresented: $showUnsettledAlert) {
                Button("Close All Tabs", role: .destructive) {
                    vm.closeAllUnsettledTabs()
                    if let counted = Decimal(string: closingCashString) {
                        _ = vm.settleShift(closingCash: counted)
                        dismiss()
                    }
                }
                Button("Carry Over to Next Shift") {
                    if let counted = Decimal(string: closingCashString) {
                        vm.settleShiftWithCarryOver(closingCash: counted)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You have open tabs with items:\n\n\(unsettledDetail)\n\nWhat would you like to do?")
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    private func handleCashKey(_ key: String) {
        switch key {
        case "⌫":
            if !closingCashString.isEmpty { closingCashString.removeLast() }
        case "00":
            let digits = closingCashString.replacingOccurrences(of: ".", with: "")
            if !digits.isEmpty { closingCashString = formatCashCents(digits + "00") }
        default:
            let digits = closingCashString.replacingOccurrences(of: ".", with: "") + key
            closingCashString = formatCashCents(digits)
        }
    }

    private func formatCashCents(_ digits: String) -> String {
        let trimmed = String(digits.drop(while: { $0 == "0" }))
        let d = trimmed.isEmpty ? "0" : trimmed
        if d.count <= 2 {
            let padded = String(repeating: "0", count: 3 - d.count) + d
            return "0.\(padded.suffix(2))"
        } else {
            return "\(d.dropLast(2)).\(d.suffix(2))"
        }
    }
}

// MARK: - Report Options Sheet

struct ReportOptionsSheet: View {
    let report: ShiftReport
    @ObservedObject var printer: MockPrinterManager
    @EnvironmentObject var vm: InventoryVM
    @Environment(\.dismiss) private var dismiss

    let onDone: () -> Void

    @State private var showingReport = false
    @State private var pdfToShare: IdentifiableURL?

    private struct IdentifiableURL: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        NavigationStack {
            List {
                Button {
                    showingReport = true
                } label: {
                    Label("View on Screen", systemImage: "doc.text")
                }

                Button {
                    Task {
                        await printReport()
                    }
                } label: {
                    Label("Print Report", systemImage: "printer")
                }

                Button {
                    Task {
                        await generateAndSharePDF()
                    }
                } label: {
                    Label("Email/Share PDF", systemImage: "square.and.arrow.up")
                }
            }
            .navigationTitle("Shift Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDone()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingReport) {
                ShiftReportSheet(report: report) {
                    showingReport = false
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $pdfToShare) { wrapper in
                ShareSheet(items: [wrapper.url])
            }
        }
    }

    private func printReport() async {
        let content = ReceiptFormatter.formatShiftReport(report, settings: vm.printerSettings)
        let receipt = ReceiptData(type: .shiftReport(report), content: content, settings: vm.printerSettings)
        _ = await printer.printReceipt(receipt)
    }

    private func generateAndSharePDF() async {
        let content = ReceiptFormatter.formatShiftReport(report, settings: vm.printerSettings)
        let receipt = ReceiptData(type: .shiftReport(report), content: content, settings: vm.printerSettings)
        let result = await printer.printReceipt(receipt)

        if case .success(let pdfURL) = result, let url = pdfURL {
            pdfToShare = IdentifiableURL(url: url)
        }
    }
}

