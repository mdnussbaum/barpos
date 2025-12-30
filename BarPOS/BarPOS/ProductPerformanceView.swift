import SwiftUI
import Charts

struct ProductPerformanceView: View {
    let analytics: AnalyticsEngine
    
    @State private var sortBy: SortOption = .revenue
    
    enum SortOption: String, CaseIterable {
        case revenue = "Revenue"
        case quantity = "Quantity"
        
        var icon: String {
            switch self {
            case .revenue: return "dollarsign.circle"
            case .quantity: return "number.circle"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if analytics.tickets.isEmpty {
                    ContentUnavailableView(
                        "No Data Available",
                        systemImage: "shippingbox",
                        description: Text("Close some tabs to see product performance")
                    )
                } else {
                    // Sort picker
                    Picker("Sort By", selection: $sortBy) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Label(option.rawValue, systemImage: option.icon).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Top products chart
                    topProductsChart
                    
                    // Detailed list
                    topProductsList
                }
            }
            .padding()
        }
        .navigationTitle("Product Performance")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var topProducts: [(product: String, quantity: Int, revenue: Decimal)] {
        let products = analytics.topProducts(limit: 20)
        
        switch sortBy {
        case .revenue:
            return products.map { (product: $0.product, quantity: $0.quantity, revenue: $0.revenue) }
                .sorted { $0.revenue > $1.revenue }
        case .quantity:
            return products.map { (product: $0.product, quantity: $0.quantity, revenue: $0.revenue) }
                .sorted { $0.quantity > $1.quantity }
        }
    }
    
    private var topProductsChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top 10 Products")
                .font(.headline)
            
            let chartData = Array(topProducts.prefix(10))
            
            Chart(chartData, id: \.product) { item in
                BarMark(
                    x: .value("Revenue", (item.revenue as NSDecimalNumber).doubleValue),
                    y: .value("Product", item.product)
                )
                .foregroundStyle(.blue.gradient)
            }
            .frame(height: 300)
            .chartXAxis {
                AxisMarks(position: .bottom)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 2)
    }
    
    private var topProductsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Products")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(Array(topProducts.enumerated()), id: \.offset) { index, item in
                HStack {
                    // Rank
                    Text("#\(index + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .frame(width: 30)
                    
                    // Product name
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.product)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(item.quantity) sold")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Revenue
                    Text(item.revenue.currencyString())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 2)
    }
}
