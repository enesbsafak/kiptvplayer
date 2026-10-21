//! Stalker / Ministra middleware ("MAG portal") client: the portal URL and
//! the MAC address the user's subscription is bound to.
//!
//! The portal talks to set-top boxes: requests carry a MAG user agent and the
//! MAC in a cookie, a handshake returns a session token, and stream links are
//! short-lived, so they are asked for (`create_link`) when playback starts.

use std::sync::Mutex;
use std::time::Duration;

use serde_json::Value;

use crate::lang::t;
use crate::xtream::{as_array, as_i64, as_string};

#[derive(Debug, thiserror::Error)]
pub enum StalkerError {
    #[error("{}: {}", t("portala ulaşılamadı", "could not reach the portal"), .0)]
    Network(String),
    #[error("{} {}", t("portal şu hatayı döndürdü: HTTP", "the portal returned HTTP"), .0)]
    Status(u16),
    #[error("{}", t("portal yanıtı okunamadı", "could not read the portal response"))]
    BadResponse,
    #[error("{}", t("portal bu MAC adresini tanımadı", "the portal did not accept this MAC address"))]
    Rejected,
    #[error("{}", t("MAC adresi 00:1A:79:12:34:56 biçiminde olmalı", "the MAC address must look like 00:1A:79:12:34:56"))]
    BadMac,
}

pub type Result<T> = std::result::Result<T, StalkerError>;

/// What MAG boxes send; many portals refuse anything else.
const MAG_UA: &str = "Mozilla/5.0 (QtEmbedded; U; Linux; C) AppleWebKit/533.3 (KHTML, like Gecko) MAG200 stbapp ver: 2 rev: 250 Safari/533.3";

#[derive(Debug, Clone, PartialEq)]
pub struct Genre {
    pub id: String,
    pub title: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Channel {
    pub id: i64,
    pub name: String,
    pub number: Option<u32>,
    /// Opaque play command, turned into a URL by [StalkerClient::create_link].
    pub cmd: String,
    pub logo: Option<String>,
    pub genre_id: Option<String>,
    pub adult: bool,
}

/// A film from the portal's video library.
#[derive(Debug, Clone, PartialEq)]
pub struct Movie {
    pub id: i64,
    pub name: String,
    pub cmd: String,
    pub poster: Option<String>,
    pub category_id: String,
    pub year: Option<i32>,
    pub rating: Option<f32>,
    pub adult: bool,
}

/// Pages fetched at once from the video library (14 items per page).
const VOD_PARALLEL: usize = 6;

#[derive(Debug, Clone, PartialEq)]
pub struct EpgEntry {
    pub start: i64,
    pub stop: i64,
    pub title: String,
    pub description: String,
}

pub struct StalkerClient {
    /// `.../server/load.php` (or `portal.php`).
    endpoint: String,
    /// Portal root, sent as Referer.
    referer: String,
    mac: String,
    http: reqwest::blocking::Client,
    token: Mutex<Option<String>>,
}

/// "00-1a-79-ab-cd-ef", "001A79ABCDEF" → "00:1A:79:AB:CD:EF".
pub fn normalize_mac(mac: &str) -> Result<String> {
    let hex: String = mac.chars().filter(|c| c.is_ascii_hexdigit()).collect::<String>().to_uppercase();
    if hex.len() != 12 || mac.chars().any(|c| !(c.is_ascii_hexdigit() || matches!(c, ':' | '-' | ' ' | '.'))) {
        return Err(StalkerError::BadMac);
    }
    Ok(hex.as_bytes().chunks(2).map(|p| std::str::from_utf8(p).unwrap_or("00")).collect::<Vec<_>>().join(":"))
}

/// Where the portal's API lives, from what users paste: ".../c/",
/// ".../stalker_portal/c", "host:8080", ".../portal.php".
pub fn endpoints(portal: &str) -> Vec<String> {
    let mut url = portal.trim().trim_end_matches('/').to_string();
    if !(url.starts_with("http://") || url.starts_with("https://")) {
        url = format!("http://{url}");
    }
    if url.ends_with(".php") {
        return vec![url];
    }
    let base = url.strip_suffix("/c").unwrap_or(&url).to_string();
    let mut out = vec![format!("{base}/server/load.php"), format!("{base}/portal.php")];
    if !base.ends_with("/stalker_portal") {
        out.push(format!("{base}/stalker_portal/server/load.php"));
    }
    out
}

impl StalkerClient {
    /// Finds the portal's API among the usual locations and opens a session.
    pub fn connect(portal: &str, mac: &str, timezone: &str, insecure_tls: bool) -> Result<Self> {
        let mac = normalize_mac(mac)?;
        let http = reqwest::blocking::Client::builder()
            .timeout(Duration::from_secs(30))
            .connect_timeout(Duration::from_secs(10))
            .user_agent(MAG_UA)
            .danger_accept_invalid_certs(insecure_tls)
            .default_headers({
                let mut h = reqwest::header::HeaderMap::new();
                h.insert("X-User-Agent", reqwest::header::HeaderValue::from_static("Model: MAG250; Link: WiFi"));
                let cookie = format!("mac={}; stb_lang=en; timezone={}", mac.replace(':', "%3A"), timezone.replace('/', "%2F"));
                if let Ok(v) = reqwest::header::HeaderValue::from_str(&cookie) {
                    h.insert(reqwest::header::COOKIE, v);
                }
                h
            })
            .build()
            .map_err(|e| StalkerError::Network(e.to_string()))?;
        let mut last = StalkerError::BadResponse;
        for endpoint in endpoints(portal) {
            let referer = endpoint.rsplit_once("/server/").map(|(b, _)| format!("{b}/c/")).unwrap_or_else(|| endpoint.clone());
            let client = StalkerClient { endpoint, referer, mac: mac.clone(), http: http.clone(), token: Mutex::new(None) };
            match client.handshake() {
                Ok(()) => return Ok(client),
                // Wrong place: try the next; a refusal is final.
                Err(e @ StalkerError::Rejected) => return Err(e),
                Err(e) => last = e,
            }
        }
        Err(last)
    }

