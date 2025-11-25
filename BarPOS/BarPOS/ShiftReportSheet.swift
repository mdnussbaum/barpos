import SwiftUI

struct ShiftReportSheet: View {
    let report: ShiftReport
    var onDismiss: () -> Void
    
    @EnvironmentObject var vm: InventoryVM
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingShareSheet = false
    @State private var pdfToShare: URL?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(report.bartenderName)
                            .font(.title2)
                            .bold()
                        Text(report.formattedDate)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(report.formattedStartTime) - \(report.formattedEndTime)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Cash Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cash Summary")
                            .font(.headline)
                        
                        HStack {
                            Text("Opening Cash")
                            Spacer()
                            Text((report.openingCash ?? 0).currencyString())
                                .bold()
                        }
                        
                        HStack {
                            Text("Cash Sales")
                            Spacer()
                            Text(report.cashSales.currencyString())
                                .bold()
                        }
                        
                        HStack {
                            Text("Expected Cash")
                            Spacer()
                            Text(report.expectedCash.currencyString())
                                .bold()
                        }
                        
                        HStack {
                            Text("Counted Cash")
                            Spacer()
                            Text((report.closingCash ?? 0).currencyString())
                                .bold()
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("Over/Short")
                                .bold()
                            Spacer()
                            Text(report.overShort.currencyString())
                                .bold()
                                .foregroundStyle(report.overShort >= 0 ? .green : .red)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Sales Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Sales Summary")
                            .font(.headline)
                        
                        HStack {
                            Text("Tabs Closed")
                            Spacer()
                            Text("\(report.tabsCount)")
                                .bold()
                        }
                        
                        HStack {
                            Text("Gross Sales")
                            Spacer()
                            Text(report.grossSales.currencyString())
                                .bold()
                        }
                        
                        HStack {
                            Text("Net Sales")
                            Spacer()
                            Text(report.netSales.currencyString())
                        }
                        
                        HStack {
                            Text("Tax Collected")
                            Spacer()
                            Text(report.taxCollected.currencyString())
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Payment Methods
                    VStack(alignment: .leading, spacing: 12) {
                        Text("By Payment Method")
                            .font(.headline)
                        
                        HStack {
                            Text("💵 Cash")
                            Spacer()
                            Text(report.cashSales.currencyString())
                                .bold()
                        }
                        
                        HStack {
                            Text("💳 Card")
                            Spacer()
                            Text(report.cardSales.currencyString())
                                .bold()
                        }
                        
                        HStack {
                            Text("⚪️ Other")
                            Spacer()
                            Text(report.otherSales.currencyString())
                                .bold()
                        }
                    }
                    .padding(.horizontal)
                    
                    if report.flagged, let note = report.flagNote {
                        Divider()
                        
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Shift Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // Action buttons at bottom
                VStack(spacing: 0) {
                    Divider()
                    HStack(spacing: 16) {
                        Button {
                            generateAndSharePDF()
                        } label: {
                            Label("Email / Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            generateAndSharePDF()
                        } label: {
                            Label("Save PDF", systemImage: "arrow.down.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            generateAndPrint()
                        } label: {
                            Label("Print", systemImage: "printer")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let pdfURL = pdfToShare {
                    ShareSheet(items: [pdfURL])
                }
            }
        }
    }
    
    private func generateAndSharePDF() {
        guard let pdfURL = PDFGenerator.generateShiftReportPDF(
            report: report,
            closedTabs: vm.allClosedTabs.filter { $0.bartenderID == report.bartenderID }
        ) else {
            print("❌ Failed to generate PDF")
            return
        }
        
        // Save to iCloud Drive
        let filename = "ShiftReport_\(report.formattedFileDate).pdf"
        let savedURL = FileManagerHelper.saveToiCloud(fileURL: pdfURL, filename: filename) ?? pdfURL
        
        // Show share sheet
        pdfToShare = savedURL
        showingShareSheet = true
    }
    
    private func generateAndPrint() {
        // TODO: Implement receipt printer integration
        print("🖨️ Print receipt")
        
        // For now, just generate and share
        generateAndSharePDF()
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
