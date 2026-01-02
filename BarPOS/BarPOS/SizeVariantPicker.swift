//
//  SizeVariantPicker.swift
//  BarPOS
//
//  Size variant picker for products with multiple size options
//

import SwiftUI

struct SizeVariantPicker: View {
    let product: Product
    let onSelect: (SizeVariant) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Product header
                VStack(spacing: 8) {
                    Text(product.name)
                        .font(.title2)
                        .bold()
                    
                    Text("Select Size")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
                
                // Size variant list
                ScrollView {
                    VStack(spacing: 12) {
                        if let variants = product.sizeVariants {
                            ForEach(variants) { variant in
                                Button {
                                    onSelect(variant)
                                    dismiss()
                                } label: {
                                    SizeVariantRow(variant: variant)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct SizeVariantRow: View {
    let variant: SizeVariant
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(variant.name)
                    .font(.headline)
                
                Text("\(variant.sizeOz.plainString()) oz")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Text(variant.price.currencyString())
                .font(.title3)
                .bold()
                .foregroundStyle(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    let testProduct = Product(
        name: "Miller Lite Draft",
        category: .beer,
        price: 0,
        sizeVariants: [
            SizeVariant(name: "Short", sizeOz: 16, price: 3.00, isDefault: true),
            SizeVariant(name: "Tall", sizeOz: 22, price: 3.50, isDefault: false)
        ]
    )
    
    SizeVariantPicker(product: testProduct) { variant in
        print("Selected: \(variant.name)")
    }
}
