//! Scale budgets from the plan. Run with:
//! `cargo test -p kp-core --release --test scale -- --ignored --nocapture`

use std::fmt::Write as _;
use std::time::Instant;

use kp_core::store::SourceRow;
use kp_core::{m3u, Catalog, ContentKind, Store};

const GROUPS: &[&str] = &["Ulusal", "Spor", "Haber", "Belgesel", "Çocuk", "Müzik", "Filmler", "Diziler", "Yetişkin", "Dünya"];
const WORDS: &[&str] = &["TRT", "FOX Türk", "Show", "Kanal D", "ATV", "beIN Sports", "NTV", "Habertürk", "TV8", "Star", "Cartoon", "National Geographic"];

fn synthetic_playlist(n: usize) -> String {
    let mut s = String::with_capacity(n * 180);
    s.push_str("#EXTM3U url-tvg=\"http://127.0.0.1/epg.xml.gz\"\n");
    for i in 0..n {
        let group = GROUPS[i % GROUPS.len()];
        let word = WORDS[(i / GROUPS.len()) % WORDS.len()];
        let _ = writeln!(
            s,
            "#EXTINF:-1 tvg-id=\"ch{i}.tr\" tvg-name=\"{word} {i}\" tvg-logo=\"http://127.0.0.1/logo/{i}.png\" group-title=\"{group}\" catchup=\"default\" catchup-days=\"3\",{word} {i} HD\nhttp://127.0.0.1:8080/live/user/pass/{i}.ts"
        );
    }
    s
}

#[test]
#[ignore = "scale budget; run in --release"]
fn ingest_and_search_150k() {
    let n = 150_000;
    let text = synthetic_playlist(n);

    let t = Instant::now();
    let parsed = m3u::parse(&text);
    let catalog = Catalog::from_m3u(parsed);
    let parse_ms = t.elapsed().as_millis();
    assert_eq!(catalog.channels.len(), n);

    let dir = tempfile::tempdir().unwrap();
    let mut store = Store::open(dir.path().join("catalog.sqlite")).unwrap();
    store
        .upsert_source(&SourceRow {
            id: "src".into(),
            kind: "m3u".into(),
            name: "Synthetic".into(),
            url: "http://127.0.0.1/list.m3u".into(),
            username: None,
            epg_url: None,
            user_agent: None,
            insecure_tls: false,
            synced_at: None,
            last_error: None,
            expires_at: None,
            max_connections: None,
            timezone: None,
        })
        .unwrap();
    let t = Instant::now();
    store.replace_catalog("src", &catalog, 1).unwrap();
    let ingest_ms = t.elapsed().as_millis();

    let t = Instant::now();
    let page = store.channels_page("src", ContentKind::Live, None, Some(100_000), 200).unwrap();
    let page_us = t.elapsed().as_micros();
    assert_eq!(page.len(), 200);

    let mut search_us = Vec::new();
    for q in ["fox turk", "habertürk 1499", "sports", "tv"] {
        let t = Instant::now();
        let hits = store.search(q, None, 200).unwrap();
        search_us.push((q, t.elapsed().as_micros(), hits.len()));
    }

    println!("parse+catalog {n}: {parse_ms} ms (budget 1500)");
    println!("sqlite ingest + fts rebuild: {ingest_ms} ms");
    println!("deep keyset page: {page_us} us");
    for (q, us, hits) in &search_us {
        println!("search {q:?}: {us} us, {hits} hits (budget 50000 us)");
    }

    assert!(parse_ms < 1500, "parse budget exceeded: {parse_ms} ms");
    assert!(search_us.iter().all(|(_, us, _)| *us < 50_000), "search budget exceeded");
}
