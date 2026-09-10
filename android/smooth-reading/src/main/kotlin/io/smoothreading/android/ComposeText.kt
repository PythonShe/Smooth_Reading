@file:JvmName("SmoothReadingCompose")

package io.smoothreading.android

import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import io.smoothreading.SmoothOptions
import io.smoothreading.SmoothReading
import io.smoothreading.SmoothToken
import io.smoothreading.WordSegmenter

/**
 * Build an [AnnotatedString] whose fixation prefixes carry [fixationStyle].
 *
 * ```kotlin
 * Text(SmoothReading.annotatedString("Smooth reading works."))
 * ```
 *
 * @param text the text to render
 * @param options fixation options (SPEC §4)
 * @param fixationStyle style applied to the emphasised prefix of each word
 * @param restStyle optional style for the remainder of each word — e.g.
 *   `SpanStyle(color = LocalContentColor.current.copy(alpha = 0.75f))`
 * @param segmenter tokenizer; ICU by default (see [IcuWordSegmenter])
 */
@JvmOverloads
public fun SmoothReading.annotatedString(
    text: String,
    options: SmoothOptions = SmoothOptions(),
    fixationStyle: SpanStyle = SpanStyle(fontWeight = FontWeight.Bold),
    restStyle: SpanStyle? = null,
    segmenter: WordSegmenter = IcuWordSegmenter(options.locale),
): AnnotatedString = buildAnnotatedString {
    for (token in tokenize(text, options, segmenter)) {
        when (token) {
            is SmoothToken.Separator -> append(token.text)
            is SmoothToken.Word -> {
                if (token.fixation == 0) {
                    appendStyled(token.text, restStyle)
                } else {
                    appendStyled(token.fixationText, fixationStyle)
                    appendStyled(token.restText, restStyle)
                }
            }
        }
    }
}

private fun AnnotatedString.Builder.appendStyled(text: String, style: SpanStyle?) {
    if (text.isEmpty()) return
    if (style == null) {
        append(text)
        return
    }
    val start = length
    append(text)
    addStyle(style, start, length)
}
