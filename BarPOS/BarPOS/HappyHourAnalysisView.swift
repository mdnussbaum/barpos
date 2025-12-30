import SwiftUI
import Charts

struct HappyHourAnalysisView: View {
    let analytics: AnalyticsEngine

    @State private var priceAdjustment: Double = 0
    @State private var volumeChange: Double = 0

    private var timeSlotStats: [AnalyticsEngine.TimeSlotStat] {
        analytics.timeSlotStats()
    }

    private var mostProfitableSlot: AnalyticsEngine.TimeSlotStat? {
        timeSlotStats.max(by: { $0.revenue < $1.revenue })
    }

    var body: some View {
        List {
            // Revenue Comparison Chart
            Section("Revenue by Time Slot") {
                revenueChart
                    .frame(height: 250)
                    .padding(.vertical, 8)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            // Time Slot Breakdown
            Section("Time Slot Performance") {
                ForEach(timeSlotStats) { stat in
                    timeSlotCard(stat)
                }
            }

            // What-If Calculator
            Section("Happy Hour Optimizer") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("What-If Analysis")
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Price Adjustment:")
                                .font(.subheadline)
                            Spacer()
                            Text("\(priceAdjustment, specifier: "%.0f")%")
                                .font(.subheadline)
                                .foregroundStyle(priceAdjustment < 0 ? .green : .primary)
                        }

                        Slider(value: $priceAdjustment, in: -50...50, step: 5)
                            .tint(priceAdjustment < 0 ? .green : .blue)

                        Text("Adjust prices during happy hour")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Expected Volume Change:")
                                .font(.subheadline)
                            Spacer()
                            Text("\(volumeChange, specifier: "%.0f")%")
                                .font(.subheadline)
                                .foregroundStyle(volumeChange > 0 ? .green : .primary)
                        }

                        Slider(value: $volumeChange, in: -50...200, step: 10)
                            .tint(volumeChange > 0 ? .green : .blue)

                        Text("Estimate customer traffic increase")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    breakEvenAnalysis
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Happy Hour Analysis")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var revenueChart: some View {
        if !timeSlotStats.isEmpty {
            Chart(timeSlotStats) { stat in
                BarMark(
                    x: .value("Time Slot", stat.slot.rawValue),
                    y: .value("Revenue", (stat.revenue as NSDecimalNumber).doubleValue)
                )
                .foregroundStyle(
                    stat.slot == mostProfitableSlot?.slot ? .green : .blue
                )
                .annotation(position: .top) {
                    if stat.ticketCount > 0 {
                        Text(stat.revenue.currencyString())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        } else {
            Text("No data available for time slot analysis")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
        }
    }

    @ViewBuilder
    private func timeSlotCard(_ stat: AnalyticsEngine.TimeSlotStat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(stat.slot.rawValue)
                    .font(.headline)

                if stat.slot == mostProfitableSlot?.slot {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }

                Spacer()

                Text(stat.revenue.currencyString())
                    .font(.headline)
                    .foregroundStyle(.green)
            }

            HStack(spacing: 20) {
                metricView(
                    label: "Tickets",
                    value: "\(stat.ticketCount)",
                    icon: "receipt"
                )

                metricView(
                    label: "Avg Ticket",
                    value: stat.avgTicket.currencyString(),
                    icon: "chart.bar"
                )
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func metricView(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
            }
        }
    }

    @ViewBuilder
    private var breakEvenAnalysis: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Break-Even Analysis")
                .font(.headline)

            if let bestSlot = mostProfitableSlot {
                let currentRevenue = (bestSlot.revenue as NSDecimalNumber).doubleValue
                let priceMultiplier = 1.0 + (priceAdjustment / 100.0)
                let volumeMultiplier = 1.0 + (volumeChange / 100.0)
                let projectedRevenue = currentRevenue * priceMultiplier * volumeMultiplier
                let difference = projectedRevenue - currentRevenue
                let isProfitable = difference > 0

                VStack(spacing: 8) {
                    HStack {
                        Text("Current Revenue:")
                            .font(.subheadline)
                        Spacer()
                        Text(currentRevenue.currencyString())
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("Projected Revenue:")
                            .font(.subheadline)
                        Spacer()
                        Text(projectedRevenue.currencyString())
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(isProfitable ? .green : .red)
                    }

                    Divider()

                    HStack {
                        Text("Net Impact:")
                            .font(.headline)
                        Spacer()
                        Text("\(isProfitable ? "+" : "")\(difference.currencyString())")
                            .font(.headline)
                            .foregroundStyle(isProfitable ? .green : .red)
                    }

                    if isProfitable {
                        Label("This happy hour strategy could increase revenue!", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Label("This strategy may reduce revenue. Consider adjusting.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding()
                .background(isProfitable ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("No data available for analysis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// Helper extension for currency formatting
extension Double {
    func currencyString() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: self)) ?? "$0.00"
    }
}
