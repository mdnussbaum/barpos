import SwiftUI

struct BuildCocktailSheet: View {
    @EnvironmentObject var vm: InventoryVM
    @Environment(\.dismiss) private var dismiss

    @State private var cocktailName: String = ""
    @State private var selectedIngredients: [RecipeIngredient] = []
    @State private var showingAddIngredient = false
    @State private var customPriceString: String = ""

    private var totalPrice: Decimal {
        selectedIngredients.reduce(0) { $0 + ($1.defaultProduct.price * $1.servings) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Cocktail Name") {
                    TextField("Name your creation", text: $cocktailName)
                        .textInputAutocapitalization(.words)
                }

                Section("Ingredients") {
                    if selectedIngredients.isEmpty {
                        Text("No ingredients added yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(selectedIngredients) { ingredient in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ingredient.defaultProduct.name)
                                        .font(.body)
                                    Text(ingredient.displayText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text((ingredient.defaultProduct.price * ingredient.servings).currencyString())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { offsets in
                            selectedIngredients.remove(atOffsets: offsets)
                        }
                    }

                    Button {
                        showingAddIngredient = true
                    } label: {
                        Label("Add Ingredient", systemImage: "plus.circle.fill")
                    }
                }

                Section("Pricing") {
                    HStack {
                        Text("Ingredient Cost")
                        Spacer()
                        Text(totalPrice.currencyString())
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Sale Price")
                        Spacer()
                        TextField("0.00", text: $customPriceString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
            }
            .navigationTitle("Build Cocktail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveCocktail()
                    }
                    .disabled(cocktailName.trimmingCharacters(in: .whitespaces).isEmpty ||
                             selectedIngredients.isEmpty ||
                             (Decimal(string: customPriceString) ?? 0) <= 0)
                }
            }
            .sheet(isPresented: $showingAddIngredient) {
                AddIngredientSheet { ingredient in
                    selectedIngredients.append(ingredient)
                }
                .environmentObject(vm)
            }
            .onAppear {
                // Pre-fill price with calculated cost
                if customPriceString.isEmpty {
                    customPriceString = totalPrice.plainString()
                }
            }
            .onChange(of: selectedIngredients) { _, _ in
                // Update price when ingredients change (if user hasn't manually edited)
                if let currentPrice = Decimal(string: customPriceString), currentPrice == 0 || customPriceString.isEmpty {
                    customPriceString = totalPrice.plainString()
                }
            }
        }
    }

    private func saveCocktail() {
        guard let bartender = vm.currentShift?.openedBy else { return }
        
        // Use custom price if provided, otherwise use calculated total
        let finalPrice = Decimal(string: customPriceString) ?? totalPrice

        let cocktail = CustomCocktail(
            name: cocktailName.trimmingCharacters(in: .whitespaces),
            createdBy: bartender.id,
            ingredients: selectedIngredients,
            basePrice: finalPrice
        )

        vm.addCustomCocktail(cocktail)
        dismiss()
    }
}

// MARK: - Add Ingredient Sheet
struct AddIngredientSheet: View {
    @EnvironmentObject var vm: InventoryVM
    @Environment(\.dismiss) private var dismiss

    let onAdd: (RecipeIngredient) -> Void

    @State private var selectedProduct: Product?
    @State private var servings: Decimal = 1.0
    @State private var servingsString: String = "1"
    @State private var selectedCategory: ProductCategory? = .liquor // Default to liquor

    private var availableProducts: [Product] {
        let filtered = vm.products.filter { $0.canBeIngredient && !$0.is86d }
        
        if let category = selectedCategory {
            return filtered.filter { $0.category == category }
        }
        return filtered
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Filter by", selection: $selectedCategory) {
                        Text("All").tag(nil as ProductCategory?)
                        ForEach(ProductCategory.allCases.filter { $0 != .chips }) { category in
                            Text(category.displayName).tag(category as ProductCategory?)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Select Ingredient") {
                    if availableProducts.isEmpty {
                        Text("No ingredients available in this category")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Product", selection: $selectedProduct) {
                            Text("Select...").tag(nil as Product?)
                            ForEach(availableProducts) { product in
                                HStack {
                                    Text(product.name)
                                    Spacer()
                                    if product.tier != .none {
                                        Text(product.tier.displayName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .tag(product as Product?)
                            }
                        }
                    }
                }

                if selectedProduct != nil {
                    Section("Servings") {
                        HStack {
                            Text("Amount")
                            Spacer()
                            TextField("1.0", text: $servingsString)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .onChange(of: servingsString) { _, newValue in
                                    if let decimal = Decimal(string: newValue) {
                                        servings = decimal
                                    }
                                }
                            Text("servings")
                                .foregroundStyle(.secondary)
                        }

                        if let product = selectedProduct {
                            HStack {
                                Text("Cost per Serving")
                                Spacer()
                                Text(product.price.currencyString())
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack {
                                Text("Total Cost")
                                Spacer()
                                Text((product.price * servings).currencyString())
                                    .font(.headline)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        if let product = selectedProduct {
                            let ingredient = RecipeIngredient(
                                defaultProduct: product,
                                servings: servings
                            )
                            onAdd(ingredient)
                            dismiss()
                        }
                    }
                    .disabled(selectedProduct == nil || servings <= 0)
                }
            }
        }
    }
}
