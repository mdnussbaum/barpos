import SwiftUI

struct BuildCocktailSheet: View {
    @EnvironmentObject var vm: InventoryVM
    @Environment(\.dismiss) private var dismiss

    @State private var cocktailName: String = ""
    @State private var selectedIngredients: [RecipeIngredient] = []
    @State private var showingAddIngredient = false

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
                        Text("Total Price")
                            .font(.headline)
                        Spacer()
                        Text(totalPrice.currencyString())
                            .font(.headline)
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
                    .disabled(cocktailName.trimmingCharacters(in: .whitespaces).isEmpty || selectedIngredients.isEmpty)
                }
            }
            .sheet(isPresented: $showingAddIngredient) {
                AddIngredientSheet { ingredient in
                    selectedIngredients.append(ingredient)
                }
                .environmentObject(vm)
            }
        }
    }

    private func saveCocktail() {
        guard let bartender = vm.currentShift?.openedBy else { return }

        let cocktail = CustomCocktail(
            name: cocktailName.trimmingCharacters(in: .whitespaces),
            createdBy: bartender.id,
            ingredients: selectedIngredients
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
    @State private var searchText: String = ""

    private let servingOptions: [Decimal] = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.25, 2.5, 2.75, 3]

    private var availableProducts: [Product] {
        vm.products
            .filter { $0.canBeIngredient && !$0.isHidden && $0.category != .chips }
            .filter { searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Select Product") {
                    List {
                        ForEach(availableProducts) { product in
                            Button {
                                selectedProduct = product
                            } label: {
                                HStack {
                                    Text(product.name)
                                    Spacer()
                                    if selectedProduct?.id == product.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .searchable(text: $searchText, prompt: "Search products")

                if selectedProduct != nil {
                    Section("Servings") {
                        Picker("Servings", selection: $servings) {
                            ForEach(servingOptions, id: \.self) { option in
                                Text(option.plainString()).tag(option)
                            }
                        }
                        .pickerStyle(.wheel)
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
                            let ingredient = RecipeIngredient(defaultProduct: product, servings: servings)
                            onAdd(ingredient)
                            dismiss()
                        }
                    }
                    .disabled(selectedProduct == nil)
                }
            }
        }
    }
}
