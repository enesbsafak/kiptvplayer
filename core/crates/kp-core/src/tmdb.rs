//! TMDB (The Movie Database) enrichment for films and series: overview in the
//! user's language, genres, cast with photos, trailer, age rating, artwork.
//!
//! Optional and user-keyed: nothing is sent to TMDB without a key the user
//! entered. Provider data stays the fallback whenever TMDB has no match or
//! is unreachable.

use std::time::Duration;

use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::xtream::{as_array, as_f32, as_i64, as_string};

#[derive(Debug, thiserror::Error)]
pub enum TmdbError {
    #[error("{}: {}", crate::lang::t("TMDB'ye ulaşılamadı", "could not reach TMDB"), .0)]
    Network(String),
    #[error("{}", crate::lang::t("TMDB anahtarı geçersiz", "Invalid TMDB key"))]
    InvalidKey,
    #[error("{} {}", crate::lang::t("TMDB şu hatayı döndürdü: HTTP", "TMDB returned HTTP"), .0)]
    Status(u16),
    #[error("{}", crate::lang::t("TMDB yanıtı okunamadı", "Could not read the TMDB response"))]
    BadResponse,
}

pub type Result<T> = std::result::Result<T, TmdbError>;

const API: &str = "https://api.themoviedb.org/3";
const IMAGES: &str = "https://image.tmdb.org/t/p/";

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Media {
    Movie,
    Tv,
}

