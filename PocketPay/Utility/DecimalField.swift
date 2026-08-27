//
//  DecimalField.swift
//  PocketPay
//
//  Created by Eduardo Torres on 1/21/26.
//

import SwiftUI

/// A text field for entering a monetary amount without the cursor jumping while typing.
///
/// `TextField(value:format:)` re-formats its text on every keystroke, so in-progress
/// input is rewritten under the user: typing `"1."` parses to `1.0`, formats back to
/// `"1"`, and the caret snaps to the end of the field (dropping the separator the user
/// just typed). This field instead keeps the raw string the user typed as its source of
/// truth and only *parses* it into the bound `Double`, never writing a reformatted
/// string back mid-edit.
struct DecimalField: View {
    /// Placeholder shown when the field is empty.
    let title: String
    /// The numeric amount being edited. Set to `0` while the field is empty.
    @Binding var value: Double
    /// Maximum digits accepted after the decimal separator.
    var maximumFractionDigits: Int = 2

    /// Exactly what the user typed, sanitized to a valid partial decimal.
    @State private var text: String = ""

    var body: some View {
        TextField(title, text: decimalBinding)
            .keyboardType(.decimalPad)
            .onAppear {
                text = Self.string(from: value, maximumFractionDigits: maximumFractionDigits)
            }
            .onChange(of: value) { _, newValue in
                // Only re-render the text when the value changed from outside the field
                // (e.g. `resetForm()`); a change we caused ourselves already matches.
                guard Self.double(from: text) != newValue else { return }
                text = Self.string(from: newValue, maximumFractionDigits: maximumFractionDigits)
            }
    }

    /// Bridges the raw `String` state to the bound `Double`.
    ///
    /// The getter returns the untouched user text, which is what keeps the caret stable.
    private var decimalBinding: Binding<String> {
        Binding(
            get: { text },
            set: { newText in
                let sanitized = Self.sanitize(newText, maximumFractionDigits: maximumFractionDigits)
                text = sanitized
                value = Self.double(from: sanitized) ?? 0
            }
        )
    }

    // MARK: - Parsing

    /// The decimal separator the numeric keypad shows for the current locale.
    private static var localeSeparator: String {
        Locale.current.decimalSeparator ?? "."
    }

    /// Strips everything that is not a digit or the first decimal separator, and
    /// truncates the fraction to `maximumFractionDigits`.
    ///
    /// Both `"."` and the locale separator are accepted and normalized to `"."`.
    static func sanitize(_ input: String, maximumFractionDigits: Int) -> String {
        let normalized = input
            .replacingOccurrences(of: localeSeparator, with: ".")
            .filter { $0.isNumber || $0 == "." }

        let parts = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count > 1 else { return normalized }

        let whole = parts[0]
        // Any separators past the first are dropped, along with the digits between them.
        let fraction = parts[1].prefix(maximumFractionDigits)
        return "\(whole).\(fraction)"
    }

    /// Parses a sanitized string into a `Double`. A lone separator (`"."`) or an empty
    /// string is treated as zero so the bound value stays usable while typing.
    static func double(from text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == "." { return 0 }
        return Double(trimmed)
    }

    /// Renders a value for display. Zero maps to an empty string so the placeholder shows.
    static func string(from value: Double, maximumFractionDigits: Int) -> String {
        guard value != 0 else { return "" }
        return String(format: "%.\(maximumFractionDigits)f", value)
    }
}
