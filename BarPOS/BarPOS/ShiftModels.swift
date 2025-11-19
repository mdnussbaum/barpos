import Foundation

// MARK: - Payments & Metrics

enum PaymentKind: String, Codable, Hashable, CaseIterable {
    case cash, card, other
}

struct ShiftMetrics: Codable, Hashable {
    var tabsCount: Int
    var grossSales: Decimal
    var netSales: Decimal
    var taxCollected: Decimal
    var byPayment: [PaymentKind: Decimal]

    init(
        tabsCount: Int = 0,
        grossSales: Decimal = 0,
        netSales: Decimal = 0,
        taxCollected: Decimal = 0,
        byPayment: [PaymentKind: Decimal] = [:]
    ) {
        self.tabsCount = tabsCount
        self.grossSales = grossSales
        self.netSales = netSales
        self.taxCollected = taxCollected
        self.byPayment = byPayment
    }
}

// MARK: - Shift

struct ShiftRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var startedAt: Date
    var openedBy: Bartender?
    var openingCash: Decimal?

    var endedAt: Date?
    var closedBy: Bartender?
    var closingCash: Decimal?

    var metrics: ShiftMetrics

    init(id: UUID = UUID(),
         startedAt: Date = Date(),
         openedBy: Bartender? = nil,
         openingCash: Decimal? = nil,
         endedAt: Date? = nil,
         closedBy: Bartender? = nil,
         closingCash: Decimal? = nil,
         metrics: ShiftMetrics = ShiftMetrics()) {
        self.id = id
        self.startedAt = startedAt
        self.openedBy = openedBy
        self.openingCash = openingCash
        self.endedAt = endedAt
        self.closedBy = closedBy
        self.closingCash = closingCash
        self.metrics = metrics
    }
}
