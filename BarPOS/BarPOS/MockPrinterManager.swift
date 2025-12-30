import Foundation
import Combine
import SwiftUI
import PDFKit

@MainActor
class MockPrinterManager: ObservableObject, PrinterService {
    @Published var isConnected: Bool = true  // Mock always "connected"
    @Published var printerName: String = "Mock Printer (PDF)"
    @Published var status: PrinterStatus = .connected

    private var settings: ReceiptSettings

    nonisolated init(settings: ReceiptSettings = ReceiptSettings()) {
        self.settings = settings
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
        status = .printing

        // Generate PDF instead of printing
        guard let pdfURL = generatePDF(from: receipt) else {
            status = .error("Failed to generate PDF")
            return .failure("PDF generation failed")
        }

        print("📄 Mock print: Receipt generated at \(pdfURL.path)")

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
        let text = content.body.joined(separator: "\n")

        let pdfMetadata = [
            kCGPDFContextTitle: "Receipt",
            kCGPDFContextCreator: "BarPOS"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetadata as [String: Any]

        // Receipt paper size (80mm width)
        let pageWidth: CGFloat = 226.77 // 80mm in points
        let pageHeight: CGFloat = 800 // Dynamic based on content
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont(name: "Courier", size: 10) ?? UIFont.systemFont(ofSize: 10),
                .foregroundColor: UIColor.black
            ]

            let attributedText = NSAttributedString(string: text, attributes: attributes)
            attributedText.draw(in: pageRect.insetBy(dx: 10, dy: 10))
        }

        // Save to temp directory
        let fileName = "receipt-\(Date().timeIntervalSince1970).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try data.write(to: url)
            return url
        } catch {
            print("❌ Failed to save PDF: \(error)")
            return nil
        }
    }
}
