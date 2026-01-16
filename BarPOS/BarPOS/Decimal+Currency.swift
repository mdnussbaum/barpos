import Foundation

extension Decimal {
    func currencyString(locale: Locale = .current) -> String {
        let nf = NumberFormatter()
        nf.locale = locale
        nf.numberStyle = .currency
        nf.minimumFractionDigits = 2  // Always show 2 decimal places
        nf.maximumFractionDigits = 2
        return nf.string(from: self as NSNumber) ?? "\(self)"
    }
    
    func plainString() -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 2
        return nf.string(from: self as NSNumber) ?? "\(self)"
    }
    
    func currencyEditingString() -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 2
        return nf.string(from: self as NSNumber) ?? "\(self)"
    }
}
