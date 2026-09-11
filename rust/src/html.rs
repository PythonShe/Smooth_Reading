//! HTML and Markdown rendering (SPEC §4).

use std::collections::HashSet;

use crate::options::Options;
use crate::tokenize::{Token, TokenizeState, tokenize, tokenize_with_state};

/// Elements whose text content [`to_html`] never touches (SPEC §4).
pub const DEFAULT_SKIP_TAGS: [&str; 7] =
    ["code", "pre", "script", "style", "kbd", "samp", "textarea"];

/// Markup options for [`to_html`].
///
/// ```
/// use smooth_reading::{HtmlOptions, Options, to_html};
///
/// let html = HtmlOptions::new()
///     .tag("span")
///     .class_name("sr-fixation")
///     .rest_tag("span")
///     .rest_class_name("sr-rest");
/// assert_eq!(
///     to_html("Smooth", &Options::new(), &html),
///     r#"<span class="sr-fixation">Smo</span><span class="sr-rest">oth</span>"#
/// );
/// ```
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HtmlOptions {
    tag: String,
    class_name: Option<String>,
    rest_tag: Option<String>,
    rest_class_name: Option<String>,
    ignore_html_tags: bool,
    skip_tags: Vec<String>,
}

impl Default for HtmlOptions {
    fn default() -> Self {
        Self::new()
    }
}

impl HtmlOptions {
    /// The defaults: `<b>` around the fixation, no class, no rest element,
    /// existing markup preserved, [`DEFAULT_SKIP_TAGS`] skipped.
    #[must_use]
    pub fn new() -> Self {
        Self {
            tag: "b".to_owned(),
            class_name: None,
            rest_tag: None,
            rest_class_name: None,
            ignore_html_tags: true,
            skip_tags: DEFAULT_SKIP_TAGS
                .iter()
                .map(|&tag| tag.to_owned())
                .collect(),
        }
    }

    /// The element wrapped around each fixation. Default `b`.
    #[must_use]
    pub fn tag(mut self, tag: impl Into<String>) -> Self {
        self.tag = tag.into();
        self
    }

    /// A `class` attribute for the fixation element. Default none.
    #[must_use]
    pub fn class_name(mut self, class_name: impl Into<String>) -> Self {
        self.class_name = Some(class_name.into());
        self
    }

    /// An element wrapped around the rest of each emphasised word. Default
    /// none (the rest is plain text).
    #[must_use]
    pub fn rest_tag(mut self, rest_tag: impl Into<String>) -> Self {
        self.rest_tag = Some(rest_tag.into());
        self
    }

    /// A `class` attribute for the rest element. Default none.
    #[must_use]
    pub fn rest_class_name(mut self, rest_class_name: impl Into<String>) -> Self {
        self.rest_class_name = Some(rest_class_name.into());
        self
    }

    /// Whether the input is HTML whose markup must pass through untouched
    /// (`true`, the default) or plain text whose `<`, `>` and `&` are escaped
    /// (`false`).
    #[must_use]
    pub const fn ignore_html_tags(mut self, ignore_html_tags: bool) -> Self {
        self.ignore_html_tags = ignore_html_tags;
        self
    }

    /// Elements whose content is left untouched (compared case-insensitively).
    /// Replaces [`DEFAULT_SKIP_TAGS`].
    #[must_use]
    pub fn skip_tags<I, S>(mut self, skip_tags: I) -> Self
    where
        I: IntoIterator<Item = S>,
        S: Into<String>,
    {
        self.skip_tags = skip_tags.into_iter().map(Into::into).collect();
        self
    }

    /// The fixation element name.
    #[must_use]
    pub fn get_tag(&self) -> &str {
        &self.tag
    }

    /// The fixation element's class, if any.
    #[must_use]
    pub fn get_class_name(&self) -> Option<&str> {
        self.class_name.as_deref()
    }

    /// The rest element name, if any.
    #[must_use]
    pub fn get_rest_tag(&self) -> Option<&str> {
        self.rest_tag.as_deref()
    }

    /// The rest element's class, if any.
    #[must_use]
    pub fn get_rest_class_name(&self) -> Option<&str> {
        self.rest_class_name.as_deref()
    }

    /// Whether existing markup passes through untouched.
    #[must_use]
    pub const fn get_ignore_html_tags(&self) -> bool {
        self.ignore_html_tags
    }

    /// The elements whose content is left untouched.
    #[must_use]
    pub fn get_skip_tags(&self) -> &[String] {
        &self.skip_tags
    }
}

/// Escapes exactly `& < > "` (SPEC §4); `'` stays so `don't` reads naturally.
///
/// ```
/// use smooth_reading::escape_html;
///
/// assert_eq!(escape_html(r#"a < b & c > "d" 'e'"#), "a &lt; b &amp; c &gt; &quot;d&quot; 'e'");
/// ```
#[must_use]
pub fn escape_html(text: &str) -> String {
    let mut out = String::with_capacity(text.len());
    push_escaped(&mut out, text);
    out
}

fn push_escaped(out: &mut String, text: &str) {
    for c in text.chars() {
        match c {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '"' => out.push_str("&quot;"),
            _ => out.push(c),
        }
    }
}

