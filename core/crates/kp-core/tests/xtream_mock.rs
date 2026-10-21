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

    let health = core.check_source(&source.id).unwrap();
    assert!(health.ok, "{health:?}");
    assert_eq!((health.active_connections, health.max_connections), (Some(0), Some(2)));
    assert!(health.expires_at.is_some());
}

#[test]
#[ignore = "needs tools/mock-iptv running"]
fn tmdb_enriches_films_and_series() {
    // The mock answers TMDB's API shapes under /3 and images under /t/p.
    std::env::set_var("KP_TMDB_BASE", mock_url());
    let core = Core::open_in_memory(Box::new(MemorySecrets::default())).unwrap();
    let (source, _) = core.add_source(xtream("demo"), &|_| {}).unwrap();
    let movie = core.page(&source.id, ContentKind::Movie, None, None, 1).unwrap().remove(0);
    let series = core.page(&source.id, ContentKind::Series, None, None, 1).unwrap().remove(0);

    assert!(core.tmdb_for(movie.id).unwrap().is_none(), "no key, no TMDB call");
    assert!(!core.tmdb_status().unwrap().configured);
    let err = core.set_tmdb_key(Some("yanlis-anahtar")).unwrap_err();
    assert!(err.to_string().contains("geçersiz"), "{err}");
    assert!(!core.tmdb_status().unwrap().configured, "a rejected key is not saved");

    // v4 read access token (Bearer), then a v3 key (api_key).
    core.set_tmdb_key(Some("eyJrcC1tb2NrLXRva2VuIn0")).unwrap();
    core.set_tmdb_key(Some("kp-mock-tmdb-key")).unwrap();
    assert!(core.tmdb_status().unwrap().configured);

    let d = core.tmdb_for(movie.id).unwrap().expect("film matched by title and year");
    assert!(d.overview.unwrap().starts_with("TMDB özeti"));
    assert_eq!((d.cast.len(), d.certification.as_deref(), d.trailer.as_deref()), (6, Some("13+"), Some("kp-mock-trailer")));
    assert_eq!(d.makers, vec!["Ayşe Karadeniz"]);
    assert!(d.poster.unwrap().starts_with(&format!("{}/t/p/w500/", mock_url())));

    let tv = core.tmdb_for(series.id).unwrap().expect("series matched");
    assert_eq!(tv.certification.as_deref(), Some("16+"));
    let eps = core.tmdb_season(series.id, 1).unwrap();
    assert_eq!(eps.len(), 8);
    assert!(eps[0].name.as_deref().unwrap().starts_with("1. Sezon 1. Bölüm"));

    // Cached: a second look needs no network (same answer, instantly).
    let t = Instant::now();
    assert!(core.tmdb_for(movie.id).unwrap().is_some());
    assert!(t.elapsed().as_millis() < 50, "served from cache");
}

#[test]
#[ignore = "needs tools/mock-iptv running"]
fn m3u_with_xmltv_guide_and_catchup() {
    let core = Core::open_in_memory(Box::new(MemorySecrets::default())).unwrap();
    let t = Instant::now();
    let (source, summary) = core
        .add_source(
            NewSource {
                kind: SourceKind::M3u,
                name: "M3U".into(),
                url: format!("{}/playlist.m3u?n=120", mock_url()),
                username: None,
                password: None,
                epg_url: None, // announced by the playlist's url-tvg header
                user_agent: None,
                insecure_tls: false,
            },
            &|s| println!("stage: {s:?}"),
        )
        .unwrap();
    println!("m3u add + guide: {} ms", t.elapsed().as_millis());
    assert_eq!(summary.live, 120);
    let status = core.guide_status(&source.id).unwrap().expect("guide downloaded during sync");
    assert!(status.ok, "{status:?}");
    assert_eq!((status.matched, status.channels), (120, 120), "tvg-id and name matches");
    assert!(status.programmes > 120 * 100);

    let channels = core.page(&source.id, ContentKind::Live, None, None, 200).unwrap();
    let by_name = |n: &str| channels.iter().find(|c| c.name == n).unwrap().id;
    let now_next = core.epg(by_name("Kanal 1")).unwrap();
    let t = kp_core::core::now();
    assert!(now_next[0].start <= t && now_next[0].stop > t, "current programme first");
    assert!(!core.epg(by_name("Kanal 9")).unwrap().is_empty(), "no tvg-id: matched by name");

    // Kanal 0 has a 3-day append-style archive.
    let past = core.archive(by_name("Kanal 0")).unwrap();
    assert!(past.len() > 48, "{}", past.len());
    let replay = core.catchup(by_name("Kanal 0"), past[0].start, past[0].stop).unwrap();
    assert!(replay.url.contains(&format!("?utc={}&lutc=", past[0].start)), "{}", replay.url);
    assert!(core.archive(by_name("Kanal 1")).unwrap().is_empty(), "no archive without catchup");

    // The user's corrections: an hour later, then Kanal 2's guide for Kanal 1.
    let k1 = by_name("Kanal 1");
    let before = core.epg(k1).unwrap();
    core.set_epg_settings(k1, None, 60).unwrap();
    let later = core.epg(k1).unwrap();
    assert!(later.iter().any(|p| p.title == before[0].title && p.start == before[0].start + 3600), "shifted an hour");
    let settings = core.epg_settings(k1).unwrap();
    assert!(settings.has_guide && settings.mapped.is_some() && settings.shift_min == 60);
    let other = core.find_guide_channels(&source.id, "Kanal 2", 5).unwrap();
    assert!(!other.is_empty());
    core.set_epg_settings(k1, Some(&other[0].0), 0).unwrap();
    assert_eq!(core.epg(k1).unwrap()[0].title, core.epg(by_name("Kanal 2")).unwrap()[0].title, "the picked guide channel");
    core.set_epg_settings(k1, Some(""), 0).unwrap();
    assert!(core.epg(k1).unwrap().is_empty(), "no guide on purpose");

    // A refresh swaps the guide while it is open, and keeps the corrections.
    core.refresh_guide(&source.id).unwrap();
    assert!(core.epg(k1).unwrap().is_empty());
    core.set_epg_settings(k1, None, 0).unwrap();
    assert!(!core.epg(k1).unwrap().is_empty());
    core.delete_source(&source.id).unwrap();
}

