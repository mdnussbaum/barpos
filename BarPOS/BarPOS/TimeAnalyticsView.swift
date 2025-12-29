//
//  TimeAnalyticsView.swift
//  BarPOS
//
//  Created by Analytics Hub
//

import SwiftUI
import Charts

struct TimeAnalyticsView: View {
    let analytics: AnalyticsEngine

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if analytics.tickets.isEmpty {
                    ContentUnavailableView(
                        "No Data Available",
                        systemImage: "clock",
                        description: Text("No sales data found for the selected date range")
                    )
                } else {
                    // MARK: - Day of Week Breakdown
                    dayOfWeekSection

                    // MARK: - Hourly Heatmap
                    hourlyHeatmapSection

                    // MARK: - Daily Trends
                    dailyTrendsSection

                    // MARK: - Peak Performance
                    peakPerformanceSection
                }
            }
            .padding()
        }
        .navigationTitle("Time Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Day of Week Section
    private var dayOfWeekSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sales by Day of Week")
                .font(.headline)

            let dayStats = sortedDayStats

            Chart(dayStats, id: \.day) { stat in
                BarMark(
                    x: .value("Day", stat.day),
                    y: .value("Sales", stat.sales as NSDecimalNumber)
                )
                .foregroundStyle(.blue)
                .annotation(position: .top) {
                    Text(stat.sales.currencyString())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 250)

            // Detailed breakdown
            VStack(spacing: 8) {
                ForEach(dayStats, id: \.day) { stat in
                    HStack {
                        Text(stat.day)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(width: 100, alignment: .leading)

                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.blue.opacity(0.3))
                                .frame(width: geo.size.width * CGFloat(truncating: (stat.sales / maxDaySales) as NSDecimalNumber))
                                .frame(height: 20)
                                .overlay(alignment: .leading) {
                                    Text(stat.sales.currencyString())
                                        .font(.caption)
                                        .padding(.leading, 8)
                                }
                        }
                        .frame(height: 20)
                    }
                    .padding(.vertical, 4)
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

    // MARK: - Hourly Heatmap Section
    private var hourlyHeatmapSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hourly Sales Heatmap")
                .font(.headline)

            let hourStats = analytics.salesByHour()
                .map { (hour: $0.key, sales: $0.value) }
                .sorted { $0.hour < $1.hour }

            if hourStats.isEmpty {
                Text("No hourly data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                Chart(hourStats, id: \.hour) { stat in
                    BarMark(
                        x: .value("Hour", formatHour(stat.hour)),
                        y: .value("Sales", stat.sales as NSDecimalNumber)
                    )
                    .foregroundStyle(heatmapColor(for: stat.sales))
                }
                .frame(height: 250)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                    }
                }

                // Peak hours callout
                VStack(alignment: .leading, spacing: 8) {
                    Text("Peak Hours")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    let topHours = analytics.peakHours()
                    ForEach(Array(topHours.enumerated()), id: \.element.hour) { index, peak in
                        HStack {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 20)

                            Text(formatHour(peak.hour))
                                .font(.subheadline)

                            Spacer()

                            Text(peak.sales.currencyString())
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Daily Trends Section
    private var dailyTrendsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Sales Trend")
                .font(.headline)

            let trends = analytics.dailyTrends()

            if trends.isEmpty {
                Text("No trend data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                Chart(trends, id: \.date) { trend in
                    LineMark(
                        x: .value("Date", trend.date),
                        y: .value("Sales", trend.sales as NSDecimalNumber)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", trend.date),
                        y: .value("Sales", trend.sales as NSDecimalNumber)
                    )
                    .foregroundStyle(.blue.opacity(0.2))
                    .interpolationMethod(.catmullRom)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(formatDate(date))
                                    .font(.caption2)
                            }
                        }
                    }
                }

                // Summary stats
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Avg Daily")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(avgDailySales.currencyString())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Best Day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(maxDailySales.currencyString())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Worst Day")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(minDailySales.currencyString())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Peak Performance Section
    private var peakPerformanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Best & Worst Days")
                .font(.headline)

            HStack(spacing: 16) {
                // Best Day
                if let best = analytics.bestPerformingDay() {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Best Day", systemImage: "trophy.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)

                        Text(best.day)
                            .font(.title3)
                            .fontWeight(.bold)

                        Text(best.sales.currencyString())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Worst Day
                if let worst = analytics.worstPerformingDay() {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Worst Day", systemImage: "arrow.down.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)

                        Text(worst.day)
                            .font(.title3)
                            .fontWeight(.bold)

                        Text(worst.sales.currencyString())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helper Functions
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func heatmapColor(for sales: Decimal) -> Color {
        let maxSales = analytics.salesByHour().values.max() ?? 1
        let ratio = Double(truncating: (sales / maxSales) as NSDecimalNumber)

        if ratio > 0.75 {
            return .red
        } else if ratio > 0.5 {
            return .orange
        } else if ratio > 0.25 {
            return .yellow
        } else {
            return .blue
        }
    }

    // MARK: - Computed Properties
    private var sortedDayStats: [(day: String, sales: Decimal)] {
        let dayOrder = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let dayStats = analytics.salesByDayOfWeek()

        return dayOrder.compactMap { day in
            guard let sales = dayStats[day] else { return nil }
            return (day: day, sales: sales)
        }
    }

    private var maxDaySales: Decimal {
        sortedDayStats.map { $0.sales }.max() ?? 1
    }

    private var avgDailySales: Decimal {
        let trends = analytics.dailyTrends()
        guard !trends.isEmpty else { return 0 }
        let total = trends.reduce(0) { $0 + $1.sales }
        return total / Decimal(trends.count)
    }

    private var maxDailySales: Decimal {
        analytics.dailyTrends().map { $0.sales }.max() ?? 0
    }

    private var minDailySales: Decimal {
        analytics.dailyTrends().map { $0.sales }.min() ?? 0
    }
}
