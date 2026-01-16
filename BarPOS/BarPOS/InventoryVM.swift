import Foundation
import SwiftUI
import Combine

// MARK: - ViewModel
@MainActor
final class InventoryVM: ObservableObject {
    
    // MARK: - Admin lock / Settings
    @Published var isAdminUnlocked: Bool = false { didSet { saveState() } }
    @Published var managerPIN: String = "0420"   { didSet { saveState() } }

    // MARK: - Printer Settings
    @Published var printerSettings: ReceiptSettings = ReceiptSettings() { didSet { saveState() } }
    
    // Staff list for Begin Shift
    @Published var bartenders: [Bartender] = [] { didSet { saveState() } }
    
    // Payments
    @Published var enabledPaymentMethods: Set<PaymentMethod> = [.cash, .card, .other] { didSet { saveState() } }
    @Published var defaultPaymentMethod: PaymentMethod = .cash { didSet { saveState() } }
    
    // Chips (legacy single value still persisted for migration)
    @Published var chipValue: Decimal = 3 { didSet { saveState() } }
    @Published var chipsOutstanding: Int = 0 { didSet { saveState() } }
    
    // New multi-type chip counters (persisted)
    @Published var chipsOutstandingByType: [ChipType: Int] = [.white: 0, .gray: 0, .black: 0] { didSet { saveState() } }
    
    // Which category is currently shown in the right grid
    @Published var selectedCategory: ProductCategory = .cocktails
    
    // Per-bartender ordering map (per-category support)
    @Published var productOrderByBartender: [UUID: [String: [UUID]]] = [:] {
        didSet {
            print("🔵 productOrderByBartender changed: \(productOrderByBartender)")
            saveState()
        }
    }

    // Default product ordering (what new bartenders see)
    @Published var defaultProductOrdering: [String: [UUID]] = [:] { didSet { saveState() } }

    // Custom cocktails per bartender
    @Published var customCocktails: [UUID: [CustomCocktail]] = [:] { didSet { saveState() } }
    
    // Happy Hour Configuration
    @Published var happyHourConfig: HappyHourConfig = HappyHourConfig() { didSet { saveState() } }
    
    // Categories to show in the picker
    var availableCategories: [ProductCategory] {
        let productCats = Set(products.map { $0.category })
        return Array(productCats.union([.chips]))
            .sorted { $0.rawValue < $1.rawValue }
    }
    
    // Products filtered by the selected category (chips handled in the view)
    var filteredProducts: [Product] {
        guard selectedCategory != .chips else { return [] }
        return products.filter { $0.category == selectedCategory }
    }
    
    // MARK: - Chip Pricing (editable + persisted)
    @Published var chipPriceOverrides: [ChipType: Decimal] = [
        .white: 3, .gray: 4, .black: 5
    ] { didSet { saveState() } }
    
    func price(for type: ChipType) -> Decimal {
        chipPriceOverrides[type] ?? defaultChipPrice(type)
    }
    
    func setChipPrice(_ type: ChipType, _ newPrice: Decimal) {
        chipPriceOverrides[type] = newPrice
        saveState()
    }
    
    private func defaultChipPrice(_ type: ChipType) -> Decimal {
        switch type {
        case .white: return 3
        case .gray:  return 4
        case .black: return 5
        }
    }
    
    // MARK: - Catalog
    @Published var products: [Product] = [] { didSet { saveState() } }
    
    // Editable chip prices (persisted)
    @Published var chipPrices: [ChipType: Decimal] = [
        .white: 3, .gray: 4, .black: 5
    ] { didSet { saveState() } }
    
    // MARK: - Unsettled tabs helpers
    var unsettledTabs: [TabTicket] {
        tabs.values
            .filter { !$0.lines.isEmpty }
            .sorted { $0.createdAt < $1.createdAt }
    }
    var hasUnsettledTabs: Bool { !unsettledTabs.isEmpty }
    
    // MARK: - Current bartender convenience
    var currentBartenderID: UUID? { currentShift?.openedBy?.id }
    var currentBartenderName: String? { currentShift?.openedBy?.name }
    
    // MARK: - Tabs / current ticket
    @Published var tabs: [UUID: TabTicket] = [:]
    @Published var activeTabID: UUID? = nil
    @Published var nextTabSequence: Int = 1
    
