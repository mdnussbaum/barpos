//
//  InventoryAnalyticsView.swift
//  BarPOS
//
//  Created by Analytics Hub
//

import SwiftUI
import Charts

struct InventoryAnalyticsView: View {
    let analytics: AnalyticsEngine

    @State private var selectedTab: Tab = .fastMovers

    enum Tab: String, CaseIterable {
        case fastMovers = "Fast Movers"
        case slowMovers = "Slow Movers"
        case alerts = "Stock Alerts"
        case eightySevenCount = "86'd Items"
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Tab Picker
            Picker("View", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // MARK: - Content
            ScrollView {
                VStack(spacing: 20) {
                    switch selectedTab {
                    case .fastMovers:
                        fastMoversSection
                    case .slowMovers:
                        slowMoversSection
                    case .alerts:
                        stockAlertsSection
                    case .eightySevenCount:
                        eightySixedSection
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Inventory Insights")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Fast Movers Section
    private var fastMoversSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top 10 Fast Movers")
                .font(.headline)

            if analytics.tickets.isEmpty {
                ContentUnavailableView(
                    "No Sales Data",
                    systemImage: "shippingbox",
                    description: Text("No products sold in the selected date range")
                )
            } else {
                let fastMovers = analytics.fastMovers(limit: 10)

                if fastMovers.isEmpty {
                    Text("No fast movers found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Chart(fastMovers, id: \.product) { mover in
                        BarMark(
                            x: .value("Quantity", mover.quantity),
                            y: .value("Product", mover.product)
                        )
                        .foregroundStyle(.green)
                        .annotation(position: .trailing) {
                            Text("\(mover.quantity)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: max(CGFloat(fastMovers.count * 60), 300))

                    // Detailed List
                    VStack(spacing: 8) {
                        ForEach(Array(fastMovers.enumerated()), id: \.element.product) { index, mover in
                            HStack {
                                Text("#\(index + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mover.product)
                                        .font(.subheadline)
                                        .fontWeight(.medium)

                                    Text(mover.category.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(mover.quantity)")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.green)

                                    Text("sold")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    // Reorder Alert
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Reorder Recommendations", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)

                        Text("These items are selling quickly. Review stock levels to avoid running out.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Slow Movers Section
    private var slowMoversSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top 10 Slow Movers")
                .font(.headline)

            if analytics.tickets.isEmpty {
                ContentUnavailableView(
                    "No Sales Data",
                    systemImage: "shippingbox",
                    description: Text("No products sold in the selected date range")
                )
            } else {
                let slowMovers = analytics.slowMovers(limit: 10)

                if slowMovers.isEmpty {
                    Text("No slow movers found")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Chart(slowMovers, id: \.product) { mover in
                        BarMark(
                            x: .value("Quantity", mover.quantity),
                            y: .value("Product", mover.product)
                        )
                        .foregroundStyle(.orange)
                        .annotation(position: .trailing) {
                            Text("\(mover.quantity)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: max(CGFloat(slowMovers.count * 60), 300))

                    // Detailed List
                    VStack(spacing: 8) {
                        ForEach(Array(slowMovers.enumerated()), id: \.element.product) { index, mover in
                            HStack {
                                Text("#\(index + 1)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mover.product)
                                        .font(.subheadline)
                                        .fontWeight(.medium)

                                    Text(mover.category.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(mover.quantity)")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.orange)

                                    Text("sold")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding()
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    // Action Recommendations
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Consider", systemImage: "lightbulb.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Run promotions to move inventory")
                            Text("• Adjust pricing strategy")
                            Text("• Review product placement")
                            Text("• Consider discontinuing low performers")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Stock Alerts Section
    private var stockAlertsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Low Stock Alerts")
                .font(.headline)

            let alerts = analytics.stockAlerts()

            if alerts.isEmpty {
                ContentUnavailableView(
                    "All Stock Levels Good",
                    systemImage: "checkmark.circle.fill",
                    description: Text("No products are currently below par level")
                )
            } else {
                // Summary Stats
                HStack(spacing: 16) {
                    AlertStat(
                        count: alerts.filter { $0.stockLevel == "OUT OF STOCK" }.count,
                        label: "Out of Stock",
                        color: .red
                    )

                    AlertStat(
                        count: alerts.filter { $0.stockLevel == "CRITICAL" }.count,
                        label: "Critical",
                        color: .orange
                    )

                    AlertStat(
                        count: alerts.filter { $0.stockLevel == "LOW" }.count,
                        label: "Low",
                        color: .yellow
                    )
                }

                // Alert List
                VStack(spacing: 8) {
                    ForEach(alerts, id: \.product.id) { alert in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(alert.product.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                HStack(spacing: 12) {
                                    if let stock = alert.product.stockQuantity {
                                        Text("Stock: \(stock.plainString())")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    if let par = alert.product.parLevel {
                                        Text("Par: \(par.plainString())")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(alert.product.category.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Text(alert.stockLevel)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(alertColor(alert.stockLevel))
                                .clipShape(Capsule())
                        }
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                // Action Item
                VStack(alignment: .leading, spacing: 8) {
                    Label("Action Required", systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)

                    Text("Review and reorder these items to maintain optimal stock levels.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.red.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 86'd Items Section
    private var eightySixedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("86'd Items")
                .font(.headline)

            let eightySevenItems = analytics.eightySevenCount()

            if eightySevenItems.isEmpty {
                ContentUnavailableView(
                    "No 86'd Items",
                    systemImage: "checkmark.circle.fill",
                    description: Text("All products are currently available")
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Currently Unavailable")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(eightySevenItems, id: \.product) { item in
                        HStack {
                            Image(systemName: "exclamationmark.octagon.fill")
                                .foregroundStyle(.red)

                            Text(item.product)
                                .font(.subheadline)

                            Spacer()

                            Text("OUT")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.red)
                                .clipShape(Capsule())
                        }
                        .padding()
                        .background(.thinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 8) {
                    Label("Note", systemImage: "info.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)

                    Text("These items are currently marked as unavailable (86'd). Update inventory to make them available again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helper Functions
    private func alertColor(_ level: String) -> Color {
        switch level {
        case "OUT OF STOCK": return .red
        case "CRITICAL": return .orange
        case "LOW": return .yellow
        default: return .blue
        }
    }
}

// MARK: - Alert Stat Component
struct AlertStat: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
