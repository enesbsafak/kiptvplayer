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
use axum::routing::get;
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
        // TMDB stand-in: the real API's shapes for the titles above.
        .route("/3/authentication", get(tmdb_auth))
        .route("/3/search/{media}", get(tmdb_search))
        .route("/3/movie/{id}", get(tmdb_movie))
        .route("/3/tv/{id}", get(tmdb_tv))
        .route("/3/tv/{id}/season/{season}", get(tmdb_season))
        .route("/t/p/{size}/{file}", get(tmdb_image))
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
    format!("{} {}", TITLE_A[i % TITLE_A.len()], TITLE_B[(i / TITLE_A.len()) % TITLE_B.len()])
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
        "get_live_categories" => categories(LIVE_CATS),
        "get_vod_categories" => categories(MOVIE_CATS),
        "get_series_categories" => categories(SERIES_CATS),
        "get_live_streams" => Value::Array(
            (0..s.live)
                .map(|i| {
                    let cat = i % LIVE_CATS.len();
                    json!({
                        "num": i + 1,
                        "name": format!("{} {} HD", LIVE_NAMES[cat], i / LIVE_CATS.len() + 1),
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
                        "category_id": (i % MOVIE_CATS.len() + 1).to_string(),
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
                        "name": format!("{} Dizisi", title(i + 7)),
                        "series_id": 8000 + i,
                        "cover": format!("{}/media/posters/{}.jpg", s.base, (i + 5) % 24),
                        "rating": format!("{:.1}", 6.0 + (i % 40) as f32 / 10.0),
                        "category_id": (i % SERIES_CATS.len() + 1).to_string(),
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
                    "plot": "Küçük bir sahil kasabasında geçen, sırlarla dolu bir hikâye. Test verisidir; gerçek bir yapımı temsil etmez.",
                    "genre": MOVIE_CATS[i % MOVIE_CATS.len()],
                    "cast": "Oyuncu Bir, Oyuncu İki, Oyuncu Üç",
                    "director": "Yönetmen Adı",
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
                            "title": format!("{}. Sezon {}. Bölüm", season, e),
                            "container_extension": "ts",
                            "info": {
                                "plot": "Bölüm özeti. Test verisidir.",
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
                    "name": format!("{} Dizisi", title(i + 7)),
                    "plot": "Bir ailenin üç kuşağa yayılan hikâyesi. Test verisidir.",
                    "genre": SERIES_CATS[i % SERIES_CATS.len()],
                    "cast": "Oyuncu Bir, Oyuncu İki",
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
            "description": b64(&format!("{} programının açıklaması.", self.show)),
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
                out.push(Programme { start, stop, show: SHOWS[(id + k + (day / 86_400) as usize) % SHOWS.len()] });
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
                "name": format!("Kanal {} · {label}", i + 1),
                "url": format!("{}/media/{file}", s.base),
            })
        })
        .collect();
    Json(channels)
}

async fn playlist(State(s): State<AppState>, Query(q): Query<HashMap<String, String>>) -> impl IntoResponse {
    const GROUPS: &[&str] = &["Ulusal", "Spor", "Haber", "Belgesel", "Çocuk", "Müzik", "Dünya"];
    let n = q.get("n").and_then(|n| n.parse::<usize>().ok()).unwrap_or(1000).min(500_000);
    let mut body = String::with_capacity(n * 160);
    body.push_str("#EXTM3U\n");
    for i in 0..n {
        let (file, _) = STREAMS[i % STREAMS.len()];
        let group = GROUPS[i % GROUPS.len()];
        let _ = writeln!(
            body,
            "#EXTINF:-1 tvg-id=\"ch{i}.tr\" tvg-logo=\"{}/media/logos/{}.png\" group-title=\"{group}\",Kanal {i}\n{}/media/{file}",
            s.base,
            i % 12,
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
    // Films are title(i); series are "title(i + 7) Dizisi".
    let hit = (0..300usize).find(|&i| match media.as_str() {
        "movie" => title(i) == query,
        _ => format!("{} Dizisi", title(i + 7)) == query,
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
    let names = ["Deniz Aksoy", "Ece Yılmaz", "Mert Kaya", "Selin Demir", "Can Öztürk", "Zeynep Arslan"];
    let roles = ["Kaptan", "Doktor", "Muhabir", "Komiser", "Ressam", "Öğretmen"];
    json!({
        "cast": names.iter().zip(roles).enumerate().map(|(k, (n, r))| json!({
            "name": n, "character": r, "profile_path": format!("/person-{}.png", k % 12)
        })).collect::<Vec<_>>(),
        "crew": [{"name": "Ayşe Karadeniz", "job": "Director"}, {"name": "Ali Veli", "job": "Writer"}]
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
        "tagline": "Bazı sırlar denizin dibinde kalmaz.",
        "overview": format!("TMDB özeti: {} için yazılmış, oyuncuları ve ekibiyle eksiksiz bir tanıtım. Test verisidir.", title(i)),
        "genres": [{"id": 18, "name": "Dram"}, {"id": 53, "name": "Gerilim"}],
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
        "name": format!("{} Dizisi", title(i + 7)),
        "original_name": format!("The {}", title(i + 7)),
        "tagline": "",
        "overview": "TMDB özeti: bir kıyı kasabasında her sezon yeni bir gizem. Test verisidir.",
        "genres": [{"id": 9648, "name": "Gizem"}, {"id": 18, "name": "Dram"}],
        "first_air_date": format!("{}-09-01", 2010 + i % 15),
        "episode_run_time": [45],
        "number_of_seasons": 1 + i % 3,
        "vote_average": 8.1,
        "vote_count": 921,
        "poster_path": format!("/poster-{}.jpg", (i + 5) % 24),
        "backdrop_path": format!("/backdrop-{}.jpg", i % 4),
        "created_by": [{"name": "Murat Sezer"}],
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
                "name": format!("{}. Sezon {}. Bölüm: {}", season, n, SHOWS[(id + n as usize) % SHOWS.len()]),
                "overview": format!("Sezon {season}, bölüm {n}: kasabada yeni bir iz ortaya çıkar."),
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
