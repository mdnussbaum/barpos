//
//  AnalyticsView.swift
//  BarPOS
//
//  Created by Analytics Hub
//

import SwiftUI

enum DateRangePreset: String, CaseIterable, Identifiable {
    case last7Days = "Last 7 Days"
    case last30Days = "Last 30 Days"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case custom = "Custom Range"

    var id: String { rawValue }
}

struct AnalyticsView: View {
    @EnvironmentObject var vm: InventoryVM

    @State private var selectedPreset: DateRangePreset = .last7Days
    @State private var customStartDate = Date()
    @State private var customEndDate = Date()
    @State private var showingDatePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Date Range Picker
                    dateRangePicker

                    // MARK: - Summary Cards
                    summaryCards

                    // MARK: - Analytics Navigation
                    analyticsNavigation
                }
                .padding()
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Date Range Picker
    private var dateRangePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Date Range")
                .font(.headline)

            Picker("Range", selection: $selectedPreset) {
                ForEach(DateRangePreset.allCases) { preset in
                    Text(preset.rawValue).tag(preset)
                }
            }
            .pickerStyle(.segmented)

            if selectedPreset == .custom {
                VStack(spacing: 8) {
                    DatePicker("Start Date", selection: $customStartDate, displayedComponents: .date)
                    DatePicker("End Date", selection: $customEndDate, displayedComponents: .date)
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text(dateRangeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Summary Cards
    private var summaryCards: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            SummaryCard(
                title: "Revenue",
                value: analytics.totalRevenue().currencyString(),
                icon: "dollarsign.circle.fill",
                color: .blue
            )

            SummaryCard(
                title: "Tickets",
                value: "\(analytics.totalTickets())",
                icon: "receipt.fill",
                color: .green
            )

            SummaryCard(
                title: "Avg Ticket",
                value: analytics.averageTicketSize().currencyString(),
                icon: "chart.bar.fill",
                color: .orange
            )

            SummaryCard(
                title: "Items Sold",
                value: "\(analytics.totalItemsSold())",
                icon: "shippingbox.fill",
                color: .purple
            )
        }
    }

    // MARK: - Analytics Navigation
    private var analyticsNavigation: some View {
        VStack(spacing: 12) {
            Text("Detailed Reports")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            NavigationLink {
                ProductPerformanceView(analytics: analytics)
            } label: {
                AnalyticsNavCard(
                    title: "Product Performance",
                    subtitle: "Top sellers, margins & trends",
                    icon: "chart.bar.xaxis",
                    color: .blue
                )
            }

            NavigationLink {
                TimeAnalyticsView(analytics: analytics)
            } label: {
                AnalyticsNavCard(
                    title: "Time Analytics",
                    subtitle: "Day/hour breakdown & trends",
                    icon: "clock.fill",
                    color: .green
                )
            }

            NavigationLink {
                BartenderMetricsView(analytics: analytics)
            } label: {
                AnalyticsNavCard(
                    title: "Bartender Metrics",
                    subtitle: "Sales & performance by staff",
                    icon: "person.2.fill",
                    color: .orange
                )
            }

            NavigationLink {
                CategoryBreakdownView(analytics: analytics)
            } label: {
                AnalyticsNavCard(
                    title: "Category Breakdown",
                    subtitle: "Beer, liquor, wine & more",
                    icon: "chart.pie.fill",
                    color: .purple
                )
            }

            NavigationLink {
                InventoryAnalyticsView(analytics: analytics)
            } label: {
                AnalyticsNavCard(
                    title: "Inventory Insights",
                    subtitle: "Fast/slow movers & alerts",
                    icon: "shippingbox.fill",
                    color: .red
                )
            }

            NavigationLink {
                ExportToolsView(analytics: analytics, dateRange: dateRange)
            } label: {
                AnalyticsNavCard(
                    title: "Export Tools",
                    subtitle: "CSV & PDF reports",
                    icon: "square.and.arrow.up.fill",
                    color: .indigo
                )
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Computed Properties
    private var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()

        switch selectedPreset {
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start: calendar.startOfDay(for: start), end: now)

        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return (start: calendar.startOfDay(for: start), end: now)

        case .thisMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            return (start: start, end: now)

        case .lastMonth:
            let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: lastMonth)) ?? now
            let end = calendar.date(byAdding: .day, value: -1, to: calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now) ?? now
            return (start: start, end: end)

        case .custom:
            return (start: calendar.startOfDay(for: customStartDate), end: customEndDate)
        }
    }

    private var dateRangeDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium

        return "\(formatter.string(from: dateRange.start)) - \(formatter.string(from: dateRange.end))"
    }

    private var analytics: AnalyticsEngine {
        AnalyticsEngine(
            reports: vm.shiftReports,
            products: vm.products,
            dateRange: dateRange
        )
    }
}

// MARK: - Summary Card Component
struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Analytics Nav Card Component
struct AnalyticsNavCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