    var activeTab: TabTicket? { activeTabID.flatMap { tabs[$0] } }
    var activeLines: [OrderLine] { activeTab?.lines ?? [] }
    var subtotalActive: Decimal { activeTab?.subtotal ?? 0 }
    var totalActive: Decimal { activeTab?.total ?? 0 }
    
    // MARK: - Per-shift & global archives
    @Published var closedTabs: [CloseResult] = []
    @Published var allClosedTabs: [CloseResult] = [] { didSet { saveState() } }
    
    // MARK: - Shift state & reports
    @Published var currentShift: ShiftRecord? = nil
    @Published var shiftRecords: [ShiftRecord] = []
    @Published var shiftReports: [ShiftReport] = [] { didSet { saveState() } }
    
    // Drives sheets
    @Published var lastCloseResult: CloseResult? = nil
    @Published var lastShiftReport: ShiftReport? = nil
    
    // MARK: - Init
    init() {
        loadState()
        ChipType.applyOverrides(chipPriceOverrides)
        ensureDefaultBartenders()
        
        print("🟢 InventoryVM initialized")
        print("🟢 Products loaded: \(products.count)")
        print("🟢 ProductOrderByBartender: \(productOrderByBartender)")
    }
    
    func setChipPrice(_ type: ChipType, to newValue: Decimal) {
        chipPriceOverrides[type] = newValue
    }
    
    // MARK: - Admin
    func unlockAdmin(with pin: String) -> Bool {
        let ok = (pin == managerPIN)
        isAdminUnlocked = ok
        return ok
    }
    func lockAdmin() { isAdminUnlocked = false }
    
    // MARK: - Payment selection clamp
    func clampedPaymentSelection(_ selection: Binding<PaymentMethod>) -> Binding<PaymentMethod> {
        Binding(
            get: {
                let current = selection.wrappedValue
                if self.enabledPaymentMethods.contains(current) { return current }
                if self.enabledPaymentMethods.contains(self.defaultPaymentMethod) { return self.defaultPaymentMethod }
                return self.enabledPaymentMethods.first ?? .cash
            },
            set: { newValue in
                if self.enabledPaymentMethods.contains(newValue) {
                    selection.wrappedValue = newValue
                }
            }
        )
    }
    
    func chipPrice(_ type: ChipType) -> Decimal {
        chipPrices[type] ?? type.price
    }
    
    // MARK: - Close active tab
    @discardableResult
    func closeActiveTab(cashTendered: Decimal, method: PaymentMethod = .cash) -> CloseResult? {
        guard let activeID = activeTabID, let ticket = tabs[activeID] else { return nil }
        
        let subtotal = ticket.subtotal
        let total    = ticket.total
        
        if method == .cash, cashTendered < total { return nil }
        
        let snapshots: [LineSnapshot] = ticket.lines.map { line in
            LineSnapshot(
                productName: line.displayName,  // Use displayName which includes variant info
                qty: line.qty,
                unitPrice: line.unitPrice,  // Use unitPrice which handles variant pricing
                lineTotal: line.lineTotal
            )
        }
        
        let actualTendered: Decimal = (method == .cash) ? cashTendered : 0
        let change: Decimal         = (method == .cash) ? (cashTendered - total) : 0
        
        let result = CloseResult(
            id: UUID(),
            tabName: ticket.name,
            lines: snapshots,
            subtotal: subtotal,
            total: total,
            paymentMethod: method,
            cashTendered: actualTendered,
            changeDue: change,
            closedAt: Date(),
            bartenderID: currentShift?.openedBy?.id,
            bartenderName: currentShift?.openedBy?.name
        )

        // Deduct inventory for sold items
        for line in ticket.lines {
            // Check if product has a recipe link (approved cocktail)
            if let recipeID = line.product.recipeID,
               let cocktail = findCocktailByID(recipeID) {
                deductCocktailInventory(for: cocktail, quantity: line.qty)
                print("🍹 Deducted ingredients for approved cocktail: \(line.product.name)")
            }
            // Check if this is a pending custom cocktail (with star)
            else if line.product.name.hasSuffix(" ⭐") {
                let productNameWithoutStar = line.product.name.replacingOccurrences(of: " ⭐", with: "")
                if let cocktail = currentBartenderCocktails().first(where: { $0.name == productNameWithoutStar }) {
                    deductCocktailInventory(for: cocktail, quantity: line.qty)
                    print("🍹 Deducted ingredients for pending cocktail: \(line.product.name)")
                }
            }
            // Regular product
            else {
                deductInventory(for: line.product, quantity: line.qty, variant: line.selectedVariant)
            }
        }

        closedTabs.insert(result, at: 0)
        allClosedTabs.insert(result, at: 0)
        recordCloseIntoShift(result)
        
        tabs.removeValue(forKey: activeID)
        if tabs.isEmpty { createNewTab() } else { activeTabID = tabs.keys.first }
        
        lastCloseResult = result
        saveState()
        return result
    }

