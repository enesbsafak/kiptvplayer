//! Local stand-in for an IPTV provider.
//!
//! `cargo run -p mock-iptv -- [port] [media-dir]` serves:
//! - `/player_api.php`         Xtream API (user `demo`, password `demo`)
//! - `/live|movie|series/...`  stream endpoints backed by the test media
//! - `/media/*`                test streams, posters and logos from `make-media.ps1`
//! - `/spike/channels.json`    channel list for the M0 playback spike
//! - `/playlist.m3u?n=N`       synthetic M3U with N channels (scale tests)
//!
//! Catalog size: `KP_MOCK_LIVE` (default 600) live channels, 240 movies, 60 series.

use std::collections::HashMap;
use std::fmt::Write as _;
use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use axum::body::Body;
use axum::extract::{Path, Query, Request, State};
use axum::http::{header, StatusCode};
use axum::response::{IntoResponse, Redirect, Response};
use axum::routing::{get, post};
use axum::{Json, Router};
use base64::Engine as _;
use serde_json::{json, Value};
use tower::ServiceExt as _;
use tower_http::services::{ServeDir, ServeFile};

const USER: &str = "demo";
const PASS: &str = "demo";

/// Test streams the spike cycles through, as (file, label).
const STREAMS: &[(&str, &str)] = &[
    ("hls720/index.m3u8", "HLS 720p H.264"),
    ("hls1080/index.m3u8", "HLS 1080p H.264"),
    ("ts1080.ts", "TS 1080p H.264"),
    ("ts2160hevc.ts", "TS 2160p HEVC"),
];

/// Provider-style labels in a typical messy order: adult first, foreign
/// regions before Turkish ones. The app should show TR first, adult last.
const LIVE_CATS: &[&str] = &[
    "XXX | Yetişkin", "DE: Sport", "UK: News", "TR: Ulusal", "TR: Haber", "TR: Spor", "TR: Belgesel", "TR: Çocuk",
    "TR: Müzik", "Dünya",
];
const LIVE_NAMES: &[&str] = &[
    "Gece", "Sport", "News", "Kanal", "Haber", "Spor", "Belgesel", "Çocuk", "Müzik", "World",
];
const SHOWS: &[&str] = &[
    "Sabah Haberleri", "Gün Ortası", "Ana Haber", "Belgesel Kuşağı", "Dizi Tekrarı", "Canlı Maç", "Spor Gündemi",
    "Çizgi Film", "Müzik Listesi", "Gece Sineması", "Yemek Saati", "Hava Durumu", "Tartışma Programı", "Magazin",
];
const MOVIE_CATS: &[&str] = &["Aksiyon", "Komedi", "Dram", "Bilim Kurgu", "Belgesel", "Animasyon"];
const SERIES_CATS: &[&str] = &["Yerli Diziler", "Yabancı Diziler", "Mini Diziler"];
const TITLE_A: &[&str] = &["Karanlık", "Son", "Kayıp", "Gizli", "Sessiz", "Kırmızı", "Uzak", "Büyük", "Yalnız", "Soğuk"];
const TITLE_B: &[&str] = &["Şehir", "Yol", "Gece", "Ufuk", "Ada", "Liman", "Deniz", "Orman", "İz", "Rüya", "Kule", "Saat"];

/// The same tables in English (KP_MOCK_LANG=en): store screenshots for an
/// English listing. All names are made up.
const LIVE_CATS_EN: &[&str] = &[
    "XXX | Adult", "DE: Sport", "FR: Info", "UK: Entertainment", "UK: News", "UK: Sport", "UK: Documentary", "UK: Kids",
    "UK: Music", "World",
];
const LIVE_NAMES_EN: &[&str] = &[
    "Night", "Sport", "News", "Channel", "Headline", "Arena", "Discovery", "Kids", "Music", "World",
];
const SHOWS_EN: &[&str] = &[
    "Morning News", "Midday", "Evening News", "Nature Hour", "Drama Rerun", "Live Match", "Sports Desk",
    "Cartoons", "Top Tracks", "Late Movie", "Cooking Time", "Weather", "Debate", "Showbiz",
];
const MOVIE_CATS_EN: &[&str] = &["Action", "Comedy", "Drama", "Science Fiction", "Documentary", "Animation"];
const SERIES_CATS_EN: &[&str] = &["Drama Series", "Crime Series", "Mini Series"];
const TITLE_A_EN: &[&str] = &["Dark", "Last", "Lost", "Hidden", "Silent", "Red", "Distant", "Great", "Lonely", "Cold"];
const TITLE_B_EN: &[&str] = &["City", "Road", "Night", "Horizon", "Island", "Harbour", "Sea", "Forest", "Trace", "Dream", "Tower", "Hour"];

/// KP_MOCK_LANG=en switches every name to English; Turkish otherwise.
fn en() -> bool {
    static EN: std::sync::OnceLock<bool> = std::sync::OnceLock::new();
    *EN.get_or_init(|| std::env::var("KP_MOCK_LANG").is_ok_and(|v| v == "en"))
}

fn tx(tr: &'static str, en_text: &'static str) -> &'static str {
    if en() { en_text } else { tr }
}

