//! The `smooth-reading` command line interface.
//!
//! Reads a file (or standard input), writes HTML or Markdown to standard
//! output without a trailing newline, exactly like the Python port's CLI.
//! Exit codes: `0` success, `1` I/O error, `2` usage error.

use std::io::{self, Read, Write};
use std::process::ExitCode;

use smooth_reading::{HtmlOptions, Options, VERSION, to_html, to_markdown};

const USAGE: &str = "usage: smooth-reading [-h] [--fixation {1,2,3,4,5}] [--saccade SACCADE]
                     [--min-word-length MIN_WORD_LENGTH] [--numbers] [--tag TAG]
                     [--class CLASS_NAME] [--no-ignore-html-tags] [--markdown]
                     [--version]
                     [file]";

const HELP: &str = "

Emphasise the leading letters of every word so the eye gets an artificial fixation
point. Reads a file or standard input, writes HTML.

positional arguments:
  file                  input file; omit or use '-' for standard input

options:
  -h, --help            show this help message and exit
  --fixation {1,2,3,4,5}
                        fixation strength, 1 (weakest) to 5 (strongest); default 3
  --saccade SACCADE     emphasise every Nth word; default 1
  --min-word-length MIN_WORD_LENGTH
                        skip words shorter than this; default 1
  --numbers             also emphasise digit-only words
  --tag TAG             HTML tag for the fixation; default b
  --class CLASS_NAME    class attribute for the fixation tag
  --no-ignore-html-tags
                        treat the input as plain text and escape existing markup
  --markdown            emit Markdown (**prefix**rest) instead of HTML
  --version             show the version and exit
";

struct Args {
    file: Option<String>,
    fixation: u8,
    saccade: usize,
    min_word_length: usize,
    numbers: bool,
    tag: String,
    class_name: Option<String>,
    ignore_html_tags: bool,
    markdown: bool,
}

enum Early {
    Help,
    Version,
}

/// Parses the command line by hand (the crate has no dependencies).
///
/// Accepts both `--opt value` and `--opt=value`; `--` ends the options.
fn parse(arguments: impl IntoIterator<Item = String>) -> Result<Result<Args, Early>, String> {
    let mut args = Args {
        file: None,
        fixation: 3,
        saccade: 1,
        min_word_length: 1,
        numbers: false,
        tag: "b".to_owned(),
        class_name: None,
        ignore_html_tags: true,
        markdown: false,
    };
    let mut iter = arguments.into_iter();
    let mut only_positional = false;
    while let Some(arg) = iter.next() {
        if only_positional || !arg.starts_with('-') || arg == "-" {
            if args.file.is_some() {
                return Err(format!("unrecognized arguments: {arg}"));
            }
            args.file = Some(arg);
            continue;
        }
        if arg == "--" {
            only_positional = true;
            continue;
        }
        let (name, inline) = match arg.split_once('=') {
            Some((name, value)) => (name.to_owned(), Some(value.to_owned())),
            None => (arg.clone(), None),
        };
        let value = |iter: &mut dyn Iterator<Item = String>| -> Result<String, String> {
            inline
                .clone()
                .or_else(|| iter.next())
                .ok_or_else(|| format!("argument {name}: expected one argument"))
        };
        match name.as_str() {
            "-h" | "--help" => return Ok(Err(Early::Help)),
            "--version" => return Ok(Err(Early::Version)),
            "--numbers" => args.numbers = true,
            "--no-ignore-html-tags" => args.ignore_html_tags = false,
            "--markdown" => args.markdown = true,
            "--fixation" => {
                let raw = value(&mut iter)?;
                args.fixation = match raw.parse::<i64>() {
                    Ok(n @ 1..=5) => u8::try_from(n).map_err(|e| e.to_string())?,
                    Ok(_) => {
                        return Err(format!(
                            "argument --fixation: invalid choice: {raw} (choose from 1, 2, 3, 4, 5)"
                        ));
                    }
                    Err(_) => {
                        return Err(format!("argument --fixation: invalid int value: '{raw}'"));
                    }
                };
            }
            "--saccade" => args.saccade = parse_int(&value(&mut iter)?, "--saccade")?,
            "--min-word-length" => {
                args.min_word_length = parse_int(&value(&mut iter)?, "--min-word-length")?;
            }
            "--tag" => args.tag = value(&mut iter)?,
            "--class" => args.class_name = Some(value(&mut iter)?),
            _ => return Err(format!("unrecognized arguments: {arg}")),
        }
    }
    Ok(Ok(args))
}

/// An integer option; negative values clamp to `0` like every port (the
/// library then clamps `saccade` up to `1`).
fn parse_int(raw: &str, option: &str) -> Result<usize, String> {
    match raw.trim().parse::<i64>() {
        Ok(n) => Ok(usize::try_from(n.max(0)).unwrap_or(usize::MAX)),
        Err(_) => Err(format!("argument {option}: invalid int value: '{raw}'")),
    }
}

fn read_input(file: Option<&str>) -> io::Result<String> {
    let mut bytes = Vec::new();
    match file {
        None | Some("-") => io::stdin().lock().read_to_end(&mut bytes)?,
        Some(path) => std::fs::File::open(path)?.read_to_end(&mut bytes)?,
    };
    String::from_utf8(bytes).map_err(|error| io::Error::new(io::ErrorKind::InvalidData, error))
}

fn main() -> ExitCode {
    let args = match parse(std::env::args().skip(1)) {
        Ok(Ok(args)) => args,
        Ok(Err(Early::Help)) => {
            println!("{USAGE}{HELP}");
            return ExitCode::SUCCESS;
        }
        Ok(Err(Early::Version)) => {
            println!("smooth-reading {VERSION}");
            return ExitCode::SUCCESS;
        }
        Err(message) => {
            eprintln!("{USAGE}\nsmooth-reading: error: {message}");
            return ExitCode::from(2);
        }
    };

    let text = match read_input(args.file.as_deref()) {
        Ok(text) => text,
        Err(error) => {
            eprintln!("smooth-reading: {error}");
            return ExitCode::from(1);
        }
    };

    let options = Options::new()
        .fixation(args.fixation)
        .saccade(args.saccade)
        .min_word_length(args.min_word_length)
        .emphasize_numbers(args.numbers);
    let output = if args.markdown {
        to_markdown(&text, &options, "**")
    } else {
        let mut html = HtmlOptions::new()
            .tag(args.tag)
            .ignore_html_tags(args.ignore_html_tags);
        if let Some(class_name) = args.class_name {
            html = html.class_name(class_name);
        }
        to_html(&text, &options, &html)
    };

    let mut stdout = io::stdout().lock();
    if let Err(error) = stdout
        .write_all(output.as_bytes())
        .and_then(|()| stdout.flush())
    {
        eprintln!("smooth-reading: {error}");
        return ExitCode::from(1);
    }
    ExitCode::SUCCESS
}
