import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject var vm: InventoryVM
    @Environment(\.dismiss) private var dismiss

    // Chips editor
    @State private var chipValueText: String = ""

    var body: some View {
        NavigationStack {
            List {
                // MARK: Payments
                Section("Payments") {
                    Toggle("Enable Cash",  isOn: binding(for: .cash))
                    Toggle("Enable Card",  isOn: binding(for: .card))
                    Toggle("Enable Other", isOn: binding(for: .other))

                    // Default payment method (clamped to enabled methods)
                    Picker(
                        "Default method",
                        selection: vm.clampedPaymentSelection(
                            Binding(
                                get: { vm.defaultPaymentMethod },
                                set: { vm.defaultPaymentMethod = $0 }
                            )
                        )
                    ) {
                        ForEach(PaymentMethod.allCases, id: \.self) { m in
                            Text(m.rawValue.capitalized).tag(m)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: vm.enabledPaymentMethods) { _, _ in
                        // Keep default valid (don’t assign a Binding to a value)
                        if !vm.enabledPaymentMethods.contains(vm.defaultPaymentMethod) {
                            vm.defaultPaymentMethod = vm.enabledPaymentMethods.first ?? .cash
                        }
                    }
                }

                // MARK: Chips
                Section("Chips") {
                    HStack {
                        Text("Chip value")
                        Spacer()
                        TextField("0.00", text: $chipValueText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                    }
                    Text("Used by “Sell Chip” / “Redeem Chip”.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // MARK: Hardware
                Section("Hardware") {
                    NavigationLink {
                        PrinterSettingsView()
                            .environmentObject(vm)
                    } label: {
                        Label("Printer & Cash Drawer", systemImage: "printer")
                    }
                }

                // Roadmap placeholders
                Section("Coming soon") {
                    Text("Multiple chip types")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        commitChipValue()
                        dismiss()
                    }
                }
            }
            .onAppear {
                chipValueText = simpleMoneyString(from: vm.chipValue)
            }
        }
    }

    // MARK: - Payments bindings

    private func binding(for method: PaymentMethod) -> Binding<Bool> {
        Binding<Bool>(
            get: { vm.enabledPaymentMethods.contains(method) },
            set: { isOn in
                if isOn {
                    vm.enabledPaymentMethods.insert(method)
                } else {
                    vm.enabledPaymentMethods.remove(method)
                    // Keep default valid if user disables the current default
                    if !vm.enabledPaymentMethods.contains(vm.defaultPaymentMethod) {
                        vm.defaultPaymentMethod = vm.enabledPaymentMethods.first ?? .cash
                    }
                }
            }
        )
    }

    // MARK: - Actions

    private func commitChipValue() {
        let filtered = chipValueText
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = Decimal(string: filtered), d >= 0 {
            vm.chipValue = d
        }
    }

    private func simpleMoneyString(from d: Decimal) -> String {
        let n = NSDecimalNumber(decimal: d)
        return String(format: "%.2f", n.doubleValue)
    }
}
