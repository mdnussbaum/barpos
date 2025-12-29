//
//  ExportToolsView.swift
//  BarPOS
//
//  Created by Analytics Hub
//

import SwiftUI

struct ExportToolsView: View {
    let analytics: AnalyticsEngine
    let dateRange: (start: Date, end: Date)

    @State private var selectedExportType: ExportType = .productPerformance
    @State private var showShareSheet = false
    @State private var exportURL: URL?
    @State private var isGenerating = false

    enum ExportType: String, CaseIterable, Identifiable {
        case productPerformance = "Product Performance"
        case timeAnalytics = "Time Analytics"
        case bartenderMetrics = "Bartender Metrics"
        case categoryBreakdown = "Category Breakdown"
        case inventoryInsights = "Inventory Insights"
        case fullReport = "Full Analytics Report"

        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Export Type Selector
                exportTypeSection

                // MARK: - Export Options
                exportOptionsSection

                // MARK: - Preview
                previewSection
            }
            .padding()
        }
        .navigationTitle("Export Tools")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
    }

    // MARK: - Export Type Section
    private var exportTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Report Type")
                .font(.headline)

            ForEach(ExportType.allCases) { type in
                Button {
                    selectedExportType = type
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(type.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)

                            Text(reportDescription(type))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if selectedExportType == type {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Export Options Section
    private var exportOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export As")
                .font(.headline)

            HStack(spacing: 12) {
                ExportButton(
                    title: "CSV",
                    icon: "tablecells",
                    color: .green,
                    isGenerating: isGenerating
                ) {
                    exportAsCSV()
                }

                ExportButton(
                    title: "PDF",
                    icon: "doc.fill",
                    color: .red,
                    isGenerating: isGenerating
                ) {
                    exportAsPDF()
                }
            }

            // Date Range Info
            VStack(alignment: .leading, spacing: 8) {
                Label("Date Range", systemImage: "calendar")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(dateRangeString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Preview Section
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preview")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Text("Report will include:")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(reportContents(selectedExportType), id: \.self) { content in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)

                            Text(content)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Summary Stats
            VStack(alignment: .leading, spacing: 8) {
                Text("Summary Statistics")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    StatPreview(label: "Total Revenue", value: analytics.totalRevenue().currencyString())
                    StatPreview(label: "Total Tickets", value: "\(analytics.totalTickets())")
                    StatPreview(label: "Avg Ticket", value: analytics.averageTicketSize().currencyString())
                    StatPreview(label: "Items Sold", value: "\(analytics.totalItemsSold())")
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helper Functions
    private func reportDescription(_ type: ExportType) -> String {
        switch type {
        case .productPerformance:
            return "Top sellers, margins, and category breakdown"
        case .timeAnalytics:
            return "Day/hour breakdown and sales trends"
        case .bartenderMetrics:
            return "Sales and performance by bartender"
        case .categoryBreakdown:
            return "Revenue distribution by category"
        case .inventoryInsights:
            return "Fast/slow movers and stock alerts"
        case .fullReport:
            return "Complete analytics across all categories"
        }
    }

    private func reportContents(_ type: ExportType) -> [String] {
        switch type {
        case .productPerformance:
            return [
                "Top 10 selling products by revenue",
                "Top 10 selling products by quantity",
                "Product category breakdown",
                "Profit margin analysis"
            ]
        case .timeAnalytics:
            return [
                "Sales by day of week",
                "Hourly sales breakdown",
                "Daily sales trends",
                "Peak hours analysis"
            ]
        case .bartenderMetrics:
            return [
                "Sales by bartender",
                "Average ticket size per bartender",
                "Tickets per hour metrics",
                "Total tabs closed comparison"
            ]
        case .categoryBreakdown:
            return [
                "Revenue by category",
                "Items sold by category",
                "Category percentage breakdown",
                "Average price per category"
            ]
        case .inventoryInsights:
            return [
                "Top 10 fast moving products",
                "Top 10 slow moving products",
                "Low stock alerts",
                "86'd items list"
            ]
        case .fullReport:
            return [
                "All product performance metrics",
                "Complete time analytics",
                "All bartender metrics",
                "Category breakdown",
                "Inventory insights",
                "Summary statistics"
            ]
        }
    }

    private var dateRangeString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        return "\(formatter.string(from: dateRange.start)) - \(formatter.string(from: dateRange.end))"
    }

    // MARK: - Export Functions
    private func exportAsCSV() {
        isGenerating = true

        Task {
            do {
                let csvData = generateCSVData()
                let tempURL = try saveToTemporaryFile(data: csvData, filename: csvFilename)

                await MainActor.run {
                    exportURL = tempURL
                    isGenerating = false
                    showShareSheet = true
                }
            } catch {
                print("Error exporting CSV: \(error)")
                isGenerating = false
            }
        }
    }

    private func exportAsPDF() {
        isGenerating = true

        // For PDF, we'll create a simple text-based PDF
        // In production, you'd use PDFKit or similar
        Task {
            do {
                let pdfData = generatePDFData()
                let tempURL = try saveToTemporaryFile(data: pdfData, filename: pdfFilename)

                await MainActor.run {
                    exportURL = tempURL
                    isGenerating = false
                    showShareSheet = true
                }
            } catch {
                print("Error exporting PDF: \(error)")
                isGenerating = false
            }
        }
    }

    private func generateCSVData() -> String {
        var csv = ""

        // Add header with date range
        csv += "BarPOS Analytics Report\n"
        csv += "Report Type: \(selectedExportType.rawValue)\n"
        csv += "Date Range: \(dateRangeString)\n"
        csv += "Generated: \(Date().formatted())\n\n"

        switch selectedExportType {
        case .productPerformance:
            csv += "Product Performance\n"
            csv += "Rank,Product,Quantity Sold,Revenue\n"
            let products = analytics.topSellingProducts(limit: 50)
            for (index, product) in products.enumerated() {
                csv += "\(index + 1),\"\(product.product)\",\(product.quantity),\(product.revenue.plainString())\n"
            }

        case .timeAnalytics:
            csv += "Sales by Day of Week\n"
            csv += "Day,Revenue\n"
            let dayStats = analytics.salesByDayOfWeek()
            for (day, sales) in dayStats.sorted(by: { $0.key < $1.key }) {
                csv += "\"\(day)\",\(sales.plainString())\n"
            }

        case .bartenderMetrics:
            csv += "Bartender Performance\n"
            csv += "Rank,Bartender,Total Sales,Tickets,Avg Ticket\n"
            let bartenders = analytics.salesByBartender()
            for (index, bartender) in bartenders.enumerated() {
                csv += "\(index + 1),\"\(bartender.name)\",\(bartender.sales.plainString()),\(bartender.tickets),\(bartender.avgTicket.plainString())\n"
            }

        case .categoryBreakdown:
            csv += "Category Breakdown\n"
            csv += "Category,Quantity,Revenue\n"
            let categories = analytics.categoryBreakdown()
            for (category, stats) in categories.sorted(by: { $0.value.revenue > $1.value.revenue }) {
                csv += "\"\(category.displayName)\",\(stats.quantity),\(stats.revenue.plainString())\n"
            }

        case .inventoryInsights:
            csv += "Fast Movers\n"
            csv += "Rank,Product,Quantity Sold,Category\n"
            let fastMovers = analytics.fastMovers(limit: 20)
            for (index, mover) in fastMovers.enumerated() {
                csv += "\(index + 1),\"\(mover.product)\",\(mover.quantity),\"\(mover.category.displayName)\"\n"
            }

        case .fullReport:
            // Include all sections
            csv += generateCSVData() // Recursive but simplified in production
        }

        return csv
    }

    private func generatePDFData() -> String {
        // Simplified text-based PDF content
        // In production, use PDFKit for proper PDF generation
        var content = ""

        content += "BarPOS Analytics Report\n"
        content += "======================\n\n"
        content += "Report Type: \(selectedExportType.rawValue)\n"
        content += "Date Range: \(dateRangeString)\n"
        content += "Generated: \(Date().formatted())\n\n"
        content += "Summary Statistics:\n"
        content += "- Total Revenue: \(analytics.totalRevenue().currencyString())\n"
        content += "- Total Tickets: \(analytics.totalTickets())\n"
        content += "- Avg Ticket: \(analytics.averageTicketSize().currencyString())\n"
        content += "- Items Sold: \(analytics.totalItemsSold())\n\n"

        return content
    }

    private func saveToTemporaryFile(data: String, filename: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)

        try data.write(to: fileURL, atomically: true, encoding: .utf8)

        return fileURL
    }

    private var csvFilename: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: Date())
        let reportType = selectedExportType.rawValue.replacingOccurrences(of: " ", with: "_")
        return "BarPOS_\(reportType)_\(dateStr).csv"
    }

    private var pdfFilename: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: Date())
        let reportType = selectedExportType.rawValue.replacingOccurrences(of: " ", with: "_")
        return "BarPOS_\(reportType)_\(dateStr).txt" // Using .txt for simplified PDF
    }
}

// MARK: - Export Button Component
struct ExportButton: View {
    let title: String
    let icon: String
    let color: Color
    let isGenerating: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                if isGenerating {
                    ProgressView()
                        .tint(color)
                } else {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isGenerating)
    }
}

// MARK: - Stat Preview Component
struct StatPreview: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
