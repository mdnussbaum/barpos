import SwiftUI

struct MyShiftDayView: View {
    @EnvironmentObject var vm: InventoryVM

    let day: Date
    let tickets: [CloseResult]
    let report: ShiftReport?

    @State private var presentingTicket: CloseResult? = nil

    var body: some View {
        List {
            // Optional banner with the day’s shift report totals
            if let rep = report {
                Section("Shift Summary") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rep.bartenderName).font(.headline)
                            Text(
                                "\(rep.startedAt.formatted(date: .abbreviated, time: .shortened)) – " +
                                "\(rep.endedAt.formatted(date: .abbreviated, time: .shortened))"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(rep.grossSales.currencyString()).bold()
                            Text("\(rep.tabsCount) tickets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if vm.isAdminUnlocked, rep.flagged {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                                .accessibilityLabel("Flagged discrepancy")
                        }
                    }
                }
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
        }
        .navigationTitle(day.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $presentingTicket) { res in
            SummarySheet(result: res) { presentingTicket = nil }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}
