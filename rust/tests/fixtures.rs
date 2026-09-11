//! Runs every `fixtures/common/*.json` case through `to_html` and requires
//! byte-identical output: the cross-port contract of SPEC §6.

mod support;

use support::{fixture_files, load_fixtures};

#[test]
fn every_common_fixture_renders_byte_for_byte() {
    let fixtures = load_fixtures("common");
    assert!(!fixtures.is_empty(), "no common fixtures found");
    let failures: Vec<String> = fixtures
        .iter()
        .filter_map(|fixture| {
            let rendered = fixture.render();
            (rendered != fixture.html).then(|| {
                format!(
                    "{}\n  input:    {:?}\n  expected: {:?}\n  actual:   {:?}",
                    fixture.id(),
                    fixture.input,
                    fixture.html,
                    rendered
                )
            })
        })
        .collect();
    assert!(
        failures.is_empty(),
        "{} of {} common fixtures failed:\n{}",
        failures.len(),
        fixtures.len(),
        failures.join("\n")
    );
    eprintln!("{} common fixture cases passed", fixtures.len());
}

#[test]
fn every_common_fixture_file_is_exercised() {
    let files = fixture_files("common");
    let fixtures = load_fixtures("common");
    assert!(!files.is_empty(), "no fixture files in fixtures/common");
    for path in &files {
        let stem = path.file_stem().expect("file stem").to_string_lossy();
        let count = fixtures
            .iter()
            .filter(|f| f.file == format!("common/{stem}"))
            .count();
        assert!(
            count > 0,
            "fixtures/common/{stem}.json contributed no cases"
        );
    }
    // The multilingual suite is a release blocker; make sure it is really there.
    let names: Vec<String> = files
        .iter()
        .map(|path| {
            path.file_stem()
                .expect("file stem")
                .to_string_lossy()
                .into_owned()
        })
        .collect();
    for expected in [
        "basic",
        "edge-cases",
        "markup",
        "options",
        "saccade",
        "scripts",
    ] {
        assert!(
            names.contains(&expected.to_owned()),
            "fixtures/common/{expected}.json is missing"
        );
    }
}
