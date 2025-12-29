//
//  ProductPerformanceView.swift
//  BarPOS
//
//  Created by Analytics Hub
//

import SwiftUI
import Charts

struct ProductPerformanceView: View {
    let analytics: AnalyticsEngine

    @State private var selectedCategory: ProductCategory?
    @State private var sortBy: SortOption = .revenue

    enum SortOption: String, CaseIterable {
        case revenue = "Revenue"
        case quantity = "Quantity"
        case margin = "Margin"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Controls
                controlSection

                // MARK: - Top Sellers
                if topProducts.isEmpty {
                    ContentUnavailableView(
                        "No Data Available",
                        systemImage: "chart.bar.xaxis",
                        description: Text("No product sales found for the selected date range")
                    )
                } else {
                    topSellersSection
                    categoryBreakdownSection
                    marginAnalysisSection
                }
            }
            .padding()
        }
        .navigationTitle("Product Performance")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Control Section
    private var controlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filters")
                .font(.headline)

            // Category Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "All",
                        isSelected: selectedCategory == nil,
                        action: { selectedCategory = nil }
                    )

                    ForEach(ProductCategory.allCases) { category in
                        FilterChip(
                            title: category.displayName,
                            isSelected: selectedCategory == category,
                            action: { selectedCategory = category }
                        )
                    }
                }
            }

            // Sort Options
            Picker("Sort By", selection: $sortBy) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Top Sellers Section
    private var topSellersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top 10 Products")
                .font(.headline)

            Chart(topProducts) { item in
                BarMark(
                    x: .value("Revenue", item.revenue as NSDecimalNumber),
                    y: .value("Product", item.product)
                )
                .foregroundStyle(.blue)
                .annotation(position: .trailing) {
                    Text(item.revenue.currencyString())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 400)
            .chartXAxis {
                AxisMarks(position: .bottom)
            }

            // Detailed List
            VStack(spacing: 8) {
                ForEach(Array(topProducts.enumerated()), id: \.element.product) { index, item in
                    HStack {
                        Text("#\(index + 1)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.product)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("\(item.quantity) sold")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(item.revenue.currencyString())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Category Breakdown Section
    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Category Performance")
                .font(.headline)

            let breakdown = analytics.categoryBreakdown()

            ForEach(Array(breakdown.keys.sorted(by: { breakdown[$0]!.revenue > breakdown[$1]!.revenue })), id: \.self) { category in
                if let data = breakdown[category] {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(category.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(data.revenue.currencyString())
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.green)

                                Text("\(data.quantity) items")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Progress bar showing relative revenue
                        if let maxRevenue = breakdown.values.map({ $0.revenue }).max(),
                           maxRevenue > 0 {
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.green.opacity(0.3))
                                    .frame(width: geo.size.width * CGFloat(truncating: (data.revenue / maxRevenue) as NSDecimalNumber))
                                    .frame(height: 8)
                            }
                            .frame(height: 8)
                        }
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Margin Analysis Section
    private var marginAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profit Margin Analysis")
                .font(.headline)

            let margins = analytics.productMargins().prefix(10)

            if margins.isEmpty {
                Text("No margin data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                ForEach(Array(margins.enumerated()), id: \.element.product) { index, item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.product)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Spacer()

                            Text("\(item.margin.plainString())%")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(marginColor(item.margin))
                        }

                        HStack {
                            Text("Cost: \(item.cost.currencyString())")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text("Price: \(item.price.currencyString())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Computed Properties
    private var topProducts: [(product: String, quantity: Int, revenue: Decimal)] {
        let allProducts = analytics.topSellingProducts(limit: 50)

        // Filter by category if selected
        let filtered = if let category = selectedCategory {
            allProducts.filter { product in
                analytics.products.first(where: { $0.name == product.product })?.category == category
            }
        } else {
            allProducts
        }

        // Sort based on selected option
        let sorted = switch sortBy {
        case .revenue:
            filtered.sorted { $0.revenue > $1.revenue }
        case .quantity:
            filtered.sorted { $0.quantity > $1.quantity }
        case .margin:
            filtered.sorted { product1, product2 in
                let margin1 = analytics.products.first(where: { $0.name == product1.product })?.profitMargin ?? 0
                let margin2 = analytics.products.first(where: { $0.name == product2.product })?.profitMargin ?? 0
                return margin1 > margin2
            }
        }

        return Array(sorted.prefix(10))
    }

    private func marginColor(_ margin: Decimal) -> Color {
        if margin >= 300 {
            return .green
        } else if margin >= 200 {
            return .blue
        } else if margin >= 100 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Filter Chip Component
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}
