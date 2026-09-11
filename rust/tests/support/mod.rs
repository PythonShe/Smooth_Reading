//! Loads the shared `fixtures/<group>/*.json` suites from the monorepo root.
//!
//! Mirrors `dart/test/fixtures.dart`: the camelCase option names of the spec
//! are mapped onto `Options`/`HtmlOptions`, and an unknown key is an error so
//! a new fixture option can never be silently ignored.

// Each test crate uses a different subset of this module.
#![allow(dead_code)]

use std::fs;
use std::path::{Path, PathBuf};

use serde_json::{Map, Value};
use smooth_reading::{DEFAULT_SKIP_TAGS, HtmlOptions, Options, to_html};

/// The repository's `fixtures/` directory, resolved from the crate root.
pub fn fixtures_root() -> PathBuf {
    let root = Path::new(concat!(env!("CARGO_MANIFEST_DIR"), "/../fixtures"));
    assert!(
        root.is_dir(),
        "fixtures directory not found at {}: the fixture suites only run from the monorepo checkout",
        root.display()
    );
    root.to_path_buf()
}

/// One case from `fixtures/<group>/<file>.json`.
pub struct Fixture {
    pub file: String,
    pub name: String,
    pub input: String,
    pub html: String,
    pub raw: Map<String, Value>,
}

const ALGORITHM_KEYS: [&str; 5] = [
    "fixation",
    "saccade",
    "minWordLength",
    "emphasizeNumbers",
    "locale",
];
const HTML_KEYS: [&str; 6] = [
    "tag",
    "className",
    "restTag",
    "restClassName",
    "ignoreHtmlTags",
    "skipTags",
];

impl Fixture {
    pub fn id(&self) -> String {
        format!("{}: {}", self.file, self.name)
    }

    /// An integer option. The spec lets a negative value behave like `0` and
    /// clamps the rest; the Rust API's unsigned types exclude negatives, so
    /// the harness applies that first step (`-1` -> `0`) and saturates.
    fn int(&self, key: &str) -> Option<u64> {
        self.raw.get(key).map(|value| {
            let signed = value
                .as_i64()
                .unwrap_or_else(|| panic!("{}: option {key} must be an integer", self.id()));
            u64::try_from(signed.max(0)).expect("non-negative")
        })
    }

    fn string(&self, key: &str) -> Option<String> {
        self.raw.get(key).map(|value| {
            value
                .as_str()
                .unwrap_or_else(|| panic!("{}: option {key} must be a string", self.id()))
                .to_owned()
        })
    }

    fn boolean(&self, key: &str) -> Option<bool> {
        self.raw.get(key).map(|value| {
            value
                .as_bool()
                .unwrap_or_else(|| panic!("{}: option {key} must be a boolean", self.id()))
        })
    }

    /// Algorithm options, using the spec's camelCase names.
    pub fn options(&self) -> Options {
        for key in self.raw.keys() {
            assert!(
                ALGORITHM_KEYS.contains(&key.as_str()) || HTML_KEYS.contains(&key.as_str()),
                "{}: unknown fixture option {key}",
                self.id()
            );
        }
        let mut options = Options::new()
            .fixation(u8::try_from(self.int("fixation").unwrap_or(3)).unwrap_or(u8::MAX))
            .saccade(usize::try_from(self.int("saccade").unwrap_or(1)).expect("saccade fits usize"))
            .min_word_length(
                usize::try_from(self.int("minWordLength").unwrap_or(1))
                    .expect("minWordLength fits usize"),
            )
            .emphasize_numbers(self.boolean("emphasizeNumbers").unwrap_or(false));
        if let Some(locale) = self.string("locale") {
            options = options.locale(locale);
        }
        options
    }

    /// The fixture's HTML options fed to `to_html`.
    pub fn html_options(&self) -> HtmlOptions {
        let mut html = HtmlOptions::new()
            .tag(self.string("tag").unwrap_or_else(|| "b".to_owned()))
            .ignore_html_tags(self.ignore_html_tags());
        if let Some(class_name) = self.string("className") {
            html = html.class_name(class_name);
        }
        if let Some(rest_tag) = self.string("restTag") {
            html = html.rest_tag(rest_tag);
        }
        if let Some(rest_class_name) = self.string("restClassName") {
            html = html.rest_class_name(rest_class_name);
        }
        let skip_tags: Vec<String> = match self.raw.get("skipTags") {
            Some(value) => value
                .as_array()
                .unwrap_or_else(|| panic!("{}: skipTags must be an array", self.id()))
                .iter()
                .map(|tag| {
                    tag.as_str()
                        .expect("skipTags entries are strings")
                        .to_owned()
                })
                .collect(),
            None => DEFAULT_SKIP_TAGS
                .iter()
                .map(|&tag| tag.to_owned())
                .collect(),
        };
        html.skip_tags(skip_tags)
    }

    pub fn ignore_html_tags(&self) -> bool {
        self.boolean("ignoreHtmlTags").unwrap_or(true)
    }

    pub fn render(&self) -> String {
        to_html(&self.input, &self.options(), &self.html_options())
    }

    /// The emphasis tags the rendered markup may contain.
    pub fn emphasis_tags(&self) -> Vec<String> {
        let mut tags = vec![self.string("tag").unwrap_or_else(|| "b".to_owned())];
        if let Some(rest_tag) = self.string("restTag") {
            tags.push(rest_tag);
        }
        tags
    }
}

/// The `.json` files of `fixtures/<group>/`, sorted by name.
pub fn fixture_files(group: &str) -> Vec<PathBuf> {
    let dir = fixtures_root().join(group);
    let mut files: Vec<PathBuf> = fs::read_dir(&dir)
        .unwrap_or_else(|error| panic!("cannot list {}: {error}", dir.display()))
        .map(|entry| entry.expect("directory entry").path())
        .filter(|path| path.extension().is_some_and(|ext| ext == "json"))
        .collect();
    files.sort();
    files
}

/// Every case in `fixtures/<group>/*.json`, in file order.
pub fn load_fixtures(group: &str) -> Vec<Fixture> {
    let mut fixtures = Vec::new();
    for path in fixture_files(group) {
        let stem = path
            .file_stem()
            .expect("file stem")
            .to_string_lossy()
            .into_owned();
        let text = fs::read_to_string(&path)
            .unwrap_or_else(|error| panic!("cannot read {}: {error}", path.display()));
        let cases: Vec<Value> = serde_json::from_str(&text)
            .unwrap_or_else(|error| panic!("invalid JSON in {}: {error}", path.display()));
        for case in cases {
            let object = case.as_object().expect("a fixture case is an object");
            let field = |key: &str| {
                object
                    .get(key)
                    .and_then(Value::as_str)
                    .unwrap_or_else(|| {
                        panic!("{}: case is missing string field {key}", path.display())
                    })
                    .to_owned()
            };
            fixtures.push(Fixture {
                file: format!("{group}/{stem}"),
                name: field("name"),
                input: field("input"),
                html: field("html"),
                raw: object
                    .get("options")
                    .map(|options| options.as_object().expect("options is an object").clone())
                    .unwrap_or_default(),
            });
        }
    }
    fixtures
}
