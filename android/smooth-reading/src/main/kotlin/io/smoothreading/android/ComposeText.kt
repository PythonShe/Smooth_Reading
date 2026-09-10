@file:JvmName("SmoothReadingCompose")

package io.smoothreading.android

import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.font.FontWeight
import io.smoothreading.SmoothOptions
import io.smoothreading.SmoothReading
import io.smoothreading.WordSegmenter

/**
 * Build an [AnnotatedString] whose fixation prefixes carry [fixationStyle].
 *
 * ```kotlin
 * Text(SmoothReading.annotatedString("Smooth reading works."))
 * ```
 *
 * Words without a fixation carry no style at all. This function is not
 * `@Composable`; it only needs `androidx.compose.ui:ui-text`, which the
 * library declares as `compileOnly` — any Compose app already has it.
 *
 * @param text the text to render
 * @param options fixation options (SPEC §4)
 * @param fixationStyle style applied to the emphasised prefix of each word
 * @param restStyle optional style for the remainder of each emphasised word —
 *   e.g. `SpanStyle(color = LocalContentColor.current.copy(alpha = 0.75f))`
 * @param segmenter word breaker; ICU by default (see [IcuWordSegmenter])
 */
@JvmOverloads
public fun SmoothReading.annotatedString(
    text: String,
    options: SmoothOptions = SmoothOptions.DEFAULTS,
    fixationStyle: SpanStyle = SpanStyle(fontWeight = FontWeight.Bold),
    restStyle: SpanStyle? = null,
    segmenter: WordSegmenter = IcuWordSegmenter(options.locale),
): AnnotatedString {
    val builder = AnnotatedString.Builder(text.length)
    builder.append(text)
    forEachFixation(text, tokenize(text, options, segmenter)) { start, fixationEnd, wordEnd ->
        builder.addStyle(fixationStyle, start, fixationEnd)
        if (restStyle != null && wordEnd > fixationEnd) builder.addStyle(restStyle, fixationEnd, wordEnd)
    }
    return builder.toAnnotatedString()
}
