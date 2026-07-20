import SwiftUI

struct AdminChipsView: View {
    @EnvironmentObject var vm: InventoryVM

    @State private var editingChip: ChipType? = nil
    @State private var editDigits: String = ""

    // Derived summaries
    private var totalOutstandingCount: Int {
        vm.chipOutstanding(.white) + vm.chipOutstanding(.gray) + vm.chipOutstanding(.black)
    }
    private var totalOutstandingValue: Decimal {
        (Decimal(vm.chipOutstanding(.white)) * vm.price(for: .white)) +
        (Decimal(vm.chipOutstanding(.gray))  * vm.price(for: .gray))  +
        (Decimal(vm.chipOutstanding(.black)) * vm.price(for: .black))
    }

    var body: some View {
        Form {
            // MARK: - Outstanding chips
            Section("Outstanding") {
                HStack {
                    Text("White")
                    Spacer()
                    Text("\(vm.chipOutstanding(.white))")
                        .monospacedDigit()
                }
                HStack {
                    Text("Gray")
                    Spacer()
                    Text("\(vm.chipOutstanding(.gray))")
                        .monospacedDigit()
                }
                HStack {
                    Text("Black")
                    Spacer()
                    Text("\(vm.chipOutstanding(.black))")
                        .monospacedDigit()
                }

                Divider()

                // Totals
                HStack {
                    Text("Total Chips")
                    Spacer()
                    Text("\(totalOutstandingCount)")
                        .bold()
                        .monospacedDigit()
                }
                HStack {
                    Text("Total Value")
                    Spacer()
                    Text(totalOutstandingValue.currencyString())
                        .bold()
                }
            }

            // MARK: - Chip Prices
            Section("Chip Prices") {
                chipPriceRow(.white)
                chipPriceRow(.gray)
                chipPriceRow(.black)
                Text("Tap a price to change it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Chips")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingChip) { chip in
            NavigationStack {
                ScrollView {
                VStack(spacing: 20) {
                    Text("\(chip.displayName) Chip Price")
                        .font(.headline)
                    Text(editedPrice.currencyString())
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .foregroundStyle(editDigits.isEmpty ? .secondary : .primary)
                    VStack(spacing: 10) {
                        ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
                            HStack(spacing: 10) {
                                ForEach(row, id: \.self) { digit in
                                    NumpadButton(label: "\(digit)") { appendPriceDigit("\(digit)") }
                                }
                            }
                        }
                        HStack(spacing: 10) {
                            NumpadButton(label: "⌫", isDestructive: true) {
                                if editDigits.isEmpty == false { editDigits.removeLast() }
                            }
                            NumpadButton(label: "0") { appendPriceDigit("0") }
                            NumpadButton(label: "✓", isAction: true) {
                                vm.setChipPrice(chip, editedPrice)
                                editingChip = nil
                            }
                            .disabled(editDigits.isEmpty)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                }
                .navigationTitle("Chip Price")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { editingChip = nil }
                    }
                }
            }
            .presentationDetents([.large])
        }
    }

    @ViewBuilder
    private func chipPriceRow(_ type: ChipType) -> some View {
        Button {
            editDigits = ""
            editingChip = type
        } label: {
            HStack {
                Text(type.displayName)
                    .foregroundStyle(.primary)
                Spacer()
                Text(vm.price(for: type).currencyString())
                    .foregroundStyle(.blue)
                    .fontWeight(.semibold)
            }
        }
    }

    private var editedPrice: Decimal {
        let digits = editDigits.isEmpty ? "0" : editDigits
        return (Decimal(string: digits) ?? 0) / 100
    }

    private func appendPriceDigit(_ digit: String) {
        guard editDigits.count < 5 else { return }
        if editDigits == "0" && digit == "0" { return }
        editDigits += digit
    }
}
