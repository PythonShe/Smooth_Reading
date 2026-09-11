//! Render a sentence three ways: HTML, Markdown and raw tokens.
//!
//! ```sh
//! cargo run --example basic
//! ```

use smooth_reading::{HtmlOptions, Options, Token, to_html, to_markdown, tokenize};

fn main() {
    let text = "Smooth reading works in every script: 我喜欢阅读, naïve, don't, 2024.";

    let options = Options::new();
    println!("{}", to_html(text, &options, &HtmlOptions::new()));
    println!();

    // Every second word, strength 5, with semantic spans for CSS.
    let strong = Options::new().fixation(5).saccade(2);
    let spans = HtmlOptions::new()
        .tag("span")
        .class_name("sr-fixation")
        .rest_tag("span")
        .rest_class_name("sr-rest");
    println!("{}", to_html(text, &strong, &spans));
    println!();

    println!("{}", to_markdown(text, &options, "**"));
    println!();

    // Tokens borrow from the input; feed them to your own text engine.
    for token in tokenize(text, &options) {
        match token {
            Token::Word {
                fixation_text,
                rest_text,
                fixation,
                ..
            } if fixation > 0 => print!("[{fixation_text}]{rest_text}"),
            other => print!("{}", other.text()),
        }
    }
    println!();
}
