//
//  DefaultOrderSheet.swift
//  BarPOSv2
//
//  Created by Michael Nussbaum on 11/17/25.
//


//
//  DefaultOrderSheet.swift
//  BarPOSv2
//

import SwiftUI

struct DefaultOrderSheet: View {
    @EnvironmentObject var vm: InventoryVM
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCategory: ProductCategory? = nil
    @State private var products: [Product] = []
    @State private var editMode: EditMode = .active
    
    var body: some View {
        VStack(spacing: 0) {
            // Category picker
            Picker("Category", selection: $selectedCategory) {
                Text("All").tag(ProductCategory?.none)
                ForEach(ProductCategory.allCases.filter { $0 != .chips }) { c in
                    Text(c.displayName).tag(ProductCategory?.some(c))
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Description
            Text("This is the default order for all bartenders who haven't customized their layout.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 8)
            
            // Reorderable list
            List {
                ForEach(products) { p in
                    HStack {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                        Text(p.name)
                        Spacer()
                        Text(p.price.currencyString())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onMove { from, to in
                    products.move(fromOffsets: from, toOffset: to)
                }
            }
            .environment(\.editMode, $editMode)
        }
        .navigationTitle("Default Product Order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveDefaultOrder()
                    dismiss()
                }
            }
        }
        .onAppear {
            loadProducts()
        }
        .onChange(of: selectedCategory) { _, _ in
            loadProducts()
        }
    }
    
    private func loadProducts() {
        // Get current default order for this category
        let defaults = vm.defaultProductOrder(category: selectedCategory)
        
        // Get all products for this category
        var allProducts = selectedCategory == nil 
            ? vm.products.filter { $0.category != .chips }
            : vm.products.filter { $0.category == selectedCategory }
        
        // Sort by default order
        allProducts.sort { p1, p2 in
            let idx1 = defaults.firstIndex(of: p1.id) ?? Int.max
            let idx2 = defaults.firstIndex(of: p2.id) ?? Int.max
            return idx1 < idx2
        }
        
        products = allProducts
    }
    
    private func saveDefaultOrder() {
        let productIDs = products.map { $0.id }
        vm.setDefaultProductOrder(category: selectedCategory, productIDs: productIDs)
    }
}
