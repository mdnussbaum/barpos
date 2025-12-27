import Foundation

// MARK: - Printer Service Protocol

protocol PrinterService: ObservableObject {
    var isConnected: Bool { get }
    var printerName: String { get }
    var status: PrinterStatus { get }

    func connect() async -> Bool
    func disconnect()
    func printReceipt(_ receipt: ReceiptData) async -> PrintResult
    func openCashDrawer() async -> Bool
    func testPrint() async -> Bool
}

enum PrinterStatus {
    case disconnected
    case connecting
    case connected
    case printing
    case error(String)
}

enum PrintResult {
    case success(pdfURL: URL?)  // URL if mock, nil if real print
    case failure(String)

    var wasSuccessful: Bool {
        if case .success = self { return true }
        return false
    }
}

// MARK: - Receipt Data

struct ReceiptData {
    let type: ReceiptType
    let content: ReceiptContent
    let settings: ReceiptSettings
}

enum ReceiptType {
    case customer(CloseResult)
    case shiftReport(ShiftReport)
    case test
}

struct ReceiptContent {
    var header: String
    var body: [String]
    var footer: String
}

// MARK: - Receipt Settings

struct ReceiptSettings: Codable {
    var headerText: String = "My Bar"
    var footerText: String = "Thank you!"
    var autoPrintReceipts: Bool = true
    var autoOpenDrawer: Bool = true
    var paperWidth: PaperWidth = .mm80

    enum PaperWidth: String, Codable {
        case mm58 = "58mm"
        case mm80 = "80mm"
    }
}
