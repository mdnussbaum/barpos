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

        // Define a few starter products across all categories
        let items: [Product] = [
            // Cocktails
            Product(name: "Gin & Tonic",        category: ProductCategory.cocktails, price: 8),
            Product(name: "Margarita",          category: ProductCategory.cocktails, price: 10),
            Product(name: "Old Fashioned",      category: ProductCategory.cocktails, price: 12),

            // Beer
            Product(name: "Lager Pint",         category: ProductCategory.beer, price: 6),
            Product(name: "IPA Pint",           category: ProductCategory.beer, price: 7),
            Product(name: "Stout Pint",         category: ProductCategory.beer, price: 7.5),

            // Wine
            Product(name: "House Red (Glass)",  category: ProductCategory.wine, price: 9),
            Product(name: "House White (Glass)",category: ProductCategory.wine, price: 9),

            // Shots
            Product(name: "Whiskey Shot",       category: ProductCategory.shots, price: 6),
            Product(name: "Tequila Shot",       category: ProductCategory.shots, price: 6),

            // Non-Alcoholic
            Product(name: "Soda",               category: ProductCategory.na, price: 3),
            Product(name: "Water Bottle",       category: ProductCategory.na, price: 2),

            // Food
            Product(name: "Pretzel",            category: ProductCategory.food, price: 5),
            Product(name: "Nachos",             category: ProductCategory.food, price: 9),

            // Misc
            Product(name: "Merch Sticker",      category: ProductCategory.misc, price: 2)
        ]

        vm.products = items
        vm.ensureAtLeastOneTab()
    }
}
