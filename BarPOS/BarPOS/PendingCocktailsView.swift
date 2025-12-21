import SwiftUI

struct PendingCocktailsView: View {
    @EnvironmentObject var vm: InventoryVM
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCocktail: CustomCocktail?
    @State private var showingDetail = false

    private var pendingCocktails: [CustomCocktail] {
        vm.allPendingCocktails()
    }

    var body: some View {
        List {
            if pendingCocktails.isEmpty {
                ContentUnavailableView(
                    "No Pending Cocktails",
                    systemImage: "checkmark.circle",
                    description: Text("All cocktail recipes have been reviewed")
                )
            } else {
                ForEach(pendingCocktails) { cocktail in
                    Button {
                        print("🔵 Selected cocktail: \(cocktail.name)")
                        print("🔵 Ingredients count: \(cocktail.ingredients.count)")
                        for (index, ingredient) in cocktail.ingredients.enumerated() {
                            print("🔵 Ingredient \(index): \(ingredient.defaultProduct.name)")
                        }
                        selectedCocktail = cocktail
                        showingDetail = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(cocktail.name)
                                    .font(.headline)
                                Spacer()
                                Text(cocktail.basePrice.currencyString())
                                    .foregroundStyle(.secondary)
                            }

                            Text("\(cocktail.ingredients.count) ingredients")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let bartender = vm.bartenders.first(where: { $0.id == cocktail.createdBy }) {
                                Text("Created by \(bartender.name)")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Pending Cocktails")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingDetail) {
            if let cocktail = selectedCocktail {
                CocktailReviewSheet(cocktail: cocktail)
                    .environmentObject(vm)
            }
        }
    }
}

// MARK: - Cocktail Review Sheet
struct CocktailReviewSheet: View {
    @EnvironmentObject var vm: InventoryVM
    @Environment(\.dismiss) private var dismiss

    let cocktail: CustomCocktail

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe Details") {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(cocktail.name)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Base Price")
                        Spacer()
                        Text(cocktail.basePrice.currencyString())
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Category")
                        Spacer()
                        Text(cocktail.category.displayName)
                            .foregroundStyle(.secondary)
                    }

                    if let bartender = vm.bartenders.first(where: { $0.id == cocktail.createdBy }) {
                        HStack {
                            Text("Created By")
                            Spacer()
                            Text(bartender.name)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Ingredients") {
                    ForEach(cocktail.ingredients) { ingredient in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ingredient.defaultProduct.name)
                                .font(.body)
                            HStack {
                                Text(ingredient.displayText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text((ingredient.defaultProduct.price * ingredient.servings).currencyString())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section {
                    Button {
                        approveCocktail()
                    } label: {
                        Label("Approve & Add to Menu", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    Button(role: .destructive) {
                        rejectCocktail()
                    } label: {
                        Label("Reject Recipe", systemImage: "xmark.circle.fill")
                    }
                }
            }
            .navigationTitle("Review Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func approveCocktail() {
        guard let adminID = vm.currentShift?.openedBy?.id else { return }
        vm.approveCocktail(cocktail, approvedBy: adminID)
        dismiss()
    }

    private func rejectCocktail() {
        vm.rejectCocktail(cocktail)
        dismiss()
    }
}