    fn request(&self, params: &[(&str, &str)]) -> Result<Value> {
        let mut req = self.http.get(&self.endpoint).query(params).query(&[("JsHttpRequest", "1-xml")]).header(reqwest::header::REFERER, &self.referer);
        if let Some(token) = self.token.lock().unwrap_or_else(|p| p.into_inner()).as_ref() {
            req = req.bearer_auth(token);
        }
        let resp = req.send().map_err(|e| StalkerError::Network(e.to_string()))?;
        match resp.status().as_u16() {
            200..=299 => {}
            401 | 403 => return Err(StalkerError::Rejected),
            s => return Err(StalkerError::Status(s)),
        }
        let text = resp.text().map_err(|_| StalkerError::BadResponse)?;
        // Portals answer "Authorization failed." as plain text when the
        // session expired.
        if text.contains("Authorization failed") {
            return Err(StalkerError::Rejected);
        }
        let v: Value = serde_json::from_str(&text).map_err(|_| StalkerError::BadResponse)?;
        v.get("js").cloned().ok_or(StalkerError::BadResponse)
    }

    /// Session token, then the box profile (some portals only serve
    /// channels to a box that asked for its profile).
    fn handshake(&self) -> Result<()> {
        *self.token.lock().unwrap_or_else(|p| p.into_inner()) = None;
        let js = self.request(&[("type", "stb"), ("action", "handshake"), ("token", "")])?;
        let token = as_string(js.get("token")).ok_or(StalkerError::Rejected)?;
        *self.token.lock().unwrap_or_else(|p| p.into_inner()) = Some(token);
        let profile = self.request(&[("type", "stb"), ("action", "get_profile"), ("hd", "1"), ("stb_type", "MAG250")])?;
        // A portal that does not know the MAC sends an empty profile or a
        // block message instead of an id.
        if as_i64(profile.get("id")).is_none() && as_string(profile.get("id")).is_none() {
            return Err(StalkerError::Rejected);
        }
        Ok(())
    }

