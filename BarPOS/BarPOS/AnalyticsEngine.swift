//
//  AnalyticsEngine.swift
//  BarPOS
//
//  Created by Analytics Hub
//

import Foundation

struct AnalyticsEngine {
    let reports: [ShiftReport]
    let products: [Product]
    let dateRange: (start: Date, end: Date)

    // MARK: - Computed Properties

    /// All tickets within the date range across all shift reports
    var tickets: [CloseResult] {
        reports
            .filter { report in
                report.startedAt >= dateRange.start && report.startedAt <= dateRange.end
            }
            .flatMap { $0.tickets }
            .filter { ticket in
                ticket.closedAt >= dateRange.start && ticket.closedAt <= dateRange.end
            }
    }

    // MARK: - Product Performance

    func topSellingProducts(limit: Int = 10) -> [(product: String, quantity: Int, revenue: Decimal)] {
        var productStats: [String: (quantity: Int, revenue: Decimal)] = [:]

        for ticket in tickets {
            for line in ticket.lines {
                let current = productStats[line.productName, default: (quantity: 0, revenue: 0)]
                productStats[line.productName] = (
                    quantity: current.quantity + line.qty,
                    revenue: current.revenue + line.lineTotal
                )
            }
        }

        return productStats
            .map { (product: $0.key, quantity: $0.value.quantity, revenue: $0.value.revenue) }
            .sorted { $0.revenue > $1.revenue }
            .prefix(limit)
            .map { $0 }
    }

    func categoryBreakdown() -> [ProductCategory: (quantity: Int, revenue: Decimal)] {
        var categoryStats: [ProductCategory: (quantity: Int, revenue: Decimal)] = [:]

        for ticket in tickets {
            for line in ticket.lines {
                // Find the product by name to get its category
                if let product = products.first(where: { $0.name == line.productName }) {
                    let current = categoryStats[product.category, default: (quantity: 0, revenue: 0)]
                    categoryStats[product.category] = (
                        quantity: current.quantity + line.qty,
                        revenue: current.revenue + line.lineTotal
                    )
                }
            }
        }

        return categoryStats
    }

    func productMargins() -> [(product: String, margin: Decimal, cost: Decimal, price: Decimal)] {
        var margins: [(product: String, margin: Decimal, cost: Decimal, price: Decimal)] = []

        for product in products {
            guard let margin = product.profitMargin,
                  let cost = product.cost else { continue }

            margins.append((
                product: product.name,
                margin: margin,
                cost: cost,
                price: product.price
            ))
        }

        return margins.sorted { $0.margin > $1.margin }
    }

    // MARK: - Time Analytics

    func salesByDayOfWeek() -> [String: Decimal] {
        var dayStats: [String: Decimal] = [:]
        let calendar = Calendar.current
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "EEEE" // Monday, Tuesday, etc.

        for ticket in tickets {
            let dayName = weekdayFormatter.string(from: ticket.closedAt)
            dayStats[dayName, default: 0] += ticket.total
        }

        return dayStats
    }

    func salesByHour() -> [Int: Decimal] {
        var hourStats: [Int: Decimal] = [:]
        let calendar = Calendar.current

        for ticket in tickets {
            let hour = calendar.component(.hour, from: ticket.closedAt)
            hourStats[hour, default: 0] += ticket.total
        }

        return hourStats
    }

    func dailyTrends() -> [(date: Date, sales: Decimal)] {
        var dailyStats: [Date: Decimal] = [:]
        let calendar = Calendar.current

        for ticket in tickets {
            let startOfDay = calendar.startOfDay(for: ticket.closedAt)
            dailyStats[startOfDay, default: 0] += ticket.total
        }

        return dailyStats
            .map { (date: $0.key, sales: $0.value) }
            .sorted { $0.date < $1.date }
    }

    func bestPerformingDay() -> (day: String, sales: Decimal)? {
        let dayStats = salesByDayOfWeek()
        guard let best = dayStats.max(by: { $0.value < $1.value }) else { return nil }
        return (day: best.key, sales: best.value)
    }

    func worstPerformingDay() -> (day: String, sales: Decimal)? {
        let dayStats = salesByDayOfWeek()
        guard let worst = dayStats.min(by: { $0.value < $1.value }) else { return nil }
        return (day: worst.key, sales: worst.value)
    }

    func peakHours() -> [(hour: Int, sales: Decimal)] {
        salesByHour()
            .map { (hour: $0.key, sales: $0.value) }
            .sorted { $0.sales > $1.sales }
            .prefix(5)
            .map { $0 }
    }

    // MARK: - Bartender Metrics

    func salesByBartender() -> [(name: String, sales: Decimal, tickets: Int, avgTicket: Decimal)] {
        var bartenderStats: [String: (sales: Decimal, tickets: Int)] = [:]

        for ticket in tickets {
            let name = ticket.bartenderName ?? "Unknown"
            let current = bartenderStats[name, default: (sales: 0, tickets: 0)]
            bartenderStats[name] = (
                sales: current.sales + ticket.total,
                tickets: current.tickets + 1
            )
        }

        return bartenderStats
            .map { (
                name: $0.key,
                sales: $0.value.sales,
                tickets: $0.value.tickets,
                avgTicket: $0.value.tickets > 0 ? $0.value.sales / Decimal($0.value.tickets) : 0
            )}
            .sorted { $0.sales > $1.sales }
    }

