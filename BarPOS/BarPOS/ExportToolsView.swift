import SwiftUI
import UniformTypeIdentifiers

struct ExportToolsView: View {
    let tickets: [CloseResult]
    let reports: [ShiftReport]
    let dateRange: String
    
    @State private var showingShareSheet = false
    @State private var fileToShare: URL?
    @State private var exportStatus: String?
    
    var body: some View {
        List {
            Section {
                Text("Export data for: \(dateRange)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Section("Export Formats") {
                Button {
                    exportCSV()
                } label: {
                    Label("Export to CSV", systemImage: "tablecells")
                }
                
                Button {
                    exportPDF()
                } label: {
                    Label("Export to PDF", systemImage: "doc.text")
                }
                
                Button {
                    exportJSON()
                } label: {
                    Label("Export to JSON", systemImage: "doc.badge.gearshape")
                }
            }
            
            if let status = exportStatus {
                Section {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(status.contains("success") ? .green : .red)
                }
            }
            
            Section("Summary") {
                LabeledContent("Total Tickets", value: "\(tickets.count)")
                LabeledContent("Total Shifts", value: "\(reports.count)")
                LabeledContent("Total Revenue", value: tickets.reduce(0) { $0 + $1.total }.currencyString())
            }
        }
        .navigationTitle("Export Tools")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            if let url = fileToShare {
                ExportShareSheet(items: [url])
            }
        }
    }
    
    // MARK: - Export Functions
    
    private func exportCSV() {
        var csv = "Date,Tab Name,Bartender,Subtotal,Tax,Total,Payment Method\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for ticket in tickets.sorted(by: { $0.closedAt < $1.closedAt }) {
            let dateStr = dateFormatter.string(from: ticket.closedAt)
            let tax = ticket.total - ticket.subtotal
            
            csv += "\"\(dateStr)\","
            csv += "\"\(ticket.tabName)\","
            csv += "\"\(ticket.bartenderName ?? "Unknown")\","
            csv += "\(ticket.subtotal),"
            csv += "\(tax),"
            csv += "\(ticket.total),"
            csv += "\"\(ticket.paymentMethod.rawValue)\"\n"
        }
        
        saveAndShare(content: csv, filename: "sales-export.csv", type: .commaSeparatedText)
    }
    
    private func exportPDF() {
        // Generate a simple text-based report
        var text = "SALES REPORT\n"
        text += "Date Range: \(dateRange)\n\n"
        text += "SUMMARY\n"
        text += "-------\n"
        text += "Total Tickets: \(tickets.count)\n"
        text += "Total Revenue: \(tickets.reduce(0) { $0 + $1.total }.currencyString())\n"
        text += "Total Shifts: \(reports.count)\n\n"
        
        text += "TICKETS\n"
        text += "-------\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy HH:mm"
        
        for ticket in tickets.sorted(by: { $0.closedAt < $1.closedAt }) {
            text += "\(dateFormatter.string(from: ticket.closedAt)) - "
            text += "\(ticket.tabName) - "
            text += "\(ticket.total.currencyString())\n"
        }
        
        saveAndShare(content: text, filename: "sales-report.txt", type: .plainText)
    }
    
    private func exportJSON() {
        struct ExportData: Codable {
            let dateRange: String
            let tickets: [CloseResult]
            let reports: [ShiftReport]
        }
        
        let data = ExportData(
            dateRange: dateRange,
            tickets: tickets,
            reports: reports
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let jsonData = try encoder.encode(data)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                saveAndShare(content: jsonString, filename: "export.json", type: .json)
            }
        } catch {
            exportStatus = "Export failed: \(error.localizedDescription)"
        }
    }
    
    private func saveAndShare(content: String, filename: String, type: UTType) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try content.write(to: tempURL, atomically: true, encoding: .utf8)
            fileToShare = tempURL
            showingShareSheet = true
            exportStatus = "Export successful!"
        } catch {
            exportStatus = "Export failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Export Share Sheet (renamed to avoid conflict)
struct ExportShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
