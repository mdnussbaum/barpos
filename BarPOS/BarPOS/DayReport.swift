//
//  DayReport.swift
//  BarPOS
//
//  Created by Michael Nussbaum on 11/29/25.
//

import Foundation

struct DayReport: Identifiable, Codable {
    var id: UUID
    let date: Date
    let shifts: [ShiftReport]
    
    init(id: UUID = UUID(), date: Date, shifts: [ShiftReport]) {
        self.id = id
        self.date = date
        self.shifts = shifts
    }
    
    // Computed totals
    var totalGrossSales: Decimal {
        shifts.reduce(0) { $0 + $1.grossSales }
    }
    
    var totalNetSales: Decimal {
        shifts.reduce(0) { $0 + $1.netSales }
    }
    
    var totalTaxCollected: Decimal {
        shifts.reduce(0) { $0 + $1.taxCollected }
    }
    
    var totalCashSales: Decimal {
        shifts.reduce(0) { $0 + $1.cashSales }
    }
    
    var totalCardSales: Decimal {
        shifts.reduce(0) { $0 + $1.cardSales }
    }
    
    var totalOtherSales: Decimal {
        shifts.reduce(0) { $0 + $1.otherSales }
    }
    
    var totalTabsCount: Int {
        shifts.reduce(0) { $0 + $1.tabsCount }
    }
    
    var bartenderNames: [String] {
        Array(Set(shifts.map { $0.bartenderName })).sorted()
    }
    
    var shiftCount: Int {
        shifts.count
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    
    var formattedFileDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
