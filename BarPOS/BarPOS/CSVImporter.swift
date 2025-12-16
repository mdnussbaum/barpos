//
//  CSVImporter.swift
//  BarPOS
//
//  Created by Michael Nussbaum on 11/29/25.
//

import Foundation

struct CSVImporter {
    
    // MARK: - Import Result
    struct ImportResult {
        let created: Int
        let updated: Int
        let skipped: Int
        let errors: [String]
    }
    
    // MARK: - Import Products from CSV
    static func importProducts(from csvData: String, existingProducts: [Product]) -> (products: [Product], result: ImportResult) {
        var products = existingProducts
        var created = 0
        var updated = 0
        var skipped = 0
        var errors: [String] = []
        
        // Parse CSV
        let rows = csvData.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        guard rows.count > 1 else {
            errors.append("CSV file is empty or has no data rows")
            return (products, ImportResult(created: 0, updated: 0, skipped: 0, errors: errors))
        }
        
        // Get header row
        let headers = parseCSVRow(rows[0])
        
        // Process each data row
        for (index, row) in rows.dropFirst().enumerated() {
            let lineNumber = index + 2 // +2 because we skip header and arrays are 0-indexed
            let values = parseCSVRow(row)
            
            guard values.count == headers.count else {
                errors.append("Line \(lineNumber): Column count mismatch")
                skipped += 1
                continue
            }
            
            // Create dictionary from headers and values
            let rowData = Dictionary(uniqueKeysWithValues: zip(headers, values))
            
            // Parse product from row
            guard let name = rowData["name"]?.trimmingCharacters(in: .whitespaces),
                  !name.isEmpty else {
                errors.append("Line \(lineNumber): Missing product name")
                skipped += 1
                continue
            }
            
            // Check if product exists
            if let existingIndex = products.firstIndex(where: { $0.name.lowercased() == name.lowercased() }) {
                // Update existing product
                var product = products[existingIndex]
                
                updateProduct(&product, from: rowData, lineNumber: lineNumber, errors: &errors)
                
                products[existingIndex] = product
                updated += 1
            } else {
                // Create new product
                var product = Product(
                    id: UUID(),
                    name: name,
                    category: .misc,
                    price: 0
                )
                
                updateProduct(&product, from: rowData, lineNumber: lineNumber, errors: &errors)
                
                products.append(product)
                created += 1
            }
        }
        
        return (products, ImportResult(created: created, updated: updated, skipped: skipped, errors: errors))
    }
    
    // MARK: - Update Product from Row Data
    private static func updateProduct(_ product: inout Product, from rowData: [String: String], lineNumber: Int, errors: inout [String]) {
        // Category
        if let categoryStr = rowData["category"], !categoryStr.isEmpty {
            if let category = ProductCategory.allCases.first(where: { $0.rawValue.lowercased() == categoryStr.lowercased() }) {
                product.category = category
            } else {
                errors.append("Line \(lineNumber): Invalid category '\(categoryStr)'")
            }
        }
        
        // Price
        if let priceStr = rowData["price"], !priceStr.isEmpty {
            if let price = Decimal(string: priceStr.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")) {
                product.price = price
            } else {
                errors.append("Line \(lineNumber): Invalid price '\(priceStr)'")
            }
        }
        
        // Cost
        if let costStr = rowData["cost"], !costStr.isEmpty {
            product.cost = Decimal(string: costStr.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: ""))
        }
        
        // Stock Quantity
        if let stockStr = rowData["stock"], !stockStr.isEmpty {
            product.stockQuantity = Decimal(string: stockStr)
        }
        
        // Par Level
        if let parStr = rowData["par"], !parStr.isEmpty {
            product.parLevel = Decimal(string: parStr)
        }
        
        // Unit
        if let unitStr = rowData["unit"], !unitStr.isEmpty {
            if let unit = UnitOfMeasure.allCases.first(where: { $0.rawValue.lowercased() == unitStr.lowercased() }) {
                product.unit = unit
            }
        }
        
        // Serving Size
        if let servingSizeStr = rowData["serving_size"], !servingSizeStr.isEmpty {
            product.servingSize = Decimal(string: servingSizeStr)
        }
        
        // Serving Unit
        if let servingUnitStr = rowData["serving_unit"], !servingUnitStr.isEmpty {
            if let unit = UnitOfMeasure.allCases.first(where: { $0.rawValue.lowercased() == servingUnitStr.lowercased() }) {
                product.servingUnit = unit
            }
        }
        
        // Case Size
        if let caseSizeStr = rowData["case_size"], !caseSizeStr.isEmpty {
            product.caseSize = Int(caseSizeStr)
        }
        
        // Tier
        if let tierStr = rowData["tier"], !tierStr.isEmpty {
            if let tier = ProductTier(rawValue: tierStr.lowercased()) {
                product.tier = tier
            }
        }
        
        // Gun item
        if let gunStr = rowData["gun_item"], !gunStr.isEmpty {
            product.isGunItem = (gunStr.lowercased() == "true" || gunStr == "1" || gunStr.lowercased() == "yes")
        }
        