impl Media {
    fn path(self) -> &'static str {
        match self {
            Media::Movie => "movie",
            Media::Tv => "tv",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Person {
    pub name: String,
    /// Role played (cast) or job (crew).
    pub role: Option<String>,
    pub photo: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TmdbDetail {
    pub id: i64,
    pub media: Media,
    pub title: String,
    pub original_title: Option<String>,
    pub tagline: Option<String>,
    pub overview: Option<String>,
    pub genres: Vec<String>,
    pub year: Option<i32>,
    pub runtime_min: Option<i32>,
    pub rating: Option<f32>,
    pub vote_count: Option<i64>,
    pub poster: Option<String>,
    pub backdrop: Option<String>,
    /// Age rating for the user's country ("13+", "TV-MA"), when TMDB has one.
    pub certification: Option<String>,
    /// YouTube video id of the best trailer.
    pub trailer: Option<String>,
    pub cast: Vec<Person>,
    /// Directors (films) or creators (series).
    pub makers: Vec<String>,
    pub seasons: i32,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TmdbEpisode {
    pub season: i32,
    pub number: i32,
    pub name: Option<String>,
    pub overview: Option<String>,
    pub still: Option<String>,
    pub runtime_min: Option<i32>,
    pub air_date: Option<String>,
}

enum Auth {
    /// v3 API key: 32 hex characters, sent as `api_key`.
    Key(String),
    /// v4 API read access token (a JWT), sent as a Bearer header.
    Bearer(String),
}

pub struct Tmdb {
    http: reqwest::blocking::Client,
    auth: Auth,
    api: String,
    images: String,
    /// "tr-TR", "en-US".
    language: String,
}

impl Tmdb {
    /// [base] replaces api.themoviedb.org and image.tmdb.org for tests (the
    /// mock serves `/3/...` and `/t/p/...`).
    pub fn new(key: &str, language: &str, base: Option<&str>) -> Result<Self> {
        let key = key.trim();
        let auth = if key.starts_with("eyJ") { Auth::Bearer(key.to_string()) } else { Auth::Key(key.to_string()) };
        let http = reqwest::blocking::Client::builder()
            .timeout(Duration::from_secs(15))
            .connect_timeout(Duration::from_secs(8))
            .user_agent(crate::DEFAULT_USER_AGENT)
            .build()
            .map_err(|e| TmdbError::Network(e.to_string()))?;
        let (api, images) = match base {
            Some(b) => {
                let b = b.trim_end_matches('/');
                (format!("{b}/3"), format!("{b}/t/p/"))
            }
            None => (API.to_string(), IMAGES.to_string()),
        };
        Ok(Tmdb { http, auth, api, images, language: language.to_string() })
    }

    fn get(&self, path: &str, query: &[(&str, &str)]) -> Result<Value> {
        let mut req = self.http.get(format!("{}{path}", self.api)).query(query);
        req = match &self.auth {
            Auth::Key(k) => req.query(&[("api_key", k.as_str())]),
            Auth::Bearer(t) => req.bearer_auth(t),
        };
        let resp = req.send().map_err(|e| TmdbError::Network(self.redact(&e.to_string())))?;
        match resp.status().as_u16() {
            200..=299 => resp.json::<Value>().map_err(|_| TmdbError::BadResponse),
            401 => Err(TmdbError::InvalidKey),
            s => Err(TmdbError::Status(s)),
        }
    }

    fn redact(&self, message: &str) -> String {
        match &self.auth {
            Auth::Key(k) | Auth::Bearer(k) if !k.is_empty() => message.replace(k.as_str(), "***"),
            _ => message.to_string(),
        }
    }

    /// Checks the key before it is saved.
    pub fn validate(&self) -> Result<()> {
        let v = self.get("/authentication", &[])?;
        if v.get("success").and_then(Value::as_bool) == Some(true) { Ok(()) } else { Err(TmdbError::InvalidKey) }
    }

    /// Best match for a provider title, or None.
    pub fn search(&self, media: Media, title: &str, year: Option<i32>) -> Result<Option<i64>> {
        let year_key = if media == Media::Movie { "year" } else { "first_air_date_year" };
        let path = format!("/search/{}", media.path());
        let y = year.map(|y| y.to_string());
        let mut query = vec![("query", title), ("language", self.language.as_str()), ("include_adult", "false")];
        if let Some(y) = y.as_deref() {
            query.push((year_key, y));
        }
        let first = |v: Value| v.get("results").cloned().map(as_array).unwrap_or_default().first().and_then(|r| as_i64(r.get("id")));
        let hit = first(self.get(&path, &query)?);
        // Providers get years wrong often enough: retry without it.
        if hit.is_none() && year.is_some() {
            query.retain(|(k, _)| *k != year_key);
            return Ok(first(self.get(&path, &query)?));
        }
        Ok(hit)
    }

    pub fn detail(&self, media: Media, id: i64, country: &str) -> Result<TmdbDetail> {
        let extra = match media {
            Media::Movie => "credits,videos,release_dates",
            Media::Tv => "credits,videos,content_ratings",
        };
        // Trailers are often only in English: accept those and untagged ones.
        let lang2 = self.language.split('-').next().unwrap_or("en");
        let video_langs = format!("{lang2},en,null");
        let v = self.get(
            &format!("/{}/{id}", media.path()),
            &[("language", &self.language), ("append_to_response", extra), ("include_video_language", &video_langs)],
        )?;
        let date = as_string(v.get(if media == Media::Movie { "release_date" } else { "first_air_date" }));
        let cast = v
            .pointer("/credits/cast")
            .cloned()
            .map(as_array)
            .unwrap_or_default()
            .iter()
            .take(15)
            .filter_map(|p| {
                Some(Person {
                    name: as_string(p.get("name"))?,
                    role: as_string(p.get("character")),
                    photo: self.image("w185", p.get("profile_path")),
                })
            })
            .collect();
        let makers = match media {
            Media::Movie => v
                .pointer("/credits/crew")
                .cloned()
                .map(as_array)
                .unwrap_or_default()
                .iter()
                .filter(|p| as_string(p.get("job")).as_deref() == Some("Director"))
                .filter_map(|p| as_string(p.get("name")))
                .collect(),
            Media::Tv => v.get("created_by").cloned().map(as_array).unwrap_or_default().iter().filter_map(|p| as_string(p.get("name"))).collect(),
        };
        let runtime_min = match media {
            Media::Movie => as_i64(v.get("runtime")),
            Media::Tv => v.get("episode_run_time").cloned().map(as_array).unwrap_or_default().first().and_then(|r| as_i64(Some(r))),
        }
        .filter(|m| *m > 0)
        .map(|m| m as i32);
        Ok(TmdbDetail {
            id,
            media,
            title: as_string(v.get("title")).or_else(|| as_string(v.get("name"))).unwrap_or_default(),
            original_title: as_string(v.get("original_title")).or_else(|| as_string(v.get("original_name"))),
            tagline: as_string(v.get("tagline")),
            overview: as_string(v.get("overview")),
            genres: v.get("genres").cloned().map(as_array).unwrap_or_default().iter().filter_map(|g| as_string(g.get("name"))).collect(),
            year: date.as_deref().and_then(|d| d.get(..4)).and_then(|y| y.parse().ok()),
            runtime_min,
            rating: as_f32(v.get("vote_average")).filter(|r| *r > 0.0),
            vote_count: as_i64(v.get("vote_count")),
            poster: self.image("w500", v.get("poster_path")),
            backdrop: self.image("w1280", v.get("backdrop_path")),
            certification: certification(&v, media, country),
            trailer: trailer(&v),
            cast,
            makers,
            seasons: as_i64(v.get("number_of_seasons")).unwrap_or(0) as i32,
        })
    }

    pub fn season(&self, tv_id: i64, season: i32) -> Result<Vec<TmdbEpisode>> {
        let v = self.get(&format!("/tv/{tv_id}/season/{season}"), &[("language", &self.language)])?;
        Ok(v.get("episodes")
            .cloned()
            .map(as_array)
            .unwrap_or_default()
            .iter()
            .filter_map(|e| {
                Some(TmdbEpisode {
                    season,
                    number: as_i64(e.get("episode_number"))? as i32,
                    name: as_string(e.get("name")),
                    overview: as_string(e.get("overview")),
                    still: self.image("w300", e.get("still_path")),
                    runtime_min: as_i64(e.get("runtime")).map(|m| m as i32),
                    air_date: as_string(e.get("air_date")),
                })
            })
            .collect())
    }

    fn image(&self, size: &str, path: Option<&Value>) -> Option<String> {
        as_string(path).map(|p| format!("{}{size}{p}", self.images))
    }
}

fn certification(v: &Value, media: Media, country: &str) -> Option<String> {
    let results = match media {
        Media::Movie => v.pointer("/release_dates/results"),
        Media::Tv => v.pointer("/content_ratings/results"),
    }
    .cloned()
    .map(as_array)
    .unwrap_or_default();
    let pick = |c: &str| {
        let r = results.iter().find(|r| as_string(r.get("iso_3166_1")).as_deref() == Some(c))?;
        match media {
            Media::Movie => r
                .get("release_dates")
                .cloned()
                .map(as_array)
                .unwrap_or_default()
                .iter()
                .find_map(|d| as_string(d.get("certification"))),
            Media::Tv => as_string(r.get("rating")),
        }
    };
    pick(country).or_else(|| pick("US"))
}

fn trailer(v: &Value) -> Option<String> {
    let videos = v.pointer("/videos/results").cloned().map(as_array).unwrap_or_default();
    let youtube = |t: &str, official: bool| {
        videos.iter().find(|x| {
            as_string(x.get("site")).as_deref() == Some("YouTube")
                && as_string(x.get("type")).as_deref() == Some(t)
                && (!official || x.get("official").and_then(Value::as_bool) == Some(true))
        })
    };
    youtube("Trailer", true)
        .or_else(|| youtube("Trailer", false))
        .or_else(|| youtube("Teaser", false))
        .and_then(|x| as_string(x.get("key")))
}

/// Turns a provider title into a search query and year:
/// "TR: Esaret Altında (1994) [4K] Altyazılı" → ("Esaret Altında", 1994).
pub fn clean_title(raw: &str) -> (String, Option<i32>) {
    let mut s = raw.trim().to_string();
    // Leading region/provider tags: "TR:", "TR |", "[TR]", "4K-TR -".
    loop {
        let before = s.clone();
        let t = s.trim_start();
        if let Some(rest) = t.strip_prefix('[').and_then(|r| r.split_once(']')).map(|(_, r)| r) {
            s = rest.to_string();
        } else if let Some((head, rest)) = t.split_once([':', '|']) {
            // Tags are short and upper case ("TR", "4K", "VOD"); "Dune:" is a title.
            let h = head.trim();
            if h.len() <= 6 && !h.is_empty() && h.chars().all(|c| c.is_ascii_uppercase() || c.is_ascii_digit() || c == ' ' || c == '-') {
                s = rest.to_string();
            }
        }
        s = s.trim_start_matches([' ', '-', '|', ':']).to_string();
        if s == before {
            break;
        }
    }
    // Year: "(1994)", "[1994]", "- 1994" or a trailing "1994".
    let mut year = None;
    let bytes: Vec<char> = s.chars().collect();
    let mut cut = s.len();
    for i in (0..bytes.len().saturating_sub(3)).rev() {
        let w: String = bytes[i..i + 4].iter().collect();
        let Ok(y) = w.parse::<i32>() else { continue };
        let before_ok = i == 0 || matches!(bytes[i - 1], '(' | '[' | ' ' | '-' | '.');
        let after_ok = i + 4 == bytes.len() || matches!(bytes[i + 4], ')' | ']' | ' ' | '.' | '-');
        if (1900..=2100).contains(&y) && before_ok && after_ok && i > 0 {
            year = Some(y);
            cut = bytes[..i].iter().collect::<String>().len();
            break;
        }
    }
    s.truncate(cut);
    // Quality and language noise.
    const NOISE: &[&str] = &[
        "4k", "uhd", "fhd", "hd", "sd", "hevc", "h265", "h264", "x265", "x264", "1080p", "720p", "2160p", "hdr", "multi",
        "altyazılı", "altyazili", "dublaj", "türkçe", "turkce", "tr", "en", "dual", "vizyon", "imdb",
    ];
    let words: Vec<&str> = s.split(|c: char| c.is_whitespace() || matches!(c, '[' | ']' | '(' | ')' | '|' | '_')).filter(|w| !w.is_empty()).collect();
    let mut kept: Vec<&str> = words.clone();
    while let Some(last) = kept.last() {
        let l = crate::text::fold(last);
        if NOISE.contains(&l.as_str()) || last.chars().all(|c| matches!(c, '-' | '.' | ':')) {
            kept.pop();
        } else {
            break;
        }
    }
    let title = if kept.is_empty() { words.join(" ") } else { kept.join(" ") };
    (title.trim_matches([' ', '-', '.', ':']).to_string(), year)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn titles_lose_provider_noise() {
        let cases = [
            ("TR: Esaret Altında (1994) [4K] Altyazılı", ("Esaret Altında", Some(1994))),
            ("[TR] Kurtlar Vadisi - 2006", ("Kurtlar Vadisi", Some(2006))),
            ("4K | Dune: Part Two 2024 HEVC", ("Dune: Part Two", Some(2024))),
            ("Inception", ("Inception", None)),
            ("1917 (2019)", ("1917", Some(2019))),
            ("EN: The Office", ("The Office", None)),
            ("Blade Runner 2049 (2017) TR Dublaj", ("Blade Runner 2049", Some(2017))),
        ];
        for (raw, (title, year)) in cases {
            assert_eq!(clean_title(raw), (title.to_string(), year), "{raw}");
        }
    }

    #[test]
    fn trailer_prefers_official_youtube_trailers() {
        let v = serde_json::json!({"videos": {"results": [
            {"site": "YouTube", "type": "Teaser", "key": "teaser"},
            {"site": "Vimeo", "type": "Trailer", "key": "vimeo"},
            {"site": "YouTube", "type": "Trailer", "key": "fan", "official": false},
            {"site": "YouTube", "type": "Trailer", "key": "official", "official": true}
        ]}});
        assert_eq!(trailer(&v).as_deref(), Some("official"));
    }

    #[test]
    fn certification_for_the_country_then_us() {
        let v = serde_json::json!({"release_dates": {"results": [
            {"iso_3166_1": "US", "release_dates": [{"certification": "R"}]},
            {"iso_3166_1": "TR", "release_dates": [{"certification": ""}, {"certification": "18+"}]}
        ]}});
        assert_eq!(certification(&v, Media::Movie, "TR").as_deref(), Some("18+"));
        assert_eq!(certification(&v, Media::Movie, "DE").as_deref(), Some("R"));
    }

    #[test]
    fn v4_tokens_use_bearer_auth() {
        assert!(matches!(Tmdb::new("eyJhbGciOi.x.y", "tr-TR", None).unwrap().auth, Auth::Bearer(_)));
        assert!(matches!(Tmdb::new("0123456789abcdef0123456789abcdef", "tr-TR", None).unwrap().auth, Auth::Key(_)));
    }
}