    /// One retry with a fresh session when the token has expired.
    fn call(&self, params: &[(&str, &str)]) -> Result<Value> {
        match self.request(params) {
            Err(StalkerError::Rejected) => {
                self.handshake()?;
                self.request(params)
            }
            other => other,
        }
    }

    /// Account expiry, when the portal says (Unix seconds).
    pub fn expires_at(&self) -> Option<i64> {
        self.main_info().ok().flatten()
    }

    /// The account page: answers when the portal and the session are fine,
    /// with the end date when the portal gives one.
    pub fn main_info(&self) -> Result<Option<i64>> {
        let js = self.call(&[("type", "account_info"), ("action", "get_main_info")])?;
        // Ministra reports the end date in a field named "phone".
        let Some(end) = as_string(js.get("end_date")).or_else(|| as_string(js.get("phone"))) else { return Ok(None) };
        Ok(end
            .get(..10)
            .and_then(|d| chrono::NaiveDate::parse_from_str(d, "%Y-%m-%d").ok())
            .and_then(|d| d.and_hms_opt(0, 0, 0))
            .map(|d| d.and_utc().timestamp()))
    }

    pub fn genres(&self) -> Result<Vec<Genre>> {
        let js = self.call(&[("type", "itv"), ("action", "get_genres")])?;
        Ok(as_array(js)
            .iter()
            .filter_map(|g| {
                let id = as_string(g.get("id"))?;
                // "*" is the portal's own "All" pseudo-genre.
                if id == "*" {
                    return None;
                }
                Some(Genre { title: as_string(g.get("title")).unwrap_or_else(|| id.clone()), id })
            })
            .collect())
    }

    pub fn channels(&self) -> Result<Vec<Channel>> {
        let js = self.call(&[("type", "itv"), ("action", "get_all_channels")])?;
        let list = js.get("data").cloned().map(as_array).unwrap_or_else(|| as_array(js));
        Ok(list
            .iter()
            .filter_map(|c| {
                Some(Channel {
                    id: as_i64(c.get("id"))?,
                    name: as_string(c.get("name"))?,
                    number: as_i64(c.get("number")).and_then(|n| u32::try_from(n).ok()),
                    cmd: as_string(c.get("cmd"))?,
                    logo: as_string(c.get("logo")).filter(|l| l.starts_with("http")),
                    genre_id: as_string(c.get("tv_genre_id")),
                    adult: as_i64(c.get("censored")) == Some(1),
                })
            })
            .collect())
    }

    /// Video library categories ("*", the portal's "All", left out).
    pub fn vod_categories(&self) -> Result<Vec<Genre>> {
        let js = self.call(&[("type", "vod"), ("action", "get_categories")])?;
        Ok(as_array(js)
            .iter()
            .filter_map(|g| {
                let id = as_string(g.get("id"))?;
                (id != "*").then(|| Genre { title: as_string(g.get("title")).unwrap_or_else(|| id.clone()), id })
            })
            .collect())
    }

    fn vod_page(&self, category: &str, page: u32) -> Result<(Vec<Movie>, u32)> {
        let p = page.to_string();
        let js = self.call(&[("type", "vod"), ("action", "get_ordered_list"), ("category", category), ("p", &p), ("sortby", "added")])?;
        let total = as_i64(js.get("total_items")).unwrap_or(0).max(0) as u32;
        let per_page = as_i64(js.get("max_page_items")).unwrap_or(14).max(1) as u32;
        let movies = js
            .get("data")
            .cloned()
            .map(as_array)
            .unwrap_or_default()
            .iter()
            // Series need the portal's season/episode API: films only here.
            .filter(|m| as_i64(m.get("is_series")) != Some(1))
            .filter_map(|m| {
                Some(Movie {
                    id: as_i64(m.get("id"))?,
                    name: as_string(m.get("name"))?,
                    cmd: as_string(m.get("cmd"))?,
                    poster: as_string(m.get("screenshot_uri")).filter(|u| u.starts_with("http")),
                    category_id: category.to_string(),
                    year: as_string(m.get("year")).and_then(|y| y.get(..4)?.parse().ok()),
                    rating: crate::xtream::as_f32(m.get("rating_imdb")).filter(|r| *r > 0.0),
                    adult: as_i64(m.get("censored")) == Some(1),
                })
            })
            .collect();
        Ok((movies, total.div_ceil(per_page)))
    }

