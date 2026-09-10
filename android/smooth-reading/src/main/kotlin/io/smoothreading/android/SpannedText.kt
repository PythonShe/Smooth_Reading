@file:JvmName("SmoothReadingSpanned")

package io.smoothreading.android

import android.graphics.Typeface
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.StyleSpan
import io.smoothreading.SmoothOptions
import io.smoothreading.SmoothReading
import io.smoothreading.SmoothToken
import io.smoothreading.WordSegmenter

/**
 * Build a [Spanned] whose fixation prefixes are bold, for `TextView`.
 *
 * ```kotlin
 * textView.text = SmoothReading.spanned("Smooth reading works.")
 * ```
 *
 * The emphasis is a plain [StyleSpan] so it composes with whatever typeface and
 * text appearance the view already has.
 *
 * @param text the text to render
 * @param options fixation options (SPEC §4)
 * @param segmenter tokenizer; ICU by default (see [IcuWordSegmenter])
 */
@JvmOverloads
public fun SmoothReading.spanned(
    text: String,
    options: SmoothOptions = SmoothOptions(),
    segmenter: WordSegmenter = IcuWordSegmenter(options.locale),
): Spanned {
    val out = SpannableStringBuilder()
    for (token in tokenize(text, options, segmenter)) {
        when (token) {
            is SmoothToken.Separator -> out.append(token.text)
            is SmoothToken.Word -> {
                if (token.fixation == 0) {
                    out.append(token.text)
                } else {
                    val start = out.length
                    out.append(token.fixationText)
                    out.setSpan(
                        StyleSpan(Typeface.BOLD),
                        start,
                        out.length,
                        Spanned.SPAN_EXCLUSIVE_EXCLUSIVE,
                    )
                    out.append(token.restText)
                }
            }
        }
    }
    return out
}
