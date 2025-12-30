import Foundation

// MARK: - Analytics Engine
struct AnalyticsEngine {
    let reports: [ShiftReport]
    let tickets: [CloseResult]
    
    init(reports: [ShiftReport], tickets: [CloseResult]) {
        self.reports = reports
        self.tickets = tickets
    }
    
    // MARK: - Time Analytics
    
    struct DayOfWeekStat: Identifiable {
        let id = UUID()
        let day: String
        let dayIndex: Int
        let sales: Decimal
        let ticketCount: Int
    }
    
    func dayOfWeekStats() -> [DayOfWeekStat] {
        let calendar = Calendar.current
        var stats: [Int: (sales: Decimal, count: Int)] = [:]
        
        for ticket in tickets {
            let weekday = calendar.component(.weekday, from: ticket.closedAt)
            stats[weekday, default: (0, 0)].sales += ticket.total
            stats[weekday, default: (0, 0)].count += 1
        }
        
        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return stats.map { weekday, data in
            DayOfWeekStat(
                day: dayNames[weekday - 1],
                dayIndex: weekday,
                sales: data.sales,
                ticketCount: data.count
            )
        }.sorted { $0.dayIndex < $1.dayIndex }
    }
    
    struct HourlyStat: Identifiable {
        let id = UUID()
        let hour: Int
        let sales: Decimal
        let ticketCount: Int
    }
    
    func hourlyStats() -> [HourlyStat] {
        let calendar = Calendar.current
        var stats: [Int: (sales: Decimal, count: Int)] = [:]
        
        for ticket in tickets {
            let hour = calendar.component(.hour, from: ticket.closedAt)
            stats[hour, default: (0, 0)].sales += ticket.total
            stats[hour, default: (0, 0)].count += 1
        }
        
        return stats.map { hour, data in
            HourlyStat(hour: hour, sales: data.sales, ticketCount: data.count)
        }.sorted { $0.hour < $1.hour }
    }
    
    struct DailyTrend: Identifiable {
        let id = UUID()
        let date: Date
        let sales: Decimal
        let ticketCount: Int
    }
    
    func dailyTrends() -> [DailyTrend] {
        let calendar = Calendar.current
        var stats: [Date: (sales: Decimal, count: Int)] = [:]
        
        for ticket in tickets {
            let day = calendar.startOfDay(for: ticket.closedAt)
            stats[day, default: (0, 0)].sales += ticket.total
            stats[day, default: (0, 0)].count += 1
        }
        
        return stats.map { date, data in
            DailyTrend(date: date, sales: data.sales, ticketCount: data.count)
        }.sorted { $0.date < $1.date }
    }
    
    // MARK: - Product Analytics
    
    struct ProductStat: Identifiable {
        let id = UUID()
        let product: String
        let quantity: Int
        let revenue: Decimal
    }
    
    func topProducts(limit: Int = 10) -> [ProductStat] {
        var productStats: [String: (qty: Int, revenue: Decimal)] = [:]
        
        for ticket in tickets {
            for line in ticket.lines {
                productStats[line.productName, default: (0, 0)].qty += line.qty
                productStats[line.productName, default: (0, 0)].revenue += line.lineTotal
            }
        }
        
        return productStats
            .map { name, data in
                ProductStat(product: name, quantity: data.qty, revenue: data.revenue)
            }
            .sorted { $0.revenue > $1.revenue }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: - Category Analytics
    
    struct CategoryStat: Identifiable {
        let id = UUID()
        let category: String
        let revenue: Decimal
        let ticketCount: Int
    }
    
    func categoryBreakdown() -> [CategoryStat] {
        // Since we don't have category info in LineSnapshot, we'll need to infer
        // For now, return placeholder that can be enhanced
        var categories: [String: (revenue: Decimal, count: Int)] = [:]
        
        for ticket in tickets {
            // Simplified: group by first word of product name
            for line in ticket.lines {
                let category = inferCategory(from: line.productName)
                categories[category, default: (0, 0)].revenue += line.lineTotal
                categories[category, default: (0, 0)].count += 1
            }
        }
        
        return categories.map { name, data in
            CategoryStat(category: name, revenue: data.revenue, ticketCount: data.count)
        }.sorted { $0.revenue > $1.revenue }
    }
    
    private func inferCategory(from productName: String) -> String {
        let lower = productName.lowercased()
        if lower.contains("beer") { return "Beer" }
        if lower.contains("wine") { return "Wine" }
        if lower.contains("vodka") || lower.contains("whiskey") || lower.contains("rum") || lower.contains("tequila") { return "Liquor" }
        if lower.contains("shot") { return "Shots" }
        if lower.contains("cocktail") { return "Cocktails" }
        if lower.contains("chip") { return "Chips" }
        return "Other"
    }
    
    // MARK: - Bartender Analytics
    
    struct BartenderStat: Identifiable {
        let id = UUID()
        let name: String
        let sales: Decimal
        let ticketCount: Int
        let avgTicket: Decimal
    }
    
    func bartenderStats() -> [BartenderStat] {
        var stats: [String: (sales: Decimal, count: Int)] = [:]
        
        for ticket in tickets {
            let name = ticket.bartenderName ?? "Unknown"
            stats[name, default: (0, 0)].sales += ticket.total
            stats[name, default: (0, 0)].count += 1
        }
        
        return stats.map { name, data in
            let avg = data.count > 0 ? data.sales / Decimal(data.count) : 0
            return BartenderStat(
                name: name,
                sales: data.sales,
                ticketCount: data.count,
                avgTicket: avg
            )
        }.sorted { $0.sales > $1.sales }
    }
    
    // MARK: - Summary Stats
    
    func totalRevenue() -> Decimal {
        tickets.reduce(0) { $0 + $1.total }
    }
    
    func totalTickets() -> Int {
        tickets.count
    }
    
    func averageTicket() -> Decimal {
        let total = totalRevenue()
        let count = totalTickets()
        return count > 0 ? total / Decimal(count) : 0
    }
}
