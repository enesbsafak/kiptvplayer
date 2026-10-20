//! Xtream Codes API client.
//!
//! Providers disagree on types (ids as numbers or strings, `null` everywhere,
//! base64 EPG titles), so responses are read as loose JSON and every field
//! goes through a tolerant accessor instead of a strict struct.

use std::time::Duration;

use base64::Engine as _;
use percent_encoding::{utf8_percent_encode, AsciiSet, NON_ALPHANUMERIC};
use serde_json::Value;

use crate::catalog::ContentKind;

#[derive(Debug, thiserror::Error)]
pub enum XtreamError {
    #[error("{}: {}", crate::lang::t("sunucuya ulaşılamadı", "could not reach the server"), .0)]
    Network(String),
    #[error("{} {}", crate::lang::t("sunucu şu hatayı döndürdü: HTTP", "the server returned HTTP"), .0)]
    Status(u16),
    #[error("{}", crate::lang::t("sunucu yanıtı okunamadı", "could not read the server response"))]
    BadResponse,
    #[error("{}", crate::lang::t("kullanıcı adı veya şifre reddedildi", "username or password rejected"))]
    AuthRejected,
}

pub type Result<T> = std::result::Result<T, XtreamError>;

/// Characters kept as-is in a URL path segment; everything else is escaped,
/// so passwords with `/`, `#` or `?` no longer break stream URLs (AbiPlayer bug).
const SEGMENT: &AsciiSet = &NON_ALPHANUMERIC.remove(b'-').remove(b'_').remove(b'.').remove(b'~');

#[derive(Debug, Clone, PartialEq)]
pub struct AccountInfo {
    pub status: String,
    pub expires_at: Option<i64>,
    pub max_connections: Option<i64>,
    pub active_connections: Option<i64>,
    pub is_trial: bool,
    pub server_timezone: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ShortEpgEntry {
    pub start: i64,
    pub end: i64,
    pub title: String,
    pub description: String,
    /// The provider keeps a recording of it (catch-up available).
    pub has_archive: bool,
}

pub struct XtreamClient {
    base: String,
    username: String,
    password: String,
    http: reqwest::blocking::Client,
}

impl XtreamClient {
    pub fn new(base: &str, username: &str, password: &str, user_agent: Option<&str>, insecure_tls: bool) -> Result<Self> {
        let http = reqwest::blocking::Client::builder()
            .timeout(Duration::from_secs(60))
            .connect_timeout(Duration::from_secs(10))
            .user_agent(user_agent.unwrap_or(crate::DEFAULT_USER_AGENT))
            // Per source, by the user's choice: many providers run self-signed
            // certificates. Never global, unlike AbiPlayer.
            .danger_accept_invalid_certs(insecure_tls)
            .build()
            .map_err(|e| XtreamError::Network(e.to_string()))?;
        Ok(XtreamClient {
            base: normalize_base(base),
            username: username.to_string(),
            password: password.to_string(),
            http,
        })
    }

    fn api(&self, params: &[(&str, &str)]) -> Result<Value> {
        let mut query: Vec<(&str, &str)> = vec![("username", &self.username), ("password", &self.password)];
        query.extend_from_slice(params);
        let resp = self
            .http
            .get(format!("{}/player_api.php", self.base))
            .query(&query)
            .send()
            .map_err(|e| XtreamError::Network(redact(&e.to_string(), &self.password)))?;
        let status = resp.status();
        if !status.is_success() {
            return Err(XtreamError::Status(status.as_u16()));
        }
        resp.json::<Value>().map_err(|_| XtreamError::BadResponse)
    }

    pub fn account(&self) -> Result<AccountInfo> {
        let v = self.api(&[])?;
        let user = v.get("user_info").ok_or(XtreamError::BadResponse)?;
        if as_i64(user.get("auth")) != Some(1) {
            return Err(XtreamError::AuthRejected);
        }
        Ok(AccountInfo {
            status: as_string(user.get("status")).unwrap_or_default(),
            expires_at: as_i64(user.get("exp_date")),
            max_connections: as_i64(user.get("max_connections")),
            active_connections: as_i64(user.get("active_cons")),
            is_trial: as_i64(user.get("is_trial")) == Some(1),
            server_timezone: v.get("server_info").and_then(|s| as_string(s.get("timezone"))),
        })
    }

