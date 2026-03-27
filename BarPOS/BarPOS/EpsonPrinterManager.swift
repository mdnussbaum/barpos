import Foundation
import Combine
import libepos2

// MARK: - Epson Printer Manager

@MainActor
class EpsonPrinterManager: ObservableObject, PrinterService {
    @Published var isConnected: Bool = false
    @Published var printerName: String = "Epson TM-M30II"
    @Published var status: PrinterStatus = .disconnected

    /// The discovered or manually configured printer IP address.
    @Published var printerIP: String = ""

    private var printer: Epos2Printer?
    private var discoveryDelegate: DiscoveryDelegate?

    private let ipKey = "EpsonPrinterIP"

    nonisolated init() {
        // Restore saved IP from UserDefaults on the main actor
        let saved = UserDefaults.standard.string(forKey: "EpsonPrinterIP")
        Task { @MainActor in
            if let saved, !saved.isEmpty {
                self.printerIP = saved
                _ = await self.connect()
            } else {
                await self.discoverPrinter()
            }
        }
    }

    // MARK: - Discovery

    /// Discovers an Epson TM-M30II on the local network using Epos2Discovery.
    func discoverPrinter() async {
        status = .connecting
        print("🔍 Starting Epson printer discovery...")

        // Stop any existing discovery
        Epos2Discovery.stop()

        let filter = Epos2FilterOption()
        filter.deviceType = EPOS2_TYPE_PRINTER.rawValue
        filter.portType = EPOS2_PORTTYPE_TCP.rawValue

        let delegate = DiscoveryDelegate { [weak self] deviceInfo in
            guard let self else { return }
            Task { @MainActor in
                self.printerIP = deviceInfo.ipAddress
                self.printerName = deviceInfo.deviceName.isEmpty ? "Epson TM-M30II" : deviceInfo.deviceName
                self.savePrinterIP()
                Epos2Discovery.stop()
                print("🔍 Discovered printer at \(self.printerIP)")
                _ = await self.connect()
            }
        }
        self.discoveryDelegate = delegate

        let result = Epos2Discovery.start(filter, delegate: delegate)
        if result != EPOS2_SUCCESS.rawValue {
            print("❌ Discovery failed with code: \(result)")
            status = .error("Discovery failed (\(result))")
            return
        }

        // Wait up to 15 seconds for discovery, then stop
        try? await Task.sleep(for: .seconds(15))
        Epos2Discovery.stop()

        if !isConnected {
            print("⚠️ Discovery timed out — no printer found")
            status = .disconnected
        }
    }

    // MARK: - Connect / Disconnect

    func connect() async -> Bool {
        guard !printerIP.isEmpty else {
            status = .error("No printer IP configured")
            return false
        }

        status = .connecting
        print("🔌 Connecting to Epson printer at \(printerIP)...")

        let eposPrinter = Epos2Printer(printerSeries: EPOS2_TM_M30II.rawValue, lang: EPOS2_MODEL_ANK.rawValue)

        guard let eposPrinter else {
            status = .error("Failed to create printer instance")
            return false
        }

        let connectResult = eposPrinter.connect("TCP:\(printerIP)", timeout: 10000)

        guard connectResult == EPOS2_SUCCESS.rawValue else {
            print("❌ Connection failed with code: \(connectResult)")
            status = .error("Connection failed (\(connectResult))")
            return false
        }

        self.printer = eposPrinter
        isConnected = true
        status = .connected
        savePrinterIP()
        print("✅ Connected to Epson TM-M30II at \(printerIP)")
        return true
    }

    func disconnect() {
        printer?.disconnect()
        printer = nil
        isConnected = false
        status = .disconnected
        print("🔌 Disconnected from Epson printer")
    }

    // MARK: - Print Receipt

    func printReceipt(_ receipt: ReceiptData) async -> PrintResult {
        if !isConnected {
            if !(await connect()) {
                return .failure("Printer not connected")
            }
        }

        guard let printer else {
            status = .error("No printer instance")
            return .failure("No printer instance")
        }

        status = .printing

        printer.clearCommandBuffer()
        printer.addTextAlign(EPOS2_ALIGN_CENTER.rawValue)

        // Header — enlarged
        printer.addTextSize(2, height: 2)
        printer.addText("\(receipt.content.header)\n")
        printer.addTextSize(1, height: 1)
        printer.addText(String(repeating: "─", count: 32) + "\n")

        // Body lines
        printer.addTextAlign(EPOS2_ALIGN_LEFT.rawValue)
        for line in receipt.content.body {
            printer.addText(line + "\n")
        }

        // Footer
        if !receipt.content.footer.isEmpty {
            printer.addTextAlign(EPOS2_ALIGN_CENTER.rawValue)
            printer.addText("\n\(receipt.content.footer)\n")
        }

        // Feed and cut
        printer.addFeedLine(3)
        printer.addCut(EPOS2_CUT_FEED.rawValue)

        let sendResult = printer.sendData(Int(EPOS2_PARAM_DEFAULT))

        printer.clearCommandBuffer()

        guard sendResult == EPOS2_SUCCESS.rawValue else {
            status = .error("Print failed (\(sendResult))")
            return .failure("Print failed with code: \(sendResult)")
        }

        status = .connected
        print("✅ Receipt printed on Epson TM-M30II")
        return .success(pdfURL: nil)
    }

    // MARK: - Open Cash Drawer

    func openCashDrawer() async -> Bool {
        if !isConnected {
            if !(await connect()) { return false }
        }

        guard let printer else { return false }

        printer.clearCommandBuffer()
        printer.addPulse(EPOS2_DRAWER_2PIN.rawValue, time: EPOS2_PULSE_200.rawValue)

        let result = printer.sendData(Int(EPOS2_PARAM_DEFAULT))
        printer.clearCommandBuffer()

        guard result == EPOS2_SUCCESS.rawValue else {
            print("❌ Drawer kick failed with code: \(result)")
            return false
        }

        print("✅ Cash drawer opened")
        return true
    }

    // MARK: - Test Print

    func testPrint() async -> Bool {
        let content = ReceiptFormatter.formatTestReceipt(settings: ReceiptSettings())
        let receipt = ReceiptData(type: .test, content: content, settings: ReceiptSettings())
        let result = await printReceipt(receipt)
        return result.wasSuccessful
    }

    // MARK: - Private Helpers

    private func savePrinterIP() {
        UserDefaults.standard.set(printerIP, forKey: ipKey)
    }
}

// MARK: - Discovery Delegate

private class DiscoveryDelegate: NSObject, Epos2DiscoveryDelegate {
    private let onFound: @Sendable (Epos2DeviceInfo) -> Void

    init(onFound: @escaping @Sendable (Epos2DeviceInfo) -> Void) {
        self.onFound = onFound
    }

    func onDiscovery(_ deviceInfo: Epos2DeviceInfo) {
        print("🔍 Found device: \(deviceInfo.deviceName) at \(deviceInfo.ipAddress)")
        onFound(deviceInfo)
    }
}
