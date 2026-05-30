//
//  DayReportSheet.swift
//  BarPOS
//
//  Created by Michael Nussbaum on 11/29/25.
//


import SwiftUI

struct DayReportSheet: View {
    let report: DayReport
    var onDismiss: () -> Void
    
    @EnvironmentObject var vm: InventoryVM
    @Environment(\.dismiss) private var dismiss
    
    @State private var pdfToShare: URL?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Day Report")
                            .font(.title2)
                            .bold()
                        Text(report.formattedDate)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("\(report.shiftCount) shift\(report.shiftCount == 1 ? "" : "s") • \(report.bartenderNames.joined(separator: ", "))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Day Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Day Summary")
                            .font(.headline)
                        
                        HStack {
                            Text("Total Tabs Closed")
                            Spacer()
                            Text("\(report.totalTabsCount)")
                                .bold()
                        }
                        
                        HStack {
                            Text("Gross Sales")
                            Spacer()
                            Text(report.totalGrossSales.currencyString())
                                .bold()
                        }
                        
                        HStack {
                            Text("Net Sales")
                            Spacer()
                            Text(report.totalNetSales.currencyString())
                        }
                        
                        HStack {
                            Text("Tax Collected")
                            Spacer()
                            Text(report.totalTaxCollected.currencyString())
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
                            Text(report.totalCashSales.currencyString())
                                .bold()
                        }
                        
                        HStack {
                            Text("💳 Card")
                            Spacer()
                            Text(report.totalCardSales.currencyString())
                                .bold()
                        }
                        
                        HStack {
                            Text("⚪️ Other")
                            Spacer()
                            Text(report.totalOtherSales.currencyString())
                                .bold()
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Breakdown by Bartender
                    VStack(alignment: .leading, spacing: 12) {
                        Text("By Bartender")
                            .font(.headline)
                        
                        ForEach(report.shifts.sorted(by: { $0.startedAt < $1.startedAt }), id: \.bartenderID) { shift in
                            VStack(spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(shift.bartenderName)
                                            .font(.subheadline)
                                            .bold()
                                        Text("\(shift.formattedStartTime) - \(shift.formattedEndTime)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(shift.grossSales.currencyString())
                                        .font(.subheadline)
                                        .bold()
                                }
                                
                                HStack {
                                    Text("\(shift.tabsCount) tabs")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    if shift.flagged {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                            .font(.caption)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Day Report")
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
        }
    }
    
    private func generateAndSharePDF() {
        guard let pdfURL = PDFGenerator.generateDayReportPDF(report: report) else {
            print("❌ Failed to generate PDF")
            return
        }
        let filename = "DayReport_\(report.formattedFileDate).pdf"
        let savedURL = FileManagerHelper.saveToiCloud(fileURL: pdfURL, filename: filename) ?? pdfURL
        presentShareSheet(for: savedURL)
    }

    private func presentShareSheet(for url: URL) {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        var topVC = rootVC
        while let presented = topVC.presentedViewController { topVC = presented }
        controller.popoverPresentationController?.sourceView = topVC.view
        controller.popoverPresentationController?.sourceRect = CGRect(
            x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0
        )
        controller.popoverPresentationController?.permittedArrowDirections = []
        topVC.present(controller, animated: true)
    }
    
    private func generateAndPrint() {
        // TODO: Implement receipt printer integration
        print("🖨️ Print day report")
        generateAndSharePDF()
    }
}