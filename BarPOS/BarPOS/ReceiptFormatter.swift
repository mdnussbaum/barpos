import Foundation

struct ReceiptFormatter {

    // MARK: - Customer Receipt

    static func formatCustomerReceipt(_ result: CloseResult, settings: ReceiptSettings) -> ReceiptContent {
        var lines: [String] = []

        // Header
        let separator = String(repeating: "=", count: 32)
        lines.append(separator)
        lines.append(center(settings.headerText, width: 32))
        lines.append(separator)
        lines.append("")

        // Date/Time
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, yyyy  h:mm a"
        lines.append("Date: \(dateFormatter.string(from: result.closedAt))")
        lines.append("Tab: \(result.tabName)")
        if let bartender = result.bartenderName {
            lines.append("Server: \(bartender)")
        }
        lines.append(String(repeating: "-", count: 32))
        lines.append("")

        // Items
        lines.append("ITEMS:")
        for line in result.lines {
            let qty = "x\(line.qty)"
            let price = line.lineTotal.currencyString()
            let nameWidth = 32 - qty.count - price.count - 2
            let truncatedName = String(line.productName.prefix(nameWidth))
            lines.append("\(truncatedName) \(qty)  \(price)")
        }
        lines.append("")

        // Totals
        let subtotalLine = formatLine("Subtotal:", result.subtotal.currencyString())
        let taxLine = formatLine("Tax:", (result.total - result.subtotal).currencyString())
        let totalLine = formatLine("TOTAL:", result.total.currencyString())

        lines.append(String(repeating: " ", count: 16) + subtotalLine)
        lines.append(String(repeating: " ", count: 16) + taxLine)
        lines.append(String(repeating: "-", count: 32))
        lines.append(String(repeating: " ", count: 16) + totalLine)
        lines.append("")

        // Payment
        if result.paymentMethod == .cash {
            lines.append(formatLine("Cash Tendered:", result.cashTendered.currencyString(), rightPad: 16))
            lines.append(formatLine("Change Due:", result.changeDue.currencyString(), rightPad: 16))
        } else {
            lines.append(formatLine("Payment:", result.paymentMethod.rawValue.capitalized, rightPad: 16))
        }

        // Footer
        lines.append("")
        lines.append(separator)
        lines.append(center(settings.footerText, width: 32))
        lines.append(separator)

        return ReceiptContent(
            header: settings.headerText,
            body: lines,
            footer: settings.footerText
        )
    }

    // MARK: - Shift Report

    static func formatShiftReport(_ report: ShiftReport, settings: ReceiptSettings) -> ReceiptContent {
        var lines: [String] = []

        let separator = String(repeating: "=", count: 32)
        lines.append(separator)
        lines.append(center("SHIFT REPORT", width: 32))
        lines.append(separator)
        lines.append("")

        // Bartender & Time
        lines.append("Bartender: \(report.bartenderName)")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd, h:mm a"
        lines.append("Started: \(dateFormatter.string(from: report.startedAt))")
        lines.append("Ended: \(dateFormatter.string(from: report.endedAt))")
        lines.append(String(repeating: "-", count: 32))
        lines.append("")

        // Sales Summary
        lines.append("SALES SUMMARY")
        lines.append(formatLine("Tabs Closed:", "\(report.tabsCount)"))
        lines.append(formatLine("Gross Sales:", report.grossSales.currencyString()))
        lines.append(formatLine("Net Sales:", report.netSales.currencyString()))
        lines.append(formatLine("Tax Collected:", report.taxCollected.currencyString()))
        lines.append("")

        // Payment Breakdown
        lines.append("PAYMENT BREAKDOWN")
        lines.append(formatLine("Cash:", report.cashSales.currencyString()))
        lines.append(formatLine("Card:", report.cardSales.currencyString()))
        lines.append(formatLine("Other:", report.otherSales.currencyString()))
        lines.append("")

        // Cash Reconciliation
        if let opening = report.openingCash, let closing = report.closingCash {
            lines.append("CASH RECONCILIATION")
            lines.append(formatLine("Opening:", opening.currencyString()))
            lines.append(formatLine("+ Cash Sales:", report.cashSales.currencyString()))
            lines.append(formatLine("Expected:", report.expectedCash.currencyString()))
            lines.append(formatLine("Closing:", closing.currencyString()))
            lines.append(String(repeating: "-", count: 32))

            let overShortLabel = report.overShort >= 0 ? "Over:" : "Short:"
            lines.append(formatLine(overShortLabel, report.overShort.currencyString()))

            if report.flagged, let note = report.flagNote {
                lines.append("")
                lines.append("WARNING: \(note)")
            }
        }

        lines.append("")
        lines.append(separator)

        return ReceiptContent(
            header: settings.headerText,
            body: lines,
            footer: ""
        )
    }

    // MARK: - Test Receipt

    static func formatTestReceipt(settings: ReceiptSettings) -> ReceiptContent {
        let separator = String(repeating: "=", count: 32)
        let body = [
            separator,
            center("TEST RECEIPT", width: 32),
            separator,
            "",
            "This is a test print to verify",
            "your printer is working correctly.",
            "",
            "Date: \(Date().formatted())",
            "",
            "If you can read this, your",
            "printer is connected!",
            "",
            separator
        ]

        return ReceiptContent(
            header: "Test Print",
            body: body,
            footer: "Test Complete"
        )
    }

    // MARK: - Helper Functions

    private static func center(_ text: String, width: Int) -> String {
        let padding = max(0, (width - text.count) / 2)
        return String(repeating: " ", count: padding) + text
    }

    private static func formatLine(_ label: String, _ value: String, rightPad: Int = 0) -> String {
        let totalWidth = 32 - rightPad
        let spaces = max(1, totalWidth - label.count - value.count)
        return label + String(repeating: " ", count: spaces) + value
    }
}
