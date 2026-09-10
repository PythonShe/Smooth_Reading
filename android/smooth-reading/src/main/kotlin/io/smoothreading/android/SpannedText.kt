@file:JvmName("SmoothReadingSpanned")

package io.smoothreading.android

import android.graphics.Typeface
import android.text.SpannableString
import android.text.Spanned
import android.text.style.CharacterStyle
import android.text.style.StyleSpan
import android.widget.TextView
import io.smoothreading.SmoothOptions
import io.smoothreading.SmoothReading
import io.smoothreading.WordSegmenter

/**
 * Build a [SpannableString] whose fixation prefixes are bold, for `TextView`.
 *
 * ```kotlin
 * textView.text = SmoothReading.spanned("Smooth reading works.")
 * ```
 *
 * Every span instance covers exactly one range, so the styles are given as
 * factories. The default fixation span is a plain [StyleSpan] with
 * [Typeface.BOLD], which composes with whatever typeface and text appearance
 * the view already has. Words without a fixation get no span at all.
 *
 * @param text the text to render
 * @param options fixation options (SPEC §4)
 * @param fixationSpan creates the span for each emphasised prefix
 * @param restSpan optional factory for the remainder of each emphasised word —
 *   e.g. `{ ForegroundColorSpan(dimColor) }` for an alpha/colour effect
 * @param segmenter word breaker; ICU by default (see [IcuWordSegmenter])
 */
@JvmOverloads
public fun SmoothReading.spanned(
    text: String,
    options: SmoothOptions = SmoothOptions.DEFAULTS,
    fixationSpan: () -> CharacterStyle = { StyleSpan(Typeface.BOLD) },
    restSpan: (() -> CharacterStyle)? = null,
    segmenter: WordSegmenter = IcuWordSegmenter(options.locale),
): SpannableString {
    val spannable = SpannableString(text)
    forEachFixation(text, tokenize(text, options, segmenter)) { start, fixationEnd, wordEnd ->
        spannable.setSpan(fixationSpan(), start, fixationEnd, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        if (restSpan != null && wordEnd > fixationEnd) {
            spannable.setSpan(restSpan(), fixationEnd, wordEnd, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
    }
    return spannable
}

/**
 * Set [text] on this view with guided-fixation emphasis; see [spanned] for
 * the parameters.
 *
 * ```kotlin
 * textView.setSmoothText("Smooth reading works.", SmoothOptions(fixation = 4))
 * ```
 */
@JvmOverloads
public fun TextView.setSmoothText(
    text: String,
    options: SmoothOptions = SmoothOptions.DEFAULTS,
    fixationSpan: () -> CharacterStyle = { StyleSpan(Typeface.BOLD) },
    restSpan: (() -> CharacterStyle)? = null,
    segmenter: WordSegmenter = IcuWordSegmenter(options.locale),
) {
    setText(
        SmoothReading.spanned(text, options, fixationSpan, restSpan, segmenter),
        TextView.BufferType.SPANNABLE,
    )
}
