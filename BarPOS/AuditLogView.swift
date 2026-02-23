import SwiftUI

struct AuditLogView: View {
    @EnvironmentObject var vm: InventoryVM
    @State private var searchText: String = ""
    
    private var filteredEntries: [AuditLogEntry] {
        if searchText.isEmpty {
            return vm.auditLog
        } else {
            return vm.auditLog.filter {
                $0.productName.localizedCaseInsensitiveContains(searchText) ||
                $0.reason.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if filteredEntries.isEmpty {
                    ContentUnavailableView {
                        Label("No Audit Entries", systemImage: "doc.text.magnifyingglass")
                    } description: {
                        Text(searchText.isEmpty ? "Stock adjustments will appear here" : "No matching audit entries")
                    }
                } else {
                    List {
                        ForEach(filteredEntries) { entry in
                            VStack(alignment: .leading, spacing: 8) {
                                // Product name and date
                                HStack {
                                    Text(entry.productName)
                                        .font(.headline)
                                    
                                    Spacer()
                                    
                                    Text(entry.date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                // Time
                                Text(entry.date, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                
                                // Variance badge
                                HStack(spacing: 12) {
                                    Text("Variance:")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    Text(varianceText(entry.variance))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(varianceColor(entry.variance))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(varianceColor(entry.variance).opacity(0.15))
                                        .clipShape(Capsule())
                                    
                                    Spacer()
                                    
                                    // Stock change indicator
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(entry.oldQuantity.plainString()) → \(entry.newQuantity.plainString())")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                // Reason
                                if !entry.reason.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "quote.opening")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        
                                        Text(entry.reason)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .italic()
                                    }
                                    .padding(.top, 2)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Audit Log")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search products or reasons")
        }
    }
    
    // MARK: - Helper Functions
    
    private func varianceText(_ variance: Decimal) -> String {
        if variance > 0 {
            return "+\(variance.plainString())"
        } else if variance < 0 {
            return "\(variance.plainString())"
        } else {
            return "±0"
        }
    }
    
    private func varianceColor(_ variance: Decimal) -> Color {
        if variance > 0 {
            return .green
        } else if variance < 0 {
            return .red
        } else {
            return .secondary
        }
    }
}

#Preview {
    let vm = InventoryVM()
    
    // Add sample audit entries
    vm.auditLog = [
        AuditLogEntry(
            date: Date(),
            productID: UUID(),
            productName: "Tito's Vodka",
            oldQuantity: 12,
            newQuantity: 10,
            variance: -2,
            reason: "Broken bottle"
        ),
        AuditLogEntry(
            date: Date().addingTimeInterval(-3600),
            productID: UUID(),
            productName: "Jack Daniel's",
            oldQuantity: 8,
            newQuantity: 12,
            variance: 4,
            reason: "Physical count correction"
        ),
        AuditLogEntry(
            date: Date().addingTimeInterval(-7200),
            productID: UUID(),
            productName: "Corona Extra",
            oldQuantity: 24,
            newQuantity: 18,
            variance: -6,
            reason: "Case damaged during delivery"
        )
    ]
    
    return AuditLogView()
        .environmentObject(vm)
}
