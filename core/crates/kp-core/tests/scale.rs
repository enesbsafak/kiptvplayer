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

/// M3 budget: a ~200 MB XMLTV guide ingests in < 20 s (peak memory is
/// checked from outside: tools/measure-guide.ps1).
#[test]
#[ignore = "writes a 200 MB file; run with --ignored --nocapture"]
fn xmltv_200mb_ingest() {
    use std::io::Write;
    let dir = tempfile::tempdir().unwrap();
    let xml = dir.path().join("big.xml");
    let now = kp_core::core::now();
    let fmt = |s: i64| chrono::DateTime::from_timestamp(s, 0).unwrap().format("%Y%m%d%H%M%S +0300").to_string();
    {
        let mut w = std::io::BufWriter::new(std::fs::File::create(&xml).unwrap());
        writeln!(w, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<tv>").unwrap();
        for c in 0..2000 {
            writeln!(w, "<channel id=\"ch{c}.tr\"><display-name>Kanal {c}</display-name></channel>").unwrap();
        }
        let start = now - 7 * 86_400;
        for c in 0..2000 {
            for k in 0..(10 * 48) {
                let s = start + k * 1800;
                writeln!(
                    w,
                    "<programme start=\"{}\" stop=\"{}\" channel=\"ch{c}.tr\"><title lang=\"tr\">Program {k} &amp; Haber</title>\
                     <desc lang=\"tr\">Kanal {c} için {k}. programın uzunca bir açıklaması; yayın akışı testleri için.</desc></programme>",
                    fmt(s),
                    fmt(s + 1800)
                )
                .unwrap();
            }
        }
        writeln!(w, "</tv>").unwrap();
    }
    let size = std::fs::metadata(&xml).unwrap().len();
    let channels: Vec<_> = (0..2000)
        .map(|c| kp_core::guide::GuideChannel { uid: c, tvg_id: Some(format!("ch{c}.tr")), name: format!("Kanal {c}") })
        .collect();
    let path = dir.path().join("guide-s.sqlite");
    let t = Instant::now();
    let input = kp_core::xmltv::decompressing(std::fs::File::open(&xml).unwrap()).unwrap();
    let stats = kp_core::guide::build(&path, input, &channels, now).unwrap();
    kp_core::guide::install(&path).unwrap();
    let took = t.elapsed();
    println!(
        "xmltv: {} MB, {} programmes, {} matched, ingest {} ms, guide file {} MB",
        size / 1_000_000,
        stats.programmes,
        stats.matched,
        took.as_millis(),
        std::fs::metadata(&path).unwrap().len() / 1_000_000
    );
    assert!(size > 150_000_000);
    assert!(took.as_secs() < 20, "budget: < 20 s");
}
