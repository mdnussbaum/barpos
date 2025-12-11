import SwiftUI

// This file has been replaced with BartenderPINSheet.swift
// for PIN-based authentication. This wrapper maintains
// compatibility with existing code.

struct BeginShiftSheet: View {
    let bartenders: [Bartender]
    let carryoverTabs: [TabTicket]
    var onStart: (_ bartender: Bartender, _ openingCash: Decimal) -> Void
    var onCancel: () -> Void = {}

    @EnvironmentObject var vm: InventoryVM

    var body: some View {
        BartenderPINSheet(
            bartenders: bartenders,
            carryoverTabs: carryoverTabs,
            vm: vm,
            onStart: onStart,
            onCancel: onCancel
        )
    }
}

#Preview {
    BeginShiftSheet(
        bartenders: [
            Bartender(name: "Alex", pin: "1234"),
            Bartender(name: "Jamie", pin: "5678")
        ],
        carryoverTabs: [],
        onStart: { _, _ in },
        onCancel: {}
    )
    .environmentObject(InventoryVM())
}
