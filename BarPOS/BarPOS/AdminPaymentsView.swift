import SwiftUI

struct AdminPaymentsView: View {
    @EnvironmentObject var vm: InventoryVM

    var body: some View {
        Form {
            Section("Accepted Methods") {
                Toggle("Enable Cash",  isOn: binding(for: .cash))
                Toggle("Enable Card",  isOn: binding(for: .card))
                Toggle("Enable Other", isOn: binding(for: .other))
            }

            Section("Default Method") {
                Picker(
                    "Default",
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
                    if !vm.enabledPaymentMethods.contains(vm.defaultPaymentMethod) {
                        vm.defaultPaymentMethod = vm.enabledPaymentMethods.first ?? .cash
                    }
                }

                Text("The default method is pre-selected when opening the payment screen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Payments")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private func binding(for method: PaymentMethod) -> Binding<Bool> {
        Binding<Bool>(
            get: { vm.enabledPaymentMethods.contains(method) },
            set: { isOn in
                if isOn {
                    vm.enabledPaymentMethods.insert(method)
                } else {
                    vm.enabledPaymentMethods.remove(method)
                    if !vm.enabledPaymentMethods.contains(vm.defaultPaymentMethod) {
                        vm.defaultPaymentMethod = vm.enabledPaymentMethods.first ?? .cash
                    }
                }
            }
        )
    }
}
