//
//  ShiftSummarySheet.swift
//  BarPOSv2
//
//  Created by Michael Nussbaum on 10/9/25.
//


import SwiftUI

struct ShiftSummarySheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var vm: InventoryVM

    let shift: ShiftRecord
    var onClose: (() -> Void)? = nil

    // Safe pulls from the shift metrics we record during the shift
    private var tabsCount: Int { shift.metrics.tabsCount }
    private var gross: Decimal { shift.metrics.grossSales }
    private var net: Decimal { shift.metrics.netSales }
    private var tax: Decimal { shift.metrics.taxCollected }
    private var cash: Decimal { shift.metrics.byPayment[.cash] ?? 0 }
    private var card: Decimal { shift.metrics.byPayment[.card] ?? 0 }
    private var other: Decimal { shift.metrics.byPayment[.other] ?? 0 }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(shift.openedBy?.name ?? "—")
                                .font(.headline)
                            Text("\(shift.startedAt.formatted(date: .abbreviated, time: .shortened)) – now")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(gross.currencyString()).bold()
                            Text("\(tabsCount) tickets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Shift Summary")
                }

                Section("Sales") {
                    row("Gross", gross)
                    row("Net",   net)
                    row("Tax",   tax)

                    Divider()

                    row("Cash",  cash)
                    row("Card",  card)
                    row("Other", other)
                }

                if let opening = shift.openingCash {
                    Section("Opening Cash") {
                        row("Opening Balance", opening)
                    }
                }
            }
            .navigationTitle("Shift Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onClose?()
                        dismiss()
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func row(_ title: String, _ amount: Decimal) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(amount.currencyString()).bold()
        }
    }
}