fn live_cats() -> &'static [&'static str] { if en() { LIVE_CATS_EN } else { LIVE_CATS } }
fn live_names() -> &'static [&'static str] { if en() { LIVE_NAMES_EN } else { LIVE_NAMES } }
fn shows() -> &'static [&'static str] { if en() { SHOWS_EN } else { SHOWS } }
fn movie_cats() -> &'static [&'static str] { if en() { MOVIE_CATS_EN } else { MOVIE_CATS } }
fn series_cats() -> &'static [&'static str] { if en() { SERIES_CATS_EN } else { SERIES_CATS } }

#[derive(Clone)]
struct AppState {
    base: String,
    media: Arc<PathBuf>,
    live: usize,
}

#[tokio::main]
async fn main() {
    let mut args = std::env::args().skip(1);
    let port: u16 = args.next().and_then(|p| p.parse().ok()).unwrap_or(8089);
    let media: PathBuf = args
        .next()
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("media"));
    let live = std::env::var("KP_MOCK_LIVE").ok().and_then(|v| v.parse().ok()).unwrap_or(600);

    let state = AppState { base: format!("http://127.0.0.1:{port}"), media: Arc::new(media.clone()), live };
    let app = Router::new()
        .route("/player_api.php", get(player_api))
        .route("/live/{user}/{pass}/{file}", get(live_stream))
        .route("/movie/{user}/{pass}/{file}", get(vod_stream))
        .route("/series/{user}/{pass}/{file}", get(vod_stream))
        .route("/timeshift/{user}/{pass}/{minutes}/{start}/{file}", get(timeshift_stream))
        .route("/spike/channels.json", get(spike_channels))
        .route("/playlist.m3u", get(playlist))
        .route("/xmltv.xml", get(xmltv))
        // Stalker / Ministra portal: MAC 00:1A:79:00:00:01.
        .route("/stalker_portal/server/load.php", get(stalker))
        .route("/stalker/play/{file}", get(stalker_play))
        .route("/xmltv.xml.gz", get(xmltv_gz))
        // TMDB stand-in: the real API's shapes for the titles above.
        .route("/3/authentication", get(tmdb_auth))
        .route("/3/search/{media}", get(tmdb_search))
        .route("/3/movie/{id}", get(tmdb_movie))
        .route("/3/tv/{id}", get(tmdb_tv))
        .route("/3/tv/{id}/season/{season}", get(tmdb_season))
        .route("/t/p/{size}/{file}", get(tmdb_image))
        // OpenSubtitles stand-in: key kp-mock-os-key.
        .route("/os/api/v1/infos/formats", get(os_formats))
        .route("/os/api/v1/subtitles", get(os_search))
        .route("/os/api/v1/download", post(os_download))
        .route("/os/file/{id}", get(os_file))
        .nest_service("/media", ServeDir::new(&media))
        .with_state(state);

    let addr = SocketAddr::from(([127, 0, 0, 1], port));
    println!("mock-iptv listening on http://{addr} (media: {}, live: {live})", media.display());
    let listener = tokio::net::TcpListener::bind(addr).await.expect("bind");
    axum::serve(listener, app).await.expect("serve");
}

fn now() -> i64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0)
}

fn title(i: usize) -> String {
    let (a, b) = if en() { (TITLE_A_EN, TITLE_B_EN) } else { (TITLE_A, TITLE_B) };
    format!("{} {}", a[i % a.len()], b[(i / a.len()) % b.len()])
}

/// A programme's guide description.
fn describe(show: &str) -> String {
    if en() { format!("About {show}.") } else { format!("{show} programının açıklaması.") }
}

/// Series names: "<title> Dizisi", or "The <title> Series" in English.
fn series_title(i: usize) -> String {
    if en() { format!("The {} Series", title(i + 7)) } else { format!("{} Dizisi", title(i + 7)) }
}

fn b64(s: &str) -> String {
    base64::engine::general_purpose::STANDARD.encode(s)
}