    /// Every film of the library. Pages are small, so they are fetched
    /// [VOD_PARALLEL] at a time; a page that fails is skipped, not fatal.
    pub fn movies(&self, categories: &[Genre]) -> Result<Vec<Movie>> {
        let mut all = Vec::new();
        for c in categories {
            let (first, pages) = self.vod_page(&c.id, 1)?;
            all.extend(first);
            let rest: Vec<u32> = (2..=pages).collect();
            for chunk in rest.chunks(VOD_PARALLEL) {
                let got: Vec<Vec<Movie>> = std::thread::scope(|s| {
                    let handles: Vec<_> = chunk.iter().map(|&p| s.spawn(move || self.vod_page(&c.id, p))).collect();
                    handles.into_iter().filter_map(|h| h.join().ok().and_then(|r| r.ok()).map(|(m, _)| m)).collect()
                });
                all.extend(got.into_iter().flatten());
            }
        }
        Ok(all)
    }

    /// The stream URL for a film's command, valid for a short while.
    pub fn create_vod_link(&self, cmd: &str) -> Result<String> {
        let js = self.call(&[("type", "vod"), ("action", "create_link"), ("cmd", cmd), ("forced_storage", "undefined"), ("disable_ad", "0")])?;
        let link = as_string(js.get("cmd")).ok_or(StalkerError::BadResponse)?;
        Ok(link.split_whitespace().last().unwrap_or(&link).to_string())
    }

    /// The stream URL for a channel's command, valid for a short while.
    pub fn create_link(&self, cmd: &str) -> Result<String> {
        let js = self.call(&[("type", "itv"), ("action", "create_link"), ("cmd", cmd), ("forced_storage", "undefined"), ("disable_ad", "0")])?;
        let link = as_string(js.get("cmd")).ok_or(StalkerError::BadResponse)?;
        // "ffmpeg http://…" / "auto http://…": the player prefix goes.
        Ok(link.split_whitespace().last().unwrap_or(&link).to_string())
    }

    pub fn short_epg(&self, channel_id: i64) -> Result<Vec<EpgEntry>> {
        let id = channel_id.to_string();
        let js = self.call(&[("type", "itv"), ("action", "get_short_epg"), ("ch_id", &id), ("size", "10")])?;
        Ok(as_array(js)
            .iter()
            .filter_map(|e| {
                Some(EpgEntry {
                    start: as_i64(e.get("start_timestamp"))?,
                    stop: as_i64(e.get("stop_timestamp"))?,
                    title: as_string(e.get("name"))?,
                    description: as_string(e.get("descr")).unwrap_or_default(),
                })
            })
            .collect())
    }

    pub fn mac(&self) -> &str {
        &self.mac
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn macs_normalize() {
        assert_eq!(normalize_mac("00-1a-79-ab-cd-ef").unwrap(), "00:1A:79:AB:CD:EF");
        assert_eq!(normalize_mac("001A79ABCDEF").unwrap(), "00:1A:79:AB:CD:EF");
        assert!(normalize_mac("00:1A:79:AB:CD").is_err());
        assert!(normalize_mac("zz:1A:79:AB:CD:EF").is_err());
    }

    #[test]
    fn portal_urls_users_paste() {
        assert_eq!(
            endpoints("http://p.tv:8080/c/"),
            vec!["http://p.tv:8080/server/load.php", "http://p.tv:8080/portal.php", "http://p.tv:8080/stalker_portal/server/load.php"]
        );
        assert_eq!(endpoints("p.tv/stalker_portal/c")[0], "http://p.tv/stalker_portal/server/load.php");
        assert_eq!(endpoints("https://p.tv/portal.php"), vec!["https://p.tv/portal.php"]);
    }
}
