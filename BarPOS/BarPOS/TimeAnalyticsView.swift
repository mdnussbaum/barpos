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
                        systemImage: "chart.bar.xaxis",
                        description: Text("Close some tabs to see time-based analytics")
                    )
                } else {
                    // MARK: - Day of Week Section
                    dayOfWeekSection
                    
                    // MARK: - Hourly Heatmap Section
                    hourlyHeatmapSection
                    
                    // MARK: - Daily Trends Section
                    dailyTrendsSection
                    
                    // MARK: - Peak Performance Section
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Sales by Day of Week")
                .font(.headline)
            
            let stats = analytics.dayOfWeekStats()
            
            Chart(stats, id: \.day) { stat in
                BarMark(
                    x: .value("Day", stat.day),
                    y: .value("Sales", (stat.sales as NSDecimalNumber).doubleValue)
                )
                .foregroundStyle(.blue.gradient)
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            
            // Stats grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(stats) { stat in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(stat.day)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(stat.sales.currencyString())
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("\(stat.ticketCount) tickets")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 2)
    }
    
    // MARK: - Hourly Heatmap Section
    
    private var hourlyHeatmapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sales by Hour")
                .font(.headline)
            
            let stats = analytics.hourlyStats()
            
            Chart(stats, id: \.hour) { stat in
                BarMark(
                    x: .value("Hour", stat.hour),
                    y: .value("Sales", (stat.sales as NSDecimalNumber).doubleValue)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [.orange, .red],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            }
            .frame(height: 200)
            .chartXAxis {
                AxisMarks(values: .stride(by: 2)) { value in
                    if let hour = value.as(Int.self) {
                        AxisValueLabel {
                            Text(formatHour(hour))
                        }
                    }
                }
            }
            
            // Peak hours
            if let peak = stats.max(by: { $0.sales < $1.sales }) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.orange)
                    Text("Peak Hour: \(formatHour(peak.hour))")
                        .font(.subheadline)
                    Spacer()
                    Text(peak.sales.currencyString())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 2)
    }
    
    // MARK: - Daily Trends Section
    
    private var dailyTrendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Sales Trend")
                .font(.headline)
            
            let trends = analytics.dailyTrends()
            
            if trends.count > 1 {
                Chart(trends) { trend in
                    LineMark(
                        x: .value("Date", trend.date),
                        y: .value("Sales", (trend.sales as NSDecimalNumber).doubleValue)
                    )
                    .foregroundStyle(.green)
                    
                    AreaMark(
                        x: .value("Date", trend.date),
                        y: .value("Sales", (trend.sales as NSDecimalNumber).doubleValue)
                    )
                    .foregroundStyle(.green.opacity(0.2))
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
            } else {
                Text("Need at least 2 days of data for trend analysis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 2)
    }
    
    // MARK: - Peak Performance Section
    
    private var peakPerformanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Peak Performance")
                .font(.headline)
            
            let stats = analytics.dayOfWeekStats()
            let bestDay = stats.max(by: { $0.sales < $1.sales })
            
            let hourlyStats = analytics.hourlyStats()
            let bestHour = hourlyStats.max(by: { $0.sales < $1.sales })
            
            VStack(spacing: 12) {
                if let bestDay = bestDay {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Best Day")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(bestDay.day)
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        Text(bestDay.sales.currencyString())
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                if let bestHour = bestHour {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Best Hour")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(formatHour(bestHour.hour))
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                        Spacer()
                        Text(bestHour.sales.currencyString())
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 2)
    }
    
    // MARK: - Helpers
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date).lowercased()
    }
}
