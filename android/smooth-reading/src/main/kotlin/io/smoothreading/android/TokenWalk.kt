package io.smoothreading.android

import io.smoothreading.SmoothToken

/**
 * The one token walk shared by [spanned] and [annotatedString]: map every word
 * that received a fixation to char offsets of the original string.
 *
 * Tokens round-trip the input (`WordSegmenter` contract), so the adapters
 * never rebuild the text — they style ranges of the string they were given.
 * Words without a fixation get no callback: they stay plain (SPEC §2).
 *
 * @param action receives `[fixationStart, fixationEnd)` and the end of the
 *   word; the rest range `[fixationEnd, wordEnd)` may be empty.
 */
internal inline fun forEachFixation(
    text: String,
    tokens: List<SmoothToken>,
    action: (fixationStart: Int, fixationEnd: Int, wordEnd: Int) -> Unit,
) {
    var offset = 0
    for (token in tokens) {
        if (token is SmoothToken.Word && token.fixation > 0) {
            action(offset, offset + token.fixationText.length, offset + token.text.length)
        }
        offset += token.text.length
    }
    check(offset == text.length) { "segmenter output does not round-trip the input ($offset != ${text.length})" }
}
