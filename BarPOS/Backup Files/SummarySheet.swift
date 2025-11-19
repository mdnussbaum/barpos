import SwiftUI

struct SummarySheet: View {
    let result: CloseResult
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tab Closed")
                            .font(.title2).bold()
                        Text(result.tabName)
                            .font(.headline)
                        Text(result.closedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Totals block
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Totals")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 8) {
                            LabeledValueRow(label: "Subtotal", value: safeCurrency(result.subtotal))
                            LabeledValueRow(label: "Tax", value: safeCurrency(derivedTax()))
                            Divider()
                            LabeledValueRow(label: "Total", value: safeCurrency(result.total), bold: true)
                            LabeledValueRow(label: "Cash Tendered", value: safeCurrency(result.cashTendered))
                            LabeledValueRow(label: "Change", value: safeCurrency(result.changeDue), accent: true)
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }

                    // Items block
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Items")
                            .font(.headline)

                        if result.lines.isEmpty {
                            Text("No items.")
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(spacing: 6) {
                                ForEach(Array(result.lines.enumerated()), id: \.offset) { _, line in
                                    HStack(alignment: .firstTextBaseline) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(line.productName.isEmpty ? "Unknown Item" : line.productName)
                                                .font(.body)
                                            Text("Qty \(line.qty)  •  @ \(safeCurrency(line.unitPrice))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(safeCurrency(line.lineTotal))
                                            .font(.body).bold()
                                    }
                                    .padding(.vertical, 6)

                                    Divider()
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color.secondary.opacity(0.15))
                            )
                        }
                    }
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDone() }
                        .bold()
                }
            }
        }
    }

    // MARK: - Helpers

    private func safeCurrency(_ value: Decimal) -> String {
        value.currencyString()
    }

    private func derivedTax() -> Decimal {
        let tax = result.total - result.subtotal
        return tax >= 0 ? tax : 0
    }
}

// MARK: - Small UI helper
private struct LabeledValueRow: View {
    let label: String
    let value: String
    var bold: Bool = false
    var accent: Bool = false

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(bold ? .headline : .body)
                .foregroundStyle(accent ? Color.green : Color.primary)
        }
    }
}
