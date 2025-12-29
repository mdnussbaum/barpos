//
//  BartenderMetricsView.swift
//  BarPOS
//
//  Created by Analytics Hub
//

import SwiftUI
import Charts

struct BartenderMetricsView: View {
    let analytics: AnalyticsEngine

    @State private var sortBy: SortOption = .sales

    enum SortOption: String, CaseIterable {
        case sales = "Total Sales"
        case tickets = "Tickets"
        case avgTicket = "Avg Ticket"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if analytics.tickets.isEmpty {
                    ContentUnavailableView(
                        "No Data Available",
                        systemImage: "person.2",
                        description: Text("No bartender data found for the selected date range")
                    )
                } else {
                    // MARK: - Controls
                    controlSection

                    // MARK: - Sales Leaderboard
                    salesLeaderboardSection

                    // MARK: - Performance Comparison
                    performanceComparisonSection

                    // MARK: - Individual Stats
                    individualStatsSection
                }
            }
            .padding()
        }
        .navigationTitle("Bartender Metrics")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Control Section
    private var controlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sort By")
                .font(.headline)

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

    // MARK: - Sales Leaderboard Section
    private var salesLeaderboardSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sales Leaderboard")
                .font(.headline)

            Chart(sortedBartenders) { stat in
                BarMark(
                    x: .value("Sales", stat.sales as NSDecimalNumber),
                    y: .value("Bartender", stat.name)
                )
                .foregroundStyle(.blue)
                .annotation(position: .trailing) {
                    Text(stat.sales.currencyString())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: max(CGFloat(sortedBartenders.count * 60), 200))

            // Medals for top 3
            if sortedBartenders.count >= 3 {
                HStack(spacing: 16) {
                    // 2nd Place
                    VStack(spacing: 8) {
                        Text("🥈")
                            .font(.largeTitle)
                        Text(sortedBartenders[1].name)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                        Text(sortedBartenders[1].sales.currencyString())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // 1st Place (larger)
                    VStack(spacing: 8) {
                        Text("🥇")
                            .font(.system(size: 50))
                        Text(sortedBartenders[0].name)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        Text(sortedBartenders[0].sales.currencyString())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.yellow.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // 3rd Place
                    VStack(spacing: 8) {
                        Text("🥉")
                            .font(.largeTitle)
                        Text(sortedBartenders[2].name)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                        Text(sortedBartenders[2].sales.currencyString())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
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

    // MARK: - Performance Comparison Section
    private var performanceComparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Metrics")
                .font(.headline)

            // Average Ticket Size Comparison
            VStack(alignment: .leading, spacing: 12) {
                Text("Average Ticket Size")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                let maxAvgTicket = sortedBartenders.map { $0.avgTicket }.max() ?? 1

                ForEach(sortedBartenders, id: \.name) { stat in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(stat.name)
                                .font(.caption)
                                .frame(width: 100, alignment: .leading)

                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(.green.opacity(0.3))
                                    .frame(width: geo.size.width * CGFloat(truncating: (stat.avgTicket / maxAvgTicket) as NSDecimalNumber))
                                    .frame(height: 20)
                                    .overlay(alignment: .leading) {
                                        Text(stat.avgTicket.currencyString())
                                            .font(.caption2)
                                            .padding(.leading, 8)
                                    }
                            }
                            .frame(height: 20)
                        }
                    }
                }
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Tickets Per Hour Comparison
            VStack(alignment: .leading, spacing: 12) {
                Text("Tickets Per Hour")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                ForEach(sortedBartenders, id: \.name) { stat in
                    HStack {
                        Text(stat.name)
                            .font(.caption)
                            .frame(width: 100, alignment: .leading)

                        Spacer()

                        let tph = analytics.ticketsPerHour(bartender: stat.name)
                        Text(String(format: "%.1f tickets/hr", Double(truncating: tph as NSDecimalNumber)))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Individual Stats Section
    private var individualStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Detailed Statistics")
                .font(.headline)

            ForEach(sortedBartenders, id: \.name) { stat in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(stat.name)
                            .font(.subheadline)
                            .fontWeight(.bold)

                        Spacer()

                        Text(stat.sales.currencyString())
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                    }

                    Divider()

                    // Metrics Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        MetricCell(
                            title: "Total Tickets",
                            value: "\(stat.tickets)",
                            icon: "receipt.fill",
                            color: .green
                        )

                        MetricCell(
                            title: "Avg Ticket",
                            value: stat.avgTicket.currencyString(),
                            icon: "chart.bar.fill",
                            color: .orange
                        )

                        MetricCell(
                            title: "Tickets/Hour",
                            value: String(format: "%.1f", Double(truncating: analytics.ticketsPerHour(bartender: stat.name) as NSDecimalNumber)),
                            icon: "clock.fill",
                            color: .purple
                        )

                        MetricCell(
                            title: "% of Total",
                            value: String(format: "%.1f%%", Double(truncating: (stat.sales / totalSales * 100) as NSDecimalNumber)),
                            icon: "percent",
                            color: .indigo
                        )
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Computed Properties
    private var sortedBartenders: [(name: String, sales: Decimal, tickets: Int, avgTicket: Decimal)] {
        let stats = analytics.salesByBartender()

        switch sortBy {
        case .sales:
            return stats.sorted { $0.sales > $1.sales }
        case .tickets:
            return stats.sorted { $0.tickets > $1.tickets }
        case .avgTicket:
            return stats.sorted { $0.avgTicket > $1.avgTicket }
        }
    }

    private var totalSales: Decimal {
        analytics.totalRevenue()
    }
}

// MARK: - Metric Cell Component
struct MetricCell: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.headline)
                .fontWeight(.bold)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
