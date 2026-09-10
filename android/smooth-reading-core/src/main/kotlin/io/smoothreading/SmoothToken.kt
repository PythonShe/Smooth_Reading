package io.smoothreading

/** A piece of the input: either a word with a computed split, or a separator. */
public sealed interface SmoothToken {
    /** The slice of the input this token covers. */
    public val text: String

    /**
     * A word token (SPEC §4).
     *
     * @property fixation how many *grapheme clusters* are emphasised (`0` = none)
     * @property fixationText the emphasised prefix
     * @property restText everything after the prefix
     */
    public data class Word(
        override val text: String,
        val fixation: Int,
        val fixationText: String,
        val restText: String,
    ) : SmoothToken

    /** Whitespace, punctuation or markup: never emphasised. */
    public data class Separator(override val text: String) : SmoothToken
}
