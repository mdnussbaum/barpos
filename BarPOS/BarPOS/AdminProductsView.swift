//
//  AdminProductsView.swift
//  BarPOSv2
//

import SwiftUI

struct AdminProductsView: View {
    @EnvironmentObject var vm: InventoryVM

    // Filters / UI state
    @State private var query: String = ""
    @State private var category: ProductCategory? = nil
    @State private var sort: Sort = .order      // ← default to saved order
    @State private var editMode: EditMode = .inactive

    // Sheet state
    @State private var showingEditor = false
    @State private var draft: Product = Product(name: "", category: .misc, price: 0)
    @State private var isNew = true
    @State private var showingDefaultOrderSheet = false
    @State private var showingBartenderOrdersSheet = false

    var body: some View {
        List {
            // Filters
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                    TextField("Search products", text: $query)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                }
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterPill(title: "All", isSelected: category == nil) { category = nil }
                        ForEach(ProductCategory.allCases) { c in
                            FilterPill(title: c.displayName, isSelected: category == c) { category = c }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Picker("Sort", selection: $sort) {
                    ForEach(Sort.allCases, id: \.self) { s in
                        Text(s.label).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Product list
            Section {
                if filteredProducts.isEmpty {
                    ContentUnavailableView("No products", systemImage: "shippingbox", description: Text("Add your first item with the + button."))
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredProducts) { p in
                        Button { beginEdit(existing: p) } label: {
                            ProductRow(product: p)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) { vm.deleteProducts([p.id]) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button { vm.duplicateProduct(p) } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }
                        }
                    }
                    // Enable drag-to-reorder when Sort == .order
                    .onMove { from, to in
                        guard sort == .order else { return }
                        reorderVisible(fromOffsets: from, toOffset: to)
                    }
                }
            }
        }
        .environment(\.editMode, $editMode)
        .navigationTitle("Products")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if sort == .order {
                            EditButton()
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button { beginNew() } label: {
                                Label("Add Product", systemImage: "plus")
                            }
                            
                            Divider()
                            
                            Button { showingDefaultOrderSheet = true } label: {
                                Label("Edit Default Order", systemImage: "arrow.up.arrow.down")
                            }
                            
                            Button { showingBartenderOrdersSheet = true } label: {
                                Label("Manage Bartender Orders", systemImage: "person.2")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                ProductEditSheet(draft: $draft) { result in
                    switch result {
                    case .save(let product):
                        if isNew { vm.addProduct(product) } else { vm.updateProduct(product) }
                    case .delete(let id):
                        vm.deleteProducts([id])
                    case .cancel: break
                    }
                    showingEditor = false
                }
            }
        }
        .sheet(isPresented: $showingDefaultOrderSheet) {
                    NavigationStack {
                        DefaultOrderSheet()
                            .environmentObject(vm)
                    }
                }
                .sheet(isPresented: $showingBartenderOrdersSheet) {
                    NavigationStack {
                        BartenderOrdersSheet()
                            .environmentObject(vm)
                    }
                }
    }

    private var filteredProducts: [Product] {
        var items = vm.products
        if let c = category { items = items.filter { $0.category == c } }
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = query.lowercased()
            items = items.filter { $0.name.lowercased().contains(q) }
        }
        switch sort {
        case .order:     return items.sorted { $0.displayOrder < $1.displayOrder }
        case .nameAZ:    return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameZA:    return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .priceLow:  return items.sorted { $0.price < $1.price }
        case .priceHigh: return items.sorted { $0.price > $1.price }
        }
    }

    private func beginNew() {
        draft = Product(name: "", category: category ?? .misc, price: 0)
        isNew = true
        showingEditor = true
    }
    private func beginEdit(existing: Product) {
        draft = existing
        isNew = false
        showingEditor = true
    }

    // Drag-to-reorder persists displayOrder for exactly the current filtered set
    private func reorderVisible(fromOffsets: IndexSet, toOffset: Int) {
        var ids = filteredProducts.map { $0.id }
        ids.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (idx, id) in ids.enumerated() {
            if let i = vm.products.firstIndex(where: { $0.id == id }) {
                vm.products[i].displayOrder = idx
            }
        }
    }

    // MARK: - Sort mode
    enum Sort: CaseIterable {
        case order, nameAZ, nameZA, priceLow, priceHigh
        var label: String {
            switch self {
            case .order:     return "Order"
            case .nameAZ:    return "A–Z"
            case .nameZA:    return "Z–A"
            case .priceLow:  return "$ Low"
            case .priceHigh: return "$ High"
            }
        }
    }
}

// MARK: - Edit Sheet
struct ProductEditSheet: View {
    @Binding var draft: Product
    var onComplete: (Result) -> Void

    @State private var name: String = ""
    @State private var priceString: String = ""

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                Picker("Category", selection: $draft.category) {
                    ForEach(ProductCategory.allCases) { c in
                        Text(c.displayName).tag(c)
                    }
                }
                HStack {
                    Text("Price")
                    TextField("0.00", text: $priceString)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                Toggle("Hide from register", isOn: $draft.isHidden)
            }
        }
        .navigationTitle("Product")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { onComplete(.cancel) }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    if let price = Decimal(string: priceString.replacingOccurrences(of: ",", with: ".")) {
                        draft.price = price
                        draft.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        onComplete(.save(draft))
                    }
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || Decimal(string: priceString.replacingOccurrences(of: ",", with: ".")) == nil)
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Spacer()
                Button(role: .destructive) { onComplete(.delete(draft.id)) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .onAppear {
            name = draft.name
            priceString = draft.price.currencyEditingString()
        }
    }

    enum Result { case save(Product), delete(UUID), cancel }
}

// MARK: - Row
struct ProductRow: View {
    let product: Product
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(product.name)
                        .font(.body).fontWeight(.medium)
                        .lineLimit(1)
                    if product.isHidden {
                        Label("Hidden", systemImage: "eye.slash")
                            .labelStyle(.iconOnly)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Capsule())
                    }
                }
                Text(product.category.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(product.price.currencyString())
                .font(.body)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Small UI helpers
struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.tertiarySystemFill))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - InventoryVM helpers for Products
extension InventoryVM {
    func addProduct(_ p: Product) {
        // Place new product at the end of its category ordering
        var np = p
        let maxOrder = products.filter { $0.category == p.category }.map(\.displayOrder).max() ?? -1
        np.displayOrder = maxOrder + 1
        products.append(np)
    }
    func updateProduct(_ p: Product) {
        guard let i = products.firstIndex(where: { $0.id == p.id }) else { return }
        products[i] = p
    }
    func deleteProducts(_ ids: [UUID]) {
        products.removeAll { ids.contains($0.id) }
    }
    func duplicateProduct(_ p: Product) {
        // Duplicate goes to end of the same category
        var copy = p
        let maxOrder = products.filter { $0.category == p.category }.map(\.displayOrder).max() ?? -1
        copy.id = UUID()
        copy.name = p.name + " (copy)"
        copy.displayOrder = maxOrder + 1
        products.append(copy)
    }
}

// MARK: - Decimal formatting helpers
private extension Decimal {
    func currencyString() -> String {
        let ns = self as NSDecimalNumber
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f.string(from: ns) ?? "$\(self)"
    }
    func currencyEditingString() -> String {
        let ns = self as NSDecimalNumber
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.minimumIntegerDigits = 1
        f.numberStyle = .decimal
        return f.string(from: ns) ?? "\(self)"
    }
}
