import Foundation

#if canImport(UIKit)
import UIKit
/// `UIFont` on UIKit platforms, `NSFont` on AppKit platforms.
public typealias PlatformFont = UIFont
#elseif canImport(AppKit)
import AppKit
/// `UIFont` on UIKit platforms, `NSFont` on AppKit platforms.
public typealias PlatformFont = NSFont
#endif

extension SmoothReading {

    // MARK: - Shared token walk

    /// Emphasised / plain runs of `text`, in order. Both attributed-string APIs
    /// are built on this, so they can never disagree.
    static func runs(_ text: String, options: SmoothOptions) -> [(text: String, isFixation: Bool)] {
        var runs: [(text: String, isFixation: Bool)] = []
        for token in tokenize(text, options: options) {
            switch token {
            case let .separator(text):
                runs.append((text, false))
            case let .word(word, fixation, fixationText, restText):
                if fixation > 0 {
                    runs.append((fixationText, true))
                    if !restText.isEmpty { runs.append((restText, false)) }
                } else {
                    runs.append((word, false))
                }
            }
        }
        return runs
    }

    // MARK: - NSAttributedString (UIKit / AppKit)

    #if canImport(UIKit) || canImport(AppKit)
    /// Render `text` as an `NSAttributedString` for `UILabel`, `UITextView`,
    /// `NSTextField`, `NSTextView` and friends.
    ///
    /// When `fixationAttributes` is `nil` a genuinely bold font is derived from
    /// `font` (or the platform body font) via the font descriptor, so the result
    /// renders bold in UIKit/AppKit without relying on markdown-style intents.
    public static func nsAttributedString(
        _ text: String,
        options: SmoothOptions = .default,
        font: PlatformFont? = nil,
        fixationAttributes: [NSAttributedString.Key: Any]? = nil,
        restAttributes: [NSAttributedString.Key: Any]? = nil
    ) -> NSAttributedString {
        let baseFont = font ?? defaultBodyFont()
        let fixationAttrs = fixationAttributes ?? [.font: boldFont(from: baseFont)]
        let restAttrs = restAttributes ?? [.font: baseFont]
        let result = NSMutableAttributedString()
        for run in runs(text, options: options) {
            result.append(
                NSAttributedString(string: run.text, attributes: run.isFixation ? fixationAttrs : restAttrs))
        }
        return result
    }

    /// The platform's body font — the sensible default when the caller has none.
    public static func defaultBodyFont() -> PlatformFont {
        #if canImport(UIKit)
        return UIFont.preferredFont(forTextStyle: .body)
        #else
        return NSFont.preferredFont(forTextStyle: .body)
        #endif
    }

    /// A bold counterpart of `font`, or `font` itself when the family has no
    /// bold face.
    public static func boldFont(from font: PlatformFont) -> PlatformFont {
        #if canImport(UIKit)
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) else { return font }
        return UIFont(descriptor: descriptor, size: font.pointSize)
        #else
        let bold = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        return bold
        #endif
    }
    #endif

    // MARK: - AttributedString (SwiftUI)

    /// Attributes applied to fixations by default: `.stronglyEmphasized`, which
    /// SwiftUI's `Text` renders bold and which bridges to UIKit/AppKit when
    /// converted to `NSAttributedString`.
    public static let defaultFixationAttributes: AttributeContainer = {
        var container = AttributeContainer()
        container.inlinePresentationIntent = .stronglyEmphasized
        return container
    }()

    /// Render `text` as an `AttributedString`, for SwiftUI `Text`.
    public static func attributedString(
        _ text: String,
        options: SmoothOptions = .default,
        fixation fixationAttributes: AttributeContainer = SmoothReading.defaultFixationAttributes,
        rest: AttributeContainer = AttributeContainer()
    ) -> AttributedString {
        var result = AttributedString()
        for run in runs(text, options: options) {
            var piece = AttributedString(run.text)
            piece.mergeAttributes(run.isFixation ? fixationAttributes : rest)
            result.append(piece)
        }
        return result
    }
}
