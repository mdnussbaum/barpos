import SwiftUI

/// Reusable admin PIN pad. Shows masked PIN dots, an error line,
/// and the standard NumpadButton grid. Calls onSubmit with the
/// entered PIN when the checkmark is tapped.
struct AdminPINPadView: View {
    @Binding var pin: String
    var errorMessage: String = ""
    let onSubmit: () -> Void

    private let maxDigits = 8

    var body: some View {
        VStack(spacing: 16) {
            // PIN dots
            HStack(spacing: 14) {
                ForEach(0..<maxDigits, id: \.self) { i in
                    Circle()
                        .fill(i < pin.count ? Color.blue : Color(.systemFill))
                        .frame(width: 14, height: 14)
                }
            }

            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.red)
                .frame(height: 16)

            VStack(spacing: 10) {
                ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(row, id: \.self) { digit in
                            NumpadButton(label: "\(digit)") { appendDigit("\(digit)") }
                        }
                    }
                }
                HStack(spacing: 10) {
                    NumpadButton(label: "⌫", isDestructive: true) {
                        if pin.isEmpty == false { pin.removeLast() }
                    }
                    NumpadButton(label: "0") { appendDigit("0") }
                    NumpadButton(label: "✓", isAction: true) { onSubmit() }
                        .disabled(pin.isEmpty)
                }
            }
        }
    }

    private func appendDigit(_ digit: String) {
        guard pin.count < maxDigits else { return }
        pin += digit
    }
}
