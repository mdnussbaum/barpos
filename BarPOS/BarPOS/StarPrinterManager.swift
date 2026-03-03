import Foundation
import Combine
import StarIO10

@MainActor
class StarPrinterManager: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var printerName: String = "Star Printer"

    private var printer: StarPrinter?

    init() {
        Task {
            await discoverPrinter()
        }
    }

    // MARK: - Discovery (delegate-based, bridged to async via continuation)
    func discoverPrinter() async {
        do {
            let manager = try StarDeviceDiscoveryManagerFactory.create(interfaceTypes: [.usb, .lan, .bluetooth])
            let delegate = DiscoveryDelegate()
            manager.delegate = delegate
            manager.discoveryTime = 10_000 // 10 seconds

            try manager.startDiscovery()

            // Wait up to 5 seconds for a printer to be found
            let foundPrinter: StarPrinter? = await withTaskGroup(of: StarPrinter?.self) { group in
                group.addTask {
                    try? await Task.sleep(for: .seconds(5))
                    return nil
                }
                group.addTask {
                    await delegate.waitForPrinter()
                }
                for await result in group {
                    group.cancelAll()
                    return result
                }
                return nil
            }

            manager.stopDiscovery()

            if let found = foundPrinter {
                await connectToPrinter(found)
            }
        } catch {
            print("❌ Discovery error: \(error)")
        }
    }

    private func connectToPrinter(_ printerInfo: StarPrinter) async {
        printer = printerInfo
        printerName = printerInfo.information?.model.description ?? "Star Printer"
        isConnected = true
        print("✅ Connected to: \(printerName)")
    }

    // MARK: - Print Receipt
    func printReceipt(_ content: StarReceiptContent) async throws {
        let p = try requirePrinter()

        let builder = StarXpandCommand.StarXpandCommandBuilder()

        var printerBuilder = StarXpandCommand.PrinterBuilder()
            .styleAlignment(.center)
            .actionPrintText(content.header + "\n")
            .actionPrintText("─────────────────────────\n")
            .styleAlignment(.left)

        for line in content.lines {
            printerBuilder = printerBuilder.actionPrintText(
                "\(line.quantity)x \(line.itemName)  \(line.price)\n"
            )
        }

        printerBuilder = printerBuilder
            .actionPrintText("─────────────────────────\n")
            .actionPrintText("Subtotal: \(content.subtotal)\n")
            .actionPrintText("Tax:      \(content.tax)\n")
            .styleBold(true)
            .actionPrintText("TOTAL:    \(content.total)\n")
            .styleBold(false)
            .styleAlignment(.center)
            .actionPrintText("\n\(content.footer)\n")
            .actionCut(.partial)

        _ = builder.addDocument(
            StarXpandCommand.DocumentBuilder()
                .addPrinter(printerBuilder)
        )

        let commands = builder.getCommands()
        try await p.open()
        try await p.print(command: commands)
        await p.close()

        print("✅ Receipt printed")
    }

    // MARK: - Open Drawer
    func openDrawer() async throws {
        let p = try requirePrinter()

        let builder = StarXpandCommand.StarXpandCommandBuilder()
        _ = builder.addDocument(
            StarXpandCommand.DocumentBuilder()
                .addDrawer(
                    StarXpandCommand.DrawerBuilder()
                        .actionOpen(StarXpandCommand.Drawer.OpenParameter())
                )
        )

        let commands = builder.getCommands()
        try await p.open()
        try await p.print(command: commands)
        await p.close()

        print("✅ Drawer opened")
    }

    // MARK: - Print + Open Drawer
    func printReceiptAndOpenDrawer(_ content: StarReceiptContent) async throws {
        let p = try requirePrinter()

        // Build combined receipt + drawer command
        let builder = StarXpandCommand.StarXpandCommandBuilder()

        var printerBuilder = StarXpandCommand.PrinterBuilder()
            .styleAlignment(.center)
            .actionPrintText(content.header + "\n")
            .actionPrintText("─────────────────────────\n")
            .styleAlignment(.left)

        for line in content.lines {
            printerBuilder = printerBuilder.actionPrintText(
                "\(line.quantity)x \(line.itemName)  \(line.price)\n"
            )
        }

        printerBuilder = printerBuilder
            .actionPrintText("─────────────────────────\n")
            .actionPrintText("Subtotal: \(content.subtotal)\n")
            .actionPrintText("Tax:      \(content.tax)\n")
            .styleBold(true)
            .actionPrintText("TOTAL:    \(content.total)\n")
            .styleBold(false)
            .styleAlignment(.center)
            .actionPrintText("\n\(content.footer)\n")
            .actionCut(.partial)

        _ = builder.addDocument(
            StarXpandCommand.DocumentBuilder()
                .addPrinter(printerBuilder)
                .addDrawer(
                    StarXpandCommand.DrawerBuilder()
                        .actionOpen(StarXpandCommand.Drawer.OpenParameter())
                )
        )

        let commands = builder.getCommands()
        try await p.open()
        try await p.print(command: commands)
        await p.close()
    }

    // MARK: - Convenience helpers (compatible with PrinterSettingsView)
    func testPrint() async -> Bool {
        let testContent = StarReceiptContent(
            header: "TEST RECEIPT",
            lines: [ReceiptLine(quantity: 1, itemName: "Test Item", price: "$0.00")],
            subtotal: "$0.00",
            tax:      "$0.00",
            total:    "$0.00",
            footer: "Printer is working!"
        )
        do {
            try await printReceipt(testContent)
            return true
        } catch {
            print("❌ Test print failed: \(error)")
            return false
        }
    }

    func openCashDrawer() async -> Bool {
        do {
            try await openDrawer()
            return true
        } catch {
            print("❌ Cash drawer failed: \(error)")
            return false
        }
    }

    // MARK: - Private helpers

    private func requirePrinter() throws -> StarPrinter {
        guard let p = printer else { throw PrinterError.notConnected }
        return p
    }
}

// MARK: - Discovery Delegate (bridges callback to async)
private final class DiscoveryDelegate: NSObject, StarDeviceDiscoveryManagerDelegate, @unchecked Sendable {
    private var continuation: CheckedContinuation<StarPrinter, Never>?
    private var foundPrinter: StarPrinter?
    private let lock = NSLock()

    func waitForPrinter() async -> StarPrinter {
        await withCheckedContinuation { continuation in
            lock.lock()
            if let already = foundPrinter {
                lock.unlock()
                continuation.resume(returning: already)
            } else {
                self.continuation = continuation
                lock.unlock()
            }
        }
    }

    func manager(_ manager: StarDeviceDiscoveryManager, didFind printer: StarPrinter) {
        lock.lock()
        foundPrinter = printer
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume(returning: printer)
    }

    func managerDidFinishDiscovery(_ manager: StarDeviceDiscoveryManager) {
        // Discovery finished without finding a printer — resolve with a never-settling task
        // The timeout task in discoverPrinter() will cancel this
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
