import SwiftUI

struct ShiftReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var vm: InventoryVM

    let report: ShiftReport
    var onClose: (() -> Void)? = nil

    // Derived (read-only)
    private var expectedCash: Decimal {
        (report.openingCash ?? 0) + report.cashSales
    }

    private var overShort: Decimal {
        report.overShort // already stored when we built the report
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Summary
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(report.bartenderName)
                                .font(.headline)
                            Text(
                                "\(report.startedAt.formatted(date: .abbreviated, time: .shortened)) – " +
                                "\(report.endedAt.formatted(date: .abbreviated, time: .shortened))"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(report.grossSales.currencyString()).bold()
                            Text("\(report.tabsCount) tickets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if report.flagged {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .symbolRenderingMode(.monochrome)
                                .foregroundColor(Color.yellow)
                            Text(report.flagNote ?? "Discrepancy detected.")
                                .font(.footnote)
                        }
                        .padding(.top, 6)
                    }
                } header: {
                    Text("Shift Summary")
                }

                // MARK: - Sales breakdown
                Section("Sales") {
                    row("Gross", report.grossSales)
                    row("Net", report.netSales)
                    row("Tax", report.taxCollected)

                    Divider()

                    row("Cash", report.cashSales)
                    row("Card", report.cardSales)
                    row("Other", report.otherSales)
                }

                // MARK: - Cash reconciliation
                Section("Cash Reconciliation") {
                    row("Opening Balance", report.openingCash ?? 0)
                    row("Cash Sales", report.cashSales)
                    row("Expected (Open + Cash)", expectedCash)
                    row("Closing Count", report.closingCash ?? 0)

                    Divider()

                    // Over/Short with color hint
                    HStack {
                        Text("Over / Short")
                        Spacer()
                        Text(overShort.currencyString())
                            .bold()
                            .foregroundColor(overShort == 0 ? Color.primary : (overShort > 0 ? Color.green : Color.red))
                    }
                }

                // MARK: - Tickets list (optional)
                if !report.tickets.isEmpty {
                    Section("Tickets") {
                        ForEach(report.tickets) { t in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.tabName)
                                    Text(t.closedAt.formatted(date: .omitted, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(t.total.currencyString()).bold()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Shift Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onClose?()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Helpers
    private func row(_ title: String, _ amount: Decimal) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(amount.currencyString()).bold()
        }
    }
}
