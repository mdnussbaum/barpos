import SwiftUI
import Charts

struct BartenderMetricsView: View {
    let analytics: AnalyticsEngine
    
    @State private var sortBy: SortOption = .sales
    
    enum SortOption: String, CaseIterable {
        case sales = "Sales"
        case tickets = "Tickets"
        case avgTicket = "Avg Ticket"
        
        var icon: String {
            switch self {
            case .sales: return "dollarsign.circle"
            case .tickets: return "receipt"
            case .avgTicket: return "chart.bar"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if analytics.tickets.isEmpty {
                    ContentUnavailableView(
                        "No Data Available",
                        systemImage: "person.2",
                        description: Text("Close some tabs to see bartender metrics")
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
                    
                    // Comparison chart
                    bartenderComparisonChart
                    
                    // Detailed cards
                    bartenderDetailCards
                }
            }
            .padding()
        }
        .navigationTitle("Bartender Metrics")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var sortedBartenders: [(name: String, sales: Decimal, tickets: Int, avgTicket: Decimal)] {
        let stats = analytics.bartenderStats()
        let tuples = stats.map { (name: $0.name, sales: $0.sales, tickets: $0.ticketCount, avgTicket: $0.avgTicket) }
        
        switch sortBy {
        case .sales:
            return tuples.sorted { $0.sales > $1.sales }
        case .tickets:
            return tuples.sorted { $0.tickets > $1.tickets }
        case .avgTicket:
            return tuples.sorted { $0.avgTicket > $1.avgTicket }
        }
    }
    
    private var bartenderComparisonChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Comparison")
                .font(.headline)
            
            Chart(sortedBartenders, id: \.name) { stat in
                BarMark(
                    x: .value("Bartender", stat.name),
                    y: .value("Sales", (stat.sales as NSDecimalNumber).doubleValue)
                )
                .foregroundStyle(.blue.gradient)
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
    
    private var bartenderDetailCards: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detailed Metrics")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(Array(sortedBartenders.enumerated()), id: \.offset) { index, stat in
                VStack(spacing: 12) {
                    HStack {
                        // Rank badge
                        Text("#\(index + 1)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(rankColor(index))
                            )
                        
                        // Name
                        VStack(alignment: .leading) {
                            Text(stat.name)
                                .font(.headline)
                            Text("Total Sales")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        // Total sales
                        Text(stat.sales.currencyString())
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                    
                    Divider()
                    
                    // Stats row
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tickets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(stat.tickets)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Avg Ticket")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(stat.avgTicket.currencyString())
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 2)
    }
    
    // MARK: - Helpers
    
    private func rankColor(_ index: Int) -> Color {
        switch index {
        case 0: return .yellow
        case 1: return .gray
        case 2: return .orange
        default: return .blue
        }
    }
}
