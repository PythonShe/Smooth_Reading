import Foundation

#if canImport(UIKit) && !os(watchOS)
import UIKit

extension UILabel {
    /// Set this label's text with guided fixation emphasis applied.
    /// Keeps the label's current font as the base font.
    @MainActor
    public func applySmoothReading(_ text: String, options: SmoothOptions = .default) {
        attributedText = SmoothReading.nsAttributedString(text, options: options, font: font)
    }
}

extension UITextView {
    /// Set this text view's text with guided fixation emphasis applied.
    @MainActor
    public func applySmoothReading(_ text: String, options: SmoothOptions = .default) {
        attributedText = SmoothReading.nsAttributedString(text, options: options, font: font)
    }
}
#endif

#if canImport(AppKit)
import AppKit

extension NSTextField {
    /// Set this field's value with guided fixation emphasis applied.
    @MainActor
    public func applySmoothReading(_ text: String, options: SmoothOptions = .default) {
        attributedStringValue = SmoothReading.nsAttributedString(text, options: options, font: font)
    }
}

extension NSTextView {
    /// Replace this text view's contents with guided fixation emphasis applied.
    @MainActor
    public func applySmoothReading(_ text: String, options: SmoothOptions = .default) {
        let attributed = SmoothReading.nsAttributedString(text, options: options, font: font)
        textStorage?.setAttributedString(attributed)
    }
}
#endif