        // Supplier
        if let supplier = rowData["supplier"], !supplier.isEmpty {
            product.supplier = supplier
        }
        
        // Supplier SKU
        if let sku = rowData["sku"], !sku.isEmpty {
            product.supplierSKU = sku
        }
        
        // Hidden
        if let hiddenStr = rowData["hidden"], !hiddenStr.isEmpty {
            product.isHidden = (hiddenStr.lowercased() == "true" || hiddenStr == "1" || hiddenStr.lowercased() == "yes")
        }
        
        // 86'd
        if let is86dStr = rowData["86d"], !is86dStr.isEmpty {
            product.is86d = (is86dStr.lowercased() == "true" || is86dStr == "1" || is86dStr.lowercased() == "yes")
        }

        // Can be ingredient
        if let ingredientStr = rowData["can_be_ingredient"], !ingredientStr.isEmpty {
            product.canBeIngredient = (ingredientStr.lowercased() == "true" || ingredientStr == "1" || ingredientStr.lowercased() == "yes")
        }
    }
    
    // MARK: - Parse CSV Row
    private static func parseCSVRow(_ row: String) -> [String] {
        var values: [String] = []
        var currentValue = ""
        var insideQuotes = false
        
        for char in row {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                values.append(currentValue.trimmingCharacters(in: .whitespaces))
                currentValue = ""
            } else {
                currentValue.append(char)
            }
        }
        
        // Add last value
        values.append(currentValue.trimmingCharacters(in: .whitespaces))
        
        return values
    }
    
    // MARK: - Generate Template CSV
    static func generateTemplateCSV() -> String {
        let headers = [
            "name",
            "category",
            "price",
            "cost",
            "stock",
            "par",
            "unit",
            "case_size",
            "serving_size",
            "serving_unit",
            "tier",
            "gun_item",
            "supplier",
            "sku",
            "hidden",
            "86d",
            "can_be_ingredient"
        ]
        
        let examples = [
            [
                "Budweiser",
                "beer",
                "4.50",
                "2.00",
                "240",
                "72",
                "bottle",
                "24",
                "1",
                "bottle",
                "none",
                "false",
                "ABC Distributing",
                "BUD-12OZ",
                "false",
                "false",
                "false"
            ],
            [
                "Well Vodka",
                "liquor",
                "7.00",
                "15.00",
                "3",
                "2",
                "liter",
                "",
                "1.5",
                "oz",
                "well",
                "false",
                "ABC Distributing",
                "VODKA-WELL",
                "false",
                "false",
                "true"
            ],
            [
                "Orange Juice",
                "na",
                "3.00",
                "8.00",
                "3",
                "5",
                "gallon",
                "",
                "6",
                "oz",
                "none",
                "true",
                "Restaurant Depot",
                "OJ-GAL",
                "false",
                "false",
                "true"
            ]
        ]
        
        var csv = headers.joined(separator: ",") + "\n"
        
        for example in examples {
            csv += example.joined(separator: ",") + "\n"
        }
        
        return csv
    }
    
    // MARK: - Export Products to CSV
    static func exportProductsToCSV(products: [Product]) -> String {
        let headers = [
            "name",
            "category",
            "price",
            "cost",
            "stock",
            "par",
            "unit",
            "case_size",
            "serving_size",
            "serving_unit",
            "tier",
            "gun_item",
            "supplier",
            "sku",
            "hidden",
            "86d",
            "can_be_ingredient"
        ]
        
        var csv = headers.joined(separator: ",") + "\n"
        
        for product in products.sorted(by: { $0.displayOrder < $1.displayOrder }) {
            // Build row values
            let name = product.name
            let category = product.category.rawValue
            let price = "\(product.price)"
            let cost = product.cost.map { "\($0)" } ?? ""
            let stock = product.stockQuantity.map { "\($0)" } ?? ""
            let par = product.parLevel.map { "\($0)" } ?? ""
            let unit = product.unit.rawValue
            let caseSize = product.caseSize.map { "\($0)" } ?? ""
            let servingSize = product.servingSize.map { "\($0)" } ?? ""
            let servingUnit = product.servingUnit?.rawValue ?? ""
            let tier = product.tier.rawValue
            let gunItem = product.isGunItem ? "true" : "false"
            let supplier = product.supplier ?? ""
            let sku = product.supplierSKU ?? ""
            let hidden = product.isHidden ? "true" : "false"
            let is86d = product.is86d ? "true" : "false"
            let canBeIngredient = product.canBeIngredient ? "true" : "false"

            let row = [
                name, category, price, cost, stock, par, unit,
                caseSize, servingSize, servingUnit, tier, gunItem, supplier, sku, hidden, is86d, canBeIngredient
            ]
    
            // Escape commas in values
            let escapedRow = row.map { value in
                if value.contains(",") {
                    return "\"\(value)\""
                }
                return value
            }
            
            csv += escapedRow.joined(separator: ",") + "\n"
        }
        
        return csv
    }
}
