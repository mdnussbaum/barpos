import Foundation
import Combine

@MainActor
class EpsonPrinterManager: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var printerName: String = "Epson TM-M30II"
    @Published var printerIP: String = ""

    private nonisolated(unsafe) var printer: Epos2Printer?
    private var target: String = ""
    private var isDiscovering = false

    init() {
        printer = Epos2Printer(printerSeries: EPOS2_TM_M30II.rawValue,
                               lang: EPOS2_MODEL_ANK.rawValue)
    }

    deinit {
        printer?.disconnect()
        printer?.clearCommandBuffer()
        printer = nil
    }

    // MARK: - Discovery (WiFi / LAN)

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
            filter.portType   = EPOS2_PORTTYPE_TCP.rawValue

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
        print("Starting Epson network printer discovery...")
        let found = await discoverPrinters(timeout: 8)
        if let first = found.first {
            let target = first.target.contains(":") && !first.target.contains(".")
                ? "TCP:192.168.1.76"
                : first.target
            print("Found: \(first.name) at \(first.target)")
            print("Connecting to: \(target)")
            await connectPrinter(target: target)
        } else {
            print("No Epson printers found on network")
            await connectPrinter(target: "TCP:192.168.1.76")
        }
    }

    // MARK: - Connect / Disconnect

    func connectPrinter(target: String) async {
        guard let printer = printer else { return }
        self.target = target
        let result = printer.connect(target, timeout: Int(EPOS2_PARAM_DEFAULT))
        if result == EPOS2_SUCCESS.rawValue {
            isConnected = true
            printerIP = target.replacingOccurrences(of: "TCP:", with: "")
            printerName = "Epson TM-M30II (\(printerIP))"
            print("Connected to Epson printer at \(target)")
        } else {
            isConnected = false
            print("Epson connect failed — code: \(result)")
        }
    }

    func connectManual(ip: String) async {
        let target = "TCP:\(ip)"
        await connectPrinter(target: target)
    }

    func disconnectPrinter() {
        printer?.disconnect()
        isConnected = false
        print("Epson printer disconnected")
    }

    // MARK: - Print Receipt

    func printReceipt(_ content: EpsonReceiptContent) async throws {
        guard let printer = printer else { throw PrinterError.notConnected }
        if !isConnected {
            print("Not connected — attempting discovery...")
            await discoverAndConnect()
            guard isConnected else { throw PrinterError.notConnected }
        }

        printer.clearCommandBuffer()
        printer.addTextLang(EPOS2_LANG_EN.rawValue)
        printer.addTextAlign(EPOS2_ALIGN_CENTER.rawValue)
        printer.addText(content.header + "\n")
        printer.addText("─────────────────────────\n")
        printer.addTextAlign(EPOS2_ALIGN_LEFT.rawValue)

        for line in content.lines {
            printer.addText("\(line.quantity)x \(line.itemName)  \(line.price)\n")
        }

        printer.addText("─────────────────────────\n")
        printer.addText("Subtotal: \(content.subtotal)\n")
        printer.addText("Tax:      \(content.tax)\n")
        printer.addTextStyle(EPOS2_FALSE, ul: EPOS2_FALSE,
                             em: EPOS2_TRUE, color: EPOS2_PARAM_DEFAULT)
        printer.addText("TOTAL:    \(content.total)\n")
        printer.addTextStyle(EPOS2_FALSE, ul: EPOS2_FALSE,
                             em: EPOS2_FALSE, color: EPOS2_PARAM_DEFAULT)
        printer.addTextAlign(EPOS2_ALIGN_CENTER.rawValue)
        printer.addText("\n\(content.footer)\n")
        printer.addCut(EPOS2_CUT_FEED.rawValue)

        let sendResult = printer.sendData(Int(EPOS2_PARAM_DEFAULT))
        printer.clearCommandBuffer()

        if sendResult != EPOS2_SUCCESS.rawValue {
            print("Print sendData failed: \(sendResult)")
            throw PrinterError.printFailed(NSError(domain: "EpsonPrint", code: Int(sendResult)))
        }
        print("Receipt printed on Epson")
    }

    // MARK: - Open Cash Drawer

    func openDrawer() async throws {
        guard let printer = printer else { throw PrinterError.notConnected }
        if !isConnected {
            await discoverAndConnect()
            guard isConnected else { throw PrinterError.notConnected }
        }

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

    // MARK: - Print + Open Drawer combined

    func printReceiptAndOpenDrawer(_ content: EpsonReceiptContent) async throws {
        guard let printer = printer else { throw PrinterError.notConnected }
        if !isConnected {
            await discoverAndConnect()
            guard isConnected else { throw PrinterError.notConnected }
        }

        printer.clearCommandBuffer()
        printer.addTextLang(EPOS2_LANG_EN.rawValue)
        printer.addTextAlign(EPOS2_ALIGN_CENTER.rawValue)
        printer.addText(content.header + "\n")
        printer.addText("─────────────────────────\n")
        printer.addTextAlign(EPOS2_ALIGN_LEFT.rawValue)

        for line in content.lines {
            printer.addText("\(line.quantity)x \(line.itemName)  \(line.price)\n")
        }

        printer.addText("─────────────────────────\n")
        printer.addText("Subtotal: \(content.subtotal)\n")
        printer.addText("Tax:      \(content.tax)\n")
        printer.addTextStyle(EPOS2_FALSE, ul: EPOS2_FALSE,
                             em: EPOS2_TRUE, color: EPOS2_PARAM_DEFAULT)
        printer.addText("TOTAL:    \(content.total)\n")
        printer.addTextStyle(EPOS2_FALSE, ul: EPOS2_FALSE,
                             em: EPOS2_FALSE, color: EPOS2_PARAM_DEFAULT)
        printer.addTextAlign(EPOS2_ALIGN_CENTER.rawValue)
        printer.addText("\n\(content.footer)\n")
        printer.addCut(EPOS2_CUT_FEED.rawValue)
        printer.addPulse(EPOS2_DRAWER_2PIN.rawValue, time: EPOS2_PULSE_100.rawValue)

        let sendResult = printer.sendData(Int(EPOS2_PARAM_DEFAULT))
        printer.clearCommandBuffer()

        if sendResult != EPOS2_SUCCESS.rawValue {
            throw PrinterError.printFailed(NSError(domain: "EpsonPrint", code: Int(sendResult)))
        }
        print("Receipt printed + drawer opened")
    }

    // MARK: - Convenience helpers

    func testPrint() async -> Bool {
        let testContent = EpsonReceiptContent(
            header: "TEST RECEIPT",
            lines: [ReceiptLine(quantity: 1, itemName: "Test Item", price: "$0.00")],
            subtotal: "$0.00", tax: "$0.00", total: "$0.00",
            footer: "Printer is working!"
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

    /// Alias so callers using the old Star discovery API still compile
    func discoverPrinter() async {
        await discoverAndConnect()
    }
}

// MARK: - Discovery Delegate

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

// MARK: - Errors

enum PrinterError: Error {
    case notConnected
    case printFailed(Error)
    case drawerFailed(Error)
}

// MARK: - Receipt Content Model

struct EpsonReceiptContent {
    let header: String
    let lines: [ReceiptLine]
    let subtotal: String
    let tax: String
    let total: String
    let footer: String
}

struct ReceiptLine {
    let quantity: Int
    let itemName: String
    let price: String
}
