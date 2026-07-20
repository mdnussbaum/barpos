import SwiftUI

struct CashNumpadView: View {
    @Binding var cashGivenString: String
    let total: Decimal

    private var tendered: Decimal {
        Decimal(string: cashGivenString) ?? 0
    }

    var body: some View {
        VStack(spacing: 6) {
            // Compact status line - only appears during a partial tender.
            // Total and Tendered/Change are already shown in the totals card
            // directly above this panel in the register.
            if tendered > 0 && tendered < total {
                HStack {
                    Text("Still owed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text((total - tendered).currencyString())
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Numpad grid
            let keys: [[String]] = [
                ["7","8","9"],
                ["4","5","6"],
                ["1","2","3"],
                ["00","0","⌫"]
            ]

            VStack(spacing: 5) {
                ForEach(keys, id: \.self) { row in
                    HStack(spacing: 5) {
                        ForEach(row, id: \.self) { key in
                            Button {
                                handleKey(key)
                            } label: {
                                Text(key)
                                    .font(.system(size: 20, weight: .medium))
                                    .frame(maxWidth: .infinity, minHeight: 50)
                                    .background(Color(.tertiarySystemFill))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .contentShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
    }

    private func handleKey(_ key: String) {
        switch key {
        case "⌫":
            if !cashGivenString.isEmpty {
                cashGivenString.removeLast()
            }
        case "00":
            let digits = cashGivenString.replacingOccurrences(of: ".", with: "")
            if !digits.isEmpty {
                cashGivenString = formatCents(digits + "00")
            }
        default:
            let digits = cashGivenString.replacingOccurrences(of: ".", with: "") + key
            cashGivenString = formatCents(digits)
        }
    }

    // Keeps value as dollars.cents - input is always in cents
    private func formatCents(_ digits: String) -> String {
        let trimmed = digits.drop(while: { $0 == "0" })
        let d = trimmed.isEmpty ? "0" : String(trimmed)
        if d.count <= 2 {
            let padded = String(repeating: "0", count: 3 - d.count) + d
            return "0.\(padded.suffix(2))"
        } else {
            let intPart = d.dropLast(2)
            let decPart = d.suffix(2)
            return "\(intPart).\(decPart)"
        }
    }
}
