//
//  CategoryBreakdownView.swift
//  BarPOS
//
//  Created by Analytics Hub
//

import SwiftUI
import Charts

struct CategoryBreakdownView: View {
    let analytics: AnalyticsEngine

    @State private var selectedCategory: ProductCategory?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if categoryData.isEmpty {
                    ContentUnavailableView(
                        "No Data Available",
                        systemImage: "chart.pie",
                        description: Text("No category data found for the selected date range")
                    )
                } else {
                    // MARK: - Pie Chart
                    pieChartSection

                    // MARK: - Revenue Breakdown
                    revenueBreakdownSection

                    // MARK: - Category Details
                    categoryDetailsSection
                }
            }
            .padding()
        }
        .navigationTitle("Category Breakdown")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Pie Chart Section
    private var pieChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Revenue Distribution")
                .font(.headline)

            Chart(categoryData, id: \.category) { data in
                SectorMark(
                    angle: .value("Revenue", data.revenue as NSDecimalNumber),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(by: .value("Category", data.category.displayName))
                .cornerRadius(4)
            }
            .frame(height: 300)
            .chartLegend(position: .bottom, spacing: 8)

            // Total Revenue
            VStack(spacing: 4) {
                Text("Total Revenue")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(totalRevenue.currencyString())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Revenue Breakdown Section
    private var revenueBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Category Performance")
                .font(.headline)

            ForEach(categoryData, id: \.category) { data in
                Button {
                    selectedCategory = selectedCategory == data.category ? nil : data.category
                } label: {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(data.category.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)

                                Text("\(data.quantity) items sold")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(data.revenue.currencyString())
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.blue)

                                Text(String(format: "%.1f%%", data.percentage))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.gray.opacity(0.2))
                                    .frame(height: 8)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(categoryColor(data.category))
                                    .frame(width: geo.size.width * CGFloat(data.percentage / 100))
                                    .frame(height: 8)
                            }
                        }
                        .frame(height: 8)

                        // Expanded details
                        if selectedCategory == data.category {
                            Divider()

                            VStack(spacing: 8) {
                                HStack {
                                    Text("Avg Item Price:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    Text(data.avgPrice.currencyString())
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }

                                HStack {
                                    Text("Total Items:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    Text("\(data.quantity)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }

                                HStack {
                                    Text("Revenue:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Spacer()

                                    Text(data.revenue.currencyString())
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Category Details Section
    private var categoryDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Comparison Chart")
                .font(.headline)

            Chart(categoryData, id: \.category) { data in
                BarMark(
                    x: .value("Category", data.category.displayName),
                    y: .value("Revenue", data.revenue as NSDecimalNumber)
                )
                .foregroundStyle(categoryColor(data.category))
                .annotation(position: .top) {
                    Text(data.revenue.currencyString())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 250)
            .chartYAxis {
                AxisMarks(position: .leading)
            }

            // Summary Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                SummaryMetric(
                    title: "Highest Revenue",
                    value: highestCategory?.category.displayName ?? "N/A",
                    subtitle: highestCategory?.revenue.currencyString() ?? "",
                    color: .green
                )

                SummaryMetric(
                    title: "Most Items Sold",
                    value: mostItemsCategory?.category.displayName ?? "N/A",
                    subtitle: "\(mostItemsCategory?.quantity ?? 0) items",
                    color: .blue
                )

                SummaryMetric(
                    title: "Highest Avg Price",
                    value: highestAvgPriceCategory?.category.displayName ?? "N/A",
                    subtitle: highestAvgPriceCategory?.avgPrice.currencyString() ?? "",
                    color: .orange
                )

                SummaryMetric(
                    title: "Total Categories",
                    value: "\(categoryData.count)",
                    subtitle: "active",
                    color: .purple
                )
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helper Functions
    private func categoryColor(_ category: ProductCategory) -> Color {
        switch category {
        case .beer: return .yellow
        case .wine: return .purple
        case .liquor: return .blue
        case .shots: return .red
        case .cocktails: return .pink
        case .na: return .green
        case .food: return .orange
        case .chips: return .brown
        case .misc: return .gray
        }
    }

    // MARK: - Computed Properties
    private var categoryData: [(category: ProductCategory, revenue: Decimal, quantity: Int, percentage: Double, avgPrice: Decimal)] {
        let breakdown = analytics.categoryBreakdown()
        let total = totalRevenue

        return breakdown.map { category, stats in
            let percentage = total > 0 ? Double(truncating: (stats.revenue / total * 100) as NSDecimalNumber) : 0
            let avgPrice = stats.quantity > 0 ? stats.revenue / Decimal(stats.quantity) : 0

            return (
                category: category,
                revenue: stats.revenue,
                quantity: stats.quantity,
                percentage: percentage,
                avgPrice: avgPrice
            )
        }
        .sorted { $0.revenue > $1.revenue }
    }

    private var totalRevenue: Decimal {
        categoryData.reduce(0) { $0 + $1.revenue }
    }

    private var highestCategory: (category: ProductCategory, revenue: Decimal)? {
        categoryData.max { $0.revenue < $1.revenue }
            .map { ($0.category, $0.revenue) }
    }

    private var mostItemsCategory: (category: ProductCategory, quantity: Int)? {
        categoryData.max { $0.quantity < $1.quantity }
            .map { ($0.category, $0.quantity) }
    }

    private var highestAvgPriceCategory: (category: ProductCategory, avgPrice: Decimal)? {
        categoryData.max { $0.avgPrice < $1.avgPrice }
            .map { ($0.category, $0.avgPrice) }
    }
}

// MARK: - Summary Metric Component
struct SummaryMetric: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
