//
//  AdminReportsListView.swift
//  BarPOSv2
//
//  Created by Michael Nussbaum on 9/26/25.
//


import SwiftUI

struct AdminReportsListView: View {
    @EnvironmentObject var vm: InventoryVM

    @State private var showOnlyFlagged = false
    @State private var presentingReport: ShiftReport?

    private var recentReports: [ShiftReport] {
        let sorted = vm.shiftReports.sorted { $0.endedAt > $1.endedAt }
        let trimmed = Array(sorted.prefix(50))
        return showOnlyFlagged ? trimmed.filter { $0.flagged } : trimmed
    }

    var body: some View {
        List {
            Section {
                Toggle("Flagged only", isOn: $showOnlyFlagged)
            }

            Section("Recent") {
                if recentReports.isEmpty {
                    Text(showOnlyFlagged ? "No flagged reports yet." : "No reports yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentReports) { rep in
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
                                if rep.flagged {
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
        .navigationTitle("Shift Reports")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $presentingReport) { rep in
            ShiftReportSheet(report: rep) { presentingReport = nil }
                .environmentObject(vm)
        }
    }
}