/// The end offset of the markup starting at byte `pos` of `text` (which holds
/// `<` or `&`), or `None` when it is ordinary text.
///
/// Mirrors the regular expression every other port uses:
///
/// ```text
/// <!--.*?-->
/// |<!\[CDATA\[.*?\]\]>
/// |<[/!?][^>]*>
/// |<[A-Za-z][^>]*>
/// |&(?:#[0-9]+|#[xX][0-9a-fA-F]+|[A-Za-z][A-Za-z0-9]*);
/// ```
///
/// An unterminated comment or CDATA block degrades to a declaration ending at
/// the first `>`; an unterminated `<` or a bare `&` is text.
fn markup_end(text: &str, pos: usize) -> Option<usize> {
    let bytes = text.as_bytes();
    let rest = &text[pos..];
    match bytes[pos] {
        b'<' => {
            if let Some(body) = rest.strip_prefix("<!--") {
                if let Some(end) = body.find("-->") {
                    return Some(pos + 4 + end + 3);
                }
            }
            if let Some(body) = rest.strip_prefix("<![CDATA[") {
                if let Some(end) = body.find("]]>") {
                    return Some(pos + 9 + end + 3);
                }
            }
            match bytes.get(pos + 1) {
                Some(&next) if matches!(next, b'/' | b'!' | b'?') || next.is_ascii_alphabetic() => {
                    rest.find('>').map(|end| pos + end + 1)
                }
                _ => None,
            }
        }
        b'&' => {
            let body = &bytes[pos + 1..];
            let mut i;
            if body.first() == Some(&b'#') {
                let hex = matches!(body.get(1), Some(b'x' | b'X'));
                i = if hex { 2 } else { 1 };
                let digits_start = i;
                while body.get(i).is_some_and(|b| {
                    if hex {
                        b.is_ascii_hexdigit()
                    } else {
                        b.is_ascii_digit()
                    }
                }) {
                    i += 1;
                }
                if i == digits_start {
                    return None;
                }
            } else {
                if !body.first().is_some_and(u8::is_ascii_alphabetic) {
                    return None;
                }
                i = 1;
                while body.get(i).is_some_and(u8::is_ascii_alphanumeric) {
                    i += 1;
                }
            }
            (body.get(i) == Some(&b';')).then_some(pos + 1 + i + 1)
        }
        _ => None,
    }
}

/// The `(closing, lower-case name)` of a tag, or `None` for comments,
/// declarations, processing instructions and character references.
///
/// Mirrors `<\s*(/?)\s*([A-Za-z][^\s/>]*)`: the name starts at the first ASCII
/// letter (after an optional `/`, which may be surrounded by whitespace, so
/// `</ code>` closes `code`) and runs until whitespace, `/` or `>`, so
/// `<code.x>` is named `code.x`, not the skip tag `code`.
fn tag_name(raw: &str) -> Option<(bool, String)> {
    let body = raw.strip_prefix('<')?.trim_start();
    let (closing, body) = match body.strip_prefix('/') {
        Some(body) => (true, body.trim_start()),
        None => (false, body),
    };
    if !body.starts_with(|c: char| c.is_ascii_alphabetic()) {
        return None;
    }
    let end = body
        .find(|c: char| c.is_whitespace() || c == '/' || c == '>')
        .unwrap_or(body.len());
    Some((closing, body[..end].to_ascii_lowercase()))
}

/// `<br/>` and `<code / >` are self-closing (`/\s*>$`); the trailing `/` may
/// be spaced.
fn is_self_closing(raw: &str) -> bool {
    raw.strip_suffix('>')
        .is_some_and(|body| body.trim_end().ends_with('/'))
}

/// A chunk of the input: raw markup to copy through, or prose to tokenize.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Chunk<'a> {
    Raw(&'a str),
    Prose(&'a str),
}

/// Splits `text` into raw chunks (markup, character references and the
/// content of `skipped` elements, emitted verbatim) and prose chunks.
/// Character references therefore act as word boundaries.
fn split_markup<'a>(text: &'a str, skipped: &HashSet<String>) -> Vec<Chunk<'a>> {
    let mut chunks = Vec::new();
    let mut skip_name: Option<String> = None; // the skip element we are inside, if any
    let mut skip_depth = 0_usize; // nesting of that same element: <pre><pre>..</pre></pre>
    let mut cursor = 0;
    let mut pos = 0;
    let bytes = text.as_bytes();
    while pos < bytes.len() {
        if bytes[pos] != b'<' && bytes[pos] != b'&' {
            pos += 1;
            continue;
        }
        let Some(end) = markup_end(text, pos) else {
            pos += 1;
            continue;
        };
        if pos > cursor {
            let prose = &text[cursor..pos];
            chunks.push(if skip_name.is_some() {
                Chunk::Raw(prose)
            } else {
                Chunk::Prose(prose)
            });
        }
        let raw = &text[pos..end];
        chunks.push(Chunk::Raw(raw));
        cursor = end;
        pos = end;

        let Some((closing, name)) = tag_name(raw) else {
            continue;
        };
        if is_self_closing(raw) {
            continue;
        }
        match &skip_name {
            None => {
                if !closing && skipped.contains(&name) {
                    skip_name = Some(name);
                    skip_depth = 1;
                }
            }
            Some(current) if *current == name => {
                if closing {
                    skip_depth -= 1;
                    if skip_depth == 0 {
                        skip_name = None;
                    }
                } else {
                    skip_depth += 1;
                }
            }
            Some(_) => {}
        }
    }
    if cursor < text.len() {
        let prose = &text[cursor..];
        chunks.push(if skip_name.is_some() {
            Chunk::Raw(prose)
        } else {
            Chunk::Prose(prose)
        });
    }
    chunks
}

