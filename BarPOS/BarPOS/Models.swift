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
// MARK: - Unit of Measure
enum UnitOfMeasure: String, Codable, CaseIterable, Identifiable {
    case each = "each"
    case bottle = "bottle"
    case can = "can"        // ← ADD THIS
    case case_ = "case"
    case oz = "oz"
    case liter = "liter"
    case gallon = "gallon"
    case keg = "keg"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .each: return "Each"
        case .bottle: return "Bottle"
        case .can: return "Can"      
        case .case_: return "Case"
        case .oz: return "oz"
        case .liter: return "Liter"
        case .gallon: return "Gallon"
        case .keg: return "Keg"
        }
    }
}

// MARK: - Product Tier
enum ProductTier: String, Codable, CaseIterable, Identifiable {
    case none = "none"
    case well = "well"
    case call = "call"
    case premium = "premium"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .well: return "Well"
        case .call: return "Call"
        case .premium: return "Premium"
        }
    }
}

// MARK: - Bartender
struct Bartender: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var isActive: Bool = true
    var pin: String? = nil
    
    init(id: UUID = UUID(), name: String, isActive: Bool = true, pin: String? = nil) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.pin = pin
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
struct Product: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var category: ProductCategory
    var price: Decimal
    var isHidden: Bool = false
    var displayOrder: Int = 0
    
    // Inventory tracking
    var stockQuantity: Decimal? = nil
    var parLevel: Decimal? = nil
    var unit: UnitOfMeasure = .each
    var servingSize: Decimal? = nil
    var servingUnit: UnitOfMeasure? = nil

    // Product type
    var tier: ProductTier = .none
    var isGunItem: Bool = false  // Soda guns, BIB mixers

    // Cost & profit
    var cost: Decimal? = nil
    
    // Supplier info
    var supplier: String? = nil
    var supplierSKU: String? = nil
    var caseSize: Int? = nil  // How many bottles per case
    
    // Status
    var is86d: Bool = false
    var canBeIngredient: Bool = false

    // Computed properties
    var profitMargin: Decimal? {
        guard let cost = cost,
              cost > 0,
              price > 0,
              cost.isFinite,
              price.isFinite else { return nil }
        return ((price - cost) / price) * 100
    }
    var stockDisplayString: String? {
            guard let stock = stockQuantity, let size = caseSize, size > 0 else {
                return stockQuantity?.plainString()
            }
            
            let stockInt = (stock as NSDecimalNumber).intValue
            let cases = stockInt / size
            let bottles = stockInt % size
            
            if bottles == 0 {
                return "\(cases) case\(cases == 1 ? "" : "s")"
            } else {
                return "\(cases) case\(cases == 1 ? "" : "s") + \(bottles) btl"
            }
        }
    
    var costPerServing: Decimal? {
        guard let cost = cost,
              let servingSize = servingSize,
              servingSize > 0,
              cost.isFinite,
              servingSize.isFinite else { return nil }
        
        // If serving unit matches stock unit, it's simple
        if servingUnit == nil || servingUnit == unit {
            return cost / servingSize
        }
        
        // Otherwise we need conversion
        return convertedCostPerServing(baseCost: cost)
    }
        
        private func convertedCostPerServing(baseCost: Decimal) -> Decimal? {
            guard let servingSize = servingSize,
                  let servingUnit = servingUnit else { return nil }
            
            // Handle common conversions
            let conversionFactor = getConversionFactor(from: unit, to: servingUnit)
            guard let factor = conversionFactor else { return nil }
            
            // Cost per base unit * conversion factor / serving size
            return (baseCost * factor) / servingSize
        }
        
        private func getConversionFactor(from: UnitOfMeasure, to: UnitOfMeasure) -> Decimal? {
            // Same unit = 1
            if from == to { return 1 }
            
            // Common conversions
            switch (from, to) {
            case (.gallon, .oz): return 128
            case (.liter, .oz): return 33.814
            case (.bottle, .oz): return 12  // Assuming standard 12oz bottle
            case (.keg, .oz): return 1984   // Half barrel keg
            default: return nil
            }
        }
        
        var servingsPerUnit: Decimal? {
            guard let servingSize = servingSize, servingSize > 0 else { return nil }
            
            if servingUnit == nil || servingUnit == unit {
                return 1 / servingSize
            }
            
            if let factor = getConversionFactor(from: unit, to: servingUnit ?? .each) {
                return factor / servingSize
            }
            
            return nil
        }
        var isLowStock: Bool {
            guard let stock = stockQuantity, let par = parLevel else { return false }
            return stock < par
        }
    }

// MARK: - Custom Cocktail Recipe
struct CustomCocktail: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var createdBy: UUID  // Bartender ID
    var ingredients: [RecipeIngredient]
    var basePrice: Decimal  // Calculated from well/default ingredients
    var category: ProductCategory = .cocktails
    var isPending: Bool = true  // Awaiting admin approval
    var approvedBy: UUID? = nil  // Admin who approved
    var approvedAt: Date? = nil

    init(id: UUID = UUID(), name: String, createdBy: UUID, ingredients: [RecipeIngredient], isPending: Bool = true) {
        self.id = id
        self.name = name
        self.createdBy = createdBy
        self.ingredients = ingredients
        self.isPending = isPending

        // Auto-calculate base price from ingredients
        self.basePrice = ingredients.reduce(0) { total, ingredient in
            total + (ingredient.defaultProduct.price * ingredient.servings)
        }
    }

    // Calculate price based on actual ingredient selections
    func calculatePrice(selectedIngredients: [UUID: Product]) -> Decimal {
        ingredients.reduce(0) { total, ingredient in
            let product = ingredient.isVariable ? (selectedIngredients[ingredient.id] ?? ingredient.defaultProduct) : ingredient.defaultProduct
            return total + (product.price * ingredient.servings)
        }
    }
}

struct RecipeIngredient: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var defaultProduct: Product  // The default/well product
    var servings: Decimal  // 0.25, 0.5, 0.75, 1, 1.25, etc.
    var isVariable: Bool = false  // If true, bartender selects at register
    var variableCategory: ProductCategory? = nil  // Filter for variable selection (e.g., .liquor)
    var variableTier: ProductTier? = nil  // Filter for variable selection (e.g., .call)

    var displayText: String {
        let servingText = "\(servings.plainString()) serving\(servings == 1 ? "" : "s")"
        if isVariable {
            return "\(servingText) of variable \(defaultProduct.category.displayName) (\(defaultProduct.name) default)"
        } else {
            return "\(servingText) of \(defaultProduct.name)"
        }
    }
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
