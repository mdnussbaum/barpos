import SwiftUI
import PDFKit

struct SavedReceiptsView: View {
    @EnvironmentObject var vm: InventoryVM
    @StateObject private var printer = MockPrinterManager()
    @State private var receipts: [URL] = []
    @State private var selectedReceipt: URL?
    @State private var showingShareSheet = false
    
    var body: some View {
        List {
            if receipts.isEmpty {
                Text("No saved receipts yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(receipts, id: \.self) { url in
                    Button {
                        selectedReceipt = url
                        showingShareSheet = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(url.lastPathComponent)
                                .font(.headline)
                            Text(formatDate(url))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Saved Receipts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh") {
                    loadReceipts()
                }
            }
        }
        .onAppear {
            loadReceipts()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = selectedReceipt {
                ShareSheet(items: [url])
            }
        }
    }
    
    private func loadReceipts() {
        receipts = printer.getRecentReceipts(limit: 50)
    }
    
    private func formatDate(_ url: URL) -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let date = attributes[.creationDate] as? Date else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
// MARK: - Share Sheet Helper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

