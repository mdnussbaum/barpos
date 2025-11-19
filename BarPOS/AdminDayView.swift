import SwiftUI

struct AdminDayView: View {
    @EnvironmentObject var vm: InventoryVM

    let day: Date
    let tickets: [CloseResult]
    let reports: [ShiftReport]

    @State private var presentingTicket: CloseResult? = nil
    @State private var presentingReport: ShiftReport? = nil
    @State private var showOnlyFlagged = false

    var filteredReports: [ShiftReport] {
        let sorted = reports.sorted { $0.endedAt > $1.endedAt }
        return showOnlyFlagged ? sorted.filter { $0.flagged } : sorted
    }

    var body: some View {
        List {
            Section {
                Toggle("Flagged reports only", isOn: $showOnlyFlagged)
            }

            Section("Tickets") {
                ForEach(tickets) { t in
                    Button {
                        presentingTicket = t
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(t.tabName).bold()
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

            Section("Shift Reports") {
                if filteredReports.isEmpty {
                    Text(showOnlyFlagged ? "No flagged reports." : "No reports.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredReports) { rep in
                        Button {
                            presentingReport = rep
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading) {
                                    Text(rep.bartenderName).font(.headline)
                                    Text(
                                        "\(rep.startedAt.formatted(date: .abbreviated, time: .shortened)) – " +
                                        "\(rep.endedAt.formatted(date: .omitted, time: .shortened))"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(rep.grossSales.currencyString()).font(.headline)

                                if vm.isAdminUnlocked, rep.flagged {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.yellow)
                                        .accessibilityLabel("Flagged discrepancy")
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(day.formatted(date: .complete, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $presentingTicket) { res in
            SummarySheet(result: res) { presentingTicket = nil }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $presentingReport) { rep in
            ShiftReportSheet(report: rep) { presentingReport = nil }
                .environmentObject(vm)
        }
    }
}
