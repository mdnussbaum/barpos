import SwiftUI
import Charts

struct CategoryBreakdownView: View {
    let analytics: AnalyticsEngine
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if analytics.tickets.isEmpty {
                    ContentUnavailableView(
                        "No Data Available",
                        systemImage: "chart.pie",
                        description: Text("Close some tabs to see category breakdown")
                    )
                } else {
                    // Pie chart
                    categoryPieChart
                    
                    // Stats grid
                    categoryStatsGrid
                    
                    // Comparison chart
                    categoryComparisonChart
                }
            }
            .padding()
        }
        .navigationTitle("Category Breakdown")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var categoryPieChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Revenue by Category")
                .font(.headline)
            
            let categories = analytics.categoryBreakdown()
            
            Chart(categories) { data in
                SectorMark(
                    angle: .value("Revenue", (data.revenue as NSDecimalNumber).doubleValue),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(by: .value("Category", data.category))
            }
            .frame(height: 300)
            
            // Legend
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(categories) { data in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colorForCategory(data.category))
                            .frame(width: 12, height: 12)
                        Text(data.category)
                            .font(.caption)
                        Spacer()
                    }
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 2)
    }
    
    private var categoryStatsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Details")
                .font(.headline)
            
            let categories = analytics.categoryBreakdown()
            let totalRevenue = categories.reduce(0) { $0 + $1.revenue }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(categories) { data in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Circle()
                                .fill(colorForCategory(data.category))
                                .frame(width: 8, height: 8)
                            Text(data.category)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        
                        Text(data.revenue.currencyString())
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        HStack {
                            Text("\(data.ticketCount) items")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if totalRevenue > 0 {
                                let percentage = (data.revenue / totalRevenue) * 100
                                Text("\(Int(percentage.rounded()))%")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(colorForCategory(data.category))
                            }
                        }
                    }
                    .padding()
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
    
    private var categoryComparisonChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Comparison")
                .font(.headline)
            
            let categories = analytics.categoryBreakdown()
            
            Chart(categories) { data in
                BarMark(
                    x: .value("Category", data.category),
                    y: .value("Revenue", (data.revenue as NSDecimalNumber).doubleValue)
                )
                .foregroundStyle(colorForCategory(data.category))
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 2)
    }
    
    // MARK: - Helpers
    
    private func colorForCategory(_ category: String) -> Color {
        switch category.lowercased() {
        case "beer": return .orange
        case "wine": return .purple
        case "liquor": return .blue
        case "shots": return .red
        case "cocktails": return .pink
        case "chips": return .green
        default: return .gray
        }
    }
}
