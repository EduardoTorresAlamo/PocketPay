import Foundation

/// Centralized currency formatting for PocketPay.
///
/// Eliminates duplicate `String(format: "$%.2f", ...)` calls across the codebase.
/// Uses the system formatter for locale-aware output.
enum CurrencyFormatter {

    /// Formats a monetary amount as a USD string with dollar sign and commas.
    ///
    /// Example: `format(1250.0)` → `"$1,250.00"`
    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    /// Formats a monetary amount as a USD string with dollar sign and commas.
    static func format(_ amount: Double) -> String {
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    /// Formats a monetary amount as a plain two-decimal string (no currency symbol).
    ///
    /// Example: `plain(1250.0)` → `"1250.00"`
    static func plain(_ amount: Double) -> String {
        return String(format: "%.2f", amount)
    }
}
