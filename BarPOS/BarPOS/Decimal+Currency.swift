import Foundation

private enum CachedFormatters {
    static let currency: NumberFormatter = {
        let nf = NumberFormatter()
        nf.locale = .current
        nf.numberStyle = .currency
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2
        return nf
    }()

    static let plain: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 0
        nf.maximumFractionDigits = 2
        return nf
    }()
}

extension Decimal {
    func currencyString(locale: Locale = .current) -> String {
        if locale == .current {
            return CachedFormatters.currency.string(from: self as NSNumber) ?? "\(self)"
        }
        let nf = NumberFormatter()
        nf.locale = locale
        nf.numberStyle = .currency
        nf.minimumFractionDigits = 2
        nf.maximumFractionDigits = 2
        return nf.string(from: self as NSNumber) ?? "\(self)"
    }
    
    func plainString() -> String {
        CachedFormatters.plain.string(from: self as NSNumber) ?? "\(self)"
    }
    
    func currencyEditingString() -> String {
        CachedFormatters.plain.string(from: self as NSNumber) ?? "\(self)"
    }
}
