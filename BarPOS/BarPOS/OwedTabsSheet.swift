import SwiftUI

struct OwedTabsSheet: View {
    @EnvironmentObject var vm: InventoryVM

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("These tabs walked without paying") {
                    ForEach(vm.owedTabs, id: \.id) { walkout in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(walkout.tabName).font(.headline)
                                Text("\((walkout.lostAmount ?? 0).currencyString()) • \(walkout.closedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Cash") {
                                if vm.recoverWalkout(walkout, method: .cash) != nil {
                                    dismiss()
                                }
                            }
                            .buttonStyle(.bordered)

                            Button("Card") {
                                if vm.recoverWalkout(walkout, method: .card) != nil {
                                    dismiss()
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Owed Tabs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