    pub fn categories(&self, kind: ContentKind) -> Result<Vec<Value>> {
        let action = match kind {
            ContentKind::Live => "get_live_categories",
            ContentKind::Movie => "get_vod_categories",
            ContentKind::Series => "get_series_categories",
        };
        Ok(as_array(self.api(&[("action", action)])?))
    }

    pub fn items(&self, kind: ContentKind) -> Result<Vec<Value>> {
        let action = match kind {
            ContentKind::Live => "get_live_streams",
            ContentKind::Movie => "get_vod_streams",
            ContentKind::Series => "get_series",
        };
        Ok(as_array(self.api(&[("action", action)])?))
    }

    pub fn series_info(&self, series_id: i64) -> Result<Value> {
        self.api(&[("action", "get_series_info"), ("series_id", &series_id.to_string())])
    }

    pub fn vod_info(&self, vod_id: i64) -> Result<Value> {
        self.api(&[("action", "get_vod_info"), ("vod_id", &vod_id.to_string())])
    }

    pub fn short_epg(&self, stream_id: i64, limit: u32) -> Result<Vec<ShortEpgEntry>> {
        let v = self.api(&[
            ("action", "get_short_epg"),
            ("stream_id", &stream_id.to_string()),
            ("limit", &limit.to_string()),
        ])?;
        Ok(epg_listings(&v))
    }

    /// Full programme table, past included, with archive flags: what
    /// catch-up channels need.
    pub fn epg_table(&self, stream_id: i64) -> Result<Vec<ShortEpgEntry>> {
        let v = self.api(&[("action", "get_simple_data_table"), ("stream_id", &stream_id.to_string())])?;
        Ok(epg_listings(&v))
    }


    pub fn live_url(&self, stream_id: i64, ext: &str) -> String {
        self.stream_url("live", stream_id, ext)
    }

    pub fn movie_url(&self, stream_id: i64, ext: &str) -> String {
        self.stream_url("movie", stream_id, ext)
    }

    pub fn episode_url(&self, episode_id: i64, ext: &str) -> String {
        self.stream_url("series", episode_id, ext)
    }

    /// Xtream catch-up: `/timeshift/u/p/<minutes>/<YYYY-MM-DD:HH-MM>/<id>.ts`,
    /// with the start written in the panel's own time zone.
    pub fn timeshift_url(&self, stream_id: i64, start: i64, stop: i64, server_tz: Option<&str>) -> String {
        use chrono::TimeZone;
        let minutes = ((stop - start).max(60) + 59) / 60;
        let tz: chrono_tz::Tz = server_tz.and_then(|t| t.parse().ok()).unwrap_or(chrono_tz::UTC);
        let local = tz
            .timestamp_opt(start, 0)
            .single()
            .map(|d| d.format("%Y-%m-%d:%H-%M").to_string())
            .unwrap_or_default();
        format!(
            "{}/timeshift/{}/{}/{minutes}/{local}/{stream_id}.ts",
            self.base,
            seg(&self.username),
            seg(&self.password)
        )
    }

