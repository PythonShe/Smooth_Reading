import Foundation

#if canImport(UIKit)
import UIKit
/// `UIFont` on UIKit platforms (iOS, tvOS, watchOS, visionOS, Mac Catalyst),
/// `NSFont` on AppKit platforms.
public typealias PlatformFont = UIFont
#elseif canImport(AppKit)
import AppKit
/// `UIFont` on UIKit platforms (iOS, tvOS, watchOS, visionOS, Mac Catalyst),
/// `NSFont` on AppKit platforms.
public typealias PlatformFont = NSFont
#endif

extension SmoothReading {

    // MARK: - Shared token walk

    /// One maximal run of text that is either entirely a fixation or entirely
    /// plain. Both attributed-string APIs are built on ``runs(_:options:)``, so
    /// they can never disagree about where the emphasis goes.
    struct Run: Equatable {
        var text: String
        var isFixation: Bool
    }

    /// Emphasised / plain runs of `text`, in order; concatenating them
    /// reproduces the input.
    static func runs(_ text: String, options: SmoothOptions) -> [Run] {
        var runs: [Run] = []
        for token in tokenize(text, options: options) {
            switch token {
            case let .separator(text):
                runs.append(Run(text: text, isFixation: false))
            case let .word(word, fixation, fixationText, restText):
                if fixation > 0 {
                    runs.append(Run(text: fixationText, isFixation: true))
                    if !restText.isEmpty { runs.append(Run(text: restText, isFixation: false)) }
                } else {
                    runs.append(Run(text: word, isFixation: false))
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
    /// `font` (or the platform body font) with ``boldFont(from:)``, so the result
    /// renders bold in UIKit/AppKit without relying on presentation intents.
    /// When `restAttributes` is `nil` the rest of every word uses `font`.
    ///
    /// - Parameters:
    ///   - text: the text to emphasise.
    ///   - options: tokenizer and fixation options.
    ///   - font: the base font; `nil` uses ``defaultBodyFont()``.
    ///   - fixationAttributes: attributes for the emphasised prefix of each word.
    ///   - restAttributes: attributes for everything else.
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

    /// A bold counterpart of `font` at the same point size.
    ///
    /// The bold face of the family is used when it has one; otherwise the
    /// closest face to a bold weight is requested through the font descriptor's
    /// weight trait. If nothing heavier exists the font is returned unchanged,
    /// so the call never fails.
    public static func boldFont(from font: PlatformFont) -> PlatformFont {
        #if canImport(UIKit)
        if let descriptor = font.fontDescriptor.withSymbolicTraits(.traitBold) {
            return UIFont(descriptor: descriptor, size: font.pointSize)
        }
        // No bold face in this family: ask for a bold weight and let UIKit
        // pick the nearest face it has.
        let weighted = font.fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: UIFont.Weight.bold.rawValue]
        ])
        return UIFont(descriptor: weighted, size: font.pointSize)
        #else
        let converted = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        if converted.fontDescriptor.symbolicTraits.contains(.bold) { return converted }
        // `convert` returns the input unchanged when the family has no bold
        // face; fall back to the nearest face to a bold weight.
        let weighted = font.fontDescriptor.addingAttributes([
            .traits: [NSFontDescriptor.TraitKey.weight: NSFont.Weight.bold.rawValue]
        ])
        return NSFont(descriptor: weighted, size: font.pointSize) ?? converted
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
    ///
    /// This is a convenience over the same token walk as
    /// ``nsAttributedString(_:options:font:fixationAttributes:restAttributes:)``;
    /// prefer that API for UIKit/AppKit views.
    ///
    /// - Parameters:
    ///   - text: the text to emphasise.
    ///   - options: tokenizer and fixation options.
    ///   - fixationAttributes: attributes merged into the emphasised prefix of
    ///     each word. Default ``defaultFixationAttributes``.
    ///   - restAttributes: attributes merged into everything else. Default empty.
    public static func attributedString(
        _ text: String,
        options: SmoothOptions = .default,
        fixationAttributes: AttributeContainer = SmoothReading.defaultFixationAttributes,
        restAttributes: AttributeContainer = AttributeContainer()
    ) -> AttributedString {
        var result = AttributedString()
        for run in runs(text, options: options) {
            var piece = AttributedString(run.text)
            piece.mergeAttributes(run.isFixation ? fixationAttributes : restAttributes)
            result.append(piece)
        }
        return result
    }
}
