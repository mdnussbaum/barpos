import SwiftUI

struct AdminChipsView: View {
    @EnvironmentObject var vm: InventoryVM

    @State private var whiteString: String = ""
    @State private var grayString: String  = ""
    @State private var blackString: String = ""

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

            // MARK: - Chip Prices (auto-saves on submit)
            Section("Chip Prices") {
                priceRow("White", text: $whiteString) { value in
                    vm.setChipPrice(.white, value)
                }
                priceRow("Gray", text: $grayString) { value in
                    vm.setChipPrice(.gray, value)
                }
                priceRow("Black", text: $blackString) { value in
                    vm.setChipPrice(.black, value)
                }
                Text("Prices save when you hit Return.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Chips")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Seed current prices into text fields
            whiteString = vm.price(for: .white).currencyEditingString()
            grayString  = vm.price(for: .gray).currencyEditingString()
            blackString = vm.price(for: .black).currencyEditingString()
        }
    }

    // MARK: - Price row
    @ViewBuilder
    private func priceRow(_ label: String,
                          text: Binding<String>,
                          onCommit: @escaping (Decimal) -> Void) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0.00", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
                .onSubmit {
                    if let val = Decimal(string: text.wrappedValue) {
                        onCommit(val)
                        text.wrappedValue = val.currencyEditingString()
                    }
                }
        }
    }
}
