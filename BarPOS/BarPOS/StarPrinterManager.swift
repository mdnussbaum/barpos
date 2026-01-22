/*
 TEMPORARILY COMMENTED OUT - Star SDK Not Added Yet
 
 This file requires StarIO10 framework which hasn't been added to the project yet.
 Uncomment this file after:
 1. Downloading Star SDK
 2. Adding StarIO10.xcframework to Xcode
 3. Updating Info.plist with required permissions
 
 For now, use MockPrinterManager for development and testing.
 */

/*
import Foundation
import StarIO10

@MainActor
class StarPrinterManager: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var printerName: String = ""

    private var printer: StarPrinter?
    private let interfaceType = InterfaceType.usb

    init() {
        Task {
            await discoverPrinter()
        }
    }

    // MARK: - Discovery
    func discoverPrinter() async {
        let manager = StarDeviceDiscoveryManagerFactory.create(interfaceTypes: [interfaceType])

        manager.discoveryTime = 10_000 // 10 seconds

        do {
            try await manager.startDiscovery()

            // Wait for discovery
            try await Task.sleep(for: .seconds(3))

            // Get first discovered printer
            if let firstPrinter = manager.printers.first {
                await connectToPrinter(firstPrinter)
            }

            manager.stopDiscovery()
        } catch {
            print("❌ Discovery error: \(error)")
        }
    }

    private func connectToPrinter(_ printerInfo: StarPrinter) async {
        printer = printerInfo
        printerName = printerInfo.information?.model ?? "Star Printer"
        isConnected = true

        print("✅ Connected to: \(printerName)")
    }

    // MARK: - Print Receipt
    func printReceipt(_ content: StarReceiptContent) async throws {
        guard let printer = printer else {
            throw PrinterError.notConnected
        }

        // Build Star commands
        let builder = StarXpandCommand.StarXpandCommandBuilder()

        _ = builder.addDocument(StarXpandCommand.DocumentBuilder()
            .addPrinter(StarXpandCommand.PrinterBuilder()
                // Header
                .actionPrintText(content.header + "\n")
                .styleAlignment(.center)
                .actionPrintText("─────────────────────────\n")

                // Lines
                .styleAlignment(.left)
                .also { printerBuilder in
                    for line in content.lines {
                        _ = printerBuilder.actionPrintText(
                            "\(line.quantity)x \(line.itemName) $\(line.price)\n"
                        )
                    }
                }

                // Totals
                .actionPrintText("─────────────────────────\n")
                .actionPrintText("Subtotal: $\(content.subtotal)\n")
                .actionPrintText("Tax: $\(content.tax)\n")
                .styleBold(true)
                .actionPrintText("TOTAL: $\(content.total)\n")
                .styleBold(false)

                // Footer
                .actionPrintText("\n\(content.footer)\n")
                .styleAlignment(.center)

                // Cut
                .actionCut(.partial)
            )
        )

        let commands = builder.getCommands()

        // Send to printer
        try await printer.print(command: commands)

        print("✅ Receipt printed")
    }

    // MARK: - Open Drawer
    func openDrawer() async throws {
        guard let printer = printer else {
            throw PrinterError.notConnected
        }

        // Drawer kick command: ESC p m t1 t2
        let drawerKick = Data([0x1B, 0x70, 0x00, 0x19, 0x64])

        let builder = StarXpandCommand.StarXpandCommandBuilder()
        _ = builder.addDocument(StarXpandCommand.DocumentBuilder()
            .addPrinter(StarXpandCommand.PrinterBuilder()
                .actionPrintRawData(drawerKick)
            )
        )

        let commands = builder.getCommands()
        try await printer.print(command: commands)

        print("✅ Drawer opened")
    }

    // MARK: - Print + Open Drawer
    func printReceiptAndOpenDrawer(_ content: StarReceiptContent) async throws {
        try await printReceipt(content)
        try await openDrawer()
    }
}

// MARK: - Errors
enum PrinterError: Error {
    case notConnected
    case printFailed(Error)
    case drawerFailed(Error)
}

// MARK: - Receipt Content Model
struct StarReceiptContent {
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
*/