async fn player_api(State(s): State<AppState>, Query(q): Query<HashMap<String, String>>) -> Response {
    let authed = q.get("username").map(String::as_str) == Some(USER) && q.get("password").map(String::as_str) == Some(PASS);
    let action = q.get("action").map(String::as_str).unwrap_or("");
    if !authed {
        return Json(json!({"user_info": {"auth": 0}})).into_response();
    }
    let body: Value = match action {
        "" => json!({
            "user_info": {
                "auth": 1, "status": "Active", "username": USER, "exp_date": (now() + 86_400 * 180).to_string(),
                "is_trial": "0", "active_cons": "0", "max_connections": "2",
                "allowed_output_formats": ["m3u8", "ts"]
            },
            "server_info": {"url": "127.0.0.1", "timezone": "Europe/Istanbul", "timestamp_now": now()}
        }),
        "get_live_categories" => categories(live_cats()),
        "get_vod_categories" => categories(movie_cats()),
        "get_series_categories" => categories(series_cats()),
        "get_live_streams" => Value::Array(
            (0..s.live)
                .map(|i| {
                    let cat = i % live_cats().len();
                    json!({
                        "num": i + 1,
                        "name": format!("{} {} HD", live_names()[cat], i / live_cats().len() + 1),
                        "stream_type": "live",
                        "stream_id": 1000 + i,
                        "stream_icon": format!("{}/media/logos/{}.png", s.base, i % 12),
                        "epg_channel_id": format!("ch{i}.tr"),
                        "category_id": (cat + 1).to_string(),
                        "tv_archive": if i % 3 == 0 { 1 } else { 0 },
                        "tv_archive_duration": if i % 3 == 0 { "3" } else { "0" },
                        "is_adult": if cat == 0 { "1" } else { "0" },
                        "added": (now() - (i as i64) * 600).to_string()
                    })
                })
                .collect(),
        ),
        "get_vod_streams" => Value::Array(
            (0..240)
                .map(|i| {
                    json!({
                        "num": i + 1,
                        "name": title(i),
                        "stream_type": "movie",
                        "stream_id": 5000 + i,
                        "stream_icon": format!("{}/media/posters/{}.jpg", s.base, i % 24),
                        "rating": format!("{:.1}", 5.0 + (i % 50) as f32 / 10.0),
                        "category_id": (i % movie_cats().len() + 1).to_string(),
                        "container_extension": "ts",
                        "year": (1995 + i % 30).to_string(),
                        "added": (now() - (i as i64) * 3_600).to_string()
                    })
                })
                .collect(),
        ),
        "get_series" => Value::Array(
            (0..60)
                .map(|i| {
                    json!({
                        "num": i + 1,
                        "name": series_title(i),
                        "series_id": 8000 + i,
                        "cover": format!("{}/media/posters/{}.jpg", s.base, (i + 5) % 24),
                        "rating": format!("{:.1}", 6.0 + (i % 40) as f32 / 10.0),
                        "category_id": (i % series_cats().len() + 1).to_string(),
                        "releaseDate": format!("{}-01-01", 2010 + i % 15),
                        "last_modified": (now() - (i as i64) * 7_200).to_string()
                    })
                })
                .collect(),
        ),
        "get_vod_info" => {
            let id: i64 = q.get("vod_id").and_then(|v| v.parse().ok()).unwrap_or(5000);
            let i = (id - 5000).max(0) as usize;
            json!({
                "info": {
                    "name": title(i),
                    "plot": tx("Küçük bir sahil kasabasında geçen, sırlarla dolu bir hikâye. Test verisidir; gerçek bir yapımı temsil etmez.", "A story full of secrets in a small seaside town. Test data; not a real production."),
                    "genre": movie_cats()[i % movie_cats().len()],
                    "cast": tx("Oyuncu Bir, Oyuncu İki, Oyuncu Üç", "Actor One, Actor Two, Actor Three"),
                    "director": tx("Yönetmen Adı", "Director Name"),
                    "duration_secs": 120,
                    "backdrop_path": [format!("{}/media/backdrops/{}.jpg", s.base, i % 4)],
                    "rating": "7.4"
                },
                "movie_data": {"stream_id": id, "container_extension": "ts"}
            })
        }
        "get_series_info" => {
            let id: i64 = q.get("series_id").and_then(|v| v.parse().ok()).unwrap_or(8000);
            let i = (id - 8000).max(0) as usize;
            let mut seasons = serde_json::Map::new();
            for season in 1..=(1 + i % 3) {
                let episodes: Vec<Value> = (1..=8)
                    .map(|e| {
                        json!({
                            "id": (id * 100 + (season * 10 + e) as i64).to_string(),
                            "episode_num": e,
                            "season": season,
                            "title": if en() { format!("Season {} Episode {}", season, e) } else { format!("{}. Sezon {}. Bölüm", season, e) },
                            "container_extension": "ts",
                            "info": {
                                "plot": tx("Bölüm özeti. Test verisidir.", "Episode summary. Test data."),
                                "duration_secs": 120,
                                "movie_image": format!("{}/media/backdrops/{}.jpg", s.base, (e + season) % 4)
                            }
                        })
                    })
                    .collect();
                seasons.insert(season.to_string(), Value::Array(episodes));
            }
            json!({
                "info": {
                    "name": series_title(i),
                    "plot": tx("Bir ailenin üç kuşağa yayılan hikâyesi. Test verisidir.", "A family story across three generations. Test data."),
                    "genre": series_cats()[i % series_cats().len()],
                    "cast": tx("Oyuncu Bir, Oyuncu İki", "Actor One, Actor Two"),
                    "backdrop_path": [format!("{}/media/backdrops/{}.jpg", s.base, i % 4)],
                    "episode_run_time": "2"
                },
                "episodes": seasons
            })
        }
        "get_short_epg" => {
            let id: usize = q.get("stream_id").and_then(|v| v.parse().ok()).unwrap_or(1000);
            let limit: usize = q.get("limit").and_then(|v| v.parse().ok()).unwrap_or(4);
            let t = now();
            let listings: Vec<Value> =
                schedule(id, t, t + 86_400).into_iter().take(limit).map(|p| p.json(false)).collect();
            json!({"epg_listings": listings})
        }
        // Full table: three days back (the archive window) to a day ahead.
        "get_simple_data_table" => {
            let id: usize = q.get("stream_id").and_then(|v| v.parse().ok()).unwrap_or(1000);
            let t = now();
            let archive = (id - 1000) % 3 == 0;
            let listings: Vec<Value> = schedule(id, t - 3 * 86_400, t + 86_400)
                .into_iter()
                .map(|p| {
                    let past = p.stop <= t;
                    p.json(archive && past)
                })
                .collect();
            json!({"epg_listings": listings})
        }
        _ => json!([]),
    };
    Json(body).into_response()
}

