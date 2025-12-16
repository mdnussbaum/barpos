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
                        HStack(spacing: 12) {
                            // Status indicator circle
                            Circle()
                                .fill(stockColor(product))
                                .frame(width: 12, height: 12)
                            
                            // Product info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                Text(stockInfoText(product))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            // Status badge
                            Text(stockStatusText(product))
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(stockColor(product).opacity(0.2))
                                .foregroundStyle(stockColor(product))
                                .clipShape(Capsule())
                            
                            // Quick action buttons
                            Button {
                                selectedProduct = product
                                stockAdjustmentAmount = ""
                                showingAddStock = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.blue)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                selectedProduct = product
                                stockAdjustmentAmount = ""
                                showingRemoveStock = true
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
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
                    .environmentObject(vm)  // ADD THIS LINE
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
                    .environmentObject(vm)  // ADD THIS LINE
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
        let stock = product.stockQuantity ?? 0

        // If we have a case size, show cases + remainder
        if let caseSize = product.caseSize, caseSize > 0 {
            let stockInt = (stock as NSDecimalNumber).intValue
            let cases = stockInt / caseSize
            let remainder = stockInt % caseSize

            // Use servingUnit for remainder, fallback to unit
            let individualUnit = (product.servingUnit ?? product.unit).displayName.lowercased()
            let remainderLabel = remainder == 1 ? individualUnit : individualUnit + "s"

            let unitStr = product.unit.displayName.lowercased()
            let casesLabel = cases == 1 ? unitStr : unitStr + "s"

            var result: String
            if remainder == 0 {
                result = "\(cases) \(casesLabel)"
            } else {
                result = "\(cases) \(casesLabel), \(remainder) \(remainderLabel)"
            }

            // Add par level if available
            if let par = product.parLevel {
                let parInt = (par as NSDecimalNumber).intValue
                let parCases = parInt / caseSize
                let parRemainder = parInt % caseSize

                let parIndividualUnit = (product.servingUnit ?? product.unit).displayName.lowercased()
                let parRemainderLabel = parRemainder == 1 ? parIndividualUnit : parIndividualUnit + "s"

                let parCasesLabel = parCases == 1 ? unitStr : unitStr + "s"

                if parRemainder == 0 {
                    result += " (Par: \(parCases) \(parCasesLabel))"
                } else {
                    result += " (Par: \(parCases) \(parCasesLabel), \(parRemainder) \(parRemainderLabel))"
                }
            }

            return result
        } else {
            // No case size - show normal stock
            let stockStr = stock.plainString()
            let unitStr = product.unit.displayName.lowercased()
            let pluralUnit = stock == 1 ? unitStr : unitStr + "s"

            if let par = product.parLevel {
                return "\(stockStr) \(pluralUnit) (Par: \(par.plainString()))"
            } else {
                return "\(stockStr) \(pluralUnit)"
            }
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

                    Text("Current Stock: \(product.stockDisplayString ?? (product.stockQuantity?.plainString() ?? "0"))")
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
