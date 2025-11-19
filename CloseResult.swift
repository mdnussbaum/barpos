import Foundation

public struct LineSnapshot: Codable, Hashable, Identifiable {
    public let id: UUID
    public let productName: String
    public let qty: Int
    public let unitPrice: Decimal
    public let lineTotal: Decimal

    public init(
        id: UUID = UUID(),
        productName: String,
        qty: Int,
        unitPrice: Decimal,
        lineTotal: Decimal
    ) {
        self.id = id
        self.productName = productName
        self.qty = qty
        self.unitPrice = unitPrice
        self.lineTotal = lineTotal
    }
}

public enum PaymentMethod: String, Codable, CaseIterable {
    case cash
    case card
    case other
}

public struct CloseResult: Codable, Hashable, Identifiable {
    public let id: UUID
    public let tabName: String
    public let lines: [LineSnapshot]
    public let subtotal: Decimal
    public let total: Decimal
    public let paymentMethod: PaymentMethod
    public let cashTendered: Decimal
    public let changeDue: Decimal
    public let closedAt: Date

    // ✅ NEW: who closed it (for “My Shifts” filtering)
    public let bartenderID: UUID?
    public let bartenderName: String?

    public init(
        id: UUID = UUID(),
        tabName: String,
        lines: [LineSnapshot],
        subtotal: Decimal,
        total: Decimal,
        paymentMethod: PaymentMethod,
        cashTendered: Decimal,
        changeDue: Decimal,
        closedAt: Date = Date(),
        bartenderID: UUID? = nil,
        bartenderName: String? = nil
    ) {
        self.id = id
        self.tabName = tabName
        self.lines = lines
        self.subtotal = subtotal
        self.total = total
        self.paymentMethod = paymentMethod
        self.cashTendered = cashTendered
        self.changeDue = changeDue
        self.closedAt = closedAt
        self.bartenderID = bartenderID
        self.bartenderName = bartenderName
    }
}