struct Programme {
    start: i64,
    stop: i64,
    show: &'static str,
}

impl Programme {
    fn json(&self, has_archive: bool) -> Value {
        json!({
            "title": b64(self.show),
            "description": b64(&describe(self.show)),
            "start_timestamp": self.start.to_string(),
            "stop_timestamp": self.stop.to_string(),
            "has_archive": if has_archive { 1 } else { 0 }
        })
    }
}

/// A channel's programmes that end after [from] and start before [to].
/// Half-hour and hour blocks restart every UTC midnight, so the schedule is a
/// pure function of time: short EPG, full table and archive agree.
fn schedule(id: usize, from: i64, to: i64) -> Vec<Programme> {
    let mut out = Vec::new();
    let mut day = from - from.rem_euclid(86_400);
    while day < to {
        let (mut start, mut k) = (day, 0usize);
        while start < day + 86_400 {
            let len = if (id + k) % 3 == 0 { 3600 } else { 1800 };
            let stop = (start + len).min(day + 86_400);
            if stop > from && start < to {
                out.push(Programme { start, stop, show: shows()[(id + k + (day / 86_400) as usize) % shows().len()] });
            }
            start = stop;
            k += 1;
        }
        day += 86_400;
    }
    out
}

fn categories(names: &[&str]) -> Value {
    Value::Array(
        names
            .iter()
            .enumerate()
            .map(|(i, n)| json!({"category_id": (i + 1).to_string(), "category_name": n, "parent_id": 0}))
            .collect(),
    )
}

fn check_creds(user: &str, pass: &str) -> Result<(), Response> {
    if user == USER && pass == PASS { Ok(()) } else { Err(StatusCode::FORBIDDEN.into_response()) }
}

async fn live_stream(State(s): State<AppState>, Path((user, pass, file)): Path<(String, String, String)>, req: Request) -> Response {
    if let Err(r) = check_creds(&user, &pass) {
        return r;
    }
    let (id, ext) = file.rsplit_once('.').unwrap_or((&file, "ts"));
    let id: usize = id.parse().unwrap_or(0);
    if ext == "m3u8" {
        return Redirect::temporary(&format!("/media/{}", STREAMS[id % 2].0)).into_response();
    }
    let file = if id % 4 == 3 { "ts2160hevc.ts" } else { "ts1080.ts" };
    serve(&s, file, req).await
}

async fn vod_stream(State(s): State<AppState>, Path((user, pass, _file)): Path<(String, String, String)>, req: Request) -> Response {
    if let Err(r) = check_creds(&user, &pass) {
        return r;
    }
    // Several audio/subtitle tracks, like provider VOD, when generated.
    let file = if s.media.join("vod-multi.mkv").exists() { "vod-multi.mkv" } else { "ts1080.ts" };
    serve(&s, file, req).await
}

/// Catch-up: the start arrives in the panel's local time (Europe/Istanbul,
/// UTC+3); anything malformed is a 404, like real panels.
async fn timeshift_stream(
    State(s): State<AppState>,
    Path((user, pass, minutes, start, _file)): Path<(String, String, String, String, String)>,
    req: Request,
) -> Response {
    if let Err(r) = check_creds(&user, &pass) {
        return r;
    }
    let valid = minutes.parse::<u32>().is_ok_and(|m| m > 0)
        && start.len() == 16
        && start.as_bytes()[10] == b':'
        && start.as_bytes()[13] == b'-';
    if !valid {
        return StatusCode::NOT_FOUND.into_response();
    }
    serve(&s, "ts1080.ts", req).await
}

async fn serve(s: &AppState, file: &str, req: Request) -> Response {
    match ServeFile::new(s.media.join(file)).oneshot(req).await {
        Ok(r) => r.map(Body::new),
        Err(_) => StatusCode::INTERNAL_SERVER_ERROR.into_response(),
    }
}

async fn spike_channels(State(s): State<AppState>) -> impl IntoResponse {
    let channels: Vec<_> = (0..48)
        .map(|i| {
            let (file, label) = STREAMS[i % STREAMS.len()];
            json!({
                "name": format!("{} {} · {label}", tx("Kanal", "Channel"), i + 1),
                "url": format!("{}/media/{file}", s.base),
            })
        })
        .collect();
    Json(channels)
}

