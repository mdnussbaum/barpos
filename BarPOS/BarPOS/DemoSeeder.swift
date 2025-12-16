import Foundation

@MainActor
struct DemoSeeder {
    /// Seeds a small demo catalog if there are no products yet,
    /// and ensures at least one tab exists for testing/demo purposes.
    static func seed(into vm: InventoryVM) {
        // Avoid overwriting user data
        guard vm.products.isEmpty else {
            vm.ensureAtLeastOneTab()
            return
        }

        // Define realistic test products with inventory tracking
        let items: [Product] = [
            // BEER
            Product(
                name: "Bud Light Can",
                category: .beer,
                price: 3.00,
                displayOrder: 0,
                stockQuantity: 136,
                parLevel: 288,
                unit: .case_,
                servingSize: 1,
                servingUnit: .can,
                tier: .none,
                isGunItem: false,
                cost: 0.95,
                supplier: "Distributor",
                supplierSKU: "BUD-CAN",
                caseSize: 24,
                canBeIngredient: false
            ),
            Product(
                name: "Miller Lite Bottle",
                category: .beer,
                price: 4.00,
                displayOrder: 1,
                stockQuantity: 48,
                parLevel: 72,
                unit: .bottle,
                servingSize: 1,
                tier: .none,
                cost: 1.10,
                caseSize: 24,
                canBeIngredient: false
            ),
            Product(
                name: "Blue Moon",
                category: .beer,
                price: 5.00,
                displayOrder: 2,
                stockQuantity: 24,
                parLevel: 48,
                unit: .bottle,
                servingSize: 1,
                tier: .none,
                cost: 1.75,
                caseSize: 24,
                canBeIngredient: false
            ),
            
            // LIQUOR - WELL
            Product(
                name: "Well Vodka",
                category: .liquor,
                price: 7.00,
                displayOrder: 10,
                stockQuantity: 3,
                parLevel: 6,
                unit: .liter,
                servingSize: 1.125,
                servingUnit: .oz,
                tier: .well,
                cost: 13.50,
                canBeIngredient: true
            ),
            Product(
                name: "Well Whiskey",
                category: .liquor,
                price: 7.00,
                displayOrder: 11,
                stockQuantity: 2,
                parLevel: 4,
                unit: .liter,
                servingSize: 1.125,
                servingUnit: .oz,
                tier: .well,
                cost: 14.00,
                canBeIngredient: true
            ),
            Product(
                name: "Well Rum",
                category: .liquor,
                price: 7.00,
                displayOrder: 12,
                stockQuantity: 2,
                parLevel: 4,
                unit: .liter,
                servingSize: 1.125,
                servingUnit: .oz,
                tier: .well,
                cost: 13.00,
                canBeIngredient: true
            ),
            Product(
                name: "Well Tequila",
                category: .liquor,
                price: 7.00,
                displayOrder: 13,
                stockQuantity: 2,
                parLevel: 4,
                unit: .liter,
                servingSize: 1.125,
                servingUnit: .oz,
                tier: .well,
                cost: 15.00,
                canBeIngredient: true
            ),
            
            // LIQUOR - CALL
            Product(
                name: "Tito's Vodka",
                category: .liquor,
                price: 9.00,
                displayOrder: 20,
                stockQuantity: 4,
                parLevel: 6,
                unit: .liter,
                servingSize: 1.125,
                servingUnit: .oz,
                tier: .call,
                cost: 22.00,
                canBeIngredient: true
            ),
            Product(
                name: "Jameson",
                category: .liquor,
                price: 10.00,
                displayOrder: 21,
                stockQuantity: 2,
                parLevel: 4,
                unit: .liter,
                servingSize: 1.125,
                servingUnit: .oz,
                tier: .call,
                cost: 28.00,
                canBeIngredient: true
            ),
            Product(
                name: "Fireball",
                category: .liquor,
                price: 8.00,
                displayOrder: 22,
                stockQuantity: 2,
                parLevel: 4,
                unit: .liter,
                servingSize: 1.125,
                servingUnit: .oz,
                tier: .call,
                cost: 18.00,
                canBeIngredient: true
            ),
            
            // GUN ITEMS / MIXERS
            Product(
                name: "Sour Mix",
                category: .na,
                price: 0.00,
                displayOrder: 30,
                stockQuantity: 640,
                parLevel: 320,
                unit: .oz,
                servingSize: 1,
                tier: .none,
                isGunItem: true,
                cost: 0.25,
                canBeIngredient: true
            ),
            Product(
                name: "Cranberry Juice",
                category: .na,
                price: 0.00,
                displayOrder: 31,
                stockQuantity: 800,
                parLevel: 400,
                unit: .oz,
                servingSize: 1,
                tier: .none,
                isGunItem: true,
                cost: 0.20,
                canBeIngredient: true
            ),
            Product(
                name: "Orange Juice",
                category: .na,
                price: 0.00,
                displayOrder: 32,
                stockQuantity: 800,
                parLevel: 400,
                unit: .oz,
                servingSize: 1,
                tier: .none,
                isGunItem: true,
                cost: 0.22,
                canBeIngredient: true
            ),
            Product(
                name: "Tonic Water",
                category: .na,
                price: 0.00,
                displayOrder: 33,
                stockQuantity: 800,
                parLevel: 400,
                unit: .oz,
                servingSize: 1,
                tier: .none,
                isGunItem: true,
                cost: 0.18,
                canBeIngredient: true
            ),
            Product(
                name: "Lime Juice",
                category: .na,
                price: 0.00,
                displayOrder: 34,
                stockQuantity: 640,
                parLevel: 320,
                unit: .oz,
                servingSize: 1,
                tier: .none,
                isGunItem: true,
                cost: 0.30,
                canBeIngredient: true
            ),
            
            // WINE
            Product(
                name: "House Red Wine",
                category: .wine,
                price: 8.00,
                displayOrder: 40,
                stockQuantity: 6,
                parLevel: 12,
                unit: .bottle,
                servingSize: 5,
                servingUnit: .oz,
                tier: .well,
                cost: 6.00,
                canBeIngredient: false
            ),
            Product(
                name: "House White Wine",
                category: .wine,
                price: 8.00,
                displayOrder: 41,
                stockQuantity: 6,
                parLevel: 12,
                unit: .bottle,
                servingSize: 5,
                servingUnit: .oz,
                tier: .well,
                cost: 6.00,
                canBeIngredient: false
            )
        ]

        vm.products = items
        vm.ensureAtLeastOneTab()
        
        print("✅ Demo products seeded: \(items.count) products with inventory tracking")
    }
}