    func avgTicketSize(bartender: String) -> Decimal {
        let bartenderTickets = tickets.filter { $0.bartenderName == bartender }
        guard !bartenderTickets.isEmpty else { return 0 }

        let totalSales = bartenderTickets.reduce(0) { $0 + $1.total }
        return totalSales / Decimal(bartenderTickets.count)
    }

    func ticketsPerHour(bartender: String) -> Decimal {
        let bartenderReports = reports.filter { $0.bartenderName == bartender }
        guard !bartenderReports.isEmpty else { return 0 }

        let totalHours = bartenderReports.reduce(0.0) { total, report in
            total + report.endedAt.timeIntervalSince(report.startedAt) / 3600
        }

        let bartenderTickets = tickets.filter { $0.bartenderName == bartender }

        return totalHours > 0 ? Decimal(bartenderTickets.count) / Decimal(totalHours) : 0
    }

    // MARK: - Inventory Analytics

    func fastMovers(limit: Int = 10) -> [(product: String, quantity: Int, category: ProductCategory)] {
        var productQuantities: [String: Int] = [:]

        for ticket in tickets {
            for line in ticket.lines {
                productQuantities[line.productName, default: 0] += line.qty
            }
        }

        return productQuantities
            .compactMap { name, quantity -> (product: String, quantity: Int, category: ProductCategory)? in
                guard let product = products.first(where: { $0.name == name }) else { return nil }
                return (product: name, quantity: quantity, category: product.category)
            }
            .sorted { $0.quantity > $1.quantity }
            .prefix(limit)
            .map { $0 }
    }

    func slowMovers(limit: Int = 10) -> [(product: String, quantity: Int, category: ProductCategory)] {
        var productQuantities: [String: Int] = [:]

        for ticket in tickets {
            for line in ticket.lines {
                productQuantities[line.productName, default: 0] += line.qty
            }
        }

        // Get products that were sold but have low quantities
        let soldProducts = productQuantities
            .compactMap { name, quantity -> (product: String, quantity: Int, category: ProductCategory)? in
                guard let product = products.first(where: { $0.name == name }) else { return nil }
                return (product: name, quantity: quantity, category: product.category)
            }
            .sorted { $0.quantity < $1.quantity }
            .prefix(limit)
            .map { $0 }

        return soldProducts
    }

    func stockAlerts() -> [(product: Product, stockLevel: String)] {
        products
            .filter { $0.isLowStock }
            .map { product in
                let level: String
                if let stock = product.stockQuantity, let par = product.parLevel {
                    let percentage = (stock / par) * 100
                    if percentage <= 0 {
                        level = "OUT OF STOCK"
                    } else if percentage < 25 {
                        level = "CRITICAL"
                    } else if percentage < 50 {
                        level = "LOW"
                    } else {
                        level = "BELOW PAR"
                    }
                } else {
                    level = "LOW"
                }
                return (product: product, stockLevel: level)
            }
            .sorted { product1, product2 in
                let order = ["OUT OF STOCK", "CRITICAL", "LOW", "BELOW PAR"]
                let index1 = order.firstIndex(of: product1.stockLevel) ?? order.count
                let index2 = order.firstIndex(of: product2.stockLevel) ?? order.count
                return index1 < index2
            }
    }

    func eightySevenCount() -> [(product: String, count: Int)] {
        products
            .filter { $0.is86d }
            .map { (product: $0.name, count: 1) } // In the future, track frequency
    }

    func stockTurnoverRate(product: Product) -> Decimal? {
        guard let stock = product.stockQuantity,
              stock > 0 else { return nil }

        // Calculate how many units sold in the date range
        var soldQuantity = 0
        for ticket in tickets {
            for line in ticket.lines where line.productName == product.name {
                soldQuantity += line.qty
            }
        }

        guard soldQuantity > 0 else { return nil }

        // Calculate days in range
        let daysInRange = Calendar.current.dateComponents([.day],
                                                          from: dateRange.start,
                                                          to: dateRange.end).day ?? 1

        // Turnover rate = (quantity sold / average stock) / days * 30 (monthly rate)
        let turnoverRate = (Decimal(soldQuantity) / stock) / Decimal(daysInRange) * 30

        return turnoverRate
    }

    // MARK: - Summary Metrics

    func totalRevenue() -> Decimal {
        tickets.reduce(0) { $0 + $1.total }
    }

    func totalTickets() -> Int {
        tickets.count
    }

    func averageTicketSize() -> Decimal {
        let count = tickets.count
        guard count > 0 else { return 0 }
        return totalRevenue() / Decimal(count)
    }

    func totalItemsSold() -> Int {
        tickets.reduce(0) { total, ticket in
            total + ticket.lines.reduce(0) { $0 + $1.qty }
        }
    }
}