async fn playlist(State(s): State<AppState>, Query(q): Query<HashMap<String, String>>) -> impl IntoResponse {
    let groups: &[&str] = if en() { &["Entertainment", "Sport", "News", "Documentary", "Kids", "Music", "World"] } else { &["Ulusal", "Spor", "Haber", "Belgesel", "Çocuk", "Müzik", "Dünya"] };
    let n = q.get("n").and_then(|n| n.parse::<usize>().ok()).unwrap_or(1000).min(500_000);
    let mut body = String::with_capacity(n * 200);
    // The guide is announced in the header, as real playlists do.
    let _ = writeln!(body, "#EXTM3U url-tvg=\"{}/xmltv.xml.gz?n={n}\"", s.base);
    for i in 0..n {
        let (file, _) = STREAMS[i % STREAMS.len()];
        let group = groups[i % groups.len()];
        // Every third channel has a 3-day archive, M3U style (append).
        let catchup = if i % 3 == 0 { " catchup=\"append\" catchup-days=\"3\" catchup-source=\"?utc={utc}&lutc={lutc}\"" } else { "" };
        // Some channels carry no tvg-id: the guide must match them by name.
        let id = if i % 10 == 9 { String::new() } else { format!(" tvg-id=\"ch{i}.tr\"") };
        let _ = writeln!(
            body,
            "#EXTINF:-1{id} tvg-logo=\"{}/media/logos/{}.png\" group-title=\"{group}\"{catchup},{} {i}\n{}/media/{file}",
            s.base,
            i % 12,
            tx("Kanal", "Channel"),
            s.base
        );
    }
    ([(header::CONTENT_TYPE, "audio/x-mpegurl; charset=utf-8")], body)
}

// ---- TMDB stand-in ------------------------------------------------------

/// Keys the mock accepts: a v3-style key and a v4-style (JWT-looking) token.
pub const TMDB_KEY: &str = "kp-mock-tmdb-key";
pub const TMDB_TOKEN: &str = "eyJrcC1tb2NrLXRva2VuIn0";

fn tmdb_authorized(q: &HashMap<String, String>, headers: &axum::http::HeaderMap) -> bool {
    let bearer = headers
        .get(header::AUTHORIZATION)
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "));
    q.get("api_key").map(String::as_str) == Some(TMDB_KEY) || bearer == Some(TMDB_TOKEN)
}

fn tmdb_denied() -> Response {
    (
        StatusCode::UNAUTHORIZED,
        Json(json!({"status_code": 7, "status_message": "Invalid API key: You must be granted a valid key.", "success": false})),
    )
        .into_response()
}

const OS_KEY: &str = "kp-mock-os-key";

fn os_ok(headers: &axum::http::HeaderMap) -> bool {
    headers.get("api-key").and_then(|v| v.to_str().ok()) == Some(OS_KEY)
        && headers.get(header::USER_AGENT).and_then(|v| v.to_str().ok()).is_some_and(|ua| ua.starts_with("Karadelik"))
}

async fn os_formats(headers: axum::http::HeaderMap) -> Response {
    if !os_ok(&headers) {
        return (StatusCode::UNAUTHORIZED, Json(json!({"message": "Invalid API key"}))).into_response();
    }
    Json(json!({"data": {"output_formats": ["srt", "vtt"]}})).into_response()
}

/// Two Turkish and one English file for any film or episode asked for.
async fn os_search(Query(q): Query<HashMap<String, String>>, headers: axum::http::HeaderMap) -> Response {
    if !os_ok(&headers) {
        return (StatusCode::UNAUTHORIZED, Json(json!({"message": "Invalid API key"}))).into_response();
    }
    let what = q.get("tmdb_id").or(q.get("parent_tmdb_id")).or(q.get("query")).cloned().unwrap_or_default();
    let episode = q.get("episode_number").map(|e| format!(".E{e:0>2}")).unwrap_or_default();
    let item = |id: i64, lang: &str, downloads: i64, sdh: bool| {
        json!({"id": id.to_string(), "type": "subtitle", "attributes": {
            "language": lang, "download_count": downloads, "hearing_impaired": sdh, "from_trusted": true,
            "release": format!("{what}{episode}.1080p.WEB-DL.{lang}"),
            "files": [{"file_id": id, "file_name": format!("{what}{episode}.{lang}.srt")}]}})
    };
    Json(json!({"total_count": 3, "page": 1, "data": [item(9001, "tr", 4200, false), item(9002, "en", 900, false), item(9003, "tr", 150, true)]}))
        .into_response()
}

async fn os_download(State(s): State<AppState>, headers: axum::http::HeaderMap, Json(body): Json<Value>) -> Response {
    if !os_ok(&headers) {
        return (StatusCode::UNAUTHORIZED, Json(json!({"message": "Invalid API key"}))).into_response();
    }
    let id = body.get("file_id").and_then(Value::as_i64).unwrap_or(0);
    Json(json!({"link": format!("{}/os/file/{id}", s.base), "file_name": format!("{id}.srt"), "requests": 1, "remaining": 19}))
        .into_response()
}