#[test]
#[ignore = "needs tools/mock-iptv running"]
fn stalker_portal_end_to_end() {
    let core = Core::open_in_memory(Box::new(MemorySecrets::default())).unwrap();
    let portal = |mac: &str| NewSource {
        kind: SourceKind::Stalker,
        name: "Portal".into(),
        url: format!("{}/stalker_portal/c/", mock_url()),
        username: None,
        password: Some(mac.into()),
        epg_url: None,
        user_agent: None,
        insecure_tls: false,
    };
    let err = core.add_source(portal("00:1A:79:FF:FF:FF"), &|_| {}).unwrap_err();
    assert!(err.to_string().contains("MAC"), "{err}");
    assert!(core.add_source(portal("not-a-mac"), &|_| {}).is_err());
    assert!(core.sources().unwrap().is_empty());

    // Typed sloppily: dashes, lower case.
    let (source, summary) = core.add_source(portal("00-1a-79-00-00-01"), &|_| {}).unwrap();
    assert_eq!(summary.live, 40);
    assert!(source.expires_at.is_some(), "account end date from the portal");
    let health = core.check_source(&source.id).unwrap();
    assert!(health.ok && health.expires_at.is_some(), "{health:?}");
    let cats = core.categories(&source.id, ContentKind::Live).unwrap();
    assert_eq!(cats.last().unwrap().name, "XXX", "adult genre last");

    let first = core.page(&source.id, ContentKind::Live, None, None, 5).unwrap();
    assert_eq!(first[0].chno, Some(1));
    let play = core.playback(first[0].id, None).unwrap();
    assert!(play.url.starts_with(&format!("{}/stalker/play/9000.ts?play_token=", mock_url())), "{}", play.url);
    let status = reqwest::blocking::get(&play.url).unwrap().status();
    assert!(status.is_success(), "fresh link plays: {status}");
    assert!(!core.epg(first[0].id).unwrap().is_empty(), "short EPG from the portal");

    // Films: three categories of 30 (14 per page), every tenth a series and left out.
    assert_eq!(summary.movies, 81);
    let film = core.page(&source.id, ContentKind::Movie, None, None, 1).unwrap().remove(0);
    let play = core.playback(film.id, None).unwrap();
    assert!(play.url.contains("/stalker/play/vod-"), "{}", play.url);
    assert!(!play.is_live);
}

#[test]
#[ignore = "needs tools/mock-iptv running"]
fn opensubtitles_search_and_download() {
    std::env::set_var("KP_OPENSUBS_BASE", format!("{}/os/api/v1", mock_url()));
    let core = Core::open_in_memory(Box::new(MemorySecrets::default())).unwrap();
    let (source, _) = core.add_source(xtream("demo"), &|_| {}).unwrap();
    let film = core.page(&source.id, ContentKind::Movie, None, None, 1).unwrap().remove(0);

    assert!(core.subtitle_search(film.id, None).unwrap_err().to_string().contains("anahtar"), "no key yet");
    assert!(core.set_opensubs_key(Some("yanlis")).unwrap_err().to_string().contains("reddedildi"));
    core.set_opensubs_key(Some("kp-mock-os-key")).unwrap();
    assert!(core.opensubs_configured());

    let found = core.subtitle_search(film.id, None).unwrap();
    assert_eq!(found.len(), 3);
    assert_eq!((found[0].language.as_str(), found[0].downloads), ("tr", 4200), "most downloaded first");
    let (path, left) = core.subtitle_download(found[0].file_id).unwrap();
    let text = std::fs::read_to_string(&path).unwrap();
    assert!(text.contains("OpenSubtitles test altyazısı 9001") && text.contains("çğıöşü"), "{text}");
    assert_eq!(left, Some(19));

    let series = core.page(&source.id, ContentKind::Series, None, None, 1).unwrap().remove(0);
    let ep = core.subtitle_search(series.id, Some((1, 2))).unwrap();
    assert!(ep[0].release.contains(".E02."), "{}", ep[0].release);
    core.set_opensubs_key(None).unwrap();
    assert!(!core.opensubs_configured());
}
