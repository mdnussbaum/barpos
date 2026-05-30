//
//  BartenderPINSheet.swift
//  BarPOS
//
//  Created by Michael Nussbaum on 12/11/25.
//

import SwiftUI

struct BartenderPINSheet: View {
    @EnvironmentObject var vm: InventoryVM
    @Environment(\.dismiss) private var dismiss

    let onAuthenticated: (Bartender) -> Void

    @State private var selectedBartender: Bartender? = nil
    @State private var pin: String = ""
    @State private var pinError: String = ""
    @State private var shake: Bool = false

    private var activeBartenders: [Bartender] {
        vm.activeBartenders
            .filter { $0.pin != nil && $0.name.uppercased() != "TEST" }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                // ── LEFT: Bartender name buttons ──────────────────────
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(activeBartenders) { bartender in
                            Button {
                                selectedBartender = bartender
                                pin = ""
                                pinError = ""
                            } label: {
                                Text(bartender.name)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(
                                        selectedBartender?.id == bartender.id
                                            ? Color.blue : Color(.secondarySystemBackground)
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

                // ── RIGHT: PIN display + numpad ───────────────────────
                VStack(spacing: 20) {
                    Spacer()
                    Text(selectedBartender?.name ?? "Select a bartender")
                        .font(.headline)
                        .foregroundStyle(selectedBartender == nil ? .secondary : .primary)
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
                            NumpadButton(label: "✓", isAction: true) { authenticateBartender() }
                                .disabled(selectedBartender == nil || pin.isEmpty)
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
            }
            .navigationTitle("Bartender Login")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
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
                authenticateBartender()
            }
        }
    }

    private func authenticateBartender() {
        guard let bartender = selectedBartender else {
            pinError = "Select a bartender first"
            return
        }
        if vm.validateBartenderPIN(bartender, pin: pin) {
            onAuthenticated(bartender)
            dismiss()
        } else {
            pinError = "Incorrect PIN"
            pin = ""
            shake = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shake = false }
        }
    }
}

// MARK: - Numpad Button
private struct NumpadButton: View {
    let label: String
    var isDestructive: Bool = false
    var isAction: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.title2)
                .fontWeight(.medium)
                .frame(width: 72, height: 72)
                .background(backgroundColor)
                .foregroundStyle(foregroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if isAction { return .blue }
        if isDestructive { return Color(.systemFill) }
        return Color(.secondarySystemBackground)
    }

    private var foregroundColor: Color {
        if isAction { return .white }
        if isDestructive { return .red }
        return .primary
    }
}

#Preview {
    BartenderPINSheet { bartender in
        print("Authenticated: \(bartender.name)")
    }
    .environmentObject(InventoryVM())
}