async fn os_file(Path(id): Path<String>) -> Response {
    let text = format!("1
00:00:01,000 --> 00:00:04,000
OpenSubtitles test altyazısı {id}

2
00:00:05,000 --> 00:00:09,000
İkinci satır: çğıöşü
");
    ([(header::CONTENT_TYPE, "application/x-subrip")], text).into_response()
}

async fn tmdb_auth(Query(q): Query<HashMap<String, String>>, headers: axum::http::HeaderMap) -> Response {
    if !tmdb_authorized(&q, &headers) {
        return tmdb_denied();
    }
    Json(json!({"success": true, "status_code": 1, "status_message": "Success."})).into_response()
}

async fn tmdb_search(
    Path(media): Path<String>,
    Query(q): Query<HashMap<String, String>>,
    headers: axum::http::HeaderMap,
) -> Response {
    if !tmdb_authorized(&q, &headers) {
        return tmdb_denied();
    }
    let query = q.get("query").cloned().unwrap_or_default();
    // Films are title(i); series are series_title(i).
    let hit = (0..300usize).find(|&i| match media.as_str() {
        "movie" => title(i) == query,
        _ => series_title(i) == query,
    });
    let results: Vec<Value> = hit
        .map(|i| {
            let id = if media == "movie" { 100_000 + i } else { 200_000 + i };
            vec![json!({"id": id, "title": query, "name": query})]
        })
        .unwrap_or_default();
    Json(json!({"page": 1, "results": results, "total_results": results.len()})).into_response()
}

fn tmdb_people() -> Value {
    let names = if en() { ["Sam Rivers", "Ada Moreno", "Noah Clarke", "Lena Fischer", "Omar Haddad", "Mia Laurent"] } else { ["Deniz Aksoy", "Ece Yılmaz", "Mert Kaya", "Selin Demir", "Can Öztürk", "Zeynep Arslan"] };
    let roles = if en() { ["Captain", "Doctor", "Reporter", "Inspector", "Painter", "Teacher"] } else { ["Kaptan", "Doktor", "Muhabir", "Komiser", "Ressam", "Öğretmen"] };
    json!({
        "cast": names.iter().zip(roles).enumerate().map(|(k, (n, r))| json!({
            "name": n, "character": r, "profile_path": format!("/person-{}.png", k % 12)
        })).collect::<Vec<_>>(),
        "crew": [{"name": tx("Ayşe Karadeniz", "Clara Hughes"), "job": "Director"}, {"name": tx("Ali Veli", "Tom Baker"), "job": "Writer"}]
    })
}

async fn tmdb_movie(Path(id): Path<usize>, Query(q): Query<HashMap<String, String>>, headers: axum::http::HeaderMap) -> Response {
    if !tmdb_authorized(&q, &headers) {
        return tmdb_denied();
    }
    let i = id.saturating_sub(100_000);
    Json(json!({
        "id": id,
        "title": title(i),
        "original_title": format!("The {}", title(i)),
        "tagline": tx("Bazı sırlar denizin dibinde kalmaz.", "Some secrets do not stay at the bottom of the sea."),
        "overview": if en() { format!("TMDB overview: a complete synopsis of {} with its cast and crew. Test data.", title(i)) } else { format!("TMDB özeti: {} için yazılmış, oyuncuları ve ekibiyle eksiksiz bir tanıtım. Test verisidir.", title(i)) },
        "genres": [{"id": 18, "name": tx("Dram", "Drama")}, {"id": 53, "name": tx("Gerilim", "Thriller")}],
        "release_date": format!("{}-05-17", 1995 + i % 30),
        "runtime": 112,
        "vote_average": 7.8,
        "vote_count": 1834,
        "poster_path": format!("/poster-{}.jpg", i % 24),
        "backdrop_path": format!("/backdrop-{}.jpg", i % 4),
        "credits": tmdb_people(),
        "videos": {"results": [{"site": "YouTube", "type": "Trailer", "official": true, "key": "kp-mock-trailer"}]},
        "release_dates": {"results": [{"iso_3166_1": "TR", "release_dates": [{"certification": "13+"}]}]}
    }))
    .into_response()
}

async fn tmdb_tv(Path(id): Path<usize>, Query(q): Query<HashMap<String, String>>, headers: axum::http::HeaderMap) -> Response {
    if !tmdb_authorized(&q, &headers) {
        return tmdb_denied();
    }
    let i = id.saturating_sub(200_000);
    Json(json!({
        "id": id,
        "name": series_title(i),
        "original_name": format!("The {}", title(i + 7)),
        "tagline": "",
        "overview": tx("TMDB özeti: bir kıyı kasabasında her sezon yeni bir gizem. Test verisidir.", "TMDB overview: a new mystery every season in a coastal town. Test data."),
        "genres": [{"id": 9648, "name": tx("Gizem", "Mystery")}, {"id": 18, "name": tx("Dram", "Drama")}],
        "first_air_date": format!("{}-09-01", 2010 + i % 15),
        "episode_run_time": [45],
        "number_of_seasons": 1 + i % 3,
        "vote_average": 8.1,
        "vote_count": 921,
        "poster_path": format!("/poster-{}.jpg", (i + 5) % 24),
        "backdrop_path": format!("/backdrop-{}.jpg", i % 4),
        "created_by": [{"name": tx("Murat Sezer", "Jonas Berg")}],
        "credits": tmdb_people(),
        "videos": {"results": []},
        "content_ratings": {"results": [{"iso_3166_1": "TR", "rating": "16+"}]}
    }))
    .into_response()
}

async fn tmdb_season(
    Path((id, season)): Path<(usize, i32)>,
    Query(q): Query<HashMap<String, String>>,
    headers: axum::http::HeaderMap,
) -> Response {
    if !tmdb_authorized(&q, &headers) {
        return tmdb_denied();
    }
    let episodes: Vec<Value> = (1..=8)
        .map(|n| {
            json!({
                "episode_number": n,
                "name": format!("{}: {}", if en() { format!("Season {season} Episode {n}") } else { format!("{season}. Sezon {n}. Bölüm") }, shows()[(id + n as usize) % shows().len()]),
                "overview": if en() { format!("Season {season}, episode {n}: a new trace turns up in town.") } else { format!("Sezon {season}, bölüm {n}: kasabada yeni bir iz ortaya çıkar.") },
                "still_path": format!("/backdrop-{}.jpg", n % 4),
                "runtime": 44,
                "air_date": format!("2020-0{}-1{}", 1 + n % 9, n % 10)
            })
        })
        .collect();
    Json(json!({"season_number": season, "episodes": episodes})).into_response()
}

/// Serves TMDB image paths from the generated media: poster-N, backdrop-N, person-N.
async fn tmdb_image(State(s): State<AppState>, Path((_size, file)): Path<(String, String)>, req: Request) -> Response {
    let (kind, rest) = file.split_once('-').unwrap_or(("", ""));
    let path = match kind {
        "poster" => format!("posters/{rest}"),
        "backdrop" => format!("backdrops/{rest}"),
        "person" => format!("logos/{rest}"),
        _ => return StatusCode::NOT_FOUND.into_response(),
    };
    serve(&s, &path, req).await
}

// ---- XMLTV --------------------------------------------------------------

/// The playlist's guide: three days back to a day ahead, from the same
/// schedule the Xtream API serves.
fn xmltv_body(n: usize) -> String {
    let t = now();
    let fmt = |s: i64| {
        let (y, m, d) = civil_from_days(s.div_euclid(86_400));
        let secs = s.rem_euclid(86_400);
        format!("{y:04}{m:02}{d:02}{:02}{:02}{:02} +0000", secs / 3600, secs / 60 % 60, secs % 60)
    };
    let mut out = String::with_capacity(n * 4096);
    out.push_str("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<tv generator-info-name=\"mock-iptv\">\n");
    for i in 0..n {
        let _ = writeln!(out, "  <channel id=\"ch{i}.tr\"><display-name>{} {i}</display-name></channel>", tx("Kanal", "Channel"));
    }
    for i in 0..n {
        for p in schedule(1000 + i, t - 3 * 86_400, t + 86_400) {
            let _ = writeln!(
                out,
                "  <programme start=\"{}\" stop=\"{}\" channel=\"ch{i}.tr\"><title lang=\"tr\">{}</title><desc lang=\"tr\">{}</desc></programme>",
                fmt(p.start),
                fmt(p.stop),
                p.show,
                p.show
            );
        }
    }
    out.push_str("</tv>\n");
    out
}

/// Days since 1970-01-01 to (year, month, day), proleptic Gregorian.
fn civil_from_days(z: i64) -> (i64, u32, u32) {
    let z = z + 719_468;
    let era = z.div_euclid(146_097);
    let doe = z.rem_euclid(146_097);
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    (yoe + era * 400 + i64::from(m <= 2), m, d)
}

async fn xmltv(Query(q): Query<HashMap<String, String>>) -> impl IntoResponse {
    let n = q.get("n").and_then(|n| n.parse::<usize>().ok()).unwrap_or(1000).min(20_000);
    ([(header::CONTENT_TYPE, "application/xml; charset=utf-8")], xmltv_body(n))
}

async fn xmltv_gz(Query(q): Query<HashMap<String, String>>) -> impl IntoResponse {
    use std::io::Write as _;
    let n = q.get("n").and_then(|n| n.parse::<usize>().ok()).unwrap_or(1000).min(20_000);
    let mut gz = flate2::write::GzEncoder::new(Vec::new(), flate2::Compression::fast());
    let _ = gz.write_all(xmltv_body(n).as_bytes());
    // Served as a file, not Content-Encoding: the client must spot the gzip.
    ([(header::CONTENT_TYPE, "application/gzip")], gz.finish().unwrap_or_default())
}

// ---- Stalker portal -----------------------------------------------------

pub const STALKER_MAC: &str = "00:1A:79:00:00:01";
const STALKER_TOKEN: &str = "kp-mock-portal-token";
const STALKER_GENRES: &[&str] = &["TR: Ulusal", "TR: Haber", "TR: Spor", "Belgesel", "XXX"];

/// One handler for load.php, like the real middleware: `type` + `action`.
async fn stalker(State(s): State<AppState>, Query(q): Query<HashMap<String, String>>, headers: axum::http::HeaderMap) -> Response {
    let cookie = headers.get(header::COOKIE).and_then(|v| v.to_str().ok()).unwrap_or("");
    let mac_ok = cookie.contains(&format!("mac={}", STALKER_MAC.replace(':', "%3A"))) || cookie.contains(&format!("mac={STALKER_MAC}"));
    let authed = headers
        .get(header::AUTHORIZATION)
        .and_then(|v| v.to_str().ok())
        .is_some_and(|v| v == format!("Bearer {STALKER_TOKEN}"));
    let action = (q.get("type").map(String::as_str).unwrap_or(""), q.get("action").map(String::as_str).unwrap_or(""));
    if action != ("stb", "handshake") && !authed {
        return (StatusCode::OK, "Authorization failed.").into_response();
    }
    let js = match action {
        ("stb", "handshake") => json!({"token": STALKER_TOKEN}),
        // An unknown MAC gets a profile without an id, like Ministra's block page.
        ("stb", "get_profile") if mac_ok => json!({"id": 4711, "name": "MAG250", "status": 0}),
        ("stb", "get_profile") => json!({"status": 1, "msg": "MAC not registered"}),
        ("account_info", "get_main_info") => json!({"mac": STALKER_MAC, "phone": "2027-04-19 00:00:00"}),
        ("itv", "get_genres") => {
            let mut list = vec![json!({"id": "*", "title": "All"})];
            list.extend(STALKER_GENRES.iter().enumerate().map(|(i, g)| json!({"id": (i + 1).to_string(), "title": g})));
            Value::Array(list)
        }
        ("itv", "get_all_channels") => json!({
            "total_items": 40,
            "data": (0..40).map(|i| json!({
                "id": (9000 + i).to_string(),
                "name": format!("Portal {} HD", i + 1),
                "number": (i + 1).to_string(),
                "cmd": format!("ffmpeg http://localhost/ch/{}_", 9000 + i),
                "logo": format!("{}/media/logos/{}.png", s.base, i % 12),
                "tv_genre_id": ((i % STALKER_GENRES.len()) + 1).to_string(),
                "censored": if i % STALKER_GENRES.len() == 4 { "1" } else { "0" }
            })).collect::<Vec<_>>()
        }),
        ("itv", "create_link") => {
            let id = q.get("cmd").and_then(|c| c.rsplit('/').next()).map(|c| c.trim_end_matches('_').to_string()).unwrap_or_default();
            json!({"cmd": format!("ffmpeg {}/stalker/play/{id}.ts?play_token=mock{}", s.base, now())})
        }
        ("vod", "get_categories") => {
            let mut list = vec![json!({"id": "*", "title": "All"})];
            list.extend((if en() { ["Action", "Drama", "Documentary"] } else { ["Aksiyon", "Dram", "Belgesel"] }).iter().enumerate().map(|(i, g)| json!({"id": (i + 1).to_string(), "title": g})));
            Value::Array(list)
        }
        // 30 entries per category, 14 per page like Ministra; every tenth is a series.
        ("vod", "get_ordered_list") => {
            let cat: usize = q.get("category").and_then(|v| v.parse().ok()).unwrap_or(1);
            let page: usize = q.get("p").and_then(|v| v.parse().ok()).unwrap_or(1).max(1);
            let data: Vec<Value> = (0..30usize)
                .skip((page - 1) * 14)
                .take(14)
                .map(|i| {
                    let id = cat * 1000 + i;
                    json!({
                        "id": id.to_string(),
                        "name": format!("{} (Portal)", title(id)),
                        "cmd": format!("/media/vod/{id}.mpg"),
                        "screenshot_uri": format!("{}/media/posters/{}.jpg", s.base, i % 24),
                        "year": format!("{}-01-01", 2000 + i % 25),
                        "rating_imdb": format!("{:.1}", 6.0 + (i % 30) as f32 / 10.0),
                        "is_series": if i % 10 == 9 { "1" } else { "0" }
                    })
                })
                .collect();
            json!({"total_items": 30, "max_page_items": 14, "data": data})
        }
        ("vod", "create_link") => {
            let id = q.get("cmd").and_then(|c| c.rsplit('/').next()).map(|c| c.trim_end_matches(".mpg").to_string()).unwrap_or_default();
            json!({"cmd": format!("ffmpeg {}/stalker/play/vod-{id}.ts?play_token=mock{}", s.base, now())})
        }
        ("itv", "get_short_epg") => {
            let id: usize = q.get("ch_id").and_then(|v| v.parse().ok()).unwrap_or(9000);
            let t = now();
            Value::Array(
                schedule(id, t, t + 86_400)
                    .into_iter()
                    .take(10)
                    .map(|p| json!({
                        "name": p.show,
                        "descr": describe(p.show),
                        "start_timestamp": p.start,
                        "stop_timestamp": p.stop
                    }))
                    .collect(),
            )
        }
        _ => json!([]),
    };
    Json(json!({ "js": js })).into_response()
}

async fn stalker_play(State(s): State<AppState>, Path(_file): Path<String>, Query(q): Query<HashMap<String, String>>, req: Request) -> Response {
    // Links are only good with the token create_link put in them.
    if !q.get("play_token").is_some_and(|t| t.starts_with("mock")) {
        return StatusCode::FORBIDDEN.into_response();
    }
    serve(&s, "ts1080.ts", req).await
}
