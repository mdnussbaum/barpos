//
//  BartenderOrdersSheet.swift
//  BarPOSv2
//
//  Created by Michael Nussbaum on 11/17/25.
//


//
//  BartenderOrdersSheet.swift
//  BarPOSv2
//

import SwiftUI

struct BartenderOrdersSheet: View {
    @EnvironmentObject var vm: InventoryVM
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedBartender: Bartender?
    @State private var showingReorderSheet = false
    
    var body: some View {
        List {
            Section {
                Text("View or edit each bartender's custom product ordering. Bartenders who haven't customized use the default order.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Bartenders") {
                ForEach(vm.bartenders, id: \.id) { bartender in
                    Button {
                        selectedBartender = bartender
                        showingReorderSheet = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(bartender.name)
                                    .font(.headline)
                                
                                if vm.hasCustomOrder(bartender: bartender) {
                                    Text("Has custom order")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                } else {
                                    Text("Using default order")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Bartender Orders")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(isPresented: $showingReorderSheet) {
            if let bartender = selectedBartender {
                NavigationStack {
                    BartenderOrderEditSheet(bartender: bartender)
                        .environmentObject(vm)
                }
            }
        }
    }
}

// MARK: - Individual Bartender Order Editor
struct BartenderOrderEditSheet: View {
    @EnvironmentObject var vm: InventoryVM
    @Environment(\.dismiss) private var dismiss
    
    let bartender: Bartender
    
    @State private var selectedCategory: ProductCategory? = nil
    @State private var products: [Product] = []
    @State private var editMode: EditMode = .active
    @State private var showingResetAlert = false
    
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
        .navigationTitle("\(bartender.name)'s Order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveBartenderOrder()
                    dismiss()
                }
            }
            
            ToolbarItemGroup(placement: .bottomBar) {
                Button(role: .destructive) {
                    showingResetAlert = true
                } label: {
                    Label("Reset to Default", systemImage: "arrow.counterclockwise")
                }
                Spacer()
            }
        }
        .alert("Reset to Default?", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                vm.resetBartenderToDefault(bartender: bartender)
                dismiss()
            }
        } message: {
            Text("This will remove \(bartender.name)'s custom order and they will use the default order.")
        }
        .onAppear {
            loadProducts()
        }
        .onChange(of: selectedCategory) { _, _ in
            loadProducts()
        }
    }
    
    private func loadProducts() {
        // Get bartender's custom order or fall back to default
        let order = vm.bartenderProductOrder(bartender: bartender, category: selectedCategory)
        
        // Get all products for this category
        var allProducts = selectedCategory == nil 
            ? vm.products.filter { $0.category != .chips }
            : vm.products.filter { $0.category == selectedCategory }
        
        // Sort by bartender's order
        allProducts.sort { p1, p2 in
            let idx1 = order.firstIndex(of: p1.id) ?? Int.max
            let idx2 = order.firstIndex(of: p2.id) ?? Int.max
            return idx1 < idx2
        }
        
        products = allProducts
    }
    
    private func saveBartenderOrder() {
        let productIDs = products.map { $0.id }
        vm.setBartenderProductOrder(bartender: bartender, category: selectedCategory, productIDs: productIDs)
    }
}

// MARK: - Helper extension
private extension Decimal {
    func currencyString() -> String {
        let ns = self as NSDecimalNumber
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f.string(from: ns) ?? "$\(self)"
    }
}