    /// Deduct inventory when product is sold
    private func deductInventory(for product: Product, quantity: Int, variant: SizeVariant? = nil) {
        guard let index = products.firstIndex(where: { $0.id == product.id }) else {
            print("⚠️ Product not found for inventory deduction: \(product.name)")
            return
        }

        // Get current stock
        guard let currentStock = products[index].stockQuantity else {
            print("⚠️ No stock quantity set for: \(product.name)")
            return
        }

        // Calculate amount to deduct based on serving size
        // If a variant is provided, use its size; otherwise use product's serving size
        let servingSize: Decimal
        if let variant = variant {
            servingSize = variant.sizeOz
            print("📏 Using variant size: \(variant.name) - \(variant.sizeOz) oz")
        } else {
            servingSize = products[index].servingSize ?? 1.0
        }
        
        let servingsToDeduct = servingSize * Decimal(quantity)
        
        // Convert serving units to stock units if needed
        let amountToDeduct: Decimal
        let servingUnit = variant != nil ? UnitOfMeasure.oz : (products[index].servingUnit ?? products[index].unit)
        
        if servingUnit != products[index].unit {
            // Need conversion (e.g., oz → liter)
            if let conversionFactor = getConversionFactor(from: servingUnit, to: products[index].unit) {
                amountToDeduct = servingsToDeduct * conversionFactor
                print("🔄 Converting \(servingsToDeduct) \(servingUnit.displayName) × \(conversionFactor) = \(amountToDeduct) \(products[index].unit.displayName)")
            } else {
                print("⚠️ No conversion available from \(servingUnit.displayName) to \(products[index].unit.displayName)")
                amountToDeduct = servingsToDeduct
            }
        } else {
            // Same unit or no serving unit specified
            amountToDeduct = servingsToDeduct
        }

        // Deduct from stock
        let newStock = max(0, currentStock - amountToDeduct)
        products[index].stockQuantity = newStock

        let variantInfo = variant != nil ? " (\(variant!.name))" : ""
        print("📦 Inventory deducted: \(product.name)\(variantInfo) - \(servingsToDeduct) \(servingUnit.displayName) (New stock: \(newStock) \(products[index].unit.displayName))")

        // Mark as 86'd if stock hits zero
        if newStock == 0 && !products[index].is86d {
            products[index].is86d = true
            print("🚫 Product auto-86'd (out of stock): \(product.name)")
        }
    }

    // Helper function for unit conversion
    private func getConversionFactor(from: UnitOfMeasure, to: UnitOfMeasure) -> Decimal? {
        if from == to { return 1 }
        
        switch (from, to) {
        case (.oz, .liter): return Decimal(1.0 / 33.814)  // 1 oz = 0.0295735 liters
        case (.liter, .oz): return 33.814
        case (.oz, .gallon): return Decimal(1.0 / 128.0)
        case (.gallon, .oz): return 128
        default: return nil
        }
    }
    var currentShiftGross: Decimal {
        closedTabs.reduce(0) { $0 + $1.total }
    }
    
    private func recordCloseIntoShift(_ result: CloseResult) {
        guard var s = currentShift else { return }
        s.metrics.tabsCount    += 1
        s.metrics.grossSales   += result.total
        s.metrics.netSales     += result.subtotal
        s.metrics.taxCollected += (result.total - result.subtotal)
        
        let kind: PaymentKind = {
            switch result.paymentMethod {
            case .cash:  return .cash
            case .card:  return .card
            case .other: return .other
            }
        }()
        s.metrics.byPayment[kind, default: 0] += result.total
        currentShift = s
    }
    
