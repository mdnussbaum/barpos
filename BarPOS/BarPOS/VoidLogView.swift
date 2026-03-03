import SwiftUI

struct VoidLogView: View {
    @EnvironmentObject var vm: InventoryVM

    var body: some View {
        List {
            if vm.voidLog.isEmpty {
                Text("No voided items recorded.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.voidLog) { record in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(record.productName)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(record.amount.currencyString())
                                .foregroundStyle(.red)
                        }
                        HStack {
                            Text("Tab: \(record.tabName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(record.bartenderName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(record.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Void Log")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !vm.voidLog.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear All", role: .destructive) {
                        vm.voidLog.removeAll()
                    }
                }
            }
        }
    }
}
