import Foundation
import UIKit
import Combine

#if canImport(ePOS2)
import ePOS2

@MainActor
class EpsonPrinterManager: ObservableObject {
    static let shared = EpsonPrinterManager()
    @Published var isConnected: Bool = false
    @Published var printerName: String = "Epson TM-M30II"
    @Published var printerIP: String = ""

    private nonisolated(unsafe) var printer: Epos2Printer?
    private var target: String = ""
    private var isDiscovering = false
    private let knownIP = "192.168.1.76"

    init() {
        printer = Epos2Printer(printerSeries: EPOS2_TM_M30II.rawValue,
                               lang: EPOS2_MODEL_ANK.rawValue)
    }

    deinit {
        printer?.disconnect()
        printer?.clearCommandBuffer()
        printer = nil
    }

    func discoverPrinters(timeout: Int = 10) async -> [(name: String, target: String)] {
        guard !isDiscovering else { return [] }
        isDiscovering = true
        defer { isDiscovering = false }

        return await withCheckedContinuation { continuation in
            let delegate = DiscoveryDelegate { results in
                continuation.resume(returning: results)
            }
            objc_setAssociatedObject(self, "discoveryDelegate", delegate,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            let filter = Epos2FilterOption()
            filter.deviceType = EPOS2_TYPE_PRINTER.rawValue
            filter.portType = EPOS2_PORTTYPE_TCP.rawValue

            let result = Epos2Discovery.start(filter, delegate: delegate)
            if result != EPOS2_SUCCESS.rawValue {
                print("Discovery start failed: \(result)")
                continuation.resume(returning: [])
                return
            }

            Task {
                try? await Task.sleep(for: .seconds(timeout))
                Epos2Discovery.stop()
            }
        }
    }

    func discoverAndConnect() async {
        print("Connecting to known printer IP...")
        await connectPrinter(target: "TCP:\(knownIP)")
        if isConnected { return }

        print("Starting Epson network printer discovery...")
        let found = await discoverPrinters(timeout: 8)
        if let first = found.first {
            let target = first.target.contains(".") ? first.target : "TCP:\(knownIP)"
            print("Found: \(first.name) at \(target)")
            await connectPrinter(target: target)
        } else {
            print("No Epson printers found on network")
        }
    }

    func connectPrinter(target: String) async {
        guard let printer else { return }
        self.target = target
        let result = printer.connect(target, timeout: Int(EPOS2_PARAM_DEFAULT))
        if result == EPOS2_SUCCESS.rawValue {
            isConnected = true
            printerIP = target.replacingOccurrences(of: "TCP:", with: "")
            printerName = "Epson TM-M30II (\(printerIP))"
            print("Connected to Epson printer at \(target)")
        } else {
            isConnected = false
            print("Epson connect failed - code: \(result)")
        }
    }

    func connectManual(ip: String) async {
        await connectPrinter(target: "TCP:\(ip)")
    }

    func disconnectPrinter() {
        printer?.disconnect()
        isConnected = false
        print("Epson printer disconnected")
    }

    func ensureConnected() async {
        guard !isConnected else { return }
        await connectPrinter(target: "TCP:\(knownIP)")
    }

    private func addLogoToBuffer() {
        guard let printer else { return }
        guard let image = UIImage(named: "receipt_logo") else {
            print("Receipt logo not found")
            return
        }

        let targetWidth: CGFloat = 300
        let scale = targetWidth / image.size.width
        let targetSize = CGSize(width: targetWidth, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let scaledImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        printer.addTextAlign(EPOS2_ALIGN_CENTER.rawValue)
        printer.addImage(scaledImage, x: 0, y: 0,
                         width: Int(targetWidth),
                         height: Int(targetSize.height),
                         color: EPOS2_COLOR_1.rawValue,
                         mode: EPOS2_MONO.rawValue,
                         halftone: EPOS2_HALFTONE_THRESHOLD.rawValue,
                         brightness: 1.0,
                         compress: EPOS2_COMPRESS_AUTO.rawValue)
        printer.addFeedLine(1)
    }

    private func padLine(_ label: String, _ value: String) -> String {
        let width = 32
        let spaces = max(1, width - label.count - value.count)
        return "\(label)\(String(repeating: " ", count: spaces))\(value)\n"
    }

    func printReceipt(_ content: EpsonReceiptContent) async throws {
        guard let printer else { throw PrinterError.notConnected }
        await ensureConnected()
        guard isConnected else { throw PrinterError.notConnected }

        printer.clearCommandBuffer()
        printer.addTextLang(EPOS2_LANG_EN.rawValue)

        addLogoToBuffer()

        printer.addTextAlign(EPOS2_ALIGN_CENTER.rawValue)
        printer.addTextSize(2, height: 2)
        printer.addText("PARMA CAFE\n")
        printer.addTextSize(1, height: 1)
        printer.addText("5780 Ridge Rd., Parma, OH 44129\n")
        printer.addFeedLine(1)

        printer.addTextAlign(EPOS2_ALIGN_LEFT.rawValue)
        printer.addText("================================\n")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy  h:mm a"
        printer.addText("Date:   \(dateFormatter.string(from: Date()))\n")
        printer.addText("Server: \(content.bartenderName ?? "Staff")\n")
        printer.addText("Tab:    \(content.tabName)\n")
        printer.addText("================================\n")
        printer.addFeedLine(1)

        printer.addTextAlign(EPOS2_ALIGN_LEFT.rawValue)
        for line in content.lines {
            let qty = "\(line.quantity)x"
            let price = line.price
            let maxNameWidth = 32 - qty.count - price.count - 2
            let name = String(line.itemName.prefix(maxNameWidth))
            let spaces = max(1, 32 - qty.count - name.count - price.count)
            printer.addText("\(qty) \(name)\(String(repeating: " ", count: spaces))\(price)\n")
        }
        printer.addFeedLine(1)

        printer.addText("--------------------------------\n")
        printer.addText(padLine("Subtotal:", content.subtotal))
        printer.addText(padLine("Tax:", content.tax))
        printer.addText("================================\n")
        printer.addTextStyle(EPOS2_FALSE, ul: EPOS2_FALSE, em: EPOS2_TRUE, color: EPOS2_PARAM_DEFAULT)
        printer.addText(padLine("TOTAL:", content.total))
        printer.addTextStyle(EPOS2_FALSE, ul: EPOS2_FALSE, em: EPOS2_FALSE, color: EPOS2_PARAM_DEFAULT)
        printer.addFeedLine(1)

        printer.addText(padLine("Payment:", content.paymentMethod))
        if content.cashTendered != "$0.00" && !content.cashTendered.isEmpty {
            printer.addText(padLine("Cash Tendered:", content.cashTendered))
            printer.addText(padLine("Change Due:", content.changeDue))
        }
        printer.addFeedLine(1)

        printer.addTextAlign(EPOS2_ALIGN_CENTER.rawValue)
        printer.addText("--------------------------------\n")
        printer.addText("We thank you for your patronage\n")
        printer.addText("and look forward to serving\n")
        printer.addText("you again soon!\n")
        printer.addText("================================\n")
        printer.addFeedLine(4)
        printer.addCut(EPOS2_CUT_FEED.rawValue)

        let sendResult = printer.sendData(Int(EPOS2_PARAM_DEFAULT))
        printer.clearCommandBuffer()

        if sendResult != EPOS2_SUCCESS.rawValue {
            print("Print sendData failed: \(sendResult)")
            throw PrinterError.printFailed(NSError(domain: "EpsonPrint", code: Int(sendResult)))
        }

        print("Receipt printed on Epson")
    }

    func openDrawer() async throws {
        guard let printer else { throw PrinterError.notConnected }
        await ensureConnected()
        guard isConnected else { throw PrinterError.notConnected }

        printer.clearCommandBuffer()
        printer.addPulse(EPOS2_DRAWER_2PIN.rawValue, time: EPOS2_PULSE_100.rawValue)

        let sendResult = printer.sendData(Int(EPOS2_PARAM_DEFAULT))
        printer.clearCommandBuffer()

        if sendResult != EPOS2_SUCCESS.rawValue {
            print("Drawer kick failed: \(sendResult)")
            throw PrinterError.drawerFailed(NSError(domain: "EpsonDrawer", code: Int(sendResult)))
        }

        print("Cash drawer opened")
    }

    func printReceiptAndOpenDrawer(_ content: EpsonReceiptContent) async throws {
        guard let printer else { throw PrinterError.notConnected }
        await ensureConnected()
        guard isConnected else { throw PrinterError.notConnected }

        printer.clearCommandBuffer()
        printer.addTextLang(EPOS2_LANG_EN.rawValue)

        addLogoToBuffer()

        printer.addTextAlign(EPOS2_ALIGN_CENTER.rawValue)
        printer.addTextSize(2, height: 2)
        printer.addText("PARMA CAFE\n")
        printer.addTextSize(1, height: 1)
        printer.addText("5780 Ridge Rd., Parma, OH 44129\n")
        printer.addFeedLine(1)

        printer.addTextAlign(EPOS2_ALIGN_LEFT.rawValue)
        printer.addText("================================\n")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy  h:mm a"
        printer.addText("Date:   \(dateFormatter.string(from: Date()))\n")
        printer.addText("Server: \(content.bartenderName ?? "Staff")\n")
        printer.addText("Tab:    \(content.tabName)\n")
        printer.addText("================================\n")
        printer.addFeedLine(1)

        printer.addTextAlign(EPOS2_ALIGN_LEFT.rawValue)
        for line in content.lines {
            let qty = "\(line.quantity)x"
            let price = line.price
            let maxNameWidth = 32 - qty.count - price.count - 2
            let name = String(line.itemName.prefix(maxNameWidth))
            let spaces = max(1, 32 - qty.count - name.count - price.count)
            printer.addText("\(qty) \(name)\(String(repeating: " ", count: spaces))\(price)\n")
        }
        printer.addFeedLine(1)

        printer.addText("--------------------------------\n")
        printer.addText(padLine("Subtotal:", content.subtotal))
        printer.addText(padLine("Tax:", content.tax))
        printer.addText("================================\n")
        printer.addTextStyle(EPOS2_FALSE, ul: EPOS2_FALSE, em: EPOS2_TRUE, color: EPOS2_PARAM_DEFAULT)
        printer.addText(padLine("TOTAL:", content.total))
        printer.addTextStyle(EPOS2_FALSE, ul: EPOS2_FALSE, em: EPOS2_FALSE, color: EPOS2_PARAM_DEFAULT)
        printer.addFeedLine(1)

        printer.addText(padLine("Payment:", content.paymentMethod))
        if content.cashTendered != "$0.00" && !content.cashTendered.isEmpty {
            printer.addText(padLine("Cash Tendered:", content.cashTendered))
            printer.addText(padLine("Change Due:", content.changeDue))
        }
        printer.addFeedLine(1)

        printer.addTextAlign(EPOS2_ALIGN_CENTER.rawValue)
        printer.addText("--------------------------------\n")
        printer.addText("We thank you for your patronage\n")
        printer.addText("and look forward to serving\n")
        printer.addText("you again soon!\n")
        printer.addText("================================\n")
        printer.addFeedLine(4)
        printer.addCut(EPOS2_CUT_FEED.rawValue)
        printer.addPulse(EPOS2_DRAWER_2PIN.rawValue, time: EPOS2_PULSE_100.rawValue)

        let sendResult = printer.sendData(Int(EPOS2_PARAM_DEFAULT))
        printer.clearCommandBuffer()

        if sendResult != EPOS2_SUCCESS.rawValue {
            throw PrinterError.printFailed(NSError(domain: "EpsonPrint", code: Int(sendResult)))
        }

        print("Receipt printed + drawer opened")
    }

    func printShiftReport(_ content: ReceiptContent) async throws {
        guard let printer else { throw PrinterError.notConnected }
        await ensureConnected()
        guard isConnected else { throw PrinterError.notConnected }

        printer.clearCommandBuffer()
        printer.addTextLang(EPOS2_LANG_EN.rawValue)
        printer.addTextAlign(EPOS2_ALIGN_LEFT.rawValue)

        for line in content.body {
            printer.addText(line + "\n")
        }

        printer.addCut(EPOS2_CUT_FEED.rawValue)

        let sendResult = printer.sendData(Int(EPOS2_PARAM_DEFAULT))
        printer.clearCommandBuffer()

        if sendResult != EPOS2_SUCCESS.rawValue {
            print("Print sendData failed: \(sendResult)")
            throw PrinterError.printFailed(NSError(domain: "EpsonPrint", code: Int(sendResult)))
        }

        print("Shift report printed on Epson")
    }

    func testPrint() async -> Bool {
        let testContent = EpsonReceiptContent(
            header: "TEST RECEIPT",
            lines: [ReceiptLine(quantity: 1, itemName: "Test Item", price: "$5.00")],
            subtotal: "$5.00",
            tax: "$0.00",
            total: "$5.00",
            footer: "Printer is working!",
            bartenderName: "Staff",
            tabName: "Test Tab",
            paymentMethod: "Cash",
            cashTendered: "$10.00",
            changeDue: "$5.00"
        )

        do {
            try await printReceipt(testContent)
            return true
        } catch {
            print("Test print failed: \(error)")
            return false
        }
    }

    func openCashDrawer() async -> Bool {
        do {
            try await openDrawer()
            return true
        } catch {
            print("Cash drawer failed: \(error)")
            return false
        }
    }

    func discoverPrinter() async {
        await discoverAndConnect()
    }
}

private class DiscoveryDelegate: NSObject, Epos2DiscoveryDelegate {
    private var results: [(name: String, target: String)] = []
    private let onComplete: ([(name: String, target: String)]) -> Void
    private var completed = false

    init(onComplete: @escaping ([(name: String, target: String)]) -> Void) {
        self.onComplete = onComplete
    }

    func onDiscovery(_ deviceInfo: Epos2DeviceInfo!) {
        guard let info = deviceInfo else { return }
        let name = info.deviceName ?? "Epson Printer"
        let target = info.target ?? ""
        print("Discovered: \(name) -> \(target)")
        results.append((name: name, target: target))
    }

    override func finalize() {
        guard !completed else { return }
        completed = true
        onComplete(results)
    }
}

#else

@MainActor
class EpsonPrinterManager: ObservableObject {
    static let shared = EpsonPrinterManager()
    @Published var isConnected: Bool = false
    @Published var printerName: String = "Epson SDK Missing"
    @Published var printerIP: String = ""

    private let unavailableError = PrinterError.sdkUnavailable

    func discoverPrinters(timeout: Int = 10) async -> [(name: String, target: String)] {
        _ = timeout
        return []
    }

    func discoverAndConnect() async {
        isConnected = false
    }

    func connectPrinter(target: String) async {
        _ = target
        isConnected = false
    }

    func connectManual(ip: String) async {
        _ = ip
        isConnected = false
    }

    func disconnectPrinter() {
        isConnected = false
    }

    func ensureConnected() async {}

    func printReceipt(_ content: EpsonReceiptContent) async throws {
        _ = content
        throw unavailableError
    }

    func openDrawer() async throws {
        throw unavailableError
    }

    func printReceiptAndOpenDrawer(_ content: EpsonReceiptContent) async throws {
        _ = content
        throw unavailableError
    }

    func printShiftReport(_ content: ReceiptContent) async throws {
        _ = content
        throw unavailableError
    }

    func testPrint() async -> Bool {
        false
    }

    func openCashDrawer() async -> Bool {
        false
    }

    func discoverPrinter() async {}
}

#endif

enum PrinterError: Error {
    case notConnected
    case printFailed(Error)
    case drawerFailed(Error)
    case sdkUnavailable
}

struct EpsonReceiptContent {
    let header: String
    let lines: [ReceiptLine]
    let subtotal: String
    let tax: String
    let total: String
    let footer: String
    let bartenderName: String?
    let tabName: String
    let paymentMethod: String
    let cashTendered: String
    let changeDue: String
}

struct ReceiptLine {
    let quantity: Int
    let itemName: String
    let price: String
}
