import Foundation

extension Decimal {
    func currencyString(locale: Locale = .current) -> String {
        let nf = NumberFormatter()
        nf.locale = locale
        nf.numberStyle = .currency
        return nf.string(from: self as NSNumber) ?? "\(self)"
    }
}
