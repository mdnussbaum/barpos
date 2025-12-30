import SwiftUI

struct AnalyticsView: View {
    @EnvironmentObject var vm: InventoryVM
    
    @State private var dateRange: DateRange = .last30Days
    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    
    enum DateRange: String, CaseIterable {
        case today = "Today"
        case last7Days = "Last 7 Days"
        case last30Days = "Last 30 Days"
        case last90Days = "Last 90 Days"
        case custom = "Custom"
        
        var days: Int? {
            switch self {
            case .today: return 0
            case .last7Days: return 7
            case .last30Days: return 30
            case .last90Days: return 90
            case .custom: return nil
            }
        }
    }
    
    private var filteredTickets: [CloseResult] {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)) ?? Date()
        
        return vm.allClosedTabs.filter { ticket in
            ticket.closedAt >= start && ticket.closedAt < end
        }
    }
    
    private var filteredReports: [ShiftReport] {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)) ?? Date()
        
        return vm.shiftReports.filter { report in
            report.endedAt >= start && report.endedAt < end
        }
    }
    
    private var analytics: AnalyticsEngine {
        AnalyticsEngine(reports: filteredReports, tickets: filteredTickets)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Date Range Picker
                Section {
                    Picker("Date Range", selection: $dateRange) {
                        ForEach(DateRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: dateRange) { _, newValue in
                        updateDateRange(newValue)
                    }
                    
                    if dateRange == .custom {
                        DatePicker("Start", selection: $startDate, displayedComponents: .date)
                        DatePicker("End", selection: $endDate, displayedComponents: .date)
                    }
                }
                
                // Summary Cards
                Section {
                    HStack(spacing: 16) {
                        summaryCard(
                            title: "Revenue",
                            value: analytics.totalRevenue().currencyString(),
                            icon: "dollarsign.circle.fill",
                            color: .green
                        )
                        
                        summaryCard(
                            title: "Tickets",
                            value: "\(analytics.totalTickets())",
                            icon: "receipt.fill",
                            color: .blue
                        )
                        
                        summaryCard(
                            title: "Avg Ticket",
                            value: analytics.averageTicket().currencyString(),
                            icon: "chart.bar.fill",
                            color: .orange
                        )
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                
                // Analytics Sections
                Section("Detailed Analytics") {
                    NavigationLink {
                        TimeAnalyticsView(analytics: analytics)
                    } label: {
                        Label("Time Analytics", systemImage: "clock.fill")
                    }
                    
                    NavigationLink {
                        ProductPerformanceView(analytics: analytics)
                    } label: {
                        Label("Product Performance", systemImage: "shippingbox.fill")
                    }
                    
                    NavigationLink {
                        CategoryBreakdownView(analytics: analytics)
                    } label: {
                        Label("Category Breakdown", systemImage: "chart.pie.fill")
                    }
                    
                    NavigationLink {
                        BartenderMetricsView(analytics: analytics)
                    } label: {
                        Label("Bartender Metrics", systemImage: "person.2.fill")
                    }
                }
                
                Section("Export") {
                    NavigationLink {
                        ExportToolsView(
                            analytics: analytics,
                            dateRange: (start: startDate, end: endDate)
                        )
                    } label: {
                        Label("Export Tools", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .navigationTitle("Analytics")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func updateDateRange(_ range: DateRange) {
        guard let days = range.days else { return }
        
        endDate = Date()
        if days == 0 {
            startDate = Calendar.current.startOfDay(for: Date())
        } else {
            startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        }
    }
    
    @ViewBuilder
    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

