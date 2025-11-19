import Foundation

struct ShiftReport: Identifiable, Codable, Hashable {
    // Identity (handy for lists)
    var id: UUID = UUID()

    // Who/when
    var bartenderID: UUID?
    var bartenderName: String
    var startedAt: Date
    var endedAt: Date

    // Cash counts
    var openingCash: Decimal?
    var closingCash: Decimal?

    // Sales summary
    var tabsCount: Int
    var grossSales: Decimal
    var netSales: Decimal
    var taxCollected: Decimal
    var cashSales: Decimal
    var cardSales: Decimal
    var otherSales: Decimal

    // Derived reconciliations
    var expectedCash: Decimal   // (openingCash ?? 0) + cashSales at settle time
    var overShort: Decimal      // (closingCash ?? 0) - expectedCash

    // Ticket archive snapshot
    var tickets: [CloseResult]

    // 🔶 Silent flagging (admin UI can surface)
    var flagged: Bool
    var flagNote: String?

    // Convenience for old UI names
    var discrepancy: Decimal { overShort }
}
