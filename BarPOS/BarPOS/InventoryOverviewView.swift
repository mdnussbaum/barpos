import SwiftUI

struct InventoryOverviewView: View {
    @EnvironmentObject var vm: InventoryVM
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""
    @State private var selectedCategory: ProductCategory?
    @State private var sortOption: SortOption = .stockLevel
    @State private var showingAddStock: Bool = false
    @State private var showingRemoveStock: Bool = false
    @State private var selectedProduct: Product?
    @State private var stockAdjustmentAmount: String = ""

    enum SortOption: String, CaseIterable {
        case stockLevel = "Stock Level"
        case name = "Name"
        case category = "Category"

        var id: String { rawValue }
    }

    private var filteredAndSortedProducts: [Product] {
        var products = vm.products

        // Filter by search
        if !searchText.isEmpty {
            products = products.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Filter by category
        if let category = selectedCategory {
            products = products.filter { $0.category == category }
        }

        // Sort
        switch sortOption {
        case .stockLevel:
            products.sort { p1, p2 in
                let level1 = stockLevel(p1)
                let level2 = stockLevel(p2)
                return level1 < level2
            }
        case .name:
            products.sort { $0.name < $1.name }
        case .category:
            products.sort {
                if $0.category != $1.category {
                    return $0.category.rawValue < $1.category.rawValue
                }
                return $0.name < $1.name
            }
        }

        return products
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Filter Picker
                Picker("Category", selection: $selectedCategory) {
                    Text("All").tag(nil as ProductCategory?)
                    ForEach(ProductCategory.allCases) { category in
                        Text(category.displayName).tag(category as ProductCategory?)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Product List
                List {
                    ForEach(filteredAndSortedProducts) { product in
                        ProductRow(
                            product: product,
                            stockLevel: stockLevel(product),
                            stockColor: stockColor(product),
                            stockStatusText: stockStatusText(product),
                            onAddStock: {
                                selectedProduct = product
                                stockAdjustmentAmount = ""
                                showingAddStock = true
                            },
                            onRemoveStock: {
                                selectedProduct = product
                                stockAdjustmentAmount = ""
                                showingRemoveStock = true
                            }
                        )
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Inventory Overview")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search products")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Picker("Sort By", selection: $sortOption) {
                            ForEach(SortOption.allCases, id: \.id) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                }
            }
            .sheet(isPresented: $showingAddStock) {
                if let product = selectedProduct {
                    StockAdjustmentSheet(
                        product: product,
                        isAdding: true,
                        amount: $stockAdjustmentAmount,
                        onSave: { amount in
                            adjustStock(product: product, amount: amount, isAdding: true)
                        }
                    )
                }
            }
            .sheet(isPresented: $showingRemoveStock) {
                if let product = selectedProduct {
                    StockAdjustmentSheet(
                        product: product,
                        isAdding: false,
                        amount: $stockAdjustmentAmount,
                        onSave: { amount in
                            adjustStock(product: product, amount: amount, isAdding: false)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Helper Functions

    /// Determine stock level (0=critical, 1=low, 2=good, 3=no par)
    private func stockLevel(_ product: Product) -> Int {
        guard let stock = product.stockQuantity,
              let par = product.parLevel else { return 3 }

        if stock < par * 0.5 { return 0 } // Critical
        if stock < par { return 1 } // Low
        return 2 // Good
    }

    /// Get stock status color
    private func stockColor(_ product: Product) -> Color {
        switch stockLevel(product) {
        case 0: return .red
        case 1: return .orange
        case 2: return .green
        default: return .gray
        }
    }

    /// Get stock status text
    private func stockStatusText(_ product: Product) -> String {
        switch stockLevel(product) {
        case 0: return "Critical"
        case 1: return "Low"
        case 2: return "Good"
        default: return "No Par"
        }
    }

    /// Format stock info text
    private func stockInfoText(_ product: Product) -> String {
        let stockStr = product.stockQuantity?.plainString() ?? "0"
        let unitStr = product.unit.displayName.lowercased()
        let pluralUnit = (product.stockQuantity ?? 0) == 1 ? unitStr : unitStr + "s"

        if let par = product.parLevel {
            return "\(stockStr) \(pluralUnit) (Par: \(par.plainString()))"
        } else {
            return "\(stockStr) \(pluralUnit)"
        }
    }

    /// Adjust stock for a product
    private func adjustStock(product: Product, amount: Decimal, isAdding: Bool) {
        guard let index = vm.products.firstIndex(where: { $0.id == product.id }) else { return }

        let currentStock = vm.products[index].stockQuantity ?? 0
        let newStock = isAdding ? currentStock + amount : currentStock - amount

        vm.products[index].stockQuantity = max(0, newStock)

        showingAddStock = false
        showingRemoveStock = false
        selectedProduct = nil
    }
}

// MARK: - Product Row

struct ProductRow: View {
    let product: Product
    let stockLevel: Int
    let stockColor: Color
    let stockStatusText: String
    let onAddStock: () -> Void
    let onRemoveStock: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Status Indicator Circle
            Circle()
                .fill(stockColor)
                .frame(width: 12, height: 12)

            // Product Info
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)

                Text(stockInfoText())
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Status Badge
                Text(stockStatusText)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(stockColor.opacity(0.2))
                    .foregroundColor(stockColor)
                    .cornerRadius(4)
            }

            Spacer()

            // Action Buttons
            HStack(spacing: 16) {
                Button(action: onRemoveStock) {
                    Image(systemName: "minus.circle")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)

                Button(action: onAddStock) {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func stockInfoText() -> String {
        let stockStr = product.stockQuantity?.plainString() ?? "0"
        let unitStr = product.unit.displayName.lowercased()
        let pluralUnit = (product.stockQuantity ?? 0) == 1 ? unitStr : unitStr + "s"

        if let par = product.parLevel {
            return "\(stockStr) \(pluralUnit) (Par: \(par.plainString()))"
        } else {
            return "\(stockStr) \(pluralUnit)"
        }
    }
}

// MARK: - Stock Adjustment Sheet

struct StockAdjustmentSheet: View {
    let product: Product
    let isAdding: Bool
    @Binding var amount: String
    let onSave: (Decimal) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(product.name)
                        .font(.headline)

                    Text("Current Stock: \(product.stockQuantity?.plainString() ?? "0") \(product.unit.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Section {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                } header: {
                    Text(isAdding ? "Add Stock" : "Remove Stock")
                }
            }
            .navigationTitle(isAdding ? "Add Stock" : "Remove Stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        if let decimalAmount = Decimal(string: amount), decimalAmount > 0 {
                            onSave(decimalAmount)
                            dismiss()
                        }
                    }
                    .disabled(Decimal(string: amount) == nil || Decimal(string: amount) ?? 0 <= 0)
                }
            }
        }
    }
}

// MARK: - Decimal Extension

extension Decimal {
    func plainString() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: self as NSDecimalNumber) ?? "0"
    }
}
