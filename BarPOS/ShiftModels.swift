import Foundation

public struct Bartender: Identifiable, Codable, Hashable {
    public let id: UUID
    public var name: String

    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

// MARK: - Payments & Metrics

public enum PaymentKind: String, Codable, Hashable, CaseIterable {
    case cash, card, other
}

public struct ShiftMetrics: Codable, Hashable {
    public var tabsCount: Int
    public var grossSales: Decimal
    public var netSales: Decimal
    public var taxCollected: Decimal
    public var byPayment: [PaymentKind: Decimal]

    public init(
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

public struct ShiftRecord: Identifiable, Codable, Hashable {
    public let id: UUID
    public var startedAt: Date
    public var openedBy: Bartender?
    public var openingCash: Decimal?

    public var endedAt: Date?
    public var closedBy: Bartender?
    public var closingCash: Decimal?

    public var metrics: ShiftMetrics

    public init(id: UUID = UUID(),
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
