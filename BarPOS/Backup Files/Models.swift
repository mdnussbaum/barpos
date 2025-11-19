import Foundation

// MARK: - ChipType
public enum ChipType: String, Codable, Hashable, CaseIterable {
    case white, gray, black

    // Default prices baked into the app
    private var defaultPrice: Decimal {
        switch self {
        case .white: return 3
        case .gray:  return 4
        case .black: return 5
        }
    }

    // Runtime overrides (not persisted here; InventoryVM owns persistence)
    private static var overrides: [ChipType: Decimal] = [:]

    /// VM calls this after loading persisted state.
    public static func applyOverrides(_ dict: [ChipType: Decimal]) {
        overrides = dict
    }

    /// Current effective price (override if present, else default).
    public var price: Decimal {
        ChipType.overrides[self] ?? defaultPrice
    }

    public var displayName: String {
        switch self {
        case .white: return "White"
        case .gray:  return "Gray"
        case .black: return "Black"
        }
    }
}

// ===== SINGLE SOURCE OF TRUTH =====
// MARK: - Product Categories
enum ProductCategory: String, Codable, CaseIterable, Identifiable {
    case beer, wine, liquor, shots, cocktails, na, food, chips, misc
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .beer: return "Beer"
        case .wine: return "Wine"
        case .liquor: return "Liquor"
        case .shots: return "Shots"
        case .cocktails: return "Cocktails"
        case .na: return "N/A"
        case .food: return "Food"
        case .chips: return "Chips"
        case .misc: return "Misc"
        }
    }
}

// MARK: - Product
// ===== PATCH 1: Product gains displayOrder for saved ordering =====
struct Product: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var category: ProductCategory
    var price: Decimal
    var isHidden: Bool = false
    var displayOrder: Int = 0      // ← new, defaults to 0 for old JSON
}

// MARK: - Core models

struct OrderLine: Identifiable, Codable, Hashable {
    let id: UUID
    var product: Product
    var qty: Int

    init(id: UUID = UUID(), product: Product, qty: Int = 1) {
        self.id = id
        self.product = product
        self.qty = qty
    }

    var lineTotal: Decimal {
        Decimal(qty) * product.price
    }
}


// MARK: - TabTicket (one and only definition)
struct TabTicket: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var lines: [OrderLine]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        lines: [OrderLine] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.lines = lines
        self.createdAt = createdAt
    }

    var subtotal: Decimal {
        lines.reduce(0) { $0 + $1.lineTotal }
    }
    var tax: Decimal { 0 }
    var total: Decimal { subtotal + tax }
}
