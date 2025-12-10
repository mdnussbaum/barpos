//
//  AdminProductsView.swift
//  BarPOSv2
//

import SwiftUI
import UniformTypeIdentifiers

struct AdminProductsView: View {
    @EnvironmentObject var vm: InventoryVM

    // Filters / UI state
    @State private var query: String = ""
    @State private var category: ProductCategory? = nil
    @State private var sort: Sort = .order
    @State private var editMode: EditMode = .inactive

    // Sheet state
    @State private var showingEditor = false
    @State private var draft: Product = Product(name: "", category: .misc, price: 0)
    @State private var isNew = true
    @State private var showingDefaultOrderSheet = false
    @State private var showingBartenderOrdersSheet = false
    
    // CSV Import state
    @State private var showingImportSheet = false
    @State private var showingImportPicker = false
    @State private var importResult: CSVImporter.ImportResult?

    @State private var caseSizeString: String = ""
    
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
                        HStack(spacing: 8) {
                            Button { beginEdit(existing: p) } label: {
                                ProductRow(product: p)
                            }
                            .buttonStyle(.plain)
                            
                            // Quick action buttons
                            HStack(spacing: 4) {
                                Button {
                                    var updated = p
                                    updated.is86d.toggle()
                                    vm.updateProduct(updated)
                                } label: {
                                    Image(systemName: p.is86d ? "checkmark.circle.fill" : "xmark.circle")
                                        .foregroundStyle(p.is86d ? .green : .orange)
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                                
                                Button { beginEdit(existing: p) } label: {
                                    Image(systemName: "pencil.circle.fill")
                                        .foregroundStyle(.blue)
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { vm.deleteProducts([p.id]) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button { vm.duplicateProduct(p) } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }
                            .tint(.blue)
                        }
                    }
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
                    
                    Button { downloadTemplateCSV() } label: {
                        Label("Download CSV Template", systemImage: "arrow.down.doc")
                    }
                    
                    Button { showingImportPicker = true } label: {
                        Label("Import CSV", systemImage: "square.and.arrow.down")
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
            .interactiveDismissDisabled()
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
        .fileImporter(isPresented: $showingImportPicker, allowedContentTypes: [.commaSeparatedText, .text]) { result in
            switch result {
            case .success(let url):
                importCSV(from: url)
            case .failure(let error):
                print("File picker error: \(error)")
            }
        }
        .alert("Import Complete", isPresented: $showingImportSheet) {
            Button("OK") {
                importResult = nil
            }
        } message: {
            if let result = importResult {
                Text("Created: \(result.created)\nUpdated: \(result.updated)\nSkipped: \(result.skipped)\n\(result.errors.isEmpty ? "" : "\nErrors:\n" + result.errors.joined(separator: "\n"))")
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

    private func reorderVisible(fromOffsets: IndexSet, toOffset: Int) {
        var ids = filteredProducts.map { $0.id }
        ids.move(fromOffsets: fromOffsets, toOffset: toOffset)
        for (idx, id) in ids.enumerated() {
            if let i = vm.products.firstIndex(where: { $0.id == id }) {
                vm.products[i].displayOrder = idx
            }
        }
    }
    
    private func downloadTemplateCSV() {
        let csv = CSVImporter.generateTemplateCSV()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ProductImportTemplate.csv")
        
        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            
            // Save to Files app / Share
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                activityVC.popoverPresentationController?.sourceView = window
                rootVC.present(activityVC, animated: true)
            }
        } catch {
            print("Error creating template: \(error)")
        }
    }
    
    private func importCSV(from url: URL) {
        do {
            let csvData = try String(contentsOf: url, encoding: .utf8)
            let (newProducts, result) = CSVImporter.importProducts(from: csvData, existingProducts: vm.products)
            
            vm.products = newProducts
            importResult = result
            showingImportSheet = true
        } catch {
            print("Error reading CSV: \(error)")
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
    @State private var costString: String = ""
    @State private var stockString: String = ""
    @State private var parString: String = ""
    @State private var servingSizeString: String = ""
    @State private var supplier: String = ""
    @State private var supplierSKU: String = ""
    @State private var caseSizeString: String = ""
    @State private var casesString: String = ""
    @State private var extraBottlesString: String = ""

    var body: some View {
        Form {
            // MARK: - Basics
            Section("Basics") {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                
                Picker("Category", selection: $draft.category) {
                    ForEach(ProductCategory.allCases) { c in
                        Text(c.displayName).tag(c)
                    }
                }
                
                Toggle("Hide from register", isOn: $draft.isHidden)
                Toggle("86'd (Out of Stock)", isOn: $draft.is86d)
            }
            
            // MARK: - Pricing
            Section("Pricing") {
                HStack {
                    Text("Sell Price")
                    Spacer()
                    TextField("0.00", text: $priceString)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Cost")
                    Spacer()
                    TextField("0.00", text: $costString)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                
                if let margin = draft.profitMargin {
                    HStack {
                        Text("Profit Margin")
                        Spacer()
                        Text("\(Int((margin as NSDecimalNumber).doubleValue.rounded()))%")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // MARK: - Inventory
            Section("Inventory") {
                Picker("Stock Unit", selection: $draft.unit) {
                    ForEach(UnitOfMeasure.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                
                HStack {
                    Text("Case Size")
                    Spacer()
                    TextField("24", text: $caseSizeString)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: caseSizeString) { _, _ in
                            updateStockFromCases()
                        }
                    Text("bottles/case")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                
                // If case size is set, show cases + bottles entry
                if let caseSize = Int(caseSizeString), caseSize > 0 {
                    HStack {
                        Text("Cases")
                        Spacer()
                        TextField("0", text: $casesString)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: casesString) { _, _ in
                                updateStockFromCases()
                            }
                        Text("cases")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Extra Bottles")
                        Spacer()
                        TextField("0", text: $extraBottlesString)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: extraBottlesString) { _, _ in
                                updateStockFromCases()
                            }
                        Text("bottles")
                            .foregroundStyle(.secondary)
                    }
                    
                    // Show calculated total
                    HStack {
                        Text("Total Stock")
                        Spacer()
                        Text(stockString + " bottles")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // No case size - show normal stock entry
                    HStack {
                        Text("Current Stock")
                        Spacer()
                        TextField("0", text: $stockString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text(draft.unit.displayName)
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack {
                    Text("Par Level")
                    Spacer()
                    TextField("0", text: $parString)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text(draft.unit.displayName)
                        .foregroundStyle(.secondary)
                }
            }
            
            // MARK: - Serving Size
            Section("Serving Size") {
                Picker("Serving Unit", selection: $draft.servingUnit) {
                    Text("Same as stock").tag(nil as UnitOfMeasure?)
                    ForEach(UnitOfMeasure.allCases) { unit in
                        Text(unit.displayName).tag(unit as UnitOfMeasure?)
                    }
                }
                
                HStack {
                    Text("Serving Size")
                    Spacer()
                    TextField("0", text: $servingSizeString)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text((draft.servingUnit ?? draft.unit).displayName)
                        .foregroundStyle(.secondary)
                }
                
                if let costPerServing = draft.costPerServing {
                    HStack {
                        Text("Cost per Serving")
                        Spacer()
                        Text(costPerServing.currencyString())
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let servingsPerUnit = draft.servingsPerUnit {
                    HStack {
                        Text("Servings per \(draft.unit.displayName)")
                        Spacer()
                        Text("\(servingsPerUnit.plainString())")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // MARK: - Supplier
            Section("Supplier") {
                TextField("Supplier Name", text: $supplier)
                    .textInputAutocapitalization(.words)
                
                TextField("Supplier SKU/Code", text: $supplierSKU)
            }
        }
        .navigationTitle(name.isEmpty ? "New Product" : name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { onComplete(.cancel) }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveProduct()
                }
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                         Decimal(string: priceString.replacingOccurrences(of: ",", with: ".")) == nil)
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Spacer()
                Button(role: .destructive) {
                    onComplete(.delete(draft.id))
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .onAppear {
            loadValues()
        }
    }
    
    private func loadValues() {
        name = draft.name
        priceString = draft.price.currencyEditingString()
        costString = draft.cost?.currencyEditingString() ?? ""
        parString = draft.parLevel?.plainString() ?? ""
        servingSizeString = draft.servingSize?.plainString() ?? ""
        supplier = draft.supplier ?? ""
        supplierSKU = draft.supplierSKU ?? ""
        caseSizeString = draft.caseSize.map { "\($0)" } ?? ""
        
        // Load stock - split into cases + bottles if case size exists
        if let stock = draft.stockQuantity, let caseSize = draft.caseSize, caseSize > 0 {
            let stockInt = (stock as NSDecimalNumber).intValue
            let cases = stockInt / caseSize
            let bottles = stockInt % caseSize
            
            casesString = "\(cases)"
            extraBottlesString = "\(bottles)"
            stockString = "\(stockInt)"
        } else {
            stockString = draft.stockQuantity?.plainString() ?? ""
            casesString = ""
            extraBottlesString = ""
        }
    }
    
    private func updateStockFromCases() {
        guard let caseSize = Int(caseSizeString), caseSize > 0 else {
            return
        }
        
        let cases = Int(casesString) ?? 0
        let extraBottles = Int(extraBottlesString) ?? 0
        let total = (cases * caseSize) + extraBottles
        
        stockString = "\(total)"
    }
    
    private func saveProduct() {
        guard let price = Decimal(string: priceString.replacingOccurrences(of: ",", with: ".")) else { return }
        
        draft.name = name.trimmingCharacters(in: .whitespaces)
        draft.price = price
        draft.cost = Decimal(string: costString.replacingOccurrences(of: ",", with: "."))
        draft.stockQuantity = Decimal(string: stockString)
        draft.parLevel = Decimal(string: parString)
        draft.servingSize = Decimal(string: servingSizeString)
        draft.supplier = supplier.isEmpty ? nil : supplier
        draft.supplierSKU = supplierSKU.isEmpty ? nil : supplierSKU
        draft.caseSize = Int(caseSizeString)
        
        onComplete(.save(draft))
    }

    enum Result { case save(Product), delete(UUID), cancel }
}
// MARK: - Row
struct ProductRow: View {
    let product: Product
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: "shippingbox")
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            // Main info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(product.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    // Status badges
                    if product.is86d {
                        Badge(text: "86'd", color: .red)
                    }
                    if product.isLowStock {
                        Badge(text: "Low", color: .orange)
                    }
                    if product.isHidden {
                        Badge(text: "Hidden", color: .gray)
                    }
                }
                
                HStack(spacing: 8) {
                    Text(product.category.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let supplier = product.supplier {
                        Text("•")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Text(supplier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let stockDisplay = product.stockDisplayString {
                        Text("•")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Text(stockDisplay)
                            .font(.caption)
                            .foregroundStyle(product.isLowStock ? .orange : .secondary)
                    }
                }
            }
            
            Spacer(minLength: 8)
            
            // Price & margin
            VStack(alignment: .trailing, spacing: 2) {
                Text(product.price.currencyString())
                    .font(.body)
                    .fontWeight(.medium)
                    .monospacedDigit()
                
                if let margin = product.profitMargin {
                    Text("\(Int((margin as NSDecimalNumber).doubleValue.rounded()))%")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Status Badge
struct Badge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(Capsule())
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
        var copy = p
        let maxOrder = products.filter { $0.category == p.category }.map(\.displayOrder).max() ?? -1
        copy.id = UUID()
        copy.name = p.name + " (copy)"
        copy.displayOrder = maxOrder + 1
        products.append(copy)
    }
}

// MARK: - Decimal formatting helpers
    extension Decimal {
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
    func plainString() -> String {
        let ns = self as NSDecimalNumber
        let f = NumberFormatter()
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        f.numberStyle = .decimal
        return f.string(from: ns) ?? "\(self)"
    }
}
