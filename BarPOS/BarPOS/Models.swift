import Foundation

// MARK: - Void Record (for deleted/voided line items)
struct VoidRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var bartenderName: String
    var productName: String
    var amount: Decimal
    var tabName: String
}

// MARK: - Audit Log Entry
struct AuditLogEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var productID: UUID
    var productName: String
    var oldQuantity: Decimal
    var newQuantity: Decimal
    var variance: Decimal
    var reason: String
}

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
    case can = "can"
    case case_ = "case"
    case oz = "oz"
    case liter = "liter"
    case fifth = "fifth"    // 750ml bottle
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
        case .fifth: return "Fifth (750ml)"
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

// MARK: - Bottle Size Helper
enum BottleSize: String, CaseIterable, Identifiable {
    case fifth = "fifth"      // 750ml / 25.36 oz
    case liter = "liter"      // 1L / 33.81 oz
    case handle = "handle"    // 1.75L / 59.17 oz
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .fifth: return "Fifth (750ml)"
        case .liter: return "Liter (1L)"
        case .handle: return "Handle (1.75L)"
        }
    }
    
    var ozEquivalent: Decimal {
        switch self {
        case .fifth: return 25.36
        case .liter: return 33.81
        case .handle: return 59.17
        }
    }
}

// MARK: - Keg Size Helper
enum KegSize: String, CaseIterable, Identifiable {
    case sixthBarrel  = "sixthBarrel"   // 1/6 barrel: 661 oz
    case quarterBarrel = "quarterBarrel" // 1/4 barrel: 992 oz
    case halfBarrel   = "halfBarrel"    // 1/2 barrel: 1984 oz

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sixthBarrel:   return "1/6 Barrel (661 oz)"
        case .quarterBarrel: return "1/4 Barrel (992 oz)"
        case .halfBarrel:    return "1/2 Barrel (1984 oz)"
        }
    }

    /// Total fluid ounces in this keg size
    var totalOz: Int {
        switch self {
        case .sixthBarrel:   return 661
        case .quarterBarrel: return 992
        case .halfBarrel:    return 1984
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

// MARK: - Size Variant
struct SizeVariant: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String              // "Short" or "Tall" for draft beer
    var sizeOz: Decimal           // 16 for Short, 22 for Tall
    var price: Decimal            // Price for this size
    var isDefault: Bool = false   // Which size shows first
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
    var caseSize: Int? = nil  // How many bottles per case (or pints per keg when unit == .keg)
    var kegSizeOz: Int? = nil // Total oz in keg (set when unit == .keg; drives costPerServing)
    
    // Status
    var is86d: Bool = false
    var canBeIngredient: Bool = false
    
    // Size variants (for products with multiple size options)
    var sizeVariants: [SizeVariant]? = nil
    
    // Recipe link (for approved cocktails)
    var recipeID: UUID? = nil
    
    // Happy hour pricing
    var happyHourPrice: Decimal? = nil  // Optional HH price (nil = not on HH)

    // Computed properties
    var profitMargin: Decimal? {
        guard let costPerServ = costPerServing, costPerServ > 0, price > 0 else { return nil }
        return ((price - costPerServ) / costPerServ) * 100
    }

    func suggestedPrice(using rules: PricingRules = PricingRules()) -> Decimal? {
        guard let cost = cost, cost > 0 else { return nil }
        print("[suggestedPrice] product=\(name) category=\(category) liquorTargetCostRatio=\(rules.liquorTargetCostRatio)")
        let increment = (rules.priceRoundingIncrement as NSDecimalNumber).doubleValue
        let costRatio = rules.costRatio(for: category, unit: unit)

        // Keg: subtract deposit, divide by total oz, multiply by serving size
        if unit == .keg, let kegOz = kegSizeOz, let servSize = servingSize, kegOz > 0, servSize > 0 {
            let adjustedCost = cost - rules.kegDepositAmount
            let costPerPint = (adjustedCost / Decimal(kegOz)) * servSize
            let suggested = costPerPint / costRatio
            let increments = ((suggested as NSDecimalNumber).doubleValue / increment).rounded(.up)
            return Decimal(increments * increment)
        }

        // All others: use costPerServing
        guard let costPerServ = costPerServing, costPerServ > 0 else { return nil }
        let suggested = costPerServ / costRatio
        let increments = ((suggested as NSDecimalNumber).doubleValue / increment).rounded(.up)
        return Decimal(increments * increment)
    }

    /// Convenience accessor using hardcoded defaults (for callers that haven't adopted PricingRules yet)
    var suggestedPrice: Decimal? { suggestedPrice() }

    func priceVariance(using rules: PricingRules = PricingRules()) -> Decimal? {
        guard let suggested = suggestedPrice(using: rules) else { return nil }
        return price - suggested
    }

    var priceVariance: Decimal? { priceVariance() }

    func priceVariancePercent(using rules: PricingRules = PricingRules()) -> Decimal? {
        guard let suggested = suggestedPrice(using: rules), suggested > 0 else { return nil }
        return ((price - suggested) / suggested) * 100
    }

    var priceVariancePercent: Decimal? { priceVariancePercent() }
    var stockDisplayString: String? {
            guard let stock = stockQuantity else { return nil }

            // Keg display: show whole kegs + remaining pints when pintsPerKeg is configured
            if unit == .keg, let pintsPerKeg = caseSize, pintsPerKeg > 0 {
                let kegSizeOzValue = kegSizeOz ?? 1984
                let totalOz = (stock as NSDecimalNumber).doubleValue * Double(kegSizeOzValue)
                let ozPerPint = 16.0
                _ = Int(totalOz / ozPerPint)
                let wholeKegs = Int((stock as NSDecimalNumber).doubleValue)
                let remainderOz = totalOz - Double(wholeKegs) * Double(kegSizeOzValue)
                let remainderPints = Int(remainderOz / ozPerPint)

                if wholeKegs == 0 {
                    return "\(remainderPints) pints remaining"
                } else if remainderPints == 0 {
                    return "\(wholeKegs) keg\(wholeKegs == 1 ? "" : "s")"
                } else {
                    return "\(wholeKegs) keg\(wholeKegs == 1 ? "" : "s") (\(remainderPints) pints remaining)"
                }
            }

            // Case/bottle display
            guard let size = caseSize, size > 0 else {
                return stock.plainString()
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
        print("🍺 [costPerServing] '\(name)' — cost=\(cost.map { "\($0)" } ?? "nil"), servingSize=\(servingSize.map { "\($0)" } ?? "nil"), servingUnit=\(servingUnit.map { $0.rawValue } ?? "nil"), unit=\(unit.rawValue), kegSizeOz=\(kegSizeOz.map { "\($0)" } ?? "nil")")

        guard let cost = cost, cost.isFinite else {
            print("🍺 [costPerServing] → nil (cost is nil or not finite)")
            return nil
        }

        guard let servingSize = servingSize,
              servingSize > 0,
              servingSize.isFinite else {
            print("🍺 [costPerServing] → nil (servingSize is nil, zero, or not finite: \(servingSize.map { "\($0)" } ?? "nil"))")
            return nil
        }

        // Keg: (cost ÷ kegSizeOz) × servingSize  e.g. $159.77 ÷ 1984oz × 16oz = $1.29/pint
        if unit == .keg {
            let totalOz = Decimal(kegSizeOz ?? 1984)
            let result = (cost / totalOz) * servingSize
            print("🍺 [costPerServing] → \(result) (keg path: cost \(cost) ÷ \(totalOz)oz × servingSize \(servingSize)oz)")
            return result
        }

        // If serving unit matches stock unit, it's simple
        if servingUnit == nil || servingUnit == unit {
            let result = cost / servingSize
            print("🍺 [costPerServing] → \(result) (same unit path: cost \(cost) ÷ servingSize \(servingSize))")
            return result
        }

        // Convert: cost per stock unit → cost per serving unit → cost per serving
        guard let conversionFactor = getConversionFactor(from: unit, to: servingUnit ?? unit) else {
            print("🍺 [costPerServing] → nil (no conversion factor from \(unit.rawValue) to \(servingUnit?.rawValue ?? unit.rawValue))")
            return nil
        }

        // Cost per serving unit
        let costPerServingUnit = cost / conversionFactor

        // Cost per individual serving
        let result = costPerServingUnit / servingSize
        print("🍺 [costPerServing] → \(result) (conversion path: cost \(cost) ÷ factor \(conversionFactor) = \(costPerServingUnit) per \(servingUnit?.rawValue ?? unit.rawValue), ÷ servingSize \(servingSize))")
        return result
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
            case (.fifth, .oz): return 25.36     // 750ml bottle
            case (.bottle, .oz): return 12       // Standard 12oz beer bottle
            case (.case_, .bottle): return Decimal(caseSize ?? 24)  // bottles per case
            case (.keg, .oz):
                // Use the admin-selected keg size if available; fall back to half barrel
                if let oz = kegSizeOz {
                    print("🍺 [getConversionFactor] keg→oz using kegSizeOz=\(oz)")
                    return Decimal(oz)
                }
                print("🍺 [getConversionFactor] keg→oz kegSizeOz is nil, using default 1984")
                return 1984  // Default: half barrel
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

// MARK: - Pricing Rules
struct PricingRules: Codable, Equatable {
    var defaultLiquorServingSizeOz: Decimal = 1.125
    var defaultBeerServingSizeOz: Decimal = 1.0
    var kegDepositAmount: Decimal = 30.0
    var liquorTargetCostRatio: Decimal = 0.33
    var beerTargetCostRatio: Decimal = 0.33
    var kegTargetCostRatio: Decimal = 0.25
    var priceRoundingIncrement: Decimal = 0.50

    // Convenience: pick the right ratio based on category and unit
    func costRatio(for category: ProductCategory, unit: UnitOfMeasure) -> Decimal {
        if unit == .keg { return kegTargetCostRatio }
        switch category {
        case .beer: return beerTargetCostRatio
        default:    return liquorTargetCostRatio
        }
    }

    // Migration: load old single-ratio saves
    enum CodingKeys: String, CodingKey {
        case defaultLiquorServingSizeOz, defaultBeerServingSizeOz, kegDepositAmount
        case liquorTargetCostRatio, beerTargetCostRatio, kegTargetCostRatio
        case priceRoundingIncrement
        case targetCostRatio  // legacy key
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        defaultLiquorServingSizeOz = try c.decodeIfPresent(Decimal.self, forKey: .defaultLiquorServingSizeOz) ?? 1.125
        defaultBeerServingSizeOz   = try c.decodeIfPresent(Decimal.self, forKey: .defaultBeerServingSizeOz)   ?? 1.0
        kegDepositAmount           = try c.decodeIfPresent(Decimal.self, forKey: .kegDepositAmount)           ?? 30.0
        priceRoundingIncrement     = try c.decodeIfPresent(Decimal.self, forKey: .priceRoundingIncrement)     ?? 0.50
        // Migrate old single targetCostRatio to per-category fields
        let legacy = try c.decodeIfPresent(Decimal.self, forKey: .targetCostRatio)
        liquorTargetCostRatio = try c.decodeIfPresent(Decimal.self, forKey: .liquorTargetCostRatio) ?? legacy ?? 0.33
        beerTargetCostRatio   = try c.decodeIfPresent(Decimal.self, forKey: .beerTargetCostRatio)   ?? legacy ?? 0.33
        kegTargetCostRatio    = try c.decodeIfPresent(Decimal.self, forKey: .kegTargetCostRatio)    ?? 0.25
    }

    init(
        defaultLiquorServingSizeOz: Decimal = 1.125,
        defaultBeerServingSizeOz: Decimal = 1.0,
        kegDepositAmount: Decimal = 30.0,
        liquorTargetCostRatio: Decimal = 0.33,
        beerTargetCostRatio: Decimal = 0.33,
        kegTargetCostRatio: Decimal = 0.25,
        priceRoundingIncrement: Decimal = 0.50
    ) {
        self.defaultLiquorServingSizeOz = defaultLiquorServingSizeOz
        self.defaultBeerServingSizeOz = defaultBeerServingSizeOz
        self.kegDepositAmount = kegDepositAmount
        self.liquorTargetCostRatio = liquorTargetCostRatio
        self.beerTargetCostRatio = beerTargetCostRatio
        self.kegTargetCostRatio = kegTargetCostRatio
        self.priceRoundingIncrement = priceRoundingIncrement
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(defaultLiquorServingSizeOz, forKey: .defaultLiquorServingSizeOz)
        try c.encode(defaultBeerServingSizeOz,   forKey: .defaultBeerServingSizeOz)
        try c.encode(kegDepositAmount,           forKey: .kegDepositAmount)
        try c.encode(liquorTargetCostRatio,      forKey: .liquorTargetCostRatio)
        try c.encode(beerTargetCostRatio,        forKey: .beerTargetCostRatio)
        try c.encode(kegTargetCostRatio,         forKey: .kegTargetCostRatio)
        try c.encode(priceRoundingIncrement,     forKey: .priceRoundingIncrement)
    }
}

// MARK: - Happy Hour Configuration
struct HappyHourConfig: Codable {
    var isEnabled: Bool = false               // Master on/off switch
    var manualOverride: Bool? = nil           // true=force on, false=force off, nil=auto
    var schedule: [HappyHourSchedule] = []    // Time ranges for auto-enable
    
    // Check if happy hour should be active right now
    func isActive(currentDate: Date = Date()) -> Bool {
        // Manual override takes precedence
        if let override = manualOverride {
            return override
        }
        
        // If not enabled, definitely not active
        guard isEnabled else { return false }
        
        // Check if current time matches any schedule
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: currentDate)  // 1=Sunday, 7=Saturday
        let hour = calendar.component(.hour, from: currentDate)
        let minute = calendar.component(.minute, from: currentDate)
        let currentMinutes = hour * 60 + minute
        
        for sched in schedule {
            if sched.daysOfWeek.contains(weekday) {
                let startMinutes = sched.startHour * 60 + sched.startMinute
                let endMinutes = sched.endHour * 60 + sched.endMinute
                
                if currentMinutes >= startMinutes && currentMinutes < endMinutes {
                    return true
                }
            }
        }
        
        return false
    }
}

struct HappyHourSchedule: Codable, Identifiable {
    var id: UUID = UUID()
    var daysOfWeek: [Int] = []  // 1=Sunday, 2=Monday, ..., 7=Saturday
    var startHour: Int = 16      // 4pm
    var startMinute: Int = 0
    var endHour: Int = 19        // 7pm
    var endMinute: Int = 0
    
    var displayDays: String {
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return daysOfWeek.sorted().map { dayNames[$0 - 1] }.joined(separator: ", ")
    }
    
    var displayTime: String {
        let start = String(format: "%d:%02d %@", 
                          startHour > 12 ? startHour - 12 : (startHour == 0 ? 12 : startHour),
                          startMinute,
                          startHour >= 12 ? "PM" : "AM")
        let end = String(format: "%d:%02d %@",
                        endHour > 12 ? endHour - 12 : (endHour == 0 ? 12 : endHour),
                        endMinute,
                        endHour >= 12 ? "PM" : "AM")
        return "\(start) - \(end)"
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

    init(id: UUID = UUID(), name: String, createdBy: UUID, ingredients: [RecipeIngredient], basePrice: Decimal? = nil, isPending: Bool = true) {
        self.id = id
        self.name = name
        self.createdBy = createdBy
        self.ingredients = ingredients
        self.isPending = isPending

        // Use provided price, or auto-calculate from ingredients
        if let providedPrice = basePrice {
            self.basePrice = providedPrice
        } else {
            self.basePrice = ingredients.reduce(0) { total, ingredient in
                total + (ingredient.defaultProduct.price * ingredient.servings)
            }
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
    var selectedVariant: SizeVariant? = nil  // Which size was ordered

    init(id: UUID = UUID(), product: Product, qty: Int = 1, selectedVariant: SizeVariant? = nil) {
        self.id = id
        self.product = product
        self.qty = qty
        self.selectedVariant = selectedVariant
    }

    var lineTotal: Decimal {
        let unitPrice = selectedVariant?.price ?? product.price
        return Decimal(qty) * unitPrice
    }
    
    var displayName: String {
        if let variant = selectedVariant {
            return "\(product.name) (\(variant.name) \(variant.sizeOz.plainString())oz)"
        }
        return product.name
    }
    
    var unitPrice: Decimal {
        selectedVariant?.price ?? product.price
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

extension Decimal {
    func rounded(to places: Int) -> Decimal {
        let divisor = pow(10.0, Double(places))
        let rounded = (self as NSDecimalNumber).doubleValue * divisor
        return Decimal(round(rounded) / divisor)
    }
}