    fn stream_url(&self, kind: &str, id: i64, ext: &str) -> String {
        format!("{}/{kind}/{}/{}/{id}.{ext}", self.base, seg(&self.username), seg(&self.password))
    }
}

fn epg_listings(v: &Value) -> Vec<ShortEpgEntry> {
    let list = v.get("epg_listings").cloned().map(as_array).unwrap_or_default();
    list.iter()
        .filter_map(|e| {
            Some(ShortEpgEntry {
                start: as_i64(e.get("start_timestamp"))?,
                end: as_i64(e.get("stop_timestamp"))?,
                title: decode_b64(e.get("title")),
                description: decode_b64(e.get("description")),
                has_archive: as_i64(e.get("has_archive")) == Some(1),
            })
        })
        .collect()
}

fn seg(s: &str) -> String {
    utf8_percent_encode(s, SEGMENT).to_string()
}

pub fn normalize_base(url: &str) -> String {
    let trimmed = url.trim().trim_end_matches('/');
    let trimmed = trimmed.strip_suffix("/player_api.php").unwrap_or(trimmed);
    if trimmed.starts_with("http://") || trimmed.starts_with("https://") {
        trimmed.to_string()
    } else {
        format!("http://{trimmed}")
    }
}

/// Errors from reqwest echo the request URL; never let the password out.
pub fn redact(message: &str, secret: &str) -> String {
    if secret.is_empty() {
        return message.to_string();
    }
    message.replace(secret, "***").replace(&seg(secret), "***")
}

pub fn as_array(v: Value) -> Vec<Value> {
    match v {
        Value::Array(a) => a,
        // Some panels return an object keyed by index instead of an array.
        Value::Object(o) => o.into_iter().map(|(_, v)| v).collect(),
        _ => Vec::new(),
    }
}

pub fn as_i64(v: Option<&Value>) -> Option<i64> {
    match v? {
        Value::Number(n) => n.as_i64().or_else(|| n.as_f64().map(|f| f as i64)),
        Value::String(s) => s.trim().parse().ok(),
        _ => None,
    }
}

pub fn as_f32(v: Option<&Value>) -> Option<f32> {
    match v? {
        Value::Number(n) => n.as_f64().map(|f| f as f32),
        Value::String(s) => s.trim().parse().ok(),
        _ => None,
    }
}

pub fn as_string(v: Option<&Value>) -> Option<String> {
    match v? {
        Value::String(s) if !s.trim().is_empty() => Some(s.trim().to_string()),
        Value::Number(n) => Some(n.to_string()),
        _ => None,
    }
}

fn decode_b64(v: Option<&Value>) -> String {
    let Some(raw) = as_string(v) else { return String::new() };
    base64::engine::general_purpose::STANDARD
        .decode(raw.as_bytes())
        .ok()
        .and_then(|b| String::from_utf8(b).ok())
        .unwrap_or(raw)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn tolerant_accessors() {
        assert_eq!(as_i64(Some(&json!("42"))), Some(42));
        assert_eq!(as_i64(Some(&json!(42))), Some(42));
        assert_eq!(as_i64(Some(&json!(null))), None);
        assert_eq!(as_f32(Some(&json!("7.5"))), Some(7.5));
        assert_eq!(as_string(Some(&json!("  "))), None);
        assert_eq!(as_array(json!({"0": 1, "1": 2})).len(), 2);
    }

    #[test]
    fn urls_escape_credentials_and_normalize_base() {
        let c = XtreamClient::new("example.com:8080/player_api.php/", "ayşe", "p/a#ss?", None, false).unwrap();
        assert_eq!(c.live_url(7, "ts"), "http://example.com:8080/live/ay%C5%9Fe/p%2Fa%23ss%3F/7.ts");
        assert_eq!(redact("GET http://x/live/u/p%2Fa%23ss%3F/1.ts", "p/a#ss?"), "GET http://x/live/u/***/1.ts");
    }

    #[test]
    fn timeshift_uses_the_panel_time_zone() {
        let c = XtreamClient::new("http://h", "u", "p", None, false).unwrap();
        // 2026-10-20 18:00:00 UTC = 21:00 in Istanbul (UTC+3).
        let start = 1_792_519_200;
        assert_eq!(
            c.timeshift_url(7, start, start + 1800, Some("Europe/Istanbul")),
            "http://h/timeshift/u/p/30/2026-10-20:21-00/7.ts"
        );
        assert_eq!(c.timeshift_url(7, start, start + 1800, None), "http://h/timeshift/u/p/30/2026-10-20:18-00/7.ts");
    }

    #[test]
    fn base64_titles() {
        assert_eq!(decode_b64(Some(&json!("SGFiZXJsZXI="))), "Haberler");
        assert_eq!(decode_b64(Some(&json!("Düz metin"))), "Düz metin");
    }
}
