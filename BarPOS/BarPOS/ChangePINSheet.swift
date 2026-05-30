//
//  ChangePINSheet.swift
//  BarPOS
//
//  Created by Michael Nussbaum on 12/11/25.
//


//
//  ChangePINSheet.swift
//  BarPOS
//
//  Allows bartenders to change their PIN during their shift
//

import SwiftUI

// MARK: - Change PIN Sheet
struct ChangePINSheet: View {
    @EnvironmentObject var vm: InventoryVM
    @Environment(\.dismiss) private var dismiss

    let bartender: Bartender

    enum Step { case current, newPIN, confirm }

    @State private var step: Step = .current
    @State private var currentPIN: String = ""
    @State private var newPIN: String = ""
    @State private var confirmPIN: String = ""
    @State private var pinError: String = ""
    @State private var shake: Bool = false
    @State private var showSuccess: Bool = false

    private var activePin: String {
        get {
            switch step {
            case .current: return currentPIN
            case .newPIN:  return newPIN
            case .confirm: return confirmPIN
            }
        }
        set {
            switch step {
            case .current: currentPIN = newValue
            case .newPIN:  newPIN = newValue
            case .confirm: confirmPIN = newValue
            }
        }
    }

    private var stepTitle: String {
        switch step {
        case .current: return "Enter current PIN"
        case .newPIN:  return "Enter new PIN"
        case .confirm: return "Confirm new PIN"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                if showSuccess {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)
                        Text("PIN changed successfully")
                            .font(.headline)
                    }
                } else {
                    Text(stepTitle)
                        .font(.headline)

                    // PIN dots
                    HStack(spacing: 14) {
                        ForEach(0..<8, id: \.self) { i in
                            Circle()
                                .fill(i < activePin.count ? Color.blue : Color(.systemFill))
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
                                if !activePin.isEmpty { activePin = String(activePin.dropLast()) }
                                pinError = ""
                            }
                            NumpadButton(label: "0") { appendDigit("0") }
                            NumpadButton(label: "✓", isAction: true) { advance() }
                                .disabled(activePin.isEmpty)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 40)
            .navigationTitle("Change PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func appendDigit(_ digit: String) {
        guard activePin.count < 8 else { return }
        activePin += digit
        pinError = ""
    }

    private func advance() {
        pinError = ""
        switch step {
        case .current:
            guard vm.validateBartenderPIN(bartender, pin: currentPIN) else {
                triggerError("Incorrect PIN")
                return
            }
            step = .newPIN
        case .newPIN:
            guard newPIN.count >= 4 else {
                triggerError("PIN must be at least 4 digits")
                return
            }
            step = .confirm
        case .confirm:
            guard confirmPIN == newPIN else {
                triggerError("PINs don't match")
                confirmPIN = ""
                return
            }
            vm.changeBartenderPIN(bartenderID: bartender.id, newPIN: newPIN)
            showSuccess = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
        }
    }

    private func triggerError(_ message: String) {
        pinError = message
        switch step {
        case .current: currentPIN = ""
        case .newPIN:  newPIN = ""
        case .confirm: confirmPIN = ""
        }
        shake = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { shake = false }
    }
}

#Preview {
    ChangePINSheet(bartender: Bartender(name: "Alex", pin: "1234"))
        .environmentObject(InventoryVM())
}
