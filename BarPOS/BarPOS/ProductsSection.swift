import SwiftUI

struct ProductsSection: View {
    @EnvironmentObject var vm: InventoryVM
    @State private var selectedCategory: ProductCategory = .beer
    var onTap: (Product) -> Void
    
    private var categories: [ProductCategory] { ProductCategory.allCases }
    private var filtered: [Product] {
        vm.products.filter { $0.category == selectedCategory }
    }
    
    private let grid = [GridItem(.adaptive(minimum: 120), spacing: 12)]
    
    var body: some View {
        VStack(spacing: 12) {
            // Category chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories) { cat in
                        Button {
                            selectedCategory = cat
                        } label: {
                            Text(cat.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(selectedCategory == cat ? .blue.opacity(0.2) : .gray.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Divider()
            
            // Product grid
            ScrollView {
                LazyVGrid(columns: grid, spacing: 12) {
                    ForEach(filtered) { product in
                        Button {
                            onTap(product)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(product.name)
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(product.price.currencyString())
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
    }
}
