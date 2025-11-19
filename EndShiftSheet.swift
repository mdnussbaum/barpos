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
                        HStack {
                            Text("Counted Cash")
                            Spacer()
                            TextField("0.00", text: $closingCashString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 120)
                                .textFieldStyle(.roundedBorder)
                        }
                        Text("Type the physically counted cash total. We will compare it to opening + cash sales in the report.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
            .navigationTitle("End Shift")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") {
                        // Guard on any open tabs
                        if vm.hasUnsettledTabs {
                            unsettledDetail = vm.unsettledTabs.map { tab in
                                let items = tab.lines.map { "• \($0.qty)x \($0.product.name)" }.joined(separator: "\n")
                                return "\(tab.name)\n\(items)"
                            }.joined(separator: "\n\n")
                            showUnsettledAlert = true
                            return
                        }

                        // Require a valid counted-cash entry
                        guard let counted = Decimal(string: closingCashString) else { return }

                        if vm.settleShift(closingCash: counted) {
                            dismiss()
                        } else {
                            // Shouldn’t happen because we check above, but keep a fallback
                            showUnsettledAlert = true
                        }
                    }
                    .disabled(vm.currentShift == nil)
                }
            }
            .onAppear {
                // Start empty so they have to type the counted amount
                closingCashString = ""
            }
            .alert("Unsettled Tabs", isPresented: $showUnsettledAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Close or clear the following tabs before ending the shift:\n\n\(unsettledDetail)")
            }
        }
    }
}
