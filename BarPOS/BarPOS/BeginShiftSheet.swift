import SwiftUI

struct BeginShiftSheet: View {
    // Inputs provided by the presenter (RegisterView)
    let bartenders: [Bartender]
    var onStart: (_ bartender: Bartender, _ openingCash: Decimal) -> Void
    var onCancel: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var selectedBartenderID: UUID? = nil
    @State private var openingCashString: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Bartender") {
                    Picker("Bartender", selection: $selectedBartenderID) {
                        Text("Select…").tag(nil as UUID?)
                        ForEach(bartenders) { person in
                            Text(person.name).tag(person.id as UUID?)
                        }
                    }
                }

                Section("Opening Cash") {
                    TextField("0.00", text: $openingCashString)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Begin Shift")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Start") { startShift() }
                        .disabled(selectedBartenderID == nil)
                }
            }
        }
    }

    private func startShift() {
        guard
            let id = selectedBartenderID,
            let bartender = bartenders.first(where: { $0.id == id })
        else { return }

        let opening = Decimal(string: openingCashString) ?? 0
        onStart(bartender, opening)
        dismiss()
    }
}

#Preview {
    BeginShiftSheet(
        bartenders: [
            Bartender(name: "Alex"), Bartender(name: "Jamie")
        ],
        onStart: { _, _ in },
        onCancel: {}
    )
}
