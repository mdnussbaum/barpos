//
//  ShiftStatusChip.swift
//  BarPOSv2
//
//  Created by Michael Nussbaum on 8/27/25.
//


import SwiftUI
import Combine

struct ShiftStatusChip: View {
    @EnvironmentObject var vm: InventoryVM
    @State private var now: Date = Date()

    // 1s ticker to keep elapsed time fresh
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: vm.currentShift == nil ? "lock.fill" : "bolt.horizontal.fill")
                .imageScale(.medium)

            if let shift = vm.currentShift {
                // Name
                Text(shift.openedBy?.name ?? "—")
                    .font(.callout).bold()

                // • separator
                Text("•").font(.caption).opacity(0.6)

                // Elapsed
                Text(elapsedString(since: shift.startedAt, to: now))
                    .font(.callout).monospacedDigit()

                // • separator
                Text("•").font(.caption).opacity(0.6)

                // Running gross (current shift only — because we clear closedTabs on begin)
                Text(totalThisShift().currencyString())
                    .font(.callout).bold()
            } else {
                Text("No shift")
                    .font(.callout).bold()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(vm.currentShift == nil
                      ? Color.secondary.opacity(0.12)
                      : Color.accentColor.opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(vm.currentShift == nil
                        ? Color.secondary.opacity(0.35)
                        : Color.accentColor.opacity(0.55),
                        lineWidth: 1)
        )
        .foregroundStyle(vm.currentShift == nil ? Color.secondary : Color.accentColor)
        .onReceive(ticker) { now = $0 }
        .accessibilityElement(children: .ignore) // compact announce
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Helpers

    private func totalThisShift() -> Decimal {
        // closedTabs are cleared when a new shift is begun, so this is per-shift total
        vm.closedTabs.reduce(0) { $0 + $1.total }
    }

    private func elapsedString(since start: Date, to now: Date) -> String {
        let seconds = Int(now.timeIntervalSince(start))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        return String(format: "%02d:%02d", h, m)
    }

    private var accessibilityText: String {
        if let shift = vm.currentShift {
            return "Shift active. Bartender \(shift.openedBy?.name ?? "unknown"). " +
                   "Elapsed \(elapsedString(since: shift.startedAt, to: now)). " +
                   "Sales \(totalThisShift().currencyString())."
        } else {
            return "No active shift."
        }
    }
}
