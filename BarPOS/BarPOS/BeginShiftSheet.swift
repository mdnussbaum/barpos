import SwiftUI

struct BeginShiftSheet: View {
    @EnvironmentObject var vm: InventoryVM
    let carryoverTabs: [TabTicket]
    var onStart: (_ bartender: Bartender, _ openingCash: Decimal) -> Void
    var onCancel: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var selectedBartender: Bartender? = nil
    @State private var pin: String = ""
    @State private var pinError: String = ""
    @State private var shake: Bool = false
    @State private var authenticated: Bool = false
    @State private var openingCashString: String = ""

    private var activeBartenders: [Bartender] {
        vm.activeBartenders
            .filter { $0.pin != nil && $0.name.uppercased() != "TEST" }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Carryover warning banner
                if !carryoverTabs.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("\(carryoverTabs.count) open tab(s) carried over from previous shift")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.1))
                }

                HStack(spacing: 0) {

                    // ── LEFT: Bartender name buttons ──────────────────
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(activeBartenders) { bartender in
                                Button {
                                    if selectedBartender?.id != bartender.id {
                                        selectedBartender = bartender
                                        pin = ""
                                        pinError = ""
                                        authenticated = false
                                        openingCashString = ""
                                    }
                                } label: {
                                    HStack {
                                        Text(bartender.name)
                                            .font(.title3)
                                            .fontWeight(.medium)
                                        Spacer()
                                        if authenticated && selectedBartender?.id == bartender.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 18)
                                    .background(
                                        selectedBartender?.id == bartender.id
                                            ? (authenticated ? Color.green : Color.blue)
                                            : Color(.secondarySystemBackground)
                                    )
                                    .foregroundStyle(
                                        selectedBartender?.id == bartender.id
                                            ? .white : .primary
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }

                            if activeBartenders.isEmpty {
                                Text("No bartenders configured.\nSee Admin → Staff.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 20)
                            }
                        }
                        .padding(16)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGroupedBackground))

                    Divider()

                    // ── RIGHT: PIN + opening cash ─────────────────────
                    VStack(spacing: 16) {

                        Spacer()

                        // Bartender name or prompt
                        Text(selectedBartender?.name ?? "Select a bartender")
                            .font(.headline)
                            .foregroundStyle(selectedBartender == nil ? .secondary : .primary)

                        if !authenticated {
                            // PIN dots
                            HStack(spacing: 14) {
                                ForEach(0..<6, id: \.self) { i in
                                    Circle()
                                        .fill(i < pin.count ? Color.blue : Color(.systemFill))
                                        .frame(width: 14, height: 14)
                                }
                            }
                            .offset(x: shake ? -8 : 0)
                            .animation(
                                shake ? .easeInOut(duration: 0.07).repeatCount(4, autoreverses: true) : .default,
                                value: shake
                            )

                            Text(pinError)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(height: 16)

                            // Numpad
                            VStack(spacing: 10) {
                                ForEach([[1,2,3],[4,5,6],[7,8,9]], id: \.self) { row in
                                    HStack(spacing: 10) {
                                        ForEach(row, id: \.self) { digit in
                                            NumpadButton(label: "\(digit)") { appendDigit("\(digit)") }
                                        }
                                    }
                                }
                                HStack(spacing: 10) {
                                    NumpadButton(label: "⌫", isDestructive: true) {
                                        if !pin.isEmpty { pin.removeLast() }
                                        pinError = ""
                                    }
                                    NumpadButton(label: "0") { appendDigit("0") }
                                    NumpadButton(label: "✓", isAction: true) { authenticatePIN() }
                                        .disabled(selectedBartender == nil || pin.isEmpty)
                                }
                            }

                        } else {
                            // Authenticated — show opening cash numpad
                            Text("Opening Cash")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(openingCashString.isEmpty ? "$0.00" : "$\(openingCashString)")
                                .font(.system(size: 32, weight: .semibold, design: .rounded))
                                .foregroundStyle(openingCashString.isEmpty ? .secondary : .primary)

                            // Cash numpad
                            VStack(spacing: 10) {
                                ForEach([[1,2,3],[4,5,6],[7,8,9]], id: \.self) { row in
                                    HStack(spacing: 10) {
                                        ForEach(row, id: \.self) { digit in
                                            NumpadButton(label: "\(digit)") { appendCash("\(digit)") }
                                        }
                                    }
                                }
                                HStack(spacing: 10) {
                                    NumpadButton(label: "⌫", isDestructive: true) {
                                        if !openingCashString.isEmpty {
                                            openingCashString.removeLast()
                                        }
                                    }
                                    NumpadButton(label: "0") { appendCash("0") }
                                    NumpadButton(label: "00") { appendCash("00") }
                                }
                            }
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                }
            }
            .navigationTitle("Begin Shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel(); dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Start Shift") { startShift() }
                        .fontWeight(.semibold)
                        .disabled(!authenticated)
                }
            }
        }
    }

    private func appendDigit(_ digit: String) {
        guard selectedBartender != nil, pin.count < 8 else { return }
        pin += digit
        pinError = ""
        if let stored = selectedBartender?.pin, pin.count == stored.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                authenticatePIN()
            }
        }
    }

    private func appendCash(_ digits: String) {
        let combined = openingCashString + digits
        if combined.count <= 7 { openingCashString = combined }
    }

    private func authenticatePIN() {
        guard let bartender = selectedBartender else { return }
        if vm.validateBartenderPIN(bartender, pin: pin) {
            authenticated = true
            pinError = ""
        } else {
            pinError = "Incorrect PIN"
            pin = ""
            shake = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shake = false }
        }
    }

    private func startShift() {
        guard let bartender = selectedBartender, authenticated else { return }
        // Convert cents-style input to dollars: "1500" → 15.00
        let opening = Decimal(string: openingCashString) ?? 0
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onStart(bartender, opening)
        }
    }
}
