//! Algorithm options (`SmoothOptions` in SPEC §4).

use std::fmt;
use std::sync::Arc;

use crate::segment::{Segmenter, SpecSegmenter};

/// A custom fixation-length algorithm (SPEC §2, "Custom override").
///
/// It receives the word exactly as tokenized, its grapheme-cluster count and
/// the options in force, and returns how many leading grapheme clusters to
/// emphasise. The result is clamped to `0..=graphemes` by the caller.
pub type FixationLengthFn = Arc<dyn Fn(&str, usize, &Options) -> usize + Send + Sync>;

/// Fixation strength → percent of the word emphasised (SPEC §2), kept as
/// integers so `floor((n * percent + 50) / 100)` is exact in every port.
const PERCENT: [usize; 5] = [20, 35, 50, 65, 80];

/// The default segmenter, shared by every [`Options`] that sets none.
static SPEC_SEGMENTER: SpecSegmenter = SpecSegmenter;

/// Algorithm options with the spec defaults (SPEC §4).
///
/// Build them with the chaining setters; every value is clamped into range
/// rather than rejected, exactly as in every other port: `fixation` to `1..=5`,
/// `saccade` to `>= 1`. Negative values cannot be expressed in the first place
/// (`u8`/`usize`), which the spec allows a port whose type system excludes them
/// to rely on.
///
/// The setters take `self` and return it, so a value can be configured in one
/// expression; the getters carry a `get_` prefix (as on
/// [`std::process::Command`]) because the plain names are taken by the setters.
///
/// ```
/// use smooth_reading::Options;
///
/// let options = Options::new().fixation(4).saccade(2);
/// assert_eq!(options.get_fixation(), 4);
/// assert_eq!(options.get_saccade(), 2);
/// assert_eq!(Options::new().fixation(9).get_fixation(), 5); // clamped
/// assert_eq!(Options::new().saccade(0).get_saccade(), 1); // clamped
/// ```
#[derive(Clone)]
pub struct Options {
    fixation: u8,
    saccade: usize,
    min_word_length: usize,
    emphasize_numbers: bool,
    locale: Option<String>,
    fixation_length: Option<FixationLengthFn>,
    segmenter: Option<Arc<dyn Segmenter>>,
}

impl Default for Options {
    fn default() -> Self {
        Self::new()
    }
}

impl Options {
    /// The spec defaults: strength `3`, every word, no minimum length, numbers
    /// not emphasised, no locale, the built-in algorithm and segmenter.
    #[must_use]
    pub const fn new() -> Self {
        Self {
            fixation: 3,
            saccade: 1,
            min_word_length: 1,
            emphasize_numbers: false,
            locale: None,
            fixation_length: None,
            segmenter: None,
        }
    }

    /// Sets the fixation strength, clamped to `1..=5`. Default `3`.
    ///
    /// The strength selects the proportion of each word that is emphasised:
    /// `0.20, 0.35, 0.50, 0.65, 0.80`.
    #[must_use]
    pub const fn fixation(mut self, fixation: u8) -> Self {
        self.fixation = if fixation < 1 {
            1
        } else if fixation > 5 {
            5
        } else {
            fixation
        };
        self
    }

    /// Sets the saccade interval: emphasise every `saccade`-th word. Clamped to
    /// `>= 1`. Default `1`.
    #[must_use]
    pub const fn saccade(mut self, saccade: usize) -> Self {
        self.saccade = if saccade < 1 { 1 } else { saccade };
        self
    }

    /// Words with fewer grapheme clusters than this get no fixation. Default `1`.
    #[must_use]
    pub const fn min_word_length(mut self, min_word_length: usize) -> Self {
        self.min_word_length = min_word_length;
        self
    }

    /// Whether words made only of decimal digits are emphasised. Default `false`.
    #[must_use]
    pub const fn emphasize_numbers(mut self, emphasize_numbers: bool) -> Self {
        self.emphasize_numbers = emphasize_numbers;
        self
    }

    /// Sets the BCP-47 language tag passed to the segmenter. The built-in
    /// [`SpecSegmenter`] ignores it; a platform break iterator may use it.
    #[must_use]
    pub fn locale(mut self, locale: impl Into<String>) -> Self {
        self.locale = Some(locale.into());
        self
    }

