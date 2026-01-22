import Foundation
import Combine
import SwiftUI
import PDFKit

@MainActor
class MockPrinterManager: ObservableObject, PrinterService {
    @Published var isConnected: Bool = true  // Mock always "connected"
    @Published var printerName: String = "Virtual Printer (PDF)"
    @Published var status: PrinterStatus = .connected
    @Published var lastSavedReceiptURL: URL?
    
    private var settings: ReceiptSettings
    private let receiptsDirectory: URL
    
    init() {
        self.settings = ReceiptSettings()
        
        // Create receipts folder in Documents (accessible via Files app)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        receiptsDirectory = documentsPath.appendingPathComponent("Receipts", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: receiptsDirectory, withIntermediateDirectories: true)
        
        print("📂 Receipts will be saved to: \(receiptsDirectory.path)")
    }

    init(settings: ReceiptSettings) {
        self.settings = settings
        
        // Create receipts folder in Documents (accessible via Files app)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        receiptsDirectory = documentsPath.appendingPathComponent("Receipts", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: receiptsDirectory, withIntermediateDirectories: true)
        
        print("📂 Receipts will be saved to: \(receiptsDirectory.path)")
    }

    func connect() async -> Bool {
        status = .connecting
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
        status = .connected
        isConnected = true
        return true
    }

    func disconnect() {
        isConnected = false
        status = .disconnected
    }

    func printReceipt(_ receipt: ReceiptData) async -> PrintResult {
        print("🖨️ Virtual printer: Saving receipt as PDF...")
        status = .printing

        // Generate PDF and save to Documents/Receipts
        guard let pdfURL = generatePDF(from: receipt) else {
            status = .error("Failed to generate PDF")
            return .failure("PDF generation failed")
        }

        print("✅ Receipt saved: \(pdfURL.lastPathComponent)")
        print("📍 Location: \(pdfURL.path)")
        
        lastSavedReceiptURL = pdfURL

        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s delay
        status = .connected

        return .success(pdfURL: pdfURL)
    }

    func openCashDrawer() async -> Bool {
        print("💰 Mock: Cash drawer opened (ESC/POS command: 0x1B 0x70 0x00)")
        try? await Task.sleep(nanoseconds: 500_000_000)
        return true
    }

    func testPrint() async -> Bool {
        let testReceipt = ReceiptData(
            type: .test,
            content: ReceiptFormatter.formatTestReceipt(settings: settings),
            settings: settings
        )

        let result = await printReceipt(testReceipt)
        return result.wasSuccessful
    }

    // MARK: - PDF Generation

    private func generatePDF(from receipt: ReceiptData) -> URL? {
        let content = receipt.content
        let fullText = ([content.header] + content.body + [content.footer]).joined(separator: "\n")
        
        // Generate filename: "Receipt_20240122T143522_Tab1.pdf"
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime]
        let timestamp = dateFormatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .prefix(15)  // YYYYMMDDTHHMMSS
        
        // Extract tab name from receipt type
        var tabName = "Receipt"
        if case .customer(let result) = receipt.type {
            tabName = result.tabName
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "/", with: "_")
        }
        
        let filename = "Receipt_\(timestamp)_\(tabName).pdf"
        let fileURL = receiptsDirectory.appendingPathComponent(filename)

        let pdfMetadata = [
            kCGPDFContextTitle: "Receipt - \(tabName)",
            kCGPDFContextCreator: "BarPOS"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetadata as [String: Any]

        // Receipt paper size (80mm width)
        let pageWidth: CGFloat = 227 // 80mm in points
        let pageHeight: CGFloat = 800 // Dynamic based on content
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.black
            ]

            let textRect = CGRect(x: 10, y: 10, width: pageWidth - 20, height: pageHeight - 20)
            fullText.draw(in: textRect, withAttributes: attributes)
        }

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("❌ Failed to save PDF: \(error)")
            return nil
        }
    }
    
    // MARK: - Get Recent Receipts
    
    func getRecentReceipts(limit: Int = 20) -> [URL] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: receiptsDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            // Sort by creation date, newest first
            let sorted = contents.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }
            
            return Array(sorted.prefix(limit))
        } catch {
            print("❌ Error reading receipts: \(error)")
            return []
        }
    }
}
