//! End-to-end against tools/mock-iptv over real HTTP. Start the mock first:
//! `cargo run -p mock-iptv --release -- 8089`, then
//! `cargo test -p kp-core --test xtream_mock -- --ignored --nocapture`

use std::time::Instant;

use kp_core::core::{Core, NewSource, SourceKind};
use kp_core::secret::MemorySecrets;
use kp_core::ContentKind;

fn mock_url() -> String {
    std::env::var("KP_MOCK_URL").unwrap_or_else(|_| "http://127.0.0.1:8089".into())
}

fn xtream(password: &str) -> NewSource {
    NewSource {
        kind: SourceKind::Xtream,
        name: "Mock".into(),
        url: mock_url(),
        username: Some("demo".into()),
        password: Some(password.into()),
        epg_url: None,
        user_agent: None,
        insecure_tls: false,
    }
}

#[test]
#[ignore = "needs tools/mock-iptv running"]
fn xtream_source_end_to_end() {
    let core = Core::open_in_memory(Box::new(MemorySecrets::default())).unwrap();

    let err = core.add_source(xtream("yanlis"), &|_| {}).unwrap_err();
    assert!(err.to_string().contains("reddedildi"), "{err}");
    assert!(core.sources().unwrap().is_empty());

    let t = Instant::now();
    let (source, summary) = core.add_source(xtream("demo"), &|s| println!("stage: {s:?}")).unwrap();
    println!("add+sync: {} ms, {summary:?}", t.elapsed().as_millis());
    assert_eq!((summary.movies, summary.series), (240, 60));
    assert!(source.expires_at.is_some());

    let cats = core.categories(&source.id, ContentKind::Live).unwrap();
    assert_eq!(cats.last().unwrap().name, "XXX | Yetişkin", "adult category sorted last");
    assert_eq!(cats[0].name, "DE: Sport", "no preference: provider order");

    core.set_region_preference(Some("TR")).unwrap();
    let cats = core.categories(&source.id, ContentKind::Live).unwrap();
    assert_eq!(cats[0].name, "TR: Ulusal", "preferred region first");
    assert_eq!(cats.last().unwrap().name, "XXX | Yetişkin");
    let first = core.page(&source.id, ContentKind::Live, None, None, 1).unwrap();
    assert!(first[0].name.starts_with("Kanal"), "first channel is Turkish: {}", first[0].name);

    let live = core.page(&source.id, ContentKind::Live, Some(cats[0].uid), None, 50).unwrap();
    let play = core.playback(live[0].id, None).unwrap();
    assert!(play.url.starts_with(&format!("{}/live/demo/demo/", mock_url())), "{}", play.url);
    assert!(play.is_live);

    let epg = core.epg(live[0].id).unwrap();
    assert!(!epg.is_empty(), "short EPG decoded");
    assert!(epg[0].title.chars().all(|c| !c.is_control()));
    println!("epg now: {} ({}–{})", epg[0].title, epg[0].start, epg[0].stop);

    // Catch-up: past programmes with archive flags, played via timeshift.
    let all = core.page(&source.id, ContentKind::Live, None, None, 50).unwrap();
    let plain = all.iter().find(|i| !i.has_catchup).unwrap();
    assert!(core.archive(plain.id).unwrap().is_empty());
    let archived = all.iter().find(|i| i.has_catchup).unwrap();
    let past = core.archive(archived.id).unwrap();
    assert!(past.len() > 48, "three days of programmes: {}", past.len());
    assert!(past.windows(2).all(|w| w[0].start > w[1].start), "newest first");
    let shift = core.catchup(archived.id, past[0].start, past[0].stop).unwrap();
    assert!(shift.url.starts_with(&format!("{}/timeshift/demo/demo/", mock_url())), "{}", shift.url);
    assert!(!shift.is_live);
    let status = reqwest::blocking::Client::new()
        .get(&shift.url)
        .header("Range", "bytes=0-187")
        .send()
        .unwrap()
        .status();
    assert!(status.is_success(), "timeshift stream: {status}");

    let series = core.page(&source.id, ContentKind::Series, None, None, 1).unwrap();
    let detail = core.detail(series[0].id).unwrap();
    assert!(detail.episodes.len() >= 8);
    let ep = &detail.episodes[0];
    let ep_play = core.playback(series[0].id, Some((ep.ext_id, ep.container.clone()))).unwrap();
    assert!(ep_play.url.contains("/series/demo/demo/"));

    let hits = core.search("haber", Some(ContentKind::Live), 20).unwrap();
    assert!(!hits.is_empty());
}