    /// Replaces the built-in fixation algorithm (SPEC §2, "Custom override").
    ///
    /// [`fixation_length`](crate::fixation_length) honours this override, so
    /// the closure must not call it with the same options (that would recurse).
    ///
    /// ```
    /// use smooth_reading::{Options, to_markdown};
    ///
    /// // Always emphasise exactly one cluster (clamped to the word length).
    /// let options = Options::new().fixation_length(|_word, _graphemes, _options| 1);
    /// assert_eq!(to_markdown("Smooth reading", &options, "**"), "**S**mooth **r**eading");
    /// ```
    #[must_use]
    pub fn fixation_length<F>(mut self, fixation_length: F) -> Self
    where
        F: Fn(&str, usize, &Options) -> usize + Send + Sync + 'static,
    {
        self.fixation_length = Some(Arc::new(fixation_length));
        self
    }

    /// Supplies word boundaries and grapheme clusters (SPEC §3).
    ///
    /// The default is the spec's regular-expression scanner. Supply an
    /// ICU-backed [`Segmenter`] for dictionary-based Chinese, Japanese and Thai
    /// word breaks; the fixation algorithm itself never changes.
    #[must_use]
    pub fn segmenter(mut self, segmenter: Arc<dyn Segmenter>) -> Self {
        self.segmenter = Some(segmenter);
        self
    }

    /// The fixation strength, `1..=5`.
    #[must_use]
    pub const fn get_fixation(&self) -> u8 {
        self.fixation
    }

    /// The saccade interval, `>= 1`.
    #[must_use]
    pub const fn get_saccade(&self) -> usize {
        self.saccade
    }

    /// The minimum word length (in grapheme clusters) that gets a fixation.
    #[must_use]
    pub const fn get_min_word_length(&self) -> usize {
        self.min_word_length
    }

    /// Whether digit-only words are emphasised.
    #[must_use]
    pub const fn get_emphasize_numbers(&self) -> bool {
        self.emphasize_numbers
    }

    /// The BCP-47 language tag, if one was set.
    #[must_use]
    pub fn get_locale(&self) -> Option<&str> {
        self.locale.as_deref()
    }

    /// The custom fixation-length function, if one was set.
    #[must_use]
    pub const fn get_fixation_length(&self) -> Option<&FixationLengthFn> {
        self.fixation_length.as_ref()
    }

    /// The custom segmenter, if one was set.
    #[must_use]
    pub const fn get_segmenter(&self) -> Option<&Arc<dyn Segmenter>> {
        self.segmenter.as_ref()
    }

    /// Fraction of each word that is emphasised at this fixation strength.
    ///
    /// ```
    /// use smooth_reading::Options;
    ///
    /// assert_eq!(Options::new().ratio(), 0.5);
    /// assert_eq!(Options::new().fixation(5).ratio(), 0.8);
    /// ```
    #[must_use]
    pub fn ratio(&self) -> f64 {
        // `percent` is at most 80, so the conversion is exact.
        #[allow(clippy::cast_precision_loss)]
        let percent = self.percent() as f64;
        percent / 100.0
    }

    /// Percent of the word emphasised at this strength (SPEC §2).
    pub(crate) const fn percent(&self) -> usize {
        PERCENT[(self.fixation - 1) as usize]
    }

    /// The segmenter in force: the custom one, or the spec scanner.
    pub(crate) fn segmenter_impl(&self) -> &dyn Segmenter {
        match &self.segmenter {
            Some(segmenter) => segmenter.as_ref(),
            None => &SPEC_SEGMENTER,
        }
    }
}

impl fmt::Debug for Options {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Options")
            .field("fixation", &self.fixation)
            .field("saccade", &self.saccade)
            .field("min_word_length", &self.min_word_length)
            .field("emphasize_numbers", &self.emphasize_numbers)
            .field("locale", &self.locale)
            .field(
                "fixation_length",
                &self.fixation_length.as_ref().map(|_| "<custom>"),
            )
            .field("segmenter", &self.segmenter.as_ref().map(|_| "<custom>"))
            .finish()
    }
}