fn push_wrapped(out: &mut String, tag: Option<&str>, class_name: Option<&str>, body: &str) {
    let Some(tag) = tag else {
        push_escaped(out, body);
        return;
    };
    out.push('<');
    out.push_str(tag);
    if let Some(class_name) = class_name {
        out.push_str(" class=\"");
        push_escaped(out, class_name);
        out.push('"');
    }
    out.push('>');
    push_escaped(out, body);
    out.push_str("</");
    out.push_str(tag);
    out.push('>');
}

fn render(out: &mut String, tokens: &[Token<'_>], html: &HtmlOptions) {
    for token in tokens {
        match *token {
            Token::Word {
                fixation,
                fixation_text,
                rest_text,
                ..
            } if fixation > 0 => {
                push_wrapped(
                    out,
                    Some(html.get_tag()),
                    html.get_class_name(),
                    fixation_text,
                );
                // A fully emphasised word gets no (empty) rest element.
                if !rest_text.is_empty() {
                    push_wrapped(
                        out,
                        html.get_rest_tag(),
                        html.get_rest_class_name(),
                        rest_text,
                    );
                }
            }
            _ => push_escaped(out, token.text()),
        }
    }
}

/// Renders `text` as HTML with the leading part of each word emphasised
/// (SPEC §4).
///
/// Each fixation is wrapped in the [`HtmlOptions`] `tag` (with `class_name`);
/// the rest of the word is plain text unless `rest_tag` is given. Everything
/// emitted as text has `& < > "` escaped.
///
/// With `ignore_html_tags` (the default) existing tags, comments and character
/// references pass through verbatim, the content of `skip_tags` elements, plus
/// `tag` and `rest_tag` themselves so already-emphasised markup is not
/// wrapped twice, is left untouched, and the saccade count continues across
/// markup. With `ignore_html_tags(false)` the input is plain text and every
/// `<`, `>` and `&` is escaped.
///
/// ```
/// use smooth_reading::{HtmlOptions, Options, to_html};
///
/// let (options, html) = (Options::new(), HtmlOptions::new());
/// assert_eq!(to_html("Smooth reading works.", &options, &html), "<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.");
/// assert_eq!(
///     to_html("<p>Smooth</p> <code>x = 1</code> & <b>done</b>", &options, &html),
///     "<p><b>Smo</b>oth</p> <code>x = 1</code> &amp; <b>done</b>"
/// );
/// assert_eq!(
///     to_html("Tom & Jerry <3", &options, &html.clone().ignore_html_tags(false)),
///     "<b>To</b>m &amp; <b>Jer</b>ry &lt;3"
/// );
/// ```
#[must_use]
pub fn to_html(text: &str, options: &Options, html: &HtmlOptions) -> String {
    let mut out = String::with_capacity(text.len() * 2);
    if !html.ignore_html_tags {
        render(&mut out, &tokenize(text, options), html);
        return out;
    }
    let skipped: HashSet<String> = html
        .skip_tags
        .iter()
        .map(String::as_str)
        .chain(Some(html.tag.as_str()))
        .chain(html.rest_tag.as_deref())
        .map(str::to_lowercase)
        .collect();
    let mut state = TokenizeState::default();
    for chunk in split_markup(text, &skipped) {
        match chunk {
            Chunk::Raw(raw) => out.push_str(raw),
            Chunk::Prose(prose) => {
                let tokens = tokenize_with_state(prose, options, &mut state);
                render(&mut out, &tokens, html);
            }
        }
    }
    out
}

/// Renders `text` as Markdown, wrapping each fixation in `marker`.
///
/// Nothing is escaped; the input is assumed to be Markdown already.
///
/// ```
/// use smooth_reading::{Options, to_markdown};
///
/// assert_eq!(to_markdown("Smooth reading works.", &Options::new(), "**"), "**Smo**oth **read**ing **wor**ks.");
/// ```
#[must_use]
pub fn to_markdown(text: &str, options: &Options, marker: &str) -> String {
    let mut out = String::with_capacity(text.len() * 2);
    for token in tokenize(text, options) {
        match token {
            Token::Word {
                fixation,
                fixation_text,
                rest_text,
                ..
            } if fixation > 0 => {
                out.push_str(marker);
                out.push_str(fixation_text);
                out.push_str(marker);
                out.push_str(rest_text);
            }
            _ => out.push_str(token.text()),
        }
    }
    out
}
