//
//  UnsettledTabsSheet.swift
//  BarPOSv2
//
//  Created by Michael Nussbaum on 9/25/25.
//


import SwiftUI

struct UnsettledTabsSheet: View {
    let tabs: [TabTicket]
    let onJumpToTab: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("These tabs still have items") {
                    ForEach(tabs, id: \.id) { t in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(t.name).font(.headline)
                                Text("\(t.lines.count) item\(t.lines.count == 1 ? "" : "s") • \(t.total.currencyString())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Go to tab") {
                                onJumpToTab(t.id)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Close tabs to end shift")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}