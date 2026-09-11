//! The `smooth-reading` binary, spawned as a subprocess. Mirrors the Python
//! port's `test_cli.py`.

use std::io::Write;
use std::process::{Command, Stdio};

const BIN: &str = env!("CARGO_BIN_EXE_smooth-reading");

struct Run {
    code: i32,
    stdout: String,
    stderr: String,
}

fn run(args: &[&str], stdin: &str) -> Run {
    let mut child = Command::new(BIN)
        .args(args)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("spawn smooth-reading");
    // A usage error makes the binary exit before reading stdin; on Linux the
    // write then fails with EPIPE, which is not a test failure.
    if let Err(error) = child
        .stdin
        .take()
        .expect("piped stdin")
        .write_all(stdin.as_bytes())
    {
        assert_eq!(
            error.kind(),
            std::io::ErrorKind::BrokenPipe,
            "write stdin: {error}"
        );
    }
    let output = child.wait_with_output().expect("wait for smooth-reading");
    Run {
        code: output.status.code().expect("exit code"),
        stdout: String::from_utf8(output.stdout).expect("utf-8 stdout"),
        stderr: String::from_utf8(output.stderr).expect("utf-8 stderr"),
    }
}

fn ok(args: &[&str], stdin: &str) -> String {
    let run = run(args, stdin);
    assert_eq!(run.code, 0, "stderr: {}", run.stderr);
    assert!(run.stderr.is_empty(), "stderr: {}", run.stderr);
    run.stdout
}

#[test]
fn reads_stdin() {
    assert_eq!(
        ok(&[], "Smooth reading works."),
        "<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks."
    );
}

#[test]
fn output_has_no_trailing_newline_unless_the_input_does() {
    assert_eq!(ok(&[], "smooth"), "<b>smo</b>oth");
    assert_eq!(ok(&[], "smooth\n"), "<b>smo</b>oth\n");
}

#[test]
fn dash_reads_stdin() {
    assert_eq!(ok(&["-"], "smooth"), "<b>smo</b>oth");
}

#[test]
fn reads_a_file() {
    let dir = std::env::temp_dir().join(format!("smooth-reading-cli-{}", std::process::id()));
    std::fs::create_dir_all(&dir).expect("temp dir");
    let path = dir.join("input.txt");
    std::fs::write(&path, "Smooth reading").expect("write input");
    assert_eq!(
        ok(&[path.to_str().expect("utf-8 path")], ""),
        "<b>Smo</b>oth <b>read</b>ing"
    );
    std::fs::remove_dir_all(&dir).expect("clean up");
}

#[test]
fn fixation_and_saccade() {
    assert_eq!(
        ok(
            &["--fixation", "5", "--saccade", "2"],
            "Smooth reading works."
        ),
        "<b>Smoot</b>h reading <b>work</b>s."
    );
    assert_eq!(
        ok(&["--fixation=5", "--saccade=2"], "Smooth reading works."),
        "<b>Smoot</b>h reading <b>work</b>s."
    );
}

#[test]
fn tag_and_class() {
    assert_eq!(
        ok(&["--tag", "span", "--class", "sr-fixation"], "smooth"),
        r#"<span class="sr-fixation">smo</span>oth"#
    );
}

#[test]
fn markdown() {
    assert_eq!(
        ok(&["--markdown"], "Smooth reading works."),
        "**Smo**oth **read**ing **wor**ks."
    );
}

#[test]
fn numbers() {
    assert_eq!(ok(&["--numbers"], "2024"), "<b>20</b>24");
    assert_eq!(ok(&[], "2024"), "2024");
}

#[test]
fn min_word_length() {
    assert_eq!(
        ok(&["--min-word-length", "4"], "the read"),
        "the <b>re</b>ad"
    );
}

#[test]
fn no_ignore_html_tags() {
    assert_eq!(
        ok(&["--no-ignore-html-tags"], "<i>hi</i>"),
        "&lt;<b>i</b>&gt;<b>h</b>i&lt;/<b>i</b>&gt;"
    );
}

#[test]
fn missing_file_reports_an_error() {
    let run = run(&["/definitely/not/here.txt"], "");
    assert_eq!(run.code, 1);
    assert!(
        run.stderr
            .starts_with("smooth-reading: /definitely/not/here.txt: "),
        "{}",
        run.stderr
    );
    assert!(run.stderr.contains("os error"), "{}", run.stderr);
    assert!(run.stdout.is_empty());
}

#[test]
fn boolean_flags_reject_an_explicit_value() {
    for arg in [
        "--numbers=foo",
        "--markdown=x",
        "--no-ignore-html-tags=x",
        "--help=1",
        "--version=2",
    ] {
        let result = run(&[arg], "x");
        assert_eq!(result.code, 2, "{arg}");
        assert!(result.stdout.is_empty(), "{arg}");
        let flag = arg.split('=').next().expect("flag");
        let value = arg.split('=').nth(1).expect("value");
        assert!(
            result.stderr.contains(&format!(
                "argument {flag}: ignored explicit argument '{value}'"
            )),
            "{arg}: {}",
            result.stderr
        );
    }
}

#[test]
fn invalid_fixation_is_rejected() {
    let result = run(&["--fixation", "9"], "x");
    assert_eq!(result.code, 2);
    assert!(result.stderr.contains("usage:"), "{}", result.stderr);
    assert!(result.stderr.contains("--fixation"), "{}", result.stderr);
    assert_eq!(run(&["--fixation", "abc"], "x").code, 2);
    assert_eq!(run(&["--saccade", "two"], "x").code, 2);
}

#[test]
fn unknown_options_and_extra_positionals_are_usage_errors() {
    assert_eq!(run(&["--bogus"], "x").code, 2);
    assert_eq!(run(&["a.txt", "b.txt"], "x").code, 2);
    assert_eq!(run(&["--tag"], "x").code, 2);
}

#[test]
fn out_of_range_saccade_is_clamped() {
    // SPEC §4: saccade < 1 is clamped to 1, so every word is emphasised.
    assert_eq!(ok(&["--saccade", "0"], "one two"), "<b>on</b>e <b>tw</b>o");
    assert_eq!(ok(&["--saccade", "-3"], "one two"), "<b>on</b>e <b>tw</b>o");
}

#[test]
fn help_and_version() {
    let help = run(&["--help"], "");
    assert_eq!(help.code, 0);
    assert!(
        help.stdout.starts_with("usage: smooth-reading"),
        "{}",
        help.stdout
    );
    assert!(help.stdout.contains("--min-word-length"), "{}", help.stdout);
    assert_eq!(run(&["-h"], "").code, 0);
    let version = run(&["--version"], "");
    assert_eq!(version.code, 0);
    assert_eq!(
        version.stdout,
        format!("smooth-reading {}\n", smooth_reading::VERSION)
    );
}

#[test]
fn unicode_input_round_trips() {
    assert_eq!(
        ok(&[], "iPhone手机很好用"),
        "<b>iPh</b>one<b>手机很</b>好用"
    );
    assert_eq!(ok(&["--markdown"], "naïve café"), "**naï**ve **ca**fé");
}