    // MARK: - Product Sorting with Default + Per-Bartender Ordering
    func sortedProductsForCurrentBartender(category: ProductCategory?) -> [Product] {
        let filtered: [Product] = {
            if let cat = category {
                if cat == .chips { return [] }
                return products.filter { $0.category == cat && !$0.isHidden }
            } else {
                return products.filter { $0.category != .chips && !$0.isHidden }
            }
        }()

        guard let bartender = currentShift?.openedBy else {
            let defaults = defaultProductOrder(category: category)
            if !defaults.isEmpty {
                print("🟡 Using admin default order for category: \(category?.displayName ?? "All")")
                return sortWithOrder(filtered, order: defaults)
            }
            
            print("🟡 Using displayOrder fallback for category: \(category?.displayName ?? "All")")
            return filtered.sorted {
                if $0.displayOrder != $1.displayOrder { return $0.displayOrder < $1.displayOrder }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        let key = category?.rawValue ?? "all"
        if let customOrder = productOrderByBartender[bartender.id]?[key], !customOrder.isEmpty {
            print("🟢 Using \(bartender.name)'s custom order")
            return sortWithOrder(filtered, order: customOrder)
        }
        
        let defaults = defaultProductOrder(category: category)
        if !defaults.isEmpty {
            print("🟡 Using admin default order")
            return sortWithOrder(filtered, order: defaults)
        }
        
        print("🟡 Using displayOrder fallback")
        return filtered.sorted {
            if $0.displayOrder != $1.displayOrder { return $0.displayOrder < $1.displayOrder }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
    
    private func sortWithOrder(_ products: [Product], order: [UUID]) -> [Product] {
        let position = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        return products.sorted { a, b in
            let pa = position[a.id, default: .max]
            let pb = position[b.id, default: .max]
            if pa != pb { return pa < pb }
            if a.displayOrder != b.displayOrder { return a.displayOrder < b.displayOrder }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
    
    // MARK: - Default Product Order Management
    func defaultProductOrder(category: ProductCategory?) -> [UUID] {
        let key = category?.rawValue ?? "all"
        return defaultProductOrdering[key] ?? []
    }
    
    func setDefaultProductOrder(category: ProductCategory?, productIDs: [UUID]) {
        let key = category?.rawValue ?? "all"
        defaultProductOrdering[key] = productIDs
    }
    
    // MARK: - Per-Bartender Order Management
    func bartenderProductOrder(bartender: Bartender, category: ProductCategory?) -> [UUID] {
        let key = category?.rawValue ?? "all"
        
        if let customOrder = productOrderByBartender[bartender.id]?[key] {
            return customOrder
        }
        
        return defaultProductOrder(category: category)
    }
    
    func setBartenderProductOrder(bartender: Bartender, category: ProductCategory?, productIDs: [UUID]) {
        let key = category?.rawValue ?? "all"
        
        if productOrderByBartender[bartender.id] == nil {
            productOrderByBartender[bartender.id] = [:]
        }
        productOrderByBartender[bartender.id]![key] = productIDs
    }
    
    func hasCustomOrder(bartender: Bartender) -> Bool {
        guard let orders = productOrderByBartender[bartender.id] else { return false }
        return !orders.isEmpty
    }
    
    func resetBartenderToDefault(bartender: Bartender) {
        productOrderByBartender[bartender.id] = nil
    }
    
    func setOrderForCurrentBartender(categoryOrderedIDs ids: [UUID]) {
        guard let bartender = currentShift?.openedBy else {
            print("🔴 Cannot save order - no current bartender")
            return
        }
        
        let key = "all"
        
        print("🔵 Saving order for bartender \(bartender.name)")
        print("🔵 Order contains \(ids.count) product IDs")
        
        if productOrderByBartender[bartender.id] == nil {
            productOrderByBartender[bartender.id] = [:]
        }
        productOrderByBartender[bartender.id]![key] = ids
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let savedOrder = self.productOrderByBartender[bartender.id]?[key] {
                print("🟢 Verified saved order: \(savedOrder.count) items")
            } else {
                print("🔴 Order was not saved!")
            }
        }
    }
    
    func productIDs(for category: ProductCategory?) -> [UUID] {
        let list = sortedProductsForCurrentBartender(category: category)
        return list.map(\.id)
    }

    // MARK: - Shift lifecycle
        func beginShift(bartender: Bartender, openingCash: Decimal?) {
            print("🟢 Beginning shift for bartender: \(bartender.name)")
            
            // Check if there are carryover tabs
            let hasCarryoverTabs = !tabs.isEmpty
            print("🟡 Carryover tabs: \(tabs.count)")
            
            currentShift = ShiftRecord(
                startedAt: Date(),
                openedBy: bartender,
                openingCash: openingCash,
                metrics: ShiftMetrics()
            )
            closedTabs.removeAll()
            
            // Only reset tabs if there are NO carryover tabs
            if !hasCarryoverTabs {
                nextTabSequence = 1
                tabs.removeAll()
                activeTabID = nil
                ensureAtLeastOneTab()
            }
            // If there ARE carryover tabs, keep them and don't reset nextTabSequence
            
            saveState()
        }
    
    @discardableResult
        func settleShift(closingCash: Decimal?) -> Bool {
            guard var s = currentShift else { return false }
            guard !hasUnsettledTabs else { return false }
            
            s.endedAt = Date()
            s.closedBy = s.openedBy
            s.closingCash = closingCash
            
            let cashSales = s.metrics.byPayment[.cash] ?? 0
            let expectedCash = (s.openingCash ?? 0) + cashSales
            let overShort = (closingCash ?? 0) - expectedCash
            
            let threshold: Decimal = 5
            let shouldFlag = abs(overShort) > threshold
            let flagNote: String? = shouldFlag
            ? "Over/Short of \(overShort.currencyString()) exceeds threshold"
            : nil
            
            let report = ShiftReport(
                bartenderID: s.openedBy?.id,
                bartenderName: s.openedBy?.name ?? "Unknown",
                startedAt: s.startedAt,
                endedAt: s.endedAt!,
                openingCash: s.openingCash,
                closingCash: closingCash,
                tabsCount: s.metrics.tabsCount,
                grossSales: s.metrics.grossSales,
                netSales: s.metrics.netSales,
                taxCollected: s.metrics.taxCollected,
                cashSales: s.metrics.byPayment[.cash] ?? 0,
                cardSales: s.metrics.byPayment[.card] ?? 0,
                otherSales: s.metrics.byPayment[.other] ?? 0,
                expectedCash: expectedCash,
                overShort: overShort,
                tickets: closedTabs,
                flagged: shouldFlag,
                flagNote: flagNote
            )
            
            shiftRecords.insert(s, at: 0)
            shiftReports.insert(report, at: 0)
            lastShiftReport = report
            
            currentShift = nil
            closedTabs.removeAll()
            nextTabSequence = 1
            tabs.removeAll()
            activeTabID = nil
            
            saveState()
            return true
        }
        
        // MARK: - Carry Over & Close All
    // Close all tabs with items (don't carry over)
        func closeAllUnsettledTabs() {
            for tab in unsettledTabs {
                // Switch to this tab and close it with $0 "other" payment
                activeTabID = tab.id
                _ = closeActiveTab(cashTendered: 0, method: .other)
            }
        }
        
        // Settle shift but keep tabs for next shift
        @discardableResult
        func settleShiftWithCarryOver(closingCash: Decimal?) -> Bool {
            guard var s = currentShift else { return false }
            // Don't check for unsettled tabs - we're carrying them over
            
            s.endedAt = Date()
            s.closedBy = s.openedBy
            s.closingCash = closingCash
            
            let cashSales = s.metrics.byPayment[.cash] ?? 0
            let expectedCash = (s.openingCash ?? 0) + cashSales
            let overShort = (closingCash ?? 0) - expectedCash
            
            let threshold: Decimal = 5
            let shouldFlag = abs(overShort) > threshold
            let flagNote: String? = shouldFlag
                ? "Over/Short of \(overShort.currencyString()) exceeds threshold. \(tabs.count) tab(s) carried over."
                : "\(tabs.count) tab(s) carried over to next shift."
            
            let report = ShiftReport(
                bartenderID: s.openedBy?.id,
                bartenderName: s.openedBy?.name ?? "Unknown",
                startedAt: s.startedAt,
                endedAt: s.endedAt!,
                openingCash: s.openingCash,
                closingCash: closingCash,
                tabsCount: s.metrics.tabsCount,
                grossSales: s.metrics.grossSales,
                netSales: s.metrics.netSales,
                taxCollected: s.metrics.taxCollected,
                cashSales: cashSales,
                cardSales: s.metrics.byPayment[.card] ?? 0,
                otherSales: s.metrics.byPayment[.other] ?? 0,
                expectedCash: expectedCash,
                overShort: overShort,
                tickets: closedTabs,
                flagged: shouldFlag,
                flagNote: flagNote
            )
            
            shiftRecords.insert(s, at: 0)
            shiftReports.insert(report, at: 0)
            lastShiftReport = report
            
            // Clear shift but KEEP tabs for carryover
                        currentShift = nil
                        closedTabs.removeAll()
                        
                        // Clean up: Remove any empty tabs before carryover
                        let emptyTabIDs = tabs.filter { $0.value.lines.isEmpty }.map { $0.key }
                        for id in emptyTabIDs {
                            tabs.removeValue(forKey: id)
                        }
                        
                        // If all tabs were empty, reset everything
                        if tabs.isEmpty {
                            nextTabSequence = 1
                            activeTabID = nil
                        }
                        
                        saveState()
                        return true
                    }
    // MARK: - Chips by type
    func chipOutstanding(_ type: ChipType) -> Int {
        chipsOutstandingByType[type, default: 0]
    }
    
    func addChipSold(_ type: ChipType, count: Int = 1) {
            guard count > 0 else { return }
            let chipID = UUID(uuidString: "10000000-0000-0000-0000-00000000000\(type == .white ? "1" : type == .gray ? "2" : "3")")!
            let p = Product(
                id: chipID,
                name: "\(type.displayName) Chip Sold",
                category: .misc,
                price: price(for: type)
            )
            for _ in 0..<count { addLine(product: p) }
            chipsOutstandingByType[type, default: 0] += count
            saveState()
        }
        
        func addChipRedeemed(_ type: ChipType, count: Int = 1) {
            guard count > 0 else { return }
            let chipID = UUID(uuidString: "20000000-0000-0000-0000-00000000000\(type == .white ? "1" : type == .gray ? "2" : "3")")!
            let p = Product(
                id: chipID,
                name: "\(type.displayName) Chip Redeemed",
                category: .misc,
                price: (0 as Decimal) - price(for: type)
            )
            for _ in 0..<count { addLine(product: p) }
            let cur = chipsOutstandingByType[type, default: 0]
            chipsOutstandingByType[type] = max(0, cur - count)
            saveState()
        }
    // MARK: - Staff Management
    func addBartender(name: String, pin: String) {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return }
            
            let bartender = Bartender(name: trimmed, pin: pin)
            bartenders.append(bartender)
        }

    func updateBartender(_ bartender: Bartender) {
        guard let index = bartenders.firstIndex(where: { $0.id == bartender.id }) else { return }
        bartenders[index] = bartender
    }
    // Validate bartender PIN
        func validateBartenderPIN(_ bartender: Bartender, pin: String) -> Bool {
            guard let storedPIN = bartender.pin else { return false }
            return storedPIN == pin
        }

        // Change bartender's PIN
        func changeBartenderPIN(bartenderID: UUID, newPIN: String) {
            guard let index = bartenders.firstIndex(where: { $0.id == bartenderID }) else { return }
            bartenders[index].pin = newPIN
        }

    func disableBartender(_ bartender: Bartender) {
        guard let index = bartenders.firstIndex(where: { $0.id == bartender.id }) else { return }
        bartenders[index].isActive = false
    }

    func enableBartender(_ bartender: Bartender) {
        guard let index = bartenders.firstIndex(where: { $0.id == bartender.id }) else { return }
        bartenders[index].isActive = true
    }

    // Update this existing computed property to only show active bartenders
    var activeBartenders: [Bartender] {
        bartenders.filter { $0.isActive }
    }
    
    // MARK: - Staff seed
    func ensureDefaultBartenders() {
        if bartenders.isEmpty {
            bartenders = [
                Bartender(id: UUID(), name: "TEST", pin: "0000"),  // Test bartender with easy PIN
                Bartender(id: UUID(), name: "Alex"),
                Bartender(id: UUID(), name: "Sam"),
                Bartender(id: UUID(), name: "Jordan")
            ]
        }
    }

    // MARK: - Custom Cocktails
    func addCustomCocktail(_ cocktail: CustomCocktail) {
        guard let bartenderID = currentShift?.openedBy?.id else { return }

        if customCocktails[bartenderID] == nil {
            customCocktails[bartenderID] = []
        }
        customCocktails[bartenderID]?.append(cocktail)
        print("✅ Custom cocktail added: \(cocktail.name) for bartender \(bartenderID)")
    }

    func deleteCustomCocktail(_ cocktail: CustomCocktail) {
        guard let bartenderID = currentShift?.openedBy?.id else { return }
        customCocktails[bartenderID]?.removeAll { $0.id == cocktail.id }
    }

    func currentBartenderCocktails() -> [CustomCocktail] {
        guard let bartenderID = currentShift?.openedBy?.id else { return [] }
        return customCocktails[bartenderID]?.filter { $0.isPending } ?? []
    }
    
    // Find a cocktail by ID across all bartenders (for approved cocktails)
    private func findCocktailByID(_ recipeID: UUID) -> CustomCocktail? {
        for cocktails in customCocktails.values {
            if let cocktail = cocktails.first(where: { $0.id == recipeID }) {
                return cocktail
            }
        }
        return nil
    }

    // Get all pending cocktails across all bartenders (for admin)
    func allPendingCocktails() -> [CustomCocktail] {
        customCocktails.values.flatMap { $0 }.filter { $0.isPending }
    }

    // Approve a cocktail - creates a real product
    func approveCocktail(_ cocktail: CustomCocktail, approvedBy: UUID) {
        // Create a real product from the recipe with recipeID link
        var newProduct = Product(
            name: cocktail.name,
            category: cocktail.category,
            price: cocktail.basePrice
        )
        
        // Link this product to its recipe for inventory deduction
        newProduct.recipeID = cocktail.id
        
        products.append(newProduct)

        // Mark cocktail as approved (keep for inventory tracking)
        if let bartenderID = customCocktails.first(where: { $0.value.contains(where: { $0.id == cocktail.id }) })?.key,
           let index = customCocktails[bartenderID]?.firstIndex(where: { $0.id == cocktail.id }) {
            customCocktails[bartenderID]?[index].isPending = false
            customCocktails[bartenderID]?[index].approvedBy = approvedBy
            customCocktails[bartenderID]?[index].approvedAt = Date()
        }

        print("✅ Cocktail approved: \(cocktail.name) → Product added with recipe link")
    }

    func rejectCocktail(_ cocktail: CustomCocktail) {
        // Find and remove from all bartenders
        for bartenderID in customCocktails.keys {
            customCocktails[bartenderID]?.removeAll { $0.id == cocktail.id }
        }
        print("❌ Cocktail rejected: \(cocktail.name)")
    }

    // Deduct inventory for recipe ingredients with selected variable products
    func deductRecipeInventory(for cocktail: CustomCocktail, quantity: Int, selectedIngredients: [UUID: Product]) {
        for ingredient in cocktail.ingredients {
            let product = ingredient.isVariable ? (selectedIngredients[ingredient.id] ?? ingredient.defaultProduct) : ingredient.defaultProduct
            let totalServings = ingredient.servings * Decimal(quantity)
            deductInventory(for: product, quantity: Int((totalServings as NSDecimalNumber).doubleValue))
        }
    }

    // Deduct inventory for custom cocktail ingredients
    private func deductCocktailInventory(for cocktail: CustomCocktail, quantity: Int) {
        for ingredient in cocktail.ingredients {
            deductInventory(for: ingredient.defaultProduct, quantity: Int((ingredient.servings * Decimal(quantity) as NSDecimalNumber).doubleValue))
        }
    }

    func toggle86d(_ product: Product) {
        guard let index = products.firstIndex(where: { $0.id == product.id }) else { return }
        products[index].is86d.toggle()
    }
    
    // Get effective price for product (HH price if active, otherwise regular)
    func effectivePrice(for product: Product) -> Decimal {
        if happyHourConfig.isActive(),
           let hhPrice = product.happyHourPrice {
            return hhPrice
        }
        return product.price
    }
    
    // Check if happy hour is currently active
    func isHappyHourActive() -> Bool {
        return happyHourConfig.isActive()
    }
    
    // MARK: - Persistence
    struct PersistedState: Codable {
        var products: [Product]
        var managerPIN: String
        var isAdminUnlocked: Bool
        var enabledPaymentMethods: Set<PaymentMethod>
        var defaultPaymentMethod: PaymentMethod
        var chipValue: Decimal?
        var chipsOutstanding: Int?
        var chipsOutstandingByType: [ChipType: Int]
        var chipPriceOverrides: [ChipType: Decimal]?
        var bartenders: [Bartender]
        var allClosedTabs: [CloseResult]
        var shiftReports: [ShiftReport]
        var productOrderByBartender: [UUID: [String: [UUID]]]
        var defaultProductOrdering: [String: [UUID]]
        var customCocktails: [UUID: [CustomCocktail]]
        var printerSettings: ReceiptSettings?
        var happyHourConfig: HappyHourConfig?
        var schemaVersion: Int?   // Added schemaVersion property
    }
    
    private var stateURL: URL { Persistence.fileURL("state.json") }
    
    func saveState() {
        let snapshot = PersistedState(
            products: products,
            managerPIN: managerPIN,
            isAdminUnlocked: isAdminUnlocked,
            enabledPaymentMethods: enabledPaymentMethods,
            defaultPaymentMethod: defaultPaymentMethod,
            chipValue: chipValue,
            chipsOutstanding: chipsOutstanding,
            chipsOutstandingByType: chipsOutstandingByType,
            chipPriceOverrides: chipPriceOverrides,
            bartenders: bartenders,
            allClosedTabs: allClosedTabs,
            shiftReports: shiftReports,
            productOrderByBartender: productOrderByBartender,
            defaultProductOrdering: defaultProductOrdering,
            customCocktails: customCocktails,
            printerSettings: printerSettings,
            happyHourConfig: happyHourConfig,
            schemaVersion: 2
        )
        
        do {
            try Persistence.saveJSON(snapshot, to: stateURL)
            print("✅ State saved successfully")
        } catch {
            print("⚠️ saveState error:", error)
        }
    }
    
    func applyState(_ s: PersistedState) {
        managerPIN = s.managerPIN
        isAdminUnlocked = s.isAdminUnlocked
        enabledPaymentMethods = s.enabledPaymentMethods
        defaultPaymentMethod = s.defaultPaymentMethod

        if let legacyValue = s.chipValue { chipValue = legacyValue }
        if let legacyOutstanding = s.chipsOutstanding { chipsOutstanding = legacyOutstanding }

        chipsOutstandingByType = s.chipsOutstandingByType
        chipPriceOverrides = s.chipPriceOverrides ?? [.white: 3, .gray: 4, .black: 5]

        bartenders = s.bartenders
        allClosedTabs = s.allClosedTabs
        shiftReports = s.shiftReports
        products = s.products

        productOrderByBartender = s.productOrderByBartender
        defaultProductOrdering = s.defaultProductOrdering
        customCocktails = s.customCocktails
        printerSettings = s.printerSettings ?? ReceiptSettings()
        happyHourConfig = s.happyHourConfig ?? HappyHourConfig()

        print("✅ State applied successfully")
    }
    
    func loadState() {
        do {
            let s = try Persistence.loadJSON(from: stateURL, as: PersistedState.self)
            applyState(s)
            print("✅ State loaded from disk")
        } catch {
            print("⚠️ loadState error:", error)
            ensureDefaultBartenders()
            chipPriceOverrides = [.white: 3, .gray: 4, .black: 5]
            products = []
            productOrderByBartender = [:]
            defaultProductOrdering = [:]
            customCocktails = [:]
        }
    }
    
    @discardableResult
    func exportBackup() -> URL? {
        let snap = PersistedState(
            products: products,
            managerPIN: managerPIN,
            isAdminUnlocked: isAdminUnlocked,
            enabledPaymentMethods: enabledPaymentMethods,
            defaultPaymentMethod: defaultPaymentMethod,
            chipValue: chipValue,
            chipsOutstanding: chipsOutstanding,
            chipsOutstandingByType: chipsOutstandingByType,
            chipPriceOverrides: chipPriceOverrides,
            bartenders: bartenders,
            allClosedTabs: allClosedTabs,
            shiftReports: shiftReports,
            productOrderByBartender: productOrderByBartender,
            defaultProductOrdering: defaultProductOrdering,
            customCocktails: customCocktails,
            printerSettings: printerSettings,
            happyHourConfig: happyHourConfig,
            schemaVersion: 2
        )
        let url = Persistence.fileURL("backup-\(Int(Date().timeIntervalSince1970)).json")
        do {
            try Persistence.saveJSON(snap, to: url)
            return url
        } catch {
            print("⚠️ exportBackup error:", error)
            return nil
        }
    }
    
    @discardableResult
    func importBackup(from url: URL) -> Bool {
        do {
            let s = try Persistence.loadJSON(from: url, as: PersistedState.self)
            applyState(s)
            saveState()
            return true
        } catch {
            print("⚠️ importBackup error:", error)
            return false
        }
    }
    
    var reportBartenders: [String] {
        Array(Set(shiftReports.map { $0.bartenderName })).sorted()
    }
}

