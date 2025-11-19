import Foundation

// MARK: - DemoSeeder Back-Compat
extension InventoryVM {
    /// Backwards-compat for older DemoSeeder code paths.
    func setProducts(_ items: [Product]) {
        self.products = items
    }
}
